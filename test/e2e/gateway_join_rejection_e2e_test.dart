// Ablehnung beim Anfragenden gegen echten Synapse (#116, #75, E-81). Der Start-Poll selbst wird isoliert
// in test/data/join_rejection_test.dart nachgewiesen, weil der Nachhol-Sync ihn hier verdecken würde.
import 'dart:convert';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_support.dart';

Future<SdkMatrixGateway> _moderator(String prefix, String familyName) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  await a.gateway.createFamily(familyName);
  await E2e.until(() => a.gateway.family != null, what: 'Familie $prefix');
  return a.gateway;
}

Future<SdkMatrixGateway> _requester(String prefix, {required Duration interval}) async {
  final c = await E2e.loggedIn(prefix, joinPollInterval: interval);
  await E2e.until(() => c.gateway.initialSyncDone, what: 'Sync $prefix');
  return c.gateway;
}

Future<void> _request(SdkMatrixGateway mod, SdkMatrixGateway c) async {
  await c.requestToJoinByCode(mod.family!.roomId);
  await E2e.until(() => mod.family?.member(c.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht die Anfrage');
}

/// Einige Abfragen mit kurzem Intervall abwarten: Es darf kein Alarm entstehen.
Future<void> _staysPending(SdkMatrixGateway c) async {
  await E2e.until(() => c.joinRequestDiagnostic.contains('Zustand: knock'), what: 'Abfrage sieht die offene Anfrage');
  await Future<void>.delayed(const Duration(seconds: 2));
  expect(c.joinRequestRejected, isFalse);
  expect(c.joinRequestPending, isTrue);
  expect(c.joinRequestDiagnostic, contains('Zustand: knock'));
}

void main() {
  group('Ablehnung beim Anfragenden gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    const long = Duration(hours: 1);
    const short = Duration(milliseconds: 300);

    test('langes Intervall: Die Ablehnung kommt über den Sync-Auslöser an', () async {
      final a = await _moderator('rsa', 'Sync-Ablehnung');
      final c = await _requester('rsc', interval: long);
      await _request(a, c);
      await a.rejectRequest(c.userId!);
      await E2e.until(() => c.joinRequestRejected, what: 'Ablehnung bei C');
      expect(c.joinRequestDiagnostic, contains('Zustand: leaveRejected'));
      expect(c.joinRequestDiagnostic, contains('Auslöser: sync'));
      expect(c.joinRequestDiagnostic, contains('Abfragen: 1'));
    });

    test('Ablehnung bei geschlossener App kommt beim nächsten Start an', () async {
      final a = await _moderator('rca', 'Zu-Ablehnung');
      final device = await E2e.newDevice();
      final acc = await E2e.loggedIn('rcc', device: device, joinPollInterval: long);
      final c = acc.gateway;
      final me = c.userId!;
      await E2e.until(() => c.initialSyncDone, what: 'Sync C');
      await _request(a, c);
      await E2e.until(() => c.sdkClient!.accountData[SdkMatrixGateway.joinRequestAccountData] != null, what: 'Vermerk bei C');
      await c.close();

      await a.rejectRequest(me);
      await E2e.until(() => a.family?.member(me) == null, what: 'Anfrage entfernt');

      final again = await E2e.newGateway(device: device, joinPollInterval: long);
      await again.restore();
      await E2e.until(() => again.joinRequestRejected, what: 'Ablehnung nach dem Start');
      expect(again.joinRequestPending, isFalse);
      expect(again.joinRequestDiagnostic, contains('Zustand: leaveRejected'));
      expect(again.joinRequestDiagnostic, matches(RegExp('Auslöser: (start|sync)')));
    });

    test('offene Anfrage liefert knock', () async {
      final a = await _moderator('rka', 'Offen');
      final c = await _requester('rkc', interval: short);
      await _request(a, c);
      await _staysPending(c);
    });

    test('Anfrage, Ablehnung, Rückzug, neue Anfrage im selben Raum: kein Fehlalarm', () async {
      final a = await _moderator('rga', 'Gleicher Raum');
      final c = await _requester('rgc', interval: short);
      await _request(a, c);
      await a.rejectRequest(c.userId!);
      await E2e.until(() => c.joinRequestRejected, what: 'Ablehnung bei C');
      await E2e.until(() => a.family?.member(c.userId!) == null, what: 'Anfrage entfernt');
      await c.cancelJoinRequest();
      await _request(a, c);
      await _staysPending(c);
    });

    test('Anfrage, Ablehnung, Rückzug, neue Anfrage in anderem Raum: kein Fehlalarm', () async {
      final a = await _moderator('raa', 'Raum Eins');
      final b = await _moderator('rab', 'Raum Zwei');
      final c = await _requester('rac', interval: short);
      await _request(a, c);
      await a.rejectRequest(c.userId!);
      await E2e.until(() => c.joinRequestRejected, what: 'Ablehnung bei C');
      await c.cancelJoinRequest();
      await _request(b, c);
      await _staysPending(c);
    });

    test('Serverbeleg: Abrufform aus dem Nachtest liefert Absender und Vorzustand (Synapse 1.163.2)', () async {
      final a = await _moderator('rba', 'Beleg');
      final c = await _requester('rbc', interval: long);
      await _request(a, c);
      await a.rejectRequest(c.userId!);
      await E2e.until(() => c.joinRequestRejected, what: 'Ablehnung bei C');

      final http = E2e.lenientClient();
      addTearDown(http.close);
      final room = Uri.encodeComponent(a.family!.roomId);
      final user = Uri.encodeComponent(c.userId!);
      final headers = <String, String>{'authorization': 'Bearer ${a.sdkClient!.accessToken}'};
      final res = await http.get(
        Uri.parse('${E2e.server.uri}/_matrix/client/v3/rooms/$room/state/m.room.member/$user?format=event'),
        headers: headers,
      );
      expect(res.statusCode, 200);
      final event = json.decode(res.body) as Map<String, Object?>;
      expect((event['content'] as Map)['membership'], 'leave');
      expect(event['sender'], a.userId);
      expect(event['origin_server_ts'], isA<int>());
      expect(((event['unsigned'] as Map)['prev_content'] as Map)['membership'], 'knock');
    });
  });
}
