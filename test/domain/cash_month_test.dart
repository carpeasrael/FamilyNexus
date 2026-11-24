import 'package:family_nexus/domain/cash_month.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';

/// #311, E-113 (Teil 4): Monat der Buchansicht.
void main() {
  test('vorheriger und nächster Monat, Jahreswechsel', () {
    expect(const CashMonth(2026, 1).previous, const CashMonth(2025, 12));
    expect(const CashMonth(2026, 12).next, const CashMonth(2027, 1));
    expect(const CashMonth(2026, 5).previous, const CashMonth(2026, 4));
    expect(const CashMonth(2026, 5).next, const CashMonth(2026, 6));
  });

  test('Monate sind nur bei gleichem Jahr und Monat gleich', () {
    expect(const CashMonth(2026, 1) == const CashMonth(2026, 2), isFalse);
    expect(const CashMonth(2026, 1) == const CashMonth(2027, 1), isFalse);
    expect(const CashMonth(2026, 1) == const CashMonth(2026, 1), isTrue);
  });

  test('gleiches Datum und gleicher Zeitstempel: die Reihenfolge entscheidet die id, unabhängig von der Eingabe', () {
    final a = cashEntry(id: '00000000-0000-4000-8000-00000000000a', date: DateTime.utc(2026, 11, 5), updatedAt: DateTime.utc(2026, 11, 5, 8));
    final b = cashEntry(id: '00000000-0000-4000-8000-00000000000b', date: DateTime.utc(2026, 11, 5), updatedAt: DateTime.utc(2026, 11, 5, 8));
    const m = CashMonth(2026, 11);
    expect(m.entriesOf(<dynamic>[a, b].cast()).map((e) => e.id), m.entriesOf(<dynamic>[b, a].cast()).map((e) => e.id));
    expect(m.entriesOf(<dynamic>[b, a].cast()).first.id, a.id);
  });

  test('of() und contains() zählen nur Jahr und Monat; Gleichheit', () {
    final m = CashMonth.of(DateTime.utc(2026, 11, 30, 23, 59));
    expect(m, const CashMonth(2026, 11));
    expect(m.hashCode, const CashMonth(2026, 11).hashCode);
    expect(m.contains(DateTime.utc(2026, 11, 1)), isTrue);
    expect(m.contains(DateTime.utc(2026, 11, 30)), isTrue);
    expect(m.contains(DateTime.utc(2026, 12, 1)), isFalse);
    expect(m.contains(DateTime.utc(2025, 11, 15)), isFalse, reason: 'anderes Jahr');
    expect(m.toString(), '2026-11');
  });

  test('entriesOf: nur der Monat, keine Löschmarken, Datum absteigend, dann Zeitstempel, dann id', () {
    final m = const CashMonth(2026, 11);
    final entries = <CashEntryParts>[];
    final a = cashEntry(id: '00000000-0000-4000-8000-000000000001', date: DateTime.utc(2026, 11, 3), updatedAt: DateTime.utc(2026, 11, 3, 10));
    final b = cashEntry(id: '00000000-0000-4000-8000-000000000002', date: DateTime.utc(2026, 11, 20), updatedAt: DateTime.utc(2026, 11, 20, 9));
    final c = cashEntry(id: '00000000-0000-4000-8000-000000000003', date: DateTime.utc(2026, 11, 20), updatedAt: DateTime.utc(2026, 11, 20, 12));
    final d = cashEntry(id: '00000000-0000-4000-8000-000000000004', date: DateTime.utc(2026, 11, 20), updatedAt: DateTime.utc(2026, 11, 20, 12));
    final other = cashEntry(id: '00000000-0000-4000-8000-000000000005', date: DateTime.utc(2026, 10, 31));
    final gone = cashEntry(id: '00000000-0000-4000-8000-000000000006', date: DateTime.utc(2026, 11, 5), deleted: true);
    expect(entries, isEmpty);
    expect(m.entriesOf(<dynamic>[a, b, c, d, other, gone].cast()).map((e) => e.id.substring(35)), <String>['3', '4', '2', '1']);
  });
}

typedef CashEntryParts = Object;
