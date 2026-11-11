part of '../tasks_screen.dart';

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
    // Das Eingabefeld begrenzt seit #221 schon nach Unicode-Zeichen wie die Prüfung; das hier bleibt als
    // Absicherung. Eigene Meldung statt „Titel, Person und Punkte angeben“.
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
        child: ContentWidth(child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          TextField(
            controller: _title,
            maxLength: TaskList.maxTitle,
            inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(TaskList.maxTitle, LengthMeasure.codePoints)],
            buildCounter: measuredCounter(_title, TaskList.maxTitle, LengthMeasure.codePoints),
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.tasksFieldTitle),
          ),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 6,
            maxLength: TaskList.maxDescription,
            inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(TaskList.maxDescription, LengthMeasure.codePoints)],
            buildCounter: measuredCounter(_description, TaskList.maxDescription, LengthMeasure.codePoints),
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
        ])),
      ),
    );
  }
}

enum _RepeatMode { daily, weekly, monthlyByWeekday, monthlyByDate }
