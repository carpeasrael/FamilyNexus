import 'dart:convert';

import 'package:family_nexus/core/platform_info.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_support.dart';

final String _run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
int _n = 0;
String _name(String prefix) => '$prefix.$_run.${_n++}';

Future<SdkMatrixGateway> _fresh() async {
  await E2e.init();
  final g = await E2e.newGateway();
  await g.restore();
  return g;
}

Matcher _gatewayError(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

/// Anzeigename laut Server (öffentliches Profil).
Future<String?> _profileName(String userId) async {
  final c = E2e.lenientClient();
  final res = await c.get(Uri.parse('${E2e.server.uri}/_matrix/client/v3/profile/${Uri.encodeComponent(userId)}/displayname'));
  c.close();
  if (res.statusCode != 200) return null;
  return (json.decode(res.body) as Map<String, Object?>)['displayname'] as String?;
}

/// Neues Konto über den Registrierungsweg der App, danach Notfall-Schlüssel.
Future<SdkMatrixGateway> _registered(String prefix, String displayName) async {
  final g = await _fresh();
  final stage = await g.register(server: E2e.server, username: _name(prefix), password: 'sicher-genug-$prefix', displayName: displayName);
  expect(stage, isNull, reason: 'Testserver verlangt keine Zusatzschritte');
  await E2e.until(() => g.initialSyncDone, what: 'Sync $prefix');
  await g.setUpSecurity();
  await E2e.until(() => g.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return g;
}

void main() {
  group('Kontoanlage und Einladung gegen echten Synapse (E-55, E-56)', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('TP-E2E-01 Registrierungsweg wird erkannt; Name frei → Konto in der App angelegt → Name vergeben', () async {
      final g = await _fresh();
      expect((await g.registrationOptions(E2e.server)).mode, RegistrationMode.inApp);
      final user = _name('reg');
      expect(await g.checkUsername(E2e.server, user), UsernameCheck.available);

      expect(await g.register(server: E2e.server, username: user, password: 'sicher-genug', displayName: 'Erika E2E'), isNull);
      expect(g.session, SessionState.ready);
      expect(g.userId, '@$user:localhost');
      await E2e.until(() => g.initialSyncDone, what: 'erster Sync');

      final other = await _fresh();
      expect(await other.checkUsername(E2e.server, user), UsernameCheck.taken);
      await expectLater(
        other.register(server: E2e.server, username: user, password: 'sicher-genug', displayName: 'Doppelt'),
        _gatewayError(GatewayError.usernameTaken),
      );
      expect(other.session, SessionState.loggedOut);

      // TP-REG-11 Anzeigename beim Anbieter, TP-DEV-01 Gerätename statt „FamilyNexus Android“.
      expect(await _profileName(g.userId!), 'Erika E2E');
      await g.refreshSecurity();
      expect(g.devices.singleWhere((d) => d.isCurrent).name, PlatformInfo.deviceName);
    });

    test('TP-E2E-02 lokale Prüfungen vor dem Senden: ungültiger Name, zu kurzes Passwort', () async {
      final g = await _fresh();
      await expectLater(
        g.register(server: E2e.server, username: 'Anna Müller', password: 'sicher-genug', displayName: 'A'),
        _gatewayError(GatewayError.usernameInvalid),
      );
      await expectLater(
        g.register(server: E2e.server, username: _name('kurz'), password: 'kurz', displayName: 'A'),
        _gatewayError(GatewayError.weakPassword),
      );
      expect(await g.checkUsername(E2e.server, 'Grossbuchstaben'), UsernameCheck.invalid);
    });

    test('TP-E2E-03 Neuling: Konto anlegen → Link v2 mit Namen → Anfrage → Moderatorin sieht den Namen → bestätigt → Mitglied', () async {
      final mod = await _registered('mod', 'Erika');
      await mod.createFamily('Familie E2E');
      await E2e.until(() => mod.family != null, what: 'Familie bei der Moderatorin');

      final raw = await mod.createInviteLink();
      expect(raw, contains('v=3'));
      final link = InviteLink.tryParse(raw, now: DateTime.now(), ownHost: 'localhost')!;
      expect(link.familyName, 'Familie E2E');
      expect(link.inviterName, 'Erika');
      expect(link.inviterServer, 'localhost', reason: 'Neulinge legen das Konto beim Anbieter des Einladenden an');
      expect(link.accountServer, 'localhost', reason: 'Der Link nennt den Server für Konto und Anmeldung ausdrücklich (E-63)');

      final guest = await _registered('gast', 'Gustav');
      await guest.requestToJoin(link);
      expect(guest.joinRequestPending, isTrue);
      await E2e.until(() => mod.family?.member(guest.userId!)?.status == MemberStatus.requested, what: 'Anfrage sichtbar');
      final req = mod.family!.member(guest.userId!)!;
      expect(req.request, RequestCheck.valid);
      await E2e.until(() => mod.family!.member(guest.userId!)!.displayName == 'Gustav', what: 'Name statt ID');

      await mod.approveRequest(guest.userId!);
      await E2e.until(() => guest.invitations.isNotEmpty, what: 'Einladung beim Gast');
      expect(guest.invitations.single.requested, isTrue);
      await guest.acceptInvitation(guest.invitations.single.roomId);
      await E2e.until(() => guest.family != null, what: 'Gast ist Mitglied');
      expect(guest.family!.myRole, Role.member);
      expect(guest.family!.name, 'Familie E2E');
    });

    test('Issue #6: Link einer Familie auf einem Heimnetz-Server (localhost) vor der Anmeldung lesen und beitreten', () async {
      final mod = await _registered('modl', 'Lena');
      await mod.createFamily('Familie Heimnetz');
      await E2e.until(() => mod.family != null, what: 'Familie');
      final raw = await mod.createInviteLink(validity: const Duration(days: 7));
      // Wie ein Neuling vor der Anmeldung: eigener Server noch unbekannt, Link aus einer HTML-Mail.
      final check = InviteLink.check('Dein Link: <${raw.replaceAll('&', '&amp;')}>', now: DateTime.now());
      expect(check.ok, isTrue, reason: '${check.problem}');
      final link = check.link!;
      expect(link.onLocalServer, isTrue, reason: 'Warnung auf der Beitrittskarte');
      expect(link.expires.difference(DateTime.now().toUtc()).inHours, inInclusiveRange(167, 168));
      expect(InviteLink.tryParse(raw, now: DateTime.now()), isNull, reason: 'strenge Prüfung ohne eigenen Server bleibt');
      final guest = await _registered('gastl', 'Jonas');
      await guest.requestToJoin(link);
      await E2e.until(() => mod.family?.member(guest.userId!)?.status == MemberStatus.requested, what: 'Anfrage');
      expect(mod.family!.member(guest.userId!)!.request, RequestCheck.valid);
    });

    test('TP-E2E-04 direkte Einladung zeigt den Namen der einladenden Person', () async {
      final mod = await _registered('modb', 'Henriette');
      await mod.createFamily('Familie Namen');
      await E2e.until(() => mod.family != null, what: 'Familie');
      final invitee = await _registered('einl', 'Ida');
      await mod.inviteUser(invitee.userId!);
      await E2e.until(() => invitee.invitations.isNotEmpty, what: 'Einladung');
      final inv = invitee.invitations.single;
      expect(inv.inviterId, mod.userId);
      expect(inv.inviterLabel, 'Henriette');
    });

    test('TP-E2E-05 Abbruch: Registrierung lässt sich verwerfen, danach erneut starten', () async {
      final g = await _fresh();
      g.cancelRegistration();
      await expectLater(g.continueRegistration(const AcceptTerms()), _gatewayError(GatewayError.notFound));
      expect(await g.register(server: E2e.server, username: _name('neu'), password: 'sicher-genug', displayName: 'Neu'), isNull);
    });
  });
}
