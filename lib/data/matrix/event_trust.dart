import 'package:matrix/matrix.dart';

import '../../core/app_log.dart';

/// Kam das Ereignis verschlüsselt an?
///
/// Das SDK entschlüsselt nur `m.room.encrypted` und reicht Klartext unverändert in die Zeitleiste; der Typ eines
/// Ereignisses sagt also nichts über seine Herkunft. `originalSource` setzt nur die Entschlüsselung des SDK,
/// `MatrixEvent.fromJson` ignoriert das Feld, ein Server kann es nicht liefern. `event_id`, `transaction_id` und
/// der Sendestatus aus `unsigned` kennt oder setzt der Server dagegen selbst und taugen nicht als Beleg.
///
/// Das belegt Verschlüsselung, nicht die Herkunft der Sitzung (`docs/OFFEN.md`).
bool arrivedEncrypted(Event e) => e.originalSource?.type == EventTypes.Encrypted;

/// Menge von Kennungen mit Obergrenze: Ist sie voll, fällt die älteste heraus.
class BoundedIdSet {
  BoundedIdSet(this.max);

  final int max;
  final Set<String> _ids = <String>{}; // behält die Einfügereihenfolge

  /// `true`, wenn [id] neu ist.
  bool add(String id) {
    if (!_ids.add(id)) return false;
    if (_ids.length > max) _ids.remove(_ids.first);
    return true;
  }

  void remove(String id) => _ids.remove(id);

  void clear() => _ids.clear();
}

/// Ereignis, das nach dem Rennen „Sync-Echo vor Sendeantwort“ aussieht: Das SDK ersetzt dabei das entschlüsselte
/// Ereignis im Speicher durch das eigene Echo ohne `originalSource`, die Datenbank behält das richtige.
/// Zustandsereignisse sind immer Klartext und kommen dafür nicht in Frage.
bool isEchoCandidate(Event e, String me) =>
    e.senderId == me &&
    e.stateKey == null &&
    e.status == EventStatus.synced &&
    e.type != EventTypes.Encrypted &&
    e.originalSource == null &&
    !e.redacted;

/// Stellt in einer Zeitleiste das Ereignis wieder her, das das eigene Echo verdrängt hat. Entscheidend ist allein die
/// gespeicherte Quelle, keine vom Server fälschbare Angabe. Jede Kennung wird einmal nachgeschlagen.
class EchoRepair {
  EchoRepair({int maxChecked = 5000}) : _checked = BoundedIdSet(maxChecked);

  final BoundedIdSet _checked;

  /// Liefert `false`, sobald [isCurrent] nach einem Datenbankzugriff nicht mehr gilt; der Abgleich gibt dann auf.
  Future<bool> run(
    Timeline t, {
    required String me,
    required DatabaseApi database,
    required bool Function() isCurrent,
  }) async {
    for (final e in List<Event>.of(t.events)) {
      if (!isEchoCandidate(e, me) || !_checked.add(e.eventId)) continue;
      final Event? stored;
      try {
        stored = await database.getEventById(e.eventId, t.room);
      } catch (err) {
        _checked.remove(e.eventId);
        AppLog.e('gateway', 'Eigenes Ereignis nicht lesbar', err);
        if (!isCurrent()) return false;
        continue;
      }
      if (!isCurrent()) return false;
      if (stored == null || !arrivedEncrypted(stored)) continue;
      // Die Zeitleiste kann sich während des Lesens verschoben haben.
      final i = t.events.indexWhere((x) => x.eventId == e.eventId);
      if (i >= 0 && isEchoCandidate(t.events[i], me)) t.events[i] = stored;
    }
    return true;
  }

  void clear() => _checked.clear();
}
