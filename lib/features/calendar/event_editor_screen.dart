import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/app_services.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_service.dart';
import '../../domain/family.dart';
import '../../domain/recurrence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/length_limit.dart';
import '../reminders/reminder_coordinator.dart';
import 'calendar_controller.dart';
import 'formatting.dart';

part 'widgets/event_editor_sections.dart';
part 'widgets/event_editor_support.dart';

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

  /// Ende von Hand gewählt (oder gespeichert): dann ändert „Ganztägig“ es nicht (#264).
  late bool _endTouched;
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
    // Beim Bearbeiten gilt das gespeicherte Ende als gewählt; mehrtägige Termine werden nie verkürzt (#264).
    _endTouched = e != null;
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
        _endTouched = true;
      }
      _timeError = null;
    });
  }

  /// Wanduhrzeit als UTC-Wert, nur zum Rechnen mit Differenzen.
  static DateTime _wall(DateTime date, TimeOfDay t) => DateTime.utc(date.year, date.month, date.day, t.hour, t.minute);

  /// Verschiebt den Beginn; das Ende wandert mit, die Dauer bleibt gleich (#34).
  void _moveStart(DateTime date, TimeOfDay time) {
    var duration = _wall(_endDate, _endTime).difference(_wall(_startDate, _startTime));
    // Auch Ende = Beginn ergibt eine Stunde, sonst wanderte ein Termin ohne Dauer mit (#56).
    if (duration <= Duration.zero) duration = const Duration(hours: 1);
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

  /// Schaltet „Ganztägig“ um. Ohne eigene Endwahl endet ein ganztägiger Termin am Tag des Beginns,
  /// auch wenn das Ende mit Uhrzeit auf 00:00 des Folgetags fiel (#264). Zurück zur Uhrzeit gilt
  /// wieder Ende = Beginn + 1 h (#56); sonst stünde 23:00–00:00 am selben Tag („Ende vor Beginn“).
  void _setAllDay(bool v) {
    _allDay = v;
    _timeError = null;
    if (_endTouched) return;
    if (v) {
      _endDate = _startDate;
    } else {
      _moveStart(_startDate, _startTime);
    }
  }

  Future<void> _pickTime({required bool start}) async {
    // Flutter zeigt das Ziffernblatt im Format der App-Sprache (Deutsch: 24 h), prüft die Texteingabe
    // aber nach der Geräteeinstellung. Auf einem 12-h-Gerät lehnte sie deshalb 13–23 ab (#64).
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context) ||
        hourFormat(of: MaterialLocalizations.of(context).timeOfDayFormat()) != HourFormat.h;
    final t = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: use24h),
        child: _SelectAllOnFocus(child: child!),
      ),
    );
    if (t == null) return;
    setState(() {
      if (start) {
        _moveStart(_startDate, t);
      } else {
        _endTime = t;
        _endTouched = true;
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
    // Ganztägig: gleicher Tag ist erlaubt; mit Uhrzeit muss das Ende nach dem Beginn liegen (#56).
    if (_allDay ? end.isBefore(start) : !end.isAfter(start)) {
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
      final CalendarEvent saved;
      if (ex == null) {
        saved = await c.create(
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
        saved = await c.update(
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
      // Der gespeicherte Termin geht an den Aufrufer zurück: Beim Wechsel von „Geteilt“ zu „Privat“
      // entsteht eine Kopie mit neuer ID, der Aufrufer muss ihr folgen.
      if (mounted) nav.pop(saved);
    } on CalendarException {
      if (mounted) _showError(l.eventSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt(context, _zone);
    final members = (AppScope.of(context).gateway.family?.joined ?? const <FamilyMember>[])
        .where((m) => m.userId != widget.controller.me)
        .toList();
    String sd(DateTime d) => fmt.dateShort(d);
    String st(TimeOfDay x) => x.format(context);
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(_ex == null ? l.eventNew : l.eventEdit),
        actions: <Widget>[
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            _TitleTimeCard(
              title: _title,
              allDay: _allDay,
              onAllDay: (v) => setState(() => _setAllDay(v)),
              startDate: sd(_startDate),
              startTime: _allDay ? null : st(_startTime),
              endDate: sd(_endDate),
              endTime: _allDay ? null : st(_endTime),
              onStartDate: () => _pickDate(start: true),
              onStartTime: () => _pickTime(start: true),
              onEndDate: () => _pickDate(start: false),
              onEndTime: () => _pickTime(start: false),
              timeError: _timeError,
              zoneName: widget.controller.zoneName,
            ),
            gap,
            _VisibilityCard(
              visibility: _visibility,
              showChangeNote: _ex != null && _ex!.isShared && _visibility == EventVisibility.private,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            gap,
            _PlaceNoteCard(location: _location, note: _note),
            gap,
            _RepeatCard(
              frequency: _freq,
              interval: _interval,
              weekdays: _weekdays,
              end: _end,
              untilLabel: _until == null ? l.repeatUntil : '${l.repeatUntil}: ${fmt.dateShort(_until!)}',
              count: _count,
              onFrequency: (f) => setState(() => _freq = f),
              onWeekday: (day, on) => setState(() => on ? _weekdays.add(day) : _weekdays.remove(day)),
              onEnd: (e) => setState(() => _end = e),
              onPickUntil: _pickUntil,
            ),
            gap,
            if (_visibility == EventVisibility.shared && members.isNotEmpty) ...<Widget>[
              _AttendeesCard(
                members: members,
                selected: _attendees,
                onToggle: (id, on) => setState(() => on ? _attendees.add(id) : _attendees.remove(id)),
              ),
              gap,
            ],
            _ColorCard(selected: _color, onSelect: (i) => setState(() => _color = i)),
            // Im Browser gibt es keine Erinnerungen (E-53, #145): keine Karte. Gespeicherte Werte bleiben unberührt
            // (`_reminderTouched` wird nur durch die Chips gesetzt).
            if (AppScope.of(context).reminders != null) ...<Widget>[
              gap,
              _ReminderCard(
                selected: _reminders,
                onToggle: (m, on) => setState(() {
                  _reminderTouched = true;
                  on ? _reminders.add(m) : _reminders.remove(m);
                }),
              ),
            ],
            if (_error != null) _FormError(key: _errorKey, text: _error!),
            const SizedBox(height: 24),
          ]),
        )),
      ),
    );
  }
}
