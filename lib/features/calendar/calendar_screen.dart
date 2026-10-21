import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/calendar_view.dart';
import '../../domain/occurrence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import 'calendar_controller.dart';
import 'event_detail_screen.dart';
import 'event_editor_screen.dart';
import 'event_tile.dart';
import 'formatting.dart';

enum CalendarMode { day, week, month, agenda }

/// Kalender mit Tag-, Wochen-, Monats- und Agenda-Ansicht sowie Personenfilter.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarMode _mode = CalendarMode.month;
  late DateTime _focus;
  final Set<String> _persons = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_focusSet) {
      _focusSet = true;
      _focus = AppScope.of(context).calendar!.today;
    }
  }

  bool _focusSet = false;

  void _shift(int dir) {
    setState(() {
      switch (_mode) {
        case CalendarMode.day:
          _focus = DateTime.utc(_focus.year, _focus.month, _focus.day + dir);
        case CalendarMode.week:
          _focus = DateTime.utc(_focus.year, _focus.month, _focus.day + 7 * dir);
        case CalendarMode.month:
          _focus = CalendarView.addMonths(_focus, dir);
        case CalendarMode.agenda:
          _focus = DateTime.utc(_focus.year, _focus.month, _focus.day + 30 * dir);
      }
    });
  }

  void _today() => setState(() => _focus = AppScope.of(context).calendar!.today);

  Future<void> _open(Occurrence o, CalendarController c) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EventDetailScreen(controller: c, occurrence: o),
    ));
  }

  Future<void> _create(CalendarController c) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EventEditorScreen(controller: c, initialDay: _focus),
    ));
  }

  String _title(Fmt f, AppLocalizations l) => switch (_mode) {
        CalendarMode.day => f.dateLong(_focus),
        CalendarMode.week => () {
            final d = CalendarView.weekDays(_focus);
            return '${f.dayMonth(d.first)} – ${f.dateShort(d.last)}';
          }(),
        CalendarMode.month => f.monthYear(_focus),
        CalendarMode.agenda => l.viewAgenda,
      };

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final c = services.calendar!;
    final l = AppLocalizations.of(context);
    final fmt = Fmt(context, c.zone);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-calendar',
        tooltip: l.calendarNewEvent,
        onPressed: () => _create(c),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[c, services.gateway]),
        builder: (context, _) => Column(children: <Widget>[
          _toolbar(l, fmt),
          _personFilter(c, l),
          Expanded(child: _body(c, l, fmt)),
        ]),
      ),
    );
  }

  Widget _toolbar(AppLocalizations l, Fmt fmt) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Column(children: <Widget>[
          SegmentedButton<CalendarMode>(
            showSelectedIcon: false,
            segments: <ButtonSegment<CalendarMode>>[
              ButtonSegment<CalendarMode>(value: CalendarMode.day, label: Text(l.viewDay)),
              ButtonSegment<CalendarMode>(value: CalendarMode.week, label: Text(l.viewWeek)),
              ButtonSegment<CalendarMode>(value: CalendarMode.month, label: Text(l.viewMonth)),
              ButtonSegment<CalendarMode>(value: CalendarMode.agenda, label: Text(l.viewAgenda)),
            ],
            selected: <CalendarMode>{_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          Row(children: <Widget>[
            IconButton(tooltip: l.calendarPrevious, icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(_title(fmt, l), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            IconButton(tooltip: l.calendarNext, icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
            TextButton(onPressed: _today, child: Text(l.calendarToday)),
          ]),
        ]),
      );

  Widget _personFilter(CalendarController c, AppLocalizations l) {
    final family = AppScope.of(context).gateway.family;
    final members = family?.joined.toList() ?? const [];
    if (members.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(l.calendarAll),
              selected: _persons.isEmpty,
              onSelected: (_) => setState(_persons.clear),
            ),
          ),
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: PersonDot(colorIndex: c.colorIndexFor(m.userId)),
                label: Text(m.userId == c.me ? '${m.displayName} ✓' : m.displayName),
                tooltip: l.calendarFilterPerson,
                selected: _persons.contains(m.userId),
                onSelected: (v) => setState(() => v ? _persons.add(m.userId) : _persons.remove(m.userId)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(CalendarController c, AppLocalizations l, Fmt fmt) {
    switch (_mode) {
      case CalendarMode.day:
        return _dayList(c, l, fmt, <DateTime>[_focus], showHeaders: false);
      case CalendarMode.week:
        return _dayList(c, l, fmt, CalendarView.weekDays(_focus), showHeaders: true);
      case CalendarMode.agenda:
        final from = CalendarView.startOfDay(c.zone, _focus).toUtc();
        final to = from.add(const Duration(days: 60));
        final occ = c.occurrences(from, to, persons: _persons);
        final groups = CalendarView.groupByDay(occ, c.zone, from, to);
        if (groups.isEmpty) return Center(child: Text(l.calendarNoEvents));
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: <Widget>[
          for (final e in groups.entries) ..._daySection(c, l, fmt, e.key, e.value, header: true),
        ]);
      case CalendarMode.month:
        return _month(c, l, fmt);
    }
  }

  List<Widget> _daySection(CalendarController c, AppLocalizations l, Fmt fmt, DateTime day, List<Occurrence> list, {required bool header}) {
    final t = AuroraTokens.of(context);
    final isToday = _isToday(day);
    return <Widget>[
      if (header)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Semantics(
            header: true,
            child: Row(children: <Widget>[
              if (isToday) Icon(Icons.circle, size: 10, color: t.primary, semanticLabel: l.calendarToday),
              if (isToday) const SizedBox(width: 6),
              Text(
                '${fmt.weekday(day)}, ${fmt.dateShort(day)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: isToday ? t.primary : null),
              ),
            ]),
          ),
        ),
      for (final o in list) EventTile(occurrence: o, controller: c, onTap: () => _open(o, c)),
    ];
  }

  bool _isToday(DateTime day) {
    final n = AppScope.of(context).calendar!.today;
    return day.year == n.year && day.month == n.month && day.day == n.day;
  }

  Widget _dayList(CalendarController c, AppLocalizations l, Fmt fmt, List<DateTime> days, {required bool showHeaders}) {
    final from = CalendarView.startOfDay(c.zone, days.first).toUtc();
    final to = CalendarView.endOfDay(c.zone, days.last).toUtc();
    final occ = c.occurrences(from, to, persons: _persons);
    final children = <Widget>[];
    for (final d in days) {
      final list = CalendarView.forDay(occ, c.zone, d);
      if (showHeaders || list.isNotEmpty) children.addAll(_daySection(c, l, fmt, d, list, header: showHeaders));
      if (showHeaders && list.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(l.calendarNoEvents, style: Theme.of(context).textTheme.bodySmall),
        ));
      }
    }
    if (!showHeaders && children.isEmpty) return Center(child: Text(l.calendarNoEvents));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: children);
  }

  Widget _month(CalendarController c, AppLocalizations l, Fmt fmt) {
    final t = AuroraTokens.of(context);
    final grid = CalendarView.monthGrid(_focus);
    final from = CalendarView.startOfDay(c.zone, grid.first).toUtc();
    final to = CalendarView.endOfDay(c.zone, grid.last).toUtc();
    final occ = c.occurrences(from, to, persons: _persons);
    final selected = CalendarView.forDay(occ, c.zone, _focus);
    final weekdays = CalendarView.weekDays(_focus);
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: <Widget>[
      Row(children: <Widget>[
        for (final d in weekdays)
          Expanded(child: Center(child: Text(fmt.weekday(d), style: Theme.of(context).textTheme.labelSmall))),
      ]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.95,
        children: <Widget>[
          for (final d in grid)
            _dayCell(c, l, t, d, CalendarView.forDay(occ, c.zone, d), inMonth: d.month == _focus.month, selected: d == _focus),
        ],
      ),
      const SizedBox(height: 12),
      Semantics(
        header: true,
        child: Text('${fmt.dateLong(_focus)} · ${l.calendarEventsOnDay(selected.length)}', style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final o in selected) EventTile(occurrence: o, controller: c, onTap: () => _open(o, c)),
    ]);
  }

  Widget _dayCell(CalendarController c, AppLocalizations l, AuroraTokens t, DateTime d, List<Occurrence> list, {required bool inMonth, required bool selected}) {
    final today = _isToday(d);
    final todaySuffix = today ? ', ${l.calendarToday}' : '';
    final colors = list.map((o) => AuroraTokens.personColors[c.displayColorIndex(o.event) % AuroraTokens.personColors.length]).toSet().take(3).toList();
    return Semantics(
      button: true,
      selected: selected,
      label: '${d.day}. ${l.calendarEventsOnDay(list.length)}$todaySuffix',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _focus = d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? t.primary.withValues(alpha: 0.22) : null,
            border: Border.all(
              color: today ? t.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: today && !t.reduceEffects ? <BoxShadow>[BoxShadow(color: t.primary.withValues(alpha: 0.4), blurRadius: 8)] : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Text(
              '${d.day}',
              style: monoStyle(context, size: 14, color: inMonth ? t.textPrimary : t.textMuted),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 8,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                for (final col in colors)
                  Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 6, height: 6, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                if (list.length > 3) Text('+', style: TextStyle(fontSize: 9, color: t.textSecondary)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Karte für Zusammenfassungen (z. B. auf „Heute“).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              Expanded(child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge))),
              ?trailing,
            ]),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );
}
