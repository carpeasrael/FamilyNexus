import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/peer.dart';

/// #431, E-112: Senden einer Moderatorfassung und Empfang bei Besitzerin und drittem Mitglied (Fake-Server).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  // Der Fake-Server stempelt Ereignisse ab 2026-10-21 12:00; alle Uhren liegen daneben.
  var clock = DateTime.utc(2026, 10, 21, 12, 30);
  DateTime now() => clock;

  late FakeMatrixServer server;
  late Peer anna; // Besitzerin
  late Peer cara; // Moderatorin
  late Peer ben; // drittes Mitglied
  late Map<String, Role?> roles;

  Role? roleOf(String id) => roles[id];

  setUp(() async {
    clock = DateTime.utc(2026, 10, 21, 12, 30);
    server = FakeMatrixServer();
    for (final n in <String>['anna', 'cara', 'ben']) {
      server.addAccount(n, 'pw', displayName: n);
    }
    roles = <String, Role?>{
      '@anna:fake.test': Role.moderator,
      '@cara:fake.test': Role.moderator,
      '@ben:fake.test': Role.member,
    };
    anna = await Peer.create(server, 'anna', 'pw', clock: now, syncClock: now, roleOf: roleOf);
    await anna.gateway.createFamily('Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@cara:fake.test', power: 50);
    server.addMember(room, '@ben:fake.test');
    cara = await Peer.create(server, 'cara', 'pw', familyRoomId: room.id, clock: now, syncClock: now, roleOf: roleOf);
    ben = await Peer.create(server, 'ben', 'pw', familyRoomId: room.id, clock: now, syncClock: now, roleOf: roleOf);
  });

  tearDown(() {
    anna.dispose();
    cara.dispose();
    ben.dispose();
  });

  Future<CalendarEvent> sharedByAnna() async {
    final e = await anna.createEvent(title: 'Elternabend');
    await anna.sync.publishPending();
    await pumpEventQueue();
    expect((await cara.store.get(e.id)), isNotNull, reason: 'Basis bei der Moderatorin');
    return e;
  }

  test('Moderatorin ändert: Besitzerin und drittes Mitglied übernehmen, Besitzerin sendet nichts erneut', () async {
    final e = await sharedByAnna();
    final edited = await cara.service.update((await cara.store.get(e.id))!.copyWith(title: 'Elternabend 19 Uhr'));
    expect(edited.editorId, '@cara:fake.test');
    expect((await cara.store.pendingPublish()).single.id, e.id);
    await cara.sync.publishPending();
    await pumpEventQueue();
    for (final p in <Peer>[anna, ben]) {
      final got = await p.store.get(e.id);
      expect(got!.title, 'Elternabend 19 Uhr');
      expect(got.editorId, '@cara:fake.test');
      expect(got.ownerId, anna.userId);
    }
    expect(await cara.store.pendingPublish(), isEmpty, reason: 'als veröffentlicht markiert');
    expect(await anna.store.pendingPublish(), isEmpty, reason: 'die Besitzerin sendet die Fassung nicht als eigene');
  });

  test('Resync der Besitzerin gibt die Moderatorfassung (mit editor-Behauptung) an ein neues Mitglied weiter', () async {
    final e = await sharedByAnna();
    await cara.service.update((await cara.store.get(e.id))!.copyWith(title: 'Neu'));
    await cara.sync.publishPending();
    await pumpEventQueue();
    server.addAccount('dora', 'pw', displayName: 'dora');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@dora:fake.test');
    final dora = await Peer.create(server, 'dora', 'pw', familyRoomId: room.id, clock: now, syncClock: now, roleOf: roleOf);
    addTearDown(dora.dispose);
    anna.gateway.injectSignal(MemberJoinedSignal('@dora:fake.test', now()));
    await pumpEventQueue();
    await anna.sync.publishPending();
    await pumpEventQueue();
    final got = await dora.store.get(e.id);
    expect(got?.title, 'Neu');
    expect(got?.editorId, '@cara:fake.test');
  });

  test('als Mitglied herabgestuft: die Fassung wird nicht gesendet und gilt als erledigt', () async {
    final e = await sharedByAnna();
    await cara.service.update((await cara.store.get(e.id))!.copyWith(title: 'Zu spät'));
    roles['@cara:fake.test'] = Role.member;
    await cara.sync.publishPending();
    await pumpEventQueue();
    expect((await anna.store.get(e.id))!.title, 'Elternabend');
    expect(await cara.store.pendingPublish(), isEmpty);
    expect(
      server.log.where((x) => x.type == EventCodec.sharedType && x.content['title'] == 'Zu spät'),
      isEmpty,
      reason: 'gar nicht erst gesendet, nicht nur vom Empfänger abgelehnt',
    );
  });

  test('Rolle unbekannt: die Fassung bleibt in der Warteschlange und geht nach Bekanntwerden hinaus', () async {
    final e = await sharedByAnna();
    await cara.service.update((await cara.store.get(e.id))!.copyWith(title: 'Später'));
    roles['@cara:fake.test'] = null;
    await cara.sync.publishPending();
    await pumpEventQueue();
    expect((await cara.store.pendingPublish()), hasLength(1));
    expect((await anna.store.get(e.id))!.title, 'Elternabend');
    roles['@cara:fake.test'] = Role.moderator;
    await cara.sync.publishPending();
    await pumpEventQueue();
    expect((await anna.store.get(e.id))!.title, 'Später');
  });

  test('lange liegengebliebene Fassung wird vor dem Senden neu gestempelt und vom Empfänger angenommen', () async {
    final e = await sharedByAnna();
    clock = DateTime.utc(2026, 10, 17, 12); // Änderung vier Tage vor dem Senden
    final old = await cara.service.update((await cara.store.get(e.id))!.copyWith(title: 'Alt gestempelt'));
    clock = DateTime.utc(2026, 10, 21, 12, 30);
    await cara.sync.publishPending();
    await pumpEventQueue();
    final got = await anna.store.get(e.id);
    expect(got!.title, 'Alt gestempelt');
    expect(got.version, old.version, reason: 'gleiche Version, nur der Zeitstempel ist neu');
    expect(got.updatedAt, clock);
    expect((await cara.store.history(e.id)).where((h) => h.version == old.version), isEmpty, reason: 'kein Verlaufseintrag');
  });

  test('Mitglied sendet nie: ein gefälschter Moderator-Versuch bleibt bei den anderen unwirksam', () async {
    final e = await sharedByAnna();
    // Ben ändert lokal an der Dienstebene vorbei (gefälschte Fassung) und sendet über das Gateway.
    final forged = (await ben.store.get(e.id))!.copyWith(title: 'Gefälscht', version: 2, editorId: '@ben:fake.test');
    await ben.gateway.publishSharedEvent(forged);
    await pumpEventQueue();
    expect((await anna.store.get(e.id))!.title, 'Elternabend');
    expect((await cara.store.get(e.id))!.title, 'Elternabend');
  });
}
