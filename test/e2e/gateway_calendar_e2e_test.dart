
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Role;

import '../support/events.dart';
import 'e2e_support.dart';

CalendarEvent _event(String owner, String id, String title, EventVisibility v) => ev(owner: owner, id: id, title: title, visibility: v);

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Kalender über den echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('geteilte und private Termine: verschlüsselt, getrennte Räume, Signale auch für späte Zuhörer', () async {
      final a = await E2e.loggedIn('kal');
      final g = a.gateway;
      await E2e.until(() => g.initialSyncDone);
      await g.createFamily('Kalender-Familie');
      await E2e.until(() => g.family != null);
      final me = g.userId!;

      final shared = _event(me, kId1, 'GETEILT-TITEL', EventVisibility.shared);
      final priv = _event(me, kId2, 'PRIVAT-TITEL', EventVisibility.private);
      await g.publishSharedEvent(shared);
      await g.publishPrivateEvent(priv);

      // Späte Zuhörer erhalten den Bestand (Wiedergabe) und anschließend Live-Signale.
      final got = <CalendarSignal>[];
      final sub = g.calendarSignals.listen(got.add);
      await E2e.until(
        () => got.whereType<SharedEventSignal>().isNotEmpty && got.whereType<PrivateEventSignal>().isNotEmpty,
        what: 'Signale (Echo/Wiedergabe)',
      );
      expect(EventCodec.decode((got.whereType<SharedEventSignal>().first).content, sender: me, visibility: EventVisibility.shared).event!.title, 'GETEILT-TITEL');
      expect(EventCodec.decode((got.whereType<PrivateEventSignal>().first).content, sender: me, visibility: EventVisibility.private).event!.title, 'PRIVAT-TITEL');

      // Server: nichts im Klartext; privater Raum enthält nur dieses Konto.
      final client = g.sdkClient!;
      final familyId = g.family!.roomId;
      final privateId = client.accountData['de.inneso.familynexus.private_room']!.content['room_id']! as String;
      expect(privateId, isNot(familyId));
      for (final id in <String>[familyId, privateId]) {
        final raw = await client.getRoomEvents(id, Direction.b, limit: 50);
        final dump = raw.chunk.where((e) => e.type == 'm.room.encrypted' || e.type.startsWith('de.inneso')).toList();
        expect(dump, isNotEmpty, reason: id);
        expect(dump.every((e) => e.type == 'm.room.encrypted'), isTrue, reason: 'Kalenderereignisse nur als Chiffretext: $id');
        expect(dump.map((e) => e.content.toString()).join(), isNot(anyOf(contains('GETEILT-TITEL'), contains('PRIVAT-TITEL'))));
      }
      final members = await client.getJoinedMembersByRoom(privateId);
      expect(members!.keys, <String>[me], reason: 'privater Raum: nur das eigene Konto');
      final privEnc = client.getRoomById(privateId)!.getState('m.room.encryption');
      expect(privEnc, isNotNull);

      // Geteilte Termine dürfen nicht in den privaten Raum, private nicht in den Familienraum.
      await expectLater(g.publishSharedEvent(priv), throwsA(isA<GatewayException>().having((e) => e.error, 'e', GatewayError.invalidInput)));
      await expectLater(g.publishPrivateEvent(shared), throwsA(isA<GatewayException>().having((e) => e.error, 'e', GatewayError.invalidInput)));

      await sub.cancel();
    });
  });
}
