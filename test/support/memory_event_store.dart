import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_store.dart';

class MemoryEventStore implements EventStore {
  final Map<String, CalendarEvent> events = <String, CalendarEvent>{};
  final Map<String, List<CalendarEvent>> _history = <String, List<CalendarEvent>>{};
  final Map<String, int> _published = <String, int>{};
  final Map<String, List<int>> _reminders = <String, List<int>>{};
  final Map<String, Map<String, ({RsvpStatus status, DateTime ts, bool published})>> _rsvps =
      <String, Map<String, ({RsvpStatus status, DateTime ts, bool published})>>{};
  final Map<String, int> _colors = <String, int>{};

  @override
  Future<CalendarEvent?> get(String id) async => events[id];

  @override
  Future<List<CalendarEvent>> all() async => events.values.toList();

  @override
  Future<void> put(CalendarEvent event, {CalendarEvent? replaced, int? publishedVersion}) async {
    if (replaced != null && replaced != event) await addHistory(replaced);
    events[event.id] = event;
    if (publishedVersion != null) _published[event.id] = publishedVersion;
  }

  @override
  Future<void> addHistory(CalendarEvent event) async {
    final list = _history.putIfAbsent(event.id, () => <CalendarEvent>[]);
    if (!list.contains(event)) list.insert(0, event);
    while (list.length > EventStore.maxHistoryPerEvent) {
      list.removeLast();
    }
  }

  @override
  Future<int> countOwnedBy(String owner) async => events.values.where((e) => e.ownerId == owner).length;

  @override
  Future<void> requeueOwnShared(String owner) async {
    for (final e in events.values) {
      if (e.ownerId == owner && e.isShared && !e.deleted) _published[e.id] = 0;
    }
    for (final byUser in _rsvps.values) {
      final cur = byUser[owner];
      if (cur != null) byUser[owner] = (status: cur.status, ts: cur.ts, published: false);
    }
  }

  @override
  Future<List<CalendarEvent>> history(String id) async => List<CalendarEvent>.of(_history[id] ?? const <CalendarEvent>[]);

  @override
  Future<List<CalendarEvent>> pendingPublish() async => events.values
      .where((e) => e.version > (_published[e.id] ?? 0))
      .toList();

  @override
  Future<void> markPublished(String id, int version) async {
    if (version > (_published[id] ?? 0)) _published[id] = version;
  }

  @override
  Future<Map<String, List<int>>> reminders() async => Map<String, List<int>>.of(_reminders);

  @override
  Future<void> setReminders(String eventId, List<int>? minutes) async {
    if (minutes == null) {
      _reminders.remove(eventId);
    } else {
      _reminders[eventId] = List<int>.of(minutes);
    }
  }

  @override
  Future<Map<String, Map<String, RsvpStatus>>> rsvps() async => <String, Map<String, RsvpStatus>>{
        for (final e in _rsvps.entries) e.key: <String, RsvpStatus>{for (final x in e.value.entries) x.key: x.value.status},
      };

  @override
  Future<void> putRsvp(String eventId, String userId, RsvpStatus status, DateTime timestamp, {bool published = true}) async {
    final m = _rsvps.putIfAbsent(eventId, () => <String, ({RsvpStatus status, DateTime ts, bool published})>{});
    final cur = m[userId];
    if (cur == null || timestamp.isAfter(cur.ts)) m[userId] = (status: status, ts: timestamp, published: published);
  }

  @override
  Future<List<({String eventId, RsvpStatus status, DateTime timestamp})>> pendingRsvps(String userId) async => [
        for (final e in _rsvps.entries)
          if (e.value[userId] != null && !e.value[userId]!.published)
            (eventId: e.key, status: e.value[userId]!.status, timestamp: e.value[userId]!.ts),
      ];

  @override
  Future<void> markRsvpPublished(String eventId, String userId, DateTime timestamp) async {
    final cur = _rsvps[eventId]?[userId];
    if (cur != null && cur.ts == timestamp) _rsvps[eventId]![userId] = (status: cur.status, ts: cur.ts, published: true);
  }

  @override
  Future<Map<String, int>> personColors() async => Map<String, int>.of(_colors);

  @override
  Future<void> setPersonColor(String userId, int colorIndex) async => _colors[userId] = colorIndex;

  @override
  Future<void> wipe() async {
    events.clear();
    _history.clear();
    _published.clear();
    _reminders.clear();
    _rsvps.clear();
    _colors.clear();
  }
}
