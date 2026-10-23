import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Öffnet verschlüsselte SQLCipher-Datenbanken plattformabhängig (E-50).
///
/// Android/iOS/macOS nutzen `sqflite_sqlcipher`, Linux und Windows `sqflite_common_ffi` mit
/// `libsqlcipher.so` bzw. `sqlcipher.dll`. Beide liefern dieselbe `sqflite`-Schnittstelle.
class EncryptedDb {
  const EncryptedDb._();

  static const _linuxAppId = 'de.inneso.familynexus';

  static bool get _useFfi => Platform.isLinux || Platform.isWindows;

  /// Verzeichnis der Datenbankdateien.
  static Future<String> databasesPath() async {
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
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi.openDatabase(
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
    return ffi.databaseFactoryFfi.deleteDatabase(path);
  }

  /// Setzt den Schlüssel als erste Anweisung. Ein normales SQLite würde
  /// `PRAGMA key` ignorieren und Klartext schreiben, daher wird vorher
  /// geprüft, dass wirklich SQLCipher geladen ist.
  static Future<void> _unlock(Database db, String password) async {
    final version = await db.rawQuery('PRAGMA cipher_version');
    if (version.isEmpty || '${version.first.values.first}'.isEmpty) {
      await db.close();
      throw StateError('SQLCipher nicht verfügbar: Datenbank wird nicht geöffnet.');
    }
    final escaped = password.replaceAll("'", "''");
    await db.execute("PRAGMA key = '$escaped'");
    // Falscher Schlüssel → Fehler beim ersten Lesezugriff.
    await db.rawQuery('SELECT count(*) FROM sqlite_master');
  }
}
