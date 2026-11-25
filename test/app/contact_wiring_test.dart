import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';
import '../support/memory_contact_store.dart';
import '../support/memory_event_store.dart';

/// #119, K2c (E-114): Verdrahtung der Kontakt-Synchronisation in `buildCalendarController`. Die Sperre gilt auch hier.
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gateway;
  late MemoryContactStore store;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    store = MemoryContactStore();
  });

  CalendarController build({MemoryContactStore? contacts, bool? enabled, String? room, MemoryBlockedList? blocked}) => buildCalendarController(
        store: MemoryEventStore(),
        gateway: gateway,
        userId: gateway.userId!,
        zoneName: 'UTC',
        retryInterval: const Duration(hours: 1),
        familyRoom: room,
        contactStore: contacts,
        contactsEnabled: enabled ?? ContactFlags.enabled,
        blockedList: blocked,
      );

  test('Standard: die Sperre ist an, es entsteht keine Kontakt-Synchronisation und der Speicher bleibt unberührt', () async {
    expect(ContactFlags.enabled, isFalse);
    final c = build(contacts: store);
    expect(c.contactSync, isNull);
    c.start();
    await c.idle();
    c.dispose();
    expect(await store.all(), isEmpty);
  });

  test('Standardwert der Factory: mit Ablage, aber ohne ausdrückliche Freigabe entsteht keine Synchronisation', () {
    final c = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
      retryInterval: const Duration(hours: 1),
      contactStore: store,
    );
    expect(c.contactSync, isNull);
    c.dispose();
  });

  test('freigeschaltet, aber ohne Ablage: keine Synchronisation', () {
    final c = build(enabled: true);
    expect(c.contactSync, isNull);
    c.dispose();
  });

  test('freigeschaltet mit Ablage: die Synchronisation entsteht auch ohne Familie, startet und endet mit dem Controller', () async {
    final blocked = MemoryBlockedList();
    final c = build(contacts: store, enabled: true, blocked: blocked);
    expect(c.contactSync, isNotNull);
    expect(gateway.family, isNull, reason: 'Kontakte gehören zum Konto, nicht zur Familie');
    await c.contactSync!.service.block('@ben:example.org');
    c.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await c.idle();
    expect(blocked.list, <String>['@ben:example.org'], reason: 'der Start gleicht die Blockierliste ab');
    expect(server.log.where((e) => e.type == ContactCodec.type), hasLength(1), reason: 'der Datensatz wurde gesendet');
    c.dispose();
  });

  test('Lebenszyklus: idle wartet auf eingehende Datensätze, dispose beendet die Synchronisation', () async {
    final c = build(contacts: store, enabled: true);
    c.start();
    final other = server.newDevice();
    await other.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await other.publishContactRecord(Contact(id: '@carla:example.org', state: ContactState.accepted, version: 1, updatedAt: server.now()));
    await c.idle();
    expect(await store.get(ContactKind.contact, '@carla:example.org'), isNotNull, reason: 'idle wartet auf die Verarbeitung');
    // ignore: invalid_use_of_protected_member
    expect(gateway.hasListeners, isTrue);
    c.dispose();
    // ignore: invalid_use_of_protected_member
    expect(gateway.hasListeners, isFalse, reason: 'dispose beendet die Synchronisation');
  });

  test('mit Familie wie ohne Familie: dieselbe Synchronisation', () async {
    await gateway.createFamily('Familie');
    final c = build(contacts: store, enabled: true, room: gateway.familyRoom!.id);
    expect(c.contactSync, isNotNull);
    c.dispose();
  });
}
