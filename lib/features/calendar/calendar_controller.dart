import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/matrix/matrix_gateway.dart';
import '../../data/sync/calendar_sync.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_service.dart';
import '../../domain/calendar_view.dart';
import '../../domain/event_store.dart';
import '../../domain/occurrence.dart';
import '../../domain/recurrence.dart';
import '../../domain/time_zones.dart';
import '../../ui/theme/tokens.dart';

/// Zustand und Aktionen des Kalenders für die Oberfläche.
class CalendarController extends ChangeNotifier {
  CalendarController({
    required this.service,
    required this.store,
    required this.sync,
    required this.gateway,
    required String zoneName,
    DateTime Function()? clock,
  })  : zone = TimeZones.tryGet(zoneName) ?? TimeZones.utc,
        zoneName = TimeZones.tryGet(zoneName) == null ? 'UTC' : zoneName,
        _clock = clock ?? DateTime.now;

  final CalendarService service;
  final EventStore store;
  final CalendarSync sync;
  final MatrixGateway gateway;

  /// Zeitzone des Geräts (Betrachter).
  final tz.Location zone;
  final String zoneName;
  final DateTime Function() _clock;

  List<CalendarEvent> _events = const <CalendarEvent>[];
  Map<String, Map<String, RsvpStatus>> _rsvps = const <String, Map<String, RsvpStatus>>{};
  Map<String, int> _colors = const <String, int>{};
  Map<String, List<int>> _reminders = const <String, List<int>>{};
  bool _started = false;

  String get me => service.myUserId;
  DateTime get now => _clock();
  List<CalendarEvent> get events => _events;

  /// Heutiger lokaler Kalendertag in der Zeitzone des Geräts (als UTC-Datum).
  DateTime get today {
    final l = tz.TZDateTime.from(_clock().toUtc(), zone);
    return DateTime.utc(l.year, l.month, l.day);
  }

  /// Aktuelle lokale Uhrzeit (Stunde/Minute) in der Zeitzone des Geräts.
  tz.TZDateTime get localNow => tz.TZDateTime.from(_clock().toUtc(), zone);
  Map<String, List<int>> get reminders => _reminders;

  void start() {
    if (_started) return;
    _started = true;
    sync.onChanged = () => load().ignore();
    sync.start();
    load().ignore();
  }

  @override
  void dispose() {
    sync.onChanged = null;
    sync.dispose();
    super.dispose();
  }

  Future<void> load() async {
    _events = await store.all();
    _rsvps = await store.rsvps();
    _colors = await store.personColors();
    _reminders = await store.reminders();
    notifyListeners();
  }

  // ------------------------------------------------------------- Abfragen

  /// Vorkommen im Zeitraum [from, to) für die Ansicht; [persons] leer = alle.
  List<Occurrence> occurrences(DateTime from, DateTime to, {Set<String> persons = const <String>{}}) {
    final out = <Occurrence>[];
    for (final e in _events) {
      if (e.deleted || !CalendarView.matchesPerson(e, persons)) continue;
      out.addAll(OccurrenceExpander.expand(e, from: from, to: to, viewer: zone));
    }
    out.sort(CalendarView.compare);
    return out;
  }

