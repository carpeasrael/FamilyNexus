import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/contact_store.dart';
import '../../domain/contacts.dart';

/// [ContactStore] auf der verschlüsselten SQLCipher-Datenbank (#119, E-114, Migration 9). `data` ist das JSON des
/// Datensatzes im Ereignisformat; die übrigen Spalten dienen der Abfrage und der Warteschlange.
class SqlContactStore implements ContactStore {
  SqlContactStore(this._db);
  final Database _db;

  ContactRecord? _decode(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final r = ContactCodec.decodeStored(data);
      if (r == null) AppLog.w('store', 'Gespeicherter Kontaktdatensatz ungültig');
      return r;
    } catch (e) {
      AppLog.e('store', 'Gespeicherter Kontaktdatensatz nicht lesbar', e);
      return null;
    }
  }

  @override
  Future<ContactRecord?> get(ContactKind kind, String id) async {
    final rows = await _db.query('contact_records', where: 'rec = ? AND id = ?', whereArgs: <Object?>[kind.name, id], limit: 1);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<ContactRecord>> all([ContactKind? kind]) async {
    final rows = kind == null
        ? await _db.query('contact_records', orderBy: 'rec, id')
        : await _db.query('contact_records', where: 'rec = ?', whereArgs: <Object?>[kind.name], orderBy: 'id');
    return <ContactRecord>[
      for (final r in rows) ?_decode(r),
    ];
  }

  @override
  Future<void> put(ContactRecord record, {int? publishedVersion}) async {
    final data = json.encode(ContactCodec.encode(record));
    final state = record is Contact ? record.state.name : '';
    final nick = record is Contact ? record.nick : '';
    final room = record is Contact ? record.room : null;
    await _db.transaction((txn) async {
      final existing = await txn.query('contact_records', columns: <String>['published_version'], where: 'rec = ? AND id = ?', whereArgs: <Object?>[record.kind.name, record.id], limit: 1);
      final published = publishedVersion ?? (existing.isEmpty ? 0 : existing.first['published_version']! as int);
      await txn.insert(
        'contact_records',
        <String, Object?>{
          'rec': record.kind.name,
          'id': record.id,
          'state': state,
          'nick': nick,
          'room': room,
          'version': record.version,
          'updated_ms': record.updatedAt.millisecondsSinceEpoch,
          'deleted': record.deleted ? 1 : 0,
          'published_version': published,
          'data': data,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<ContactRecord>> pending() async {
    final rows = await _db.query('contact_records', where: 'version > published_version', orderBy: 'rec, id');
    return <ContactRecord>[
      for (final r in rows) ?_decode(r),
    ];
  }

  @override
  Future<void> markPublished(ContactKind kind, String id, int version) async {
    await _db.rawUpdate(
      'UPDATE contact_records SET published_version = ? WHERE rec = ? AND id = ? AND published_version < ?',
      <Object?>[version, kind.name, id, version],
    );
  }

  @override
  Future<int> pruneTombstones({required int keep}) async {
    final rows = await _db.query(
      'contact_records',
      columns: <String>['rec', 'id'],
      where: 'deleted = 1 AND version <= published_version',
      orderBy: 'updated_ms DESC, rec, id',
    );
    if (rows.length <= keep) return 0;
    var removed = 0;
    for (final r in rows.skip(keep)) {
      removed += await _db.delete('contact_records', where: 'rec = ? AND id = ?', whereArgs: <Object?>[r['rec'], r['id']]);
    }
    return removed;
  }

  @override
  Future<void> requeueAll() async {
    await _db.rawUpdate('UPDATE contact_records SET published_version = 0 WHERE deleted = 0');
  }

  @override
  Future<void> wipe() async {
    await _db.delete('contact_records');
  }
}
