import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';
import 'recurrence.dart';
import 'time_zones.dart';

/// Ein konkretes Vorkommen eines Termins (bei Wiederholungen eines von vielen).
class Occurrence {
  const Occurrence({
    required this.event,
    required this.start,
    required this.end,
    required this.dateKey,
  });

  final CalendarEvent event;

  /// Zeitpunkt (UTC). Bei ganztägigen Terminen: Beginn des ersten Tages in der
  /// Zeitzone des Betrachters.
  final DateTime start;
  final DateTime end;

  /// Lokales Datum `yyyy-MM-dd` des Vorkommens in der Zeitzone des Termins
  /// (Schlüssel für Ausnahmen).
  final String dateKey;

  bool overlaps(DateTime from, DateTime to) => start.isBefore(to) && end.isAfter(from);
}

String dateKey(int y, int m, int d) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Berechnet Vorkommen. Wiederholungen laufen in der Zeitzone des Termins auf
/// Wanduhrzeit; über Sommerzeitwechsel bleibt die Uhrzeit gleich (E-20).
class OccurrenceExpander {
  const OccurrenceExpander._();

  /// Schutz gegen entartete Regeln (z. B. Intervall 1 über Jahrzehnte).
  static const int maxIterations = 20000;

  /// Vorkommen, die das Intervall [from, to) berühren, aufsteigend nach Beginn.
  /// [viewer]: Zeitzone des Betrachters für ganztägige Termine (Standard UTC).
  static List<Occurrence> expand(
    CalendarEvent e, {
    required DateTime from,
    required DateTime to,
    tz.Location? viewer,
  }) {
    if (e.deleted) return const <Occurrence>[];
    final viewerLoc = viewer ?? TimeZones.utc;
    final loc = TimeZones.tryGet(e.timeZone);
    if (loc == null) return const <Occurrence>[];
    final out = <Occurrence>[];

    final first = e.allDay
        ? DateTime.utc(e.start.year, e.start.month, e.start.day)
        : _localWall(e, loc);
    final r = e.recurrence;

    Occurrence build(DateTime wallDate, DateTime wallTime) {
      // wallDate: lokales Datum des Vorkommens; wallTime: Uhrzeit-Anteil.
      if (e.allDay) {
        final days = e.end.difference(e.start).inDays + 1;
        final s = tz.TZDateTime(viewerLoc, wallDate.year, wallDate.month, wallDate.day);
        final en = tz.TZDateTime(viewerLoc, wallDate.year, wallDate.month, wallDate.day + days);
        return Occurrence(
          event: e,
          start: s.toUtc(),
          end: en.toUtc(),
          dateKey: dateKey(wallDate.year, wallDate.month, wallDate.day),
        );
      }
      final s = tz.TZDateTime(loc, wallDate.year, wallDate.month, wallDate.day, wallTime.hour, wallTime.minute, wallTime.second);
      return Occurrence(
        event: e,
        start: s.toUtc(),
        end: s.toUtc().add(e.duration),
        dateKey: dateKey(wallDate.year, wallDate.month, wallDate.day),
      );
    }

    final startDate = DateTime.utc(first.year, first.month, first.day);

    if (!r.isRecurring) {
      final o = build(startDate, first);
      if (o.overlaps(from, to)) out.add(o);
      return out;
    }

    var produced = 0; // Anzahl der Vorkommen inkl. ausgenommener (für count)
    var iterations = 0;

    // Gibt true zurück, wenn die Aufzählung beendet werden soll.
    bool visit(DateTime date) {
      if (++iterations > maxIterations) return true;
      if (r.until != null && date.isAfter(r.until!)) return true;
      produced++;
      if (r.count != null && produced > r.count!) return true;
      final o = build(date, first);
      // Beginn liegt hinter dem Fenster; spätere Vorkommen ebenfalls.
      if (o.start.isAfter(to)) return true;
      if (!r.exdates.contains(o.dateKey) && o.overlaps(from, to)) out.add(o);
      return false;
    }

    // Ohne count dürfen frühe Vorkommen übersprungen werden (Ergebnis bleibt gleich);
    // so bleiben auch Jahrzehnte alte, endlose Regeln im Iterationslimit.
    final lower = DateTime.utc(from.year, from.month, from.day).subtract(Duration(days: e.duration.inDays + 3));
    int skip(int unitsBetween) => r.count != null ? 0 : (unitsBetween ~/ r.interval - 1).clamp(0, 1 << 30);

    switch (r.frequency) {
      case Frequency.none:
        break;
      case Frequency.daily:
        for (var k = skip(lower.difference(startDate).inDays);; k++) {
          if (visit(DateTime.utc(startDate.year, startDate.month, startDate.day + k * r.interval))) break;
        }
      case Frequency.weekly:
        final days = (r.weekdays.isEmpty ? <int>{startDate.weekday} : r.weekdays).toList()..sort();
        final weekStart = DateTime.utc(startDate.year, startDate.month, startDate.day - (startDate.weekday - 1));
        var done = false;
        for (var k = skip(lower.difference(weekStart).inDays ~/ 7); !done; k++) {
          for (final wd in days) {
            final date = DateTime.utc(weekStart.year, weekStart.month, weekStart.day + k * 7 * r.interval + (wd - 1));
            if (date.isBefore(startDate)) continue;
            if (visit(date)) {
              done = true;
              break;
            }
          }
        }
      case Frequency.monthly:
        final monthsBetween = (lower.year * 12 + lower.month) - (startDate.year * 12 + startDate.month);
        for (var k = skip(monthsBetween);; k++) {
          final total = startDate.year * 12 + (startDate.month - 1) + k * r.interval;
          final y = total ~/ 12;
          final m = total % 12 + 1;
          final d = startDate.day > daysInMonth(y, m) ? daysInMonth(y, m) : startDate.day;
          if (visit(DateTime.utc(y, m, d))) break;
        }
      case Frequency.yearly:
        for (var k = skip(lower.year - startDate.year);; k++) {
          final y = startDate.year + k * r.interval;
          final d = startDate.day > daysInMonth(y, startDate.month) ? daysInMonth(y, startDate.month) : startDate.day;
          if (visit(DateTime.utc(y, startDate.month, d))) break;
        }
    }
    return out;
  }

  /// Lokale Wanduhrzeit des Beginns in der Zeitzone des Termins (als UTC-Datum
  /// verpackt, nur Feldwerte zählen).
  static DateTime _localWall(CalendarEvent e, tz.Location loc) {
    final l = tz.TZDateTime.from(e.start, loc);
    return DateTime.utc(l.year, l.month, l.day, l.hour, l.minute, l.second);
  }
}
