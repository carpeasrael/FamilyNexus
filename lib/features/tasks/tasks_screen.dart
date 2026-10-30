import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_services.dart';
import '../../domain/family.dart';
import '../../domain/task_period.dart';
import '../../domain/tasks.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import '../chat/sender_name.dart';
import 'tasks_controller.dart';

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

/// Erledigt-Datum (`yyyy-MM-dd`) in der Schreibweise der App-Sprache, z. B. „26.10.2026“ (#38).
String _date(BuildContext context, String doneOn) {
  final p = TaskPeriod.parseDate(doneOn);
  if (p == null) return doneOn;
  return DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(DateTime(p.y, p.m, p.d));
}

String _nameOf(AppServices s, TasksController c, AppLocalizations l, String id) => memberLabel(l, s.gateway.family, id, me: c.me);

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
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: <Widget>[
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
            ]),
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
            '${l.tasksAssignedTo(_nameOf(services, controller, l, list.assignee))}\n${l.tasksProgress(done, total)}',
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
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: <Widget>[
              Text(l.tasksAssignedTo(_nameOf(services, c, l, list.assignee)), style: Theme.of(context).textTheme.titleSmall),
              Text('${_ruleLabel(l, list.rule)} · ${_resetLabel(l, list.rule)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
              if (c.nextReset(list) case final next?)
                Text(l.tasksNextReset(material.formatFullDate(next)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary)),
              if (list.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Icon(Icons.info_outline, size: 18, color: t.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(list.description)),
                  ]),
                ),
              ],
              const SizedBox(height: 4),
              Text(l.tasksProgress(done.length, list.items.length), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final item in list.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(children: <Widget>[
                      Semantics(
                        label: done.containsKey(item.id) ? l.tasksMarkUndone(item.title) : l.tasksMarkDone(item.title),
                        child: Checkbox(
                          value: done.containsKey(item.id),
                          onChanged: canComplete
                              ? (v) => v == true ? _complete(context, c, list, item) : _undo(context, c, list, item)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          Text(
                            item.title,
                            style: done.containsKey(item.id)
                                ? Theme.of(context).textTheme.bodyLarge?.copyWith(decoration: TextDecoration.lineThrough, color: t.textSecondary)
                                : Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (done[item.id] case final e?) ...<Widget>[
                            Text(
                              l.tasksDoneOn(_date(context, e.doneOn), material.formatTimeOfDay(TimeOfDay.fromDateTime(e.at.toLocal()))),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                            ),
                            if (e.comment.isNotEmpty) Text(e.comment, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                ),
              _Header(l.tasksHistory),
              if (history.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.tasksHistoryEmpty)),
              for (final e in history)
                ListTile(
                  dense: true,
                  leading: Icon(e.kind == TaskLogKind.done ? Icons.check_circle_outline : Icons.undo),
                  title: Text(() {
                    final title = list.items.where((i) => i.id == e.itemId).map((i) => i.title).firstOrNull ?? '';
                    return e.kind == TaskLogKind.done ? l.tasksHistoryDone(title) : l.tasksHistoryUndone(title);
                  }()),
                  subtitle: Text([
                    l.tasksHistoryLine(
                      _nameOf(services, c, l, e.by),
                      _date(context, e.doneOn),
                      material.formatTimeOfDay(TimeOfDay.fromDateTime(e.at.toLocal())),
                    ),
                    if (e.comment.isNotEmpty) e.comment,
                  ].join('\n')),
                ),
            ]),
          ),
        );
      },
    );
  }
}

/// Kommentar-Dialog beim Abhaken; die Eingabe gehört dem Dialog.
class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.title});
  final String title;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _comment,
        autofocus: true,
        maxLength: TaskLogEntry.maxComment,
        enableIMEPersonalizedLearning: false,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.tasksCommentHint),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _comment.text), child: Text(l.tasksConfirmDone)),
      ],
    );
  }
}

