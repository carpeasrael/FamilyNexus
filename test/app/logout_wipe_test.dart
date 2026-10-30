import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pen-Test F-02: Nach dem Ende der Sitzung dürfen keine Familiendaten des Kontos auf dem Gerät bleiben.
void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
  });

  tearDown(() => db.close());

  Future<void> fill() async {
    await db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': '@anna:example.org|!f:example.org'});
    await db.insert('settings', <String, Object?>{'key': 'languageCode', 'value': 'de'});
    await db.insert('events', <String, Object?>{'id': 'e1', 'owner': '@anna:example.org', 'visibility': 'private', 'version': 1, 'deleted': 0, 'data': '{"title":"Arzt"}'});
    await db.insert('event_history', <String, Object?>{'id': 'e1', 'version': 1, 'updated_ms': 1, 'owner': '@anna:example.org', 'visibility': 'private', 'data': '{}'});
    await db.insert('rsvps', <String, Object?>{'event_id': 'e1', 'user_id': '@anna:example.org', 'status': 'yes', 'ts': 1});
    await db.insert('event_reminders', <String, Object?>{'event_id': 'e1', 'minutes': '15'});
    await db.insert('person_colors', <String, Object?>{'user_id': '@anna:example.org', 'color': 1});
    await db.insert('shopping_items', <String, Object?>{'id': 's1', 'version': 1, 'deleted': 0, 'author': '@anna:example.org', 'data': '{}'});
    await db.insert('task_lists', <String, Object?>{'id': 't1', 'version': 1, 'deleted': 0, 'author': '@anna:example.org', 'data': '{}'});
    await db.insert('task_log', <String, Object?>{'id': 'l1', 'list_id': 't1', 'at_ms': 1, 'author': '@anna:example.org', 'data': '{}'});
  }

  Future<int> rows(String table) async => (await db.query(table)).length;

  test('entfernt Termine, Einkaufszettel, Aufgaben und den Besitzer; Einstellungen bleiben', () async {
    await fill();
    await AppServices.wipeAccountDataIn(db);
    for (final t in <String>['events', 'event_history', 'rsvps', 'event_reminders', 'person_colors', 'shopping_items', 'task_lists', 'task_log']) {
      expect(await rows(t), 0, reason: t);
    }
    final settings = {for (final r in await db.query('settings')) r['key']: r['value']};
    expect(settings.containsKey(AppServices.calendarOwnerKey), isFalse);
    expect(settings['languageCode'], 'de');
  });

  test('ohne frühere Anmeldung (kein Besitzer) bleibt alles unangetastet', () async {
    await fill();
    await db.delete('settings', where: 'key = ?', whereArgs: <Object>[AppServices.calendarOwnerKey]);
    await AppServices.wipeAccountDataIn(db);
    expect(await rows('events'), 1);
  });
}
