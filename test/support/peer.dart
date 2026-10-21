import 'package:family_nexus/data/sync/calendar_sync.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/server.dart';

import 'fake_matrix.dart';
import 'memory_event_store.dart';

/// Ein Gerät eines Nutzers: Gateway, lokale Ablage, Kalenderdienst und Sync.
class Peer {
  Peer._(this.gateway, this.store, this.service, this.sync);

  final FakeMatrixGateway gateway;
  final MemoryEventStore store;
  final CalendarService service;
  final CalendarSync sync;

  String get userId => gateway.userId!;

  static Future<Peer> create(
    FakeMatrixServer server,
    String user,
    String password, {
    String? familyRoomId,
    DateTime Function()? clock,
    String Function()? ids,
  }) async {
    final gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: user, password: password);
    if (familyRoomId != null) gw.attachFamilyRoom(familyRoomId);
    final store = MemoryEventStore();
    final svc = CalendarService(store: store, myUserId: gw.userId!, clock: clock, idGenerator: ids);
    final sync = CalendarSync(gateway: gw, service: svc, store: store, retryInterval: const Duration(hours: 1));
    sync.start();
    return Peer._(gw, store, svc, sync);
  }

  Future<CalendarEvent> createEvent({
    String title = 'Termin',
    EventVisibility visibility = EventVisibility.shared,
    DateTime? start,
    List<int>? reminders,
  }) {
    final s = start ?? DateTime.utc(2026, 11, 2, 9);
    return service.create(
      title: title,
      start: s,
      end: s.add(const Duration(hours: 1)),
      timeZone: 'Europe/Berlin',
      visibility: visibility,
      reminders: reminders,
    );
  }

  void dispose() => sync.dispose();
}
