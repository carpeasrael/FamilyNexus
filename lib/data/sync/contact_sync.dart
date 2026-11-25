import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/app_log.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/contact_service.dart';
import '../../domain/contact_store.dart';
import '../../domain/contacts.dart';
import '../../domain/moderation.dart';
import '../matrix/matrix_gateway.dart';
import 'send_backoff.dart';

/// Port zur lokalen Blockierliste (`AppSettings.blockedUsers`, E-48): Der Adapter entsteht in `bootstrap.dart`.
abstract class BlockedListPort {
  Set<String> get blocked;

  /// Trägt [ids] ein (Dubletten ignorieren; die Liste kennt eine Obergrenze).
  Future<void> add(Iterable<String> ids);
}

/// Verbindet die Kontaktliste mit dem **privaten** Raum des Kontos (#119, K2c, E-114), nach dem Muster von
/// `AnniversarySync`, aber **ohne Familienbindung**: Kontakte gehören zum Konto, nicht zur Familie (Konzept §10); sie
/// überstehen einen Familienwechsel und funktionieren auch ohne Familie.
///
/// * eingehend: nur [ContactSignal] (das Gateway lässt sie nur aus dem privaten Raum und vom eigenen Konto zu); streng
///   prüfen ([ContactCodec.decode] mit Absender == eigenes Konto), per [ContactService] zusammenführen;
/// * ausgehend: noch nicht gesendete eigene Datensätze, bei altem Zeitstempel zuvor neu gestempelt;
/// * Blockierliste: aktive `blocked`-Datensätze werden in die lokale Liste eingetragen (nur hinzufügen).
class ContactSync {
  ContactSync({
    required this.gateway,
    required this.service,
    required this.store,
    this.blockedList,
    this.retryInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
    Duration backoffBase = const Duration(seconds: 5),
    Duration backoffMax = const Duration(seconds: 60),
  }) : _backoff = SendBackoff(clock: clock, base: backoffBase, max: backoffMax);

  final MatrixGateway gateway;
  final ContactService service;
  final ContactStore store;
  final BlockedListPort? blockedList;
  final Duration retryInterval;
  final SendBackoff _backoff;

  /// Wird nach jeder Änderung des lokalen Bestands aufgerufen.
  void Function()? onChanged;

  /// Verworfene (ungültige) Ereignisse.
  int rejected = 0;

  StreamSubscription<CalendarSignal>? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _publishing = false;
  bool _again = false;

  String get _me => service.myUserId;

  @visibleForTesting
  SendBackoff get backoff => _backoff;

  Future<void> _queue = Future<void>.value();

  void _enqueue(CalendarSignal s) {
    _queue = _queue.then((_) => _onSignal(s)).catchError((Object e) {
      AppLog.e('contacts', 'Signal konnte nicht verarbeitet werden', e);
    });
  }

  /// Wartet, bis alle bisher eingegangenen Signale verarbeitet sind (Schließen, Tests).
  Future<void> idle() => _queue;

  void start() {
    _sub ??= gateway.calendarSignals.listen(_enqueue);
    _timer ??= Timer.periodic(retryInterval, (_) => kick());
    _backoff.changed(_gatewayState());
    gateway.addListener(_onGatewayChanged);
    reconcileBlocked().ignore();
    kick();
  }

  Object _gatewayState() => (gateway.session, gateway.userId, gateway.server, gateway.initialSyncDone);

  /// Im Wartefenster nach einem Sendefehler löst eine Meldung des Gateways keinen neuen Versuch aus.
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

  /// Merkt alle eigenen (nicht gelöschten) Datensätze erneut zum Senden vor (Resync, z. B. für ein neues Gerät).
  Future<void> resync() async {
    await store.requeueAll();
    kick();
  }

  /// Nur für Tests: verarbeitet ein Signal unmittelbar (ohne Gateway-Strom).
  @visibleForTesting
  Future<void> debugDeliver(CalendarSignal s) => _onSignal(s);

  Future<void> _onSignal(CalendarSignal s) async {
    if (s is! ContactSignal) return;
    try {
      final record = ContactCodec.decode(s.content, sender: s.sender, me: _me, serverTime: s.timestamp);
      if (record == null) {
        rejected++;
        AppLog.w('contacts', 'Ungültiger Kontaktdatensatz verworfen');
        return;
      }
      if (await service.applyIncoming(record)) {
        onChanged?.call();
        await reconcileBlocked();
      }
    } catch (e) {
      AppLog.e('contacts', 'Kontaktdatensatz konnte nicht verarbeitet werden', e);
    }
  }

  /// Trägt alle aktiven `blocked`-Datensätze in die lokale Blockierliste ein: nur hinzufügen (nie entfernen, die Liste
  /// kann auch lokal blockierte Mitglieder enthalten, E-48), nach Kennung sortiert, höchstens bis zur Obergrenze der Liste.
  /// Das stellt die bei einem Familienwechsel gelöschte Liste wieder her.
  Future<void> reconcileBlocked() async {
    final port = blockedList;
    if (port == null) return;
    try {
      final current = port.blocked;
      final missing = <String>[
        for (final c in await service.contacts())
          if (c.state == ContactState.blocked && !current.contains(c.id)) c.id,
      ]..sort();
      final room = BlockedUsers.maxEntries - current.length;
      if (missing.isEmpty || room <= 0) return;
      await port.add(missing.take(room));
    } catch (e) {
      AppLog.e('contacts', 'Blockierliste konnte nicht abgeglichen werden', e);
    }
  }

  bool get _canPublish => gateway.session == SessionState.ready && gateway.initialSyncDone;

  /// Sendet alle noch nicht gesendeten eigenen Datensätze. Läuft nie parallel. Unerwartete Fehler werden protokolliert
  /// und zählen als Fehlversuch.
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
        final records = await store.pending()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        for (final r in records) {
          if (!_canPublish) return;
          try {
            // Ein lange wartender Datensatz würde beim Empfänger wegen des Zeitstempels verworfen: neu stempeln.
            final fresh = await service.restamp(r.kind, r.id, expectedVersion: r.version, expectedDeleted: r.deleted);
            if (fresh == null) continue; // zwischenzeitlich geändert: der nächste Durchlauf nimmt den neuen Stand
            await gateway.publishContactRecord(fresh);
            await store.markPublished(fresh.kind, fresh.id, fresh.version);
          } on GatewayException catch (err) {
            if (err.error == GatewayError.invalidInput) {
              AppLog.w('contacts', 'Datensatz nicht sendbar, Warteschlange bereinigt');
              await store.markPublished(r.kind, r.id, r.version);
              continue;
            }
            AppLog.w('contacts', 'Senden verschoben (${err.error.name})');
            _backoff.failure();
            return;
          }
        }
        _backoff.success();
      } while (_again);
    } catch (e) {
      AppLog.e('contacts', 'Sendedurchlauf gescheitert', e);
      _backoff.failure();
    } finally {
      _publishing = false;
    }
  }
}
