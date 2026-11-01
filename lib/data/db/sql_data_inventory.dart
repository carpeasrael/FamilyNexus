import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/platform_info.dart';
import '../../domain/data_inventory.dart';
import '../platform/key_store.dart';
import 'encrypted_db.dart';

/// Liest Speicherorte und Inhalt der App-Datenbank für das Datenprotokoll. Schlüsselwerte werden
/// nie herausgegeben, nur ob sie vorhanden sind.
class SqlDataInventory implements LocalDataInventory {
  SqlDataInventory({
    required this._db,
    required this._keyStore,
    required this.appFileName,
    required this.matrixFileName,
    required this.keyNames,
    this._directory,
  });

  final Database _db;
  final KeyStore _keyStore;
  final String? _directory;
  final String appFileName;
  final String matrixFileName;
  final List<String> keyNames;

  /// Tabellen der App-Datenbank in Ausgabereihenfolge (siehe `AppDatabase.migrations`).
  static const List<String> tables = <String>[
    'settings',
    'events',
    'event_history',
    'rsvps',
    'event_reminders',
    'person_colors',
    'shopping_items',
    'task_lists',
    'task_log',
  ];

  static KeyStoreKind get _keyStoreKind {
    if (PlatformInfo.isWeb) return KeyStoreKind.browserVault;
    if (Platform.isAndroid) return KeyStoreKind.androidKeystore;
    if (Platform.isIOS || Platform.isMacOS) return KeyStoreKind.appleKeychain;
    if (Platform.isWindows) return KeyStoreKind.windowsCredentialManager;
    return linuxKeyStoreKind();
  }

  /// Linux: im Flatpak liegen die Schlüssel über das Secret-Portal in der Sandbox (E-50), sonst im
  /// Secret Service des Systems. Erkennung wie üblich per `FLATPAK_ID` oder `/.flatpak-info`.
  @visibleForTesting
  static KeyStoreKind linuxKeyStoreKind({Map<String, String>? environment, bool Function(String path)? fileExists}) {
    final env = environment ?? Platform.environment;
    final exists = fileExists ?? (String p) => File(p).existsSync();
    final inFlatpak = (env['FLATPAK_ID'] ?? '').isNotEmpty || exists('/.flatpak-info');
    return inFlatpak ? KeyStoreKind.linuxFlatpakPortal : KeyStoreKind.linuxSecretService;
  }

  @override
  Future<StorageLocations> locations() async {
    if (PlatformInfo.isWeb) {
      return StorageLocations(
        databaseDirectory: '',
        appDatabase: appFileName,
        matrixDatabase: matrixFileName,
        keyStore: _keyStoreKind,
        inBrowser: true,
      );
    }
    final dir = _directory ?? await EncryptedDb.databasesPath();
    return StorageLocations(
      databaseDirectory: dir,
      appDatabase: p.join(dir, appFileName),
      matrixDatabase: p.join(dir, matrixFileName),
      keyStore: _keyStoreKind,
    );
  }

  @override
  Future<LocalInventory> read() async {
    final loc = await locations();
    final result = <LocalTable>[];
    for (final t in tables) {
      result.add(LocalTable(t, await _db.query(t)));
    }
    return LocalInventory(
      locations: loc,
      keys: <LocalKey>[
        for (final k in keyNames) LocalKey(k, present: await _keyStore.readKey(k) != null),
      ],
      tables: result,
      appDatabaseBytes: _size(loc.inBrowser ? null : loc.appDatabase),
      matrixDatabaseBytes: _size(loc.inBrowser ? null : loc.matrixDatabase),
    );
  }

  static int? _size(String? path) {
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? f.lengthSync() : null;
  }
}
