import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_avatar_photo_store.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/avatar_photo_fixtures.dart';

const String _room = '!familie:fake.test';
const String _other = '!zweite:fake.test';
const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _id1 = '00000000-0000-4000-8000-000000000001';
const String _id2 = '00000000-0000-4000-8000-000000000002';

StoredAvatarPhoto _stored({
  String owner = _anna,
  String id = _id1,
  int createdAt = 1000,
  String eventId = '',
  bool published = false,
}) => StoredAvatarPhoto(
  photo: AvatarPhoto(
    owner: owner,
    id: id,
    createdAt: createdAt,
    cleared: false,
    width: 64,
    height: 48,
    bytes: jpegBytes(),
  ),
  eventId: eventId,
  published: published,
);

void main() {
  late Database db;
  late SqlAvatarPhotoStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlAvatarPhotoStore(db);
  });

  tearDown(() => db.close());

  test('Migration v7 legt beide Tabellen an', () async {
    expect(AppDatabase.schemaVersion, 7);
    final rows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(<String>{
      for (final r in rows) r['name']! as String,
    }, containsAll(<String>['avatar_photos', 'avatar_resets']));
  });

  test('Schlüssel der Tabellen: (room_id, owner) und (room_id, target, photo_id)', () async {
    Future<List<String>> pk(String table) async {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final keyed = cols.where((c) => (c['pk']! as int) > 0).toList()
        ..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int));
      return <String>[for (final c in keyed) c['name']! as String];
    }

    expect(await pk('avatar_photos'), <String>['room_id', 'owner']);
    expect(await pk('avatar_resets'), <String>['room_id', 'target', 'photo_id']);
    final photoCols = <String>{
      for (final c in await db.rawQuery('PRAGMA table_info(avatar_photos)')) c['name']! as String,
    };
    expect(photoCols, <String>{
      'room_id',
      'owner',
      'photo_id',
      'created_at',
      'cleared',
      'w',
      'h',
      'data',
      'event_id',
      'published',
      'redact_ids',
    });
    final resetCols = <String>{
      for (final c in await db.rawQuery('PRAGMA table_info(avatar_resets)')) c['name']! as String,
    };
    expect(resetCols, <String>{'room_id', 'target', 'photo_id', 'photo_created_at', 'published'});
  });

  test('Migration v6 → v7 lässt bestehende Daten lesbar', () async {
    final old = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final m in AppDatabase.migrations.take(6)) {
      await m(old);
    }
    await old.insert('settings', <String, Object?>{'key': 'language', 'value': 'de'});
    await old.insert('anniversaries', <String, Object?>{
      'id': '00000000-0000-4000-8000-0000000000aa',
      'version': 1,
      'published': 1,
      'deleted': 0,
      'author': '@anna:fake.test',
      'data': '{}',
    });
    await AppDatabase.migrations[6](old);
    expect((await old.query('settings')).single['value'], 'de');
    expect((await old.query('anniversaries')).single['id'], '00000000-0000-4000-8000-0000000000aa');
    expect(await old.query('avatar_photos'), isEmpty);
    await old.close();
  });

  test('Foto übersteht Speichern und Lesen, auch die Bytes', () async {
    final s = _stored(eventId: r'$e1', published: true);
    await store.putPhoto(_room, s);
    final back = (await store.photo(_room, _anna))!;
    expect(back.photo, s.photo);
    expect(back.photo.bytes, s.photo.bytes);
    expect(back.eventId, r'$e1');
    expect(back.published, isTrue);
    expect(await store.photo(_room, _ben), isNull);
  });

  test('Löschmarke übersteht Speichern und Lesen', () async {
    final marker = AvatarPhoto.clearedMarker(owner: _anna, id: _id2, createdAt: 2000);
    await store.putPhoto(_room, StoredAvatarPhoto(photo: marker));
    final back = (await store.photo(_room, _anna))!.photo;
    expect(back.cleared, isTrue);
    expect(back.bytes, isEmpty);
  });

  test('eine Zeile je Eigentümer: ein neueres Ereignis ersetzt das bisherige', () async {
    await store.putPhoto(_room, _stored());
    await store.putPhoto(_room, _stored(id: _id2, createdAt: 2000));
    final all = await store.photos(_room);
    expect(all, hasLength(1));
    expect(all.single.photo.id, _id2);
  });

  test('Familien sind getrennt (room_id im Schlüssel)', () async {
    await store.putPhoto(_room, _stored());
    await store.putPhoto(_other, _stored(id: _id2, createdAt: 5000));
    expect((await store.photo(_room, _anna))!.photo.id, _id1);
    expect((await store.photo(_other, _anna))!.photo.id, _id2);
    await store.addReset(_room, const AvatarReset(target: _anna, photoId: _id1, photoCreatedAt: 1000));
    expect(await store.resets(_other), isEmpty);
  });

  test('Ausgangswarteschlange: ungesendete Ereignisse, markPublished trägt die Ereignis-ID nach', () async {
    await store.putPhoto(_room, _stored());
    expect((await store.pendingPhotos(_room)).single.photo.id, _id1);
    await store.markPublished(_room, _anna, _id1, r'$ev');
    expect(await store.pendingPhotos(_room), isEmpty);
    expect((await store.photo(_room, _anna))!.eventId, r'$ev');
  });

  test('markPublished wirkt nur auf das Foto, das die Zeile noch hält', () async {
    await store.putPhoto(_room, _stored());
    await store.putPhoto(_room, _stored(id: _id2, createdAt: 2000));
    await store.markPublished(_room, _anna, _id1, r'$alt');
    final s = (await store.photo(_room, _anna))!;
    expect(s.photo.id, _id2);
    expect(s.published, isFalse);
    expect(s.eventId, isEmpty);
  });

  group('Resync (Teil 2)', () {
    test('requeueOwnPhoto setzt nur das Foto des Eigentümers wieder auf ungesendet', () async {
      await store.putPhoto(_room, _stored(eventId: r'$a', published: true));
      await store.putPhoto(_room, _stored(owner: _ben, createdAt: 2000, eventId: r'$b', published: true));
      await store.requeueOwnPhoto(_room, _anna);
      expect((await store.pendingPhotos(_room)).map((p) => p.photo.owner), <String>[_anna]);
      expect((await store.photo(_room, _ben))!.published, isTrue);
    });

    test('requeueOwnPhoto wirkt nur in der eigenen Familie', () async {
      await store.putPhoto(_room, _stored(eventId: r'$a', published: true));
      await store.putPhoto(_other, _stored(eventId: r'$b', published: true));
      await store.requeueOwnPhoto(_room, _anna);
      expect(await store.pendingPhotos(_other), isEmpty);
    });

    test('markPublished nach einer Wiederholung: die frühere Kopie wandert in die Schwärz-Liste', () async {
      await store.putPhoto(_room, _stored(eventId: r'$alt', published: true));
      await store.requeueOwnPhoto(_room, _anna);
      await store.markPublished(_room, _anna, _id1, r'$neu');
      final s = (await store.photo(_room, _anna))!;
      expect(s.eventId, r'$neu');
      expect(s.published, isTrue);
      expect(s.redactIds, <String>[r'$alt']);
    });

    test('markPublished mit derselben Ereignis-ID räumt nichts auf', () async {
      await store.putPhoto(_room, _stored(eventId: r'$gleich', published: true));
      await store.markPublished(_room, _anna, _id1, r'$gleich');
      expect((await store.photo(_room, _anna))!.redactIds, isEmpty);
    });

    test('markPublished lässt offene Aufträge bestehen und fügt hinzu, ohne Doppelte', () async {
      await store.putPhoto(_room, _stored(eventId: r'$e1', published: true));
      await store.putPhoto(
        _room,
        _stored(id: _id2, createdAt: 2000, eventId: r'$e2', published: true),
        queueRedactOfPrevious: true,
      );
      await store.requeueOwnPhoto(_room, _anna);
      await store.markPublished(_room, _anna, _id2, r'$e3');
      expect((await store.photo(_room, _anna))!.redactIds, <String>[r'$e1', r'$e2']);
      await store.requeueOwnPhoto(_room, _anna);
      await store.markPublished(_room, _anna, _id2, r'$e3');
      expect((await store.photo(_room, _anna))!.redactIds, <String>[r'$e1', r'$e2'], reason: 'keine Doppelten');
    });

    test('requeueResets setzt alle Zurücksetzen der Familie wieder auf ungesendet', () async {
      await store.addReset(_room, const AvatarReset(target: _anna, photoId: _id1, photoCreatedAt: 1000));
      await store.addReset(_room, const AvatarReset(target: _ben, photoId: _id2, photoCreatedAt: 2000));
      await store.addReset(_other, const AvatarReset(target: _anna, photoId: _id1, photoCreatedAt: 1000));
      expect(await store.pendingResets(_room), isEmpty);
      await store.requeueResets(_room);
      expect(await store.pendingResets(_room), hasLength(2));
      expect(await store.pendingResets(_other), isEmpty, reason: 'eine andere Familie bleibt unberührt');
    });
  });

  test('Aufräumen: die ID des bisherigen eigenen Ereignisses wandert in die Schwärz-Liste', () async {
    await store.putPhoto(_room, _stored(eventId: r'$e1', published: true));
    await store.putPhoto(_room, _stored(id: _id2, createdAt: 2000), queueRedactOfPrevious: true);
    final q = await store.redactQueue(_room);
    expect(q.single.redactIds, <String>[r'$e1']);
    expect(q.single.photo.id, _id2);
  });

  test('ohne queueRedactOfPrevious bleibt die Liste leer; ohne bisherige Ereignis-ID auch', () async {
    await store.putPhoto(_room, _stored(eventId: r'$e1', published: true));
    await store.putPhoto(_room, _stored(id: _id2, createdAt: 2000));
    expect(await store.redactQueue(_room), isEmpty);
    await store.putPhoto(
      _room,
      _stored(id: '00000000-0000-4000-8000-000000000003', createdAt: 3000),
      queueRedactOfPrevious: true,
    );
    expect(await store.redactQueue(_room), isEmpty); // die Vorgängerin war nie gesendet
  });

  test('offene Aufträge bleiben beim nächsten Ersetzen erhalten und wachsen', () async {
    await store.putPhoto(_room, _stored(eventId: r'$e1', published: true));
    await store.putPhoto(
      _room,
      _stored(id: _id2, createdAt: 2000, eventId: r'$e2', published: true),
      queueRedactOfPrevious: true,
    );
    await store.putPhoto(
      _room,
      _stored(id: '00000000-0000-4000-8000-000000000003', createdAt: 3000),
      queueRedactOfPrevious: true,
    );
    // Beide gesendeten Vorgänger-Ereignisse sind offene Schwärz-Aufträge.
    expect((await store.redactQueue(_room)).single.redactIds, <String>[r'$e1', r'$e2']);
  });

  test('clearRedacted entfernt genau den erledigten Auftrag', () async {
    await store.putPhoto(_room, _stored(eventId: r'$e1', published: true));
    await store.putPhoto(
      _room,
      _stored(id: _id2, createdAt: 2000, eventId: r'$e2', published: true),
      queueRedactOfPrevious: true,
    );
    await store.clearRedacted(_room, _anna, r'$e1');
    expect(await store.redactQueue(_room), isEmpty);
    expect((await store.photo(_room, _anna))!.photo.id, _id2);
  });

  group('Zurücksetzen', () {
    final reset = const AvatarReset(target: _anna, photoId: _id1, photoCreatedAt: 1000);

    test('gespeichert, Menge ohne Doppelte, ungesendet zählt als ausstehend', () async {
      await store.addReset(_room, reset, published: false);
      await store.addReset(_room, reset); // schon bekannt: bleibt ungesendet
      expect((await store.resets(_room)).single.reset, reset);
      expect((await store.pendingResets(_room)).single.reset, reset);
      await store.markResetPublished(_room, _anna, _id1);
      expect(await store.pendingResets(_room), isEmpty);
    });

    test('mehrere Resets desselben Ziels mit verschiedenen Foto-IDs bleiben nebeneinander erhalten', () async {
      await store.addReset(_room, const AvatarReset(target: _anna, photoId: _id1, photoCreatedAt: 1000));
      await store.addReset(_room, const AvatarReset(target: _anna, photoId: _id2, photoCreatedAt: 2000));
      await store.addReset(_room, const AvatarReset(target: _ben, photoId: _id1, photoCreatedAt: 1000));
      final all = (await store.resets(_room)).map((r) => '${r.reset.target}|${r.reset.photoId}').toSet();
      expect(all, <String>{'$_anna|$_id1', '$_anna|$_id2', '$_ben|$_id1'});
    });

    test('pruneResets entfernt nur, wenn die Zeile des Ziels existiert und neuer ist', () async {
      await store.addReset(_room, reset);
      await store.pruneResets(_room);
      expect(await store.resets(_room), hasLength(1), reason: 'Reset vor dem Eintreffen des Fotos bleibt erhalten');

      await store.putPhoto(_room, _stored(createdAt: 1000)); // dasselbe Foto, nicht neuer
      await store.pruneResets(_room);
      expect(await store.resets(_room), hasLength(1));

      await store.putPhoto(_room, _stored(id: _id2, createdAt: 2000)); // neueres Foto
      await store.pruneResets(_room);
      expect(await store.resets(_room), isEmpty);
    });

    test('pruneResets behält eigene, noch ungesendete Resets', () async {
      await store.addReset(_room, reset, published: false);
      await store.putPhoto(_room, _stored(id: _id2, createdAt: 2000));
      await store.pruneResets(_room);
      expect(await store.resets(_room), hasLength(1));
    });

    test('removeOwner löscht die Foto-Zeile, aber nicht die Resets', () async {
      await store.putPhoto(_room, _stored());
      await store.addReset(_room, reset);
      await store.removeOwner(_room, _anna);
      expect(await store.photo(_room, _anna), isNull);
      expect(await store.resets(_room), hasLength(1));
    });
  });

  test('ungültige Zeilen werden ignoriert, nicht zurückgegeben', () async {
    await db.insert('avatar_photos', <String, Object?>{
      'room_id': _room,
      'owner': _anna,
      'photo_id': 'kaputt',
      'created_at': 1,
      'cleared': 0,
      'w': 64,
      'h': 48,
      'data': 'AAAA',
    });
    expect(await store.photo(_room, _anna), isNull);
    expect(await store.photos(_room), isEmpty);
  });

  test('wipe leert beide Tabellen', () async {
    await store.putPhoto(_room, _stored());
    await store.addReset(_room, const AvatarReset(target: _anna, photoId: _id1, photoCreatedAt: 1));
    await store.wipe();
    expect(await db.query('avatar_photos'), isEmpty);
    expect(await db.query('avatar_resets'), isEmpty);
  });
}
