import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/app_log.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/event_theme_codec.dart';
import '../../domain/event_theme_service.dart';
import '../../domain/event_theme_store.dart';
import '../matrix/matrix_gateway.dart';
import 'send_backoff.dart';

/// Verbindet die lokalen Kalender-Themen mit Matrix (E-99), nach dem Muster von `TaskSync`:
///
/// * eingehend: Signale streng prüfen ([EventThemeCodec]), per [EventThemeService] zusammenführen;
/// * ausgehend: noch nicht gesendete eigene Themen (Warteschlange mit Wiederholung);
/// * Resync: beim Beitritt neuer Mitglieder alles Eigene erneut senden (Empfänger entfernen Duplikate).
class EventThemeSync {
  EventThemeSync({
    required this.gateway,
    required this.service,
    required this.store,
    this.retryInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
    Duration backoffBase = const Duration(seconds: 5),
    Duration backoffMax = const Duration(seconds: 60),
  }) : _backoff = SendBackoff(clock: clock, base: backoffBase, max: backoffMax);

  final MatrixGateway gateway;
  final EventThemeService service;
  final EventThemeStore store;
  final Duration retryInterval;
  final SendBackoff _backoff;

  /// Wird nach jeder Änderung des lokalen Bestands aufgerufen.
  void Function()? onChanged;

  /// Verworfene (ungültige oder unberechtigte) Ereignisse.
  int rejected = 0;

  StreamSubscription<CalendarSignal>? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _publishing = false;
  bool _again = false;

  String get _me => service.myUserId;

  /// Fehlerstand der Warteschlange (Tests).
  @visibleForTesting
  SendBackoff get backoff => _backoff;

  /// Familie, zu der der lokale Bestand gehört (#140). Ohne Angabe beim Start: die erste bekannte.
  String? _room;

  /// `false`: Der Bestand gehört zu einer anderen Familie als der aktuellen. „Keine Familie“ ist kein Wechsel.
  bool get _sameFamily {
    final current = gateway.family?.roomId;
    final room = _room ??= current;
    return room == null || current == null || room == current;
  }

  Future<void> _queue = Future<void>.value();

  void _enqueue(CalendarSignal s) {
    _queue = _queue.then((_) => _onSignal(s)).catchError((Object e) {
      AppLog.e('themes', 'Signal konnte nicht verarbeitet werden', e);
    });
  }

  /// Wartet, bis alle bisher eingegangenen Signale verarbeitet sind (Schließen der Familie, Tests).
  Future<void> idle() => _queue;

  /// [familyRoom]: Familie, für die `AppServices.openCalendar` den lokalen Bestand beansprucht hat.
  void start({String? familyRoom}) {
    _room ??= familyRoom;
    _sub ??= gateway.calendarSignals.listen(_enqueue);
    _timer ??= Timer.periodic(retryInterval, (_) => kick());
    _backoff.changed(_gatewayState()); // Ausgangszustand merken, erst spätere Wechsel heben das Fenster auf
    gateway.addListener(_onGatewayChanged);
    kick();
  }

  Object _gatewayState() => (gateway.session, gateway.userId, gateway.server, gateway.family?.roomId, gateway.initialSyncDone);

  /// Im Wartefenster nach einem Sendefehler löst eine Meldung des Gateways keinen neuen Versuch aus (#132).
  void _onGatewayChanged() {
    final changed = _backoff.changed(_gatewayState());
    if (!changed && _backoff.blocked) return;
    kick();
  }

  void dispose() {
    _sub?.cancel().ignore();
    _timer?.cancel();
    _debounce?.cancel();
    gateway.removeListener(_onGatewayChanged);
  }

  void kick() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => publishPending().ignore());
  }

  Future<void> _onSignal(CalendarSignal s) async {
    // Bleibt in der Historie des Gateways für die neuen Dienste (#140).
    if (!_sameFamily) return;
    try {
      switch (s) {
        case EventThemeSignal():
          final theme = EventThemeCodec.decode(s.content, sender: s.sender);
          if (theme == null) {
            rejected++;
            AppLog.w('themes', 'Ungültiges Kalender-Thema verworfen');
            return;
          }
          if (await service.applyIncoming(theme)) {
            onChanged?.call();
          } else if (!service.isModerator(theme.by)) {
            rejected++;
          }
        case MemberJoinedSignal():
          await store.requeueLastEditedBy(_me);
          kick();
        default:
          break;
      }
    } catch (e) {
      AppLog.e('themes', 'Themen-Ereignis konnte nicht verarbeitet werden', e);
    }
  }

  bool get _canPublish => gateway.session == SessionState.ready && gateway.initialSyncDone && gateway.family != null && _sameFamily;

  /// Sendet alle noch nicht gesendeten eigenen Themen. Läuft nie parallel.
  Future<void> publishPending() async {
    if (_publishing) {
      _again = true;
      return;
    }
    _publishing = true;
    try {
      do {
        _again = false;
        if (!_canPublish) break;
        final themes = (await store.pending()).where((t) => t.by == _me).toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        for (final t in themes) {
          if (!_canPublish) return; // Abbruch (#140): zählt weder als Erfolg noch als Fehler
          try {
            await gateway.publishEventTheme(t);
            await store.markPublished(t.id, t.version);
          } on GatewayException catch (err) {
            if (err.error == GatewayError.invalidInput) {
              AppLog.w('themes', 'Thema nicht sendbar, Warteschlange bereinigt');
              await store.markPublished(t.id, t.version);
              continue;
            }
            AppLog.w('themes', 'Senden verschoben (${err.error.name})');
            _backoff.failure();
            return;
          }
        }
        _backoff.success();
      } while (_again);
    } finally {
      _publishing = false;
    }
  }
}
