import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/anniversaries.dart';
import '../../domain/anniversary_codec.dart';
import '../../domain/anniversary_store.dart';

/// [AnniversaryStore] auf der verschlüsselten SQLCipher-Datenbank (E-104).
class SqlAnniversaryStore implements AnniversaryStore {
  SqlAnniversaryStore(this._db);
  final Database _db;

  AnniversaryPerson? _decode(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final t = AnniversaryCodec.decode(data, sender: row['author']! as String);
      if (t == null) AppLog.w('store', 'Gespeicherter Geburtstagseintrag ungültig');
      return t;
    } catch (e) {
      AppLog.e('store', 'Gespeicherter Geburtstagseintrag nicht lesbar', e);
      return null;
    }
  }

  @override
  Future<AnniversaryPerson?> get(String id) async {
    final rows = await _db.query('anniversaries', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<AnniversaryPerson>> all() async {
    final rows = await _db.query('anniversaries');
    return <AnniversaryPerson>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<({int active, int total})> counts() async {
    final total = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM anniversaries')) ?? 0;
    final active = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM anniversaries WHERE deleted = 0')) ?? 0;
    return (active: active, total: total);
  }

  @override
  Future<void> put(AnniversaryPerson person, {int? publishedVersion}) => _db.transaction((txn) async {
        final row = <String, Object?>{
          'id': person.id,
          'version': person.version,
          'deleted': person.deleted ? 1 : 0,
          'author': person.by,
          'data': json.encode(AnniversaryCodec.encode(person)),
        };
        final exists =
            Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM anniversaries WHERE id = ?', <Object?>[person.id])) ?? 0;
        if (exists == 0) {
          await txn.insert('anniversaries', <String, Object?>{...row, 'published': publishedVersion ?? 0});
        } else {
          await txn.update('anniversaries', <String, Object?>{...row, 'published': ?publishedVersion},
              where: 'id = ?', whereArgs: <Object?>[person.id]);
        }
      });

  @override
  Future<List<AnniversaryPerson>> pending() async {
    final rows = await _db.query('anniversaries', where: 'version > published');
    return <AnniversaryPerson>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> markPublished(String id, int version) => _db.rawUpdate(
        'UPDATE anniversaries SET published = ? WHERE id = ? AND published < ?',
        <Object?>[version, id, version],
      );

  @override
  Future<void> pruneTombstones({required int keep}) => _db.rawDelete(
        'DELETE FROM anniversaries WHERE deleted = 1 AND published >= version AND rowid NOT IN '
        '(SELECT rowid FROM anniversaries WHERE deleted = 1 ORDER BY rowid DESC LIMIT ?)',
        <Object?>[keep],
      );

  @override
  Future<void> requeueLastEditedBy(String userId) =>
      _db.rawUpdate('UPDATE anniversaries SET published = 0 WHERE author = ? AND deleted = 0', <Object?>[userId]);

  @override
  Future<void> wipe() async {
    await _db.delete('anniversaries');
  }
}
