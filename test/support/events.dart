import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:family_nexus/domain/time_zones.dart';

const String kOwner = '@anna:fake.test';
const String kOther = '@ben:fake.test';
const String kId1 = '11111111-1111-4111-8111-111111111111';
const String kId2 = '22222222-2222-4222-8222-222222222222';

/// Hilfsfunktion: Termin in einer Zeitzone mit lokaler Wanduhrzeit.
CalendarEvent ev({
  String id = kId1,
  String owner = kOwner,
  String zone = 'Europe/Berlin',
  int y = 2026,
  int mo = 3,
  int d = 20,
  int h = 9,
  int mi = 0,
  Duration length = const Duration(hours: 1),
  Recurrence recurrence = Recurrence.none,
  EventVisibility visibility = EventVisibility.shared,
  int version = 1,
  String title = 'Test',
  DateTime? updatedAt,
  bool allDay = false,
  DateTime? allDayEnd,
  List<String> attendees = const <String>[],
}) {
  TimeZones.ensureInitialized();
  final loc = tz.getLocation(zone);
  final DateTime start;
  final DateTime end;
  if (allDay) {
    start = DateTime.utc(y, mo, d);
    end = allDayEnd ?? start;
  } else {
    start = tz.TZDateTime(loc, y, mo, d, h, mi).toUtc();
    end = start.add(length);
  }
  return CalendarEvent(
    id: id,
    ownerId: owner,
    version: version,
    title: title,
    start: start,
    end: end,
    timeZone: zone,
    allDay: allDay,
    visibility: visibility,
    recurrence: recurrence,
    attendees: attendees,
    updatedAt: updatedAt ?? DateTime.utc(2026, 3, 1),
  );
}
