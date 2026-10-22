import 'package:timezone/timezone.dart' as tz;

import 'occurrence.dart';

/// Wiederholungsintervall einer Aufgabenliste (E-51).
enum TaskInterval { daily, weekly, monthly }

/// Periodenschlüssel einer Aufgabenliste (E-51).
///
/// Der „Reset“ einer Liste ist kein Schreibvorgang: Eine Erledigung gilt nur, solange ihr
/// Schlüssel dem aktuellen Schlüssel entspricht. Der Schlüssel wird in der Zeitzone der Liste
/// gebildet, damit alle Geräte ohne Absprache dasselbe Ergebnis erhalten.
///
/// * täglich: `2026-10-22`
/// * wöchentlich: ISO-Woche (Montag bis Sonntag), `2026-W43`
/// * monatlich: `2026-10`
class TaskPeriod {
  const TaskPeriod._();

  static final RegExp _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Lokales Datum `yyyy-MM-dd` des Zeitpunkts [instant] in [loc].
  static String localDate(tz.Location loc, DateTime instant) {
    final t = tz.TZDateTime.from(instant.toUtc(), loc);
    return dateKey(t.year, t.month, t.day);
  }

  /// Zerlegt ein Datum `yyyy-MM-dd`; `null`, wenn es kein echtes Kalenderdatum ist.
  static ({int y, int m, int d})? parseDate(String s) {
    final m = _dateRe.firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (y < 2000 || y > 2100) return null;
    final back = DateTime.utc(y, mo, d);
    if (back.year != y || back.month != mo || back.day != d) return null;
    return (y: y, m: mo, d: d);
  }

  /// Schlüssel der Periode, in die das Datum [date] (`yyyy-MM-dd`) fällt; `null` bei ungültigem Datum.
  static String? keyForDate(TaskInterval interval, String date) {
    final p = parseDate(date);
    if (p == null) return null;
    switch (interval) {
      case TaskInterval.daily:
        return date;
      case TaskInterval.monthly:
        return date.substring(0, 7);
      case TaskInterval.weekly:
        final d = DateTime.utc(p.y, p.m, p.d);
        // ISO-8601: Die Woche gehört zu dem Jahr, in dem ihr Donnerstag liegt.
        final thursday = d.add(Duration(days: 4 - d.weekday));
        final week = (thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7) + 1;
        return '${thursday.year.toString().padLeft(4, '0')}-W${week.toString().padLeft(2, '0')}';
    }
  }

  /// Schlüssel der aktuellen Periode zum Zeitpunkt [instant] in [loc].
  static String key(TaskInterval interval, tz.Location loc, DateTime instant) =>
      keyForDate(interval, localDate(loc, instant))!;

  static final RegExp _keyRe = RegExp(r'^\d{4}-(\d{2}-\d{2}|W\d{2}|\d{2})$');

  /// Grobe Formatprüfung eines Schlüssels (ohne Bezug zu einer Liste).
  static bool isKey(String s) => s.length <= 10 && _keyRe.hasMatch(s);
}
