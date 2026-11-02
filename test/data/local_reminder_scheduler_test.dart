import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nachgebautes Plugin: zeichnet Anzeige und Entfernen auf (Linux/Windows halten Erinnerungen selbst).
class _Plugin implements FlutterLocalNotificationsPlugin {
  final List<int> shown = <int>[];
  final List<int> cancelled = <int>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<void> show({required int id, String? title, String? body, NotificationDetails? notificationDetails, String? payload}) async =>
      shown.add(id);

  @override
  Future<void> cancel({required int id, String? tag}) async => cancelled.add(id);

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// #218: Bestätigen entfernt unter Linux/Windows auch die noch nicht gezeigte In-App-Erinnerung.
void main() {
  test('dismiss entfernt die gehaltene Erinnerung und die angezeigte Benachrichtigung', () async {
    final plugin = _Plugin();
    final s = LocalReminderScheduler(plugin, true);
    await s.initialize(channelName: 'Erinnerungen', channelDescription: '');
    final fire = DateTime.now().toUtc().add(const Duration(hours: 1));
    PlannedReminder r(int id) => PlannedReminder(id: id, fireAt: fire, eventId: 'e$id', occurrenceStart: fire, minutesBefore: 0);
    await s.replaceAll(<PlannedReminder>[r(1), r(2)], title: 'Erinnerung', bodyFor: (_) => 'jetzt');
    await s.dismiss(1);
    expect(plugin.cancelled, <int>[1]);
    await s.fireDue(fire.add(const Duration(minutes: 1)));
    expect(plugin.shown, <int>[2], reason: 'die bestätigte erscheint nicht mehr');
    await s.cancelAll();
  });
}
