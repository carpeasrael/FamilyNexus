import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/event_theme_codec.dart';
import '../../domain/event_theme_store.dart';
import '../../domain/event_themes.dart';

/// [EventThemeStore] auf der verschlüsselten SQLCipher-Datenbank (E-99).
class SqlEventThemeStore implements EventThemeStore {
  SqlEventThemeStore(this._db);
  final Database _db;

  EventTheme? _decode(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final t = EventThemeCodec.decode(data, sender: row['author']! as String);
      if (t == null) AppLog.w('store', 'Gespeichertes Kalender-Thema ungültig');
      return t;
    } catch (e) {
      AppLog.e('store', 'Gespeichertes Kalender-Thema nicht lesbar', e);
      return null;
    }
  }

  @override
  Future<EventTheme?> get(String id) async {
    final rows = await _db.query('event_themes', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<EventTheme>> all() async {
    final rows = await _db.query('event_themes');
    return <EventTheme>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<({int active, int total})> counts() async {
    final total = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM event_themes')) ?? 0;
    final active = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM event_themes WHERE deleted = 0')) ?? 0;
    return (active: active, total: total);
  }

  @override
  Future<void> put(EventTheme theme, {int? publishedVersion}) => _db.transaction((txn) async {
        final row = <String, Object?>{
          'id': theme.id,
          'version': theme.version,
          'deleted': theme.deleted ? 1 : 0,
          'author': theme.by,
          'data': json.encode(EventThemeCodec.encode(theme)),
        };
        final exists =
            Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM event_themes WHERE id = ?', <Object?>[theme.id])) ?? 0;
        if (exists == 0) {
          await txn.insert('event_themes', <String, Object?>{...row, 'published': publishedVersion ?? 0});
        } else {
          await txn.update('event_themes', <String, Object?>{...row, 'published': ?publishedVersion},
              where: 'id = ?', whereArgs: <Object?>[theme.id]);
        }
      });

  @override
  Future<List<EventTheme>> pending() async {
    final rows = await _db.query('event_themes', where: 'version > published');
    return <EventTheme>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> markPublished(String id, int version) => _db.rawUpdate(
        'UPDATE event_themes SET published = ? WHERE id = ? AND published < ?',
        <Object?>[version, id, version],
      );

  @override
  Future<void> pruneTombstones({required int keep}) => _db.rawDelete(
        'DELETE FROM event_themes WHERE deleted = 1 AND published >= version AND rowid NOT IN '
        '(SELECT rowid FROM event_themes WHERE deleted = 1 ORDER BY rowid DESC LIMIT ?)',
        <Object?>[keep],
      );

  @override
  Future<void> requeueLastEditedBy(String userId) =>
      _db.rawUpdate('UPDATE event_themes SET published = 0 WHERE author = ? AND deleted = 0', <Object?>[userId]);

  @override
  Future<void> wipe() async {
    await _db.delete('event_themes');
  }
}
