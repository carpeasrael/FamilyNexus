import 'package:sqflite_common/sqlite_api.dart';

/// Nur im Browser verfügbar.
DatabaseFactory createCipherWebFactory({required String wasmPath, required String indexedDbName}) =>
    throw UnsupportedError('Verschlüsselte Web-Datenbank nur im Browser');
