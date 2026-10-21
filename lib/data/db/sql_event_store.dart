import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/app_log.dart';
import '../../domain/calendar_event.dart';
import '../../domain/event_codec.dart';
import '../../domain/event_store.dart';

/// [EventStore] auf der verschlüsselten SQLCipher-Datenbank.
class SqlEventStore implements EventStore {
  SqlEventStore(this._db);
  final Database _db;

  static EventVisibility _vis(String s) =>
      s == EventVisibility.shared.name ? EventVisibility.shared : EventVisibility.private;

  CalendarEvent? _decode(Map<String, Object?> row) {
    try {
      final data = json.decode(row['data']! as String);
      if (data is! Map<String, Object?>) return null;
      final r = EventCodec.decodeStored(
        data,
        owner: row['owner']! as String,
        visibility: _vis(row['visibility']! as String),
      );
      if (!r.isOk) AppLog.w('store', 'Gespeicherter Termin ungültig (${r.error})');
      return r.event;
    } catch (e) {
      AppLog.e('store', 'Gespeicherter Termin nicht lesbar', e);
      return null;
    }
  }

  Map<String, Object?> _row(CalendarEvent e, {int? published}) => <String, Object?>{
        'id': e.id,
        'owner': e.ownerId,
        'visibility': e.visibility.name,
        'version': e.version,
        'published': ?published,
        'deleted': e.deleted ? 1 : 0,
        'data': json.encode(EventCodec.encodeStored(e)),
      };

