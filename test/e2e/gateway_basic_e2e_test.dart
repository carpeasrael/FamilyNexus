import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Role;

import 'e2e_support.dart';

void main() {
  group('Gateway gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Anmeldung, Familie anlegen, verschlüsselt chatten', () async {
      final a = await E2e.loggedIn('anna');
      final g = a.gateway;
      expect(g.session, SessionState.ready);
      await E2e.until(() => g.initialSyncDone, what: 'erster Sync');
      await g.createFamily('Familie E2E');
      await E2e.until(() => g.family != null, what: 'Familie sichtbar');
      expect(g.family!.myRole, Role.moderator);
      expect(g.family!.name, 'Familie E2E');

      await g.sendMessage('Hallo verschlüsselt');
      await E2e.until(() => g.messages.any((m) => m.body == 'Hallo verschlüsselt'), what: 'eigene Nachricht');

      // Der Server sieht nur Chiffretext.
      final client = g.sdkClient!;
      final roomId = g.family!.roomId;
      final room = client.getRoomById(roomId)!;
      expect(room.encrypted, isTrue);
      final raw = await client.getRoomEvents(roomId, Direction.b, limit: 20);
      final msgs = raw.chunk.where((e) => e.type == 'm.room.encrypted' || e.type == 'm.room.message').toList();
      expect(msgs, isNotEmpty);
      expect(msgs.every((e) => e.type == 'm.room.encrypted'), isTrue, reason: 'keine Klartextnachricht auf dem Server');
      expect(msgs.map((e) => e.content.toString()).join(), isNot(contains('Hallo verschlüsselt')));

      // Power-Levels laut E-12 und E-61 (Ersteller = Administrator)
      final pl = room.getState('m.room.power_levels')!.content;
      expect((pl['users']! as Map)[client.userID], 100);
      expect(pl['users_default'], 0);
      expect(room.getState('m.room.join_rules')!.content['join_rule'], 'knock');
      expect(room.getState('m.room.create')!.content['room_version'], '10');

      await g.logout();
      expect(g.session, SessionState.loggedOut);
    });

    test('falsche Zugangsdaten werden als invalidCredentials gemeldet', () async {
      await E2e.init();
      final acc = await E2e.registerUser('bob');
      final g = await E2e.newGateway();
      await g.restore();
      await expectLater(
        g.login(server: E2e.server, username: acc.user, password: 'falsch'),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.invalidCredentials)),
      );
    });

    test('createFamily überschreibt keine bestehende Familie', () async {
      final a = await E2e.loggedIn('cara');
      await E2e.until(() => a.gateway.initialSyncDone);
      await a.gateway.createFamily('Eins');
      await E2e.until(() => a.gateway.family != null);
      await expectLater(
        a.gateway.createFamily('Zwei'),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.alreadyExists)),
      );
    });
  });
}
