import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/avatar_photo.dart';
import '../../domain/avatar_photo_store.dart';

/// [AvatarPhotoStore] auf der verschlüsselten SQLCipher-Datenbank (#434, E-111).
class SqlAvatarPhotoStore implements AvatarPhotoStore {
  SqlAvatarPhotoStore(this._db);
  final Database _db;

  StoredAvatarPhoto? _decode(Map<String, Object?> row) {
    try {
      final data = row['data']! as String;
      final bytes = data.isEmpty ? Uint8List(0) : Uint8List.fromList(base64.decode(data));
      final photo = AvatarPhoto(
        owner: row['owner']! as String,
        id: row['photo_id']! as String,
        createdAt: row['created_at']! as int,
        cleared: (row['cleared']! as int) != 0,
        width: row['w']! as int,
        height: row['h']! as int,
        bytes: bytes,
      );
      if (photo.validate().isNotEmpty) {
        AppLog.w('store', 'Gespeichertes Avatar-Foto ungültig');
        return null;
      }
      final redact = json.decode(row['redact_ids']! as String);
      return StoredAvatarPhoto(
        photo: photo,
        eventId: row['event_id']! as String,
        published: (row['published']! as int) != 0,
        redactIds: <String>[
          if (redact is List<Object?>)
            for (final e in redact)
              if (e is String) e,
        ],
      );
    } catch (e) {
      AppLog.e('store', 'Gespeichertes Avatar-Foto nicht lesbar', e);
      return null;
    }
  }

  StoredAvatarReset? _decodeReset(Map<String, Object?> row) {
    final reset = AvatarReset(
      target: row['target']! as String,
      photoId: row['photo_id']! as String,
      photoCreatedAt: row['photo_created_at']! as int,
    );
    if (reset.validate().isNotEmpty) {
      AppLog.w('store', 'Gespeichertes Zurücksetzen ungültig');
      return null;
    }
    return StoredAvatarReset(reset: reset, published: (row['published']! as int) != 0);
  }

  Map<String, Object?> _row(String roomId, StoredAvatarPhoto s) => <String, Object?>{
    'room_id': roomId,
    'owner': s.photo.owner,
    'photo_id': s.photo.id,
    'created_at': s.photo.createdAt,
    'cleared': s.photo.cleared ? 1 : 0,
    'w': s.photo.width,
    'h': s.photo.height,
    'data': s.photo.cleared ? '' : base64.encode(s.photo.bytes),
    'event_id': s.eventId,
    'published': s.published ? 1 : 0,
    'redact_ids': json.encode(s.redactIds),
  };

