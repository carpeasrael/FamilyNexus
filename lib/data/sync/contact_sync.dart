import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;

import '../../core/app_log.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/chat.dart' show ThreadKind;
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

  /// Nimmt [ids] zurück (Entsperren eines Kontakts); Unbekanntes ändert nichts.
  Future<void> remove(Iterable<String> ids);
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

  /// Zähler, der nach jeder inhaltlichen Änderung (lokal, Abgleich, Empfang, Richtlinie, Blockierliste) steigt: Die
  /// Oberfläche hört darauf (K3b-1). Wird nie freigegeben, weil [start] wiederholbar ist.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bump() => revision.value++;

  /// Verworfene (ungültige) Ereignisse.
  int rejected = 0;

  StreamSubscription<CalendarSignal>? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _publishing = false;
  bool _again = false;
  bool _listening = false;
  bool _disposed = false;

  // Richtlinie fürs Gateway (K3a-1): ein einziger Lauf, Anstöße während des Laufs werden zusammengefasst; jeder Lauf liest
  // den **aktuellen** Bestand, ein älterer Aufbau kann so nie nach einem neueren im Gateway landen.
  bool _policyRunning = false;
  bool _policyAgain = false;
  Future<void> _policyDone = Future<void>.value();
  Set<String> _lastLocalBlocked = const <String>{};

  // Abgleich `outgoing` → `accepted` (K3a-2b): ein Lauf, Anstöße fassen zusammen.
  bool _reconciling = false;
  bool _reconcileAgain = false;
  Future<void> _reconcileDone = Future<void>.value();
  Object? _lastState;

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
  Future<void> idle() async {
    await _queue;
    await _policyDone;
    await _reconcileDone;
  }

  /// Rückruf des Dienstes bei jeder inhaltlichen Änderung: Richtlinie neu bauen und den Abgleich prüfen.
  void _onServiceChanged() {
    _schedulePolicy();
    _scheduleReconcile();
    _bump();
  }

  void _scheduleReconcile() {
    if (_disposed) return;
    if (_reconciling) {
      _reconcileAgain = true;
      return;
    }
    _reconciling = true;
    _reconcileDone = _reconcile();
  }

  /// Setzt `outgoing` auf `accepted`, sobald das Gegenüber **positiv beigetreten** ist (Kontakt-Thread ohne `pending`,
  /// K3a-2a): auch wenn die Gegenseite den Raum zuerst angelegt hat und wir ihn per Auto-Annahme betreten haben
  /// (gegenseitiges Hinzufügen). Ein lokal Blockierter wird nie `accepted`. Abgelehnt/verlassen ⇒ kein Thread ⇒ nie.
  Future<void> _reconcile() async {
    try {
      do {
        _reconcileAgain = false;
        if (_disposed) return;
        final outgoing = <Contact>[
          for (final c in await service.contacts())
            if (c.state == ContactState.outgoing) c,
        ];
        if (_disposed) return;
        final blocked = blockedList?.blocked ?? const <String>{};
        for (final c in outgoing) {
          if (blocked.contains(c.id)) continue;
          String? room;
          for (final t in gateway.threads) {
            if (t.kind == ThreadKind.contact && t.peerId == c.id && !t.pending) {
              room = t.id;
              break;
            }
          }
          if (room == null) continue;
          try {
            await service.markAccepted(c.id, room: room);
            if (_disposed) return;
            kick();
          } on ContactException {
            // Zwischenzeitlich geändert (entfernt, blockiert, schon bestätigt): der nächste Lauf entscheidet neu.
          }
        }
      } while (_reconcileAgain);
    } catch (e) {
      AppLog.e('contacts', 'Abgleich der Kontakte gescheitert', e);
    } finally {
      _reconciling = false;
    }
  }

  /// Plant den Aufbau der Richtlinie (läuft nie parallel; wirft nie).
  void _schedulePolicy() {
    if (_disposed) return;
    if (_policyRunning) {
      _policyAgain = true;
      return;
    }
    _policyRunning = true;
    _policyDone = _pushPolicy();
  }

  /// Schiebt die Richtlinie jetzt und wartet, bis der Lauf (samt zwischenzeitlich angemeldeter Anstöße) fertig ist. Der
  /// Controller ruft das nach `addAccepted`/`addOutgoing` auf, bevor er das Gateway braucht (Datensatz **vor** Raum).
  Future<void> pushPolicyNow() async {
    _schedulePolicy();
    await _policyDone;
  }

  Future<void> _pushPolicy() async {
    try {
      do {
        _policyAgain = false;
        final local = blockedList?.blocked ?? const <String>{};
        _lastLocalBlocked = <String>{...local};
        final policy = ContactPolicy.of(await store.all(), localBlocked: local);
        if (_disposed) break;
        gateway.setContactPolicy(policy);
        _scheduleReconcile();
        _bump();
      } while (_policyAgain);
    } catch (e) {
      AppLog.e('contacts', 'Kontaktrichtlinie konnte nicht aufgebaut werden', e);
    } finally {
      _policyRunning = false;
    }
  }

  void start() {
    _disposed = false;
    service.onChanged = _onServiceChanged;
    _sub ??= gateway.calendarSignals.listen(_enqueue);
    _timer ??= Timer.periodic(retryInterval, (_) => kick());
    _backoff.changed(_gatewayState());
    if (!_listening) {
      _listening = true; // start() darf mehrfach laufen: genau ein Zuhörer
      gateway.addListener(_onGatewayChanged);
    }
    reconcileBlocked().ignore();
    _schedulePolicy();
    _scheduleReconcile();
    kick();
  }

  Object _gatewayState() => (gateway.session, gateway.userId, gateway.server, gateway.initialSyncDone);

  /// Im Wartefenster nach einem Sendefehler löst eine Meldung des Gateways keinen neuen Versuch aus.
  void _onGatewayChanged() {
    final state = _gatewayState();
    // Sitzung, Konto oder lokale Blockierliste haben sich geändert: Richtlinie neu bauen (nach Abmelden setzt das Gateway
    // sie zurück; ein lokal Blockierter erreicht sie sonst erst mit der nächsten Datensatzänderung).
    final list = blockedList?.blocked ?? const <String>{};
    if (state != _lastState || list.length != _lastLocalBlocked.length || !list.containsAll(_lastLocalBlocked)) {
      _lastState = state;
      _schedulePolicy();
    }
    _scheduleReconcile();
    final changed = _backoff.changed(state);
    if (!changed && _backoff.blocked) return;
    kick();
  }

  void dispose() {
    _disposed = true;
    if (service.onChanged == _onServiceChanged) service.onChanged = null;
    try {
      gateway.setContactPolicy(ContactPolicy.off);
    } catch (e) {
      // Ein bereits zerstörtes Gateway nimmt nichts mehr an; das ist hier gewollt und ohne Folgen.
      AppLog.w('contacts', 'Richtlinie beim Beenden nicht zurückgesetzt ($e)');
    }
    _sub?.cancel().ignore();
    _timer?.cancel();
    _debounce?.cancel();
    if (_listening) {
      _listening = false;
      gateway.removeListener(_onGatewayChanged);
    }
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
      // Vorzustand vor dem Zusammenführen: nur die Löschmarke eines **blockierten** Kontakts gibt die lokale Liste frei.
      final prior = record is Contact ? await service.contact(record.id) : null;
      if (await service.applyIncoming(record)) {
        onChanged?.call();
        if (record is Contact && record.deleted && prior != null && !prior.deleted && prior.state == ContactState.blocked) {
          await forgetBlocked(record.id);
        }
        await reconcileBlocked();
      }
    } catch (e) {
      AppLog.e('contacts', 'Kontaktdatensatz konnte nicht verarbeitet werden', e);
    }
  }

  /// Trägt alle aktiven `blocked`-Datensätze in die lokale Blockierliste ein: nur hinzufügen (nie entfernen, die Liste
  /// kann auch lokal blockierte Mitglieder enthalten, E-48), nach Kennung sortiert, höchstens bis zur Obergrenze der Liste.
  /// Das stellt die bei einem Familienwechsel gelöschte Liste wieder her.
  Future<void> reconcileBlocked() => _blockedSerial(() async {
        final port = blockedList;
        if (port == null) return;
        try {
          // Die Datensätze werden **unmittelbar vor** dem Eintragen gelesen (und nur, was jetzt noch `blocked` ist, wird
          // eingetragen): ein vor dem Entsperren begonnener Lauf kann die Kennung nicht wieder eintragen.
          final contacts = await service.contacts();
          final current = port.blocked;
          final missing = <String>[
            for (final c in contacts)
              if (c.state == ContactState.blocked && !current.contains(c.id)) c.id,
          ]..sort();
          final room = BlockedUsers.maxEntries - current.length;
          if (missing.isEmpty || room <= 0) return;
          await port.add(missing.take(room));
          _bump();
        } catch (e) {
          AppLog.e('contacts', 'Blockierliste konnte nicht abgeglichen werden', e);
        }
      });

  // `reconcileBlocked` und `forgetBlocked` laufen nacheinander, in der Reihenfolge des Eintreffens.
  Future<void> _blockedQueue = Future<void>.value();

  Future<T> _blockedSerial<T>(Future<T> Function() op) {
    final next = _blockedQueue.then((_) => op());
    _blockedQueue = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  /// Ist die Kennung in der lokalen Blockierliste (E-48)?
  bool isLocallyBlocked(String id) => blockedList?.blocked.contains(id) ?? false;

  /// Nimmt die Kennung aus der lokalen Blockierliste (Entsperren eines Kontakts). Familienmitglieder bleiben blockiert
  /// (E-48: lokal blockierte Mitglieder gehören nicht zu den Kontakten). `true`, wenn die Kennung entfernt wurde.
  Future<bool> forgetBlocked(String id) => _blockedSerial(() async {
        final port = blockedList;
        if (port == null || !port.blocked.contains(id) || gateway.family?.member(id) != null) return false;
        try {
          await port.remove(<String>[id]);
        } catch (e) {
          AppLog.e('contacts', 'Blockierliste konnte nicht bereinigt werden', e);
          return false;
        }
        _schedulePolicy();
        _bump();
        return true;
      });

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
