import 'package:family_nexus/data/sync/contact_sync.dart';
import 'package:family_nexus/domain/contact_service.dart';
import 'package:family_nexus/domain/server.dart';

import 'fake_matrix.dart';
import 'memory_contact_store.dart';

/// Blockierliste im Arbeitsspeicher (Test, #119): bildet `AppSettings.blockedUsers` mit Obergrenze nach.
class MemoryBlockedList implements BlockedListPort {
  MemoryBlockedList([Iterable<String> initial = const <String>[], this.limit = 200]) : list = <String>[...initial];
  final List<String> list;
  final int limit;
  int adds = 0;

  @override
  Set<String> get blocked => list.toSet();

  @override
  Future<void> add(Iterable<String> ids) async {
    adds++;
    for (final id in ids) {
      if (!list.contains(id) && list.length < limit) list.add(id);
    }
  }
}

/// Ein Gerät eines Nutzers mit Kontaktliste: Gateway, Ablage, Dienst und Sync (#119, K2c).
class ContactPeer {
  ContactPeer._(this.gateway, this.store, this.service, this.sync, this.blockedList);

  final FakeMatrixGateway gateway;
  final MemoryContactStore store;
  final ContactService service;
  final ContactSync sync;
  final MemoryBlockedList blockedList;

  static Future<ContactPeer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    MemoryContactStore? store,
    MemoryBlockedList? blockedList,
    FakeMatrixGateway? gateway,
    bool start = true,
  }) async {
    final gw = gateway ?? server.newDevice();
    if (gateway == null) await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    final s = store ?? MemoryContactStore();
    final blocked = blockedList ?? MemoryBlockedList();
    final svc = ContactService(store: s, myUserId: gw.userId!, clock: () => server.now());
    final sync = ContactSync(gateway: gw, service: svc, store: s, blockedList: blocked, retryInterval: const Duration(hours: 1), clock: () => server.now());
    if (start) sync.start();
    return ContactPeer._(gw, s, svc, sync, blocked);
  }

  Future<void> flush(List<ContactPeer> others) async {
    await sync.publishPending();
    await pumpAll(<ContactPeer>[this, ...others]);
  }

  static Future<void> pumpAll(List<ContactPeer> peers) async {
    for (var i = 0; i < 3; i++) {
      for (final p in peers) {
        await p.sync.idle();
      }
    }
  }

  void dispose() => sync.dispose();
}
