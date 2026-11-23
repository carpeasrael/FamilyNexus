import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_cash_book_store.dart';
import 'package:family_nexus/domain/cash_book_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/cash_books.dart';
import '../support/memory_cash_book_store.dart';

/// #311, E-113 (Teil 2c): Warteschlange der Buch-Metadaten und Verhalten von `putEntry` ohne `publishedVersion`, für
/// beide Ablagen (SQL und Arbeitsspeicher) gleich.
void main() {
  setUpAll(sqfliteFfiInit);

  void suite(String name, Future<CashBookStore> Function() make) {
    group(name, () {
      late CashBookStore store;
      setUp(() async => store = await make());

      test('pendingBooks: nur eigene, ungesendete Bücher mit Version >= 1; Platzhalter (Version 0) nie', () async {
        await store.putBook(bookMeta(room: '!a:fake.test'), published: false);
        await store.putBook(bookMeta(room: '!b:fake.test'), published: true);
        await store.putBook(bookMeta(room: '!c:fake.test', owner: kBookMember), published: false);
        await store.putBook(bookMeta(room: '!d:fake.test', version: 0), published: false);
        expect((await store.pendingBooks(kBookOwner)).map((b) => b.roomId), <String>['!a:fake.test']);
      });

      test('markBookPublished: nur wenn Titel, Währung und Version noch dem gesendeten Stand entsprechen', () async {
        final sent = bookMeta(title: 'Haushalt');
        await store.putBook(sent, published: false);
        // zwischenzeitlich geändert: der gesendete Stand gilt nicht mehr
        await store.putBook(bookMeta(title: 'Haushalt neu', version: 2), published: false);
        await store.markBookPublished(sent);
        expect((await store.pendingBooks(kBookOwner)).single.title, 'Haushalt neu', reason: 'bleibt in der Warteschlange');
        await store.markBookPublished(bookMeta(title: 'Haushalt neu', version: 2));
        expect(await store.pendingBooks(kBookOwner), isEmpty);
        // gleiche Version, anderer Titel: kein Treffer
        await store.putBook(bookMeta(title: 'A', version: 3), published: false);
        await store.markBookPublished(bookMeta(title: 'B', version: 3));
        expect(await store.pendingBooks(kBookOwner), hasLength(1));
      });

      test('requeueBook: setzt ein gesendetes Buch zurück, nie das Platzhalter-Buch', () async {
        await store.putBook(bookMeta(room: '!a:fake.test'), published: true);
        await store.putBook(bookMeta(room: '!p:fake.test', version: 0), published: true);
        await store.requeueBook('!a:fake.test');
        await store.requeueBook('!p:fake.test');
        await store.requeueBook('!unbekannt:fake.test');
        expect((await store.pendingBooks(kBookOwner)).map((b) => b.roomId), <String>['!a:fake.test']);
      });

      test('putEntry ohne publishedVersion lässt den Sendestand unverändert (restamp bleibt in der Warteschlange)', () async {
        await store.putBook(bookMeta());
        final e = cashEntry();
        await store.putEntry(kBookRoom, e, publishedVersion: 0);
        await store.markPublished(kBookRoom, e.author, e.id, 1);
        expect(await store.pending(kBookOwner), isEmpty);
        // gleiche Version, neuer Zeitstempel, ohne publishedVersion: bleibt gesendet
        await store.putEntry(kBookRoom, e.copyWith(updatedAt: DateTime.utc(2026, 11, 21)));
        expect(await store.pending(kBookOwner), isEmpty);
        // neue Version ohne publishedVersion: wartet
        await store.putEntry(kBookRoom, e.copyWith(version: 2));
        expect((await store.pending(kBookOwner)).single.entry.version, 2);
      });

      test('deleteBook und wipe räumen die Warteschlange der Metadaten', () async {
        await store.putBook(bookMeta(), published: false);
        await store.deleteBook(kBookRoom);
        expect(await store.pendingBooks(kBookOwner), isEmpty);
        await store.putBook(bookMeta(), published: false);
        await store.wipe();
        expect(await store.pendingBooks(kBookOwner), isEmpty);
      });
    });
  }

  suite('Arbeitsspeicher', () async => MemoryCashBookStore());
  suite('SQL', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    addTearDown(db.close);
    return SqlCashBookStore(db);
  });
}
