import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../domain/family.dart';
import '../../domain/task_period.dart';
import '../../domain/tasks.dart';
import '../../domain/time_zones.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/length_limit.dart';
import '../calendar/formatting.dart';
import '../chat/sender_name.dart';
import '../common/error_text.dart';
import 'tasks_controller.dart';

part 'widgets/task_editor_screen.dart';
part 'widgets/task_parts.dart';

/// Kurzlabel für die Kachel (Täglich, Mo–Fr, Wöchentlich, Monatlich).
String _badgeLabel(AppLocalizations l, TaskRule r) => switch (r.kind) {
      TaskRepeat.everyDay => l.tasksIntervalDaily,
      TaskRepeat.weekdays => l.tasksBadgeWeekdays,
      TaskRepeat.weekly => l.tasksIntervalWeekly,
      TaskRepeat.monthlyByWeekday || TaskRepeat.monthlyByDate => l.tasksIntervalMonthly,
    };

List<String> _weekdayNames(AppLocalizations l) => <String>[
      l.weekdayLongMon,
      l.weekdayLongTue,
      l.weekdayLongWed,
      l.weekdayLongThu,
      l.weekdayLongFri,
      l.weekdayLongSat,
      l.weekdayLongSun,
    ];

/// „Erster“ … „Letzter“ (Auswahlliste).
String _ordinalLabel(AppLocalizations l, int o) => switch (o) {
      1 => l.tasksOrdinal1,
      2 => l.tasksOrdinal2,
      3 => l.tasksOrdinal3,
      4 => l.tasksOrdinal4,
      _ => l.tasksOrdinalLast,
    };

/// „ersten“ … „letzten“ (im Satz: „am zweiten Dienstag“).
String _ordinalInText(AppLocalizations l, int o) => switch (o) {
      1 => l.tasksOrdinalInText1,
      2 => l.tasksOrdinalInText2,
      3 => l.tasksOrdinalInText3,
      4 => l.tasksOrdinalInText4,
      _ => l.tasksOrdinalInTextLast,
    };

/// Ausgeschriebene Regel, z. B. „Monatlich am zweiten Dienstag“.
String _ruleLabel(AppLocalizations l, TaskRule r) {
  final days = _weekdayNames(l);
  return switch (r.kind) {
    TaskRepeat.everyDay => l.tasksIntervalDaily,
    TaskRepeat.weekdays => l.tasksRuleWeekdays,
    TaskRepeat.weekly => l.tasksRuleWeekly(days[r.weekday! - 1]),
    TaskRepeat.monthlyByWeekday => l.tasksRuleMonthlyWeekday(_ordinalInText(l, r.ordinal!), days[r.weekday! - 1]),
    TaskRepeat.monthlyByDate => l.tasksRuleMonthlyDate(r.day!),
  };
}

/// Wann die Liste neu startet.
String _resetLabel(AppLocalizations l, TaskRule r) {
  final days = _weekdayNames(l);
  return switch (r.kind) {
    TaskRepeat.everyDay => l.tasksResetDaily,
    TaskRepeat.weekdays => l.tasksResetWeekdays,
    TaskRepeat.weekly => l.tasksResetWeeklyOn(days[r.weekday! - 1]),
    TaskRepeat.monthlyByWeekday => l.tasksResetMonthlyWeekday(_ordinalInText(l, r.ordinal!), days[r.weekday! - 1]),
    TaskRepeat.monthlyByDate => r.day! > 28 ? l.tasksResetMonthlyDateShort(r.day!) : l.tasksResetMonthlyDate(r.day!),
  };
}

/// Erledigt-Datum (`yyyy-MM-dd`) in der Schreibweise der App-Sprache, z. B. „03.11.2026“ (#38, #260).
String _date(BuildContext context, String doneOn) {
  final p = TaskPeriod.parseDate(doneOn);
  if (p == null) return doneOn;
  return formatDateNumeric(DateTime(p.y, p.m, p.d), Localizations.localeOf(context).toLanguageTag());
}

/// Uhrzeit der Erledigung in der Zeitzone der Liste – dieselbe Zone, aus der das Datum stammt (E-51, #163).
/// Ist die Zone unbekannt, bleibt die Gerätezeit.
String _time(BuildContext context, TaskList list, DateTime at) {
  final loc = TimeZones.tryGet(list.timeZone);
  final c = loc == null ? null : TaskPeriod.localClock(loc, at);
  if (c != null) return formatClock(context, c.hour, c.minute);
  final d = at.toLocal();
  return formatClock(context, d.hour, d.minute);
}

String _nameOf(AppServices s, TasksController c, AppLocalizations l, String id, {bool inSentence = false}) =>
    memberLabel(l, s.gateway.family, id, me: c.me, inSentence: inSentence);

