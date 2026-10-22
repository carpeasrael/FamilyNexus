import 'dart:io';

import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/key_value_store.dart';
import 'package:family_nexus/data/db/sql_event_store.dart';
import 'package:family_nexus/data/db/sql_shopping_store.dart';
import 'package:family_nexus/data/db/sql_task_store.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

CalendarEvent _ev(String id, {int version = 1, String title = 'Test', bool shared = true, bool deleted = false}) => CalendarEvent(
      id: id,
      ownerId: '@anna:fake.test',
      version: version,
      title: title,
      start: DateTime.utc(2026, 11, 2, 9),
      end: DateTime.utc(2026, 11, 2, 10),
      timeZone: 'Europe/Berlin',
      updatedAt: DateTime.utc(2026, 11, 1, 12, 0, version),
      visibility: shared ? EventVisibility.shared : EventVisibility.private,
      deleted: deleted,
      recurrence: const Recurrence(frequency: Frequency.weekly, weekdays: <int>{1, 3}, count: 4, exdates: <String>{'2026-11-04'}),
      attendees: const <String>['@ben:fake.test'],
    );

const _id1 = '11111111-1111-4111-8111-111111111111';
const _id2 = '22222222-2222-4222-8222-222222222222';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  TimeZones.ensureInitialized();

  late Directory dir;
  late AppDatabase db;
  late SqlEventStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_store');
    db = await AppDatabase.openWithKey(path: p.join(dir.path, 'a.db'), key: 'test-key-123456');
    store = SqlEventStore(db.db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets('speichern, lesen, Verlauf, Wiederherstellung aller Felder', (tester) async {
    final v1 = _ev(_id1, title: 'Alt');
    final v2 = _ev(_id1, version: 2, title: 'Neu');
    await store.put(v1, publishedVersion: 1);
    await store.put(v2, replaced: v1, publishedVersion: 1);
    expect(await store.get(_id1), v2);
    expect((await store.history(_id1)).single, v1);
    expect((await store.all()), <CalendarEvent>[v2]);
    expect(await store.get(_id2), isNull);
  });

  testWidgets('Warteschlange: unveröffentlichte Versionen, Markierung', (tester) async {
    await store.put(_ev(_id1), publishedVersion: 0);
    await store.put(_ev(_id2, shared: false), publishedVersion: 1);
    expect((await store.pendingPublish()).map((e) => e.id), <String>[_id1]);
    await store.markPublished(_id1, 1);
    expect(await store.pendingPublish(), isEmpty);
    await store.put(_ev(_id1, version: 2), replaced: _ev(_id1), publishedVersion: null);
    expect((await store.pendingPublish()).single.version, 2);
    await store.markPublished(_id1, 1); // nie rückwärts
    expect((await store.pendingPublish()).single.version, 2);
  });

  testWidgets('addHistory legt nur in den Verlauf', (tester) async {
    await store.put(_ev(_id1, version: 2, title: 'Aktuell'));
    await store.addHistory(_ev(_id1, title: 'Alt'));
    expect((await store.get(_id1))!.title, 'Aktuell');
    expect((await store.history(_id1)).single.title, 'Alt');
    await store.addHistory(_ev(_id1, title: 'Alt')); // doppelt → ignoriert
    expect(await store.history(_id1), hasLength(1));
  });

  testWidgets('Erinnerungen, Zusagen (neueste gewinnt, Warteschlange), Farben', (tester) async {
    await store.setReminders(_id1, <int>[10, 60]);
    await store.setReminders(_id2, <int>[]);
    expect(await store.reminders(), <String, List<int>>{_id1: <int>[10, 60], _id2: <int>[]});
    await store.setReminders(_id1, null);
    expect((await store.reminders()).containsKey(_id1), isFalse);

    final t = DateTime.utc(2026, 11, 1);
    await store.putRsvp(_id1, '@ben:fake.test', RsvpStatus.accepted, t);
    await store.putRsvp(_id1, '@ben:fake.test', RsvpStatus.declined, t.subtract(const Duration(minutes: 1)));
    expect((await store.rsvps())[_id1]!['@ben:fake.test'], RsvpStatus.accepted);
    await store.putRsvp(_id1, '@anna:fake.test', RsvpStatus.maybe, t, published: false);
    final pend = await store.pendingRsvps('@anna:fake.test');
    expect(pend.single.status, RsvpStatus.maybe);
    await store.markRsvpPublished(_id1, '@anna:fake.test', pend.single.timestamp);
    expect(await store.pendingRsvps('@anna:fake.test'), isEmpty);

    await store.setPersonColor('@ben:fake.test', 3);
    expect(await store.personColors(), <String, int>{'@ben:fake.test': 3});
  });

  testWidgets('wipe entfernt alles', (tester) async {
    await store.put(_ev(_id1));
    await store.addHistory(_ev(_id1, title: 'x'));
    await store.setReminders(_id1, <int>[5]);
    await store.putRsvp(_id1, '@ben:fake.test', RsvpStatus.maybe, DateTime.utc(2026));
    await store.setPersonColor('@ben:fake.test', 1);
    await store.wipe();
    expect(await store.all(), isEmpty);
    expect(await store.history(_id1), isEmpty);
    expect(await store.reminders(), isEmpty);
    expect(await store.rsvps(), isEmpty);
    expect(await store.personColors(), isEmpty);
  });

  testWidgets('Termindaten liegen nur verschlüsselt auf dem Gerät', (tester) async {
    await store.put(_ev(_id1, title: 'GEHEIMER-KALENDERTITEL'));
    await db.close();
    final bytes = File(p.join(dir.path, 'a.db')).readAsBytesSync();
    expect(String.fromCharCodes(bytes).contains('GEHEIMER-KALENDERTITEL'), isFalse);
    db = await AppDatabase.openWithKey(path: p.join(dir.path, 'a.db'), key: 'test-key-123456');
    store = SqlEventStore(db.db);
    expect((await store.get(_id1))!.title, 'GEHEIMER-KALENDERTITEL');
  });

  testWidgets('Migration v1 → v2 erhält Einstellungen und legt Kalendertabellen an', (tester) async {
    final path = p.join(dir.path, 'm.db');
    const key = 'migration-key-1234';
    final v1 = await openDatabase(path, password: key, version: 1, onCreate: (d, v) => AppDatabase.migrations[0](d));
    await v1.insert('settings', <String, Object?>{'key': 'language', 'value': 'de'});
    await v1.close();

    final upgraded = await AppDatabase.openWithKey(path: path, key: key);
    expect((await SqlKeyValueStore(upgraded.db).readAll())['language'], 'de');
    final s = SqlEventStore(upgraded.db);
    await s.put(_ev(_id1));
    expect(await s.all(), hasLength(1));
    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
    await upgraded.close();
  });

  testWidgets('Einkaufszettel: speichern, Warteschlange, Zählung, Wiederholung, Löschen – verschlüsselt auf der Platte', (tester) async {
    final shop = SqlShoppingStore(db.db);
    ShoppingItem item(String id, {String title = 'GEHEIME-MILCH', int version = 1, bool deleted = false, String by = '@anna:fake.test'}) => ShoppingItem(
          id: id,
          title: deleted ? '' : title,
          quantity: deleted ? '' : '2 Liter',
          by: by,
          version: version,
          deleted: deleted,
          updatedAt: DateTime.utc(2026, 11, 1, 12, 0, version),
        );
    await shop.put(item(_id1), publishedVersion: 0);
    await shop.put(item(_id2, by: '@ben:fake.test'), publishedVersion: 1);
    expect((await shop.pendingPublish()).map((i) => i.id), <String>[_id1]);
    expect(await shop.counts(), (active: 2, total: 2));
    await shop.markPublished(_id1, 1);
    expect(await shop.pendingPublish(), isEmpty);
    await shop.requeueLastEditedBy('@anna:fake.test');
    expect((await shop.pendingPublish()).map((i) => i.id), <String>[_id1], reason: 'nur Einträge des letzten Bearbeiters');
    await shop.put(item(_id1, version: 2, deleted: true));
    expect(await shop.counts(), (active: 1, total: 2));
    expect((await shop.get(_id1))!.deleted, isTrue);
    expect((await shop.pendingPublish()).single.version, 2, reason: 'Änderung bleibt vorgemerkt, Veröffentlichungsstand erhalten');
    await shop.requeueLastEditedBy('@anna:fake.test');
    expect(await shop.pendingPublish(), hasLength(1), reason: 'Löschmarken werden nicht erneut vorgemerkt');

    await db.close();
    final bytes = File(p.join(dir.path, 'a.db')).readAsBytesSync();
    expect(String.fromCharCodes(bytes).contains('GEHEIME-MILCH'), isFalse);
    db = await AppDatabase.openWithKey(path: p.join(dir.path, 'a.db'), key: 'test-key-123456');
    expect((await SqlShoppingStore(db.db).get(_id2))!.title, 'GEHEIME-MILCH');
    await SqlShoppingStore(db.db).wipe();
    expect(await SqlShoppingStore(db.db).all(), isEmpty);
  });

  testWidgets('Migration v2 → v3 legt die Einkaufstabelle an und erhält Termine', (tester) async {
    final path = p.join(dir.path, 'm3.db');
    const key = 'migration-key-1234';
    final v2 = await openDatabase(path, password: key, version: 2, onCreate: (d, v) async {
      await AppDatabase.migrations[0](d);
      await AppDatabase.migrations[1](d);
    });
    await SqlEventStore(v2).put(_ev(_id1, title: 'Bleibt'));
    await v2.close();

    final upgraded = await AppDatabase.openWithKey(path: path, key: key);
    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
    expect((await SqlEventStore(upgraded.db).get(_id1))!.title, 'Bleibt');
    expect(await SqlShoppingStore(upgraded.db).all(), isEmpty);
    await upgraded.close();
  });

  testWidgets('Migration v3 → v4 legt die Aufgabentabellen an und erhält Termine', (tester) async {
    final path = p.join(dir.path, 'm4.db');
    const key = 'migration-key-5678';
    final v3 = await openDatabase(path, password: key, version: 3, onCreate: (d, v) async {
      for (var i = 0; i < 3; i++) {
        await AppDatabase.migrations[i](d);
      }
    });
    await SqlEventStore(v3).put(_ev(_id1, title: 'Bleibt'));
    await v3.close();

    final upgraded = await AppDatabase.openWithKey(path: path, key: key);
    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
    expect((await SqlEventStore(upgraded.db).get(_id1))!.title, 'Bleibt');
    final tasks = SqlTaskStore(upgraded.db);
    expect(await tasks.lists(), isEmpty);
    expect(await tasks.log(), isEmpty);
    await upgraded.close();
  });
}
