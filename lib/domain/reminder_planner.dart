import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';
import 'occurrence.dart';
import 'time_zones.dart';

/// Eine geplante lokale Erinnerung.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.fireAt,
    required this.eventId,
    required this.occurrenceStart,
    required this.minutesBefore,
  });

  /// Stabile positive 31-Bit-ID (gleiche Eingabe → gleiche ID).
  final int id;
  final DateTime fireAt;
  final String eventId;
  final DateTime occurrenceStart;
  final int minutesBefore;
}

/// Plant lokale Erinnerungen. Enthält bewusst **keine** Termininhalte: Das
/// Ergebnis trägt nur IDs und Zeiten, damit nichts davon in Benachrichtigungen
/// oder deren Plattformablage gelangt (E-15).
class ReminderPlanner {
  const ReminderPlanner._();

  static const Duration horizon = Duration(days: 60);
  static const int maxPlanned = 100;
  static const int maxMinutes = 60 * 24 * 60;

  static int stableId(String eventId, DateTime occurrenceStart, int minutes) {
    // FNV-1a 32 Bit
    var h = 0x811c9dc5;
    for (final u in '$eventId|${occurrenceStart.millisecondsSinceEpoch}|$minutes'.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  /// Uhrzeit, auf die sich Erinnerungen ganztägiger Termine beziehen (lokal).
  static const int allDayHour = 9;

  /// [personal]: eigene Erinnerungen je Termin (fehlt der Eintrag → [defaults]).
  /// [skip]: Termin-IDs ohne Erinnerung (z. B. selbst abgesagte).
  /// [viewer]: Zeitzone des Geräts; ganztägige Termine beziehen sich auf [allDayHour] Uhr dieses Tages.
  static List<PlannedReminder> plan({
    required Iterable<CalendarEvent> events,
    required Map<String, List<int>> personal,
    required List<int> defaults,
    required DateTime now,
    Duration window = horizon,
    int limit = maxPlanned,
    Set<String> skip = const <String>{},
    tz.Location? viewer,
  }) =>
      <PlannedReminder>[
        for (final e in upcoming(
          events: events,
          personal: personal,
          defaults: defaults,
          now: now,
          window: window,
          limit: limit,
          skip: skip,
          viewer: viewer,
        ))
          e.reminder,
      ];

  /// Wie [plan], aber mit dem Vorkommen je Erinnerung; nur für die Anzeige in der App (#218).
  static List<ReminderEntry> upcoming({
    required Iterable<CalendarEvent> events,
    required Map<String, List<int>> personal,
    required List<int> defaults,
    required DateTime now,
    Duration window = horizon,
    int limit = maxPlanned,
    Set<String> skip = const <String>{},
    tz.Location? viewer,
  }) {
    final nowUtc = now.toUtc();
    final to = nowUtc.add(window).add(const Duration(minutes: maxMinutes));
    final out = <ReminderEntry>[
      for (final r in _collect(events, personal, defaults, nowUtc, to, skip, viewer ?? TimeZones.utc))
        if (r.reminder.fireAt.isAfter(nowUtc) && r.reminder.fireAt.isBefore(nowUtc.add(window))) r,
    ]..sort((a, b) => a.reminder.fireAt.compareTo(b.reminder.fireAt));
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  /// Höchstzahl fälliger Erinnerungen in der Übersicht.
  static const int maxDue = 50;

  /// Ausgelöste Erinnerungen (Auslösezeit erreicht), deren Vorkommen noch nicht vorbei ist, ohne die IDs in
  /// [acknowledged]; jüngste zuerst (#218). Bestätigte fallen vor der Grenze weg, sonst verdeckten sie ältere.
  static List<ReminderEntry> due({
    required Iterable<CalendarEvent> events,
    required Map<String, List<int>> personal,
    required List<int> defaults,
    required DateTime now,
    Set<int> acknowledged = const <int>{},
    int limit = maxDue,
    Set<String> skip = const <String>{},
    tz.Location? viewer,
  }) {
    final nowUtc = now.toUtc();
    // Ein Vorkommen mit fälliger Erinnerung beginnt höchstens [maxMinutes] nach jetzt.
    final to = nowUtc.add(const Duration(minutes: maxMinutes + 1));
    final out = <ReminderEntry>[
      for (final r in _collect(events, personal, defaults, nowUtc, to, skip, viewer ?? TimeZones.utc))
        if (!r.reminder.fireAt.isAfter(nowUtc) && r.occurrence.end.isAfter(nowUtc) && !acknowledged.contains(r.reminder.id)) r,
    ]..sort((a, b) {
        final c = b.reminder.fireAt.compareTo(a.reminder.fireAt);
        return c != 0 ? c : a.reminder.id.compareTo(b.reminder.id);
      });
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  /// Alle Erinnerungen der Vorkommen, die [from]–[to] berühren, mit stabiler ID wie in der Benachrichtigung.
  static Iterable<ReminderEntry> _collect(
    Iterable<CalendarEvent> events,
    Map<String, List<int>> personal,
    List<int> defaults,
    DateTime from,
    DateTime to,
    Set<String> skip,
    tz.Location loc,
  ) sync* {
    for (final e in events) {
      if (e.deleted || skip.contains(e.id)) continue;
      final minutes = (personal[e.id] ?? defaults).where((m) => m >= 0 && m <= maxMinutes).toSet();
      if (minutes.isEmpty) continue;
      for (final o in OccurrenceExpander.expand(e, from: from, to: to, viewer: loc)) {
        // Ganztägig: Bezugszeit ist 09:00 Ortszeit des ersten Tages.
        final base = e.allDay
            ? () {
                final l = tz.TZDateTime.from(o.start, loc);
                return tz.TZDateTime(loc, l.year, l.month, l.day, allDayHour).toUtc();
              }()
            : o.start;
        for (final m in minutes) {
          yield ReminderEntry(
            PlannedReminder(
              id: stableId(e.id, base, m),
              fireAt: base.subtract(Duration(minutes: m)),
              eventId: e.id,
              occurrenceStart: base,
              minutesBefore: m,
            ),
            o,
          );
        }
      }
    }
  }
}

/// Erinnerung mit ihrem Vorkommen. Nur für die Oberfläche; an den Scheduler geht nur [reminder] (E-15).
class ReminderEntry {
  const ReminderEntry(this.reminder, this.occurrence);
  final PlannedReminder reminder;
  final Occurrence occurrence;
}
