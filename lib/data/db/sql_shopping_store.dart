import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/shopping.dart';
import '../../domain/shopping_store.dart';

/// [ShoppingStore] auf der verschlüsselten SQLCipher-Datenbank.
class SqlShoppingStore implements ShoppingStore {
  SqlShoppingStore(this._db);
  final Database _db;

  ShoppingItem? _decode(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final item = ShoppingCodec.decode(data, sender: row['author']! as String);
      if (item == null) AppLog.w('store', 'Gespeicherter Einkaufseintrag ungültig');
      return item;
    } catch (e) {
      AppLog.e('store', 'Gespeicherter Einkaufseintrag nicht lesbar', e);
      return null;
    }
  }

  Map<String, Object?> _row(ShoppingItem i, {int? published}) => <String, Object?>{
        'id': i.id,
        'version': i.version,
        'published': ?published,
        'deleted': i.deleted ? 1 : 0,
        'author': i.by,
        'data': json.encode(ShoppingCodec.encode(i)),
      };

  @override
  Future<ShoppingItem?> get(String id) async {
    final rows = await _db.query('shopping_items', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<ShoppingItem>> all() async {
    final rows = await _db.query('shopping_items');
    return <ShoppingItem>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<({int active, int total})> counts() async {
    final total = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM shopping_items')) ?? 0;
    final active = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM shopping_items WHERE deleted = 0')) ?? 0;
    return (active: active, total: total);
  }

  @override
  Future<void> put(ShoppingItem item, {int? publishedVersion}) => _db.transaction((txn) async {
        final exists = Sqflite.firstIntValue(
                await txn.rawQuery('SELECT COUNT(*) FROM shopping_items WHERE id = ?', <Object?>[item.id])) ??
            0;
        if (exists == 0) {
          await txn.insert('shopping_items', <String, Object?>{..._row(item), 'published': publishedVersion ?? 0});
        } else {
          await txn.update('shopping_items', _row(item, published: publishedVersion), where: 'id = ?', whereArgs: <Object?>[item.id]);
        }
      });

  @override
  Future<List<ShoppingItem>> pendingPublish() async {
    final rows = await _db.query('shopping_items', where: 'version > published');
    return <ShoppingItem>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> markPublished(String id, int version) => _db.rawUpdate(
        'UPDATE shopping_items SET published = ? WHERE id = ? AND published < ?',
        <Object?>[version, id, version],
      );

  @override
  Future<void> requeueLastEditedBy(String userId) => _db.rawUpdate(
        'UPDATE shopping_items SET published = 0 WHERE author = ? AND deleted = 0',
        <Object?>[userId],
      );

  @override
  Future<void> pruneTombstones({required int keep}) => _db.rawDelete(
        'DELETE FROM shopping_items WHERE deleted = 1 AND published >= version AND rowid NOT IN '
        '(SELECT rowid FROM shopping_items WHERE deleted = 1 ORDER BY rowid DESC LIMIT ?)',
        <Object?>[keep],
      );

  @override
  Future<void> wipe() => _db.delete('shopping_items');
}
