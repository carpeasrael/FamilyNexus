import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_cash_book_store.dart';
import 'package:family_nexus/data/db/sql_data_inventory.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/cash_books.dart';

/// #311, E-113: SQL-Ablage des Kassenbuchs und Migration 8.
void main() {
  late Database db;
  late SqlCashBookStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlCashBookStore(db);
  });

  tearDown(() => db.close());

  test('Migration 8: Tabellen und Schlüssel; der Bestand eines Standes mit Version 7 bleibt unverändert', () async {
    expect(AppDatabase.schemaVersion, 9);
    Future<List<String>> pk(String t) async => <String>[
          for (final c in (await db.rawQuery('PRAGMA table_info($t)')).where((c) => (c['pk']! as int) > 0).toList()
            ..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int)))
            c['name']! as String,
        ];
    expect(await pk('cash_books'), <String>['room_id']);
    expect(await pk('cash_entries'), <String>['room_id', 'author', 'id']);

    // Leere und gefüllte Datenbank mit Stand 7: Zeilen anderer Tabellen überstehen die Migration 8.
    final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations.take(7)) {
      await m(old);
    }
    await old.insert('avatar_resets', <String, Object?>{'room_id': '!f:x', 'target': '@a:x', 'photo_id': 'p', 'photo_created_at': 1});
    await AppDatabase.migrations[7](old);
    expect(await old.query('avatar_resets'), hasLength(1));
    expect(await old.query('cash_books'), isEmpty);
    expect(await old.query('cash_entries'), isEmpty);
    await old.close();
  });

  test('Buch: speichern, lesen, überschreiben, vollständig-Marke, löschen mit Einträgen', () async {
    expect(await store.getBook(kBookRoom), isNull);
    await store.putBook(bookMeta());
    expect(await store.getBook(kBookRoom), bookMeta());
    await store.putBook(bookMeta(title: 'Neu', version: 2));
    expect((await store.books()).single.title, 'Neu');
    expect(await store.isComplete(kBookRoom), isFalse);
    await store.setComplete(kBookRoom, true);
    expect(await store.isComplete(kBookRoom), isTrue);
    await store.putEntry(kBookRoom, cashEntry());
    await store.deleteBook(kBookRoom);
    expect(await store.books(), isEmpty);
    expect(await store.entries(kBookRoom), isEmpty);
  });

  test('Eintrag: Schlüssel (Raum, Autor, ID), Rundlauf mit Bon, Zählung je Autor', () async {
    const receipt = CashReceipt(eventId: r'$abc:fake.test', sha256: kHash, size: 1234);
    await store.putEntry(kBookRoom, cashEntry(author: kBookOwner, store: 'Meiner', receipt: receipt));
    await store.putEntry(kBookRoom, cashEntry(author: kBookMember, store: 'Fremder'));
    await store.putEntry('!zwei:fake.test', cashEntry(author: kBookOwner, store: 'Anderes Buch'));
    expect((await store.getEntry(kBookRoom, kBookOwner, kEntryId1))!.receipt, receipt);
    expect((await store.getEntry(kBookRoom, kBookMember, kEntryId1))!.store, 'Fremder');
    expect(await store.entries(kBookRoom), hasLength(2));
    expect(await store.countByAuthor(kBookRoom, kBookOwner), 1);
    await store.putEntry(kBookRoom, cashEntry(author: kBookOwner, store: 'Meiner neu', version: 2));
    expect(await store.countByAuthor(kBookRoom, kBookOwner), 1, reason: 'überschreibt, legt nicht neu an');
    expect((await store.getEntry(kBookRoom, kBookOwner, kEntryId1))!.store, 'Meiner neu');
  });

  test('ausstehend, veröffentlicht, erneut vormerken (nur eigene, nicht gelöschte)', () async {
    await store.putEntry(kBookRoom, cashEntry(), publishedVersion: 0);
    await store.putEntry(kBookRoom, cashEntry(author: kBookMember), publishedVersion: 1);
    expect((await store.pending(kBookOwner)).single.entry.id, kEntryId1);
    expect(await store.pending(kBookMember), isEmpty);
    await store.markPublished(kBookRoom, kBookOwner, kEntryId1, 1);
    expect(await store.pending(kBookOwner), isEmpty);
    await store.markPublished(kBookRoom, kBookOwner, kEntryId1, 0); // nie rückwärts
    expect(await store.pending(kBookOwner), isEmpty);
  });

  test('requeueOwn setzt published auf 0: Version 1 gilt wieder als ausstehend', () async {
    await store.putEntry(kBookRoom, cashEntry(), publishedVersion: 1);
    expect(await store.pending(kBookOwner), isEmpty);
    await store.requeueOwn(kBookRoom, kBookOwner);
    expect((await store.pending(kBookOwner)).single.entry.version, 1);
    await store.putEntry(kBookRoom, cashEntry(version: 2).tombstone(DateTime.utc(2026, 11, 21)), publishedVersion: 3);
    await store.requeueOwn(kBookRoom, kBookOwner);
    expect(await store.pending(kBookOwner), isEmpty, reason: 'gelöschte Einträge werden nicht erneut gesendet');
  });

  test('requeueOwn berührt keine fremden Einträge desselben Buchs', () async {
    await store.putEntry(kBookRoom, cashEntry(author: kBookOwner), publishedVersion: 1);
    await store.putEntry(kBookRoom, cashEntry(author: kBookMember), publishedVersion: 1);
    await store.requeueOwn(kBookRoom, kBookOwner);
    expect((await store.pending(kBookOwner)).single.entry.author, kBookOwner);
    expect(await store.pending(kBookMember), isEmpty);
  });

  test('neuer Eintrag ohne publishedVersion gilt als ausstehend (published 0)', () async {
    await store.putEntry(kBookRoom, cashEntry());
    expect((await store.pending(kBookOwner)).single.entry.version, 1);
    await store.markPublished(kBookRoom, kBookOwner, kEntryId1, 1);
    expect(await store.pending(kBookOwner), isEmpty);
  });

  test('ohne publishedVersion bleibt der bisherige Wert (lokale Änderung wartet auf Senden)', () async {
    await store.putEntry(kBookRoom, cashEntry(), publishedVersion: 1);
    await store.putEntry(kBookRoom, cashEntry(version: 2, store: 'Rewe'));
    expect((await store.pending(kBookOwner)).single.entry.version, 2);
  });

  test('Datenübersicht kennt beide Tabellen', () {
    expect(SqlDataInventory.tables, containsAll(<String>['cash_books', 'cash_entries']));
  });

  test('wipe leert beide Tabellen', () async {
    await store.putBook(bookMeta());
    await store.putEntry(kBookRoom, cashEntry());
    await store.wipe();
    expect(await db.query('cash_books'), isEmpty);
    expect(await db.query('cash_entries'), isEmpty);
  });
}
