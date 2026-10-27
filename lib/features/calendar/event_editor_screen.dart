import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/app_services.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_service.dart';
import '../../domain/family.dart';
import '../../domain/recurrence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../reminders/reminder_coordinator.dart';
import 'calendar_controller.dart';
import 'formatting.dart';

/// Reminder-Auswahl (Minuten vor Beginn).
const List<int> kReminderChoices = <int>[0, 5, 10, 15, 30, 60, 120, 1440, 2880];

/// Anlegen und Bearbeiten eines Termins.
class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key, required this.controller, this.existing, this.initialDay});

  final CalendarController controller;
  final CalendarEvent? existing;
  final DateTime? initialDay;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

enum _End { never, until, count }

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _note;
  late final TextEditingController _interval;
  late final TextEditingController _count;

  late bool _allDay;
  late DateTime _startDate; // UTC-Datum (Jahr/Monat/Tag)
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late EventVisibility _visibility;
  late int _color;
  late Frequency _freq;
  late Set<int> _weekdays;
  _End _end = _End.never;
  DateTime? _until;
  late Set<String> _attendees;
  late Set<int> _reminders;
  bool _reminderTouched = false;
  bool _saving = false;
  String? _error;

  /// Fehler zu Beginn/Ende: steht direkt unter den Zeitfeldern (#34).
  String? _timeError;
  final GlobalKey _errorKey = GlobalKey();

  CalendarEvent? get _ex => widget.existing;
  tz.Location get _zone => widget.controller.zone;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    final e = _ex;
    final defaults = AppScope.read(context).settings.settings.defaultReminderMinutes;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    if (e != null) {
      _allDay = e.allDay;
      if (e.allDay) {
        _startDate = DateTime.utc(e.start.year, e.start.month, e.start.day);
        _endDate = DateTime.utc(e.end.year, e.end.month, e.end.day);
        _startTime = const TimeOfDay(hour: 9, minute: 0);
        _endTime = const TimeOfDay(hour: 10, minute: 0);
      } else {
        final s = tz.TZDateTime.from(e.start, _zone);
        final en = tz.TZDateTime.from(e.end, _zone);
        _startDate = DateTime.utc(s.year, s.month, s.day);
        _endDate = DateTime.utc(en.year, en.month, en.day);
        _startTime = TimeOfDay(hour: s.hour, minute: s.minute);
        _endTime = TimeOfDay(hour: en.hour, minute: en.minute);
      }
      _visibility = e.visibility;
      _color = e.colorIndex;
      _freq = e.recurrence.frequency;
      _weekdays = <int>{...e.recurrence.weekdays};
      _interval = TextEditingController(text: '${e.recurrence.interval}');
      _count = TextEditingController(text: '${e.recurrence.count ?? 10}');
      if (e.recurrence.count != null) {
        _end = _End.count;
      } else if (e.recurrence.until != null) {
        _end = _End.until;
        _until = e.recurrence.until;
      }
      _attendees = <String>{...e.attendees};
      _reminders = <int>{...c.remindersOf(e, defaults)};
    } else {
      final base = widget.initialDay ?? c.today;
      final n = c.localNow;
      _allDay = false;
      _startDate = DateTime.utc(base.year, base.month, base.day);
      _endDate = _startDate;
      // Nächste volle Stunde; nach 23 Uhr: 00:00 des Folgetags (nie in der Vergangenheit).
      final hour = (n.hour + 1) % 24;
      if (n.hour == 23 && widget.initialDay == null) {
        _startDate = DateTime.utc(base.year, base.month, base.day + 1);
        _endDate = _startDate;
      }
      _startTime = TimeOfDay(hour: hour, minute: 0);
      _endTime = TimeOfDay(hour: (hour + 1) % 24, minute: 0);
      if (hour == 23) _endDate = DateTime.utc(_startDate.year, _startDate.month, _startDate.day + 1);
      // Sichere Voreinstellung: privat. Teilen ist eine bewusste Entscheidung.
      _visibility = EventVisibility.private;
      _color = c.colorIndexFor(c.me);
      _freq = Frequency.none;
      _weekdays = <int>{};
      _interval = TextEditingController(text: '1');
      _count = TextEditingController(text: '10');
      _attendees = <String>{};
      _reminders = <int>{...defaults};
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[_title, _location, _note, _interval, _count]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay t) =>
      tz.TZDateTime(_zone, date.year, date.month, date.day, t.hour, t.minute).toUtc();

  Future<void> _pickDate({required bool start}) async {
    final cur = start ? _startDate : _endDate;
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(cur.year, cur.month, cur.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
    );
    if (d == null) return;
    setState(() {
      final utc = DateTime.utc(d.year, d.month, d.day);
      if (start) {
        _moveStart(utc, _startTime);
      } else {
        _endDate = utc;
      }
      _timeError = null;
    });
  }

  /// Wanduhrzeit als UTC-Wert, nur zum Rechnen mit Differenzen.
  static DateTime _wall(DateTime date, TimeOfDay t) => DateTime.utc(date.year, date.month, date.day, t.hour, t.minute);

  /// Verschiebt den Beginn; das Ende wandert mit, die Dauer bleibt gleich (#34).
  void _moveStart(DateTime date, TimeOfDay time) {
    var duration = _wall(_endDate, _endTime).difference(_wall(_startDate, _startTime));
    if (duration.isNegative) duration = const Duration(hours: 1);
    if (_allDay) {
      final days = _endDate.difference(_startDate).inDays;
      _startDate = date;
      _endDate = DateTime.utc(date.year, date.month, date.day + (days < 0 ? 0 : days));
      return;
    }
    final end = _wall(date, time).add(duration);
    _startDate = date;
    _startTime = time;
    _endDate = DateTime.utc(end.year, end.month, end.day);
    _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  Future<void> _pickTime({required bool start}) async {
    final t = await showTimePicker(context: context, initialTime: start ? _startTime : _endTime);
    if (t == null) return;
    setState(() {
      if (start) {
        _moveStart(_startDate, t);
      } else {
        _endTime = t;
      }
      _timeError = null;
    });
  }

  Future<void> _pickUntil() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(_startDate.year, _startDate.month, _startDate.day + 30),
      firstDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      lastDate: DateTime(2099, 12, 31),
    );
    if (d != null) setState(() => _until = DateTime.utc(d.year, d.month, d.day));
  }

  Recurrence _recurrence() {
    if (_freq == Frequency.none) return Recurrence.none;
    final interval = int.tryParse(_interval.text.trim()) ?? 1;
    return Recurrence(
      frequency: _freq,
      interval: interval,
      weekdays: _freq == Frequency.weekly ? _weekdays : const <int>{},
      count: _end == _End.count ? int.tryParse(_count.text.trim()) : null,
      until: _end == _End.until ? _until : null,
      exdates: _ex?.recurrence.exdates ?? const <String>{},
    );
  }

  /// Zeigt einen Fehler am Formularende und scrollt dorthin (#34).
  void _showError(String text) {
    setState(() => _error = text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _errorKey.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250)).ignore();
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _error = null;
      _timeError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final DateTime start;
    final DateTime end;
    if (_allDay) {
      start = _startDate;
      end = _endDate;
    } else {
      start = _combine(_startDate, _startTime);
      end = _combine(_endDate, _endTime);
    }
    if (end.isBefore(start)) {
      setState(() => _timeError = l.eventEndBeforeStart);
      return;
    }
    if (_end == _End.until && (_until == null || _until!.isBefore(DateTime.utc(_startDate.year, _startDate.month, _startDate.day)))) {
      _showError(l.repeatUntilInvalid);
      return;
    }
    setState(() => _saving = true);
    final c = widget.controller;
    final nav = Navigator.of(context);
    try {
      final reminders = _reminders.toList()..sort((a, b) => b.compareTo(a));
      final ex = _ex;
      if (ex == null) {
        await c.create(
          title: _title.text,
          start: start,
          end: end,
          allDay: _allDay,
          visibility: _visibility,
          location: _location.text.trim(),
          note: _note.text.trim(),
          colorIndex: _color,
          recurrence: _recurrence(),
          attendees: _attendees.toList()..sort(),
          reminders: reminders,
        );
      } else {
        await c.update(
          ex.copyWith(
            title: _title.text.trim(),
            start: start,
            end: end,
            // Die Eingaben gelten in der Zeitzone des Geräts; Wiederholungen laufen dort.
            timeZone: _allDay ? ex.timeZone : c.zoneName,
            allDay: _allDay,
            location: _location.text.trim(),
            note: _note.text.trim(),
            colorIndex: _color,
            recurrence: _recurrence(),
            attendees: _attendees.toList()..sort(),
          ),
          reminders: _reminderTouched ? reminders : null,
          visibility: _visibility,
        );
      }
      if (mounted) nav.pop();
    } on CalendarException {
      if (mounted) _showError(l.eventSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final fmt = Fmt(context, _zone);
    final members = (AppScope.of(context).gateway.family?.joined ?? const <FamilyMember>[])
        .where((m) => m.userId != widget.controller.me)
        .toList();
    String sd(DateTime d) => fmt.dateShort(d);
    String st(TimeOfDay x) => x.format(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_ex == null ? l.eventNew : l.eventEdit),
        actions: <Widget>[
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            GlassCard(
              child: Column(children: <Widget>[
                TextFormField(
                  controller: _title,
                  maxLength: CalendarEvent.maxTitle,
                  textCapitalization: TextCapitalization.sentences,
                  enableIMEPersonalizedLearning: false,
                  decoration: InputDecoration(labelText: l.eventTitle),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.eventTitleRequired : null,
                ),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.eventAllDay), value: _allDay, onChanged: (v) => setState(() => _allDay = v)),
                _dateRow(l.eventStart, sd(_startDate), _allDay ? null : st(_startTime), () => _pickDate(start: true), () => _pickTime(start: true)),
                _dateRow(l.eventEnd, sd(_endDate), _allDay ? null : st(_endTime), () => _pickDate(start: false), () => _pickTime(start: false)),
                if (_timeError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Semantics(liveRegion: true, child: Text(_timeError!, style: TextStyle(color: t.danger))),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.eventTimeZone(widget.controller.zoneName), style: Theme.of(context).textTheme.bodySmall),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(l.eventVisibility, style: Theme.of(context).textTheme.titleSmall),
                SegmentedButton<EventVisibility>(
                  segments: <ButtonSegment<EventVisibility>>[
                    ButtonSegment<EventVisibility>(value: EventVisibility.private, icon: const Icon(Icons.lock_outline), label: Text(l.visibilityPrivate)),
                    ButtonSegment<EventVisibility>(value: EventVisibility.shared, icon: const Icon(Icons.groups_outlined), label: Text(l.visibilityShared)),
                  ],
                  selected: <EventVisibility>{_visibility},
                  onSelectionChanged: (s) => setState(() => _visibility = s.first),
                ),
                const SizedBox(height: 8),
                Text(_visibility == EventVisibility.shared ? l.visibilitySharedHint : l.visibilityPrivateHint, style: Theme.of(context).textTheme.bodySmall),
                if (_ex != null && _ex!.isShared && _visibility == EventVisibility.private)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.visibilityChangeNote, style: TextStyle(color: t.warning))),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(children: <Widget>[
                TextFormField(controller: _location, maxLength: CalendarEvent.maxLocation, enableIMEPersonalizedLearning: false, decoration: InputDecoration(labelText: l.eventLocation)),
                TextFormField(controller: _note, maxLength: CalendarEvent.maxNote, maxLines: 4, minLines: 2, enableIMEPersonalizedLearning: false, decoration: InputDecoration(labelText: l.eventNote)),
              ]),
            ),
            const SizedBox(height: 12),
            _repeatCard(l),
            const SizedBox(height: 12),
            if (_visibility == EventVisibility.shared && members.isNotEmpty) ...<Widget>[
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(l.eventAttendees, style: Theme.of(context).textTheme.titleSmall),
                  Wrap(spacing: 8, children: <Widget>[
                    for (final m in members)
                      FilterChip(
                        label: Text(m.displayName),
                        selected: _attendees.contains(m.userId),
                        onSelected: (v) => setState(() => v ? _attendees.add(m.userId) : _attendees.remove(m.userId)),
                      ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(l.eventColor, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
                  for (var i = 0; i < AuroraTokens.personColors.length; i++)
                    Semantics(
                      label: l.eventColorName(i + 1),
                      selected: _color == i,
                      button: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AuroraTokens.personColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(color: _color == i ? t.textPrimary : Colors.transparent, width: 3),
                          ),
                          child: _color == i ? const Icon(Icons.check, color: Colors.black) : null,
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(l.remindersTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
                  for (final m in kReminderChoices)
                    FilterChip(
                      label: Text(m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m))),
                      selected: _reminders.contains(m),
                      onSelected: (v) => setState(() {
                        _reminderTouched = true;
                        v ? _reminders.add(m) : _reminders.remove(m);
                      }),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(l.remindersHint, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            if (_error != null)
              Padding(
                key: _errorKey,
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: t.danger))),
              ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _dateRow(String label, String date, String? time, VoidCallback onDate, VoidCallback onTime) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: <Widget>[
          SizedBox(width: 64, child: Text(label)),
          Expanded(child: OutlinedButton(onPressed: onDate, child: Text(date))),
          if (time != null) ...<Widget>[
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onTime, child: Text(time)),
          ],
        ]),
      );

  Widget _repeatCard(AppLocalizations l) {
    final labels = <Frequency, String>{
      Frequency.none: l.repeatNone,
      Frequency.daily: l.repeatDaily,
      Frequency.weekly: l.repeatWeekly,
      Frequency.monthly: l.repeatMonthly,
      Frequency.yearly: l.repeatYearly,
    };
    final weekdayNames = <String>[l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu, l.weekdayFri, l.weekdaySat, l.weekdaySun];
    final unit = switch (_freq) {
      Frequency.daily => l.repeatUnitDays,
      Frequency.weekly => l.repeatUnitWeeks,
      Frequency.monthly => l.repeatUnitMonths,
      Frequency.yearly => l.repeatUnitYears,
      Frequency.none => '',
    };
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventRepeat, style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, children: <Widget>[
          for (final e in labels.entries)
            ChoiceChip(label: Text(e.value), selected: _freq == e.key, onSelected: (_) => setState(() => _freq = e.key)),
        ]),
        if (_freq != Frequency.none) ...<Widget>[
          const SizedBox(height: 8),
          Row(children: <Widget>[
            Text(l.repeatEvery),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: TextFormField(
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 1 || n > Recurrence.maxInterval) ? l.errInvalidInput : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Text(unit),
          ]),
          if (_freq == Frequency.weekly)
            Wrap(spacing: 6, children: <Widget>[
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(weekdayNames[i]),
                  selected: _weekdays.contains(i + 1),
                  onSelected: (v) => setState(() => v ? _weekdays.add(i + 1) : _weekdays.remove(i + 1)),
                ),
            ]),
          const SizedBox(height: 8),
          Text(l.repeatEnds, style: Theme.of(context).textTheme.labelMedium),
          Wrap(spacing: 8, children: <Widget>[
            ChoiceChip(label: Text(l.repeatEndsNever), selected: _end == _End.never, onSelected: (_) => setState(() => _end = _End.never)),
            ChoiceChip(label: Text(l.repeatEndsOn), selected: _end == _End.until, onSelected: (_) => setState(() => _end = _End.until)),
            ChoiceChip(label: Text(l.repeatEndsAfter), selected: _end == _End.count, onSelected: (_) => setState(() => _end = _End.count)),
          ]),
          if (_end == _End.until)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: _pickUntil,
                child: Text(_until == null ? l.repeatUntil : '${l.repeatUntil}: ${Fmt(context, _zone).dateShort(_until!)}'),
              ),
            ),
          if (_end == _End.count)
            SizedBox(
              width: 140,
              child: TextFormField(
                controller: _count,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.repeatCount),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 1 || n > Recurrence.maxCount) ? l.errInvalidInput : null;
                },
              ),
            ),
        ],
      ]),
    );
  }
}
