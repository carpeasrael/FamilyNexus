import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/platform/reminder_scheduler.dart';
import '../../domain/reminder_planner.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/clock_tick.dart';
import '../../ui/widgets/glass.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_screen.dart' show SectionCard;
import '../calendar/event_detail_screen.dart';
import '../calendar/formatting.dart';
import '../../ui/layout/adaptive.dart';
import 'permission_hint.dart';
import 'reminder_coordinator.dart';

/// Übersicht der Erinnerungen dieses Geräts: fällige zum Bestätigen, darunter geplante (#218, E-87).
///
/// Coordinator und Kalender kommen beim Öffnen herein: Beim Abmelden oder Familienwechsel ist
/// `AppServices.reminders` schon `null`, bevor die Seite geschlossen wird.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.reminders, required this.calendar});
  final ReminderCoordinator reminders;
  final CalendarController calendar;

  void _open(BuildContext context, ReminderEntry e) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => EventDetailScreen(controller: calendar, occurrence: e.occurrence)));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ContentWidth(child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[reminders, calendar]),
        builder: (context, _) => ClockTick(builder: (context) {
          final due = reminders.due();
          final planned = reminders.planned();
          final perm = reminders.permission;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: <Widget>[
            if (perm != ReminderPermission.granted)
              Builder(builder: (context) {
                final hint = reminderPermissionHint(l, reminders, perm);
                return SectionCard(
                  title: l.remindersTitle,
                  trailing: TextButton(onPressed: hint.onPressed, child: Text(hint.action)),
                  child: Text(hint.text),
                );
              }),
            if (due.isEmpty && planned.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.remindersEmpty)),
            if (due.isNotEmpty)
              SectionCard(
                title: l.remindersDueHeader(due.length),
                trailing: due.length > 1
                    ? TextButton(onPressed: () => reminders.acknowledge(due).ignore(), child: Text(l.remindersAcknowledgeAll))
                    : null,
                child: Column(children: <Widget>[
                  for (final e in due)
                    _ReminderRow(
                      entry: e,
                      calendar: calendar,
                      onTap: () => _open(context, e),
                      onAcknowledge: () => reminders.acknowledge(<ReminderEntry>[e]).ignore(),
                    ),
                ]),
              ),
            if (planned.isNotEmpty)
              SectionCard(
                title: l.remindersPlannedHeader(planned.length),
                child: Column(children: <Widget>[
                  for (final e in planned) _ReminderRow(entry: e, calendar: calendar, onTap: () => _open(context, e), showFireTime: true),
                ]),
              ),
          ]);
        }),
      )),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.entry, required this.calendar, required this.onTap, this.onAcknowledge, this.showFireTime = false});
  final ReminderEntry entry;
  final CalendarController calendar;
  final VoidCallback onTap;
  final VoidCallback? onAcknowledge;
  final bool showFireTime;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final fmt = Fmt(context, calendar.zone);
    final o = entry.occurrence;
    final m = entry.reminder.minutesBefore;
    final before = m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m));
    final fire = tz.TZDateTime.from(entry.reminder.fireAt, calendar.zone);
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(children: <Widget>[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(o.event.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(fmt.range(o, l), style: small),
              Text(showFireTime ? '$before · ${l.remindersFiresAt('${fmt.dayMonth(fire)} ${fmt.time(entry.reminder.fireAt)}')}' : before, style: small),
            ]),
          ),
          if (onAcknowledge != null)
            IconButton(
              tooltip: l.remindersAcknowledge(o.event.title),
              icon: const Icon(Icons.check_circle_outline),
              onPressed: onAcknowledge,
            ),
        ]),
      ),
    );
  }
}
