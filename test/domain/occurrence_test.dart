import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/occurrence.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/events.dart';

List<Occurrence> _x(CalendarEvent event, DateTime from, DateTime to, {tz.Location? viewer}) =>
    OccurrenceExpander.expand(event, from: from, to: to, viewer: viewer);

List<String> _keys(List<Occurrence> o) => o.map((e) => e.dateKey).toList();

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('einmalige Termine', () {
    test('im Fenster / außerhalb / Randfälle (Ende ist exklusiv)', () {
      final e = ev(h: 9); // 08:00Z–09:00Z am 20.03.2026 (MEZ)
      final s = e.start;
      expect(_x(e, s.subtract(const Duration(hours: 1)), s.add(const Duration(hours: 2))), hasLength(1));
      expect(_x(e, e.end, e.end.add(const Duration(days: 1))), isEmpty, reason: 'Fenster beginnt genau am Ende');
      expect(_x(e, s.subtract(const Duration(days: 1)), s), isEmpty, reason: 'Fenster endet genau am Beginn');
      expect(_x(e, s.add(const Duration(minutes: 30)), s.add(const Duration(minutes: 31))), hasLength(1));
    });

    test('mehrtägiger Termin, der vor dem Fenster begann, wird gefunden', () {
      final e = ev(length: const Duration(days: 3));
      expect(_x(e, e.start.add(const Duration(days: 2)), e.start.add(const Duration(days: 5))), hasLength(1));
    });

    test('gelöschte und Termine mit unbekannter Zeitzone liefern nichts', () {
      final e = ev();
      expect(_x(e.tombstone(DateTime.utc(2026)), DateTime.utc(2026), DateTime.utc(2027)), isEmpty);
      expect(_x(e.copyWith(timeZone: 'Mars/Olympus'), DateTime.utc(2026), DateTime.utc(2027)), isEmpty);
    });
  });

  group('täglich', () {
    test('Intervall und count', () {
      final e = ev(d: 1, recurrence: const Recurrence(frequency: Frequency.daily, interval: 2, count: 3));
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))), <String>['2026-03-01', '2026-03-03', '2026-03-05']);
    });

    test('Uhrzeit bleibt über die Sommerzeitumstellung gleich (09:00 Berlin)', () {
      final e = ev(d: 27, recurrence: const Recurrence(frequency: Frequency.daily, count: 4));
      final o = _x(e, DateTime.utc(2026, 3, 1), DateTime.utc(2026, 4, 30));
      expect(_keys(o), <String>['2026-03-27', '2026-03-28', '2026-03-29', '2026-03-30']);
      expect(o[0].start, DateTime.utc(2026, 3, 27, 8)); // MEZ = UTC+1
      expect(o[1].start, DateTime.utc(2026, 3, 28, 8));
      expect(o[2].start, DateTime.utc(2026, 3, 29, 7)); // MESZ = UTC+2
      expect(o[3].start, DateTime.utc(2026, 3, 30, 7));
    });

    test('Herbst: Rückstellung am 25.10.2026', () {
      final e = ev(mo: 10, d: 24, recurrence: const Recurrence(frequency: Frequency.daily, count: 3));
      final o = _x(e, DateTime.utc(2026, 10), DateTime.utc(2026, 11));
      expect(o[0].start, DateTime.utc(2026, 10, 24, 7));
      expect(o[2].start, DateTime.utc(2026, 10, 26, 8));
    });

    test('Termin in der Sommerzeit-Lücke (02:30 am 29.03.) rutscht, stürzt nicht ab', () {
      final e = ev(mo: 3, d: 28, h: 2, mi: 30, recurrence: const Recurrence(frequency: Frequency.daily, count: 3));
      final o = _x(e, DateTime.utc(2026, 3), DateTime.utc(2026, 4));
      expect(o, hasLength(3));
      expect(o[1].start.isAfter(o[0].start), isTrue);
      expect(o[1].start.difference(o[0].start).inHours, allOf(greaterThanOrEqualTo(22), lessThanOrEqualTo(25)));
    });
  });

  group('wöchentlich', () {
    test('Wochentag des Beginns', () {
      final e = ev(d: 2, recurrence: const Recurrence(frequency: Frequency.weekly, count: 3)); // Montag
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))), <String>['2026-03-02', '2026-03-09', '2026-03-16']);
    });

    test('mehrere Wochentage, Intervall 2', () {
      final e = ev(
        d: 2, // Montag
        recurrence: const Recurrence(frequency: Frequency.weekly, interval: 2, weekdays: <int>{1, 3}, count: 5),
      );
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))),
          <String>['2026-03-02', '2026-03-04', '2026-03-16', '2026-03-18', '2026-03-30']);
    });

    test('Wochentage vor dem Beginn in der ersten Woche entfallen', () {
      final e = ev(
        d: 4, // Mittwoch
        recurrence: const Recurrence(frequency: Frequency.weekly, weekdays: <int>{1, 3, 5}, count: 4),
      );
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))),
          <String>['2026-03-04', '2026-03-06', '2026-03-09', '2026-03-11']);
    });
  });

  group('monatlich / jährlich', () {
    test('31. springt auf Monatsende, kehrt zurück', () {
      final e = ev(mo: 1, d: 31, recurrence: const Recurrence(frequency: Frequency.monthly, count: 5));
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))),
          <String>['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31']);
    });

    test('Schaltjahr: 29.02. jährlich', () {
      final e = ev(y: 2024, mo: 2, d: 29, recurrence: const Recurrence(frequency: Frequency.yearly, count: 3));
      expect(_keys(_x(e, DateTime.utc(2024), DateTime.utc(2030))), <String>['2024-02-29', '2025-02-28', '2026-02-28']);
    });

    test('monatlich über den Jahreswechsel, Intervall 3', () {
      final e = ev(y: 2026, mo: 11, d: 15, recurrence: const Recurrence(frequency: Frequency.monthly, interval: 3, count: 3));
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2030))), <String>['2026-11-15', '2027-02-15', '2027-05-15']);
    });
  });

  group('Ende und Ausnahmen', () {
    test('until ist inklusive', () {
      final e = ev(d: 1, recurrence: Recurrence(frequency: Frequency.daily, until: DateTime.utc(2026, 3, 3)));
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))), <String>['2026-03-01', '2026-03-02', '2026-03-03']);
    });

    test('Ausnahmen entfernen Vorkommen, zählen aber für count mit', () {
      final e = ev(
        d: 1,
        recurrence: const Recurrence(frequency: Frequency.daily, count: 4, exdates: <String>{'2026-03-02'}),
      );
      expect(_keys(_x(e, DateTime.utc(2026), DateTime.utc(2027))), <String>['2026-03-01', '2026-03-03', '2026-03-04']);
    });

    test('Fenster schneidet Serie zu', () {
      final e = ev(d: 1, recurrence: const Recurrence(frequency: Frequency.daily));
      final o = _x(e, DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 13));
      expect(_keys(o), <String>['2026-03-10', '2026-03-11', '2026-03-12']);
    });

    test('endlose Serie, die Jahrzehnte zurückliegt, wird korrekt gefunden (Skip-Ahead)', () {
      final e = ev(y: 2001, mo: 1, d: 1, recurrence: const Recurrence(frequency: Frequency.daily));
      final o = _x(e, DateTime.utc(2060, 6, 10), DateTime.utc(2060, 6, 12));
      expect(_keys(o), <String>['2060-06-10', '2060-06-11']);
      final w = ev(y: 2001, mo: 1, d: 1, recurrence: const Recurrence(frequency: Frequency.weekly, interval: 3));
      final ow = _x(w, DateTime.utc(2050), DateTime.utc(2050, 3));
      for (final x in ow) {
        final days = DateTime.utc(int.parse(x.dateKey.substring(0, 4)), int.parse(x.dateKey.substring(5, 7)), int.parse(x.dateKey.substring(8)))
            .difference(DateTime.utc(2001))
            .inDays;
        expect(days % 21, 0, reason: x.dateKey);
      }
      expect(ow, isNotEmpty);
    });

    test('Skip-Ahead liefert dasselbe wie volle Aufzählung (monatlich/jährlich)', () {
      final m = ev(y: 2010, mo: 1, d: 31, recurrence: const Recurrence(frequency: Frequency.monthly, interval: 5));
      final full = _keys(_x(m, DateTime.utc(2010), DateTime.utc(2030)));
      final part = _keys(_x(m, DateTime.utc(2020), DateTime.utc(2030)));
      expect(part, full.where((k) => k.compareTo('2019-12') >= 0 && k.compareTo('2030') < 0).toList());
    });
  });

  group('ganztägig', () {
    test('mehrtägig, wiederholt, Betrachter-Zeitzone bestimmt die Grenzen', () {
      final e = ev(
        allDay: true,
        mo: 5,
        d: 1,
        allDayEnd: DateTime.utc(2026, 5, 2),
        recurrence: const Recurrence(frequency: Frequency.weekly, count: 2),
      );
      final utc = _x(e, DateTime.utc(2026, 4), DateTime.utc(2026, 6));
      expect(utc, hasLength(2));
      expect(utc[0].start, DateTime.utc(2026, 5, 1));
      expect(utc[0].end, DateTime.utc(2026, 5, 3));
      final ny = _x(e, DateTime.utc(2026, 4), DateTime.utc(2026, 6), viewer: tz.getLocation('America/New_York'));
      expect(ny[0].start, DateTime.utc(2026, 5, 1, 4)); // EDT = UTC-4
    });

    test('Ausnahme für ganztägigen Termin', () {
      final e = ev(
        allDay: true,
        mo: 5,
        d: 1,
        recurrence: const Recurrence(frequency: Frequency.daily, count: 3, exdates: <String>{'2026-05-02'}),
      );
      expect(_keys(_x(e, DateTime.utc(2026, 4), DateTime.utc(2026, 6))), <String>['2026-05-01', '2026-05-03']);
    });
  });

  group('Zeitzonen', () {
    test('Termin in New York wird in UTC korrekt abgebildet (Sommerzeit-Versatz)', () {
      final e = ev(zone: 'America/New_York', mo: 3, d: 7, h: 20, recurrence: const Recurrence(frequency: Frequency.daily, count: 3));
      final o = _x(e, DateTime.utc(2026, 3), DateTime.utc(2026, 4));
      expect(o[0].start, DateTime.utc(2026, 3, 8, 1)); // EST = UTC-5
      expect(o[2].start, DateTime.utc(2026, 3, 10, 0)); // 8.3. 02:00 Umstellung → EDT = UTC-4
      expect(o[1].start, DateTime.utc(2026, 3, 9, 0));
    });
  });
}
