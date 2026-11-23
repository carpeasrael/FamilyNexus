import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/memory_cash_book_store.dart';

/// #311, E-113 (Teil 3b): Rückruf `onReceiptReleased` des Dienstes.
void main() {
  late MemoryCashBookStore store;
  late CashBookService svc;
  late List<(String, String, String)> released;
  final now = DateTime.utc(2026, 11, 22, 12);

  CashReceipt receipt(String id) => CashReceipt(eventId: id, sha256: kHash, size: 1000);

  setUp(() async {
    store = MemoryCashBookStore();
    svc = CashBookService(store: store, myUserId: kBookOwner, clock: () => now);
    released = <(String, String, String)>[];
    svc.onReceiptReleased = (r, e, ev) => released.add((r, e, ev));
    await store.putBook(bookMeta());
  });

  Future<CashEntry> own({CashReceipt? r}) => svc.create(kBookRoom, date: now, store: 'Edeka', amountCents: 100, receipt: r);

  test('Ersetzen des Bons eines eigenen Eintrags: der alte Verweis wird gemeldet', () async {
    final e = await own(r: receipt(r'$alt'));
    await svc.update(kBookRoom, e.copyWith(receipt: receipt(r'$neu')));
    expect(released, <(String, String, String)>[(kBookRoom, e.id, r'$alt')]);
  });

  test('Entfernen des Bons: der alte Verweis wird gemeldet', () async {
    final e = await own(r: receipt(r'$alt'));
    await svc.update(kBookRoom, e.copyWith(clearReceipt: true));
    expect(released.single.$3, r'$alt');
  });

  test('Löschen eines Eintrags mit Bon: gemeldet; ohne Bon nicht', () async {
    final e = await own(r: receipt(r'$alt'));
    await svc.delete(kBookRoom, e.id);
    expect(released.single, (kBookRoom, e.id, r'$alt'));
    released.clear();
    final plain = await svc.create(kBookRoom, date: now, store: 'Rewe', amountCents: 5);
    await svc.delete(kBookRoom, plain.id);
    expect(released, isEmpty);
  });

  test('Ändern ohne Änderung des Bons, Anlegen, Wiederholtes Löschen: nie gemeldet', () async {
    final e = await own(r: receipt(r'$alt'));
    expect(released, isEmpty, reason: 'Anlegen');
    await svc.update(kBookRoom, e.copyWith(amountCents: 999));
    expect(released, isEmpty, reason: 'gleicher Bon');
    await svc.delete(kBookRoom, e.id);
    released.clear();
    await svc.delete(kBookRoom, e.id);
    expect(released, isEmpty, reason: 'schon gelöscht');
  });

  test('Empfang, Fremdeinträge und restamp melden nie', () async {
    final foreign = cashEntry(author: kBookMember, receipt: receipt(r'$fremd'));
    await svc.applyEntry(kBookRoom, foreign);
    await svc.applyEntry(kBookRoom, foreign.copyWith(version: 2, clearReceipt: true));
    final mine = cashEntry(receipt: receipt(r'$mein'), updatedAt: now.subtract(const Duration(days: 9)));
    await store.putEntry(kBookRoom, mine, publishedVersion: 0);
    await svc.restamp(kBookRoom, mine.id, expectedVersion: 1, expectedDeleted: false);
    expect(released, isEmpty);
  });

  test('ein fremder Eintrag kann nicht über update() geändert werden und meldet nichts', () async {
    final foreign = cashEntry(author: kBookMember, receipt: receipt(r'$fremd'));
    await store.putEntry(kBookRoom, foreign, publishedVersion: 1);
    await expectLater(svc.update(kBookRoom, foreign.copyWith(clearReceipt: true)), throwsA(isA<CashBookException>()));
    expect(released, isEmpty);
  });
}
