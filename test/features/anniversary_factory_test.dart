import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_anniversary_store.dart';
import '../support/memory_event_store.dart';

/// E-104: Eine Quelle für „heute“: Der Dienst der Geburts- und Gedenktage nutzt `controller.today` (dieselbe
/// Zonenauflösung mit Rückfall auf UTC und dieselbe Uhr).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  final clockTime = DateTime.utc(2026, 3, 15, 23, 30);

  Future<void> check(String zone, DateTime expected) async {
    final server = FakeMatrixServer()..addAccount('anna', 'pw1', displayName: 'Anna');
    final gateway = server.newDevice();
    final c = buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: '@anna:fake.test',
      zoneName: zone,
      clock: () => clockTime,
      anniversaryStore: MemoryAnniversaryStore(),
    );
    addTearDown(c.dispose);
    expect(c.today, expected);
    expect(c.anniversaries!.today(), expected, reason: 'Dienst und Controller rechnen mit demselben Tag');
  }

  test('ungültiger Zonenname: beide rechnen mit UTC', () => check('Nirgendwo/Zone', DateTime.utc(2026, 3, 15)));
  test('Pacific/Auckland: beide rechnen mit dem 16.03.', () => check('Pacific/Auckland', DateTime.utc(2026, 3, 16)));
  test('America/Los_Angeles: beide rechnen mit dem 15.03.', () => check('America/Los_Angeles', DateTime.utc(2026, 3, 15)));

  test('ohne anniversaryStore gibt es keinen Dienst und keine Synchronisation', () {
    final server = FakeMatrixServer()..addAccount('anna', 'pw1', displayName: 'Anna');
    final c = buildCalendarController(store: MemoryEventStore(), gateway: server.newDevice(), userId: '@anna:fake.test', zoneName: 'UTC');
    addTearDown(c.dispose);
    expect(c.anniversaries, isNull);
    expect(c.anniversarySync, isNull);
  });
}
