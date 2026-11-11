import 'package:family_nexus/data/sync/calendar_sync.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/peer.dart';

/// #358: Der Kalender gleicht zusätzlich zum Abgleich nach Änderungen regelmäßig (alle 15 Minuten) mit dem
/// Homeserver ab.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  late FakeMatrixServer server;
  late Peer anna;
  CalendarSync? sync;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    anna = await Peer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    anna.sync.dispose();
  });

  tearDown(() => sync?.dispose());

  CalendarSync make(Duration reconcile) => sync = CalendarSync(
        gateway: anna.gateway,
        service: anna.service,
        store: anna.store,
        retryInterval: const Duration(hours: 1),
        reconcileInterval: reconcile,
      );

  test('Standard: alle 15 Minuten', () {
    expect(CalendarSync.defaultReconcileInterval, const Duration(minutes: 15));
    expect(make(CalendarSync.defaultReconcileInterval).reconcileInterval, const Duration(minutes: 15));
  });

  test('reconcile gleicht mit dem Homeserver ab, wenn die Sitzung bereit ist', () async {
    final s = make(const Duration(hours: 1))..start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final base = anna.gateway.syncNowCalls;
    await s.reconcile();
    expect(anna.gateway.syncNowCalls, base + 1);
  });

  test('der Zeitgeber löst den Abgleich wiederholt aus, dispose beendet ihn', () async {
    final s = make(const Duration(milliseconds: 60))..start();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final n = anna.gateway.syncNowCalls;
    expect(n, greaterThanOrEqualTo(2));
    s.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(anna.gateway.syncNowCalls, n, reason: 'nach dispose kein weiterer Abgleich');
  });

  test('ohne bereite Sitzung kein Abgleich', () async {
    final s = make(const Duration(hours: 1));
    // nicht gestartet, Gateway nach Abmelden nicht bereit
    await anna.gateway.logout();
    final base = anna.gateway.syncNowCalls;
    await s.reconcile();
    expect(anna.gateway.syncNowCalls, base);
  });
}
