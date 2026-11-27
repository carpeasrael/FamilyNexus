import 'package:family_nexus/domain/cash_book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';

/// #311, E-113: Totalordnung `(gelöscht, Version, updated_at, kanonisch)`; alle Reihenfolgen enden gleich.
void main() {
  final t0 = DateTime.utc(2026, 11, 20, 12);

  CashEntry run(List<CashEntry> list) {
    CashEntry? cur;
    for (final e in list) {
      final r = CashEntryResolver.resolve(cur, e);
      if (r == CashResolution.insert || r == CashResolution.replace) cur = e;
    }
    return cur!;
  }

  Iterable<List<T>> perms<T>(List<T> l) sync* {
    if (l.length <= 1) {
      yield l;
      return;
    }
    for (var i = 0; i < l.length; i++) {
      final rest = <T>[...l]..removeAt(i);
      for (final p in perms(rest)) {
        yield <T>[l[i], ...p];
      }
    }
  }

  void converges(List<CashEntry> list) {
    expect(<CashEntry>{for (final p in perms(list)) run(p)}, hasLength(1));
  }

  test('neu: einfügen; gleiche Fassung: Duplikat; höhere Version gewinnt', () {
    expect(CashEntryResolver.resolve(null, cashEntry()), CashResolution.insert);
    expect(CashEntryResolver.resolve(cashEntry(), cashEntry()), CashResolution.ignoreDuplicate);
    expect(CashEntryResolver.resolve(cashEntry(), cashEntry(version: 2)), CashResolution.replace);
    expect(CashEntryResolver.resolve(cashEntry(version: 2), cashEntry()), CashResolution.ignoreStale);
  });

  test('gleiche Version: später aktualisiert gewinnt, sonst kanonisch deterministisch', () {
    converges(<CashEntry>[cashEntry(version: 2, store: 'A', updatedAt: t0), cashEntry(version: 2, store: 'B', updatedAt: t0.add(const Duration(seconds: 1)))]);
    converges(<CashEntry>[cashEntry(version: 2, store: 'A', updatedAt: t0), cashEntry(version: 2, store: 'B', updatedAt: t0)]);
  });

  test('Löschmarke schlägt jede lebende Fassung, auch mit höherer Version (alle sechs Reihenfolgen)', () {
    final gone = cashEntry().tombstone(t0); // Version 2
    final live5 = cashEntry(version: 5, store: 'lebt');
    final live7 = cashEntry(version: 7, store: 'lebt mehr');
    converges(<CashEntry>[gone, live5, live7]);
    expect(run(<CashEntry>[live5, gone, live7]).deleted, isTrue);
    expect(run(<CashEntry>[gone, live7]).deleted, isTrue);
    expect(CashEntryResolver.resolve(live5, gone), CashResolution.replace);
    expect(CashEntryResolver.resolve(gone, live5), CashResolution.ignoreStale);
  });

  test('Versionskette in allen Reihenfolgen endet auf der höchsten', () {
    converges(<CashEntry>[cashEntry(), cashEntry(version: 2, store: 'B'), cashEntry(version: 3, store: 'C')]);
    expect(run(<CashEntry>[cashEntry(version: 3, store: 'C'), cashEntry()]).store, 'C');
  });
}
