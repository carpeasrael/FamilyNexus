import 'dart:math';

import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/event_times.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// AP-6a: Beginn und Ende des Termin-Editors ohne Widget. Die Zeitregeln (#34, #56, #264) wurden aus dem State
/// herausgelöst; ein Wertvergleich gegen eine unveränderte Kopie des alten Verhaltens stellt sicher, dass dabei nichts
/// anders rechnet.

/// Referenz: die Felder und Methoden des Editors im Stand vor der Auslagerung, unverändert kopiert.
class _Ref {
  _Ref({
    required this.allDay,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.endTouched,
    required this.zone,
  });

  /// Wie `initState` für einen bestehenden Termin.
  factory _Ref.existing(CalendarEvent e, tz.Location zone) {
    late bool allDay;
    late DateTime startDate;
    late TimeOfDay startTime;
    late DateTime endDate;
    late TimeOfDay endTime;
    allDay = e.allDay;
    if (e.allDay) {
      startDate = DateTime.utc(e.start.year, e.start.month, e.start.day);
      endDate = DateTime.utc(e.end.year, e.end.month, e.end.day);
      startTime = const TimeOfDay(hour: 9, minute: 0);
      endTime = const TimeOfDay(hour: 10, minute: 0);
    } else {
      final s = tz.TZDateTime.from(e.start, zone);
      final en = tz.TZDateTime.from(e.end, zone);
      startDate = DateTime.utc(s.year, s.month, s.day);
      endDate = DateTime.utc(en.year, en.month, en.day);
      startTime = TimeOfDay(hour: s.hour, minute: s.minute);
      endTime = TimeOfDay(hour: en.hour, minute: en.minute);
    }
    return _Ref(allDay: allDay, startDate: startDate, startTime: startTime, endDate: endDate, endTime: endTime, endTouched: true, zone: zone);
  }

  /// Wie `initState` für einen neuen Termin ([hourNow]: Stunde der Ortszeit).
  factory _Ref.fresh(DateTime base, int hourNow, DateTime? initialDay, tz.Location zone) {
    final n = hourNow;
    var startDate = DateTime.utc(base.year, base.month, base.day);
    var endDate = startDate;
    final hour = (n + 1) % 24;
    if (n == 23 && initialDay == null) {
      startDate = DateTime.utc(base.year, base.month, base.day + 1);
      endDate = startDate;
    }
    final startTime = TimeOfDay(hour: hour, minute: 0);
    final endTime = TimeOfDay(hour: (hour + 1) % 24, minute: 0);
    if (hour == 23) endDate = DateTime.utc(startDate.year, startDate.month, startDate.day + 1);
    return _Ref(allDay: false, startDate: startDate, startTime: startTime, endDate: endDate, endTime: endTime, endTouched: false, zone: zone);
  }

  bool allDay;
  DateTime startDate;
  TimeOfDay startTime;
  DateTime endDate;
  TimeOfDay endTime;
  bool endTouched;
  final tz.Location zone;

  static DateTime _wall(DateTime date, TimeOfDay t) => DateTime.utc(date.year, date.month, date.day, t.hour, t.minute);

