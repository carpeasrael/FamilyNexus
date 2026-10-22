import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_task_store.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _l1 = '00000000-0000-4000-8000-000000000001';
const String _i1 = '00000000-0000-4000-8000-000000000002';

TaskList _list({int version = 1, bool deleted = false, String id = _l1}) => TaskList(
      id: id,
      title: deleted ? '' : 'Haushalt',
      assignee: _ben,
      interval: TaskInterval.weekly,
      timeZone: 'Europe/Berlin',
      items: deleted ? const <TaskItem>[] : const <TaskItem>[TaskItem(id: _i1, title: 'Müll')],
      deleted: deleted,
      version: version,
      by: _anna,
      updatedAt: DateTime.utc(2026, 10, 21, 12),
    );

TaskLogEntry _entry(String id, DateTime at) => TaskLogEntry(
      id: id,
      listId: _l1,
      itemId: _i1,
      periodKey: '2026-W43',
      doneOn: '2026-10-22',
      at: at,
      by: _ben,
      comment: 'ok',
    );

void main() {
  late SqlTaskStore store;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    TimeZones.ensureInitialized();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    // Die echten Migrationen (inkl. v4) auf eine leere Datenbank anwenden.
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlTaskStore(db);
  });

  tearDown(() => db.close());

  test('Migration v4 legt die Tabellen an; schemaVersion ist 4', () {
    expect(AppDatabase.schemaVersion, 4);
  });

  test('Liste: speichern, lesen, Version überschreibt, ausstehend/veröffentlicht', () async {
    await store.putList(_list(), publishedVersion: 0);
    expect(await store.getList(_l1), _list());
    expect((await store.pendingLists()).map((l) => l.id), [_l1]);
    await store.markListPublished(_l1, 1);
    expect(await store.pendingLists(), isEmpty);
    await store.putList(_list(version: 2));
    expect((await store.getList(_l1))!.version, 2);
    expect((await store.pendingLists()).single.version, 2, reason: 'neue Version ist wieder ausstehend');
    expect(await store.listCounts(), (active: 1, total: 1));
  });

  test('Löschmarken: nur veröffentlichte werden gekürzt', () async {
    for (var i = 1; i <= 3; i++) {
      final id = '00000000-0000-4000-8000-0000000001${i.toString().padLeft(2, '0')}';
      await store.putList(_list(deleted: true, version: 2, id: id), publishedVersion: i == 3 ? 0 : 2);
    }
    await store.pruneListTombstones(keep: 0);
    expect((await store.lists()).single.id, endsWith('103'), reason: 'unveröffentlichte Löschmarke bleibt');
  });

  test('Protokoll: nur anfügen (Duplikat ändert nichts), Reihenfolge, ausstehend', () async {
    final a = _entry('00000000-0000-4000-8000-0000000000a1', DateTime.utc(2026, 10, 22, 8));
    final b = _entry('00000000-0000-4000-8000-0000000000a2', DateTime.utc(2026, 10, 22, 9));
    await store.addLog(a, published: false);
    await store.addLog(b, published: true);
    await store.addLog(_entry(a.id, DateTime.utc(2026, 10, 22, 23)), published: true); // gleiche ID: wird ignoriert
    expect(await store.hasLog(a.id), isTrue);
    expect(await store.logCount(_l1), 2);
    expect((await store.log(listId: _l1)).map((e) => e.id), [b.id, a.id], reason: 'neueste zuerst');
    expect((await store.log()).last.at, a.at, reason: 'Original unverändert');
    expect((await store.pendingLog()).map((e) => e.id), [a.id]);
    await store.markLogPublished(a.id);
    expect(await store.pendingLog(), isEmpty);
  });

  test('pruneLog entfernt nur veröffentlichte alte Einträge; requeue markiert Eigenes neu', () async {
    for (var i = 0; i < 5; i++) {
      await store.addLog(_entry('00000000-0000-4000-8000-0000000002${i.toString().padLeft(2, '0')}', DateTime.utc(2026, 10, 22, 8 + i)),
          published: i != 0);
    }
    await store.pruneLog(_l1, keep: 2);
    expect(await store.logCount(_l1), 3, reason: '2 neueste + 1 älterer unveröffentlichter');
    await store.requeueLastEditedBy(_ben);
    expect(await store.pendingLog(), hasLength(3));
  });

  test('wipe leert alles', () async {
    await store.putList(_list());
    await store.addLog(_entry('00000000-0000-4000-8000-0000000000a1', DateTime.utc(2026, 10, 22, 8)), published: true);
    await store.wipe();
    expect(await store.lists(), isEmpty);
    expect(await store.log(), isEmpty);
    expect(await store.logTotal(), 0);
  });
}
