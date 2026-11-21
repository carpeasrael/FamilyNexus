import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_avatar_photo_store.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/sync/avatar_photo_sync.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_service.dart';
import 'package:family_nexus/domain/avatar_photo_store.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/avatar_photo_fixtures.dart';
import '../support/avatar_photo_peer.dart';
import '../support/fake_matrix.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _cara = '@cara:fake.test';

void main() {
  late FakeMatrixServer server;
  late AvatarPhotoPeer anna;
  late AvatarPhotoPeer ben;
  late AvatarPhotoPeer cara;
  final extra = <AvatarPhotoPeer>[];

  setUpAll(sqfliteFfiInit);

  /// Anna ist Moderatorin (Ersteller), Cara ebenfalls (zweite Moderatorin), Ben Mitglied.
  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    server.addAccount('dora', 'pw4', displayName: 'Dora');
    final mods = <String>{_anna, _cara};
    anna = await AvatarPhotoPeer.create(server, 'anna', 'pw1', moderators: mods, createFamily: 'Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, _ben);
    server.addMember(room, _cara, power: 50);
    ben = await AvatarPhotoPeer.create(server, 'ben', 'pw2', familyRoomId: room.id, moderators: mods);
    cara = await AvatarPhotoPeer.create(server, 'cara', 'pw3', familyRoomId: room.id, moderators: mods);
  });

  tearDown(() async {
    for (final p in <AvatarPhotoPeer>[anna, ben, cara, ...extra]) {
      await p.dispose();
    }
    extra.clear();
  });

  List<AvatarPhotoPeer> others(AvatarPhotoPeer me) =>
      <AvatarPhotoPeer>[anna, ben, cara, ...extra].where((p) => p != me).toList();

  Future<AvatarPhotoPeer> lateMember(String user, String pw) async {
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@$user:fake.test');
    final p = await AvatarPhotoPeer.create(server, user, pw, familyRoomId: room.id, moderators: <String>{_anna, _cara});
    extra.add(p);
    return p;
  }

  int sent(String type) => server.log.where((e) => e.type == type).length;

  test('Ein Foto erreicht alle Mitglieder, nur als verschlüsseltes Ereignis im Familienraum', () async {
    final photo = await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    for (final p in <AvatarPhotoPeer>[anna, cara, ben]) {
      expect((await p.service.visible(_ben))!.id, photo.id, reason: p.userId);
    }
    expect((await anna.service.visible(_ben))!.bytes, photo.bytes);
    expect(await ben.store.pendingPhotos(ben.roomId), isEmpty, reason: 'Gesendetes ist veröffentlicht');
    expect((await ben.store.photo(ben.roomId, _ben))!.eventId, isNotEmpty);
    expect(await anna.store.pendingPhotos(anna.roomId), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    final events = server.log.where((e) => e.type == AvatarPhotoCodec.type).toList();
    expect(events, hasLength(1));
    expect(events.single.roomId, anna.gateway.familyRoom!.id);
    expect(events.single.content['owner'], _ben);
    expect(events.single.content['data'], isNotEmpty);
  });

  test('Ändern: das neuere Foto gilt überall, die vorige eigene Kopie wird aufgeräumt', () async {
    final first = await ben.service.setOwn(jpegBytes(width: 40, height: 40));
    await ben.flush(others(ben));
    final firstEvent = (await ben.store.photo(ben.roomId, _ben))!.eventId;
    final second = await ben.service.setOwn(jpegBytes(width: 50, height: 50));
    await ben.flush(others(ben));
    expect(second.isNewerThan(first), isTrue);
    expect((await anna.service.visible(_ben))!.id, second.id);
    expect((await cara.service.visible(_ben))!.width, 50);
    expect(ben.gateway.redactedEvents, <String>[firstEvent], reason: 'nur die eigene Vorgänger-Kopie wird geschwärzt');
    expect(await ben.store.redactQueue(ben.roomId), isEmpty);
  });

  test('Entfernen: Löschmarke blendet das Foto überall aus', () async {
    await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    await ben.service.clearOwn();
    await ben.flush(others(ben));
    for (final p in <AvatarPhotoPeer>[anna, cara, ben]) {
      expect(await p.service.visible(_ben), isNull, reason: p.userId);
    }
    expect(sent(AvatarPhotoCodec.type), 2);
  });

  group('Resync für neue Mitglieder', () {
    test(
      'das aktuelle Foto kommt mit gleicher ID und gleichem created_at erneut, die alte Kopie wird aufgeräumt',
      () async {
        final photo = await ben.service.setOwn(jpegBytes());
        await ben.flush(others(ben));
        final oldEvent = (await ben.store.photo(ben.roomId, _ben))!.eventId;
        final dora = await lateMember('dora', 'pw4');
        await ben.flush(others(ben));
        await ben.flush(others(ben));
        final seen = (await dora.service.visible(_ben))!;
        expect(seen.id, photo.id);
        expect(seen.createdAt, photo.createdAt);
        expect(sent(AvatarPhotoCodec.type), 2, reason: 'Original und eine Wiederholung');
        expect((await ben.store.photo(ben.roomId, _ben))!.eventId, isNot(oldEvent));
        expect(ben.gateway.redactedEvents, contains(oldEvent), reason: 'die frühere Kopie wird geschwärzt');
      },
    );

    test('ein Mitglied ohne Foto sendet nichts', () async {
      await lateMember('dora', 'pw4');
      await ben.flush(others(ben));
      expect(sent(AvatarPhotoCodec.type), 0);
    });
  });

  group('Zurücksetzen durch Moderatoren', () {
    test('das Foto verschwindet überall; ein Resync des Eigentümers bringt es nicht zurück', () async {
      await ben.service.setOwn(jpegBytes());
      await ben.flush(others(ben));
      await cara.service.reset(_ben);
      await cara.flush(others(cara));
      for (final p in <AvatarPhotoPeer>[anna, ben, cara]) {
        expect(await p.service.visible(_ben), isNull, reason: p.userId);
      }
      expect(await ben.service.isResetFor(_ben), isTrue, reason: 'der Eigentümer weiß es');

      final dora = await lateMember('dora', 'pw4');
      await ben.flush(others(ben));
      await cara.flush(others(cara));
      await ben.flush(others(ben));
      expect(sent(AvatarPhotoCodec.type), 1, reason: 'Ben sendet das zurückgesetzte Foto nie erneut');
      expect(await dora.service.visible(_ben), isNull);
      expect(
        sent(AvatarResetCodec.type),
        greaterThanOrEqualTo(2),
        reason: 'der Moderator wiederholt den Reset beim Beitritt',
      );
    });

    test('ein neues Foto nach dem Zurücksetzen wird wieder gezeigt (kein Dauerverbot)', () async {
      await ben.service.setOwn(jpegBytes());
      await ben.flush(others(ben));
      await cara.service.reset(_ben);
      await cara.flush(others(cara));
      final fresh = await ben.service.setOwn(jpegBytes(width: 30, height: 30));
      await ben.flush(others(ben));
      expect((await anna.service.visible(_ben))!.id, fresh.id);
      expect(await ben.service.isResetFor(_ben), isFalse);
    });

    test('ein Zurücksetzen von einem Nicht-Moderator wird verworfen und gezählt', () async {
      final photo = await ben.service.setOwn(jpegBytes());
      await ben.flush(others(ben));
      final reset = AvatarReset(target: _ben, photoId: photo.id, photoCreatedAt: photo.createdAt);
      // Ben schickt für sich selbst ein „Zurücksetzen“ ab: Empfänger prüfen die Rolle des Absenders.
      await ben.gateway.publishAvatarReset(reset);
      await AvatarPhotoPeer.pumpAll(<AvatarPhotoPeer>[anna, ben, cara]);
      expect((await anna.service.visible(_ben))!.id, photo.id);
      expect(anna.sync.rejected, greaterThan(0));
    });
  });

  group('Fälschungen und Ungültiges', () {
    test('Absender ungleich Eigentümer wird verworfen', () async {
      final photo = AvatarPhotoCodec.encode(
        AvatarPhoto(
          owner: _ben,
          id: '00000000-0000-4000-8000-0000000000f1',
          createdAt: server.now().millisecondsSinceEpoch,
          cleared: false,
          width: 64,
          height: 48,
          bytes: jpegBytes(),
        ),
      );
      anna.gateway.injectSignal(AvatarPhotoSignal(_cara, DateTime.utc(2026), photo, eventId: r'$x'));
      await anna.sync.idle();
      expect(await anna.store.photos(anna.roomId), isEmpty);
      expect(anna.sync.rejected, 1);
    });

    test('Foto eines Nicht-Mitglieds wird verworfen', () async {
      final photo = AvatarPhotoCodec.encode(
        AvatarPhoto(
          owner: '@zed:fake.test',
          id: '00000000-0000-4000-8000-0000000000f2',
          createdAt: server.now().millisecondsSinceEpoch,
          cleared: false,
          width: 64,
          height: 48,
          bytes: jpegBytes(),
        ),
      );
      anna.gateway.injectSignal(AvatarPhotoSignal('@zed:fake.test', DateTime.utc(2026), photo));
      await anna.sync.idle();
      expect(await anna.store.photos(anna.roomId), isEmpty);
      expect(anna.sync.rejected, 1);
    });

    test('kaputter Inhalt und falsche Schemaversion werden verworfen', () async {
      anna.gateway.injectSignal(AvatarPhotoSignal(_ben, DateTime.utc(2026), <String, Object?>{'v': 1, 'owner': _ben}));
      anna.gateway.injectSignal(AvatarResetSignal(_cara, DateTime.utc(2026), <String, Object?>{'v': 9}));
      await anna.sync.idle();
      expect(anna.sync.rejected, 2);
      expect(await anna.store.photos(anna.roomId), isEmpty);
    });
  });

  test('Familienwechsel: Signale für eine andere Familie ändern den Bestand nicht', () async {
    final room = anna.gateway.familyRoom!;
    server.addAccount('eva', 'pw5', displayName: 'Eva');
    server.addMember(room, '@eva:fake.test');
    final eva = await AvatarPhotoPeer.create(
      server,
      'eva',
      'pw5',
      familyRoomId: room.id,
      roomIdOverride: '!andere:fake.test',
    );
    extra.add(eva);
    await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    expect(await eva.store.photos('!andere:fake.test'), isEmpty);
    expect((await anna.service.visible(_ben)), isNotNull);
  });

  test('Sperre: ein deaktiviertes Gerät sendet nichts und verarbeitet nichts', () async {
    final room = anna.gateway.familyRoom!;
    server.addAccount('fred', 'pw6', displayName: 'Fred');
    server.addMember(room, '@fred:fake.test');
    final off = await AvatarPhotoPeer.create(server, 'fred', 'pw6', familyRoomId: room.id, enabled: false);
    extra.add(off);
    await off.service.setOwn(jpegBytes());
    final before = off.gateway.publishAttempts;
    await off.sync.publishPending();
    off.sync.kick();
    expect(off.gateway.publishAttempts, before, reason: 'es wird nichts gesendet');
    expect(sent(AvatarPhotoCodec.type), 0);
    await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    await off.sync.idle();
    expect(await off.store.photo(off.roomId, _ben), isNull, reason: 'es wird nichts verarbeitet');
    expect((await anna.service.visible(_ben)), isNotNull);
    expect(AvatarPhotoFlags.enabled, isFalse, reason: 'Standard bleibt gesperrt');
  });

  test('Standardzustand: ohne enabled-Argument bleibt die Klasse inaktiv (Sperre aus)', () async {
    final room = anna.gateway.familyRoom!;
    server.addAccount('gina', 'pw7', displayName: 'Gina');
    server.addMember(room, '@gina:fake.test');
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'gina', password: 'pw7');
    gw.attachFamilyRoom(room.id);
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    final store = SqlAvatarPhotoStore(db);
    final service = AvatarPhotoService(
      store: store,
      roomId: room.id,
      myUserId: gw.userId!,
      isModerator: (_) => false,
      isMember: (_) => true,
    );
    // Absichtlich ohne `enabled`: es gilt die Voreinstellung der Sperre.
    final sync = AvatarPhotoSync(gateway: gw, service: service, store: store);
    expect(sync.enabled, AvatarPhotoFlags.enabled);
    expect(sync.enabled, isFalse);
    sync.start();
    await service.setOwn(jpegBytes());
    final before = gw.publishAttempts;
    await sync.publishPending();
    sync.kick();
    await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    await sync.idle();
    expect(gw.publishAttempts, before, reason: 'es wird nichts gesendet');
    expect(await store.photo(room.id, _ben), isNull, reason: 'es wird nichts verarbeitet');
    sync.dispose();
    await db.close();
  });

  group('Eigene Zeilen: fremde Einträge in den Warteschlangen werden nie gesendet oder geschwärzt', () {
    AvatarPhoto foreign(String id) => AvatarPhoto(
      owner: _ben,
      id: id,
      createdAt: server.now().millisecondsSinceEpoch,
      cleared: false,
      width: 64,
      height: 48,
      bytes: jpegBytes(),
    );

    test('eine fremde, ungesendete Zeile wird nicht gesendet', () async {
      await anna.store.putPhoto(anna.roomId, StoredAvatarPhoto(photo: foreign('00000000-0000-4000-8000-0000000000c1')));
      final before = anna.gateway.publishAttempts;
      await anna.sync.publishPending();
      expect(anna.gateway.publishAttempts, before);
      expect(sent(AvatarPhotoCodec.type), 0);
    });

    test('Schwärz-Aufträge einer fremden Zeile werden nicht ausgeführt', () async {
      await anna.store.putPhoto(
        anna.roomId,
        StoredAvatarPhoto(
          photo: foreign('00000000-0000-4000-8000-0000000000c2'),
          eventId: r'$ben1',
          published: true,
          redactIds: const <String>[r'$fremd'],
        ),
      );
      await anna.sync.publishPending();
      expect(anna.gateway.redactedEvents, isEmpty);
      expect((await anna.store.redactQueue(anna.roomId)).single.redactIds, <String>[r'$fremd']);
    });
  });

  test('Eigener Bestand einer anderen Familie wird nicht in die aktuelle Familie gesendet (#140)', () async {
    final room = anna.gateway.familyRoom!;
    server.addAccount('eva', 'pw5', displayName: 'Eva');
    server.addMember(room, '@eva:fake.test');
    final eva = await AvatarPhotoPeer.create(
      server,
      'eva',
      'pw5',
      familyRoomId: room.id,
      roomIdOverride: '!andere:fake.test',
    );
    extra.add(eva);
    await eva.service.setOwn(jpegBytes());
    final before = eva.gateway.publishAttempts;
    await eva.sync.publishPending();
    expect(eva.gateway.publishAttempts, before, reason: 'es wird nichts gesendet');
    expect(sent(AvatarPhotoCodec.type), 0);
    expect(
      await eva.store.pendingPhotos('!andere:fake.test'),
      hasLength(1),
      reason: 'bleibt für die andere Familie erhalten',
    );
  });

  test('Löschmarke eines zurückgesetzten Eigentümers wird trotzdem gesendet', () async {
    await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    await cara.service.reset(_ben);
    await cara.flush(others(cara));
    expect(await ben.service.isResetFor(_ben), isTrue);
    await ben.service.clearOwn();
    await ben.flush(others(ben));
    final events = server.log.where((e) => e.type == AvatarPhotoCodec.type).toList();
    expect(events, hasLength(2));
    expect(events.last.content['cleared'], isTrue);
  });

  group('Wartefenster und Fehlerarten beim Senden', () {
    test('ein Sendefehler öffnet das Wartefenster, ein Erfolg schließt es', () async {
      await ben.service.setOwn(jpegBytes());
      ben.gateway.failPublishes = true;
      await ben.sync.publishPending();
      expect(ben.sync.backoff.blocked, isTrue);
      ben.gateway.failPublishes = false;
      await ben.sync.publishPending();
      expect(ben.sync.backoff.blocked, isFalse);
    });

    test('ein nicht sendbares Foto (invalidInput) wird aus der Warteschlange genommen, ohne Wartefenster', () async {
      await ben.service.setOwn(jpegBytes());
      ben.gateway.publishAvatarError = GatewayError.invalidInput;
      await ben.sync.publishPending();
      expect(await ben.store.pendingPhotos(ben.roomId), isEmpty);
      expect(sent(AvatarPhotoCodec.type), 0);
      expect(ben.sync.backoff.blocked, isFalse);
      expect((await ben.service.visible(_ben)), isNotNull, reason: 'der lokale Stand bleibt');
    });
  });

  group('Fehler beim Senden und Aufräumen ändern den Stand nie', () {
    test(
      'Senden scheitert: das Foto bleibt lokal sichtbar und in der Warteschlange, später wird es gesendet',
      () async {
        final photo = await ben.service.setOwn(jpegBytes());
        ben.gateway.failPublishes = true;
        await ben.sync.publishPending();
        expect((await ben.service.visible(_ben))!.id, photo.id);
        expect(await ben.store.pendingPhotos(ben.roomId), hasLength(1));
        expect(sent(AvatarPhotoCodec.type), 0);
        ben.gateway.failPublishes = false;
        await ben.flush(others(ben));
        expect(await ben.store.pendingPhotos(ben.roomId), isEmpty);
        expect((await anna.service.visible(_ben))!.id, photo.id);
      },
    );

    test('Aufräumen scheitert vorübergehend: Stand bleibt richtig, der Auftrag wird später erledigt', () async {
      await ben.service.setOwn(jpegBytes());
      await ben.flush(others(ben));
      final firstEvent = (await ben.store.photo(ben.roomId, _ben))!.eventId;
      ben.gateway.redactError = GatewayError.serverUnreachable;
      final second = await ben.service.setOwn(jpegBytes(width: 44, height: 44));
      await ben.flush(others(ben));
      expect((await anna.service.visible(_ben))!.id, second.id, reason: 'das neue Foto gilt trotz Fehler');
      expect(ben.gateway.redactedEvents, isEmpty);
      expect((await ben.store.redactQueue(ben.roomId)).single.redactIds, <String>[firstEvent]);
      ben.gateway.redactError = null;
      await ben.sync.publishPending();
      expect(ben.gateway.redactedEvents, <String>[firstEvent]);
      expect(await ben.store.redactQueue(ben.roomId), isEmpty);
    });

    test('Aufräumen scheitert dauerhaft (verboten oder unbekannt): der Auftrag entfällt', () async {
      for (final err in <GatewayError>[GatewayError.notAllowed, GatewayError.notFound]) {
        await ben.service.setOwn(jpegBytes());
        await ben.flush(others(ben));
        ben.gateway.redactError = err;
        await ben.service.setOwn(jpegBytes(width: 41, height: 41));
        await ben.flush(others(ben));
        expect(await ben.store.redactQueue(ben.roomId), isEmpty, reason: err.name);
        ben.gateway.redactError = null;
      }
    });
  });

  test('Austritt: die Foto-Zeile des Mitglieds verschwindet, ein Zurücksetzen bleibt', () async {
    final photo = await ben.service.setOwn(jpegBytes());
    await ben.flush(others(ben));
    await cara.service.reset(_ben);
    await cara.flush(others(cara));
    await anna.gateway.removeMember(_ben);
    await anna.flush(<AvatarPhotoPeer>[cara]);
    expect(await anna.store.photo(anna.roomId, _ben), isNull);
    final resets = await anna.store.resets(anna.roomId);
    expect(resets.map((r) => r.reset.photoId), <String>[photo.id]);
    // Das alte Ereignis kommt noch einmal an: es bleibt zurückgesetzt, auch ohne Foto-Zeile.
    final again = AvatarPhotoCodec.encode(photo);
    server.addMember(anna.gateway.familyRoom!, _ben);
    anna.gateway.injectSignal(AvatarPhotoSignal(_ben, DateTime.utc(2026), again));
    await anna.sync.idle();
    expect(await anna.service.visible(_ben), isNull);
  });
}