  @override
  Future<StoredAvatarPhoto?> photo(String roomId, String owner) async {
    final rows = await _db.query(
      'avatar_photos',
      where: 'room_id = ? AND owner = ?',
      whereArgs: <Object?>[roomId, owner],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<StoredAvatarPhoto>> photos(String roomId) async {
    final rows = await _db.query('avatar_photos', where: 'room_id = ?', whereArgs: <Object?>[roomId]);
    return <StoredAvatarPhoto>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> putPhoto(String roomId, StoredAvatarPhoto stored, {bool queueRedactOfPrevious = false}) =>
      _db.transaction((txn) async {
        var redact = stored.redactIds;
        if (queueRedactOfPrevious) {
          final old = await txn.query(
            'avatar_photos',
            where: 'room_id = ? AND owner = ?',
            whereArgs: <Object?>[roomId, stored.photo.owner],
            limit: 1,
          );
          if (old.isNotEmpty) {
            final prev = _decode(old.first);
            // Offene Aufträge der bisherigen Zeile bleiben erhalten, dazu kommt ihre eigene Ereignis-ID.
            redact = <String>{
              ...?prev?.redactIds,
              if (prev != null && prev.eventId.isNotEmpty) prev.eventId,
              ...redact,
            }.toList();
          }
        }
        await txn.insert(
          'avatar_photos',
          _row(roomId, stored.copyWith(redactIds: redact)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

  @override
  Future<List<StoredAvatarPhoto>> pendingPhotos(String roomId) async {
    final rows = await _db.query('avatar_photos', where: 'room_id = ? AND published = 0', whereArgs: <Object?>[roomId]);
    return <StoredAvatarPhoto>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> markPublished(String roomId, String owner, String photoId, String eventId) =>
      _db.transaction((txn) async {
        final rows = await txn.query(
          'avatar_photos',
          where: 'room_id = ? AND owner = ? AND photo_id = ?',
          whereArgs: <Object?>[roomId, owner, photoId],
          limit: 1,
        );
        if (rows.isEmpty) return;
        final cur = _decode(rows.first);
        // Eine frühere Kopie desselben Fotos (Resync) wird aufgeräumt; das neue Ereignis bleibt der gültige Stand.
        final redact = <String>{
          ...?cur?.redactIds,
          if (cur != null && cur.eventId.isNotEmpty && cur.eventId != eventId) cur.eventId,
        }.toList();
        await txn.update(
          'avatar_photos',
          <String, Object?>{'published': 1, 'event_id': eventId, 'redact_ids': json.encode(redact)},
          where: 'room_id = ? AND owner = ? AND photo_id = ?',
          whereArgs: <Object?>[roomId, owner, photoId],
        );
      });

  @override
  Future<void> requeueOwnPhoto(String roomId, String owner) =>
      _db.rawUpdate('UPDATE avatar_photos SET published = 0 WHERE room_id = ? AND owner = ?', <Object?>[roomId, owner]);

  @override
  Future<void> requeueResets(String roomId) =>
      _db.rawUpdate('UPDATE avatar_resets SET published = 0 WHERE room_id = ?', <Object?>[roomId]);

  @override
  Future<List<StoredAvatarPhoto>> redactQueue(String roomId) async {
    final rows = await _db.query(
      'avatar_photos',
      where: "room_id = ? AND redact_ids != '[]'",
      whereArgs: <Object?>[roomId],
    );
    return <StoredAvatarPhoto>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> clearRedacted(String roomId, String owner, String eventId) => _db.transaction((txn) async {
    final rows = await txn.query(
      'avatar_photos',
      where: 'room_id = ? AND owner = ?',
      whereArgs: <Object?>[roomId, owner],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final cur = _decode(rows.first);
    if (cur == null) return;
    final left = <String>[
      for (final id in cur.redactIds)
        if (id != eventId) id,
    ];
    await txn.update(
      'avatar_photos',
      <String, Object?>{'redact_ids': json.encode(left)},
      where: 'room_id = ? AND owner = ?',
      whereArgs: <Object?>[roomId, owner],
    );
  });

  @override
  Future<List<StoredAvatarReset>> resets(String roomId) async {
    final rows = await _db.query('avatar_resets', where: 'room_id = ?', whereArgs: <Object?>[roomId]);
    return <StoredAvatarReset>[for (final r in rows) ?_decodeReset(r)];
  }

  @override
  Future<void> addReset(String roomId, AvatarReset reset, {bool published = true}) async {
    final rows = await _db.query(
      'avatar_resets',
      where: 'room_id = ? AND target = ? AND photo_id = ?',
      whereArgs: <Object?>[roomId, reset.target, reset.photoId],
      limit: 1,
    );
    if (rows.isNotEmpty) return; // bereits bekannt: ein gesendeter Stand wird nie auf „ungesendet“ zurückgesetzt
    await _db.insert('avatar_resets', <String, Object?>{
      'room_id': roomId,
      'target': reset.target,
      'photo_id': reset.photoId,
      'photo_created_at': reset.photoCreatedAt,
      'published': published ? 1 : 0,
    });
  }

  @override
  Future<List<StoredAvatarReset>> pendingResets(String roomId) async {
    final rows = await _db.query('avatar_resets', where: 'room_id = ? AND published = 0', whereArgs: <Object?>[roomId]);
    return <StoredAvatarReset>[for (final r in rows) ?_decodeReset(r)];
  }

  @override
  Future<void> markResetPublished(String roomId, String target, String photoId) => _db.rawUpdate(
    'UPDATE avatar_resets SET published = 1 WHERE room_id = ? AND target = ? AND photo_id = ?',
    <Object?>[roomId, target, photoId],
  );

  @override
  Future<void> pruneResets(String roomId) => _db.rawDelete(
    'DELETE FROM avatar_resets WHERE room_id = ? AND published = 1 AND EXISTS ('
    'SELECT 1 FROM avatar_photos p WHERE p.room_id = avatar_resets.room_id AND p.owner = avatar_resets.target '
    'AND p.created_at > avatar_resets.photo_created_at)',
    <Object?>[roomId],
  );

  @override
  Future<void> removeOwner(String roomId, String owner) =>
      _db.delete('avatar_photos', where: 'room_id = ? AND owner = ?', whereArgs: <Object?>[roomId, owner]);

  @override
  Future<void> wipe() async {
    await _db.delete('avatar_photos');
    await _db.delete('avatar_resets');
  }
}
