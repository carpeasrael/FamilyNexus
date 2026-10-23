import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../platform/key_store.dart';
import 'encrypted_db.dart';

/// Der Datenbankschlüssel fehlt oder ist nicht mehr lesbar, obwohl die
/// Datenbankdatei existiert. Es wird bewusst **kein** neuer Schlüssel erzeugt,
/// weil sonst die vorhandenen Daten unlesbar überschrieben würden.
class KeyLostException implements Exception {
  const KeyLostException();
  @override
  String toString() => 'KeyLostException';
}

/// Verschlüsselte App-Datenbank (SQLCipher, AES-256).
///
/// Das Passwort stammt aus dem [KeyStore] (Android Keystore, Schlüsselbund bzw.
/// Secret Service unter Linux). Ohne dieses
/// Passwort ist die Datei nicht lesbar.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const String keyName = 'db.app';
  static const String fileName = 'familynexus_app.db';

  /// Migrationen: Index i bringt die Datenbank von Version i auf i+1.
  /// Nie nachträglich ändern, nur anhängen.
  static final List<Future<void> Function(Database)> migrations =
      <Future<void> Function(Database)>[
    (db) async {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        )''');
    },
    // v2: Kalender (Phase 3)
    (db) async {
      await db.execute('''
        CREATE TABLE events (
          id TEXT PRIMARY KEY NOT NULL,
          owner TEXT NOT NULL,
          visibility TEXT NOT NULL,
          version INTEGER NOT NULL,
          published INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL,
          data TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE event_history (
          id TEXT NOT NULL,
          version INTEGER NOT NULL,
          updated_ms INTEGER NOT NULL,
          owner TEXT NOT NULL,
          visibility TEXT NOT NULL,
          data TEXT NOT NULL,
          PRIMARY KEY (id, version, updated_ms)
        )''');
      await db.execute('''
        CREATE TABLE rsvps (
          event_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          status TEXT NOT NULL,
          ts INTEGER NOT NULL,
          published INTEGER NOT NULL DEFAULT 1,
          PRIMARY KEY (event_id, user_id)
        )''');
      await db.execute('''
        CREATE TABLE event_reminders (
          event_id TEXT PRIMARY KEY NOT NULL,
          minutes TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE person_colors (
          user_id TEXT PRIMARY KEY NOT NULL,
          color INTEGER NOT NULL
        )''');
    },
    // v3: Einkaufszettel (Phase 6, E-40)
    (db) async {
      await db.execute('''
        CREATE TABLE shopping_items (
          id TEXT PRIMARY KEY NOT NULL,
          version INTEGER NOT NULL,
          published INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL,
          author TEXT NOT NULL,
          data TEXT NOT NULL
        )''');
    },
    // v4: Aufgabenlisten und Protokoll (E-51)
    (db) async {
      await db.execute('''
        CREATE TABLE task_lists (
          id TEXT PRIMARY KEY NOT NULL,
          version INTEGER NOT NULL,
          published INTEGER NOT NULL DEFAULT 0,
          deleted INTEGER NOT NULL,
          author TEXT NOT NULL,
          data TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE task_log (
          id TEXT PRIMARY KEY NOT NULL,
          list_id TEXT NOT NULL,
          at_ms INTEGER NOT NULL,
          published INTEGER NOT NULL DEFAULT 0,
          author TEXT NOT NULL,
          data TEXT NOT NULL
        )''');
      await db.execute('CREATE INDEX task_log_list ON task_log (list_id, at_ms)');
    },
  ];

  static int get schemaVersion => migrations.length;

  static Future<AppDatabase> open({
    required KeyStore keyStore,
    String? directory,
    String name = fileName,
  }) async {
    final dir = directory ?? await EncryptedDb.databasesPath();
    final path = p.join(dir, name);
    final key = await resolveKey(keyStore: keyStore, keyName: keyName, path: path);
    return openWithKey(path: path, key: key);
  }

  /// Liefert den Schlüssel für [path]. Existiert die Datei bereits, wird der
  /// Schlüssel nur gelesen; fehlt er, wird nie ein neuer erzeugt ([KeyLostException]).
  static Future<String> resolveKey({
    required KeyStore keyStore,
    required String keyName,
    required String path,
  }) async {
    if (await EncryptedDb.exists(path)) {
      final existing = await keyStore.readKey(keyName);
      if (existing == null) throw const KeyLostException();
      return existing;
    }
    return keyStore.getOrCreateKey(keyName);
  }

  static Future<AppDatabase> openWithKey({
    required String path,
    required String key,
  }) async {
    final db = await EncryptedDb.open(
      path,
      password: key,
      version: schemaVersion,
      onCreate: (db, version) async {
        for (var i = 0; i < version; i++) {
          await migrations[i](db);
        }
      },
      onUpgrade: (db, from, to) async {
        for (var i = from; i < to; i++) {
          await migrations[i](db);
        }
      },
      onDowngrade: (db, from, to) =>
          throw StateError('Datenbank-Downgrade nicht unterstützt ($from→$to)'),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  /// Löscht die Datei vollständig (Konto-/Datenlöschung).
  static Future<void> destroy({String? directory, String name = fileName}) async {
    final dir = directory ?? await EncryptedDb.databasesPath();
    await EncryptedDb.delete(p.join(dir, name));
  }
}
