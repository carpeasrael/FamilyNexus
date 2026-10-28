import 'package:flutter/widgets.dart';

import '../../data/platform/reminder_scheduler.dart';
import '../../l10n/gen/app_localizations.dart';
import 'reminder_coordinator.dart';

/// Hinweis und Schaltfläche bei fehlender Berechtigung für Erinnerungen („Heute“ und Einstellungen).
/// Hat „Erlauben“ nichts bewirkt, führt die Schaltfläche in die Systemeinstellungen (#57).
({String text, String action, VoidCallback onPressed}) reminderPermissionHint(
  AppLocalizations l,
  ReminderCoordinator? c,
  ReminderPermission perm,
) {
  if (c != null && c.needsSystemSettings) {
    return (text: l.remindersPermissionSystem, action: l.remindersOpenSettings, onPressed: () => c.openSystemSettings().ignore());
  }
  return (
    text: perm == ReminderPermission.notificationsDenied ? l.remindersPermissionNotifications : l.remindersPermissionExact,
    action: l.remindersAllow,
    onPressed: () => c?.requestPermission().ignore(),
  );
}
