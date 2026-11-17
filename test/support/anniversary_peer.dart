import 'package:family_nexus/data/sync/anniversary_sync.dart';
import 'package:family_nexus/domain/anniversary_service.dart';
import 'package:family_nexus/domain/server.dart';

import 'fake_matrix.dart';
import 'memory_anniversary_store.dart';

/// Ein Gerät eines Nutzers mit Geburts- und Gedenktagen: Gateway, lokale Ablage, Dienst und Sync (E-104).
class AnniversaryPeer {
  AnniversaryPeer._(this.gateway, this.store, this.service, this.sync);

  final FakeMatrixGateway gateway;
  final MemoryAnniversaryStore store;
  final AnniversaryService service;
  final AnniversarySync sync;

  String get userId => gateway.userId!;

  static var _ids = 0;

  static Future<AnniversaryPeer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    String? familyRoomId,
    MemoryAnniversaryStore? store,
  }) async {
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    if (familyRoomId != null) gw.attachFamilyRoom(familyRoomId);
    final s = store ?? MemoryAnniversaryStore();
    final svc = AnniversaryService(
      store: s,
      myUserId: gw.userId!,
      today: () {
        final n = server.now().toUtc();
        return DateTime.utc(n.year, n.month, n.day);
      },
      clock: () => server.now(),
      idGenerator: () => '00000000-0000-4000-8000-2${(++_ids).toString().padLeft(11, '0')}',
    );
    final sync = AnniversarySync(gateway: gw, service: svc, store: s, retryInterval: const Duration(hours: 1));
    sync.start();
    return AnniversaryPeer._(gw, s, svc, sync);
  }

  Future<void> flush(List<AnniversaryPeer> others) async {
    await sync.publishPending();
    await pumpAll(<AnniversaryPeer>[this, ...others]);
  }

  static Future<void> pumpAll(List<AnniversaryPeer> peers) async {
    for (var i = 0; i < 3; i++) {
      for (final p in peers) {
        await p.sync.idle();
      }
    }
  }

  void dispose() => sync.dispose();
}
