/// Wiederholungsart (Concept: täglich, wöchentlich, monatlich, jährlich).
enum Frequency { none, daily, weekly, monthly, yearly }

/// Wiederholungsregel mit Ausnahmen.
///
/// * [interval]: jede n-te Einheit (≥ 1).
/// * [weekdays]: nur bei wöchentlich; 1 = Montag … 7 = Sonntag. Leer = Wochentag des Beginns.
/// * [count] und [until] schließen sich aus; ohne beides endlos.
/// * [exdates]: ausgenommene Vorkommen als lokales Datum `yyyy-MM-dd` in der
///   Zeitzone des Termins. Ausgenommene Vorkommen zählen für [count] mit.
class Recurrence {
  const Recurrence({
    this.frequency = Frequency.none,
    this.interval = 1,
    this.weekdays = const <int>{},
    this.count,
    this.until,
    this.exdates = const <String>{},
  });

  static const Recurrence none = Recurrence();

  static const int maxInterval = 366;
  static const int maxCount = 5000;
  static const int maxExdates = 1000;

  final Frequency frequency;
  final int interval;
  final Set<int> weekdays;
  final int? count;

  /// Letztes lokales Datum (inklusive), als UTC-Mitternacht.
  final DateTime? until;
  final Set<String> exdates;

  bool get isRecurring => frequency != Frequency.none;

  static final RegExp _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static bool isDateKey(String s) {
    if (!_dateRe.hasMatch(s)) return false;
    final y = int.parse(s.substring(0, 4));
    final m = int.parse(s.substring(5, 7));
    final d = int.parse(s.substring(8, 10));
    if (m < 1 || m > 12 || d < 1 || d > 31) return false;
    final probe = DateTime.utc(y, m, d);
    return probe.month == m && probe.day == d;
  }

  /// Gibt eine Liste von Problemen zurück; leer = gültig.
  List<String> validate() {
    final problems = <String>[];
    if (interval < 1 || interval > maxInterval) problems.add('interval');
    if (weekdays.any((d) => d < 1 || d > 7)) problems.add('weekdays');
    if (weekdays.isNotEmpty && frequency != Frequency.weekly) problems.add('weekdays-not-weekly');
    if (count != null && until != null) problems.add('count-and-until');
    if (count != null && (count! < 1 || count! > maxCount)) problems.add('count');
    if (until != null && (until!.hour != 0 || until!.minute != 0 || !until!.isUtc)) problems.add('until');
    if (exdates.length > maxExdates || exdates.any((e) => !isDateKey(e))) problems.add('exdates');
    if (frequency == Frequency.none && (count != null || until != null || exdates.isNotEmpty)) {
      problems.add('none-with-details');
    }
    return problems;
  }

  Recurrence copyWith({
    Frequency? frequency,
    int? interval,
    Set<int>? weekdays,
    Object? count = _unset,
    Object? until = _unset,
    Set<String>? exdates,
  }) =>
      Recurrence(
        frequency: frequency ?? this.frequency,
        interval: interval ?? this.interval,
        weekdays: weekdays ?? this.weekdays,
        count: identical(count, _unset) ? this.count : count as int?,
        until: identical(until, _unset) ? this.until : until as DateTime?,
        exdates: exdates ?? this.exdates,
      );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      other.frequency == frequency &&
      other.interval == interval &&
      _setEq(other.weekdays, weekdays) &&
      other.count == count &&
      other.until == until &&
      _setEq(other.exdates, exdates);

  @override
  int get hashCode => Object.hash(frequency, interval, Object.hashAllUnordered(weekdays), count, until, Object.hashAllUnordered(exdates));

  static bool _setEq<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);
}
