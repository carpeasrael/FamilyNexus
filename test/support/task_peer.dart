import 'package:family_nexus/data/sync/task_sync.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/tasks.dart';

import 'fake_matrix.dart';
import 'memory_task_store.dart';

/// Ein Gerät eines Nutzers mit Aufgabenlisten: Gateway, lokale Ablage, Dienst und Sync.
class TaskPeer {
  TaskPeer._(this.gateway, this.store, this.service, this.sync);

  final FakeMatrixGateway gateway;
  final MemoryTaskStore store;
  final TaskService service;
  final TaskSync sync;

  String get userId => gateway.userId!;

  static var _ids = 0;

  /// [moderators]: Matrix-IDs der Moderatoren (Standard: nur Anna).
  static Future<TaskPeer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    String? familyRoomId,
    Set<String> moderators = const <String>{'@anna:fake.test'},
  }) async {
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    if (familyRoomId != null) gw.attachFamilyRoom(familyRoomId);
    final store = MemoryTaskStore();
    final svc = TaskService(
      store: store,
      myUserId: gw.userId!,
      isModerator: moderators.contains,
      // Gleiche Uhr wie das Ereigniswesen des Fake-Servers.
      clock: () => server.now(),
      idGenerator: () => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}',
    );
    final sync = TaskSync(gateway: gw, service: svc, store: store, retryInterval: const Duration(hours: 1));
    sync.start();
    return TaskPeer._(gw, store, svc, sync);
  }

  Future<void> flush(List<TaskPeer> others) async {
    await sync.publishPending();
    await pumpAll(<TaskPeer>[this, ...others]);
  }

  static Future<void> pumpAll(List<TaskPeer> peers) async {
    for (var i = 0; i < 3; i++) {
      for (final p in peers) {
        await p.sync.idle();
      }
    }
  }

  void dispose() => sync.dispose();
}
