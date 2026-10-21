import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android-Adapter plant, ersetzt und entfernt lokale Erinnerungen', (tester) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final s = LocalReminderScheduler(plugin);
    await s.initialize(channelName: 'Erinnerungen', channelDescription: 'Test');
    await s.cancelAll();

    final now = DateTime.now().toUtc();
    final r1 = PlannedReminder(
      id: ReminderPlanner.stableId('11111111-1111-4111-8111-111111111111', now.add(const Duration(hours: 2)), 10),
      fireAt: now.add(const Duration(hours: 1)),
      eventId: '11111111-1111-4111-8111-111111111111',
      occurrenceStart: now.add(const Duration(hours: 2)),
      minutesBefore: 10,
    );
    final r2 = PlannedReminder(
      id: ReminderPlanner.stableId('22222222-2222-4222-8222-222222222222', now.add(const Duration(hours: 3)), 60),
      fireAt: now.add(const Duration(hours: 2)),
      eventId: '22222222-2222-4222-8222-222222222222',
      occurrenceStart: now.add(const Duration(hours: 3)),
      minutesBefore: 60,
    );

    await s.replaceAll(<PlannedReminder>[r1, r2], title: 'Erinnerung', bodyFor: (m) => 'Termin in $m Minuten');
    var pending = await plugin.pendingNotificationRequests();
    expect(pending.map((p) => p.id).toSet(), <int>{r1.id, r2.id});
    // Nichts Inhaltliches liegt in der Plattform-Ablage: nur generischer Text, keine Nutzlast.
    for (final p in pending) {
      expect(p.title, 'Erinnerung');
      expect(p.body, startsWith('Termin in '));
      expect(p.payload ?? '', isEmpty);
    }

    // Ersetzen: alte verschwinden, neue erscheinen.
    await s.replaceAll(<PlannedReminder>[r2], title: 'Erinnerung', bodyFor: (m) => 'Termin in $m Minuten');
    pending = await plugin.pendingNotificationRequests();
    expect(pending.map((p) => p.id), <int>[r2.id]);

    await s.replaceAll(const <PlannedReminder>[], title: 'Erinnerung', bodyFor: (m) => '');
    expect(await plugin.pendingNotificationRequests(), isEmpty);
  });
}