  @override
  Future<CalendarEvent?> get(String id) async {
    final rows = await _db.query('events', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<List<CalendarEvent>> all() async {
    final rows = await _db.query('events');
    return <CalendarEvent>[for (final r in rows) ?_decode(r)];
  }

  Future<void> _trimHistory(DatabaseExecutor ex, String id) => ex.rawDelete(
        'DELETE FROM event_history WHERE id = ? AND rowid NOT IN '
        '(SELECT rowid FROM event_history WHERE id = ? ORDER BY version DESC, updated_ms DESC LIMIT ?)',
        <Object?>[id, id, EventStore.maxHistoryPerEvent],
      );

  @override
  Future<int> countOwnedBy(String owner) async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM events WHERE owner = ?', <Object?>[owner])) ?? 0;

  @override
  Future<void> requeueOwnShared(String owner) => _db.transaction((txn) async {
        await txn.rawUpdate(
          "UPDATE events SET published = 0 WHERE owner = ? AND visibility = 'shared' AND deleted = 0",
          <Object?>[owner],
        );
        await txn.rawUpdate('UPDATE rsvps SET published = 0 WHERE user_id = ?', <Object?>[owner]);
      });

  Future<void> _addHistory(DatabaseExecutor ex, CalendarEvent e) async {
    await ex.insert(
        'event_history',
        <String, Object?>{
          'id': e.id,
          'version': e.version,
          'updated_ms': e.updatedAt.millisecondsSinceEpoch,
          'owner': e.ownerId,
          'visibility': e.visibility.name,
          'data': json.encode(EventCodec.encodeStored(e)),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    await _trimHistory(ex, e.id);
  }

  @override
  Future<void> put(CalendarEvent event, {CalendarEvent? replaced, int? publishedVersion}) =>
      _db.transaction((txn) async {
        if (replaced != null && replaced != event) await _addHistory(txn, replaced);
        final exists = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM events WHERE id = ?', <Object?>[event.id])) ?? 0;
        if (exists == 0) {
          await txn.insert('events', <String, Object?>{..._row(event), 'published': publishedVersion ?? 0});
        } else {
          await txn.update('events', _row(event, published: publishedVersion), where: 'id = ?', whereArgs: <Object?>[event.id]);
        }
      });

  @override
  Future<void> addHistory(CalendarEvent event) => _addHistory(_db, event);

  @override
  Future<List<CalendarEvent>> history(String id) async {
    final rows = await _db.query(
      'event_history',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      orderBy: 'version DESC, updated_ms DESC',
    );
    return <CalendarEvent>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<List<CalendarEvent>> pendingPublish() async {
    final rows = await _db.query('events', where: 'version > published');
    return <CalendarEvent>[for (final r in rows) ?_decode(r)];
  }

  @override
  Future<void> markPublished(String id, int version) => _db.rawUpdate(
        'UPDATE events SET published = ? WHERE id = ? AND published < ?',
        <Object?>[version, id, version],
      );

  @override
  Future<Map<String, List<int>>> reminders() async {
    final rows = await _db.query('event_reminders');
    return <String, List<int>>{
      for (final r in rows)
        r['event_id']! as String: (r['minutes']! as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.tryParse)
            .whereType<int>()
            .toList(),
    };
  }

  @override
  Future<void> setReminders(String eventId, List<int>? minutes) async {
    if (minutes == null) {
      await _db.delete('event_reminders', where: 'event_id = ?', whereArgs: <Object?>[eventId]);
    } else {
      await _db.insert(
        'event_reminders',
        <String, Object?>{'event_id': eventId, 'minutes': minutes.join(',')},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<Map<String, Map<String, RsvpStatus>>> rsvps() async {
    final rows = await _db.query('rsvps');
    final out = <String, Map<String, RsvpStatus>>{};
    for (final r in rows) {
      final st = RsvpStatus.values.where((s) => s.name == r['status']);
      if (st.isEmpty) continue;
      out.putIfAbsent(r['event_id']! as String, () => <String, RsvpStatus>{})[r['user_id']! as String] = st.first;
    }
    return out;
  }

  @override
  Future<List<({String eventId, RsvpStatus status, DateTime timestamp})>> pendingRsvps(String userId) async {
    final rows = await _db.query('rsvps', where: 'user_id = ? AND published = 0', whereArgs: <Object?>[userId]);
    return <({String eventId, RsvpStatus status, DateTime timestamp})>[
      for (final r in rows)
        for (final s in RsvpStatus.values.where((s) => s.name == r['status']))
          (
            eventId: r['event_id']! as String,
            status: s,
            timestamp: DateTime.fromMillisecondsSinceEpoch(r['ts']! as int, isUtc: true),
          ),
    ];
  }

  @override
  Future<void> markRsvpPublished(String eventId, String userId, DateTime timestamp) => _db.rawUpdate(
        'UPDATE rsvps SET published = 1 WHERE event_id = ? AND user_id = ? AND ts = ?',
        <Object?>[eventId, userId, timestamp.millisecondsSinceEpoch],
      );

  @override
  Future<void> putRsvp(
    String eventId,
    String userId,
    RsvpStatus status,
    DateTime timestamp, {
    bool published = true,
  }) =>
      _db.transaction((txn) async {
        final cur = await txn.query('rsvps',
            where: 'event_id = ? AND user_id = ?', whereArgs: <Object?>[eventId, userId], limit: 1);
        final ms = timestamp.millisecondsSinceEpoch;
        if (cur.isNotEmpty && (cur.first['ts']! as int) >= ms) return;
        await txn.insert(
          'rsvps',
          <String, Object?>{'event_id': eventId, 'user_id': userId, 'status': status.name, 'ts': ms, 'published': published ? 1 : 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

  @override
  Future<Map<String, int>> personColors() async {
    final rows = await _db.query('person_colors');
    return <String, int>{for (final r in rows) r['user_id']! as String: r['color']! as int};
  }

  @override
  Future<void> setPersonColor(String userId, int colorIndex) => _db.insert(
        'person_colors',
        <String, Object?>{'user_id': userId, 'color': colorIndex},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> wipe() => _db.transaction((txn) async {
        for (final t in <String>['events', 'event_history', 'rsvps', 'event_reminders', 'person_colors']) {
          await txn.delete(t);
        }
      });
}
