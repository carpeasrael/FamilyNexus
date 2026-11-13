import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_data_inventory.dart';
import 'package:family_nexus/data/db/sql_event_store.dart';
import 'package:family_nexus/data/db/sql_event_theme_store.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _t1 = '00000000-0000-4000-8000-000000000001';

EventTheme _theme({int version = 1, bool deleted = false, String id = _t1, String by = _anna, String name = 'Schule'}) => EventTheme(
      id: id,
      name: deleted ? '' : name,
      colorIndex: 2,
      deleted: deleted,
      version: version,
      by: by,
      updatedAt: DateTime.utc(2026, 10, 21, 12),
    );

void main() {
  late Database db;
  late SqlEventThemeStore store;

  setUpAll(() {
    sqfliteFfiInit();
    TimeZones.ensureInitialized();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlEventThemeStore(db);
  });

  tearDown(() => db.close());

  test('Migration legt die Tabelle event_themes mit den erwarteten Spalten an', () async {
    final cols = (await db.rawQuery('PRAGMA table_info(event_themes)')).map((r) => r['name']).toSet();
    expect(cols, <String>{'id', 'version', 'published', 'deleted', 'author', 'data'});
  });

  test('speichern, lesen, Version überschreibt, ausstehend und veröffentlicht', () async {
    await store.put(_theme(), publishedVersion: 0);
    expect(await store.get(_t1), _theme());
    expect((await store.pending()).map((t) => t.id), [_t1]);
    await store.markPublished(_t1, 1);
    expect(await store.pending(), isEmpty);
    await store.put(_theme(version: 2));
    expect((await store.get(_t1))!.version, 2);
    expect((await store.pending()).single.version, 2, reason: 'neue Version ist wieder ausstehend');
    expect(await store.counts(), (active: 1, total: 1));
    expect(await store.get('00000000-0000-4000-8000-0000000000ff'), isNull);
  });

  test('Empfangenes wird mit publishedVersion abgelegt und nicht erneut gesendet', () async {
    await store.put(_theme(version: 3, by: _ben), publishedVersion: 3);
    expect(await store.pending(), isEmpty);
  });

  test('Löschmarken: nur veröffentlichte werden gekürzt, Zählung aktiv/gesamt', () async {
    for (var i = 1; i <= 3; i++) {
      final id = '00000000-0000-4000-8000-0000000001${i.toString().padLeft(2, '0')}';
      await store.put(_theme(deleted: true, version: 2, id: id), publishedVersion: i == 3 ? 0 : 2);
    }
    await store.put(_theme());
    expect(await store.counts(), (active: 1, total: 4));
    await store.pruneTombstones(keep: 0);
    expect((await store.all()).map((t) => t.id).toSet(), <String>{_t1, '00000000-0000-4000-8000-000000000103'},
        reason: 'unveröffentlichte Löschmarke und aktives Thema bleiben');
  });

  test('requeueLastEditedBy markiert nur eigene, nicht gelöschte Themen neu', () async {
    final b = '00000000-0000-4000-8000-000000000002';
    final d = '00000000-0000-4000-8000-000000000003';
    await store.put(_theme(), publishedVersion: 1);
    await store.put(_theme(id: b, by: _ben), publishedVersion: 1);
    await store.put(_theme(id: d, deleted: true, version: 2), publishedVersion: 2);
    await store.requeueLastEditedBy(_anna);
    expect((await store.pending()).map((t) => t.id), [_t1]);
  });

  test('wipe leert die Tabelle', () async {
    await store.put(_theme());
    await store.wipe();
    expect(await store.all(), isEmpty);
    expect(await store.counts(), (active: 0, total: 0));
  });

  test('unlesbare oder ungültige Zeilen werden übergangen, nicht geworfen', () async {
    await db.insert('event_themes', <String, Object?>{'id': 'x1', 'version': 1, 'deleted': 0, 'author': _anna, 'data': 'kein json'});
    await db.insert('event_themes', <String, Object?>{'id': 'x2', 'version': 1, 'deleted': 0, 'author': _anna, 'data': '{"v":1}'});
    await store.put(_theme());
    expect((await store.all()).map((t) => t.id), [_t1]);
    expect(await store.get('x1'), isNull);
  });

  test('Datenübersicht und Löschen beim Abmelden/Konto löschen enthalten event_themes', () async {
    expect(SqlDataInventory.tables, contains('event_themes'));
    await db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': '@anna:fake.test|!f:fake.test'});
    await store.put(_theme());
    await AppServices.wipeAccountDataIn(db);
    expect(await store.all(), isEmpty);
    // Familienwechsel: Der Anspruch einer anderen Familie leert den Bestand ebenfalls.
    await store.put(_theme());
    await db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': '@anna:fake.test|!a:fake.test'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await AppServices.claimFamilyData(db, '@anna:fake.test|!b:fake.test');
    expect(await store.all(), isEmpty);
  });

  test('gespeicherter Termin behält themeId über die SQL-Ablage', () async {
    const theme = '00000000-0000-4000-8000-0000000000a1';
    final events = SqlEventStore(db);
    final e = CalendarEvent(
      id: '11111111-1111-4111-8111-111111111111',
      ownerId: _anna,
      title: 'Elternabend',
      start: DateTime.utc(2026, 11, 2, 9),
      end: DateTime.utc(2026, 11, 2, 10),
      timeZone: 'Europe/Berlin',
      updatedAt: DateTime.utc(2026, 11, 1),
      visibility: EventVisibility.shared,
      themeId: theme,
    );
    await events.put(e);
    expect((await events.get(e.id))!.themeId, theme);
    expect((await events.all()).single.themeId, theme);
  });
}
