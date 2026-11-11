/// Fortschritt des laufenden Jahres (#337). Der heutige Tag zählt als Tag `dayOfYear` von `daysInYear`.
class YearProgress {
  YearProgress._(this.year, this.dayOfYear, this.daysInYear);

  /// [today]: Kalendertag (nur Jahr, Monat und Tag zählen).
  factory YearProgress.of(DateTime today) {
    final start = DateTime.utc(today.year);
    final next = DateTime.utc(today.year + 1);
    final day = DateTime.utc(today.year, today.month, today.day);
    return YearProgress._(today.year, day.difference(start).inDays + 1, next.difference(start).inDays);
  }

  final int year;

  /// 1 am 1. Januar, `daysInYear` am 31. Dezember.
  final int dayOfYear;
  final int daysInYear;

  /// Tage nach heute bis Jahresende.
  int get daysLeft => daysInYear - dayOfYear;

  /// Anteil 0..1 (heute mitgezählt).
  double get fraction => dayOfYear / daysInYear;

  /// Ganze Prozent, abgerundet: 100 erst am letzten Tag des Jahres.
  int get percent => (dayOfYear * 100) ~/ daysInYear;
}
