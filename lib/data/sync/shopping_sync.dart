import 'dart:async';

import '../../core/app_log.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/shopping.dart';
import '../../domain/shopping_store.dart';
import '../matrix/matrix_gateway.dart';
import 'send_backoff.dart';

/// Verbindet die lokale Einkaufsliste mit Matrix (E-40):
///
/// * eingehend: Signale streng prüfen ([ShoppingCodec]), per [ShoppingService] zusammenführen;
/// * ausgehend: noch nicht gesendete Änderungen in den Familienraum (Warteschlange mit Wiederholung);
/// * Resync: beim Beitritt neuer Mitglieder alle Einträge erneut senden, die man zuletzt selbst bearbeitet hat.
class ShoppingSync {
  ShoppingSync({
    required this.gateway,
    required this.service,
    required this.store,
    this.retryInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
    Duration backoffBase = const Duration(seconds: 5),
    Duration backoffMax = const Duration(seconds: 60),
  }) : _backoff = SendBackoff(clock: clock, base: backoffBase, max: backoffMax);

  final MatrixGateway gateway;
  final ShoppingService service;
  final ShoppingStore store;
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

  // Eingehende Signale werden strikt nacheinander verarbeitet.
  Future<void> _queue = Future<void>.value();

  void _enqueue(CalendarSignal s) {
    _queue = _queue.then((_) => _onSignal(s)).catchError((Object e) {
      AppLog.e('shopping', 'Signal konnte nicht verarbeitet werden', e);
    });
  }

  /// Wartet, bis alle bisher eingegangenen Signale verarbeitet sind (Tests).
  Future<void> idle() => _queue;

  void start() {
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

  /// Plant einen Sendeversuch (entprellt).
  void kick() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => publishPending().ignore());
  }

  Future<void> _onSignal(CalendarSignal s) async {
    try {
      switch (s) {
        case ShoppingSignal():
          final item = ShoppingCodec.decode(s.content, sender: s.sender);
          if (item == null) {
            rejected++;
            AppLog.w('shopping', 'Ungültigen Einkaufseintrag verworfen');
            return;
          }
          if (await service.applyIncoming(item)) onChanged?.call();
        case MemberJoinedSignal():
          // Zuverlässig: erneut zum Senden vormerken; die Warteschlange erledigt den Rest.
          await store.requeueLastEditedBy(_me);
          kick();
        default:
          break;
      }
    } catch (e) {
      AppLog.e('shopping', 'Einkaufseintrag konnte nicht verarbeitet werden', e);
    }
  }

  bool get _canPublish => gateway.session == SessionState.ready && gateway.initialSyncDone && gateway.family != null;

  /// Sendet alle noch nicht gesendeten eigenen Änderungen. Läuft nie parallel; bei Fehlern bleibt
  /// alles für den nächsten Versuch erhalten.
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
        final pending = (await store.pendingPublish()).where((i) => i.by == _me).toList()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        for (final i in pending) {
          try {
            await gateway.publishShoppingItem(i);
            await store.markPublished(i.id, i.version);
          } on GatewayException catch (err) {
            if (err.error == GatewayError.invalidInput) {
              // Lokal als nicht sendbar erkannt: nicht endlos wiederholen.
              AppLog.w('shopping', 'Eintrag nicht sendbar, Warteschlange bereinigt');
              await store.markPublished(i.id, i.version);
              continue;
            }
            AppLog.w('shopping', 'Senden verschoben (${err.error.name})');
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
