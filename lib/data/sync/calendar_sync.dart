import 'dart:async';

import '../../core/app_log.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_service.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/conflict.dart';
import '../../domain/event_codec.dart';
import '../../domain/event_store.dart';
import '../matrix/matrix_gateway.dart';
import 'send_backoff.dart';

/// Verbindet lokale Termine mit Matrix (E-09, E-13):
///
/// * eingehend: Signale prüfen (Codec, Absender), per [CalendarService] anwenden;
/// * ausgehend: nicht veröffentlichte Termine senden – **geteilte nur in den
///   Familienraum, private nur in den privaten Raum** (Warteschlange mit Wiederholung);
/// * Resync: beim Beitritt neuer Mitglieder die eigenen geteilten Termine erneut senden.
class CalendarSync {
  CalendarSync({
    required this.gateway,
    required this.service,
    required this.store,
    DateTime Function()? clock,
    this.retryInterval = const Duration(seconds: 60),
    Duration backoffBase = const Duration(seconds: 5),
    Duration backoffMax = const Duration(seconds: 60),
  })  : _clock = clock ?? DateTime.now,
        _backoff = SendBackoff(clock: clock, base: backoffBase, max: backoffMax);

  final MatrixGateway gateway;
  final CalendarService service;
  final EventStore store;
  final Duration retryInterval;
  final DateTime Function() _clock;
  final SendBackoff _backoff;

  /// Wird nach jeder Änderung des lokalen Bestands aufgerufen.
  void Function()? onChanged;

  StreamSubscription<CalendarSignal>? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _publishing = false;
  bool _again = false;
  int rejected = 0;
  DateTime? _lastRsvpTs;

  String get _me => service.myUserId;

  // Eingehende Signale werden strikt nacheinander verarbeitet (keine Überholvorgänge).
  Future<void> _queue = Future<void>.value();

  void _enqueue(CalendarSignal s) {
    _queue = _queue.then((_) => _onSignal(s)).catchError((Object e) {
      AppLog.e('sync', 'Signal konnte nicht verarbeitet werden', e);
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

  /// Der Gateway meldet sich auch nach jedem Fehlerereignis eines Sendeversuchs; im Wartefenster nach einem
  /// Fehler löst das keinen neuen Versuch aus (#132). Anmeldung, Wiederverbindung und Konto-/Familienwechsel
  /// heben das Fenster auf.
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

  // ------------------------------------------------------------- eingehend

  Future<void> _onSignal(CalendarSignal s) async {
    try {
      switch (s) {
        case SharedEventSignal():
          await _apply(EventCodec.decode(s.content, sender: s.sender, visibility: EventVisibility.shared));
        case PrivateEventSignal():
          // Private Termine stammen ausschließlich vom eigenen Konto.
          if (s.sender != _me) {
            rejected++;
            AppLog.w('sync', 'Fremder Absender im privaten Raum verworfen');
            return;
          }
          await _apply(EventCodec.decode(s.content, sender: s.sender, visibility: EventVisibility.private));
        case RsvpSignal():
          final r = EventCodec.decodeRsvp(s.content);
          if (r == null) {
            rejected++;
            return;
          }
          // Nur Antworten auf bekannte, geteilte Termine werden gespeichert (Speicherschutz).
          final known = await store.get(r.eventId);
          if (known == null || !known.isShared) {
            rejected++;
            return;
          }
          // Nur eine wirksame Änderung lädt den Kalender neu; Duplikate und ältere Zusagen nicht (#131).
          if (await store.putRsvp(r.eventId, s.sender, r.status, r.timestamp)) onChanged?.call();
        case ShoppingSignal():
        case TaskListSignal():
        case TaskLogSignal():
          break; // gehört dem Einkaufszettel (ShoppingSync)
        case MemberJoinedSignal():
          // Zuverlässig: erneut zum Senden vormerken; die Warteschlange (mit Wiederholung)
          // erledigt den Rest, auch nach Neustart.
          await store.requeueOwnShared(_me);
          kick();
      }
    } catch (e) {
      AppLog.e('sync', 'Kalender-Ereignis konnte nicht verarbeitet werden', e);
    }
  }

  Future<void> _apply(DecodeResult r) async {
    final e = r.event;
    if (e == null) {
      rejected++;
      AppLog.w('sync', 'Ungültiges Kalender-Ereignis verworfen (${r.error})');
      return;
    }
    final resolution = await service.applyIncoming(e);
    // Nur neue und geänderte Termine laden den Kalender neu. Duplikate, ältere Fassungen (nur Verlauf) und
    // abgelehnte Absender ändern den Bestand nicht (#131).
    if (resolution == Resolution.insert || resolution == Resolution.replace) onChanged?.call();
  }

  // -------------------------------------------------------------- ausgehend

  bool get _canPublish => gateway.session == SessionState.ready && gateway.initialSyncDone;

  /// Sendet alle noch nicht veröffentlichten eigenen Termine und Zusagen.
  /// Läuft nie parallel; bei Fehlern bleibt alles für den nächsten Versuch erhalten.
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
        // Beide Teile laufen immer; der Durchlauf zählt höchstens einen Fehler (#132).
        final eventsOk = await _publishEvents();
        final rsvpsOk = await _publishRsvps();
        if (eventsOk && rsvpsOk) {
          _backoff.success();
        } else {
          _backoff.failure();
          break;
        }
      } while (_again);
    } finally {
      _publishing = false;
    }
  }

