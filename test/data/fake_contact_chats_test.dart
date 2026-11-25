import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #119, K3a-2a: Der Fake stuft Kontakt-Räume mit **derselben** reinen [ConversationPolicy] ein wie das echte Gateway (die
/// Tests des Gateways stehen in `book_gateway_sync_test.dart`, Gruppe „Kontakt-Einzelchats“). Hier: das Verhalten, auf das
/// sich die Controller-Tests (K3b) verlassen.
void main() {
  const carla = '@carla:fake.test';
  const dora = '@dora:fake.test';
  const emil = '@emil:fake.test'; // Familienmitglied
  late FakeRoom gwFamilyRoom;

  late TestApp app;
  late FakeMatrixGateway gw;
  late String me;

  setUp(() async {
    app = await buildTestApp();
    app.server.addAccount('carla', 'pw-carla', displayName: 'Carla');
    app.server.addAccount('dora', 'pw-dora', displayName: 'Dora');
    app.server.addAccount('emil', 'pw-emil', displayName: 'Emil');
    gwFamilyRoom = app.gateway.familyRoom!;
    gwFamilyRoom.membership[emil] = MemberStatus.joined;
    gw = app.gateway;
    me = gw.userId!;
  });

  ContactPolicy policy(Map<String, ContactState> contacts, {bool enabled = true, Set<String> blocked = const <String>{}}) =>
      ContactPolicy(enabled: enabled, contacts: contacts, blocked: blocked);

  List<ChatThread> contacts() => gw.threads.where((t) => t.kind == ThreadKind.contact).toList();

  test('Kontakt mit Datensatz und beigetretenem Gegenüber: Thread „Name · server“, außerhalb der Familie', () {
    final r = app.server.createContactRoom(carla, me, toJoined: true);
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    final t = contacts().single;
    expect(t.id, r.id);
    expect(t.title, 'Carla · fake.test');
    expect(t.isOutside, isTrue);
    expect(t.pending, isFalse);
  });

  test('ohne Datensatz, Bereich aus, blockiert: kein Thread', () {
    app.server.createContactRoom(carla, me, toJoined: true);
    expect(contacts(), isEmpty);
    gw.setContactPolicy(policy({carla: ContactState.accepted}, enabled: false));
    expect(contacts(), isEmpty);
    gw.setContactPolicy(policy({carla: ContactState.blocked}, blocked: {carla}));
    expect(contacts(), isEmpty);
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    expect(contacts(), hasLength(1));
  });

  test('Anfrage von Fremden ohne Datensatz; Familienmitglied nie; ablehnen entfernt sie', () async {
    final r = app.server.createContactRoom(carla, me);
    gw.setContactPolicy(policy(const <String, ContactState>{}));
    expect(gw.contactRequests.map((q) => (q.roomId, q.fromUserId, q.fromName)), <(String, String, String)>[(r.id, carla, 'Carla · fake.test')]);
    expect(contacts(), isEmpty);
    await gw.declineContactRequest(r.id);
    expect(gw.contactRequests, isEmpty);
    await expectLater(gw.declineContactRequest(r.id), throwsA(isA<GatewayException>()));
  });

  test('Einladung eines Kontakts mit Datensatz wird beim Setzen der Richtlinie angenommen', () {
    final r = app.server.createContactRoom(carla, me);
    expect(contacts(), isEmpty);
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    expect(contacts().single.id, r.id);
    expect(gw.contactRequests, isEmpty);
  });

  test('wartender Raum (outgoing, Gegenüber eingeladen): pending, Senden verweigert', () async {
    final r = app.server.createContactRoom(me, carla);
    gw.setContactPolicy(policy({carla: ContactState.outgoing}));
    final t = contacts().single;
    expect(t.pending, isTrue);
    await gw.openThread(r.id);
    await expectLater(gw.sendMessage('Hallo', threadId: r.id), throwsA(isA<GatewayException>()));
  });

  test('Senden nur nach openThread und bei beigetretenem Gegenüber; Reaktionen nie; messagesIn erst nach openThread', () async {
    final r = app.server.createContactRoom(carla, me, toJoined: true);
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    await expectLater(gw.sendMessage('Hallo', threadId: r.id), throwsA(isA<GatewayException>()));
    await gw.openThread(r.id);
    await gw.sendMessage('Hallo', threadId: r.id);
    expect(gw.messagesIn(r.id).map((m) => m.body), <String>['Hallo']);
    await expectLater(gw.sendReaction(gw.messagesIn(r.id).single.id, '👍', threadId: r.id), throwsA(isA<GatewayException>()));
  });

  test('familyUnreadCount zählt Kontakte nie, unreadCount schon', () async {
    final r = app.server.createContactRoom(carla, me, toJoined: true);
    r.events.add(FakeEvent('e1', r.id, carla, 'm.room.message', <String, Object?>{'body': 'Hi'}, DateTime.now()));
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    await gw.openThread(r.id);
    expect(gw.familyUnreadCount, 0);
    expect(gw.unreadCount, greaterThan(0));
  });

  test('leaveConversation: nur Kontakt-Threads; danach weg', () async {
    final r = app.server.createContactRoom(carla, me, toJoined: true);
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    await expectLater(gw.leaveConversation(ChatThread.familyId), throwsA(isA<GatewayException>()));
    await gw.leaveConversation(r.id);
    expect(contacts(), isEmpty);
  });

  test('dritte Person: ein Raum mit ihr ist nur mit eigenem Datensatz ein Thread', () {
    app.server.createContactRoom(dora, me, toJoined: true);
    gw.setContactPolicy(policy({carla: ContactState.accepted}));
    expect(contacts(), isEmpty);
  });

  group('Kontakt hinzufügen (K3a-2b)', () {
    test('probeContact: vorhanden/erreichbar; Familienmitglied ohne Netz; nicht gefunden', () async {
      gw.setContactPolicy(policy({carla: ContactState.outgoing}));
      final p = await gw.probeContact(carla);
      expect((p.existence, p.reachability, p.displayName), (ContactExistence.yes, ContactReachability.reachable, 'Carla'));
      final calls = app.server.probeNetworkCalls;
      final fam = await gw.probeContact(emil);
      expect(fam.isFamilyMember, isTrue);
      expect(app.server.probeNetworkCalls, calls);
      expect((await gw.probeContact('@niemand:fake.test')).existence, ContactExistence.no);
    });

    test('probeContact: nicht erreichbar, Schlüsselabfrage gescheitert, Profil unbekannt; Vorbedingungen', () async {
      gw.setContactPolicy(policy({carla: ContactState.outgoing}));
      app.server.unreachableUsers.add(carla);
      expect((await gw.probeContact(carla)).reachability, ContactReachability.notReachable);
      app.server.keyQueryFailures.add(dora);
      expect((await gw.probeContact(dora)).reachability, ContactReachability.unknown);
      app.server.profileUnknown.add(dora);
      expect((await gw.probeContact(dora)).existence, ContactExistence.unknown);
      await expectLater(gw.probeContact(me), throwsA(isA<GatewayException>()));
      gw.setContactPolicy(policy({carla: ContactState.blocked}, blocked: {carla}));
      await expectLater(gw.probeContact(carla), throwsA(isA<GatewayException>()));
    });

    test('startContactChat: nur mit Datensatz outgoing; legt einen wartenden Kontakt-Raum an; Wiederverwendung', () async {
      await expectLater(gw.startContactChat(carla), throwsA(isA<GatewayException>()), reason: 'Bereich aus');
      gw.setContactPolicy(policy(const <String, ContactState>{}));
      await expectLater(gw.startContactChat(carla), throwsA(isA<GatewayException>()), reason: 'ohne Datensatz');
      gw.setContactPolicy(policy({carla: ContactState.outgoing}));
      final id = await gw.startContactChat(carla);
      expect(contacts().single.pending, isTrue);
      expect(await gw.startContactChat(carla), id, reason: 'derselbe Raum');
      expect(app.server.contactRooms, hasLength(1));
    });

    test('startContactChat: nicht erreichbar ⇒ peerNotReachable, Abfragefehler ⇒ serverUnreachable; kein Raum', () async {
      gw.setContactPolicy(policy({carla: ContactState.outgoing, dora: ContactState.outgoing}));
      app.server.unreachableUsers.add(carla);
      app.server.keyQueryFailures.add(dora);
      await expectLater(gw.startContactChat(carla), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.peerNotReachable)));
      await expectLater(gw.startContactChat(dora), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnreachable)));
      expect(app.server.contactRooms, isEmpty);
    });

    test('Familienmitglied nie, auch mit Datensatz', () async {
      gw.setContactPolicy(policy({emil: ContactState.outgoing}));
      await expectLater(gw.startContactChat(emil), throwsA(isA<GatewayException>()));
    });

    test('Senden an nicht erreichbare Kontakte: peerNotReachable; Anzeige reachable=false', () async {
      final r = app.server.createContactRoom(carla, me, toJoined: true);
      gw.setContactPolicy(policy({carla: ContactState.accepted}));
      await gw.openThread(r.id);
      app.server.unreachableUsers.add(carla);
      expect(contacts().single.reachable, isFalse);
      await expectLater(gw.sendMessage('Hallo', threadId: r.id), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.peerNotReachable)));
    });
  });
}