/// Anlegen und Bearbeiten einer Liste (nur Moderatoren).
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, required this.controller, this.existing});
  final TasksController controller;
  final TaskList? existing;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _items =
      TextEditingController(text: widget.existing?.items.map((i) => i.title).join('\n') ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.existing?.description ?? '');
  late _RepeatMode _mode;
  bool _includeWeekend = true;
  int _weekday = DateTime.monday;
  int _ordinal = 1;
  int _day = 1;
  String? _assignee;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _assignee = widget.existing?.assignee;
    final r = widget.existing?.rule ?? const TaskRule.everyDay();
    _mode = switch (r.kind) {
      TaskRepeat.everyDay || TaskRepeat.weekdays => _RepeatMode.daily,
      TaskRepeat.weekly => _RepeatMode.weekly,
      TaskRepeat.monthlyByWeekday => _RepeatMode.monthlyByWeekday,
      TaskRepeat.monthlyByDate => _RepeatMode.monthlyByDate,
    };
    _includeWeekend = r.kind != TaskRepeat.weekdays;
    _weekday = r.weekday ?? DateTime.monday;
    _ordinal = r.ordinal ?? 1;
    _day = r.day ?? 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _items.dispose();
    super.dispose();
  }

  TaskRule get _rule => switch (_mode) {
        _RepeatMode.daily => _includeWeekend ? const TaskRule.everyDay() : const TaskRule.weekdays(),
        _RepeatMode.weekly => TaskRule.weekly(_weekday),
        _RepeatMode.monthlyByWeekday => TaskRule.monthlyByWeekday(_ordinal, _weekday),
        _RepeatMode.monthlyByDate => TaskRule.monthlyByDate(_day),
      };

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final assignee = _assignee;
    final items = _items.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (_title.text.trim().isEmpty || assignee == null || items.isEmpty) {
      _toast(context, l.tasksInvalid);
      return;
    }
    // Das Eingabefeld zählt Zeichen, wie man sie sieht; gespeichert wird nach Unicode-Zeichen begrenzt
    // (Emoji mit Hautfarbe zählen doppelt). Eigene Meldung statt „Titel, Person und Punkte angeben“.
    if (_description.text.trim().runes.length > TaskList.maxDescription) {
      _toast(context, l.tasksDescriptionTooLong);
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.controller.create(
          title: _title.text,
          assignee: assignee,
          rule: _rule,
          description: _description.text,
          items: items,
        );
      } else {
        await widget.controller.update(
          existing.id,
          title: _title.text,
          assignee: assignee,
          rule: _rule,
          description: _description.text,
          items: items,
        );
      }
      if (mounted) nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        if (context.mounted) _toast(context, errorText(l, e));
      }
    }
  }

  /// Wiederholung (Issue #1): Art, dann die passenden Angaben; darunter, wann die Liste neu startet.
  List<Widget> _repeatFields(AppLocalizations l) {
    final days = _weekdayNames(l);
    DropdownButtonFormField<int> weekdayField() => DropdownButtonFormField<int>(
          key: ValueKey<String>('weekday-$_mode'),
          initialValue: _weekday,
          decoration: InputDecoration(labelText: l.tasksFieldWeekday),
          items: <DropdownMenuItem<int>>[
            for (var i = 1; i <= 7; i++) DropdownMenuItem<int>(value: i, child: Text(days[i - 1])),
          ],
          onChanged: (v) => setState(() => _weekday = v ?? _weekday),
        );
    return <Widget>[
      DropdownButtonFormField<_RepeatMode>(
        initialValue: _mode,
        decoration: InputDecoration(labelText: l.tasksFieldInterval),
        items: <DropdownMenuItem<_RepeatMode>>[
          DropdownMenuItem<_RepeatMode>(value: _RepeatMode.daily, child: Text(l.tasksIntervalDaily)),
          DropdownMenuItem<_RepeatMode>(value: _RepeatMode.weekly, child: Text(l.tasksIntervalWeekly)),
          DropdownMenuItem<_RepeatMode>(value: _RepeatMode.monthlyByWeekday, child: Text(l.tasksRepeatMonthlyWeekday)),
          DropdownMenuItem<_RepeatMode>(value: _RepeatMode.monthlyByDate, child: Text(l.tasksRepeatMonthlyDate)),
        ],
        onChanged: (v) => setState(() => _mode = v ?? _mode),
      ),
      const SizedBox(height: 8),
      switch (_mode) {
        _RepeatMode.daily => RadioGroup<bool>(
            groupValue: _includeWeekend,
            onChanged: (v) => setState(() => _includeWeekend = v ?? _includeWeekend),
            child: Column(children: <Widget>[
              RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: true, title: Text(l.tasksDailyAllDays)),
              RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: false, title: Text(l.tasksDailyWeekdays)),
            ]),
          ),
        _RepeatMode.weekly => weekdayField(),
        _RepeatMode.monthlyByWeekday => Row(children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _ordinal,
                decoration: InputDecoration(labelText: l.tasksFieldOrdinal),
                items: <DropdownMenuItem<int>>[
                  for (final o in <int>[1, 2, 3, 4, TaskRule.last]) DropdownMenuItem<int>(value: o, child: Text(_ordinalLabel(l, o))),
                ],
                onChanged: (v) => setState(() => _ordinal = v ?? _ordinal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: weekdayField()),
          ]),
        _RepeatMode.monthlyByDate => DropdownButtonFormField<int>(
            initialValue: _day,
            decoration: InputDecoration(labelText: l.tasksFieldDay),
            items: <DropdownMenuItem<int>>[
              for (var d = 1; d <= 31; d++) DropdownMenuItem<int>(value: d, child: Text('$d.')),
            ],
            onChanged: (v) => setState(() => _day = v ?? _day),
          ),
      },
      const SizedBox(height: 4),
      Semantics(
        liveRegion: true,
        child: Text(_resetLabel(l, _rule), style: Theme.of(context).textTheme.bodySmall),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final family = services.gateway.family;
    final members = <FamilyMember>[if (family != null) ...family.joined];
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? l.tasksNew : l.tasksEditTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          TextField(
            controller: _title,
            maxLength: TaskList.maxTitle,
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.tasksFieldTitle),
          ),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 6,
            maxLength: TaskList.maxDescription,
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(labelText: l.tasksFieldDescription, hintText: l.tasksDescriptionHint, alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: members.any((m) => m.userId == _assignee) ? _assignee : null,
            decoration: InputDecoration(labelText: l.tasksFieldAssignee),
            items: <DropdownMenuItem<String>>[
              for (final m in members)
                DropdownMenuItem<String>(value: m.userId, child: Text(m.userId == family?.myUserId ? l.chatYou : m.displayName)),
            ],
            onChanged: (v) => setState(() => _assignee = v),
          ),
          const SizedBox(height: 8),
          ..._repeatFields(l),
          const SizedBox(height: 8),
          TextField(
            controller: _items,
            minLines: 4,
            maxLines: 12,
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(labelText: l.tasksFieldItems, alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

enum _RepeatMode { daily, weekly, monthlyByWeekday, monthlyByDate }
