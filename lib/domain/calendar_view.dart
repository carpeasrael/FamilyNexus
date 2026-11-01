import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';
import 'occurrence.dart';

/// Reine Hilfsfunktionen für Kalenderansichten (Tag/Woche/Monat/Agenda).
/// Alle Tage sind lokale Kalendertage in der Zeitzone des Betrachters.
class CalendarView {
  const CalendarView._();

  /// Beginn des lokalen Tages von [day] (nur Jahr/Monat/Tag zählen).
  static tz.TZDateTime startOfDay(tz.Location loc, DateTime day) => tz.TZDateTime(loc, day.year, day.month, day.day);

  static tz.TZDateTime endOfDay(tz.Location loc, DateTime day) => tz.TZDateTime(loc, day.year, day.month, day.day + 1);

  /// Montag der Woche, die [day] enthält (als reines Datum in UTC).
  static DateTime weekStart(DateTime day) => DateTime.utc(day.year, day.month, day.day - (day.weekday - 1));

  static List<DateTime> weekDays(DateTime day) {
    final s = weekStart(day);
    return <DateTime>[for (var i = 0; i < 7; i++) DateTime.utc(s.year, s.month, s.day + i)];
  }

  /// 6 × 7 Tage (Montag zuerst) für den Monat von [month]; Tage außerhalb des
  /// Monats gehören zu den Nachbarmonaten.
  static List<DateTime> monthGrid(DateTime month) {
    final first = DateTime.utc(month.year, month.month);
    final s = weekStart(first);
    return <DateTime>[for (var i = 0; i < 42; i++) DateTime.utc(s.year, s.month, s.day + i)];
  }

  static DateTime addMonths(DateTime d, int n) {
    final total = d.year * 12 + (d.month - 1) + n;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = daysInMonth(y, m);
    return DateTime.utc(y, m, d.day > last ? last : d.day);
  }

  /// Vorkommen, die den lokalen Tag [day] berühren, sortiert: ganztägige zuerst,
  /// dann nach Beginn.
  static List<Occurrence> forDay(
    Iterable<Occurrence> all,
    tz.Location loc,
    DateTime day,
  ) {
    final from = startOfDay(loc, day).toUtc();
    final to = endOfDay(loc, day).toUtc();
    final out = all.where((o) => o.overlaps(from, to)).toList()..sort(compareInDay);
    return out;
  }

  /// Innerhalb eines Tages: ganztägige zuerst, dann nach Beginn.
  static int compareInDay(Occurrence a, Occurrence b) {
    if (a.event.allDay != b.event.allDay) return a.event.allDay ? -1 : 1;
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : a.event.title.compareTo(b.event.title);
  }

  /// Über mehrere Tage (z. B. „Nächste Termine“): nach Beginn. Ganztägige Termine beginnen um
  /// Mitternacht und stehen so am Anfang ihres Tages, nie vor Terminen früherer Tage (#33).
  static int compare(Occurrence a, Occurrence b) {
    final c = a.start.compareTo(b.start);
    if (c != 0) return c;
    if (a.event.allDay != b.event.allDay) return a.event.allDay ? -1 : 1;
    return a.event.title.compareTo(b.event.title);
  }

  /// Gruppiert [occurrences] nach lokalem Starttag (für die Agenda). Mehrtägige
  /// Termine erscheinen an jedem Tag, den sie berühren, im Bereich [from]–[to).
  static Map<DateTime, List<Occurrence>> groupByDay(
    List<Occurrence> occurrences,
    tz.Location loc,
    DateTime from,
    DateTime to,
  ) {
    final out = <DateTime, List<Occurrence>>{};
    final firstDay = tz.TZDateTime.from(from, loc);
    final lastDay = tz.TZDateTime.from(to, loc);
    var d = DateTime.utc(firstDay.year, firstDay.month, firstDay.day);
    final end = DateTime.utc(lastDay.year, lastDay.month, lastDay.day);
    while (!d.isAfter(end)) {
      final list = forDay(occurrences, loc, d);
      if (list.isNotEmpty) out[d] = list;
      d = DateTime.utc(d.year, d.month, d.day + 1);
    }
    return out;
  }

  /// Die wirksame Personenauswahl (#155): Ohne Filterleiste (weniger als zwei beigetretene Mitglieder) kann
  /// niemand filtern, also gilt keine Auswahl; sonst nur Personen, die noch beigetreten sind. Die gewählte
  /// Menge bleibt unverändert, tritt jemand wieder bei, gilt seine Auswahl wieder.
  static Set<String> activePersons(Set<String> selected, Iterable<String> joinedIds) {
    final joined = joinedIds.toSet();
    if (joined.length < 2) return <String>{};
    return selected.intersection(joined);
  }

  /// Ob ein Termin zur Personenauswahl passt (Besitzer oder Teilnehmer).
  static bool matchesPerson(CalendarEvent e, Set<String> persons) =>
      persons.isEmpty || persons.contains(e.ownerId) || e.attendees.any(persons.contains);
}
