import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_avatar_photo_store.dart';
import 'package:family_nexus/data/sync/avatar_photo_sync.dart';
import 'package:family_nexus/domain/avatar_photo_service.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_matrix.dart';

/// Ein Gerät eines Nutzers mit Avatar-Fotos: Gateway, lokale (SQL-)Ablage, Dienst und Sync (#434, E-111).
class AvatarPhotoPeer {
  AvatarPhotoPeer._(this.gateway, this.db, this.store, this.service, this.sync);

  final FakeMatrixGateway gateway;
  final Database db;
  final SqlAvatarPhotoStore store;
  final AvatarPhotoService service;
  final AvatarPhotoSync sync;

  String get userId => gateway.userId!;
  String get roomId => service.roomId;

  /// [moderators]: Matrix-IDs der Moderatoren (Standard: nur Anna). [enabled] steuert die Sperre.
  /// [createFamily] legt eine neue Familie an (der Ersteller). [roomIdOverride] gibt dem Bestand eine andere Familie als die des Gateways (Familienwechsel, #140).
  static Future<AvatarPhotoPeer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    String? familyRoomId,
    Set<String> moderators = const <String>{'@anna:fake.test'},
    bool enabled = true,
    String? roomIdOverride,
    String? createFamily,
  }) async {
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    if (createFamily != null) await gw.createFamily(createFamily);
    if (familyRoomId != null) gw.attachFamilyRoom(familyRoomId);
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    final store = SqlAvatarPhotoStore(db);
    final svc = AvatarPhotoService(
      store: store,
      roomId: roomIdOverride ?? gw.familyRoom!.id,
      myUserId: gw.userId!,
      isModerator: moderators.contains,
      isMember: (id) => gw.family?.member(id)?.status == MemberStatus.joined,
      clock: () => server.now(),
    );
    final sync = AvatarPhotoSync(
      gateway: gw,
      service: svc,
      store: store,
      enabled: enabled,
      retryInterval: const Duration(hours: 1),
    );
    sync.start();
    return AvatarPhotoPeer._(gw, db, store, svc, sync);
  }

  Future<void> flush(List<AvatarPhotoPeer> others) async {
    await sync.publishPending();
    await pumpAll(<AvatarPhotoPeer>[this, ...others]);
  }

  static Future<void> pumpAll(List<AvatarPhotoPeer> peers) async {
    for (var i = 0; i < 3; i++) {
      for (final p in peers) {
        await p.sync.idle();
      }
    }
  }

  Future<void> dispose() async {
    sync.dispose();
    await db.close();
  }
}
