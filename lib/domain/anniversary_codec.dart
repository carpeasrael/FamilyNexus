import 'anniversaries.dart';
import 'calendar_event.dart';
import 'server.dart';

/// Ereignisformat der Geburts- und Gedenktage: ein verschlüsseltes Raumereignis je Person im Familienraum (E-104).
///
/// Sicherheitsregeln: Alle Felder werden streng typgeprüft und über [AnniversaryPerson.validate] begrenzt; `by`
/// muss dem authentischen Absender des Matrix-Ereignisses entsprechen (kein Schreiben in fremdem Namen).
/// Eine Mitgliedsprüfung gibt es nicht: Vertrauensgrenze ist der verschlüsselte Familienraum (E-40).
class AnniversaryCodec {
  const AnniversaryCodec._();

  static const String type = 'de.inneso.familynexus.anniversary';
  static const int schema = 1;

  static int get _minMs => CalendarEvent.minDate.millisecondsSinceEpoch;
  static int get _maxMs => CalendarEvent.maxDate.millisecondsSinceEpoch;

  static Map<String, Object?> _encodeDate(AnniversaryDate d) =>
      <String, Object?>{'m': d.month, 'd': d.day, 'y': ?d.year};

  static Map<String, Object?> encode(AnniversaryPerson p) {
    final problems = p.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiger Eintrag: ${problems.join(',')}');
    return <String, Object?>{
      'v': schema,
      'id': p.id,
      'by': p.by,
      'version': p.version,
      'deleted': p.deleted,
      'name': p.name,
      if (p.birth != null) 'birth': _encodeDate(p.birth!),
      if (p.death != null) 'death': _encodeDate(p.death!),
      'ts': p.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Fehlender Schlüssel = ohne Datum; falscher Typ = Fehler (`bad`).
  static ({AnniversaryDate? date, bool bad}) _decodeDate(Object? raw, {required bool present}) {
    if (!present) return (date: null, bad: false);
    if (raw is! Map) return (date: null, bad: true);
    final m = raw['m'];
    final d = raw['d'];
    final hasYear = raw.containsKey('y');
    final y = raw['y'];
    if (m is! int || d is! int || (hasYear && y is! int)) return (date: null, bad: true);
    return (date: AnniversaryDate(month: m, day: d, year: hasYear ? y as int : null), bad: false);
  }

  /// `null` bei ungültigem Inhalt. `by` muss mit [sender] übereinstimmen.
  static AnniversaryPerson? decode(Map<String, Object?> c, {required String sender}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final id = c['id'];
    final by = c['by'];
    final version = c['version'];
    final deleted = c['deleted'];
    final name = c['name'];
    final ts = c['ts'];
    if (id is! String || by is! String || version is! int || deleted is! bool) return null;
    if (name is! String || ts is! int || by != sender) return null;
    if (ts < _minMs || ts > _maxMs) return null;
    if (name.length > AnniversaryPerson.maxName * 2) return null;
    final birth = _decodeDate(c['birth'], present: c.containsKey('birth'));
    final death = _decodeDate(c['death'], present: c.containsKey('death'));
    if (birth.bad || death.bad) return null;
    final person = AnniversaryPerson(
      id: id,
      name: name,
      birth: birth.date,
      death: death.date,
      deleted: deleted,
      version: version,
      by: by,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
    );
    return person.validate().isEmpty ? person : null;
  }
}
