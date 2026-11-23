import 'cash_book.dart';

/// Ein Kalendermonat der Buchansicht (#311, E-113).
class CashMonth {
  const CashMonth(this.year, this.month) : assert(month >= 1 && month <= 12);

  final int year;
  final int month;

  /// Der Monat des Tages [day] (nur Jahr und Monat zählen).
  factory CashMonth.of(DateTime day) => CashMonth(day.year, day.month);

  CashMonth get previous => month == 1 ? CashMonth(year - 1, 12) : CashMonth(year, month - 1);
  CashMonth get next => month == 12 ? CashMonth(year + 1, 1) : CashMonth(year, month + 1);

  /// Liegt der Tag [day] (als UTC-Kalendertag) in diesem Monat?
  bool contains(DateTime day) => day.year == year && day.month == month;

  /// Nicht gelöschte Einträge des Monats: Datum absteigend, dann Zeitstempel absteigend, dann `id` (feste Reihenfolge).
  List<CashEntry> entriesOf(Iterable<CashEntry> entries) {
    final list = <CashEntry>[
      for (final e in entries)
        if (!e.deleted && contains(e.date)) e,
    ];
    list.sort((a, b) {
      final d = b.date.compareTo(a.date);
      if (d != 0) return d;
      final u = b.updatedAt.compareTo(a.updatedAt);
      return u != 0 ? u : a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  bool operator ==(Object other) => other is CashMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
