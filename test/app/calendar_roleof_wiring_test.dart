import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_event_store.dart';

/// #431, E-112: Die Fabrik reicht `roleOf` an den Kalenderdienst weiter (der Sync nutzt den Dienst). Ohne Angabe kennt
/// der Dienst niemanden (fail-closed).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  late FakeMatrixGateway gateway;

  setUp(() async {
    final server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
  });

  test('roleOf wird durchgereicht; Standard: niemand', () async {
    final withRole = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
      roleOf: (id) => id == '@cara:fake.test' ? Role.moderator : null,
    );
    expect(withRole.service.roleOf('@cara:fake.test'), Role.moderator);
    expect(withRole.service.roleOf('@x:fake.test'), isNull);
    final plain = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
    );
    expect(plain.service.roleOf('@cara:fake.test'), isNull);
    withRole.dispose();
    plain.dispose();
  });

  test('Permissions.roleOf: Moderator, Mitglied, unbekannt (Familie fehlt, Mitglied fehlt, nicht beigetreten)', () async {
    await gateway.createFamily('Familie');
    final f = gateway.family!;
    expect(Permissions.roleOf(f, gateway.userId!), Role.moderator);
    expect(Permissions.roleOf(f, '@niemand:fake.test'), isNull);
    expect(Permissions.roleOf(null, gateway.userId!), isNull);
    final left = Family(
      roomId: f.roomId,
      name: f.name,
      myUserId: f.myUserId,
      members: <FamilyMember>[for (final m in f.members) m.copyWith(status: MemberStatus.invited)],
    );
    expect(Permissions.roleOf(left, gateway.userId!), isNull, reason: 'nicht beigetreten');
  });
}
