import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Role;

import 'e2e_support.dart';

/// Wie in der App: Anmeldung, dann Pflicht-Schlüsselsicherung (nur verifizierte Geräte erhalten Schlüssel).
Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

/// Alle Teilnehmer treten über Anfrage → Bestätigung → Annahme bei.
Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => user.joinRequestPending, what: 'Anfrage wartet');
  await E2e.until(
    () => mod.family?.member(user.userId!)?.status == MemberStatus.requested,
    what: 'Moderator sieht Anfrage',
  );
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

void main() {
  group('Familie, Einladung, Rollen gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Beitritt per Link: Anfrage → Bestätigung → Annahme; Chat wird entschlüsselt', () async {
      final a = await _login('mod');
      await a.createFamily('Familie Einladung');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');

      await _join(a, b);
      expect(b.family!.myRole, Role.member);
      expect(b.family!.name, 'Familie Einladung');
      expect(b.joinRequestPending, isFalse);

      await a.sendMessage('Willkommen!');
      await E2e.until(() => b.messages.any((m) => m.body == 'Willkommen!'), what: 'B entschlüsselt Annes Nachricht');
      await b.sendMessage('Danke!');
      await E2e.until(() => a.messages.any((m) => m.body == 'Danke!'), what: 'A entschlüsselt Bens Nachricht');
    });

    test('Einladungslink: gefälschte ID nicht bestätigbar, Link nur einmal verwendbar, Identität vermerkt', () async {
      final a = await _login('mod');
      await a.createFamily('Nonce');
      await E2e.until(() => a.family != null);
      final forger = await _login('fake');
      final real = await _login('real');

      // Link mit selbst gewählter ID (nicht vom Moderator ausgegeben).
      final good = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      final forged = InviteLink(roomId: good.roomId, via: good.via, inviter: good.inviter, expires: good.expires, nonce: 'a' * 32);
      await forger.requestToJoin(forged);
      await E2e.until(() => a.family?.member(forger.userId!)?.status == MemberStatus.requested, what: 'Anfrage des Fälschers');
      expect(a.family!.member(forger.userId!)!.request, RequestCheck.unknown);
      await expectLater(a.approveRequest(forger.userId!), _error(GatewayError.notAllowed));
      await a.rejectRequest(forger.userId!);

      // Echter Link: bestätigbar, danach verbraucht.
      await real.requestToJoin(good);
      await E2e.until(() => a.family?.member(real.userId!)?.request == RequestCheck.valid, what: 'gültige Anfrage');
      await a.approveRequest(real.userId!);
      await forger.cancelJoinRequest();
      await forger.requestToJoin(good);
      await E2e.until(() => a.family?.member(forger.userId!)?.status == MemberStatus.requested, what: 'zweite Anfrage');
      await E2e.until(() => a.family?.member(forger.userId!)?.request == RequestCheck.unknown, what: 'Link verbraucht');
      await expectLater(a.approveRequest(forger.userId!), _error(GatewayError.notAllowed));
    });

    test('Mitglied hat keine Verwaltungsrechte – im Gateway UND auf dem Server', () async {
      final a = await _login('mod');
      await a.createFamily('Rechte');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      await _join(a, b);
      final c = await _login('dritter');

      await expectLater(b.createInviteLink(), throwsA(isA<GatewayException>()));
      await expectLater(b.inviteUser(c.userId!), _error(GatewayError.notAllowed));
      await expectLater(b.renameFamily('Gekapert'), _error(GatewayError.notAllowed));
      await expectLater(b.removeMember(a.userId!), _error(GatewayError.notAllowed));
      await expectLater(b.promote(b.userId!), _error(GatewayError.notAllowed));

      // Selbst bei umgangener Oberfläche lehnt der Server ab (Power-Level 0 < 50).
      final raw = b.sdkClient!;
      await expectLater(
        raw.inviteUser(b.family!.roomId, c.userId!),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      await expectLater(
        raw.setRoomStateWithKey(b.family!.roomId, 'm.room.name', '', <String, Object?>{'name': 'Gekapert'}),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      await expectLater(
        raw.setRoomStateWithKey(b.family!.roomId, 'm.room.encryption', '', <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      expect(a.family!.name, 'Rechte');
    });

    test('Ernennen, Umbenennen, Moderatoren sind gleichrangig', () async {
      final a = await _login('mod');
      await a.createFamily('Rollen');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      await _join(a, b);

      await a.promote(b.userId!);
      await E2e.until(() => b.family?.myRole == Role.moderator, what: 'B ist Moderator');
      await E2e.until(() => a.family?.moderatorCount == 2);
      expect(a.family!.needsSecondModerator, isFalse);

      await b.renameFamily('Neuer Name');
      await E2e.until(() => a.family?.name == 'Neuer Name', what: 'Umbenennung sichtbar');

      // Moderatoren können einander weder entfernen noch herabstufen (E-10).
      await expectLater(a.removeMember(b.userId!), _error(GatewayError.notAllowed));
      await expectLater(b.removeMember(a.userId!), _error(GatewayError.notAllowed));
    });

    test('Ablehnen einer Anfrage und abgelaufene/ungültige Links', () async {
      final a = await _login('mod');
      await a.createFamily('Ablehnen');
      await E2e.until(() => a.family != null);
      final d = await _login('fremd');

      final link = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      await d.requestToJoin(link);
      await E2e.until(() => a.family?.member(d.userId!)?.status == MemberStatus.requested);
      await a.rejectRequest(d.userId!);
      await E2e.until(() => a.family?.member(d.userId!) == null, what: 'Anfrage entfernt');
      // Der Client sieht eine Ablehnung nicht (das SDK liefert den knock-Abschnitt nicht);
      // die Anfrage läuft ab oder wird zurückgezogen.
      expect(d.joinRequestPending, isTrue);
      await d.cancelJoinRequest();
      expect(d.joinRequestPending, isFalse);
      expect(d.family, isNull);

      // abgelaufen
      final old = InviteLink.tryParse(
        InviteLink.create(roomId: a.family!.roomId, via: 'localhost', inviter: a.userId!, now: DateTime.now().subtract(const Duration(days: 3)), validity: const Duration(hours: 1), nonce: '0123456789abcdef0123456789abcdef', ownHost: 'localhost'),
        now: DateTime.now().subtract(const Duration(days: 3)),
        ownHost: 'localhost',
      )!;
      await expectLater(d.requestToJoin(old), _error(GatewayError.invalidInput));
      // unbekannter Raum
      final bogus = InviteLink(roomId: '!gibtsnicht:localhost', via: 'localhost', inviter: a.userId!, expires: DateTime.now().add(const Duration(hours: 1)), nonce: '0123456789abcdef0123456789abcdef');
      await expectLater(d.requestToJoin(bogus), throwsA(isA<GatewayException>()));
    });

    test('Entfernen rotiert den Raumschlüssel; Entfernte lesen neue Nachrichten nicht', () async {
      final a = await _login('mod');
      await a.createFamily('Rotation');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      final c = await _login('ausscheiden');
      await _join(a, b);
      await _join(a, c);

      await a.sendMessage('vor dem Entfernen');
      await E2e.until(() => c.messages.any((m) => m.body == 'vor dem Entfernen'), what: 'C liest vorher');

      await a.removeMember(c.userId!);
      await E2e.until(() => a.family?.member(c.userId!) == null, what: 'C entfernt');
      await E2e.until(() => c.family == null, what: 'C hat keine Familie mehr');

      await a.sendMessage('nach dem Entfernen');
      await E2e.until(() => b.messages.any((m) => m.body == 'nach dem Entfernen'), what: 'B liest nachher');
      expect(c.messages.any((m) => m.body == 'nach dem Entfernen'), isFalse);

      final client = a.sdkClient!;
      final raw = await client.getRoomEvents(a.family!.roomId, Direction.b, limit: 50);
      final sessions = <String>[
        for (final e in raw.chunk.reversed)
          if (e.type == 'm.room.encrypted') (e.content['session_id'] as String?) ?? '',
      ];
      expect(sessions.length, greaterThanOrEqualTo(2));
      expect(sessions.first, isNot(sessions.last), reason: 'neue Megolm-Sitzung nach dem Entfernen');
    });

    test('Einladung per Matrix-ID und Ablehnen einer Einladung', () async {
      final a = await _login('mod');
      await a.createFamily('Direkt');
      await E2e.until(() => a.family != null);
      final e1 = await _login('direkt');
      await a.inviteUser(e1.userId!);
      await E2e.until(() => e1.invitations.isNotEmpty);
      expect(e1.invitations.single.roomName, 'Direkt');
      expect(e1.invitations.single.inviterId, a.userId);
      await e1.declineInvitation(e1.invitations.single.roomId);
      await E2e.until(() => e1.invitations.isEmpty, what: 'Einladung abgelehnt');
      expect(e1.family, isNull);
    });
  });
}
