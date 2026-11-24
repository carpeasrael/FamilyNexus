import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/cash_book.dart';
import '../../domain/cash_book_store.dart';

/// [CashBookStore] auf der verschlüsselten SQLCipher-Datenbank (#311, E-113).
class SqlCashBookStore implements CashBookStore {
  SqlCashBookStore(this._db);
  final Database _db;

  CashBookMeta _meta(Map<String, Object?> r) => CashBookMeta(
        roomId: r['room_id']! as String,
        title: r['title']! as String,
        currency: r['currency']! as String,
        owner: r['owner']! as String,
        version: r['version']! as int,
      );

  CashEntry? _entry(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final e = CashBookCodec.decodeEntry(data, sender: row['author']! as String);
      if (e == null) AppLog.w('store', 'Gespeicherter Kassenbuch-Eintrag ungültig');
      return e;
    } catch (e) {
      AppLog.e('store', 'Gespeicherter Kassenbuch-Eintrag nicht lesbar', e);
      return null;
    }
  }

  @override
  Future<CashBookMeta?> getBook(String roomId) async {
    final rows = await _db.query('cash_books', where: 'room_id = ?', whereArgs: <Object?>[roomId], limit: 1);
    return rows.isEmpty ? null : _meta(rows.first);
  }

  @override
  Future<List<CashBookMeta>> books() async => <CashBookMeta>[for (final r in await _db.query('cash_books')) _meta(r)];

  @override
  Future<void> putBook(CashBookMeta meta, {bool published = true}) => _db.insert(
        'cash_books',
        <String, Object?>{
          'room_id': meta.roomId,
          'title': meta.title,
          'currency': meta.currency,
          'owner': meta.owner,
          'version': meta.version,
          'published': published ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ).then((_) {});

  @override
  Future<void> deleteBook(String roomId) => _db.transaction((txn) async {
        await txn.delete('cash_entries', where: 'room_id = ?', whereArgs: <Object?>[roomId]);
        await txn.delete('cash_books', where: 'room_id = ?', whereArgs: <Object?>[roomId]);
      });

  @override
  Future<bool> isComplete(String roomId) async {
    final rows = await _db.query('cash_books', columns: <String>['complete'], where: 'room_id = ?', whereArgs: <Object?>[roomId], limit: 1);
    return rows.isNotEmpty && rows.first['complete'] == 1;
  }

  @override
  Future<void> setComplete(String roomId, bool complete) => _db
      .update('cash_books', <String, Object?>{'complete': complete ? 1 : 0}, where: 'room_id = ?', whereArgs: <Object?>[roomId])
      .then((_) {});

  @override
  Future<CashEntry?> getEntry(String roomId, String author, String id) async {
    final rows = await _db.query(
      'cash_entries',
      where: 'room_id = ? AND author = ? AND id = ?',
      whereArgs: <Object?>[roomId, author, id],
      limit: 1,
    );
    return rows.isEmpty ? null : _entry(rows.first);
  }

  @override
  Future<List<CashEntry>> entries(String roomId) async {
    final rows = await _db.query('cash_entries', where: 'room_id = ?', whereArgs: <Object?>[roomId]);
    return <CashEntry>[for (final r in rows) ?_entry(r)];
  }

  @override
  Future<int> countByAuthor(String roomId, String author) async =>
      Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM cash_entries WHERE room_id = ? AND author = ?',
        <Object?>[roomId, author],
      )) ??
      0;

  @override
  Future<void> putEntry(String roomId, CashEntry entry, {int? publishedVersion}) => _db.transaction((txn) async {
        final row = <String, Object?>{
          'room_id': roomId,
          'author': entry.author,
          'id': entry.id,
          'version': entry.version,
          'deleted': entry.deleted ? 1 : 0,
          'data': json.encode(CashBookCodec.encodeStored(entry)),
        };
        final exists = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM cash_entries WHERE room_id = ? AND author = ? AND id = ?',
              <Object?>[roomId, entry.author, entry.id],
            )) ??
            0;
        if (exists == 0) {
          await txn.insert('cash_entries', <String, Object?>{...row, 'published': publishedVersion ?? 0});
        } else {
          await txn.update(
            'cash_entries',
            <String, Object?>{...row, 'published': ?publishedVersion},
            where: 'room_id = ? AND author = ? AND id = ?',
            whereArgs: <Object?>[roomId, entry.author, entry.id],
          );
        }
      });

  @override
  Future<List<({String roomId, CashEntry entry})>> pending(String author) async {
    final rows = await _db.query('cash_entries', where: 'author = ? AND version > published', whereArgs: <Object?>[author]);
    return <({String roomId, CashEntry entry})>[
      for (final r in rows)
        if (_entry(r) case final e?) (roomId: r['room_id']! as String, entry: e),
    ];
  }

  @override
  Future<void> markPublished(String roomId, String author, String id, int version) => _db.rawUpdate(
        'UPDATE cash_entries SET published = ? WHERE room_id = ? AND author = ? AND id = ? AND published < ?',
        <Object?>[version, roomId, author, id, version],
      ).then((_) {});

  @override
  Future<void> requeueOwn(String roomId, String author) => _db.rawUpdate(
        'UPDATE cash_entries SET published = 0 WHERE room_id = ? AND author = ? AND deleted = 0',
        <Object?>[roomId, author],
      ).then((_) {});

  @override
  Future<void> wipe() => _db.transaction((txn) async {
        await txn.delete('cash_entries');
        await txn.delete('cash_books');
      });
}
