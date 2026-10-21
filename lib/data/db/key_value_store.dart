import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../domain/key_value_store.dart';

class SqlKeyValueStore implements KeyValueStore {
  SqlKeyValueStore(this._db);
  final Database _db;

  @override
  Future<Map<String, String>> readAll() async {
    final rows = await _db.query('settings');
    return <String, String>{
      for (final r in rows) r['key']! as String: r['value']! as String,
    };
  }

  @override
  Future<void> write(String key, String value) => apply(writes: <String, String>{key: value});

  @override
  Future<void> delete(String key) => apply(deletes: <String>[key]);

  @override
  Future<void> apply({
    Map<String, String> writes = const <String, String>{},
    Iterable<String> deletes = const <String>[],
  }) =>
      _db.transaction((txn) async {
        for (final e in writes.entries) {
          await txn.insert(
            'settings',
            <String, Object?>{'key': e.key, 'value': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final k in deletes) {
          await txn.delete('settings', where: 'key = ?', whereArgs: <Object?>[k]);
        }
      });
}