  /// `false`, wenn ein Sendefehler den Durchlauf beendet hat.
  Future<bool> _publishEvents() async {
    final pending = (await store.pendingPublish()).where((e) => e.ownerId == _me).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    for (final e in pending) {
      try {
        if (e.isShared) {
          if (gateway.family == null) continue;
          await gateway.publishSharedEvent(e);
        } else {
          await gateway.publishPrivateEvent(e);
        }
        await store.markPublished(e.id, e.version);
      } on GatewayException catch (err) {
        if (err.error == GatewayError.invalidInput) {
          // Lokal als nicht sendbar erkannt (Codec): nicht endlos wiederholen. Serverfehler
          // werden vom Gateway nie als `invalidInput` gemeldet und bleiben in der Warteschlange.
          AppLog.w('sync', 'Termin nicht sendbar, Warteschlange bereinigt');
          await store.markPublished(e.id, e.version);
          continue;
        }
        AppLog.w('sync', 'Senden verschoben (${err.error.name})');
        return false;
      }
    }
    return true;
  }

  Future<bool> _publishRsvps() async {
    if (gateway.family == null) return true;
    for (final r in await store.pendingRsvps(_me)) {
      final target = await store.get(r.eventId);
      if (target == null || !target.isShared || target.deleted) {
        await store.markRsvpPublished(r.eventId, _me, r.timestamp);
        continue;
      }
      try {
        await gateway.publishRsvp(r.eventId, r.status, r.timestamp);
        await store.markRsvpPublished(r.eventId, _me, r.timestamp);
      } on GatewayException catch (err) {
        AppLog.w('sync', 'Zusage verschoben (${err.error.name})');
        return false;
      }
    }
    return true;
  }

  /// Beim Beitritt neuer Mitglieder: eigene aktuelle geteilte Termine erneut senden
  /// (gleiche Version; Empfänger behandeln das als Duplikat). Neue Mitglieder
  /// können ältere Megolm-Sitzungen nicht lesen (E-13).
  Future<void> resyncOwnShared() async {
    if (!_canPublish || gateway.family == null) return;
    for (final e in await store.all()) {
      if (e.ownerId != _me || !e.isShared || e.deleted) continue;
      try {
        await gateway.publishSharedEvent(e);
      } on GatewayException catch (err) {
        AppLog.w('sync', 'Resync abgebrochen (${err.error.name})');
        _backoff.failure();
        return;
      }
    }
  }

  // ----------------------------------------------------------------- Zusagen

  /// Speichert die eigene Zusage sofort lokal und sendet sie (mit Warteschlange).
  Future<void> respond(String eventId, RsvpStatus status) async {
    // Streng aufsteigende Zeitstempel: eine spätere Antwort ersetzt immer die frühere.
    var ts = _clock().toUtc();
    final last = _lastRsvpTs;
    if (last != null && !ts.isAfter(last)) ts = last.add(const Duration(milliseconds: 1));
    _lastRsvpTs = ts;
    // Zusagen nur für bekannte, geteilte Termine (privat gewordene Termine verlassen das Gerät nie).
    final target = await store.get(eventId);
    if (target == null || !target.isShared || target.deleted) return;
    await store.putRsvp(eventId, _me, status, ts, published: false);
    onChanged?.call();
    kick();
  }
}
