import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_log.dart';
import '../../domain/reminder_planner.dart';
import '../../domain/time_zones.dart';

enum ReminderPermission {
  granted,

  /// Benachrichtigungen sind blockiert: Erinnerungen erscheinen nicht.
  notificationsDenied,

  /// Genaue Alarme fehlen: Erinnerungen können sich verspäten.
  exactAlarmMissing,
}

/// Plant lokale Erinnerungen (E-15). Die Benachrichtigung enthält **nie**
/// Termininhalte: nur einen festen Titel und „in n Minuten“.
abstract class ReminderScheduler {
  Future<void> initialize({required String channelName, required String channelDescription});

  Future<ReminderPermission> permission();

  /// Fragt die Berechtigungen beim Nutzer an.
  Future<ReminderPermission> request();

  /// Ersetzt alle geplanten Erinnerungen durch [planned].
  Future<void> replaceAll(
    List<PlannedReminder> planned, {
    required String title,
    required String Function(int minutesBefore) bodyFor,
  });

  Future<void> cancelAll();
}

class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const String _channelId = 'reminders';
  String _channelName = 'Erinnerungen';
  String _channelDescription = '';
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  MacOSFlutterLocalNotificationsPlugin? get _mac =>
      _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();

  /// Apple-Plattformen (iOS, macOS) verhalten sich gleich: Berechtigung auf Wunsch, begrenzte Anzahl.
  bool get _isApple => _ios != null || _mac != null;

  /// iOS hält höchstens 64 geplante Benachrichtigungen; die nächsten 60 werden geplant, der Rest
  /// beim nächsten Öffnen der App (Neuplanung).
  static const int iosMaxPending = 60;

  @override
  Future<void> initialize({required String channelName, required String channelDescription}) async {
    TimeZones.ensureInitialized();
    _channelName = channelName;
    _channelDescription = channelDescription;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Berechtigungen werden erst auf ausdrücklichen Wunsch abgefragt (nicht beim Start).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<ReminderPermission> permission() async {
    final ios = _ios;
    final mac = _mac;
    if (ios != null || mac != null) {
      final o = ios != null ? await ios.checkPermissions() : await mac!.checkPermissions();
      return (o?.isEnabled ?? false) ? ReminderPermission.granted : ReminderPermission.notificationsDenied;
    }
    final android = _android;
    if (android == null) return ReminderPermission.granted;
    final notifications = await android.areNotificationsEnabled() ?? false;
    if (!notifications) return ReminderPermission.notificationsDenied;
    final exact = await android.canScheduleExactNotifications() ?? false;
    return exact ? ReminderPermission.granted : ReminderPermission.exactAlarmMissing;
  }

  @override
  Future<ReminderPermission> request() async {
    final ios = _ios;
    final mac = _mac;
    if (ios != null || mac != null) {
      if (ios != null) {
        await ios.requestPermissions(alert: true, badge: false, sound: true);
      } else {
        await mac!.requestPermissions(alert: true, badge: false, sound: true);
      }
      return permission();
    }
    final android = _android;
    if (android == null) return ReminderPermission.granted;
    await android.requestNotificationsPermission();
    if (!(await android.canScheduleExactNotifications() ?? false)) {
      await android.requestExactAlarmsPermission();
    }
    return permission();
  }

  @override
  Future<void> replaceAll(
    List<PlannedReminder> planned, {
    required String title,
    required String Function(int minutesBefore) bodyFor,
  }) async {
    if (!_ready) return;
    final android = _android;
    try {
      await _plugin.cancelAllPendingNotifications();
      final exact = (await android?.canScheduleExactNotifications()) ?? false;
      const darwin = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );
      final details = NotificationDetails(
        iOS: darwin,
        macOS: darwin,
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.private,
          autoCancel: true,
        ),
      );
      final list = !_isApple
          ? planned
          : (List<PlannedReminder>.of(planned)..sort((a, b) => a.fireAt.compareTo(b.fireAt))).take(iosMaxPending).toList();
      for (final r in list) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: title,
          body: bodyFor(r.minutesBefore),
          scheduledDate: tz.TZDateTime.from(r.fireAt, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      AppLog.e('reminders', 'Erinnerungen konnten nicht geplant werden', e);
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      AppLog.e('reminders', 'Erinnerungen konnten nicht entfernt werden', e);
    }
  }
}
