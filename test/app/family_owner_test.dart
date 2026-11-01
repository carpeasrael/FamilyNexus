import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// #140: Die lokalen Familiendaten gehören genau einem Konto und einer Familie (S7). Der Anspruch läuft gegen die
/// echten Tabellen, damit keine Tabelle vergessen wird.
void main() {
  late Database db;
  const annaA = '@anna:example.org|!a:example.org';
  const annaB = '@anna:example.org|!b:example.org';
  const tables = <String>['events', 'event_history', 'rsvps', 'event_reminders', 'person_colors', 'shopping_items', 'task_lists', 'task_log'];

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
  });

  tearDown(() => db.close());

  Future<void> fill() async {
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

  Future<void> own(String owner) => db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': owner}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> rows(String table) async => (await db.query(table)).length;

  Future<String?> owner() async {
    final r = await db.query('settings', where: 'key = ?', whereArgs: <Object>[AppServices.calendarOwnerKey]);
    return r.isEmpty ? null : r.single['value'] as String?;
  }

  Future<void> expectFilled() async {
    for (final t in tables) {
      expect(await rows(t), 1, reason: t);
    }
  }

  Future<void> expectEmpty() async {
    for (final t in tables) {
      expect(await rows(t), 0, reason: t);
    }
    expect((await db.query('settings', where: 'key = ?', whereArgs: <Object>['languageCode'])).single['value'], 'de', reason: 'Einstellungen bleiben');
  }

  test('gleicher Besitzer: nichts gelöscht, kein onWiped', () async {
    await fill();
    await own(annaA);
    var wiped = 0;
    await AppServices.claimFamilyData(db, annaA, onWiped: () async => wiped++);
    await expectFilled();
    expect(wiped, 0);
    expect(await owner(), annaA);
  });

  test('anderer Raum: Termine, Einkauf und Aufgaben gelöscht, onWiped einmal, Besitzer neu', () async {
    await fill();
    await own(annaA);
    var wiped = 0;
    await AppServices.claimFamilyData(db, annaB, onWiped: () async => wiped++);
    await expectEmpty();
    expect(wiped, 1);
    expect(await owner(), annaB);
  });

  test('anderer Nutzer: gelöscht', () async {
    await fill();
    await own(annaA);
    await AppServices.claimFamilyData(db, '@ben:example.org|!a:example.org');
    await expectEmpty();
  });

  test('kein Vorbesitzer: nichts gelöscht, kein onWiped, Besitzer gesetzt', () async {
    await fill();
    var wiped = 0;
    await AppServices.claimFamilyData(db, annaA, onWiped: () async => wiped++);
    await expectFilled();
    expect(wiped, 0);
    expect(await owner(), annaA);
  });

  test('Fehler im Löschen: Besitzer unverändert, der nächste Aufruf löscht', () async {
    await fill();
    await own(annaA);
    await expectLater(
      AppServices.claimFamilyData(db, annaB, onWiped: () async => throw StateError('Planung nicht erreichbar')),
      throwsStateError,
    );
    expect(await owner(), annaA, reason: 'sonst gälte der halbe Bestand als Bestand von B');

    await db.insert('events', <String, Object?>{'id': 'e2', 'owner': '@anna:example.org', 'visibility': 'private', 'version': 1, 'deleted': 0, 'data': '{}'});
    var wiped = 0;
    await AppServices.claimFamilyData(db, annaB, onWiped: () async => wiped++);
    expect(await rows('events'), 0);
    expect(wiped, 1);
    expect(await owner(), annaB);
  });

  test('Fehler in einer Tabelle: Besitzer unverändert', () async {
    await fill();
    await own(annaA);
    await db.execute('DROP TABLE task_log');
    await expectLater(AppServices.claimFamilyData(db, annaB), throwsA(anything));
    expect(await owner(), annaA);
  });

  test('Wiederbeitritt: Anspruch für dieselbe Familie löscht nicht, und A → B → A löscht je Wechsel', () async {
    await fill();
    await own(annaA);
    await AppServices.claimFamilyData(db, annaA);
    await AppServices.claimFamilyData(db, annaA);
    await expectFilled();

    await AppServices.claimFamilyData(db, annaB);
    await expectEmpty();
    await db.insert('events', <String, Object?>{'id': 'e3', 'owner': '@anna:example.org', 'visibility': 'private', 'version': 1, 'deleted': 0, 'data': '{}'});
    await AppServices.claimFamilyData(db, annaA);
    expect(await rows('events'), 0, reason: 'Daten von B gehören nicht zu A');
    expect(await owner(), annaA);
  });
}
