import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/features/reminders/reminder_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// #140: Die lokalen Familiendaten gehören genau einem Konto und einer Familie (S7). Der Anspruch läuft gegen die
/// echten Tabellen, damit keine Tabelle vergessen wird.
void main() {
  late Database db;
  const annaA = '@anna:example.org|!a:example.org';
  const annaB = '@anna:example.org|!b:example.org';
  const tables = <String>['events', 'event_history', 'rsvps', 'event_reminders', 'person_colors', 'shopping_items', 'task_lists', 'task_log', 'event_themes', 'anniversaries', 'avatar_photos', 'avatar_resets', 'cash_books', 'cash_entries'];

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
    await db.insert('event_themes', <String, Object?>{'id': 'th1', 'version': 1, 'deleted': 0, 'author': '@anna:example.org', 'data': '{}'});
    await db.insert('anniversaries', <String, Object?>{'id': 'an1', 'version': 1, 'deleted': 0, 'author': '@anna:example.org', 'data': '{}'});
    await db.insert('avatar_photos', <String, Object?>{'room_id': '!f:example.org', 'owner': '@anna:example.org', 'photo_id': '00000000-0000-4000-8000-000000000001', 'created_at': 1, 'cleared': 1});
    await db.insert('avatar_resets', <String, Object?>{'room_id': '!f:example.org', 'target': '@anna:example.org', 'photo_id': '00000000-0000-4000-8000-000000000002', 'photo_created_at': 1});
    await db.insert('cash_books', <String, Object?>{'room_id': '!b:example.org', 'title': 'Haushalt', 'currency': 'EUR', 'owner': '@anna:example.org', 'version': 1});
    await db.insert('cash_entries', <String, Object?>{'room_id': '!b:example.org', 'author': '@anna:example.org', 'id': '11111111-1111-4111-8111-111111111111', 'version': 1, 'deleted': 0, 'data': '{}'});
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

  test('#218 bestätigte Erinnerungen: bei anderem Besitzer gelöscht, bei gleichem behalten', () async {
    Future<bool> has() async => (await db.query('settings', where: 'key = ?', whereArgs: <Object>[ReminderCoordinator.acknowledgedKey])).isNotEmpty;
    await own(annaA);
    await db.insert('settings', <String, Object?>{'key': ReminderCoordinator.acknowledgedKey, 'value': '{"1":9999999999999}'});
    await AppServices.claimFamilyData(db, annaA);
    expect(await has(), isTrue);
    await AppServices.claimFamilyData(db, annaB);
    expect(await has(), isFalse);
  });

  group('#450 Blockierliste gehört zu den lokalen Familiendaten', () {
    const annaX = '@anna:example.org|!a:example.org';
    const benX = '@ben:example.org|!a:example.org';

    Future<void> block() => db.insert('settings', <String, Object?>{'key': AppSettings.blockedUsersKey, 'value': '["@carla:example.org"]'}, conflictAlgorithm: ConflictAlgorithm.replace);

    Future<bool> blocked() async => (await db.query('settings', where: 'key = ?', whereArgs: <Object>[AppSettings.blockedUsersKey])).isNotEmpty;

    test('anderes Konto: Blockierliste weg, Rückgabe true', () async {
      await own(annaX);
      await block();
      expect(await AppServices.claimFamilyData(db, benX), isTrue);
      expect(await blocked(), isFalse);
    });

    test('anderer Besitzer (gleiches Konto, andere Familie): Blockierliste weg, Rückgabe true', () async {
      await own(annaA);
      await block();
      expect(await AppServices.claimFamilyData(db, annaB), isTrue);
      expect(await blocked(), isFalse);
    });

    test('gleicher Besitzer: Blockierliste bleibt, Rückgabe false', () async {
      await own(annaA);
      await block();
      expect(await AppServices.claimFamilyData(db, annaA), isFalse);
      expect(await blocked(), isTrue);
    });

    test('erster Anspruch ohne früheren Besitzer: Blockierliste bleibt, Rückgabe false', () async {
      await block();
      expect(await AppServices.claimFamilyData(db, annaA), isFalse);
      expect(await blocked(), isTrue);
    });

    Future<void> lastChat() => db.insert('settings', <String, Object?>{'key': AppSettings.lastChatThreadKey, 'value': '!dm:example.org'}, conflictAlgorithm: ConflictAlgorithm.replace);

    Future<bool> hasLastChat() async => (await db.query('settings', where: 'key = ?', whereArgs: <Object>[AppSettings.lastChatThreadKey])).isNotEmpty;

    test('#516 anderer Besitzer: gemerktes Gespräch weg; gleicher Besitzer: bleibt', () async {
      await own(annaA);
      await lastChat();
      expect(await AppServices.claimFamilyData(db, annaA), isFalse);
      expect(await hasLastChat(), isTrue);
      expect(await AppServices.claimFamilyData(db, annaB), isTrue);
      expect(await hasLastChat(), isFalse);
    });

    test('Wiederholung nach einem Fehler in onWiped löscht erneut, auch die Blockierliste', () async {
      await own(annaA);
      await block();
      await expectLater(AppServices.claimFamilyData(db, annaB, onWiped: () async => throw StateError('Planung')), throwsA(anything));
      expect(await owner(), annaA, reason: 'Besitzer erst nach erfolgreichem Löschen');
      await block();
      expect(await AppServices.claimFamilyData(db, annaB), isTrue);
      expect(await blocked(), isFalse);
    });
  });
}
