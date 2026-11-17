import 'calendar_event.dart';
import 'server.dart';
import 'task_models.dart' show hasBadTitleText, isBlankTitleText;

/// Ein Kalendertag mit optionalem Jahr (Geburts- oder Todesdatum, E-104). Ohne Jahr wiederholt er sich nur
/// als Tag und Monat; Altersangaben gibt es dann nicht.
class AnniversaryDate {
  const AnniversaryDate({required this.month, required this.day, this.year});

  /// Grenzen des Jahres beim Empfang (tolerant); beim Anlegen und Ändern gilt zusätzlich „nicht in der Zukunft“.
  /// Die Untergrenze ist bewusst unabhängig von `CalendarEvent.minDate` (2000): Dieses begrenzt nur Zeitstempel
  /// und Termine, nicht Lebensdaten.
  static const int minYear = 1000;
  static int get maxYear => CalendarEvent.maxDate.year;

  final int month;
  final int day;
  final int? year;

  static bool isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// Tage des Monats; ohne Jahr gilt ein Schaltjahr (der 29.2. ist erlaubt).
  static int daysInMonth(int month, int? year) {
    switch (month) {
      case 2:
        return year == null || isLeap(year) ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  /// Aufbau gültig: Monat 1–12, Tag passend zum Monat (mit Jahr nach dem gregorianischen Kalender),
  /// Jahr (falls angegeben) in [minYear], [maxYear].
  bool get isValid {
    if (month < 1 || month > 12) return false;
    final y = year;
    if (y != null && (y < minYear || y > maxYear)) return false;
    return day >= 1 && day <= daysInMonth(month, y);
  }

  /// `true`, wenn das volle Datum (Jahr angegeben) nach [today] liegt.
  bool isAfter(DateTime today) {
    final y = year;
    if (y == null) return false;
    if (y != today.year) return y > today.year;
    if (month != today.month) return month > today.month;
    return day > today.day;
  }

  @override
  bool operator ==(Object other) => other is AnniversaryDate && other.month == month && other.day == day && other.year == year;

  @override
  int get hashCode => Object.hash(month, day, year);

  @override
  String toString() => 'AnniversaryDate($day.$month.${year ?? '-'})';
}

/// Eine Person der Geburts- und Gedenktage der Familie (E-104): freier Name, optional Geburts- und Todesdatum.
///
/// Ein Datensatz je Person mit eigener Version und Löschmarke; gleichzeitige Änderungen konvergieren über
/// [AnniversaryMerge]. Jedes beigetretene Mitglied darf ändern und löschen (wie der Einkaufszettel, E-40).
class AnniversaryPerson {
  AnniversaryPerson({
    required this.id,
    required this.name,
    required this.by,
    required this.updatedAt,
    this.birth,
    this.death,
    this.version = 1,
    this.deleted = false,
  });

  static const int maxName = 60;

  /// Höchstzahl aktiver Personen und aller Datensätze (inkl. Löschmarken), Speicherschutz.
  static const int maxActive = 200;
  static const int maxTotal = 300;
  static const int keepTombstones = 20;

  static const int maxVersion = 1000000;
  static const int maxFirstVersion = 10000;
  static const int maxVersionJump = 1000;

  final String id;
  final String name;
  final AnniversaryDate? birth;
  final AnniversaryDate? death;
  final int version;
  final bool deleted;

  /// Letzter Bearbeiter (Matrix-ID); beim Empfang muss er dem authentischen Absender entsprechen.
  final String by;
  final DateTime updatedAt;

  List<String> validate() {
    final p = <String>[];
    if (!CalendarEvent.isValidId(id)) p.add('id');
    if (!MatrixIds.isUserId(by)) p.add('by');
    if (version < 1 || version > maxVersion) p.add('version');
    if (!updatedAt.isUtc || updatedAt.isBefore(CalendarEvent.minDate) || updatedAt.isAfter(CalendarEvent.maxDate)) p.add('time');
    if (name.runes.length > maxName || hasBadTitleText(name)) p.add('name');
    if (deleted) {
      if (name.isNotEmpty) p.add('tombstone');
      if (birth != null || death != null) p.add('tombstone');
      return p;
    }
    if (isBlankTitleText(name)) p.add('name');
    final b = birth;
    final d = death;
    if (b == null && d == null) p.add('dates');
    if (b != null && !b.isValid) p.add('birth');
    if (d != null && !d.isValid) p.add('death');
    if (b != null && d != null && b.isValid && d.isValid) {
      final by0 = b.year;
      final dy = d.year;
      if (by0 != null && dy != null) {
        if (dy < by0) {
          p.add('order');
        } else if (dy == by0 && (d.month < b.month || (d.month == b.month && d.day < b.day))) {
          p.add('order');
        }
      }
    }
    return p;
  }

  AnniversaryPerson copyWith({
    String? name,
    Object? birth = _unset,
    Object? death = _unset,
    bool? deleted,
    int? version,
    String? by,
    DateTime? updatedAt,
  }) =>
      AnniversaryPerson(
        id: id,
        name: name ?? this.name,
        birth: identical(birth, _unset) ? this.birth : birth as AnniversaryDate?,
        death: identical(death, _unset) ? this.death : death as AnniversaryDate?,
        deleted: deleted ?? this.deleted,
        version: version ?? this.version,
        by: by ?? this.by,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is AnniversaryPerson &&
      other.id == id &&
      other.name == name &&
      other.birth == birth &&
      other.death == death &&
      other.deleted == deleted &&
      other.version == version &&
      other.by == by &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, birth, death, deleted, version, by, updatedAt);
}

/// Konfliktregel (wie E-40/E-51/E-99): höhere Version, dann Zeit, dann Absender-ID.
class AnniversaryMerge {
  const AnniversaryMerge._();

  static bool incomingWins(AnniversaryPerson? current, AnniversaryPerson incoming) {
    if (current == null) return true;
    if (incoming.version != current.version) return incoming.version > current.version;
    final byTime = incoming.updatedAt.compareTo(current.updatedAt);
    if (byTime != 0) return byTime > 0;
    final byAuthor = incoming.by.compareTo(current.by);
    if (byAuthor != 0) return byAuthor > 0;
    return _tie(incoming).compareTo(_tie(current)) > 0;
  }

  static String _tie(AnniversaryPerson p) => '${p.deleted}|${p.name}|${p.birth}|${p.death}';
}
