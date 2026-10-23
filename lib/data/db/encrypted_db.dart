import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../core/platform_info.dart';
import 'web/cipher_factory_stub.dart' if (dart.library.js_interop) 'web/cipher_factory_web.dart' as web_factory;

/// Öffnet verschlüsselte SQLCipher-Datenbanken plattformabhängig (E-50, E-52, E-53).
///
/// Android/iOS/macOS nutzen `sqflite_sqlcipher`, Linux und Windows `sqflite_common_ffi` mit
/// `libsqlcipher.so` bzw. `sqlcipher.dll`, der Browser `sqflite_common_ffi_web` mit
/// SQLite3MultipleCiphers (`sqlite3mc.wasm`, Ablage in IndexedDB). Alle liefern dieselbe
/// `sqflite`-Schnittstelle.
class EncryptedDb {
  const EncryptedDb._();

  static const _linuxAppId = 'de.inneso.familynexus';

  /// Browser: Dateien liegen nur im IndexedDB-Speicher dieser Ursprungsadresse.
  static const _webWasm = 'sqlite3mc.wasm';
  static const _webIndexedDb = 'familynexus';
  static DatabaseFactory? _webFactory;

  static bool get _useFfi => PlatformInfo.usesFfiDatabase;

  static DatabaseFactory get _factory {
    if (PlatformInfo.isWeb) {
      // Hauptthread statt Shared Worker: die Datei `sqlite3mc.wasm` kommt aus dem eigenen Ursprung.
      return _webFactory ??= web_factory.createCipherWebFactory(wasmPath: _webWasm, indexedDbName: _webIndexedDb);
    }
    return ffi.databaseFactoryFfi;
  }

  /// Verzeichnis der Datenbankdateien.
  static Future<String> databasesPath() async {
    if (PlatformInfo.isWeb) return '';
    if (!_useFfi) return getDatabasesPath();
    final env = Platform.environment;
    final String base;
    if (Platform.isWindows) {
      // %LOCALAPPDATA%: nicht im Roaming-Profil, die Datenbank bleibt auf dem Gerät.
      final local = env['LOCALAPPDATA'];
      base = (local != null && local.isNotEmpty) ? local : p.join(env['USERPROFILE'] ?? '.', 'AppData', 'Local');
    } else {
      final xdg = env['XDG_DATA_HOME'];
      base = (xdg != null && xdg.isNotEmpty) ? xdg : p.join(env['HOME'] ?? '.', '.local', 'share');
    }
    final dir = Directory(p.join(base, _linuxAppId, 'databases'));
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Gibt es die Datenbank schon?
  static Future<bool> exists(String path) async {
    if (PlatformInfo.isWeb) return _factory.databaseExists(path);
    return File(path).existsSync();
  }

  static Future<Database> open(
    String path, {
    required String password,
    required int version,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseVersionChangeFn? onDowngrade,
  }) {
    if (!_useFfi) {
      return openDatabase(
        path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onDowngrade: onDowngrade,
      );
    }
    if (!PlatformInfo.isWeb) ffi.sqfliteFfiInit();
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => _unlock(db, password),
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onDowngrade: onDowngrade,
      ),
    );
  }

  static Future<void> delete(String path) {
    if (!_useFfi) return deleteDatabase(path);
    return _factory.deleteDatabase(path);
  }

  /// Setzt den Schlüssel als erste Anweisung. Ein normales SQLite würde
  /// `PRAGMA key` ignorieren und Klartext schreiben, daher wird vorher
  /// geprüft, dass wirklich eine Verschlüsselung geladen ist.
  static Future<void> _unlock(Database db, String password) async {
    final escaped = password.replaceAll("'", "''");
    // Browser: SQLite3MultipleCiphers liest die Datei erst nach dem Schlüssel; ohne Verschlüsselung würde das
    // PRAGMA nur ignoriert, die Prüfung danach fängt das ab, bevor etwas geschrieben wird.
    if (PlatformInfo.isWeb) await db.execute("PRAGMA key = '$escaped'");
    if (!await _hasCipher(db)) {
      await db.close();
      throw StateError('SQLCipher nicht verfügbar: Datenbank wird nicht geöffnet.');
    }
    if (!PlatformInfo.isWeb) await db.execute("PRAGMA key = '$escaped'");
    // Falscher Schlüssel → Fehler beim ersten Lesezugriff.
    await db.rawQuery('SELECT count(*) FROM sqlite_master');
  }

  static Future<bool> _hasCipher(Database db) async {
    if (!PlatformInfo.isWeb) {
      final version = await db.rawQuery('PRAGMA cipher_version');
      return version.isNotEmpty && '${version.first.values.first}'.isNotEmpty;
    }
    // SQLite3MultipleCiphers kennt kein `cipher_version`, dafür die Funktion `sqlite3mc_version()`.
    try {
      final version = await db.rawQuery('SELECT sqlite3mc_version() AS v');
      return version.isNotEmpty && '${version.first.values.first}'.isNotEmpty;
    } catch (e) {
      // Falscher Schlüssel: die Datei ist mit diesem Schlüssel nicht lesbar (kein fehlendes Verfahren).
      if ('$e'.contains('file is not a database')) rethrow;
      AppLog.e('db', 'SQLite3MultipleCiphers nicht verfügbar', e);
      return false;
    }
  }
}
