import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/task_store.dart';
import '../../domain/tasks.dart';

/// [TaskStore] auf der verschlüsselten SQLCipher-Datenbank (E-51).
class SqlTaskStore implements TaskStore {
  SqlTaskStore(this._db);
  final Database _db;

  TaskList? _decodeList(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final l = TaskCodec.decodeList(data, sender: row['author']! as String);
      if (l == null) AppLog.w('store', 'Gespeicherte Aufgabenliste ungültig');
      return l;
    } catch (e) {
      AppLog.e('store', 'Gespeicherte Aufgabenliste nicht lesbar', e);
      return null;
    }
  }

  TaskLogEntry? _decodeLog(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final e = TaskCodec.decodeLog(data, sender: row['author']! as String);
      if (e == null) AppLog.w('store', 'Gespeicherter Protokolleintrag ungültig');
      return e;
    } catch (e) {
      AppLog.e('store', 'Gespeicherter Protokolleintrag nicht lesbar', e);
      return null;
    }
  }

  @override
  Future<TaskList?> getList(String id) async {
    final rows = await _db.query('task_lists', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    return rows.isEmpty ? null : _decodeList(rows.first);
  }

  @override
  Future<List<TaskList>> lists() async {
    final rows = await _db.query('task_lists');
    return <TaskList>[for (final r in rows) ?_decodeList(r)];
  }

  @override
  Future<({int active, int total})> listCounts() async {
    final total = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM task_lists')) ?? 0;
    final active = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM task_lists WHERE deleted = 0')) ?? 0;
    return (active: active, total: total);
  }

  @override
  Future<void> putList(TaskList list, {int? publishedVersion}) => _db.transaction((txn) async {
        final row = <String, Object?>{
          'id': list.id,
          'version': list.version,
          'deleted': list.deleted ? 1 : 0,
          'author': list.by,
          'data': json.encode(TaskCodec.encodeList(list)),
        };
        final exists =
            Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM task_lists WHERE id = ?', <Object?>[list.id])) ?? 0;
        if (exists == 0) {
          await txn.insert('task_lists', <String, Object?>{...row, 'published': publishedVersion ?? 0});
        } else {
          await txn.update('task_lists', <String, Object?>{...row, 'published': ?publishedVersion},
              where: 'id = ?', whereArgs: <Object?>[list.id]);
        }
      });

  @override
  Future<List<TaskList>> pendingLists() async {
    final rows = await _db.query('task_lists', where: 'version > published');
    return <TaskList>[for (final r in rows) ?_decodeList(r)];
  }

  @override
  Future<void> markListPublished(String id, int version) => _db.rawUpdate(
        'UPDATE task_lists SET published = ? WHERE id = ? AND published < ?',
        <Object?>[version, id, version],
      );

  @override
  Future<void> pruneListTombstones({required int keep}) => _db.rawDelete(
        'DELETE FROM task_lists WHERE deleted = 1 AND published >= version AND rowid NOT IN '
        '(SELECT rowid FROM task_lists WHERE deleted = 1 ORDER BY rowid DESC LIMIT ?)',
        <Object?>[keep],
      );

  @override
  Future<bool> hasLog(String id) async =>
      (Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM task_log WHERE id = ?', <Object?>[id])) ?? 0) > 0;

  @override
  Future<void> addLog(TaskLogEntry entry, {required bool published}) async {
    await _db.insert(
      'task_log',
      <String, Object?>{
        'id': entry.id,
        'list_id': entry.listId,
        'at_ms': entry.at.millisecondsSinceEpoch,
        'published': published ? 1 : 0,
        'author': entry.by,
        'data': json.encode(TaskCodec.encodeLog(entry)),
      },
      // Einträge werden nur angefügt, nie überschrieben.
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<TaskLogEntry>> log({String? listId}) async {
    final rows = listId == null
        ? await _db.query('task_log', orderBy: 'at_ms DESC')
        : await _db.query('task_log', where: 'list_id = ?', whereArgs: <Object?>[listId], orderBy: 'at_ms DESC');
    return <TaskLogEntry>[for (final r in rows) ?_decodeLog(r)];
  }

  @override
  Future<int> logCount(String listId) async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM task_log WHERE list_id = ?', <Object?>[listId])) ?? 0;

  @override
  Future<int> logTotal() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM task_log')) ?? 0;

  @override
  Future<void> pruneLog(String listId, {required int keep}) => _db.rawDelete(
        'DELETE FROM task_log WHERE list_id = ? AND published = 1 AND id NOT IN '
        '(SELECT id FROM task_log WHERE list_id = ? ORDER BY at_ms DESC LIMIT ?)',
        <Object?>[listId, listId, keep],
      );

  @override
  Future<List<TaskLogEntry>> pendingLog() async {
    final rows = await _db.query('task_log', where: 'published = 0', orderBy: 'at_ms ASC');
    return <TaskLogEntry>[for (final r in rows) ?_decodeLog(r)];
  }

  @override
  Future<void> markLogPublished(String id) =>
      _db.rawUpdate('UPDATE task_log SET published = 1 WHERE id = ?', <Object?>[id]);

  @override
  Future<void> requeueLastEditedBy(String userId) async {
    await _db.rawUpdate('UPDATE task_lists SET published = 0 WHERE author = ? AND deleted = 0', <Object?>[userId]);
    await _db.rawUpdate('UPDATE task_log SET published = 0 WHERE author = ?', <Object?>[userId]);
  }

  @override
  Future<void> wipe() async {
    await _db.delete('task_lists');
    await _db.delete('task_log');
  }
}
