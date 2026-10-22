import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/platform/reminder_scheduler.dart';
import '../../l10n/gen/app_localizations.dart';
import '../calendar/calendar_screen.dart' show SectionCard;
import '../calendar/event_detail_screen.dart';
import '../calendar/event_editor_screen.dart';
import '../calendar/event_tile.dart';
import '../presence/presence_view.dart';
import '../tasks/tasks_screen.dart';
import '../../domain/family.dart';
import '../../domain/presence.dart';

/// „Heute“: nächste Termine, Erinnerungen, ungelesene Nachrichten.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenChat, required this.onOpenShopping});
  final VoidCallback onOpenChat;
  final VoidCallback onOpenShopping;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final c = services.calendar!;
    final reminders = services.reminders;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-today',
        tooltip: l.calendarNewEvent,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EventEditorScreen(controller: c))),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[c, services.gateway, ?reminders, ?services.shopping, ?services.tasks]),
        builder: (context, _) {
          final upcoming = c.upcoming(limit: 5);
          final unread = services.gateway.unreadCount;
          final perm = reminders?.permission ?? ReminderPermission.granted;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: <Widget>[
            if (perm != ReminderPermission.granted)
              SectionCard(
                title: l.remindersTitle,
                trailing: TextButton(onPressed: () => reminders?.requestPermission().ignore(), child: Text(l.remindersAllow)),
                child: Text(perm == ReminderPermission.notificationsDenied ? l.remindersPermissionNotifications : l.remindersPermissionExact),
              ),
            SectionCard(
              title: l.todayNext,
              child: upcoming.isEmpty
                  ? Text(l.todayNoUpcoming)
                  : Column(children: <Widget>[
                      for (final o in upcoming)
                        EventTile(
                          occurrence: o,
                          controller: c,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EventDetailScreen(controller: c, occurrence: o))),
                        ),
                    ]),
            ),
            SectionCard(
              title: l.remindersTitle,
              child: Text(l.remindersPlanned(reminders?.plannedCount ?? 0)),
            ),
            SectionCard(
              title: l.todayOnlineHeader,
              child: PresenceBuilder(builder: (context, now) => _OnlineList(services: services, now: now)),
            ),
            if (services.shopping != null)
              SectionCard(
                title: l.shoppingTitle,
                trailing: TextButton(onPressed: onOpenShopping, child: Text(l.tabShopping)),
                child: Text(l.todayShoppingOpen(services.shopping!.openCount)),
              ),
            if (services.tasks != null)
              SectionCard(
                title: l.tasksTitle,
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TasksScreen())),
                  child: Text(l.tasksTitle),
                ),
                child: Text(l.todayTasksOpen(services.tasks!.myOpenCount)),
              ),
            SectionCard(
              title: l.todayUnread,
              trailing: TextButton(onPressed: onOpenChat, child: Text(l.todayOpenChat)),
              child: Text(l.todayUnreadCount(unread)),
            ),
          ]);
        },
      ),
    );
  }
}

/// Die anderen beigetretenen Mitglieder, die gerade online sind.
class _OnlineList extends StatelessWidget {
  const _OnlineList({required this.services, required this.now});
  final AppServices services;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = services.gateway.family;
    final online = <FamilyMember>[
      if (f != null)
        for (final m in f.joined)
          if (m.userId != f.myUserId && presenceOf(services, m.userId, now).status == PresenceStatus.online) m,
    ];
    if (online.isEmpty) return Text(l.todayNobodyOnline);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      for (final m in online)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: <Widget>[
            const PresenceDot(online: true),
            const SizedBox(width: 8),
            Flexible(child: Text('${m.displayName} – ${l.presenceOnline}')),
          ]),
        ),
    ]);
  }
}
