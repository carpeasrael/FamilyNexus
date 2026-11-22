import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/memory_cash_book_store.dart';

/// #311, E-113: Dienst des Kassenbuchs (lokale Änderungen, Annahme empfangener Einträge und Bücher).
void main() {
  late MemoryCashBookStore store;
  late CashBookService svc;
  var ids = 0;
  var now = DateTime.utc(2026, 11, 22, 12);

  CashBookService serviceFor(String me) => CashBookService(
        store: store,
        myUserId: me,
        clock: () => now,
        idGenerator: () => '00000000-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}',
      );

  setUp(() async {
    store = MemoryCashBookStore();
    ids = 0;
    now = DateTime.utc(2026, 11, 22, 12);
    svc = serviceFor(kBookOwner);
    await store.putBook(bookMeta());
  });

  Future<CashEntry> make({String author = kBookOwner, int cents = 1250}) =>
      serviceFor(author).create(kBookRoom, date: DateTime.utc(2026, 11, 20, 15), store: ' Edeka ', amountCents: cents);

  group('eigene Einträge', () {
    test('anlegen: trimmt, Tag ohne Uhrzeit, Version 1, wartet auf Senden', () async {
      final e = await make();
      expect(e.store, 'Edeka');
      expect(e.date, DateTime.utc(2026, 11, 20));
      expect(e.version, 1);
      expect(e.author, kBookOwner);
      expect((await store.pending(kBookOwner)).single.entry, e);
    });

    test('ungültige Eingaben, unbekanntes Buch, Limit je Autor', () async {
      await expectLater(svc.create(kBookRoom, date: now, store: '', amountCents: 5), throwsA(isA<CashBookException>()));
      await expectLater(svc.create(kBookRoom, date: now, store: 'x', amountCents: -1), throwsA(isA<CashBookException>()));
      await expectLater(svc.create('!nope:fake.test', date: now, store: 'x', amountCents: 1),
          throwsA(isA<CashBookException>().having((e) => e.error, 'error', CashBookError.notFound)));
      for (var i = 0; i < CashBookLimits.maxEntriesPerAuthor; i++) {
        await store.putEntry(kBookRoom, cashEntry(id: '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}'));
      }
      await expectLater(svc.create(kBookRoom, date: now, store: 'x', amountCents: 1),
          throwsA(isA<CashBookException>().having((e) => e.error, 'error', CashBookError.limit)));
    });

    test('ändern: Version +1, nur der Autor; fremde Einträge und Löschmarken nicht', () async {
      final e = await make();
      final changed = await svc.update(kBookRoom, e.copyWith(store: 'Rewe', amountCents: 999));
      expect(changed.version, 2);
      expect(changed.store, 'Rewe');
      expect(changed.amountCents, 999);
      expect((await store.pending(kBookOwner)).single.entry.version, 2);
    });

    test('Fremder Autor ändert und löscht nicht', () async {
      final e = await make();
      final other = serviceFor(kBookMember);
      await expectLater(other.update(kBookRoom, e.copyWith(store: 'X')), throwsA(isA<CashBookException>()));
      await expectLater(other.delete(kBookRoom, e.id), throwsA(isA<CashBookException>()));
      expect((await store.getEntry(kBookRoom, kBookOwner, e.id))!.store, 'Edeka');
    });

    test('löschen: Löschmarke, Summen zählen sie nicht, Ändern danach nicht möglich', () async {
      final e = await make(cents: 700);
      expect(await svc.monthTotal(kBookRoom, 2026, 11), 700);
      await svc.delete(kBookRoom, e.id);
      final gone = (await store.getEntry(kBookRoom, kBookOwner, e.id))!;
      expect(gone.deleted, isTrue);
      expect(gone.version, 2);
      expect(await svc.monthTotal(kBookRoom, 2026, 11), 0);
      await expectLater(svc.update(kBookRoom, e), throwsA(isA<CashBookException>()));
      await svc.delete(kBookRoom, e.id); // zweites Löschen ist folgenlos
    });
  });

  group('empfangene Einträge', () {
    test('neuer, neuerer, älterer und doppelter Eintrag', () async {
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember)), CashResolution.insert);
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember, version: 2, store: 'Neu')), CashResolution.replace);
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember)), CashResolution.ignoreStale);
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember, version: 2, store: 'Neu')), CashResolution.ignoreDuplicate);
      expect((await store.getEntry(kBookRoom, kBookMember, kEntryId1))!.store, 'Neu');
    });

    test('gleiche id eines anderen Autors verdrängt nie den eigenen Eintrag (Schlüssel Raum, Autor, ID), jede Reihenfolge', () async {
      final mine = cashEntry(author: kBookOwner, store: 'Meiner');
      final theirs = cashEntry(author: kBookMember, store: 'Fremder', version: 9);
      for (final order in <List<CashEntry>>[<CashEntry>[mine, theirs], <CashEntry>[theirs, mine]]) {
        store = MemoryCashBookStore();
        await store.putBook(bookMeta());
        svc = serviceFor(kBookOwner);
        for (final e in order) {
          await svc.applyEntry(kBookRoom, e);
        }
        expect((await store.getEntry(kBookRoom, kBookOwner, kEntryId1))!.store, 'Meiner');
        expect((await store.getEntry(kBookRoom, kBookMember, kEntryId1))!.store, 'Fremder');
      }
    });

    test('Löschmarke eines Fremden mit meiner id trifft nur seinen Schlüssel', () async {
      await svc.applyEntry(kBookRoom, cashEntry(author: kBookOwner));
      final forged = cashEntry(author: kBookMember).tombstone(now);
      await svc.applyEntry(kBookRoom, forged);
      expect((await store.getEntry(kBookRoom, kBookOwner, kEntryId1))!.deleted, isFalse);
    });

    test('Versionssprung über 1000, Limit je Autor, unbekanntes Buch, ungültiger Eintrag: verworfen', () async {
      await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember));
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember, version: 1002)), isNull);
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember, version: 1001)), CashResolution.replace);
      expect(await svc.applyEntry('!nope:fake.test', cashEntry(author: kBookMember, id: kEntryId2)), isNull);
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember, id: kEntryId2, cents: -5)), isNull);
      for (var i = 0; i < CashBookLimits.maxEntriesPerAuthor - 1; i++) {
        await store.putEntry(kBookRoom, cashEntry(author: kBookMember, id: '20000000-0000-4000-8000-${i.toString().padLeft(12, '0')}'));
      }
      expect(await svc.applyEntry(kBookRoom, cashEntry(author: kBookMember, id: '30000000-0000-4000-8000-000000000001')), isNull);
    });

    test('angenommene Fassung gilt als veröffentlicht, nicht als ausstehend', () async {
      await svc.applyEntry(kBookRoom, cashEntry(author: kBookOwner));
      expect(await store.pending(kBookOwner), isEmpty);
    });
  });

  group('Bücher', () {
    test('neues, neueres und gleich-versioniertes Buch konvergieren; fremder Ersteller und Ungültiges nicht', () async {
      store = MemoryCashBookStore();
      svc = serviceFor(kBookOwner);
      expect(await svc.applyBook(bookMeta(title: 'A')), isTrue);
      expect(await svc.applyBook(bookMeta(title: 'A')), isFalse, reason: 'Duplikat');
      expect(await svc.applyBook(bookMeta(title: 'B', version: 2)), isTrue);
      expect(await svc.applyBook(bookMeta(title: 'A', version: 1)), isFalse, reason: 'älter');
      expect(await svc.applyBook(bookMeta(owner: kBookMember, title: 'C', version: 9)), isFalse, reason: 'anderer Ersteller');
      expect(await svc.applyBook(bookMeta(currency: 'xx')), isFalse);
      expect((await store.getBook(kBookRoom))!.title, 'B');
    });

    test('gleiche Version: deterministisch, unabhängig von der Reihenfolge', () async {
      final a = bookMeta(title: 'A', version: 3);
      final b = bookMeta(title: 'B', version: 3);
      for (final order in <List<CashBookMeta>>[<CashBookMeta>[a, b], <CashBookMeta>[b, a]]) {
        store = MemoryCashBookStore();
        svc = serviceFor(kBookOwner);
        for (final m in order) {
          await svc.applyBook(m);
        }
        expect((await store.getBook(kBookRoom))!.title, 'B');
      }
    });

    test('höchstens zehn Bücher je Familie', () async {
      store = MemoryCashBookStore();
      svc = serviceFor(kBookOwner);
      for (var i = 0; i < CashBookLimits.maxBooksPerFamily; i++) {
        expect(await svc.applyBook(bookMeta(room: '!b$i:fake.test')), isTrue);
      }
      expect(await svc.applyBook(bookMeta(room: '!elf:fake.test')), isFalse);
      expect(await svc.applyBook(bookMeta(room: '!b0:fake.test', title: 'Neu', version: 2)), isTrue, reason: 'vorhandenes Buch aktualisieren');
    });
  });
}