  void moveStart(DateTime date, TimeOfDay time) {
    var duration = _wall(endDate, endTime).difference(_wall(startDate, startTime));
    if (duration <= Duration.zero) duration = const Duration(hours: 1);
    if (allDay) {
      final days = endDate.difference(startDate).inDays;
      startDate = date;
      endDate = DateTime.utc(date.year, date.month, date.day + (days < 0 ? 0 : days));
      return;
    }
    final end = _wall(date, time).add(duration);
    startDate = date;
    startTime = time;
    endDate = DateTime.utc(end.year, end.month, end.day);
    endTime = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  void setAllDay(bool v) {
    allDay = v;
    if (endTouched) return;
    if (v) {
      endDate = startDate;
    } else {
      moveStart(startDate, startTime);
    }
  }

  DateTime combine(DateTime date, TimeOfDay t) => tz.TZDateTime(zone, date.year, date.month, date.day, t.hour, t.minute).toUtc();

  /// Wie `_save`: Beginn, Ende und die Prüfung „Ende vor Beginn“.
  (DateTime, DateTime, bool) save() {
    final DateTime start;
    final DateTime end;
    if (allDay) {
      start = startDate;
      end = endDate;
    } else {
      start = combine(startDate, startTime);
      end = combine(endDate, endTime);
    }
    return (start, end, allDay ? end.isBefore(start) : !end.isAfter(start));
  }
}

void _same(EventTimes t, _Ref r, String reason) {
  expect(
    (t.allDay, t.startDate, t.startTime, t.endDate, t.endTime, t.endTouched).toString(),
    (r.allDay, r.startDate, r.startTime, r.endDate, r.endTime, r.endTouched).toString(),
    reason: reason,
  );
  final range = t.range(r.zone);
  final (start, end, bad) = r.save();
  expect((range.start, range.end, t.endsBeforeStart(r.zone)), (start, end, bad), reason: '$reason (Speichern)');
}

CalendarEvent _event({required DateTime start, required DateTime end, bool allDay = false}) => CalendarEvent(
      id: 'e',
      ownerId: '@a:x',
      title: 't',
      start: start,
      end: end,
      timeZone: 'Europe/Berlin',
      updatedAt: DateTime.utc(2026, 1, 1),
      allDay: allDay,
    );

void main() {
  TimeZones.ensureInitialized();
  final berlin = TimeZones.tryGet('Europe/Berlin')!;

  group('Vorbelegung', () {
    test('neuer Termin: nächste volle Stunde, eine Stunde lang, für jede Stunde wie vorher', () {
      for (var h = 0; h < 24; h++) {
        for (final chosen in <bool>[false, true]) {
          final base = DateTime.utc(2026, 3, 20);
          final t = EventTimes.forNew(base: base, nowHour: h, dayChosen: chosen);
          _same(t, _Ref.fresh(base, h, chosen ? base : null, berlin), 'Stunde $h, Tag gewählt: $chosen');
        }
      }
    });

    test('neuer Termin nach 23 Uhr ohne gewählten Tag beginnt um 00:00 des Folgetags; mit gewähltem Tag bleibt der Tag', () {
      final base = DateTime.utc(2026, 3, 31);
      final open = EventTimes.forNew(base: base, nowHour: 23, dayChosen: false);
      expect((open.startDate, open.startTime), (DateTime.utc(2026, 4, 1), const TimeOfDay(hour: 0, minute: 0)));
      final chosen = EventTimes.forNew(base: base, nowHour: 23, dayChosen: true);
      expect((chosen.startDate, chosen.startTime), (DateTime.utc(2026, 3, 31), const TimeOfDay(hour: 0, minute: 0)));
      expect(chosen.endTouched, isFalse);
    });

    test('neuer Termin um 22 Uhr: 23:00 bis 00:00 des Folgetags', () {
      final t = EventTimes.forNew(base: DateTime.utc(2026, 3, 20), nowHour: 22, dayChosen: false);
      expect((t.startTime, t.endTime, t.endDate), (const TimeOfDay(hour: 23, minute: 0), const TimeOfDay(hour: 0, minute: 0), DateTime.utc(2026, 3, 21)));
    });

    test('bestehender Termin mit Uhrzeit: Wanduhrzeit der Zone, Ende gilt als gewählt', () {
      final e = _event(start: DateTime.utc(2026, 3, 20, 9, 30), end: DateTime.utc(2026, 3, 20, 10, 45)); // 10:30 und 11:45 in Berlin
      final t = EventTimes.fromEvent(e, berlin);
      expect((t.startTime, t.endTime, t.endTouched, t.allDay), (const TimeOfDay(hour: 10, minute: 30), const TimeOfDay(hour: 11, minute: 45), true, false));
      _same(t, _Ref.existing(e, berlin), 'bestehend');
    });

    test('bestehender ganztägiger Termin: Tage unverändert, Standard-Uhrzeiten 9 und 10', () {
      final e = _event(start: DateTime.utc(2026, 3, 20), end: DateTime.utc(2026, 3, 22), allDay: true);
      final t = EventTimes.fromEvent(e, berlin);
      expect((t.startDate, t.endDate, t.startTime, t.endTime, t.allDay), (DateTime.utc(2026, 3, 20), DateTime.utc(2026, 3, 22), const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 10, minute: 0), true));
      _same(t, _Ref.existing(e, berlin), 'ganztägig');
    });

    test('Zeitumstellung: Mitternacht in Berlin liegt im UTC-Vortag, der Tag bleibt der Berliner', () {
      final e = _event(start: DateTime.utc(2026, 3, 28, 23), end: DateTime.utc(2026, 3, 29, 0, 30)); // 00:00 und 01:30 am 29.3.
      final t = EventTimes.fromEvent(e, berlin);
      expect(t.startDate, DateTime.utc(2026, 3, 29));
      _same(t, _Ref.existing(e, berlin), 'Umstellung');
    });
  });

