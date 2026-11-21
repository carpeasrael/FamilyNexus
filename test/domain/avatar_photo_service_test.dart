import 'dart:typed_data';

import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_avatar_photo_store.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_service.dart';
import 'package:family_nexus/domain/avatar_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/avatar_photo_fixtures.dart';

const String _room = '!familie:fake.test';
const String _anna = '@anna:fake.test'; // eigenes Konto
const String _ben = '@ben:fake.test';
const String _cora = '@cora:fake.test'; // Moderatorin
const String _fremd = '@fremd:fake.test';

String _id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  late Database db;
  late SqlAvatarPhotoStore store;
  late AvatarPhotoService service;
  late DateTime now;
  late Set<String> moderators;
  late Set<String> members;
  final ids = <String>[];

  setUpAll(sqfliteFfiInit);

  AvatarPhotoService build({String me = _anna}) => AvatarPhotoService(
    store: store,
    roomId: _room,
    myUserId: me,
    isModerator: moderators.contains,
    isMember: members.contains,
    clock: () => now,
    idGenerator: () => ids.isEmpty ? _id(900) : ids.removeAt(0),
  );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlAvatarPhotoStore(db);
    now = DateTime.utc(2026, 11, 21, 12);
    moderators = <String>{_cora};
    members = <String>{_anna, _ben, _cora};
    ids.clear();
    service = build();
  });

  tearDown(() => db.close());

  AvatarPhoto photo(String owner, int n, int createdAt) => AvatarPhoto(
    owner: owner,
    id: _id(n),
    createdAt: createdAt,
    cleared: false,
    width: 64,
    height: 48,
    bytes: jpegBytes(),
  );

  AvatarPhoto marker(String owner, int n, int createdAt) =>
      AvatarPhoto.clearedMarker(owner: owner, id: _id(n), createdAt: createdAt);

  AvatarReset resetOf(AvatarPhoto p) => AvatarReset(target: p.owner, photoId: p.id, photoCreatedAt: p.createdAt);

  group('neuestes Ereignis gewinnt, unabhängig von der Reihenfolge', () {
    test('alle Reihenfolgen von drei Fotos enden beim neuesten', () async {
      final p1 = photo(_ben, 1, 1000);
      final p2 = photo(_ben, 2, 2000);
      final p3 = photo(_ben, 3, 3000);
      final orders = <List<AvatarPhoto>>[
        [p1, p2, p3], [p1, p3, p2], [p2, p1, p3], [p2, p3, p1], [p3, p1, p2], [p3, p2, p1], //
      ];
      for (final order in orders) {
        await store.wipe();
        for (final p in order) {
          await service.acceptPhoto(p, eventId: r'$x');
        }
        expect((await service.visible(_ben))!.id, p3.id, reason: order.map((p) => p.createdAt).join(','));
      }
    });

    test('bei gleichem createdAt entscheidet die größere ID, in beiden Reihenfolgen', () async {
      final a = photo(_ben, 1, 1000);
      final b = photo(_ben, 2, 1000);
      await service.acceptPhoto(a, eventId: r'$a');
      await service.acceptPhoto(b, eventId: r'$b');
      expect((await service.visible(_ben))!.id, b.id);
      await store.wipe();
      await service.acceptPhoto(b, eventId: r'$b');
      await service.acceptPhoto(a, eventId: r'$a');
      expect((await service.visible(_ben))!.id, b.id);
    });

    test('gleichzeitig eintreffende Ereignisse werden nacheinander verarbeitet', () async {
      final all = <AvatarPhoto>[for (var i = 1; i <= 8; i++) photo(_ben, i, i * 100)];
      await Future.wait(<Future<bool>>[for (final p in all.reversed) service.acceptPhoto(p, eventId: r'$x')]);
      expect((await service.visible(_ben))!.id, _id(8));
    });

    test('dasselbe Ereignis zweimal ändert nichts', () async {
      final p = photo(_ben, 1, 1000);
      expect(await service.acceptPhoto(p, eventId: r'$a'), isTrue);
      expect(await service.acceptPhoto(p, eventId: r'$a'), isFalse);
    });
  });

  group('kein Rückfall auf ältere Fotos', () {
    test('eine neuere Löschmarke blendet das Foto aus; ein später eintreffendes älteres bleibt wirkungslos', () async {
      await service.acceptPhoto(photo(_ben, 1, 1000), eventId: r'$a');
      await service.acceptPhoto(marker(_ben, 2, 2000), eventId: r'$b');
      expect(await service.visible(_ben), isNull);
      expect(await service.acceptPhoto(photo(_ben, 3, 500), eventId: r'$c'), isFalse);
      expect(await service.visible(_ben), isNull);
    });

    test('eine Löschmarke in beliebiger Reihenfolge ergibt dasselbe', () async {
      await service.acceptPhoto(marker(_ben, 2, 2000), eventId: r'$b');
      await service.acceptPhoto(photo(_ben, 1, 1000), eventId: r'$a');
      expect(await service.visible(_ben), isNull);
    });

    test('ein neueres Foto nach der Löschmarke ist wieder sichtbar', () async {
      await service.acceptPhoto(marker(_ben, 2, 2000), eventId: r'$b');
      await service.acceptPhoto(photo(_ben, 3, 3000), eventId: r'$c');
      expect((await service.visible(_ben))!.id, _id(3));
    });
  });

  group('Zurücksetzen durch Moderatoren', () {
    test('versteckt das neueste Foto; ein Resync derselben ID bleibt versteckt; ein neues Foto wird gezeigt', () async {
      final p = photo(_ben, 1, 1000);
      await service.acceptPhoto(p, eventId: r'$a');
      expect(await service.acceptReset(resetOf(p), sender: _cora), isTrue);
      expect(await service.visible(_ben), isNull);
      expect(await service.isResetFor(_ben), isTrue);

      // Der Eigentümer sendet dasselbe Foto erneut (Resync): gleiche ID, gleiches createdAt.
      await service.acceptPhoto(p, eventId: r'$a2');
      expect(await service.visible(_ben), isNull);

      await service.acceptPhoto(photo(_ben, 2, 2000), eventId: r'$b');
      expect((await service.visible(_ben))!.id, _id(2));
      expect(await service.isResetFor(_ben), isFalse);
    });

    test('Reset und Foto in beiden Reihenfolgen ergeben denselben Endstand', () async {
      final p = photo(_ben, 1, 1000);
      await service.acceptReset(resetOf(p), sender: _cora);
      await service.acceptPhoto(p, eventId: r'$a');
      final resetFirst = await service.visible(_ben);

      await store.wipe();
      await service.acceptPhoto(p, eventId: r'$a');
      await service.acceptReset(resetOf(p), sender: _cora);
      final photoFirst = await service.visible(_ben);

      expect(resetFirst, isNull);
      expect(photoFirst, resetFirst);
    });

    test('ein Reset vor dem Foto bleibt erhalten, bis ein neueres Foto da ist; dann wird aufgeräumt', () async {
      final old = photo(_ben, 1, 1000);
      await service.acceptReset(resetOf(old), sender: _cora);
      expect(await store.resets(_room), hasLength(1));
      await service.acceptPhoto(old, eventId: r'$a');
      expect(await store.resets(_room), hasLength(1), reason: 'dasselbe Foto ist nicht neuer');
      await service.acceptPhoto(photo(_ben, 2, 2000), eventId: r'$b');
      expect(await store.resets(_room), isEmpty);
    });

    test('Reset von einem Nicht-Moderator, für ein Nicht-Mitglied und mit ungültigem Inhalt wird verworfen', () async {
      final p = photo(_ben, 1, 1000);
      await service.acceptPhoto(p, eventId: r'$a');
      expect(await service.acceptReset(resetOf(p), sender: _ben), isFalse);
      expect(await service.acceptReset(resetOf(p), sender: _fremd), isFalse);
      expect(
        await service.acceptReset(
          AvatarReset(target: _fremd, photoId: _id(1), photoCreatedAt: 1),
          sender: _cora,
        ),
        isFalse,
      );
      expect(
        await service.acceptReset(
          const AvatarReset(target: _ben, photoId: 'x', photoCreatedAt: 1),
          sender: _cora,
        ),
        isFalse,
      );
      expect((await service.visible(_ben))!.id, _id(1));
    });

    test('Grenze: ein später herabgestufter Moderator ändert einen angenommenen Reset nicht, neue Resets von ihm gelten nicht mehr', () async {
      final p = photo(_ben, 1, 1000);
      await service.acceptPhoto(p, eventId: r'$a');
      await service.acceptReset(resetOf(p), sender: _cora);
      moderators.remove(_cora); // Herabstufung
      expect(await service.visible(_ben), isNull, reason: 'bereits angenommen, bleibt lokal');
      final p2 = photo(_ben, 2, 2000);
      await service.acceptPhoto(p2, eventId: r'$b');
      expect(await service.acceptReset(resetOf(p2), sender: _cora), isFalse);
      expect((await service.visible(_ben))!.id, _id(2));
    });
  });

  group('Mitglieder', () {
    test('ein Foto von einem Nicht-Mitglied oder ein ungültiges Foto wird verworfen', () async {
      expect(await service.acceptPhoto(photo(_fremd, 1, 1000), eventId: r'$a'), isFalse);
      final broken = AvatarPhoto(
        owner: _ben,
        id: 'x',
        createdAt: 1,
        cleared: false,
        width: 64,
        height: 48,
        bytes: jpegBytes(),
      );
      expect(await service.acceptPhoto(broken, eventId: r'$b'), isFalse);
      expect(await store.photos(_room), isEmpty);
    });

    test('Austritt und Wiedereintritt: das alte, zurückgesetzte Foto taucht nicht wieder auf', () async {
      final p = photo(_ben, 1, 1000);
      await service.acceptPhoto(p, eventId: r'$a');
      await service.acceptReset(resetOf(p), sender: _cora);
      await service.removeMember(_ben);
      expect(await store.photo(_room, _ben), isNull);
      expect(await store.resets(_room), hasLength(1));
      // Nach dem Wiedereintritt kommt das alte Ereignis noch einmal an (Verlauf, Resync).
      await service.acceptPhoto(p, eventId: r'$a');
      expect(await service.visible(_ben), isNull);
    });
  });

  group('eigenes Foto', () {
    test('setOwn speichert ein ungesendetes Ereignis und macht es sichtbar', () async {
      ids.add(_id(1));
      final p = await service.setOwn(jpegBytes());
      expect(p.owner, _anna);
      expect(p.id, _id(1));
      expect(p.createdAt, now.millisecondsSinceEpoch);
      expect((await service.visible(_anna))!.id, _id(1));
      expect((await store.pendingPhotos(_room)).single.photo.id, _id(1));
    });

    test('setOwn lehnt Ungültiges ab', () async {
      for (final bad in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        jpegBytes(width: 200, height: 100),
      ]) {
        await expectLater(
          service.setOwn(bad),
          throwsA(isA<AvatarPhotoException>().having((e) => e.error, 'error', AvatarPhotoError.invalid)),
        );
      }
      await expectLater(
        service.setOwn(jpegBytes(width: 192, height: 192, quality: 95, noisy: true)),
        throwsA(isA<AvatarPhotoException>()),
      );
      expect(await store.photos(_room), isEmpty);
    });

    test('createdAt wächst auch bei zurückgestellter Uhr (letztes + 1)', () async {
      ids.addAll(<String>[_id(1), _id(2)]);
      final first = await service.setOwn(jpegBytes());
      now = now.subtract(const Duration(hours: 5)); // die Uhr wird zurückgestellt
      final second = await service.setOwn(jpegBytes());
      expect(second.createdAt, first.createdAt + 1);
      expect(second.isNewerThan(first), isTrue);
    });

    test('liegt das nächste createdAt über der Obergrenze, wird nicht gesendet (Uhrfehler)', () async {
      await store.putPhoto(
        _room,
        StoredAvatarPhoto(
          photo: photo(_anna, 1, now.add(const Duration(days: 1)).millisecondsSinceEpoch),
          published: true,
        ),
      );
      await expectLater(
        service.setOwn(jpegBytes()),
        throwsA(isA<AvatarPhotoException>().having((e) => e.error, 'error', AvatarPhotoError.clock)),
      );
      await expectLater(service.clearOwn(), throwsA(isA<AvatarPhotoException>()));
    });

    test('clearOwn löst das Foto durch eine Löschmarke ab', () async {
      ids.addAll(<String>[_id(1), _id(2)]);
      final p = await service.setOwn(jpegBytes());
      final c = await service.clearOwn();
      expect(c.cleared, isTrue);
      expect(c.isNewerThan(p), isTrue);
      expect(await service.visible(_anna), isNull);
    });

    test('das Ersetzen eines gesendeten eigenen Fotos merkt das Aufräumen vor', () async {
      ids.addAll(<String>[_id(1), _id(2)]);
      final first = await service.setOwn(jpegBytes());
      await store.markPublished(_room, _anna, first.id, r'$e1');
      await service.setOwn(jpegBytes());
      expect((await store.redactQueue(_room)).single.redactIds, <String>[r'$e1']);
    });

    test('Der Sendestand eines eigenen Echos ändert nichts: dasselbe Foto kommt zurück', () async {
      ids.add(_id(1));
      final p = await service.setOwn(jpegBytes());
      expect(await service.acceptPhoto(p, eventId: r'$echo'), isFalse);
      expect((await service.visible(_anna))!.id, p.id);
    });
  });

  group('reset (Moderator setzt das angezeigte Foto zurück)', () {
    late AvatarPhotoService mod;
    setUp(() => mod = build(me: _cora));

    test('legt ein ungesendetes Zurücksetzen für die angezeigte ID an', () async {
      final p = photo(_ben, 4, 4000);
      await mod.acceptPhoto(p, eventId: r'$a');
      final r = await mod.reset(_ben);
      expect(r.photoId, p.id);
      expect(r.photoCreatedAt, p.createdAt);
      expect(await mod.visible(_ben), isNull);
      expect((await store.pendingResets(_room)).single.reset, r);
    });

    test('nur Moderatoren, nur für ein anderes Mitglied mit sichtbarem Foto', () async {
      await service.acceptPhoto(photo(_ben, 1, 1000), eventId: r'$a');
      await expectLater(
        service.reset(_ben),
        throwsA(isA<AvatarPhotoException>().having((e) => e.error, 'error', AvatarPhotoError.notAllowed)),
      );
      await expectLater(mod.reset(_fremd), throwsA(isA<AvatarPhotoException>()));
      await expectLater(mod.reset(_cora), throwsA(isA<AvatarPhotoException>()));
      await expectLater(mod.reset(_anna), throwsA(isA<AvatarPhotoException>()), reason: 'kein Foto vorhanden');
      await mod.acceptPhoto(marker(_anna, 2, 2000), eventId: r'$b');
      await expectLater(mod.reset(_anna), throwsA(isA<AvatarPhotoException>()), reason: 'Löschmarke zeigt kein Foto');
    });
  });
}
