import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_anniversary_store.dart';
import 'package:family_nexus/data/db/sql_data_inventory.dart';
import 'package:family_nexus/domain/anniversaries.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _p1 = '00000000-0000-4000-8000-000000000001';

AnniversaryPerson _person({int version = 1, bool deleted = false, String id = _p1, String by = _anna, String name = 'Oma'}) => AnniversaryPerson(
      id: id,
      name: deleted ? '' : name,
      birth: deleted ? null : const AnniversaryDate(month: 3, day: 15, year: 1940),
      deleted: deleted,
      version: version,
      by: by,
      updatedAt: DateTime.utc(2026, 10, 21, 12),
    );

void main() {
  late Database db;
  late SqlAnniversaryStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlAnniversaryStore(db);
  });

  tearDown(() => db.close());

  test('Migration 6 legt die Tabelle anniversaries an, der Bestand bleibt unverändert', () async {
    expect(AppDatabase.schemaVersion, 9);
    final cols = (await db.rawQuery('PRAGMA table_info(anniversaries)')).map((r) => r['name']).toSet();
    expect(cols, <String>{'id', 'version', 'published', 'deleted', 'author', 'data'});
    // Bestand eines Standes mit Version 5: Zeilen der Themen überstehen die Migration 6 unverändert.
    final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations.take(5)) {
      await m(old);
    }
    await old.insert('event_themes', <String, Object?>{'id': 'th1', 'version': 1, 'deleted': 0, 'author': _anna, 'data': '{}'});
    await AppDatabase.migrations[5](old);
    expect((await old.query('event_themes')).single['id'], 'th1');
    expect(await old.query('anniversaries'), isEmpty);
    await old.close();
  });

  test('speichern, lesen, Version überschreibt, ausstehend und veröffentlicht', () async {
    await store.put(_person(), publishedVersion: 0);
    expect(await store.get(_p1), _person());
    expect((await store.pending()).map((t) => t.id), [_p1]);
    await store.markPublished(_p1, 1);
    expect(await store.pending(), isEmpty);
    await store.put(_person(version: 2, name: 'Oma Erna'));
    expect((await store.get(_p1))!.name, 'Oma Erna');
    expect((await store.pending()).single.version, 2);
    expect(await store.counts(), (active: 1, total: 1));
  });

  test('Empfangenes wird mit publishedVersion abgelegt und nicht erneut gesendet', () async {
    await store.put(_person(version: 3, by: _ben), publishedVersion: 3);
    expect(await store.pending(), isEmpty);
  });

  test('Löschmarken: nur veröffentlichte werden gekürzt, Zählung aktiv/gesamt', () async {
    for (var i = 1; i <= 3; i++) {
      final id = '00000000-0000-4000-8000-0000000001${i.toString().padLeft(2, '0')}';
      await store.put(_person(deleted: true, version: 2, id: id), publishedVersion: i == 3 ? 0 : 2);
    }
    await store.put(_person());
    expect(await store.counts(), (active: 1, total: 4));
    await store.pruneTombstones(keep: 0);
    expect((await store.all()).map((t) => t.id).toSet(), <String>{_p1, '00000000-0000-4000-8000-000000000103'});
  });

  test('requeueLastEditedBy markiert nur eigene, nicht gelöschte Einträge neu', () async {
    const b = '00000000-0000-4000-8000-000000000002';
    const d = '00000000-0000-4000-8000-000000000003';
    await store.put(_person(), publishedVersion: 1);
    await store.put(_person(id: b, by: _ben), publishedVersion: 1);
    await store.put(_person(id: d, deleted: true, version: 2), publishedVersion: 2);
    await store.requeueLastEditedBy(_anna);
    expect((await store.pending()).map((t) => t.id), [_p1]);
  });

  test('unlesbare oder ungültige Zeilen werden übergangen, nicht geworfen', () async {
    await db.insert('anniversaries', <String, Object?>{'id': 'x1', 'version': 1, 'deleted': 0, 'author': _anna, 'data': 'kein json'});
    await db.insert('anniversaries', <String, Object?>{'id': 'x2', 'version': 1, 'deleted': 0, 'author': _anna, 'data': '{"v":1}'});
    await store.put(_person());
    expect((await store.all()).map((t) => t.id), [_p1]);
    expect(await store.get('x1'), isNull);
  });

  test('Datenübersicht, Abmelden/Konto löschen und Familienwechsel leeren anniversaries', () async {
    expect(SqlDataInventory.tables, contains('anniversaries'));
    await db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': '@anna:fake.test|!f:fake.test'});
    await store.put(_person());
    await AppServices.wipeAccountDataIn(db);
    expect(await store.all(), isEmpty);
    await store.put(_person());
    await db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': '@anna:fake.test|!a:fake.test'}, conflictAlgorithm: ConflictAlgorithm.replace);
    await AppServices.claimFamilyData(db, '@anna:fake.test|!b:fake.test');
    expect(await store.all(), isEmpty);
  });
}