  group('Regeln (#34, #56, #264)', () {
    EventTimes timed() => EventTimes(
          allDay: false,
          startDate: DateTime.utc(2026, 3, 20),
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endDate: DateTime.utc(2026, 3, 20),
          endTime: const TimeOfDay(hour: 11, minute: 30),
          endTouched: false,
        );

    test('Beginn verschieben: das Ende wandert mit, die Dauer bleibt (#34)', () {
      final t = timed()..moveStart(DateTime.utc(2026, 3, 21), const TimeOfDay(hour: 14, minute: 0));
      expect((t.endDate, t.endTime), (DateTime.utc(2026, 3, 21), const TimeOfDay(hour: 15, minute: 30)));
    });

    test('Ende = Beginn ergibt beim Verschieben eine Stunde (#56)', () {
      final t = timed()..endTime = const TimeOfDay(hour: 10, minute: 0);
      t.moveStart(DateTime.utc(2026, 3, 20), const TimeOfDay(hour: 12, minute: 0));
      expect(t.endTime, const TimeOfDay(hour: 13, minute: 0));
    });

    test('über Mitternacht: Ende am Folgetag', () {
      final t = timed()..moveStart(DateTime.utc(2026, 3, 20), const TimeOfDay(hour: 23, minute: 0));
      expect((t.endDate, t.endTime), (DateTime.utc(2026, 3, 21), const TimeOfDay(hour: 0, minute: 30)));
    });

    test('Ganztägig an ohne eigene Endwahl: Ende am Tag des Beginns (#264)', () {
      final t = timed()..endDate = DateTime.utc(2026, 3, 21);
      t.setAllDay(true);
      expect(t.endDate, t.startDate);
    });

    test('Ganztägig an und wieder aus: 23:00 bis 00:00 des Folgetags bleibt gültig (#56, #264)', () {
      final t = EventTimes(
        allDay: false,
        startDate: DateTime.utc(2026, 3, 20),
        startTime: const TimeOfDay(hour: 23, minute: 0),
        endDate: DateTime.utc(2026, 3, 21),
        endTime: const TimeOfDay(hour: 0, minute: 0),
        endTouched: false,
      );
      t.setAllDay(true);
      expect(t.endDate, DateTime.utc(2026, 3, 20), reason: 'ganztägig endet am Tag des Beginns');
      t.setAllDay(false);
      expect((t.endDate, t.endTime), (DateTime.utc(2026, 3, 21), const TimeOfDay(hour: 0, minute: 0)), reason: 'zurück: Beginn + 1 Stunde');
      expect(t.endsBeforeStart(berlin), isFalse);
    });

    test('Ende selbst gewählt: Ganztägig behält das Enddatum', () {
      final t = timed()..setEndDate(DateTime.utc(2026, 3, 25));
      t.setAllDay(true);
      expect((t.endDate, t.endTouched), (DateTime.utc(2026, 3, 25), true));
    });

    test('Ende-Uhrzeit von Hand gewählt zählt als gewählt', () {
      final t = timed()..setEndTime(const TimeOfDay(hour: 18, minute: 0));
      expect((t.endTime, t.endTouched), (const TimeOfDay(hour: 18, minute: 0), true));
    });

    test('ganztägig: Beginn verschieben behält die Zahl der Tage, nie negativ', () {
      final t = EventTimes(
        allDay: true,
        startDate: DateTime.utc(2026, 3, 20),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endDate: DateTime.utc(2026, 3, 22),
        endTime: const TimeOfDay(hour: 10, minute: 0),
        endTouched: true,
      )..moveStart(DateTime.utc(2026, 4, 1), const TimeOfDay(hour: 9, minute: 0));
      expect((t.startDate, t.endDate), (DateTime.utc(2026, 4, 1), DateTime.utc(2026, 4, 3)));
      t.endDate = DateTime.utc(2026, 3, 1); // Ende vor Beginn
      t.moveStart(DateTime.utc(2026, 4, 10), const TimeOfDay(hour: 9, minute: 0));
      expect(t.endDate, DateTime.utc(2026, 4, 10));
    });

    test('Ende vor Beginn: mit Uhrzeit auch bei Gleichheit, ganztägig nur davor', () {
      final t = timed()..endTime = const TimeOfDay(hour: 10, minute: 0);
      expect(t.endsBeforeStart(berlin), isTrue, reason: 'Ende = Beginn mit Uhrzeit');
      t.endTime = const TimeOfDay(hour: 10, minute: 1);
      expect(t.endsBeforeStart(berlin), isFalse);
      t.allDay = true;
      t.endDate = t.startDate;
      expect(t.endsBeforeStart(berlin), isFalse, reason: 'ganztägig am selben Tag');
      t.endDate = DateTime.utc(2026, 3, 19);
      expect(t.endsBeforeStart(berlin), isTrue);
    });
  });

