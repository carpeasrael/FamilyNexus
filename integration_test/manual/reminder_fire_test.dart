// Plant eine Erinnerung in wenigen Sekunden und prüft die tatsächlich
// zugestellte Benachrichtigung. Benötigt die Berechtigung POST_NOTIFICATIONS
// (vorher per `adb shell pm grant` erteilen), daher nicht Teil der Gates.
import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Erinnerung feuert mit generischem Text', (tester) async {
    final s = LocalReminderScheduler();
    await s.initialize(channelName: 'Erinnerungen', channelDescription: 'Test');
    final perm = await s.request();
    final now = DateTime.now().toUtc();
    await s.replaceAll(
      <PlannedReminder>[
        PlannedReminder(
          id: 424242,
          fireAt: now.add(const Duration(seconds: 12)),
          eventId: '11111111-1111-4111-8111-111111111111',
          occurrenceStart: now.add(const Duration(minutes: 10)),
          minutesBefore: 10,
        ),
      ],
      title: 'Erinnerung',
      bodyFor: (m) => 'Termin in $m Minuten',
    );
    // ignore: avoid_print
    print('PERMISSION=$perm');
    await Future<void>.delayed(const Duration(seconds: 25));
    final active = await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
        .getActiveNotifications();
    final mine = active.where((n) => n.id == 424242).toList();
    expect(mine, hasLength(1), reason: 'Erinnerung wurde nicht zugestellt');
    expect(mine.single.title, 'Erinnerung');
    expect(mine.single.body, 'Termin in 10 Minuten');
    expect(mine.single.payload ?? '', isEmpty);
    await s.cancelAll();
  });
}
