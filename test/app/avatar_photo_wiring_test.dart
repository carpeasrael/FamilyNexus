import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_avatar_photo_store.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/avatar_photo_fixtures.dart';
import '../support/fake_matrix.dart';
import '../support/memory_event_store.dart';

/// #434, E-111: Verdrahtung der Avatar-Fotos in `buildCalendarController`. Die Sperre gilt auch hier: Ohne Angabe folgt die
/// Sync-Klasse der Freigabe (seit Teil 3 aktiv), `avatarPhotosEnabled: false` sperrt sie ausdrücklich.
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gateway;
  late Database db;
  late SqlAvatarPhotoStore store;
  late String roomId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gateway.createFamily('Familie');
    roomId = gateway.familyRoom!.id;
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

  test('ohne Ablage oder ohne Familie entstehen weder Dienst noch Sync', () {
    final noStore = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
      familyRoom: roomId,
    );
    final noRoom = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
      avatarPhotoStore: store,
    );
    for (final c in <CalendarController>[noStore, noRoom]) {
      expect(c.avatarPhotos, isNull);
      expect(c.avatarPhotoSync, isNull);
    }
  });

  test(
    'ausdrücklich gesperrt (avatarPhotosEnabled: false): die Sync-Klasse bleibt inaktiv und sendet nichts',
    () async {
      final c = buildCalendarController(
        store: MemoryEventStore(),
        gateway: gateway,
        userId: gateway.userId!,
        zoneName: 'UTC',
        retryInterval: const Duration(hours: 1),
        avatarPhotoStore: store,
        familyRoom: roomId,
        avatarPhotosEnabled: false,
      );
      expect(c.avatarPhotoSync, isNotNull);
      expect(c.avatarPhotoSync!.enabled, isFalse);
      c.start(familyRoom: roomId);
      await c.avatarPhotos!.setOwn(jpegBytes());
      final before = gateway.publishAttempts;
      await c.avatarPhotoSync!.publishPending();
      await c.idle();
      expect(gateway.publishAttempts, before);
      expect(server.log.where((e) => e.type == AvatarPhotoCodec.type), isEmpty);
      c.dispose();
    },
  );

  test('Standard: ohne avatarPhotosEnabled folgt die Fabrik der Freigabe (Teil 3: aktiv) und sendet', () async {
    final c = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
      retryInterval: const Duration(hours: 1),
      avatarPhotoStore: store,
      familyRoom: roomId,
    );
    expect(c.avatarPhotoSync!.enabled, AvatarPhotoFlags.enabled);
    expect(c.avatarPhotoSync!.enabled, isTrue);
    c.start(familyRoom: roomId);
    await c.avatarPhotos!.setOwn(jpegBytes());
    await c.avatarPhotoSync!.publishPending();
    await c.idle();
    expect(server.log.where((e) => e.type == AvatarPhotoCodec.type), hasLength(1));
    c.dispose();
  });

  test(
    'mit avatarPhotosEnabled: true sendet der Controller das Foto; start, idle und dispose sind verdrahtet',
    () async {
      final c = buildCalendarController(
        store: MemoryEventStore(),
        gateway: gateway,
        userId: gateway.userId!,
        zoneName: 'UTC',
        retryInterval: const Duration(hours: 1),
        avatarPhotoStore: store,
        familyRoom: roomId,
        avatarPhotosEnabled: true,
      );
      expect(c.avatarPhotoSync!.enabled, isTrue);
      c.start(familyRoom: roomId);
      final photo = await c.avatarPhotos!.setOwn(jpegBytes());
      await c.avatarPhotoSync!.publishPending();
      await c.idle();
      final events = server.log.where((e) => e.type == AvatarPhotoCodec.type).toList();
      expect(events, hasLength(1));
      expect(events.single.content['id'], photo.id);
      expect(await store.pendingPhotos(roomId), isEmpty);
      c.dispose();
    },
  );
}
