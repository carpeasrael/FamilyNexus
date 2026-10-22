import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Öffnet verschlüsselte SQLCipher-Datenbanken plattformabhängig (E-50).
///
/// Android/iOS/macOS nutzen `sqflite_sqlcipher`, Linux `sqflite_common_ffi` mit
/// der System-Bibliothek `libsqlcipher.so`. Beide liefern dieselbe
/// `sqflite`-Schnittstelle.
class EncryptedDb {
  const EncryptedDb._();

  static const _linuxAppId = 'de.inneso.familynexus';

  static bool get _useFfi => Platform.isLinux;

  /// Verzeichnis der Datenbankdateien.
  static Future<String> databasesPath() async {
    if (!_useFfi) return getDatabasesPath();
    final env = Platform.environment;
    final xdg = env['XDG_DATA_HOME'];
    final base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : p.join(env['HOME'] ?? '.', '.local', 'share');
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
