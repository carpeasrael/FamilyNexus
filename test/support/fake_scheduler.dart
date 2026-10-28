import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/reminder_planner.dart';

/// Zeichnet auf, was geplant würde (inkl. der exakten Benachrichtigungstexte).
class FakeReminderScheduler implements ReminderScheduler {
  ReminderPermission current = ReminderPermission.granted;
  final List<List<PlannedReminder>> plans = <List<PlannedReminder>>[];
  final List<({String title, String body})> texts = <({String title, String body})>[];
  int cancelled = 0;
  int requested = 0;

  /// `false`: „Erlauben“ bringt keine Berechtigung (System zeigt keinen Dialog, #57).
  bool grantOnRequest = true;
  bool settingsAvailable = true;
  int settingsOpened = 0;

  List<PlannedReminder> get last => plans.isEmpty ? const <PlannedReminder>[] : plans.last;

  @override
  Future<void> initialize({required String channelName, required String channelDescription}) async {}

  @override
  Future<ReminderPermission> permission() async => current;

  @override
  Future<ReminderPermission> request() async {
    requested++;
    if (grantOnRequest) current = ReminderPermission.granted;
    return current;
  }

  @override
  bool get canOpenSettings => settingsAvailable;

  @override
  Future<bool> openSettings() async {
    if (!settingsAvailable) return false;
    settingsOpened++;
    return true;
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
