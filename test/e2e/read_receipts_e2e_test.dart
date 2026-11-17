import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_support.dart';

/// #526, E-106: Lesebestätigung gegen echten Synapse. Läuft nur mit `FN_E2E=1` (`tool/e2e.sh`, Docker);
/// ohne Docker nicht ausgeführt und damit nicht belegt.
Future<SdkMatrixGateway> _login(String prefix, {bool Function()? share}) async {
  final a = await E2e.loggedIn(prefix, shareReadReceipts: share);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht Anfrage');
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

Future<(SdkMatrixGateway, SdkMatrixGateway)> _family(String name, {bool Function()? bShares}) async {
  final a = await _login('rra');
  await a.createFamily(name);
  await E2e.until(() => a.family != null);
  final b = await _login('rrb', share: bShares);
  await _join(a, b);
  return (a, b);
}

ChatMessage _byBody(SdkMatrixGateway g, String body) => g.messages.firstWhere((m) => m.body == body);

void main() {
  group('Lesebestätigung gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('#526: B liest mit öffentlichem Marker, A sieht readBy == {B}', () async {
      final (a, b) = await _family('Lese-Familie');
      await a.sendMessage('Hallo B');
      await E2e.until(() => b.messages.any((m) => m.body == 'Hallo B'), what: 'B entschlüsselt');
      await E2e.until(() => b.unreadIn(ChatThread.familyId) > 0, what: 'B hat Ungelesenes');
      expect(_byBody(a, 'Hallo B').readBy, isEmpty, reason: 'vor dem Lesen');

      await b.markChatRead();
      await E2e.until(() => _byBody(a, 'Hallo B').readBy.contains(b.userId), what: 'A sieht den öffentlichen Marker von B');
      expect(_byBody(a, 'Hallo B').readBy, <String>{b.userId!});
    });

    test('#526: B mit Schalter aus sendet nur privat, A sieht nichts', () async {
      final (a, b) = await _family('Privat-Familie', bShares: () => false);
      await a.sendMessage('Hallo B');
      await E2e.until(() => b.messages.any((m) => m.body == 'Hallo B'), what: 'B entschlüsselt');
      await E2e.until(() => b.unreadIn(ChatThread.familyId) > 0, what: 'B hat Ungelesenes');
      await b.markChatRead();
      await E2e.until(() => b.unreadIn(ChatThread.familyId) == 0, what: 'B hat gelesen (privat)');

      // Beleg über den Sync: Eine spätere Nachricht von B kommt bei A an, der Marker wäre vorher da gewesen.
      await b.sendMessage('Antwort');
      await E2e.until(() => a.messages.any((m) => m.body == 'Antwort'), what: 'A sieht die Antwort');
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(_byBody(a, 'Hallo B').readBy, isEmpty, reason: 'privater Marker ist für A nie sichtbar');
    });
  });
}
