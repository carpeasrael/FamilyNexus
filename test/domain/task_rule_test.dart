import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

// Erwartete Daten unabhängig mit Python (datetime/calendar) nachgerechnet; 24.10.2026 ist ein Samstag.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Issue #1: Perioden je Wiederholungsregel (Schlüssel = Startdatum)', () {
    test('täglich, alle Wochentage: wie bisher (gleicher Schlüssel, Format v1)', () {
      const r = TaskRule.everyDay();
      expect(r.isLegacy, isTrue);
      expect(r.keyForDate('2026-10-24'), '2026-10-24');
      expect(r.keyForDate('2026-10-25'), '2026-10-25');
    });

    test('Montag bis Freitag: am Wochenende keine Erneuerung, Samstag/Sonntag gehören zum Freitag', () {
      const r = TaskRule.weekdays();
      expect(r.isLegacy, isFalse);
      expect(r.keyForDate('2026-10-23'), '2026-10-23'); // Freitag
      expect(r.keyForDate('2026-10-24'), '2026-10-23'); // Samstag
      expect(r.keyForDate('2026-10-25'), '2026-10-23'); // Sonntag
      expect(r.keyForDate('2026-10-26'), '2026-10-26'); // Montag
    });

    test('wöchentlich am Mittwoch: Periode Mittwoch bis Dienstag', () {
      const r = TaskRule.weekly(DateTime.wednesday);
      expect(r.keyForDate('2026-10-21'), '2026-10-21');
      expect(r.keyForDate('2026-10-24'), '2026-10-21');
      expect(r.keyForDate('2026-10-20'), '2026-10-14');
    });

    test('wöchentlich am Montag entspricht dem bisherigen Intervall (ISO-Woche)', () {
      const r = TaskRule.weekly(DateTime.monday);
      expect(r.isLegacy, isTrue);
      expect(r.keyForDate('2026-10-24'), '2026-W43');
    });

    test('monatlich am zweiten Dienstag und am letzten Freitag', () {
      const second = TaskRule.monthlyByWeekday(2, DateTime.tuesday);
      expect(second.keyForDate('2026-10-13'), '2026-10-13');
      expect(second.keyForDate('2026-10-24'), '2026-10-13');
      expect(second.keyForDate('2026-10-12'), '2026-09-08');
      const lastFriday = TaskRule.monthlyByWeekday(TaskRule.last, DateTime.friday);
      expect(lastFriday.keyForDate('2026-10-24'), '2026-09-25');
      expect(lastFriday.keyForDate('2026-10-30'), '2026-10-30');
      expect(lastFriday.keyForDate('2026-10-31'), '2026-10-30');
    });

    test('monatlich am 20.', () {
      const r = TaskRule.monthlyByDate(20);
      expect(r.keyForDate('2026-10-20'), '2026-10-20');
      expect(r.keyForDate('2026-10-24'), '2026-10-20');
      expect(r.keyForDate('2026-10-19'), '2026-09-20');
      expect(r.keyForDate('2027-01-05'), '2026-12-20', reason: 'über den Jahreswechsel');
    });

    test('Klärungspunkt: am 31. – in kürzeren Monaten am letzten Kalendertag (auch Februar, Schaltjahr)', () {
      const r = TaskRule.monthlyByDate(31);
      expect(r.keyForDate('2026-11-30'), '2026-11-30');
      expect(r.keyForDate('2026-12-05'), '2026-11-30');
      expect(r.keyForDate('2026-12-31'), '2026-12-31');
      expect(r.keyForDate('2027-02-28'), '2027-02-28');
      expect(r.keyForDate('2027-03-01'), '2027-02-28');
      expect(r.keyForDate('2027-03-31'), '2027-03-31');
      expect(r.keyForDate('2028-02-29'), '2028-02-29');
      expect(r.keyForDate('2028-02-28'), '2028-01-31');
    });

    test('monatlich am 1. entspricht dem bisherigen Intervall (Monatsschlüssel)', () {
      const r = TaskRule.monthlyByDate(1);
      expect(r.isLegacy, isTrue);
      expect(r.keyForDate('2026-10-24'), '2026-10');
    });

    test('nächster Neustart', () {
      expect(const TaskRule.weekdays().nextStartAfter(DateTime.utc(2026, 10, 23)), DateTime.utc(2026, 10, 26));
      expect(const TaskRule.monthlyByWeekday(2, DateTime.tuesday).nextStartAfter(DateTime.utc(2026, 10, 13)), DateTime.utc(2026, 11, 10));
      expect(const TaskRule.monthlyByDate(31).nextStartAfter(DateTime.utc(2026, 11, 5)), DateTime.utc(2026, 11, 30));
      expect(const TaskRule.weekly(DateTime.sunday).nextStartAfter(DateTime.utc(2026, 10, 24)), DateTime.utc(2026, 10, 25));
    });

    test('Startdatum liegt nie nach dem Tag und höchstens 35 Tage davor (alle Regeln, 2026–2030)', () {
      final rules = <TaskRule>[
        const TaskRule.everyDay(),
        const TaskRule.weekdays(),
        for (var w = 1; w <= 7; w++) TaskRule.weekly(w),
        for (var o = 1; o <= TaskRule.last; o++)
          for (var w = 1; w <= 7; w++) TaskRule.monthlyByWeekday(o, w),
        for (var d = 1; d <= 31; d++) TaskRule.monthlyByDate(d),
      ];
      for (final r in rules) {
        for (var day = DateTime.utc(2026); day.isBefore(DateTime.utc(2031)); day = day.add(const Duration(days: 1))) {
          final start = r.startOf(day);
          final diff = day.difference(start).inDays;
          expect(diff >= 0 && diff < TaskRule.maxPeriodDays, isTrue, reason: '$r $day → $start');
          expect(r.startOf(start), start, reason: 'Start ist selbst ein Erneuerungstag: $r $start');
        }
      }
    });
  });

  group('Regel im Ereignis (nicht vertrauenswürdig)', () {
    test('Roundtrip aller Arten', () {
      for (final r in <TaskRule>[
        const TaskRule.everyDay(),
        const TaskRule.weekdays(),
        const TaskRule.weekly(DateTime.sunday),
        const TaskRule.monthlyByWeekday(TaskRule.last, DateTime.friday),
        const TaskRule.monthlyByDate(31),
      ]) {
        expect(TaskRule.fromJson(r.toJson()), r);
      }
    });

    test('ungültige Regeln werden verworfen', () {
      for (final bad in <Object?>[
        null,
        'weekly',
        <String, Object?>{'kind': 'yearly'},
        <String, Object?>{'kind': 'weekly'},
        <String, Object?>{'kind': 'weekly', 'weekday': 0},
        <String, Object?>{'kind': 'weekly', 'weekday': 8},
        <String, Object?>{'kind': 'weekly', 'weekday': '3'},
        <String, Object?>{'kind': 'monthlyByWeekday', 'weekday': 2, 'ordinal': 6},
        <String, Object?>{'kind': 'monthlyByWeekday', 'weekday': 2, 'ordinal': 0},
        <String, Object?>{'kind': 'monthlyByDate', 'day': 32},
        <String, Object?>{'kind': 'monthlyByDate', 'day': 0},
        <String, Object?>{'kind': 'monthlyByDate', 'day': 5, 'weekday': 1},
        <String, Object?>{'kind': 'everyDay', 'day': 1},
        <String, Object?>{'kind': 'everyDay', 'extra': true},
      ]) {
        expect(TaskRule.fromJson(bad), isNull, reason: '$bad');
      }
    });
  });
}
