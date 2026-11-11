import 'package:flutter/material.dart' show TimeOfDay;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/calendar_event.dart';

/// Beginn und Ende eines Termins im Termin-Editor (AP-6a): Datum und Uhrzeit getrennt, wie die Felder sie zeigen, samt
/// den Regeln, wie sich das Ende beim Ändern des Beginns und bei „Ganztägig“ verhält. Ohne Oberfläche und ohne
/// Zustand des Bildschirms; die Daten sind UTC-Daten (Jahr/Monat/Tag) und Wanduhrzeiten der Zeitzone des Geräts.
class EventTimes {
  EventTimes({
    required this.allDay,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.endTouched,
  });

  /// Werte eines bestehenden Termins. Das gespeicherte Ende gilt als gewählt; mehrtägige Termine werden nie verkürzt
  /// (#264). Ganztägige Termine zeigen die Standard-Uhrzeiten 9 und 10 Uhr, falls „Ganztägig“ ausgeschaltet wird.
  factory EventTimes.fromEvent(CalendarEvent e, tz.Location zone) {
    if (e.allDay) {
      return EventTimes(
        allDay: true,
        startDate: DateTime.utc(e.start.year, e.start.month, e.start.day),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endDate: DateTime.utc(e.end.year, e.end.month, e.end.day),
        endTime: const TimeOfDay(hour: 10, minute: 0),
        endTouched: true,
      );
    }
    final s = tz.TZDateTime.from(e.start, zone);
    final en = tz.TZDateTime.from(e.end, zone);
    return EventTimes(
      allDay: false,
      startDate: DateTime.utc(s.year, s.month, s.day),
      startTime: TimeOfDay(hour: s.hour, minute: s.minute),
      endDate: DateTime.utc(en.year, en.month, en.day),
      endTime: TimeOfDay(hour: en.hour, minute: en.minute),
      endTouched: true,
    );
  }

  /// Vorbelegung für einen neuen Termin: die nächste volle Stunde, eine Stunde lang, nie in der Vergangenheit. [base] ist
  /// der gewählte Tag oder heute, [nowHour] die Stunde der Ortszeit, [dayChosen] ob der Tag ausdrücklich gewählt wurde.
  /// Nach 23 Uhr beginnt der Termin um 00:00 des Folgetags, es sei denn, der Tag wurde gewählt.
  factory EventTimes.forNew({required DateTime base, required int nowHour, required bool dayChosen}) {
    var startDate = DateTime.utc(base.year, base.month, base.day);
    var endDate = startDate;
    final hour = (nowHour + 1) % 24;
    if (nowHour == 23 && !dayChosen) {
      startDate = DateTime.utc(base.year, base.month, base.day + 1);
      endDate = startDate;
    }
    if (hour == 23) endDate = DateTime.utc(startDate.year, startDate.month, startDate.day + 1);
    return EventTimes(
      allDay: false,
      startDate: startDate,
      startTime: TimeOfDay(hour: hour, minute: 0),
      endDate: endDate,
      endTime: TimeOfDay(hour: (hour + 1) % 24, minute: 0),
      endTouched: false,
    );
  }

  bool allDay;
  DateTime startDate; // UTC-Datum (Jahr/Monat/Tag)
  TimeOfDay startTime;
  DateTime endDate;
  TimeOfDay endTime;

  /// Ende von Hand gewählt (oder gespeichert): dann ändert „Ganztägig“ es nicht (#264).
  bool endTouched;

  /// Wanduhrzeit als UTC-Wert, nur zum Rechnen mit Differenzen.
  static DateTime _wall(DateTime date, TimeOfDay t) => DateTime.utc(date.year, date.month, date.day, t.hour, t.minute);

  /// Verschiebt den Beginn; das Ende wandert mit, die Dauer bleibt gleich (#34).
  void moveStart(DateTime date, TimeOfDay time) {
    var duration = _wall(endDate, endTime).difference(_wall(startDate, startTime));
    // Auch Ende = Beginn ergibt eine Stunde, sonst wanderte ein Termin ohne Dauer mit (#56).
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

  /// Das Ende wurde von Hand gewählt.
  void setEndDate(DateTime date) {
    endDate = date;
    endTouched = true;
  }

  void setEndTime(TimeOfDay time) {
    endTime = time;
    endTouched = true;
  }

  /// Schaltet „Ganztägig“ um. Ohne eigene Endwahl endet ein ganztägiger Termin am Tag des Beginns,
  /// auch wenn das Ende mit Uhrzeit auf 00:00 des Folgetags fiel (#264). Zurück zur Uhrzeit gilt
  /// wieder Ende = Beginn + 1 h (#56); sonst stünde 23:00–00:00 am selben Tag („Ende vor Beginn“).
  void setAllDay(bool v) {
    allDay = v;
    if (endTouched) return;
    if (v) {
      endDate = startDate;
    } else {
      moveStart(startDate, startTime);
    }
  }

  /// Beginn und Ende als UTC-Zeitpunkte: ganztägig die Tage selbst, sonst die Wanduhrzeiten in [zone].
  ({DateTime start, DateTime end}) range(tz.Location zone) {
    if (allDay) return (start: startDate, end: endDate);
    DateTime combine(DateTime date, TimeOfDay t) => tz.TZDateTime(zone, date.year, date.month, date.day, t.hour, t.minute).toUtc();
    return (start: combine(startDate, startTime), end: combine(endDate, endTime));
  }

  /// Liegt das Ende vor dem Beginn? Ganztägig ist der gleiche Tag erlaubt; mit Uhrzeit muss das Ende nach dem Beginn
  /// liegen (#56).
  bool endsBeforeStart(tz.Location zone) {
    final r = range(zone);
    return allDay ? r.end.isBefore(r.start) : !r.end.isAfter(r.start);
  }
}
