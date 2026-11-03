import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../sync/activity_notifier.dart';
import 'reminder_scheduler.dart';

/// Feste Texte der Meldungen (#254): nie Absender, Gespräch oder Inhalt.
typedef ActivityTexts = ({
  String title,
  String chatBody,
  String shoppingBody,
  String channelName,
  String channelDescription,
});

/// Zeigt die Meldungen zu Chat und Einkauf über dasselbe Plugin wie die Erinnerungen (E-15). Initialisiert wird es
/// dort genau einmal beim Start; vorher zeigt dieser Adapter nichts. Eigener Android-Kanal `activity`, damit er sich
/// im System getrennt von den Erinnerungen abschalten lässt; Sperrbildschirm „private“, keine Nutzlast.
class LocalActivityNotifications implements ActivityPlatform {
  LocalActivityNotifications(this._scheduler, this._texts);

  final LocalReminderScheduler _scheduler;
  final ActivityTexts Function() _texts;

  static const String channelId = 'activity';

  @override
  Future<void> show(ActivityKind kind, {required bool alert, int count = 0}) async {
    if (!_scheduler.ready) return;
    final t = _texts();
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: alert,
      presentList: true,
      presentBadge: false,
      presentSound: alert,
    );
    await _scheduler.plugin.show(
      id: kind.id,
      title: t.title,
      body: kind == ActivityKind.chat ? t.chatBody : t.shoppingBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          t.channelName,
          channelDescription: t.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          channelShowBadge: true,
          number: count > 0 ? count : null,
          onlyAlertOnce: !alert,
          autoCancel: true,
        ),
        iOS: darwin,
        macOS: darwin,
        linux: const LinuxNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> cancel(ActivityKind kind) async {
    if (!_scheduler.ready) return;
    await _scheduler.plugin.cancel(id: kind.id);
  }
}
