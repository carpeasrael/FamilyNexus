part of '../settings_screen.dart';

class _RemindersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final settings = services.settings;
    final coordinator = services.reminders;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[settings, ?coordinator]),
      builder: (context, _) {
        final selected = settings.settings.defaultReminderMinutes.toSet();
        final perm = coordinator?.permission ?? ReminderPermission.granted;
        return _Section(title: l.settingsReminders, children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.remindersHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.remindersDefault, style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
              for (final m in kReminderChoices)
                FilterChip(
                  label: Text(m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m))),
                  selected: selected.contains(m),
                  onSelected: (v) => _actions(context).setDefaultReminder(m, on: v),
                ),
            ]),
          ),
          if (perm != ReminderPermission.granted)
            Builder(builder: (context) {
              final hint = reminderPermissionHint(l, coordinator, perm);
              // Kein ListTile: Eine lange Schaltfläche als trailing drückte den Text in eine schmale, abgeschnittene Spalte (#97).
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    const Padding(padding: EdgeInsets.only(top: 2, right: 16), child: Icon(Icons.notifications_off_outlined)),
                    Expanded(child: Text(hint.text)),
                  ]),
                  Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: hint.onPressed, child: Text(hint.action))),
                ]),
              );
            }),
        ]);
      },
    );
  }
}

/// Schalter für die Meldungen zu Chat und Einkauf (#254, E-88). Beim Einschalten wird nur die
/// Benachrichtigungsberechtigung angefragt (ohne genaue Alarme).
class _ActivitySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.settings;
        return _Section(title: l.settingsActivity, children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.settingsActivityHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          SwitchListTile(
            title: Text(l.settingsNotifyChat),
            value: s.notifyChat,
            onChanged: (v) => _actions(context).setNotifyChat(on: v),
          ),
          SwitchListTile(
            title: Text(l.settingsNotifyShopping),
            value: s.notifyShopping,
            onChanged: (v) => _actions(context).setNotifyShopping(on: v),
          ),
          if (PlatformInfo.isIOS || PlatformInfo.isMacOS)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l.settingsActivityBadgeApple, style: Theme.of(context).textTheme.bodySmall),
            ),
        ]);
      },
    );
  }
}