/// „Zugewiesen an dich“ für die eigene Liste, sonst „Zugewiesen an {Name}“ (Dativ, #329).
String _assignedLabel(AppServices s, TasksController c, AppLocalizations l, String assignee) =>
    assignee == c.me ? l.tasksAssignedToYou : l.tasksAssignedTo(_nameOf(s, c, l, assignee, inSentence: true));

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Übersicht der Aufgabenlisten der Familie (E-51).
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final c = services.tasks;
    final l = AppLocalizations.of(context);
    if (c == null) return Scaffold(appBar: AppBar(title: Text(l.tasksTitle)));
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[c, services.gateway]),
      builder: (context, _) {
        final mine = c.mine;
        final others = c.others;
        return Scaffold(
          appBar: AppBar(title: Text(l.tasksTitle)),
          floatingActionButton: c.canManage
              ? FloatingActionButton(
                  heroTag: 'fab-tasks',
                  tooltip: l.tasksNew,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(controller: c))),
                  child: const Icon(Icons.add),
                )
              : null,
          body: SafeArea(
            child: ContentWidth(child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  const Icon(Icons.lock_outline, size: 14),
                  const SizedBox(width: 4),
                  Flexible(child: Text(l.tasksNote, style: Theme.of(context).textTheme.labelSmall)),
                ]),
              ),
              if (mine.isEmpty && others.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Text(l.tasksEmpty, textAlign: TextAlign.center)),
              if (mine.isNotEmpty) ...<Widget>[
                _Header(l.tasksSectionMine),
                for (final t in mine) _ListTile(list: t, controller: c, services: services),
              ],
              if (others.isNotEmpty) ...<Widget>[
                _Header(l.tasksSectionOthers),
                for (final t in others) _ListTile(list: t, controller: c, services: services),
              ],
            ])),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.list, required this.controller, required this.services});
  final TaskList list;
  final TasksController controller;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final total = list.items.length;
    final done = total - controller.openCount(list);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(list.title),
          subtitle: Text(
            '${_assignedLabel(services, controller, l, list.assignee)}\n${l.tasksProgress(done, total)}',
            style: TextStyle(color: t.textSecondary),
          ),
          isThreeLine: true,
          trailing: StatusBadge(label: _badgeLabel(l, list.rule), color: t.primary),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(listId: list.id))),
        ),
      ),
    );
  }
}

/// Eine Liste: Punkte abhaken (nur die zugewiesene Person) und Verlauf.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.listId});
  final String listId;

  Future<void> _complete(BuildContext context, TasksController c, TaskList list, TaskItem item) async {
    final l = AppLocalizations.of(context);
    final comment = await showDialog<String>(context: context, builder: (_) => _CommentDialog(title: item.title));
    if (comment == null || !context.mounted) return;
    try {
      await c.complete(list.id, item.id, comment: comment);
    } catch (e) {
      if (context.mounted) _toast(context, errorText(l, e));
    }
  }

  Future<void> _undo(BuildContext context, TasksController c, TaskList list, TaskItem item) async {
    final l = AppLocalizations.of(context);
    try {
      await c.undo(list.id, item.id);
    } catch (e) {
      if (context.mounted) _toast(context, errorText(l, e));
    }
  }

  Future<void> _delete(BuildContext context, TasksController c, TaskList list) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l.tasksDeleteConfirm(list.title)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.tasksDelete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await c.delete(list.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _toast(context, errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final c = services.tasks;
    final l = AppLocalizations.of(context);
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[c, services.gateway]),
      builder: (context, _) {
        final list = c.byId(listId);
        if (list == null) {
          // Gelöscht (auch durch eine andere Moderatorin).
          return Scaffold(appBar: AppBar(title: Text(l.tasksTitle)), body: Center(child: Text(l.errNotFound)));
        }
        final t = AuroraTokens.of(context);
        final done = c.doneNow(list);
        final canComplete = list.assignee == c.me;
        final history = c.history(list);
        final material = MaterialLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(list.title), actions: <Widget>[
            if (c.canManage) ...<Widget>[
              IconButton(
                tooltip: l.tasksEditTitle,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(controller: c, existing: list))),
              ),
              IconButton(tooltip: l.tasksDelete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, c, list)),
            ],
          ]),
          body: SafeArea(
            child: ContentWidth(child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: <Widget>[
              Text(_assignedLabel(services, c, l, list.assignee), style: Theme.of(context).textTheme.titleSmall),
              Text('${_ruleLabel(l, list.rule)} · ${_resetLabel(l, list.rule)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
              if (c.nextReset(list) case final next?)
                Text(l.tasksNextReset(material.formatFullDate(next)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
              if (list.description.isNotEmpty) ...<Widget>[const SizedBox(height: 8), _TaskInfoCard(text: list.description)],
              const SizedBox(height: 4),
              Text(l.tasksProgress(done.length, list.items.length), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final item in list.items)
                _TaskItemRow(
                  item: item,
                  entry: done[item.id],
                  list: list,
                  canComplete: canComplete,
                  onComplete: () => _complete(context, c, list, item),
                  onUndo: () => _undo(context, c, list, item),
                ),
              _Header(l.tasksHistory),
              if (history.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.tasksHistoryEmpty)),
              for (final e in history)
                _TaskHistoryTile(entry: e, list: list, by: _nameOf(services, c, l, e.by)),
            ])),
          ),
        );
      },
    );
  }
}
