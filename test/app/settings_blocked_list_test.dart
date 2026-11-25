import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/app/bootstrap.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:family_nexus/features/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

/// #119, K2c (E-114): Der Adapter zur Blockierliste (echte Einstellungen) und der Ablauf bei einem Familienwechsel.
void main() {
  setUpAll(sqfliteFfiInit);

  Future<(SettingsController, SettingsBlockedList)> make([List<String> initial = const <String>[]]) async {
    final kv = MemoryKeyValueStore();
    final settings = await SettingsController.load(kv);
    if (initial.isNotEmpty) await settings.update((c) => c.copyWith(blockedUsers: initial));
    return (settings, SettingsBlockedList(settings));
  }

  test('lesen und eintragen: nur hinzufügen, Dubletten und ungültige IDs ändern nichts', () async {
    final (settings, port) = await make(<String>['@lokal:example.org']);
    expect(port.blocked, <String>{'@lokal:example.org'});
    await port.add(<String>['@ben:example.org', '@lokal:example.org', 'kein-konto']);
    expect(settings.settings.blockedUsers, <String>['@lokal:example.org', '@ben:example.org']);
    await port.add(const <String>[]);
    expect(settings.settings.blockedUsers, hasLength(2));
  });

  test('zurücknehmen (Entsperren): nur die genannten Kennungen, Unbekanntes ändert nichts', () async {
    final (settings, port) = await make(<String>['@lokal:example.org', '@ben:example.org']);
    await port.remove(<String>['@ben:example.org', '@unbekannt:example.org']);
    expect(settings.settings.blockedUsers, <String>['@lokal:example.org']);
    await port.remove(const <String>[]);
    await port.remove(<String>['@unbekannt:example.org']);
    expect(settings.settings.blockedUsers, <String>['@lokal:example.org']);
    expect(port.blocked, <String>{'@lokal:example.org'});
  });

  test('die Obergrenze der Liste bleibt erhalten', () async {
    final (settings, port) = await make(<String>[for (var i = 0; i < BlockedUsers.maxEntries; i++) '@v$i:example.org']);
    await port.add(<String>['@ben:example.org']);
    expect(settings.settings.blockedUsers, hasLength(BlockedUsers.maxEntries));
    expect(settings.settings.blockedUsers, isNot(contains('@ben:example.org')));
  });

  test('Ausgangslage der Wiederherstellung: claimFamilyData löscht die Liste bei Familienwechsel (der Abgleich aus den Datensätzen: contact_sync_test)', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    addTearDown(db.close);
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    // Kontaktdatensatz „blockiert“ liegt in der Ablage; die Blockierliste steht in den Einstellungen.
    await db.insert('settings', <String, Object?>{'key': AppServices.calendarOwnerKey, 'value': '@anna:example.org|!a:example.org'});
    await db.insert('settings', <String, Object?>{'key': AppSettings.blockedUsersKey, 'value': '@ben:example.org'});
    final wiped = await AppServices.claimFamilyData(db, '@anna:example.org|!b:example.org');
    expect(wiped, isTrue);
    final stored = {for (final r in await db.query('settings')) r['key']: r['value']};
    expect(stored.containsKey(AppSettings.blockedUsersKey), isFalse, reason: 'die Liste gehört den Familiendaten und ist gelöscht');
  });
}
