import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/events.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);
  final now = DateTime.utc(2026, 3, 20, 6);

  test('plant Standard-Erinnerung vor dem Termin', () {
    final e = ev(h: 9); // 08:00Z
    final r = ReminderPlanner.plan(events: [e], personal: const <String, List<int>>{}, defaults: const <int>[10], now: now);
    expect(r, hasLength(1));
    expect(r.single.fireAt, DateTime.utc(2026, 3, 20, 7, 50));
    expect(r.single.minutesBefore, 10);
  });

  test('eigene Erinnerungen überschreiben den Standard; leere Liste = keine', () {
    final e = ev(h: 9);
    final own = ReminderPlanner.plan(
      events: [e],
      personal: <String, List<int>>{e.id: <int>[10, 60, 1440]},
      defaults: const <int>[5],
      now: now.subtract(const Duration(days: 2)),
    );
    expect(own.map((r) => r.minutesBefore), <int>[1440, 60, 10]);
    final none = ReminderPlanner.plan(events: [e], personal: <String, List<int>>{e.id: <int>[]}, defaults: const <int>[5], now: now);
    expect(none, isEmpty);
  });

  test('vergangene Erinnerungen und gelöschte Termine werden übersprungen', () {
    final e = ev(h: 7); // 06:00Z = jetzt → 10 Min vorher liegt in der Vergangenheit
    expect(ReminderPlanner.plan(events: [e], personal: const {}, defaults: const <int>[10], now: now), isEmpty);
    final g = ev(h: 9).tombstone(now);
    expect(ReminderPlanner.plan(events: [g], personal: const {}, defaults: const <int>[10], now: now), isEmpty);
  });

  test('Serien: jedes Vorkommen im Horizont, begrenzt auf das Limit', () {
    final e = ev(d: 21, recurrence: const Recurrence(frequency: Frequency.daily));
    final r = ReminderPlanner.plan(events: [e], personal: const {}, defaults: const <int>[10], now: now, limit: 5);
    expect(r, hasLength(5));
    expect(r.first.occurrenceStart, DateTime.utc(2026, 3, 21, 8));
    for (var i = 1; i < r.length; i++) {
      expect(r[i].fireAt.isAfter(r[i - 1].fireAt), isTrue);
    }
  });

  test('Horizont: nichts weiter als 60 Tage voraus', () {
    final e = ev(mo: 8, d: 1);
    expect(ReminderPlanner.plan(events: [e], personal: const {}, defaults: const <int>[10], now: now), isEmpty);
  });

  test('Ausnahmen werden respektiert', () {
    final e = ev(d: 21, recurrence: const Recurrence(frequency: Frequency.daily, count: 3, exdates: <String>{'2026-03-22'}));
    final r = ReminderPlanner.plan(events: [e], personal: const {}, defaults: const <int>[10], now: now);
    expect(r.map((x) => x.occurrenceStart.day), <int>[21, 23]);
  });

  test('IDs sind stabil, positiv (31 Bit) und unterscheiden Vorkommen/Minuten', () {
    final a = ReminderPlanner.stableId(kId1, DateTime.utc(2026, 3, 21, 8), 10);
    expect(a, ReminderPlanner.stableId(kId1, DateTime.utc(2026, 3, 21, 8), 10));
    expect(a, inInclusiveRange(0, 0x7fffffff));
    expect(a, isNot(ReminderPlanner.stableId(kId1, DateTime.utc(2026, 3, 21, 8), 60)));
    expect(a, isNot(ReminderPlanner.stableId(kId1, DateTime.utc(2026, 3, 22, 8), 10)));
    expect(a, isNot(ReminderPlanner.stableId(kId2, DateTime.utc(2026, 3, 21, 8), 10)));
  });

  test('Datenschutz: PlannedReminder enthält weder Titel noch Ort noch Notiz', () {
    final e = ev(h: 9, title: 'Geheimer Titel');
    final r = ReminderPlanner.plan(events: [e], personal: const {}, defaults: const <int>[10], now: now).single;
    final dump = '${r.id} ${r.fireAt} ${r.eventId} ${r.occurrenceStart} ${r.minutesBefore}';
    expect(dump, isNot(contains('Geheimer')));
  });

  test('ungültige Minutenwerte werden ignoriert', () {
    final e = ev(h: 9);
    final r = ReminderPlanner.plan(
      events: [e],
      personal: <String, List<int>>{e.id: <int>[-5, 10, 99999999]},
      defaults: const <int>[],
      now: now,
    );
    expect(r.map((x) => x.minutesBefore), <int>[10]);
  });

  test('K7: Erinnerungen ganztägiger Termine beziehen sich auf 09:00 Ortszeit des Tages', () {
    final e = ev(allDay: true, d: 24); // 24.03.2026 ganztägig
    final berlin = tz.getLocation('Europe/Berlin');
    final r = ReminderPlanner.plan(
      events: [e],
      personal: <String, List<int>>{e.id: <int>[0, 1440]},
      defaults: const <int>[],
      now: DateTime.utc(2026, 3, 20),
      viewer: berlin,
    );
    expect(r.map((x) => x.fireAt), <DateTime>[
      DateTime.utc(2026, 3, 23, 8), // 23.03. 09:00 MEZ (+1)... Sommerzeit ab 29.3.
      DateTime.utc(2026, 3, 24, 8),
    ]);
  });

  test('abgesagte Termine (skip) erhalten keine Erinnerung', () {
    final e = ev(d: 25);
    final r = ReminderPlanner.plan(events: [e], personal: const {}, defaults: const <int>[10], now: now, skip: <String>{e.id});
    expect(r, isEmpty);
  });

  group('#218 fällige Erinnerungen', () {
    tz.Location berlin() => tz.getLocation('Europe/Berlin');

    List<ReminderEntry> due(List<CalendarEvent> events, DateTime at, {List<int> defaults = const <int>[10], Set<int> ack = const <int>{}, Set<String> skip = const <String>{}, int limit = ReminderPlanner.maxDue}) =>
        ReminderPlanner.due(events: events, personal: const <String, List<int>>{}, defaults: defaults, now: at, acknowledged: ack, skip: skip, viewer: berlin(), limit: limit);

    test('fällig ab der Auslösezeit bis zum Ende des Termins, dieselbe ID wie die Benachrichtigung', () {
      final e = ev(h: 9); // 08:00Z bis 09:00Z
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 7, 49)), isEmpty);
      final at = due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 7, 50));
      expect(at.single.reminder.id, ReminderPlanner.stableId(e.id, DateTime.utc(2026, 3, 20, 8), 10));
      expect(at.single.occurrence.start, DateTime.utc(2026, 3, 20, 8));
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 8, 30)), hasLength(1), reason: 'läuft noch');
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 9)), isEmpty, reason: 'vorbei');
    });

    test('dieselbe ID wie in plan kurz vor der Auslösung', () {
      final e = ev(h: 9);
      final planned = ReminderPlanner.plan(events: <CalendarEvent>[e], personal: const {}, defaults: const <int>[10], now: DateTime.utc(2026, 3, 20, 7), viewer: berlin());
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 7, 55)).single.reminder.id, planned.single.id);
    });

    test('ganztägig: Bezug 09:00 Ortszeit, fällig bis Tagesende', () {
      final e = ev(allDay: true, d: 20);
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 6, 59), defaults: const <int>[60]), isEmpty);
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 7), defaults: const <int>[60]), hasLength(1));
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 22, 59), defaults: const <int>[60]), hasLength(1));
      expect(due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 23), defaults: const <int>[60]), isEmpty);
    });

    test('Serie: nur das laufende bzw. kommende Vorkommen, vergangene nicht', () {
      final e = ev(d: 18, recurrence: const Recurrence(frequency: Frequency.daily));
      final r = due(<CalendarEvent>[e], DateTime.utc(2026, 3, 20, 7, 55));
      expect(r.single.occurrence.start, DateTime.utc(2026, 3, 20, 8));
    });

    test('abgesagte Termine und bestätigte Erinnerungen fehlen; jüngste zuerst', () {
      final e = ev(h: 9);
      final at = DateTime.utc(2026, 3, 20, 7, 55);
      expect(due(<CalendarEvent>[e], at, skip: <String>{e.id}), isEmpty);
      final both = due(<CalendarEvent>[e], at, defaults: const <int>[10, 60]);
      expect(both.map((x) => x.reminder.minutesBefore), <int>[10, 60]);
      expect(due(<CalendarEvent>[e], at, defaults: const <int>[10, 60], ack: <int>{both.first.reminder.id}).single.reminder.minutesBefore, 60);
    });

    test('Bestätigte fallen vor der Grenze weg und verdecken keine älteren', () {
      String id(int i) => '00000000-0000-4000-8000-${i.toRadixString(16).padLeft(12, '0')}';
      final events = <CalendarEvent>[for (var i = 0; i < 60; i++) ev(id: id(i + 1), h: 9, mi: i % 60, length: const Duration(hours: 3))];
      final at = DateTime.utc(2026, 3, 20, 9, 30);
      final first = due(events, at);
      expect(first, hasLength(ReminderPlanner.maxDue));
      final rest = due(events, at, ack: first.map((e) => e.reminder.id).toSet());
      expect(rest, hasLength(10));
      expect(rest.map((e) => e.reminder.id).toSet().intersection(first.map((e) => e.reminder.id).toSet()), isEmpty);
    });

    test('upcoming liefert dieselben Erinnerungen wie plan', () {
      final events = <CalendarEvent>[ev(h: 9), ev(id: kId2, d: 21, h: 12)];
      final at = DateTime.utc(2026, 3, 20, 6);
      final planned = ReminderPlanner.plan(events: events, personal: const {}, defaults: const <int>[10, 60], now: at, viewer: berlin());
      final up = ReminderPlanner.upcoming(events: events, personal: const {}, defaults: const <int>[10, 60], now: at, viewer: berlin());
      expect(up.map((e) => (e.reminder.id, e.reminder.fireAt)), planned.map((r) => (r.id, r.fireAt)));
      expect(up.first.occurrence.event.id, events.first.id);
    });
  });
}
