import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/contact_service.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/features/contacts/contact_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';

/// #119, K3b-1 (E-114): Abläufe des Kontakt-Controllers gegen den Fake: Datensatz zuerst, Rücknahme, Entfernen, Blockieren
/// und Entsperren, Anfragen, lokale Prüfungen vor jeder Netzabfrage.
void main() {
  const carla = '@carla:fake.test';
  const dora = '@dora:fake.test';
  const emil = '@emil:fake.test'; // Familienmitglied

  late FakeMatrixServer server;
  late ContactPeer peer;
  late ContactController c;
  late String me;

  Matcher fails(ContactError e) => throwsA(isA<ContactException>().having((x) => x.error, 'error', e));

  setUp(() async {
    server = FakeMatrixServer();
    for (final n in <String>['anna', 'carla', 'dora', 'emil']) {
      server.addAccount(n, 'pw-$n', displayName: n[0].toUpperCase() + n.substring(1));
    }
    peer = await ContactPeer.create(server, 'anna', 'pw-anna');
    await peer.gateway.createFamily('Familie');
    server.rooms.values.first.membership[emil] = MemberStatus.joined;
    me = peer.gateway.userId!;
    c = ContactController(gateway: peer.gateway, sync: peer.sync);
    c.start();
    await c.idle();
  });

  tearDown(() {
    c.dispose();
    peer.dispose();
  });

  Future<void> on() async {
    await c.setEnabled(true);
    await c.idle();
  }

  test('Start: geladen, Standard aus, keine Netzabfrage, nichts gesendet', () async {
    expect(c.loaded, isTrue);
    expect(c.enabled, isFalse);
    expect(c.contacts, isEmpty);
    expect(c.requests, isEmpty);
    expect(server.probeNetworkCalls, 0);
    expect(peer.gateway.contactPolicy, ContactPolicy.off);
    expect(c.myContactId, me);
  });

  test('Einschalten schreibt die Einstellung und schiebt die Richtlinie; Ausschalten löscht nichts', () async {
    await on();
    expect(c.enabled, isTrue);
    expect(peer.gateway.contactPolicy.enabled, isTrue);
    await c.add(carla);
    await c.setEnabled(false);
    await c.idle();
    expect(c.enabled, isFalse);
    expect(c.requests, isEmpty);
    expect(await peer.service.contact(carla), isNotNull, reason: 'nichts gelöscht');
    expect(peer.gateway.contactPolicy.enabled, isFalse);
  });

  group('check', () {
    test('lokale Prüfungen vor jeder Netzabfrage: ungültig, eigene Kennung, schon Kontakt, blockiert (Datensatz und lokale Liste)', () async {
      await on();
      await c.add(carla);
      await peer.service.block(dora);
      peer.blockedList.list.add('@frank:fake.test');
      final calls = server.probeNetworkCalls;
      expect((await c.check('kein-konto')).outcome, ContactCheckOutcome.invalid);
      expect((await c.check(me)).outcome, ContactCheckOutcome.self);
      expect((await c.check(carla)).outcome, ContactCheckOutcome.duplicate);
      expect((await c.check(dora)).outcome, ContactCheckOutcome.blockedRecord);
      expect((await c.check('@frank:fake.test')).outcome, ContactCheckOutcome.blockedLocal);
      expect(server.probeNetworkCalls, calls, reason: 'alles lokal, kein Abfluss');
    });

    test('Ergebnisse: bereit, Familienmitglied, nicht gefunden, nicht erreichbar, unbekannt', () async {
      await on();
      final ready = await c.check(carla);
      expect((ready.outcome, ready.userId, ready.title), (ContactCheckOutcome.ready, carla, 'Carla · fake.test'));
      expect((await c.check(emil)).outcome, ContactCheckOutcome.familyMember);
      expect((await c.check('@niemand:fake.test')).outcome, ContactCheckOutcome.notFound);
      server.unreachableUsers.add(dora);
      expect((await c.check(dora)).outcome, ContactCheckOutcome.notReachable);
      server.addAccount('gina', 'pw-gina', displayName: 'Gina');
      server.keyQueryFailures.add('@gina:fake.test');
      expect((await c.check('@gina:fake.test')).outcome, ContactCheckOutcome.unknown);
    });

    test('rateLimited sperrt „Prüfen“ für 60 s, danach wieder möglich; notAllowed ⇒ notReady', () async {
      var now = DateTime.utc(2026, 11, 25, 12);
      c.dispose();
      c = ContactController(gateway: peer.gateway, sync: peer.sync, clock: () => now)..start();
      await c.idle();
      await on();
      server.probeError = GatewayError.rateLimited;
      expect((await c.check(carla)).outcome, ContactCheckOutcome.rateLimited);
      expect(c.checkBlockedUntil, isNotNull);
      server.probeError = null;
      final calls = server.probeNetworkCalls;
      expect((await c.check(carla)).outcome, ContactCheckOutcome.rateLimited, reason: 'gesperrt, ohne Netz');
      expect(server.probeNetworkCalls, calls);
      now = now.add(const Duration(seconds: 61));
      expect((await c.check(carla)).outcome, ContactCheckOutcome.ready);
      server.probeError = GatewayError.notAllowed;
      expect((await c.check(dora)).outcome, ContactCheckOutcome.notReady);
    });
  });

  group('add', () {
    test('Datensatz zuerst, dann Richtlinie, dann Raum; der Kontakt wartet auf Annahme', () async {
      await on();
      await c.add(carla);
      await c.idle();
      expect((await peer.service.contact(carla))!.state, ContactState.outgoing);
      expect(peer.gateway.contactPolicy.contacts[carla], ContactState.outgoing);
      expect(server.contactRooms, hasLength(1));
      expect(c.contacts.single.state, ContactStateView.waiting);
      expect(c.contacts.single.title, 'Carla · fake.test');
    });

    test('Familienmitglied, ausgeschaltet, eigene Kennung, blockiert: verweigert, **kein** Datensatz', () async {
      await expectLater(c.add(carla), fails(ContactError.notAllowed), reason: 'Bereich aus');
      await on();
      await expectLater(c.add(emil), fails(ContactError.notAllowed));
      await expectLater(c.add(me), fails(ContactError.notAllowed));
      peer.blockedList.list.add(dora);
      await expectLater(c.add(dora), fails(ContactError.notAllowed));
      await expectLater(c.add('kein-konto'), fails(ContactError.invalid));
      expect(await peer.store.all(), hasLength(1), reason: 'nur die Einstellung');
      expect(server.contactRooms, isEmpty);
    });

    test('nicht erreichbar: Fehler, Datensatz zurückgenommen (Löschmarke), keine Richtlinie mehr, kein Raum', () async {
      await on();
      server.unreachableUsers.add(carla);
      await expectLater(c.add(carla), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.peerNotReachable)));
      await c.idle();
      final rec = (await peer.store.get(ContactKind.contact, carla))!;
      expect((rec.deleted, rec.version), (true, 2));
      expect(c.contacts, isEmpty);
      expect(peer.gateway.contactPolicy.contacts, isEmpty);
      expect(server.contactRooms, isEmpty);
    });

    test('Rücknahme nur bei gleicher Version: ein zwischenzeitlicher Stand bleibt', () async {
      await on();
      server.keyQueryFailures.add(carla);
      // `startContactChat` scheitert; dazwischen wird der Datensatz bestätigt (Empfang/Abgleich): nie löschen.
      final f = c.add(carla);
      await peer.service.markAccepted(carla);
      await expectLater(f, throwsA(isA<GatewayException>()));
      final rec = (await peer.store.get(ContactKind.contact, carla))!;
      expect(((rec as Contact).state, rec.deleted), (ContactState.accepted, false));
    });

    test('Doppeltipp: nur ein Raum', () async {
      await on();
      await Future.wait<void>(<Future<void>>[c.add(carla), c.add(carla)]);
      expect(server.contactRooms, hasLength(1));
    });

    test('„Erneut senden“: outgoing ohne Raum; ohne Datensatz notFound; Familie/Blockierte verweigert', () async {
      await on();
      await peer.service.addOutgoing(carla); // z. B. nach Abbruch der App
      await c.idle();
      expect(c.contacts.single.state, ContactStateView.notSent);
      await c.retry(carla);
      await c.idle();
      expect(server.contactRooms, hasLength(1));
      expect(c.contacts.single.state, ContactStateView.waiting);
      await c.retry(carla); // idempotent: derselbe Raum
      expect(server.contactRooms, hasLength(1));
      await expectLater(c.retry(dora), fails(ContactError.notFound));
      await expectLater(c.retry(emil), fails(ContactError.notAllowed));
    });
  });

  group('Anfragen', () {
    test('Anfrage erscheint mit Namen und Kennung; „weitere Anfragen“ folgt dem Gateway', () async {
      await on();
      final room = server.createContactRoom(carla, me);
      peer.gateway.hiddenRequests = 3;
      peer.gateway.setContactPolicy(peer.gateway.contactPolicy); // Gateway meldet
      server.notifyAll();
      await c.idle();
      expect(c.requests.map((r) => (r.roomId, r.fromUserId, r.fromName)), <(String, String, String)>[(room.id, carla, 'Carla · fake.test')]);
      expect(c.requestsHidden, 3);
    });

    test('annehmen: Datensatz accepted, Richtlinie, die Auto-Annahme betritt den Raum; bestätigt', () async {
      await on();
      final room = server.createContactRoom(carla, me);
      server.notifyAll();
      await c.idle();
      await c.accept(room.id);
      for (var i = 0; i < 3; i++) {
        await peer.sync.idle();
        await c.idle();
      }
      expect((await peer.service.contact(carla))!.state, ContactState.accepted);
      expect(c.requests, isEmpty);
      expect(c.contacts.single.state, ContactStateView.confirmed);
      expect(room.invitedUsers, isNot(contains(me)));
    });

    test('ablehnen: Raum verlassen, kein Datensatz; erneutes Ablehnen ist kein Fehler', () async {
      await on();
      final room = server.createContactRoom(carla, me);
      server.notifyAll();
      await c.idle();
      await c.decline(room.id);
      await c.decline(room.id);
      await c.idle();
      expect(c.requests, isEmpty);
      expect(room.dmMembers, isNot(contains(me)));
      expect(await peer.service.contact(carla), isNull);
    });

    test('blockieren: nur der Datensatz; die Einladung bleibt unbeantwortet (der Absender erfährt nichts)', () async {
      await on();
      final room = server.createContactRoom(carla, me);
      server.notifyAll();
      await c.idle();
      await c.blockRequest(room.id);
      await c.idle();
      expect((await peer.service.contact(carla))!.state, ContactState.blocked);
      expect(peer.blockedList.list, contains(carla));
      expect(c.requests, isEmpty);
      expect(room.invitedUsers, contains(me), reason: 'nicht abgelehnt, nicht verlassen');
      expect(room.dmMembers, contains(me));
    });
  });

  group('verwalten', () {
    test('entfernen: erst den Raum verlassen, dann den Datensatz löschen', () async {
      await on();
      final room = server.createContactRoom(carla, me, toJoined: true);
      await c.add(dora); // zweiter Kontakt, bleibt
      server.notifyAll();
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await c.idle();
      expect(c.contacts.map((e) => e.id), containsAll(<String>[carla, dora]));
      await c.remove(carla);
      await c.idle();
      expect(room.dmMembers, isNot(contains(me)));
      expect(c.contacts.map((e) => e.id), <String>[dora]);
    });

    test('entfernen scheitert beim Verlassen: Datensatz bleibt, alles unverändert', () async {
      await on();
      server.createContactRoom(carla, me, toJoined: true);
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await c.idle();
      peer.gateway.failLeaveConversation = true;
      await expectLater(c.remove(carla), throwsA(isA<GatewayException>()));
      expect((await peer.service.contact(carla))!.deleted, isFalse);
      peer.gateway.failLeaveConversation = false;
      await c.remove(carla);
      expect((await peer.service.contact(carla))!.deleted, isTrue);
    });

    test('blockieren verlässt keinen Raum; entsperren löscht auch die lokale Blockierung; erneut hinzufügen funktioniert', () async {
      await on();
      final room = server.createContactRoom(carla, me, toJoined: true);
      await peer.service.addAccepted(carla);
      await peer.sync.pushPolicyNow();
      await c.idle();
      await c.block(carla);
      await c.idle();
      expect(c.contacts.single.state, ContactStateView.blocked);
      expect(peer.blockedList.list, contains(carla));
      expect(room.dmMembers, contains(me), reason: 'der Raum bleibt');
      await expectLater(c.remove(carla), fails(ContactError.notAllowed), reason: 'blockierte nur entsperren');
      await c.unblock(carla);
      await c.idle();
      expect(peer.blockedList.list, isNot(contains(carla)));
      expect(c.contacts, isEmpty);
      await c.add(carla);
      await c.idle();
      expect(c.contacts.single.id, carla);
    });

    test('unblockLocal: ohne Datensatz freigeben; ein Familienmitglied bleibt blockiert (E-48)', () async {
      await on();
      peer.blockedList.list.addAll(<String>[dora, emil]);
      await c.unblockLocal(dora);
      expect(peer.blockedList.list, isNot(contains(dora)));
      await expectLater(c.unblockLocal(emil), fails(ContactError.notAllowed));
      expect(peer.blockedList.list, contains(emil));
      await expectLater(c.unblockLocal('kein-konto'), fails(ContactError.invalid));
    });
  });

  test('die Ansicht folgt dem Abgleich: tritt die Gegenseite bei, wechselt der Zustand ohne weiteren Anstoß', () async {
    await on();
    final room = server.createContactRoom(me, carla);
    await peer.service.addOutgoing(carla);
    await peer.sync.pushPolicyNow();
    await c.idle();
    expect(c.contacts.single.state, ContactStateView.waiting);
    var notified = 0;
    c.addListener(() => notified++);
    room.invitedUsers.clear();
    server.notifyAll();
    for (var i = 0; i < 4; i++) {
      await peer.sync.idle();
      await c.idle();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(c.contacts.single.state, ContactStateView.confirmed);
    expect((await peer.service.contact(carla))!.state, ContactState.accepted);
    expect(notified, greaterThan(0));
  });

  test('accepted ohne Gespräch: „Gespräch wird gesucht“ (nicht stumm bestätigt)', () async {
    await on();
    await peer.service.addAccepted(carla);
    await c.idle();
    expect(c.contacts.single.state, ContactStateView.searching);
  });

  test('keine Benachrichtigung ohne Änderung der Ansicht', () async {
    await on();
    await c.idle();
    var n = 0;
    c.addListener(() => n++);
    server.notifyAll();
    server.notifyAll();
    await c.idle();
    expect(n, 0);
  });

  test('nach dispose kein Zugriff mehr', () async {
    c.dispose();
    server.notifyAll();
    await peer.service.setEnabled(true);
    await peer.sync.idle();
    // kein Fehler (kein Aufruf nach dispose); tearDown ruft dispose erneut nicht auf
    c = ContactController(gateway: peer.gateway, sync: peer.sync);
  });
}
