import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_support.dart';

Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(autoApprove: false), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht Anfrage');
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

void main() {
  group('Einladungen gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Link eines Moderators: ein zweiter Moderator prüft und bestätigt die Anfrage', () async {
      final a = await _login('inva');
      await a.createFamily('Einladungs-Familie');
      await E2e.until(() => a.family != null, what: 'Familie bei A');
      final b = await _login('invb');
      await _join(a, b);
      await a.promote(b.userId!);
      await E2e.until(() => b.family?.myRole == Role.moderator, what: 'B ist Moderator');

      // A gibt den Link aus; die Anfrage trifft ein.
      final link = InviteLink.tryParse(await a.createInviteLink(autoApprove: false), now: DateTime.now(), ownHost: 'localhost')!;
      final c = await _login('invc');
      await c.requestToJoin(link);
      await E2e.until(() => b.family?.member(c.userId!)?.status == MemberStatus.requested, what: 'B sieht die Anfrage');

      // B kennt den Link nur über den verschlüsselten Vermerk im Familienraum.
      await E2e.until(() => b.family!.member(c.userId!)!.request == RequestCheck.valid, what: 'B erkennt den Link von A als gültig');
      await b.approveRequest(c.userId!);
      await E2e.until(() => c.invitations.isNotEmpty, what: 'C erhält die Einladung');
      await c.acceptInvitation(c.invitations.single.roomId);
      await E2e.until(() => c.family != null, what: 'C ist in der Familie');
      expect(c.family!.myRole, Role.member);

      // Der Link ist verbraucht: ein zweiter Anfrager mit demselben Link wird von beiden Moderatoren nicht bestätigt.
      final d = await _login('invd');
      await d.requestToJoin(link);
      await E2e.until(() => b.family?.member(d.userId!)?.status == MemberStatus.requested, what: 'B sieht die zweite Anfrage');
      await E2e.until(() => b.family!.member(d.userId!)!.request == RequestCheck.unknown, what: 'verbrauchter Link gilt nicht mehr');
      await E2e.until(() => a.family!.member(d.userId!)!.request == RequestCheck.unknown, what: 'A sieht den verbrauchten Link ebenso');
    });

    test('Link mit automatischer Bestätigung: die App des Moderators lädt ohne Klick ein, nur einmal', () async {
      final a = await _login('inaa');
      await a.createFamily('Auto-Familie');
      await E2e.until(() => a.family != null, what: 'Familie bei A');
      final link = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      final c = await _login('inac');
      await c.requestToJoin(link);
      await E2e.until(() => c.invitations.isNotEmpty, what: 'C erhält die Einladung ohne Zutun eines Moderators');
      await c.acceptInvitation(c.invitations.single.roomId);
      await E2e.until(() => c.family != null, what: 'C ist in der Familie');
      expect(c.family!.myRole, Role.member);

      // Einmalig: ein zweiter Anfrager mit demselben Link bleibt unbestätigt.
      final d = await _login('inad');
      await d.requestToJoin(link);
      await E2e.until(() => a.family?.member(d.userId!)?.status == MemberStatus.requested, what: 'A sieht die zweite Anfrage');
      await E2e.until(() => a.family!.member(d.userId!)!.request == RequestCheck.unknown, what: 'verbrauchter Link gilt nicht mehr');
      expect(d.invitations, isEmpty);
    });

    test('Familien-Code ohne Link: Moderator sieht die Anfrage als „Code“, nichts geschieht von allein, Bestätigung führt zum Beitritt', () async {
      final a = await _login('incda');
      await a.createFamily('Code-Familie');
      await E2e.until(() => a.family != null, what: 'Familie bei A');
      final c = await _login('incdc');
      await expectLater(c.requestToJoinByCode('kein code'), throwsA(isA<GatewayException>()));
      await c.requestToJoinByCode(a.family!.roomId);
      await E2e.until(() => a.family?.member(c.userId!)?.status == MemberStatus.requested, what: 'A sieht die Anfrage');
      await E2e.until(() => a.family!.member(c.userId!)!.request == RequestCheck.code, what: 'Anfrage per Code erkannt');
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(c.invitations, isEmpty, reason: 'keine automatische Bestätigung ohne Link');
      await a.approveRequest(c.userId!);
      await E2e.until(() => c.invitations.isNotEmpty, what: 'C erhält die Einladung');
      await c.acceptInvitation(c.invitations.single.roomId);
      await E2e.until(() => c.family != null, what: 'C ist in der Familie');
    });

    test('Per Matrix-ID eingeladenes Konto findet die Einladung nach der Anmeldung', () async {
      final a = await _login('invm');
      await a.createFamily('ID-Familie');
      await E2e.until(() => a.family != null, what: 'Familie bei A');
      final c = await _login('invn');
      expect(c.invitations, isEmpty);
      await a.inviteUser(c.userId!);
      await E2e.until(() => c.invitations.isNotEmpty, what: 'C sieht die Einladung');
      final inv = c.invitations.single;
      expect(inv.inviterId, a.userId);
      expect(inv.requested, isFalse);
      await c.acceptInvitation(inv.roomId);
      await E2e.until(() => c.family != null, what: 'C ist in der Familie');
    });
  });
}