  /// Kommende Vorkommen ab jetzt, begrenzt auf [limit].
  List<Occurrence> upcoming({int limit = 10, Duration window = const Duration(days: 30)}) {
    final n = _clock().toUtc();
    final list = occurrences(n, n.add(window)).where((o) => o.end.isAfter(n)).toList();
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  CalendarEvent? eventById(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  Map<String, RsvpStatus> rsvpsOf(String eventId) => _rsvps[eventId] ?? const <String, RsvpStatus>{};
  RsvpStatus? myRsvp(String eventId) => rsvpsOf(eventId)[me];

  /// Termine, die ich selbst abgesagt habe (keine Erinnerungen).
  Set<String> get declinedEventIds => <String>{
        for (final e in _rsvps.entries)
          if (e.value[me] == RsvpStatus.declined) e.key,
      };

  /// Anzeigefarbe: eigene Termine in der selbst gewählten Farbe, fremde in der
  /// Personenfarbe des Besitzers (ein Absender kann sich keine fremde Farbe geben).
  int displayColorIndex(CalendarEvent e) => e.ownerId == me ? e.colorIndex : colorIndexFor(e.ownerId);

  /// Anzeigename einer Person (Familie), sonst die Kennung.
  String nameOf(String userId) => userId == me ? me : (displayNameOf(userId) ?? userId);

  /// Anzeigename aus der Familie; `null`, wenn die Person nicht (mehr) Mitglied oder der Name unbekannt ist (#98).
  String? displayNameOf(String userId) {
    final name = gateway.family?.member(userId)?.displayName;
    return name == null || name.isEmpty ? null : name;
  }

  /// Neonfarbe (Palettenindex) einer Person: gespeichert oder aus der ID abgeleitet.
  int colorIndexFor(String userId) =>
      _colors[userId] ?? (userId.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff) % AuroraTokens.personColors.length);

  List<int> remindersOf(CalendarEvent e, List<int> defaults) => _reminders[e.id] ?? defaults;
  bool hasCustomReminders(String eventId) => _reminders.containsKey(eventId);

  Future<List<CalendarEvent>> history(String id) => store.history(id);

  // -------------------------------------------------------------- Aktionen

  Future<CalendarEvent> create({
    required String title,
    required DateTime start,
    required DateTime end,
    required EventVisibility visibility,
    bool allDay = false,
    String location = '',
    String note = '',
    int? colorIndex,
    Recurrence recurrence = Recurrence.none,
    List<String> attendees = const <String>[],
    List<int>? reminders,
    String? timeZone,
  }) async {
    final e = await service.create(
      title: title,
      start: start,
      end: end,
      timeZone: timeZone ?? zoneName,
      visibility: visibility,
      allDay: allDay,
      location: location,
      note: note,
      colorIndex: colorIndex ?? colorIndexFor(me),
      recurrence: recurrence,
      attendees: attendees,
      reminders: reminders,
    );
    await _changed();
    return e;
  }

  Future<CalendarEvent> update(
    CalendarEvent edited, {
    List<int>? reminders,
    bool resetReminders = false,
    EventVisibility? visibility,
  }) async {
    var target = edited;
    // Sichtbarkeitswechsel zuerst: Der bearbeitete Inhalt wird nie kurz in der alten
    // Sichtbarkeit gespeichert und veröffentlicht.
    if (visibility != null && visibility != edited.visibility) {
      final moved = await service.changeVisibility(edited.id, visibility);
      target = moved.copyWith(
        title: edited.title,
        start: edited.start,
        end: edited.end,
        timeZone: edited.timeZone,
        allDay: edited.allDay,
        location: edited.location,
        note: edited.note,
        colorIndex: edited.colorIndex,
        recurrence: edited.recurrence,
        attendees: moved.isShared ? edited.attendees : const <String>[],
      );
    }
    final e = await service.update(target);
    if (reminders != null) await store.setReminders(e.id, reminders);
    if (resetReminders) await store.setReminders(e.id, null);
    await _changed();
    return e;
  }

  Future<void> delete(String id) async {
    await service.delete(id);
    await _changed();
  }

  /// Nimmt ein einzelnes Vorkommen einer Serie aus (Ausnahme).
  Future<void> excludeOccurrence(CalendarEvent e, String dateKey) async {
    final r = e.recurrence;
    if (!r.isRecurring) return delete(e.id);
    await update(e.copyWith(recurrence: r.copyWith(exdates: <String>{...r.exdates, dateKey})));
  }

  Future<CalendarEvent> changeVisibility(String id, EventVisibility to) async {
    final e = await service.changeVisibility(id, to);
    await _changed();
    return e;
  }

  Future<void> setReminders(String eventId, List<int>? minutes) async {
    await store.setReminders(eventId, minutes);
    await _changed();
  }

  Future<void> respond(String eventId, RsvpStatus status) async {
    await sync.respond(eventId, status);
    await load();
  }

  Future<void> shareInChat(CalendarEvent e) => gateway.shareEventInChat(e);

  Future<void> _changed() async {
    await load();
    sync.kick();
  }
}
