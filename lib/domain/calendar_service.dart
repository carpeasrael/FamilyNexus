import 'package:uuid/uuid.dart';

import 'calendar_event.dart';
import 'conflict.dart';
import 'event_store.dart';
import 'recurrence.dart';

/// Fachlogik rund um Termine. Kennt nur den [EventStore]-Port – weder Matrix
/// noch Oberfläche.
class CalendarService {
  CalendarService({
    required this.store,
    required this.myUserId,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final EventStore store;
  final String myUserId;
  final DateTime Function() _clock;
  final String Function() _newId;

  DateTime get _now => _clock().toUtc();

  /// Höchstzahl fremder Termine je Absender (Schutz vor Speicher-Aufblähung).
  static const int maxEventsPerSender = 2000;

  // Alle schreibenden Abläufe laufen nacheinander (Eingänge, lokale Änderungen).
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  bool isMine(CalendarEvent e) => e.ownerId == myUserId;

  /// Rechte: Termine ändern/löschen darf nur der Besitzer (E-10).
  bool canEdit(CalendarEvent e) => isMine(e) && !e.deleted;

  /// Legt einen neuen eigenen Termin an. Bei [visibility] = geteilt wird er
  /// später veröffentlicht, bei privat nur in den eigenen privaten Raum.
  Future<CalendarEvent> create({
    required String title,
    required DateTime start,
    required DateTime end,
    required String timeZone,
    required EventVisibility visibility,
    bool allDay = false,
    String location = '',
    String note = '',
    int colorIndex = 0,
    Recurrence recurrence = Recurrence.none,
    List<String> attendees = const <String>[],
    List<int>? reminders,
  }) =>
      _serial(() => _create(
            title: title,
            start: start,
            end: end,
            timeZone: timeZone,
            visibility: visibility,
            allDay: allDay,
            location: location,
            note: note,
            colorIndex: colorIndex,
            recurrence: recurrence,
            attendees: attendees,
            reminders: reminders,
          ));

  Future<CalendarEvent> _create({
    required String title,
    required DateTime start,
    required DateTime end,
    required String timeZone,
    required EventVisibility visibility,
    bool allDay = false,
    String location = '',
    String note = '',
    int colorIndex = 0,
    Recurrence recurrence = Recurrence.none,
    List<String> attendees = const <String>[],
    List<int>? reminders,
  }) async {
    final e = CalendarEvent(
      id: _newId(),
      ownerId: myUserId,
      title: title.trim(),
      start: start.toUtc(),
      end: end.toUtc(),
      timeZone: timeZone,
      allDay: allDay,
      location: location,
      note: note,
      colorIndex: colorIndex,
      visibility: visibility,
      recurrence: recurrence,
      attendees: attendees,
      updatedAt: _now,
    );
    _check(e);
    await store.put(e, publishedVersion: 0);
    if (reminders != null) await store.setReminders(e.id, reminders);
    return e;
  }

  /// Speichert eine Änderung: Version +1, `updatedAt` neu. Die Sichtbarkeit
  /// ändert sich hier nie (siehe [changeVisibility]).
  Future<CalendarEvent> update(CalendarEvent edited) => _serial(() => _update(edited));

  Future<CalendarEvent> _update(CalendarEvent edited) async {
    final current = await store.get(edited.id);
    if (current == null || !canEdit(current)) throw const CalendarException(CalendarError.notAllowed);
    final next = edited.copyWith(
      version: current.version + 1,
      updatedAt: _now,
      visibility: current.visibility,
    );
    _check(next);
    await store.put(next, replaced: current);
    return next;
  }

  Future<void> delete(String id) => _serial(() => _delete(id));

  Future<void> _delete(String id) async {
    final current = await store.get(id);
    if (current == null) throw const CalendarException(CalendarError.notFound);
    if (!canEdit(current)) throw const CalendarException(CalendarError.notAllowed);
    await store.put(current.tombstone(_now), replaced: current);
    await store.setReminders(id, null);
  }

  /// Wechselt die Sichtbarkeit.
  ///
  /// * privat → geteilt: dieselbe ID, neue Version; wird in den Familienraum gesendet.
  /// * geteilt → privat: Der geteilte Termin wird für alle als gelöscht markiert,
  ///   der private Termin ist eine **Kopie mit neuer ID**. Bereits zugestellte
  ///   Inhalte bleiben auf Geräten, die sie empfangen haben (nicht erzwingbar).
  Future<CalendarEvent> changeVisibility(String id, EventVisibility to) => _serial(() => _changeVisibility(id, to));

  Future<CalendarEvent> _changeVisibility(String id, EventVisibility to) async {
    final current = await store.get(id);
    if (current == null) throw const CalendarException(CalendarError.notFound);
    if (!canEdit(current)) throw const CalendarException(CalendarError.notAllowed);
    if (current.visibility == to) return current;
    final reminders = (await store.reminders())[id];
    if (to == EventVisibility.shared) {
      final shared = current.copyWith(visibility: to, version: current.version + 1, updatedAt: _now);
      _check(shared);
      await store.put(shared, replaced: current, publishedVersion: 0);
      return shared;
    }
    final copy = CalendarEvent(
      id: _newId(),
      ownerId: myUserId,
      title: current.title,
      start: current.start,
      end: current.end,
      timeZone: current.timeZone,
      allDay: current.allDay,
      location: current.location,
      note: current.note,
      colorIndex: current.colorIndex,
      visibility: EventVisibility.private,
      recurrence: current.recurrence,
      attendees: const <String>[],
      updatedAt: _now,
    );
    await store.put(current.tombstone(_now), replaced: current);
    await store.put(copy, publishedVersion: 0);
    if (reminders != null) await store.setReminders(copy.id, reminders);
    await store.setReminders(id, null);
    return copy;
  }

  /// Nimmt einen empfangenen Termin an (bereits dekodiert und validiert).
  Future<Resolution> applyIncoming(CalendarEvent incoming) => _serial(() => _applyIncoming(incoming));

  Future<Resolution> _applyIncoming(CalendarEvent incoming) async {
    final current = await store.get(incoming.id);
    if (current != null && current.visibility != incoming.visibility) {
      // Erlaubt ist nur der Übergang privat → geteilt durch den Besitzer mit höherer Version
      // (eigenes anderes Gerät); alles andere ist eine Fälschung/Unstimmigkeit.
      final ok = current.visibility == EventVisibility.private &&
          incoming.visibility == EventVisibility.shared &&
          incoming.ownerId == current.ownerId &&
          incoming.version > current.version;
      if (!ok) return Resolution.rejectOwner;
    }
    if (current == null && incoming.ownerId != myUserId && await store.countOwnedBy(incoming.ownerId) >= maxEventsPerSender) {
      return Resolution.rejectOwner;
    }
    final r = ConflictResolver.resolve(current, incoming);
    switch (r) {
      case Resolution.insert:
        await store.put(incoming, publishedVersion: incoming.version);
      case Resolution.replace:
        await store.put(incoming, replaced: current, publishedVersion: incoming.version);
      case Resolution.ignoreStale:
        // Für den Verlauf merken, nicht als aktuelle Fassung.
        await store.addHistory(incoming);
      case Resolution.ignoreDuplicate:
      case Resolution.rejectOwner:
        break;
    }
    return r;
  }

  void _check(CalendarEvent e) {
    if (e.validate().isNotEmpty) throw const CalendarException(CalendarError.invalid);
  }
}

enum CalendarError { invalid, notAllowed, notFound }

class CalendarException implements Exception {
  const CalendarException(this.error);
  final CalendarError error;

  @override
  String toString() => 'CalendarException(${error.name})';
}
