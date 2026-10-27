import 'package:family_nexus/domain/calendar_view.dart';
import 'package:family_nexus/domain/occurrence.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/events.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);
  late tz.Location berlin;
  setUp(() => berlin = tz.getLocation('Europe/Berlin'));

  test('Woche beginnt am Montag', () {
    expect(CalendarView.weekStart(DateTime.utc(2026, 3, 22)), DateTime.utc(2026, 3, 16)); // Sonntag
    expect(CalendarView.weekStart(DateTime.utc(2026, 3, 16)), DateTime.utc(2026, 3, 16));
    expect(CalendarView.weekDays(DateTime.utc(2026, 3, 18)).map((d) => d.day), <int>[16, 17, 18, 19, 20, 21, 22]);
  });

  test('Monatsraster: 42 Tage, Montag zuerst, enthält alle Monatstage', () {
    final g = CalendarView.monthGrid(DateTime.utc(2026, 2, 10));
    expect(g, hasLength(42));
    expect(g.first.weekday, DateTime.monday);
    expect(g.first, DateTime.utc(2026, 1, 26));
    expect(g.where((d) => d.month == 2), hasLength(28));
  });

  test('Monate addieren mit Klemmung auf Monatsende', () {
    expect(CalendarView.addMonths(DateTime.utc(2026, 1, 31), 1), DateTime.utc(2026, 2, 28));
    expect(CalendarView.addMonths(DateTime.utc(2026, 12, 15), 1), DateTime.utc(2027, 1, 15));
    expect(CalendarView.addMonths(DateTime.utc(2026, 1, 15), -2), DateTime.utc(2025, 11, 15));
  });

  test('Tagesgrenzen folgen der lokalen Zeitzone (Sommerzeittag hat 23 Stunden)', () {
    final s = CalendarView.startOfDay(berlin, DateTime.utc(2026, 3, 29)).toUtc();
    final e = CalendarView.endOfDay(berlin, DateTime.utc(2026, 3, 29)).toUtc();
    expect(e.difference(s).inHours, 23);
  });

  test('Termin kurz nach Mitternacht lokal gehört zum lokalen, nicht zum UTC-Tag', () {
    final e = ev(d: 21, h: 0, mi: 30); // 20.03. 23:30Z = 21.03. 00:30 lokal
    final occ = OccurrenceExpander.expand(e, from: DateTime.utc(2026, 3, 1), to: DateTime.utc(2026, 4, 1));
    expect(CalendarView.forDay(occ, berlin, DateTime.utc(2026, 3, 21)), hasLength(1));
    expect(CalendarView.forDay(occ, berlin, DateTime.utc(2026, 3, 20)), isEmpty);
  });

  test('Sortierung: ganztägig zuerst, dann nach Beginn', () {
    final a = ev(d: 20, h: 14, title: 'Spät');
    final b = ev(d: 20, h: 8, title: 'Früh');
    final c = ev(d: 20, allDay: true, title: 'Ganztags');
    final occ = <Occurrence>[
      for (final e in [a, b, c])
        ...OccurrenceExpander.expand(e, from: DateTime.utc(2026, 3, 19), to: DateTime.utc(2026, 3, 22)),
    ];
    expect(CalendarView.forDay(occ, berlin, DateTime.utc(2026, 3, 20)).map((o) => o.event.title), <String>['Ganztags', 'Früh', 'Spät']);
  });

  test('#33 „Nächste Termine“: nach Beginn, ganztägige späterer Tage nicht vorn', () {
    final heute = ev(d: 20, h: 18, title: 'Heute Abend');
    final morgen = ev(d: 21, allDay: true, title: 'Morgen ganztags');
    final morgenFrueh = ev(d: 21, h: 8, title: 'Morgen früh');
    final occ = <Occurrence>[
      for (final e in [morgen, morgenFrueh, heute])
        ...OccurrenceExpander.expand(e, from: DateTime.utc(2026, 3, 20), to: DateTime.utc(2026, 3, 23), viewer: berlin),
    ]..sort(CalendarView.compare);
    expect(occ.map((o) => o.event.title), <String>['Heute Abend', 'Morgen ganztags', 'Morgen früh']);
  });

  test('mehrtägiger Termin erscheint an jedem berührten Tag der Agenda', () {
    final e = ev(d: 20, h: 22, length: const Duration(hours: 30)); // bis 22.03. 04:00
    final occ = OccurrenceExpander.expand(e, from: DateTime.utc(2026, 3, 1), to: DateTime.utc(2026, 4, 1));
    final g = CalendarView.groupByDay(occ, berlin, DateTime.utc(2026, 3, 19), DateTime.utc(2026, 3, 24));
    expect(g.keys.map((d) => d.day), <int>[20, 21, 22]);
  });

  test('Personenfilter: Besitzer oder Teilnehmer', () {
    final e = ev(owner: kOwner, attendees: const <String>[kOther]);
    expect(CalendarView.matchesPerson(e, <String>{}), isTrue);
    expect(CalendarView.matchesPerson(e, <String>{kOwner}), isTrue);
    expect(CalendarView.matchesPerson(e, <String>{kOther}), isTrue);
    expect(CalendarView.matchesPerson(e, <String>{'@cara:fake.test'}), isFalse);
  });

  test('Serie über die Sommerzeit bleibt im Wochenraster stabil', () {
    final e = ev(d: 23, recurrence: const Recurrence(frequency: Frequency.weekly, count: 3));
    final occ = OccurrenceExpander.expand(e, from: DateTime.utc(2026, 3), to: DateTime.utc(2026, 5));
    final g = CalendarView.groupByDay(occ, berlin, DateTime.utc(2026, 3, 1), DateTime.utc(2026, 4, 30));
    expect(g.keys.map((d) => d.day), <int>[23, 30, 6]);
  });
}
