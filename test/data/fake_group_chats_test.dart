import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #119, K4-2a: Der Fake stuft Gruppen mit **derselben** reinen [ConversationPolicy] ein wie das echte Gateway (dessen Tests
/// stehen in `book_gateway_sync_test.dart`, Gruppe „Gruppen“). Hier: das Verhalten, auf das sich die Controller-Tests (K4-3)
/// verlassen.
void main() {
  const carla = '@carla:fake.test';
  const emil = '@emil:fake.test'; // Familienmitglied

  late TestApp app;
  late FakeMatrixGateway gw;
  late String me;

  setUp(() async {
    app = await buildTestApp();
    app.server.addAccount('carla', 'pw-carla', displayName: 'Carla');
    app.server.addAccount('emil', 'pw-emil', displayName: 'Emil');
    app.gateway.familyRoom!.membership[emil] = MemberStatus.joined;
    gw = app.gateway;
    me = gw.userId!;
  });

  ContactPolicy policy({Set<String> groups = const <String>{}, bool enabled = true, Set<String> blocked = const <String>{}}) =>
      ContactPolicy(enabled: enabled, groups: groups, blocked: blocked);

  Matcher error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

  List<ChatThread> groups() => gw.threads.where((t) => t.kind == ThreadKind.group).toList();

  test('Gruppe nur mit Datensatz und Bereich an: Thread außerhalb der Familie, sonst keiner', () {
    final r = app.server.createGroupRoom(carla, 'Skat', joined: <String>[me]);
    gw.setContactPolicy(policy());
    expect(groups(), isEmpty);
    gw.setContactPolicy(policy(groups: <String>{r.id}, enabled: false));
    expect(groups(), isEmpty);
    gw.setContactPolicy(policy(groups: <String>{r.id}));
    final t = groups().single;
    expect(t.title, 'Skat');
    expect(t.isOutside, isTrue);
    expect(t.peerId, isNull);
    expect(t.memberCount, 2);
    expect(t.sendLock, GroupSendLock.keiner);
  });

  test('Sperrgründe: zu groß, unverschlüsselt, Regel, Verlauf; die Gruppe bleibt sichtbar und verlassbar', () async {
    final r = app.server.createGroupRoom(carla, 'Groß', joined: <String>[me, for (var i = 0; i < 50; i++) '@u$i:fake.test']);
    gw.setContactPolicy(policy(groups: <String>{r.id}));
    expect(groups().single.sendLock, GroupSendLock.zuGross);
    r.dmMembers.removeWhere((m) => m.startsWith('@u'));
    r.groupEncrypted = false;
    expect(groups().single.sendLock, GroupSendLock.unverschluesselt);
    r.groupEncrypted = true;
    r.joinRule = 'public';
    expect(groups().single.sendLock, GroupSendLock.regelGeaendert);
    r.joinRule = 'invite';
    r.history = 'shared';
    expect(groups().single.sendLock, GroupSendLock.verlaufGeoeffnet);
    await gw.leaveConversation(r.id);
    expect(groups(), isEmpty);
    expect(gw.leftGroupRooms, <String>{r.id});
  });

  test('Gruppenanfrage: Name, Einladender, inviterIsFamily nach Familie; ablehnen entfernt sie; Einzelchat-Anfragen bleiben getrennt', () async {
    final a = app.server.createGroupRoom(carla, 'Skat', invited: <String>[me], inviter: carla);
    final b = app.server.createGroupRoom(emil, 'Ausflug', invited: <String>[me], inviter: emil);
    gw.setContactPolicy(policy());
    final byRoom = {for (final r in gw.contactRequests) r.roomId: r};
    expect(byRoom[a.id]!.isGroup, isTrue);
    expect(byRoom[a.id]!.groupName, 'Skat');
    expect(byRoom[a.id]!.inviterIsFamily, isFalse);
    expect(byRoom[b.id]!.inviterIsFamily, isTrue);
    await gw.declineContactRequest(a.id);
    expect(gw.contactRequests.map((r) => r.roomId), <String>[b.id]);
  });

  test('acceptGroupInvite: Beitritt mit Nachprüfung; Verstoß verlässt den Raum (notAllowed); idempotent', () async {
    final ok = app.server.createGroupRoom(carla, 'Skat', invited: <String>[me], inviter: carla);
    final bad = app.server.createGroupRoom(carla, 'Offen', invited: <String>[me], inviter: carla)..history = 'shared';
    gw.setContactPolicy(policy(groups: <String>{ok.id, bad.id}));
    await gw.acceptGroupInvite(ok.id);
    await gw.acceptGroupInvite(ok.id);
    expect(groups().map((t) => t.id), <String>[ok.id]);
    await expectLater(gw.acceptGroupInvite(bad.id), error(GatewayError.notAllowed));
    expect(bad.dmMembers, isNot(contains(me)));
    expect(gw.leftGroupRooms, <String>{bad.id});
    await expectLater(gw.acceptGroupInvite('!gibtsnicht:fake.test'), error(GatewayError.notFound));
  });

  test('createGroup: Raum ohne Mitglieder, Name geprüft, Doppelstart alreadyExists, 50 Gruppen; Gruppe sichtbar erst mit Datensatz; verlassen geht', () async {
    gw.setContactPolicy(policy());
    await expectLater(gw.createGroup('  '), error(GatewayError.invalidInput));
    await expectLater(gw.createGroup('x' * 61), error(GatewayError.invalidInput));
    gw.groupCreationRunning = true;
    await expectLater(gw.createGroup('Zwei'), error(GatewayError.alreadyExists));
    gw.groupCreationRunning = false;
    final id = await gw.createGroup(' Neue Runde ');
    expect(app.server.groupRooms[id]!.dmMembers, <String>{me});
    expect(app.server.groupRooms[id]!.name, 'Neue Runde');
    expect(groups(), isEmpty, reason: 'ohne Datensatz keine Gruppe');
    gw.setContactPolicy(policy(groups: <String>{id}));
    expect(groups().single.canManage, isTrue);
    await gw.leaveConversation(id);
    expect(groups(), isEmpty);
    gw.setContactPolicy(policy(groups: <String>{for (var i = 0; i < ContactLimits.maxGroups; i++) '!x$i:fake.test'}));
    await expectLater(gw.createGroup('Noch eine'), error(GatewayError.notAllowed));
  });

  // K4-2b: ersetzt „Senden in Gruppen ist gesperrt (Platzhalter bis K4-2b): Text und Reaktion notAllowed“ (K4-2a) ausdrücklich; der
  // Fake bildet jetzt das Tor des Gateways ab, die Gegenproben stehen unten.
  group('Senden in Gruppen (K4-2b, Fake spiegelt das Tor)', () {
    Future<FakeRoom> openGroup({List<String> joined = const <String>[]}) async {
      final r = app.server.createGroupRoom(carla, 'Skat', joined: <String>[me, ...joined]);
      gw.setContactPolicy(policy(groups: <String>{r.id}));
      await gw.openThread(r.id);
      return r;
    }

    test('Text und Reaktion gehen durch, Blockierte als Reaktionsziel nicht', () async {
      final r = await openGroup();
      await gw.sendMessage('Hallo', threadId: r.id);
      final id = gw.messagesIn(r.id).single.id;
      await gw.sendReaction(id, '👍', threadId: r.id);
      expect(gw.messagesIn(r.id).single.reactions['👍'], isNotNull);
      gw.setContactPolicy(policy(groups: <String>{r.id}, blocked: <String>{me}));
      await expectLater(gw.sendReaction(id, '🎉', threadId: r.id), error(GatewayError.notAllowed));
    });

    test('nicht geöffnet ⇒ notAllowed; nur ich ⇒ groupNoOtherMembers; zu groß ⇒ notAllowed', () async {
      final r = app.server.createGroupRoom(me, 'Allein');
      gw.setContactPolicy(policy(groups: <String>{r.id}));
      await expectLater(gw.sendMessage('x', threadId: r.id), error(GatewayError.notAllowed));
      await gw.openThread(r.id);
      await expectLater(gw.sendMessage('x', threadId: r.id), error(GatewayError.groupNoOtherMembers));
      expect(groups().single.sendLock, GroupSendLock.keineMitglieder);
      r.dmMembers.addAll(<String>[for (var i = 0; i < 51; i++) '@u$i:fake.test']);
      await expectLater(gw.sendMessage('x', threadId: r.id), error(GatewayError.notAllowed));
    });

    test('Weggang bei verzögertem Zustand: kein Wisch vor dem Zustandswechsel, danach genau einer; gescheitert ⇒ groupBusy', () async {
      final r = await openGroup(joined: <String>[carla]);
      gw.outboundPort.createSession(r.id, <String>{me, carla});
      gw.lagGroupState(r.id);
      gw.removeGroupMember(r.id, carla);
      await gw.syncGroups();
      expect(gw.outboundPort.wipes, 0, reason: 'das Gateway sieht den Weggang noch nicht');
      await gw.sendMessage('noch', threadId: r.id); // alter Stand: Carla noch da
      gw.outboundPort.wipeIneffective = true;
      await gw.releaseGroupState(r.id);
      expect(gw.outboundPort.wipes, 1);
      await expectLater(gw.sendMessage('x', threadId: r.id), error(GatewayError.groupBusy));
      expect(groups().single.sendLock, GroupSendLock.wechsel);
      gw.outboundPort.wipeIneffective = false;
      await gw.syncGroups();
      expect(gw.outboundPort.recipients(r.id), isNull);
      await expectLater(gw.sendMessage('x', threadId: r.id), error(GatewayError.groupNoOtherMembers));
    });
  });
}
