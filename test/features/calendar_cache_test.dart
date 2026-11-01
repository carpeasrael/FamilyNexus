import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_view.dart';
import 'package:family_nexus/domain/occurrence.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_event_store.dart';

/// #151: Die Vorkommen werden je Fenster zwischengespeichert, ohne dass sich das Ergebnis ändert.
void main() {
  late DateTime now;
  late CalendarController c;
  late MemoryEventStore store;

  Future<CalendarEvent> add(String title, DateTime start, DateTime end,
      {bool allDay = false, Recurrence recurrence = Recurrence.none, EventVisibility visibility = EventVisibility.private}) =>
      c.service.create(
        title: title,
        start: start,
        end: end,
        timeZone: 'Europe/Berlin',
        visibility: visibility,
        allDay: allDay,
        recurrence: recurrence,
      );

  setUp(() async {
    now = DateTime.utc(2026, 3, 20, 10, 0, 30);
    store = MemoryEventStore();
    c = buildCalendarController(
      store: store,
      gateway: FakeMatrixServer().newDevice(),
      userId: '@anna:fake.test',
      zoneName: 'Europe/Berlin',
      clock: () => now,
      retryInterval: const Duration(hours: 1),
    );
  });

  /// Der bisherige Algorithmus ohne Zwischenspeicher als Referenz.
  List<Occurrence> reference(DateTime n, {int limit = 10, Duration window = const Duration(days: 30)}) {
    final out = <Occurrence>[];
    for (final e in c.events) {
      if (e.deleted) continue;
      out.addAll(OccurrenceExpander.expand(e, from: n, to: n.add(window), viewer: c.zone));
    }
    out.sort(CalendarView.compare);
    final list = out.where((o) => o.end.isAfter(n)).toList();
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  List<String> ids(List<Occurrence> l) => l.map((o) => '${o.event.id}@${o.start.toIso8601String()}').toList();

  test('gleiche Anfrage liefert dieselbe Liste; nach load() mit neuem Bestand ein neues Ergebnis', () async {
    await add('A', DateTime.utc(2026, 3, 21, 9), DateTime.utc(2026, 3, 21, 10));
    await c.load();
    final from = DateTime.utc(2026, 3, 1);
    final to = DateTime.utc(2026, 4, 1);
    final first = c.occurrences(from, to);
    expect(identical(c.occurrences(from, to), first), isTrue, reason: 'Cache-Treffer');
    expect(first, hasLength(1));
    expect(() => first.add(first.first), throwsUnsupportedError, reason: 'Cache darf nicht verändert werden');

    await add('B', DateTime.utc(2026, 3, 22, 9), DateTime.utc(2026, 3, 22, 10));
    await c.load();
    final second = c.occurrences(from, to);
    expect(identical(second, first), isFalse);
    expect(second, hasLength(2), reason: 'kein veralteter Cache');
  });

  test('Personenauswahl gehört zum Schlüssel, auch wenn das Set später verändert wird', () async {
    await add('Meins', DateTime.utc(2026, 3, 21, 9), DateTime.utc(2026, 3, 21, 10));
    await c.load();
    final from = DateTime.utc(2026, 3, 1);
    final to = DateTime.utc(2026, 4, 1);
    final persons = <String>{'@ben:fake.test'};
    final forBen = c.occurrences(from, to, persons: persons);
    persons
      ..clear()
      ..add('@anna:fake.test');
    final forAnna = c.occurrences(from, to, persons: persons);
    expect(identical(forBen, forAnna), isFalse);
    expect(ids(forBen), isNot(equals(ids(forAnna))));
    expect(forAnna, hasLength(1));
    expect(forBen, isEmpty);
  });

  test('upcoming entspricht dem bisherigen Algorithmus (Rand, laufend, ganztägig, wiederkehrend, Minutenwechsel)', () async {
    // laufend (begann vor jetzt, endet danach), endet genau jetzt, beginnt genau am Fensterende, ganztägig
    await add('läuft', DateTime.utc(2026, 3, 20, 9, 30), DateTime.utc(2026, 3, 20, 10, 30));
    await add('endet', DateTime.utc(2026, 3, 20, 9), DateTime.utc(2026, 3, 20, 10, 0, 30));
    await add('rand', DateTime.utc(2026, 4, 19, 10, 0, 30), DateTime.utc(2026, 4, 19, 11));
    await add('knapp', DateTime.utc(2026, 4, 19, 10, 0, 29), DateTime.utc(2026, 4, 19, 11));
    await add('ganztägig', DateTime.utc(2026, 3, 25), DateTime.utc(2026, 3, 26), allDay: true);
    await add('mehrtägig', DateTime.utc(2026, 3, 27, 8), DateTime.utc(2026, 3, 29, 18));
    await add('täglich', DateTime.utc(2026, 3, 20, 5), DateTime.utc(2026, 3, 20, 6), recurrence: const Recurrence(frequency: Frequency.daily));
    await c.load();
    for (final t in <DateTime>[
      DateTime.utc(2026, 3, 20, 10, 0, 30),
      DateTime.utc(2026, 3, 20, 10, 0, 59),
      DateTime.utc(2026, 3, 20, 10, 1, 0),
      DateTime.utc(2026, 3, 20, 10, 30),
      DateTime.utc(2026, 3, 25, 23, 59, 59),
    ]) {
      now = t;
      for (final limit in <int>[5, 10, 100]) {
        expect(ids(c.upcoming(limit: limit)), ids(reference(t, limit: limit)), reason: '$t limit $limit');
      }
    }
  });

  test('Reihenfolge der Personen ändert den Schlüssel nicht; der Speicher ist auf 6 Fenster begrenzt', () async {
    await add('A', DateTime.utc(2026, 3, 21, 9), DateTime.utc(2026, 3, 21, 10));
    await c.load();
    final from = DateTime.utc(2026, 3, 1);
    final to = DateTime.utc(2026, 4, 1);
    final ab = c.occurrences(from, to, persons: <String>{'a', 'b'});
    expect(identical(c.occurrences(from, to, persons: <String>{'b', 'a'}), ab), isTrue);

    final first = c.occurrences(from, to);
    for (var i = 1; i <= 6; i++) {
      c.occurrences(from, to.add(Duration(days: i)));
    }
    expect(identical(c.occurrences(from, to), first), isFalse, reason: 'ältester Eintrag wurde verdrängt');
  });

  test('Sommerzeitwechsel: Vorkommen über den Wechsel gleich wie ohne Zwischenspeicher', () async {
    // Europe/Berlin: Sommerzeit ab 29.03.2026; täglicher Termin 09:00 Ortszeit.
    await add('täglich', DateTime.utc(2026, 3, 27, 8), DateTime.utc(2026, 3, 27, 9), recurrence: const Recurrence(frequency: Frequency.daily));
    await c.load();
    final from = DateTime.utc(2026, 3, 26);
    final to = DateTime.utc(2026, 4, 2);
    final list = c.occurrences(from, to);
    final direct = <Occurrence>[
      for (final e in c.events) ...OccurrenceExpander.expand(e, from: from, to: to, viewer: c.zone),
    ]..sort(CalendarView.compare);
    expect(ids(list), ids(direct));
    expect(list.map((o) => o.start.hour).toSet(), <int>{8, 7}, reason: '09:00 Ortszeit = 08:00 UTC vor, 07:00 UTC nach dem Wechsel');
  });
}
