import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_contact_store.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// #119, K2b (E-114): SQLCipher-Ablage der Kontakte, Migration 9, Warteschlange.
void main() {
  late Database db;
  late SqlContactStore store;
  final t0 = DateTime.utc(2026, 11, 25, 10);
  Contact c(String id, {int v = 1, bool deleted = false, ContactState s = ContactState.accepted, DateTime? at}) =>
      Contact(id: id, state: s, nick: 'N', room: '!r:example.org', version: v, updatedAt: at ?? t0, deleted: deleted);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlContactStore(db);
  });

  tearDown(() => db.close());

  test('Migration 9: Tabelle, Schlüssel; der Bestand eines Standes mit Version 8 bleibt unverändert', () async {
    expect(AppDatabase.schemaVersion, 9);
    final pk = <String>[
      for (final col in (await db.rawQuery('PRAGMA table_info(contact_records)')).where((x) => (x['pk']! as int) > 0).toList()
        ..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int)))
        col['name']! as String,
    ];
    expect(pk, <String>['rec', 'id']);
    final cols = (await db.rawQuery('PRAGMA table_info(contact_records)')).map((r) => r['name']).toSet();
    expect(cols, containsAll(<String>['rec', 'id', 'state', 'nick', 'room', 'version', 'updated_ms', 'deleted', 'published_version', 'data']));

    final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations.take(8)) {
      await m(old);
    }
    await old.insert('cash_books', <String, Object?>{'room_id': '!b:x', 'title': 'Haushalt', 'currency': 'EUR', 'owner': '@a:x', 'version': 1});
    await AppDatabase.migrations[8](old);
    expect(await old.query('cash_books'), hasLength(1));
    expect(await old.query('contact_records'), isEmpty);
    await old.close();
  });

  test('speichern, lesen, überschreiben; alle Arten; Reihenfolge', () async {
    expect(await store.get(ContactKind.contact, '@a:x.org'), isNull);
    await store.put(c('@b:x.org'));
    await store.put(c('@a:x.org'));
    await store.put(GroupRecord(id: '!g:x.org', version: 1, updatedAt: t0));
    await store.put(ContactPrefs(enabled: true, version: 1, updatedAt: t0));
    expect((await store.all(ContactKind.contact)).map((r) => r.id), <String>['@a:x.org', '@b:x.org']);
    expect(await store.all(), hasLength(4));
    expect(await store.get(ContactKind.prefs, 'prefs'), ContactPrefs(enabled: true, version: 1, updatedAt: t0));
    await store.put(c('@a:x.org', v: 2, s: ContactState.blocked));
    expect((await store.get(ContactKind.contact, '@a:x.org') as Contact).state, ContactState.blocked);
    expect(await store.all(ContactKind.contact), hasLength(2));
  });

  test('ungültige Zeile wird übersprungen, nie ein Absturz', () async {
    await store.put(c('@a:x.org'));
    await db.insert('contact_records', <String, Object?>{'rec': 'contact', 'id': '@kaputt:x.org', 'version': 1, 'updated_ms': 1, 'deleted': 0, 'data': 'kein json'});
    await db.insert('contact_records', <String, Object?>{'rec': 'contact', 'id': '@leer:x.org', 'version': 1, 'updated_ms': 1, 'deleted': 0, 'data': '{}'});
    await db.insert('contact_records', <String, Object?>{'rec': 'contact', 'id': '@liste:x.org', 'version': 1, 'updated_ms': 1, 'deleted': 0, 'data': '[]'});
    expect((await store.all()).map((r) => r.id), <String>['@a:x.org']);
    expect(await store.get(ContactKind.contact, '@kaputt:x.org'), isNull);
  });

  test('Warteschlange: neue Zeile wartet; markPublished nur bis zur gesendeten Version; eine neuere Fassung bleibt', () async {
    await store.put(c('@a:x.org'));
    expect((await store.pending()).map((r) => r.id), <String>['@a:x.org']);
    await store.markPublished(ContactKind.contact, '@a:x.org', 1);
    expect(await store.pending(), isEmpty);
    await store.put(c('@a:x.org', v: 2));
    expect(await store.pending(), hasLength(1), reason: 'lokal geändert: der Stand bleibt, die Fassung wartet');
    await store.markPublished(ContactKind.contact, '@a:x.org', 1);
    expect(await store.pending(), hasLength(1), reason: 'eine ältere Bestätigung verdrängt nichts');
    await store.markPublished(ContactKind.contact, '@a:x.org', 2);
    expect(await store.pending(), isEmpty);
  });

  test('lokal geändert (ohne publishedVersion): die bereits gemeldete Version bleibt erhalten', () async {
    await store.put(c('@a:x.org', v: 3), publishedVersion: 3);
    await store.put(c('@a:x.org', v: 3, s: ContactState.blocked));
    expect(await store.pending(), isEmpty, reason: 'gleiche Version, schon gesendet: bleibt gesendet');
    final row = (await db.query('contact_records')).single;
    expect(row['published_version'], 3);
  });

  test('empfangene Fassung (publishedVersion) wartet nicht', () async {
    await store.put(c('@a:x.org', v: 4), publishedVersion: 4);
    expect(await store.pending(), isEmpty);
  });

  test('requeueAll merkt alle nicht gelöschten Datensätze erneut vor, Löschmarken nicht', () async {
    await store.put(c('@a:x.org'), publishedVersion: 1);
    await store.put(c('@b:x.org', v: 2, deleted: true), publishedVersion: 2);
    await store.put(GroupRecord(id: '!g:x.org', version: 1, updatedAt: t0), publishedVersion: 1);
    await store.requeueAll();
    expect((await store.pending()).map((r) => r.id).toSet(), <String>{'@a:x.org', '!g:x.org'});
  });

  test('pruneTombstones: nur veröffentlichte Löschmarken, die ältesten zuerst, unveröffentlichte bleiben immer', () async {
    for (var i = 0; i < 5; i++) {
      await store.put(c('@t$i:x.org', v: 2, deleted: true, at: t0.add(Duration(minutes: i))), publishedVersion: 2);
    }
    await store.put(c('@offen:x.org', v: 2, deleted: true, at: t0.subtract(const Duration(days: 9))), publishedVersion: 0);
    await store.put(c('@aktiv:x.org'), publishedVersion: 1);
    expect(await store.pruneTombstones(keep: 2), 3);
    final ids = (await store.all()).map((r) => r.id).toSet();
    expect(ids, <String>{'@t3:x.org', '@t4:x.org', '@offen:x.org', '@aktiv:x.org'});
    expect(await store.pruneTombstones(keep: 2), 0);
  });

  test('wipe entfernt alles', () async {
    await store.put(c('@a:x.org'));
    await store.put(GroupRecord(id: '!g:x.org', version: 1, updatedAt: t0));
    await store.wipe();
    expect(await store.all(), isEmpty);
    expect(await store.pending(), isEmpty);
  });
}
