import 'package:family_nexus/data/sync/event_theme_sync.dart';
import 'package:family_nexus/domain/event_theme_service.dart';
import 'package:family_nexus/domain/server.dart';

import 'fake_matrix.dart';
import 'memory_event_theme_store.dart';

/// Ein Gerät eines Nutzers mit Kalender-Themen: Gateway, lokale Ablage, Dienst und Sync (E-99).
class EventThemePeer {
  EventThemePeer._(this.gateway, this.store, this.service, this.sync);

  final FakeMatrixGateway gateway;
  final MemoryEventThemeStore store;
  final EventThemeService service;
  final EventThemeSync sync;

  String get userId => gateway.userId!;

  static var _ids = 0;

  /// [moderators]: Matrix-IDs der Moderatoren (Standard: nur Anna).
  static Future<EventThemePeer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    String? familyRoomId,
    Set<String> moderators = const <String>{'@anna:fake.test'},
    MemoryEventThemeStore? store,
  }) async {
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    if (familyRoomId != null) gw.attachFamilyRoom(familyRoomId);
    final themeStore = store ?? MemoryEventThemeStore();
    final svc = EventThemeService(
      store: themeStore,
      myUserId: gw.userId!,
      isModerator: moderators.contains,
      // Gleiche Uhr wie das Ereigniswesen des Fake-Servers.
      clock: () => server.now(),
      idGenerator: () => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '1')}',
    );
    final sync = EventThemeSync(gateway: gw, service: svc, store: themeStore, retryInterval: const Duration(hours: 1));
    sync.start();
    return EventThemePeer._(gw, themeStore, svc, sync);
  }

  Future<void> flush(List<EventThemePeer> others) async {
    await sync.publishPending();
    await pumpAll(<EventThemePeer>[this, ...others]);
  }

  static Future<void> pumpAll(List<EventThemePeer> peers) async {
    for (var i = 0; i < 3; i++) {
      for (final p in peers) {
        await p.sync.idle();
      }
    }
  }

  void dispose() => sync.dispose();
}
