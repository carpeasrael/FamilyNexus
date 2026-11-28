import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #119, K4-3: Der Fake spiegelt die Regeln der Gruppen-Verwaltung des echten Gateways (dessen Tests: `group_admin_gateway_test.dart`),
/// damit die Controller-Tests auf ihm aufbauen können: Recht, Größe, `groupFull`, Selbstabstufung, `alreadyExists`, die Sperre des
/// Sendens nach dem Entfernen bis `completeRemoval`.
void main() {
  const carla = '@carla:fake.test';
  const dora = '@dora:fake.test';
  const emil = '@emil:fake.test'; // Familienmitglied

  late TestApp app;
  late FakeMatrixGateway gw;
  late String me;
  late FakeRoom room;

  Matcher error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

  void policy({Map<String, ContactState> contacts = const <String, ContactState>{}, Set<String> blocked = const <String>{}}) =>
      gw.setContactPolicy(ContactPolicy(enabled: true, contacts: contacts, blocked: blocked, groups: <String>{room.id}));

  setUp(() async {
    app = await buildTestApp();
    for (final n in <String>['carla', 'dora', 'emil']) {
      app.server.addAccount(n, 'pw-$n', displayName: n[0].toUpperCase() + n.substring(1));
    }
    app.gateway.familyRoom!.membership[emil] = MemberStatus.joined;
    gw = app.gateway;
    me = gw.userId!;
    room = app.server.createGroupRoom(me, 'Skat', joined: <String>[carla]);
    room.power[me] = PowerLevels.admin;
    policy(contacts: <String, ContactState>{carla: ContactState.accepted, dora: ContactState.accepted});
  });

  test('groupMembers: Stufen, Mitgliedschaft, Familie, ich; ohne Gruppe notAllowed', () async {
    room.dmMembers.add(emil);
    room.invitedUsers.add(dora);
    room.dmMembers.add(dora);
    final list = await gw.groupMembers(room.id);
    expect(list.first.isMe, isTrue);
    expect(list.firstWhere((m) => m.userId == emil).isFamily, isTrue);
    expect(list.firstWhere((m) => m.userId == dora).membership, GroupMembership.invite);
    await expectLater(gw.groupMembers('!nein:fake.test'), error(GatewayError.notAllowed));
  });

  test('inviteToGroup: bestätigter Kontakt ok; Nicht-Kontakt, blockiert, ich ⇒ notAllowed; schon dabei ⇒ alreadyExists; Familie ok', () async {
    await gw.inviteToGroup(room.id, dora);
    expect(room.dmMembers, contains(dora));
    expect(room.invitedUsers, contains(dora));
    await expectLater(gw.inviteToGroup(room.id, dora), error(GatewayError.alreadyExists));
    await expectLater(gw.inviteToGroup(room.id, me), error(GatewayError.notAllowed));
    await gw.inviteToGroup(room.id, emil);
    policy(contacts: <String, ContactState>{carla: ContactState.accepted}, blocked: <String>{'@x:fake.test'});
    await expectLater(gw.inviteToGroup(room.id, '@x:fake.test'), error(GatewayError.notAllowed));
  });

  test('inviteToGroup: Größe 50 ⇒ groupFull; Recht fehlt ⇒ notAllowed', () async {
    for (var i = 0; i < 48; i++) {
      room.dmMembers.add('@u$i:fake.test');
    }
    expect(room.dmMembers.length, 50);
    await expectLater(gw.inviteToGroup(room.id, dora), error(GatewayError.groupFull));
    room.dmMembers.remove('@u0:fake.test');
    room.power[me] = 0;
    await expectLater(gw.inviteToGroup(room.id, dora), error(GatewayError.notAllowed));
  });

  test('removeFromGroup sperrt das Senden (groupBusy) bis completeRemoval; Selbst, gleiche Stufe ⇒ notAllowed; unbekannt ⇒ notFound', () async {
    room.dmMembers.add(dora);
    await gw.openThread(room.id);
    await gw.sendMessage('Hallo', threadId: room.id);
    await gw.removeFromGroup(room.id, dora);
    expect(room.dmMembers, isNot(contains(dora)));
    await expectLater(gw.sendMessage('Hallo', threadId: room.id), error(GatewayError.groupBusy));
    await gw.completeRemoval(room.id);
    await gw.sendMessage('Wieder', threadId: room.id);
    await expectLater(gw.removeFromGroup(room.id, me), error(GatewayError.notAllowed));
    room.power[carla] = 100;
    await expectLater(gw.removeFromGroup(room.id, carla), error(GatewayError.notAllowed));
    await expectLater(gw.removeFromGroup(room.id, dora), error(GatewayError.notFound));
  });

  test('setGroupAdmin: ernennen (50), abstufen; Selbstabstufung nur mit einem zweiten Admin; Selbsternennung nie', () async {
    await gw.setGroupAdmin(room.id, carla, admin: true);
    expect(room.power[carla], 50);
    await expectLater(gw.setGroupAdmin(room.id, me, admin: true), error(GatewayError.notAllowed));
    await gw.setGroupAdmin(room.id, me, admin: false); // carla ist zweiter Admin
    expect(room.power.containsKey(me), isFalse);
    room.power[me] = 100;
    await gw.setGroupAdmin(room.id, carla, admin: false);
    await expectLater(gw.setGroupAdmin(room.id, me, admin: false), error(GatewayError.notAllowed), reason: 'der einzige Admin');
    expect(gw.setGroupAdminCalls, 5);
  });

  test('groupAdminError wirkt für jede Verwaltungsoperation', () async {
    gw.groupAdminError = GatewayError.serverUnreachable;
    await expectLater(gw.groupMembers(room.id), error(GatewayError.serverUnreachable));
    await expectLater(gw.inviteToGroup(room.id, dora), error(GatewayError.serverUnreachable));
    await expectLater(gw.removeFromGroup(room.id, carla), error(GatewayError.serverUnreachable));
    await expectLater(gw.setGroupAdmin(room.id, carla, admin: true), error(GatewayError.serverUnreachable));
  });
}
