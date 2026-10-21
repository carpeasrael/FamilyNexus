import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/reminder_planner.dart';

/// Zeichnet auf, was geplant würde (inkl. der exakten Benachrichtigungstexte).
class FakeReminderScheduler implements ReminderScheduler {
  ReminderPermission current = ReminderPermission.granted;
  final List<List<PlannedReminder>> plans = <List<PlannedReminder>>[];
  final List<({String title, String body})> texts = <({String title, String body})>[];
  int cancelled = 0;
  int requested = 0;

  List<PlannedReminder> get last => plans.isEmpty ? const <PlannedReminder>[] : plans.last;

  @override
  Future<void> initialize({required String channelName, required String channelDescription}) async {}

  @override
  Future<ReminderPermission> permission() async => current;

  @override
  Future<ReminderPermission> request() async {
    requested++;
    current = ReminderPermission.granted;
    return current;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> planned, {required String title, required String Function(int) bodyFor}) async {
    plans.add(planned);
    texts
      ..clear()
      ..addAll(<({String title, String body})>[for (final r in planned) (title: title, body: bodyFor(r.minutesBefore))]);
  }

  @override
  Future<void> cancelAll() async => cancelled++;
}
