import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/moderation.dart';
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

/// Zwei Mitglieder (Moderator [a], Mitglied [b]); wartet, bis a die Geräteschlüssel von b kennt.
Future<(SdkMatrixGateway, SdkMatrixGateway)> _family(String name) async {
  final a = await _login('moda');
  await a.createFamily(name);
  await E2e.until(() => a.family != null);
  final b = await _login('modb');
  await _join(a, b);
  return (a, b);
}

void main() {
  group('Melden gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('fremde Nachricht wird gemeldet, eigene und unbekannte werden abgelehnt', () async {
      final (a, b) = await _family('Melde-Familie');
      await b.sendMessage('Unerwünschte Nachricht');
      await E2e.until(() => a.messages.any((m) => m.body == 'Unerwünschte Nachricht'), what: 'A entschlüsselt');
      final foreign = a.messages.firstWhere((m) => m.body == 'Unerwünschte Nachricht');

      // Der Server nimmt die Meldung an (POST /rooms/{id}/report/{eventId}); es wird kein Fehler geworfen.
      await a.reportMessage(ReportRequest(messageId: foreign.id, category: ReportCategory.harassment, details: 'Test'));

      await a.sendMessage('Meine eigene');
      await E2e.until(() => a.messages.any((m) => m.body == 'Meine eigene'), what: 'eigene Nachricht im Verlauf');
      final own = a.messages.firstWhere((m) => m.body == 'Meine eigene');
      await expectLater(
        a.reportMessage(ReportRequest(messageId: own.id, category: ReportCategory.spam)),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      await expectLater(
        a.reportMessage(ReportRequest(messageId: r'$gibtsnicht', category: ReportCategory.spam)),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notFound)),
      );
    });
  });
}
