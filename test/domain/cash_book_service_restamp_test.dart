import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/memory_cash_book_store.dart';

/// #311, E-113 (Teil 2c): Neustempeln eigener Einträge vor dem Senden und Platzhalter-Buch.
void main() {
  late MemoryCashBookStore store;
  late CashBookService svc;
  final now = DateTime.utc(2026, 11, 22, 12);

  CashBookService serviceFor(String me) => CashBookService(store: store, myUserId: me, clock: () => now);

  setUp(() async {
    store = MemoryCashBookStore();
    svc = serviceFor(kBookOwner);
    await store.putBook(bookMeta());
  });

  group('restamp', () {
    test('Eintrag über einen Tag alt: neuer Zeitstempel, Version gleich, bleibt in der Warteschlange', () async {
      final old = cashEntry(updatedAt: now.subtract(const Duration(days: 5)));
      await store.putEntry(kBookRoom, old, publishedVersion: 0);
      final r = await svc.restamp(kBookRoom, old.id, expectedVersion: 1, expectedDeleted: false);
      expect(r!.updatedAt, now);
      expect(r.version, 1);
      expect((await store.getEntry(kBookRoom, kBookOwner, old.id))!.updatedAt, now);
      expect((await store.pending(kBookOwner)).single.entry.updatedAt, now);
    });

    test('Zeitstempel in der Zukunft (falsche Gerätezeit) wird ebenfalls korrigiert', () async {
      final e = cashEntry(updatedAt: now.add(const Duration(days: 9)));
      await store.putEntry(kBookRoom, e, publishedVersion: 0);
      expect((await svc.restamp(kBookRoom, e.id, expectedVersion: 1, expectedDeleted: false))!.updatedAt, now);
    });

    test('höchstens ein Tag Abweichung: unverändert', () async {
      final e = cashEntry(updatedAt: now.subtract(const Duration(hours: 23)));
      await store.putEntry(kBookRoom, e, publishedVersion: 0);
      expect(await svc.restamp(kBookRoom, e.id, expectedVersion: 1, expectedDeleted: false), e);
      expect((await store.getEntry(kBookRoom, kBookOwner, e.id))!.updatedAt, e.updatedAt);
    });

    test('Löschmarke wird gestempelt und bleibt eine Löschmarke', () async {
      final t = cashEntry(version: 2, deleted: true, updatedAt: now.subtract(const Duration(days: 4)));
      await store.putEntry(kBookRoom, t, publishedVersion: 0);
      final r = await svc.restamp(kBookRoom, t.id, expectedVersion: 2, expectedDeleted: true);
      expect(r!.deleted, isTrue);
      expect(r.updatedAt, now);
    });

    test('ein update() zwischen Lesen und Stempeln bleibt erhalten (alte Version wird nicht zurückgeschrieben)', () async {
      final e = cashEntry(updatedAt: now.subtract(const Duration(days: 5)));
      await store.putEntry(kBookRoom, e, publishedVersion: 0);
      final snapshot = (await store.pending(kBookOwner)).single.entry;
      final updated = await svc.update(kBookRoom, snapshot.copyWith(amountCents: 99));
      final r = await svc.restamp(kBookRoom, snapshot.id, expectedVersion: snapshot.version, expectedDeleted: false);
      expect(r, isNull, reason: 'Version hat sich geändert');
      expect(await store.getEntry(kBookRoom, kBookOwner, e.id), updated);
    });

    test('ein delete() dazwischen macht den Eintrag nicht wieder lebendig', () async {
      final e = cashEntry(updatedAt: now.subtract(const Duration(days: 5)));
      await store.putEntry(kBookRoom, e, publishedVersion: 0);
      await svc.delete(kBookRoom, e.id);
      final r = await svc.restamp(kBookRoom, e.id, expectedVersion: 1, expectedDeleted: false);
      expect(r, isNull);
      expect((await store.getEntry(kBookRoom, kBookOwner, e.id))!.deleted, isTrue);
    });

    test('fremder Autor und unbekannter Eintrag: nie gestempelt', () async {
      final foreign = cashEntry(author: kBookMember, updatedAt: now.subtract(const Duration(days: 5)));
      await store.putEntry(kBookRoom, foreign, publishedVersion: 1);
      expect(await svc.restamp(kBookRoom, foreign.id, expectedVersion: 1, expectedDeleted: false), isNull);
      expect((await store.getEntry(kBookRoom, kBookMember, foreign.id))!.updatedAt, foreign.updatedAt);
      expect(await svc.restamp(kBookRoom, kEntryId2, expectedVersion: 1, expectedDeleted: false), isNull);
    });
  });

  group('Platzhalter-Buch', () {
    test('applyFallback legt Version 0 an, nur wenn kein Buch existiert, nie gesendet', () async {
      expect(await svc.applyFallback('!neu:fake.test', owner: kBookOwner, currency: 'EUR'), isTrue);
      final b = (await store.getBook('!neu:fake.test'))!;
      expect(b.version, 0);
      expect(b.title, CashBookMeta.fallbackTitle);
      expect(await store.pendingBooks(kBookOwner), isEmpty);
      expect(await svc.applyFallback('!neu:fake.test', owner: kBookOwner, currency: 'USD'), isFalse);
      expect(await svc.applyFallback(kBookRoom, owner: kBookOwner, currency: 'EUR'), isFalse, reason: 'echtes Buch bleibt');
      expect((await store.getBook(kBookRoom))!.version, 1);
    });

    test('jedes echte Meta ersetzt das Platzhalter-Buch, auch mit lexikografisch kleinerem Titel', () async {
      await svc.applyFallback('!neu:fake.test', owner: kBookOwner, currency: 'EUR');
      expect(await svc.applyBook(bookMeta(room: '!neu:fake.test', title: 'Aaa', currency: 'AUD', version: 1)), isTrue);
      expect((await store.getBook('!neu:fake.test'))!.title, 'Aaa');
    });

    test('ungültige Währung oder Besitzer: kein Platzhalter; Bücher-Grenze gilt', () async {
      expect(await svc.applyFallback('!x:fake.test', owner: kBookOwner, currency: 'eur'), isFalse);
      expect(await svc.applyFallback('!x:fake.test', owner: 'kein-user', currency: 'EUR'), isFalse);
      for (var i = 0; i < CashBookLimits.maxBooksPerFamily; i++) {
        await store.putBook(bookMeta(room: '!l$i:fake.test'));
      }
      expect(await svc.applyFallback('!ueber:fake.test', owner: kBookOwner, currency: 'EUR'), isFalse);
    });
  });
}
