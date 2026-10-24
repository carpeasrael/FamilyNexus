import 'package:timezone/timezone.dart' as tz;

import 'occurrence.dart';
import 'task_period.dart';

/// Art der Wiederholung einer Aufgabenliste (E-58, Issue #1).
enum TaskRepeat {
  /// Jeden Tag, auch am Wochenende.
  everyDay,

  /// Montag bis Freitag; am Wochenende wird nicht erneuert.
  weekdays,

  /// Einmal pro Woche am gewählten Wochentag.
  weekly,

  /// Einmal pro Monat am n-ten (oder letzten) gewählten Wochentag, z. B. „zweiter Dienstag“.
  monthlyByWeekday,

  /// Einmal pro Monat am gewählten Kalendertag; gibt es ihn nicht, am letzten Tag des Monats.
  monthlyByDate,
}

/// Wiederholungsregel einer Aufgabenliste: An welchen Tagen beginnt eine neue Periode? (E-58)
///
/// Wie bisher (E-51) ist der „Reset“ kein Schreibvorgang: Jede Erledigung trägt den Schlüssel ihrer
/// Periode, und alle Geräte berechnen ihn ohne Absprache gleich. Der Schlüssel ist das **Startdatum**
/// der Periode (`yyyy-MM-dd`, letzter Erneuerungstag ≤ heute in der Zeitzone der Liste).
///
/// Regeln, die den bisherigen Intervallen entsprechen (täglich, wöchentlich ab Montag, monatlich ab dem
/// 1.), behalten deren Schlüssel (`2026-10-22`, `2026-W43`, `2026-10`) und das Ereignisformat v1, damit
/// bestehende Listen und Verläufe unverändert gelten ([isLegacy]).
class TaskRule {
  const TaskRule._(this.kind, {this.weekday, this.ordinal, this.day});

  const TaskRule.everyDay() : this._(TaskRepeat.everyDay);
  const TaskRule.weekdays() : this._(TaskRepeat.weekdays);

  /// [weekday]: 1 = Montag … 7 = Sonntag.
  const TaskRule.weekly(int weekday) : this._(TaskRepeat.weekly, weekday: weekday);

  /// [ordinal]: 1–4 oder [last]; [weekday]: 1 = Montag … 7 = Sonntag.
  const TaskRule.monthlyByWeekday(int ordinal, int weekday)
      : this._(TaskRepeat.monthlyByWeekday, ordinal: ordinal, weekday: weekday);

  /// [day]: 1–31.
  const TaskRule.monthlyByDate(int day) : this._(TaskRepeat.monthlyByDate, day: day);

  /// Position „letzter“ (z. B. letzter Freitag des Monats).
  static const int last = 5;

  final TaskRepeat kind;
  final int? weekday;
  final int? ordinal;
  final int? day;

  /// Regel, die einem bisherigen Intervall entspricht.
  static TaskRule fromInterval(TaskInterval i) => switch (i) {
        TaskInterval.daily => const TaskRule.everyDay(),
        TaskInterval.weekly => const TaskRule.weekly(DateTime.monday),
        TaskInterval.monthly => const TaskRule.monthlyByDate(1),
      };

  /// Grobe Einordnung (für Anzeige und das Feld `interval` im Ereignis).
  TaskInterval get interval => switch (kind) {
        TaskRepeat.everyDay || TaskRepeat.weekdays => TaskInterval.daily,
        TaskRepeat.weekly => TaskInterval.weekly,
        TaskRepeat.monthlyByWeekday || TaskRepeat.monthlyByDate => TaskInterval.monthly,
      };

  /// Entspricht einem bisherigen Intervall (gleiche Schlüssel, Ereignisformat v1).
  bool get isLegacy => switch (kind) {
        TaskRepeat.everyDay => true,
        TaskRepeat.weekly => weekday == DateTime.monday,
        TaskRepeat.monthlyByDate => day == 1,
        _ => false,
      };

  bool get isValid => switch (kind) {
        TaskRepeat.everyDay || TaskRepeat.weekdays => weekday == null && ordinal == null && day == null,
        TaskRepeat.weekly => _isWeekday(weekday) && ordinal == null && day == null,
        TaskRepeat.monthlyByWeekday => _isWeekday(weekday) && ordinal != null && ordinal! >= 1 && ordinal! <= last && day == null,
        TaskRepeat.monthlyByDate => day != null && day! >= 1 && day! <= 31 && weekday == null && ordinal == null,
      };

  static bool _isWeekday(int? w) => w != null && w >= DateTime.monday && w <= DateTime.sunday;

