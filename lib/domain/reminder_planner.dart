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
  }) {
    final loc = viewer ?? TimeZones.utc;
    final nowUtc = now.toUtc();
    final to = nowUtc.add(window).add(const Duration(minutes: maxMinutes));
    final out = <PlannedReminder>[];
    for (final e in events) {
      if (e.deleted || skip.contains(e.id)) continue;
      final minutes = (personal[e.id] ?? defaults).where((m) => m >= 0 && m <= maxMinutes).toSet();
      if (minutes.isEmpty) continue;
      for (final o in OccurrenceExpander.expand(e, from: nowUtc, to: to, viewer: loc)) {
        // Ganztägig: Bezugszeit ist 09:00 Ortszeit des ersten Tages.
        final base = e.allDay
            ? () {
                final l = tz.TZDateTime.from(o.start, loc);
                return tz.TZDateTime(loc, l.year, l.month, l.day, allDayHour).toUtc();
              }()
            : o.start;
        for (final m in minutes) {
          final fire = base.subtract(Duration(minutes: m));
          if (fire.isAfter(nowUtc) && fire.isBefore(nowUtc.add(window))) {
            out.add(PlannedReminder(
              id: stableId(e.id, base, m),
              fireAt: fire,
              eventId: e.id,
              occurrenceStart: base,
              minutesBefore: m,
            ));
          }
        }
      }
    }
    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return out.length > limit ? out.sublist(0, limit) : out;
  }
}
