import 'dart:io';

import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_data_inventory.dart';
import 'package:family_nexus/domain/data_inventory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

void main() {
  late Database db;
  late Directory dir;
  late MemoryKeyStore keys;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    dir = await Directory.systemTemp.createTemp('fn_inventory');
    keys = MemoryKeyStore();
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  SqlDataInventory inventory() => SqlDataInventory(
        db: db,
        keyStore: keys,
        appFileName: 'app.db',
        matrixFileName: 'matrix.db',
        keyNames: const <String>['db.app', 'db.matrix'],
        directory: dir.path,
      );

  test('erfasst jede Tabelle der App-Datenbank (auch künftige Migrationen)', () async {
    final rows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
    expect(SqlDataInventory.tables.toSet(), <String>{for (final r in rows) r['name']! as String});
  });

  test('liefert Pfade, Zeilen, Dateigrößen und nur das Vorhandensein der Schlüssel', () async {
    await db.insert('settings', <String, Object?>{'key': 'language', 'value': 'de'});
    final secret = await keys.getOrCreateKey('db.app');
    File(p.join(dir.path, 'app.db')).writeAsBytesSync(List<int>.filled(2048, 0));

    final inv = await inventory().read();

    expect(inv.locations.databaseDirectory, dir.path);
    expect(inv.locations.appDatabase, p.join(dir.path, 'app.db'));
    expect(inv.locations.matrixDatabase, p.join(dir.path, 'matrix.db'));
    expect(
      inv.locations.keyStore,
      Platform.isMacOS || Platform.isIOS
          ? KeyStoreKind.appleKeychain
          : Platform.isWindows
              ? KeyStoreKind.windowsCredentialManager
              : Platform.isAndroid
                  ? KeyStoreKind.androidKeystore
                  : KeyStoreKind.linuxSecretService,
    );
    expect(inv.appDatabaseBytes, 2048);
    expect(inv.matrixDatabaseBytes, isNull, reason: 'Datei fehlt');
    expect(inv.tables.map((t) => t.name), SqlDataInventory.tables);
    expect(inv.tables.first.rows.single, <String, Object?>{'key': 'language', 'value': 'de'});
    expect(<String, bool>{for (final k in inv.keys) k.name: k.present}, <String, bool>{'db.app': true, 'db.matrix': false});
    expect(inv.keys.map((k) => '${k.name}${k.present}').join(), isNot(contains(secret)));
  });

  group('Schlüsselablage unter Linux (#169, E-50)', () {
    test('Flatpak wird an FLATPAK_ID oder /.flatpak-info erkannt', () {
      expect(
        SqlDataInventory.linuxKeyStoreKind(environment: <String, String>{'FLATPAK_ID': 'de.inneso.familynexus'}, fileExists: (_) => false),
        KeyStoreKind.linuxFlatpakPortal,
      );
      expect(
        SqlDataInventory.linuxKeyStoreKind(environment: <String, String>{}, fileExists: (p) => p == '/.flatpak-info'),
        KeyStoreKind.linuxFlatpakPortal,
      );
    });

    test('ohne Flatpak bleibt es der Secret Service des Systems', () {
      expect(
        SqlDataInventory.linuxKeyStoreKind(environment: <String, String>{}, fileExists: (_) => false),
        KeyStoreKind.linuxSecretService,
      );
      expect(
        SqlDataInventory.linuxKeyStoreKind(environment: <String, String>{'FLATPAK_ID': ''}, fileExists: (_) => false),
        KeyStoreKind.linuxSecretService,
      );
    });
  });
}