  /// Längste mögliche Periode in Tagen (Prüfung empfangener Einträge): monatlich nach Wochentag bis 35.
  static const int maxPeriodDays = 35;

  /// Schlüssel der Periode, in die das Datum [date] (`yyyy-MM-dd`) fällt; `null` bei ungültigem Datum.
  String? keyForDate(String date) {
    if (isLegacy) return TaskPeriod.keyForDate(interval, date);
    final p = TaskPeriod.parseDate(date);
    if (p == null || !isValid) return null;
    final start = startOf(DateTime.utc(p.y, p.m, p.d));
    return dateKey(start.year, start.month, start.day);
  }

  /// Schlüssel der aktuellen Periode zum Zeitpunkt [instant] in [loc].
  String key(tz.Location loc, DateTime instant) => keyForDate(TaskPeriod.localDate(loc, instant))!;

  /// Beginn der Periode, in die der Tag [d] (UTC-Mitternacht) fällt: letzter Erneuerungstag ≤ [d].
  DateTime startOf(DateTime d) {
    switch (kind) {
      case TaskRepeat.everyDay:
        return d;
      case TaskRepeat.weekdays:
        // Samstag und Sonntag gehören zur Periode vom Freitag.
        return d.weekday >= DateTime.saturday ? d.subtract(Duration(days: d.weekday - DateTime.friday)) : d;
      case TaskRepeat.weekly:
        return d.subtract(Duration(days: (d.weekday - weekday! + 7) % 7));
      case TaskRepeat.monthlyByDate:
        final here = _dateIn(d.year, d.month);
        if (!d.isBefore(here)) return here;
        return _dateIn(d.year, d.month - 1);
      case TaskRepeat.monthlyByWeekday:
        final here = _nthIn(d.year, d.month);
        if (!d.isBefore(here)) return here;
        return _nthIn(d.year, d.month - 1);
    }
  }

  /// Nächster Erneuerungstag nach dem Tag [d] (für die Anzeige „Neu ab …“).
  DateTime nextStartAfter(DateTime d) {
    var probe = d.add(const Duration(days: 1));
    // Höchstens eine Periodenlänge plus Puffer suchen.
    for (var i = 0; i <= maxPeriodDays + 1; i++) {
      if (startOf(probe) == probe) return probe;
      probe = probe.add(const Duration(days: 1));
    }
    return probe;
  }

  static int _daysIn(int y, int m) => DateTime.utc(y, m + 1, 0).day;

  /// Kalendertag [day] im Monat; gibt es ihn nicht, der letzte Tag (Issue #1, bevorzugte Variante).
  DateTime _dateIn(int y, int m) {
    final first = DateTime.utc(y, m);
    final dd = day!.clamp(1, _daysIn(first.year, first.month));
    return DateTime.utc(first.year, first.month, dd);
  }

  /// n-ter bzw. letzter [weekday] im Monat.
  DateTime _nthIn(int y, int m) {
    final first = DateTime.utc(y, m);
    if (ordinal == last) {
      final lastDay = DateTime.utc(first.year, first.month, _daysIn(first.year, first.month));
      return lastDay.subtract(Duration(days: (lastDay.weekday - weekday! + 7) % 7));
    }
    final firstMatch = first.add(Duration(days: (weekday! - first.weekday + 7) % 7));
    return firstMatch.add(Duration(days: 7 * (ordinal! - 1)));
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        'weekday': ?weekday,
        'ordinal': ?ordinal,
        'day': ?day,
      };

  /// `null` bei ungültigem Inhalt (empfangene Daten sind nicht vertrauenswürdig).
  static TaskRule? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    if (raw.keys.any((k) => !const <String>{'kind', 'weekday', 'ordinal', 'day'}.contains(k))) return null;
    final kind = TaskRepeat.values.where((k) => k.name == raw['kind']);
    final w = raw['weekday'];
    final o = raw['ordinal'];
    final d = raw['day'];
    if (kind.isEmpty || (w != null && w is! int) || (o != null && o is! int) || (d != null && d is! int)) return null;
    final rule = TaskRule._(kind.first, weekday: w as int?, ordinal: o as int?, day: d as int?);
    return rule.isValid ? rule : null;
  }

  @override
  bool operator ==(Object other) =>
      other is TaskRule && other.kind == kind && other.weekday == weekday && other.ordinal == ordinal && other.day == day;

  @override
  int get hashCode => Object.hash(kind, weekday, ordinal, day);

  @override
  String toString() => 'TaskRule(${kind.name}, w=$weekday, o=$ordinal, d=$day)';
}
