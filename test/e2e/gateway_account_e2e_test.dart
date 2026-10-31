import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/account_deletion.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_support.dart';

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

Future<({SdkMatrixGateway g, String user, String password})> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return (g: a.gateway, user: a.user, password: a.password);
}

void main() {
  group('Kontolöschung (#12) gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Passwort-Konto: falsches Passwort scheitert, danach gelöscht, Familie verlassen, Anmeldung unmöglich', () async {
      final mod = await _login('delmod');
      await mod.g.createFamily('Familie Löschung');
      await E2e.until(() => mod.g.family != null);
      final b = await _login('delmem');
      final bid = b.g.userId!;

      final link = InviteLink.tryParse(await mod.g.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      await b.g.requestToJoin(link);
      await E2e.until(() => mod.g.family?.member(bid)?.status == MemberStatus.requested, what: 'Anfrage');
      await mod.g.approveRequest(bid);
      await E2e.until(() => b.g.invitations.isNotEmpty, what: 'Einladung');
      await b.g.acceptInvitation(b.g.invitations.single.roomId);
      await E2e.until(() => mod.g.family?.member(bid)?.status == MemberStatus.joined, what: 'beigetreten');

      // Zweites Gerät desselben Kontos: sieht die Löschung bei der nächsten Prüfung.
      final second = await E2e.loginAs(b.user, b.password);
      expect(await second.checkAccountDeleted(), isFalse);

      expect(await b.g.accountDeletion(), isA<AccountDeletionInApp>());
      await expectLater(b.g.deleteAccount(password: 'falsch-falsch'), _error(GatewayError.invalidCredentials));
      expect(b.g.session, SessionState.ready, reason: 'nichts gelöscht');

      await b.g.deleteAccount(password: b.password);
      expect(b.g.session, SessionState.loggedOut);
      await E2e.until(() => mod.g.family?.member(bid)?.status != MemberStatus.joined, what: 'Konto hat die Familie verlassen');

      expect(await second.checkAccountDeleted(), isTrue);
      expect(second.session, SessionState.loggedOut);
      await expectLater(E2e.loginAs(b.user, b.password), throwsA(isA<GatewayException>()));
    });
  });
}
