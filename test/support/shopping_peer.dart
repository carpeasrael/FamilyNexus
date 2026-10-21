import 'package:family_nexus/data/sync/shopping_sync.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/shopping.dart';

import 'fake_matrix.dart';
import 'memory_shopping_store.dart';

/// Ein Gerät eines Nutzers mit Einkaufsliste: Gateway, lokale Ablage, Dienst und Sync.
class ShoppingPeer {
  ShoppingPeer._(this.gateway, this.store, this.service, this.sync);

  final FakeMatrixGateway gateway;
  final MemoryShoppingStore store;
  final ShoppingService service;
  final ShoppingSync sync;

  String get userId => gateway.userId!;

  static var _ids = 0;

  static Future<ShoppingPeer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    String? familyRoomId,
  }) async {
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    if (familyRoomId != null) gw.attachFamilyRoom(familyRoomId);
    final store = MemoryShoppingStore();
    final svc = ShoppingService(
      store: store,
      myUserId: gw.userId!,
      idGenerator: () => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}',
    );
    final sync = ShoppingSync(gateway: gw, service: svc, store: store, retryInterval: const Duration(hours: 1));
    sync.start();
    return ShoppingPeer._(gw, store, svc, sync);
  }

  /// Sendet ausstehende Änderungen und wartet, bis alle Empfänger sie verarbeitet haben.
  Future<void> flush(List<ShoppingPeer> others) async {
    await sync.publishPending();
    await pumpAll(<ShoppingPeer>[this, ...others]);
  }

  static Future<void> pumpAll(List<ShoppingPeer> peers) async {
    for (var i = 0; i < 3; i++) {
      for (final p in peers) {
        await p.sync.idle();
      }
    }
  }

  void dispose() => sync.dispose();
}