  group('Wertvergleich gegen das alte Verhalten', () {
    test('zufällige Folgen von Änderungen ergeben in jedem Schritt dieselben Werte', () {
      final rnd = Random(264);
      final starts = <CalendarEvent>[
        _event(start: DateTime.utc(2026, 3, 20, 9), end: DateTime.utc(2026, 3, 20, 10)),
        _event(start: DateTime.utc(2026, 3, 28, 21), end: DateTime.utc(2026, 3, 29, 2)),
        _event(start: DateTime.utc(2026, 10, 24, 20), end: DateTime.utc(2026, 10, 25, 5)),
        _event(start: DateTime.utc(2026, 3, 20), end: DateTime.utc(2026, 3, 20), allDay: true),
        _event(start: DateTime.utc(2026, 3, 20), end: DateTime.utc(2026, 3, 24), allDay: true),
      ];
      var steps = 0;
      for (var run = 0; run < 300; run++) {
        final base = DateTime.utc(2026, 1 + rnd.nextInt(12), 1 + rnd.nextInt(28));
        final EventTimes t;
        final _Ref r;
        if (run % 3 == 0) {
          final e = starts[rnd.nextInt(starts.length)];
          t = EventTimes.fromEvent(e, berlin);
          r = _Ref.existing(e, berlin);
        } else {
          final h = rnd.nextInt(24);
          final chosen = rnd.nextBool();
          t = EventTimes.forNew(base: base, nowHour: h, dayChosen: chosen);
          r = _Ref.fresh(base, h, chosen ? base : null, berlin);
        }
        _same(t, r, 'Lauf $run: Anfang');
        for (var step = 0; step < 12; step++) {
          switch (rnd.nextInt(4)) {
            case 0:
              final d = DateTime.utc(2026, 1 + rnd.nextInt(12), 1 + rnd.nextInt(28));
              final time = TimeOfDay(hour: rnd.nextInt(24), minute: rnd.nextInt(60));
              t.moveStart(d, time);
              r.moveStart(d, time);
            case 1:
              final on = rnd.nextBool();
              t.setAllDay(on);
              r.setAllDay(on);
            case 2:
              final d = DateTime.utc(2026, 1 + rnd.nextInt(12), 1 + rnd.nextInt(28));
              t.setEndDate(d);
              r
                ..endDate = d
                ..endTouched = true;
            default:
              final time = TimeOfDay(hour: rnd.nextInt(24), minute: rnd.nextInt(60));
              t.setEndTime(time);
              r
                ..endTime = time
                ..endTouched = true;
          }
          steps++;
          _same(t, r, 'Lauf $run, Schritt $step');
        }
      }
      expect(steps, 300 * 12);
    });
  });
}
