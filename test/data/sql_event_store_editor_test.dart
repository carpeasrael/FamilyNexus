import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_event_store.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/events.dart';

/// #431, E-112: `editorId` überlebt die SQL-Ablage (Termin und Verlauf); ein später herabgestufter Moderator lässt den
/// Termin nicht verschwinden (Lesen ohne Rollenprüfung).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    TimeZones.ensureInitialized();
  });

  late Database db;
  late SqlEventStore store;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlEventStore(db);
  });

  tearDown(() => db.close());

  test('Rundlauf mit editor; Verlauf behält editor je Fassung; Besitzerfassung löscht ihn', () async {
    const mod = '@cara:fake.test';
    final v1 = ev(version: 1);
    await store.put(v1, publishedVersion: 1);
    final v2 = ev(version: 2, title: 'M').copyWith(editorId: mod);
    await store.put(v2, replaced: v1);
    expect((await store.get(kId1))!.editorId, mod);
    final v3 = ev(version: 3, title: 'O');
    await store.put(v3, replaced: v2, publishedVersion: 3);
    expect((await store.get(kId1))!.editorId, isNull);
    final history = await store.history(kId1);
    expect(history.map((e) => (e.version, e.editorId)), <(int, String?)>[(2, mod), (1, null)]);
  });

  test('Moderatorfassung wartet in pendingPublish, bis sie veröffentlicht ist (published bleibt)', () async {
    const mod = '@cara:fake.test';
    await store.put(ev(version: 1), publishedVersion: 1);
    await store.put(ev(version: 2).copyWith(editorId: mod), replaced: ev(version: 1));
    expect((await store.pendingPublish()).single.editorId, mod);
    await store.markPublished(kId1, 2);
    expect(await store.pendingPublish(), isEmpty);
  });
}
