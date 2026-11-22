import 'package:uuid/uuid.dart';

import 'calendar_event.dart';
import 'conflict.dart';
import 'event_store.dart';
import 'family.dart';
import 'recurrence.dart';
import 'task_models.dart';

/// Fachlogik rund um Termine. Kennt nur den [EventStore]-Port – weder Matrix
/// noch Oberfläche.
class CalendarService {
  CalendarService({
    required this.store,
    required this.myUserId,
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.roleOf = _noRole,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final EventStore store;
  final String myUserId;

  /// Rolle eines Mitglieds in der aktuellen Familie (#431, E-112): `Role.moderator` oder `Role.member` für beigetretene
  /// Mitglieder, `null`, wenn Familie oder Mitglied (noch) unbekannt sind. Standard: niemand bekannt.
  final Role? Function(String userId) roleOf;
  static Role? _noRole(String _) => null;

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

  /// Rechte (E-10, E-112): Ändern darf der Besitzer und ein Moderator (nur geteilte Termine, nie gelöschte).
  /// Löschen und Sichtbarkeit wechseln darf nur der Besitzer ([canDelete], [canChangeVisibility]).
  bool canEdit(CalendarEvent e) =>
      !e.deleted && (isMine(e) || (e.isShared && roleOf(myUserId) == Role.moderator));

  bool canDelete(CalendarEvent e) => isMine(e) && !e.deleted;

  bool canChangeVisibility(CalendarEvent e) => isMine(e) && !e.deleted;

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
    String? themeId,
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
            themeId: themeId,
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
    String? themeId,
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
      // Nur geteilte Termine haben ein Thema (E-99).
      themeId: visibility == EventVisibility.shared ? themeId : null,
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
    if (!isMine(current)) return _updateAsModerator(edited, current);
    final next = edited.copyWith(
      version: current.version + 1,
      updatedAt: _now,
      visibility: current.visibility,
      // Ein privater Termin hat nie ein Thema (E-99); ein geteilter behält das gewählte.
      clearTheme: !current.isShared,
      // Eine Änderung des Besitzers ist keine Moderatorfassung mehr (E-112).
      clearEditor: true,
    );
    _check(next);
    await store.put(next, replaced: current);
    return next;
  }

  /// Änderung eines fremden geteilten Termins durch einen Moderator (E-112): Besitzer, Kennung und Sichtbarkeit bleiben
  /// die der gespeicherten Fassung, die Fassung trägt den Moderator als `editor`.
  Future<CalendarEvent> _updateAsModerator(CalendarEvent edited, CalendarEvent current) async {
    if (edited.ownerId != current.ownerId) throw const CalendarException(CalendarError.invalid);
    final next = edited.copyWith(
      version: current.version + 1,
      updatedAt: _now,
      visibility: current.visibility,
      editorId: myUserId,
    );
    _check(next);
    await store.put(next, replaced: current);
    return next;
  }

  Future<void> delete(String id) => _serial(() => _delete(id));

  Future<void> _delete(String id) async {
    final current = await store.get(id);
    if (current == null) throw const CalendarException(CalendarError.notFound);
    if (!canDelete(current)) throw const CalendarException(CalendarError.notAllowed);
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
    if (!canChangeVisibility(current)) throw const CalendarException(CalendarError.notAllowed);
    if (current.visibility == to) return current;
    final reminders = (await store.reminders())[id];
    if (to == EventVisibility.shared) {
      final shared = current.copyWith(visibility: to, version: current.version + 1, updatedAt: _now, clearEditor: true);
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

  /// Größter Versionssprung einer Fremdfassung (Moderator) über der gespeicherten Fassung (E-112).
  static const int maxForeignStep = 20;

  /// Grenzen des flüchtigen Puffers für noch nicht beurteilbare Fremdfassungen (E-112).
  static const int maxDeferredTotal = 50;
  static const int maxDeferredPerSender = 10;
  static const Duration deferredLifetime = Duration(days: 2);

  final Map<(String, String), _Deferred> _deferred = <(String, String), _Deferred>{};

  /// Anzahl gepufferter Fremdfassungen (Tests).
  int get deferredCount => _deferred.length;

  /// Gibt es gepufferte Fremdfassungen? (Der Sync stößt nur dann Wiederholungsläufe an.)
  bool get hasDeferred => _deferred.isNotEmpty;

  /// Rollenabbild der gepufferten Absender; ändert es sich, lohnt ein neuer Lauf ([retryDeferred]).
  String get deferredRoleState {
    final senders = _deferred.keys.map((k) => k.$2).toSet().toList()..sort();
    return senders.map((s) => '$s:${roleOf(s)?.name ?? '-'}').join('|');
  }

  /// Nimmt einen empfangenen Termin an (bereits dekodiert und validiert). [sender] ist der authentische Absender des
  /// Matrix-Ereignisses, [serverTime] dessen Serverzeit. Ein Absender, der nicht der Besitzer ist, darf nur eine
  /// Moderatorfassung eines bekannten, geteilten, nicht gelöschten Termins schicken (E-112); nie einen neuen Termin.
  Future<Resolution> applyFrom(CalendarEvent incoming, {required String sender, required DateTime? serverTime}) =>
      _serial(() async {
        final r = sender == incoming.ownerId
            ? await _applyIncoming(incoming)
            : await _applyForeign(incoming, sender: sender, serverTime: serverTime, hold: true);
        if (r == Resolution.insert || r == Resolution.replace) await _drainFor(incoming.id);
        return r;
      });

  /// Wie [applyFrom] für eine Fassung des Besitzers. Nur für Tests: `lib/` ruft sie nicht auf (Wächtertest `calendar_apply_guard_test`).
  Future<Resolution> applyIncoming(CalendarEvent incoming) =>
      applyFrom(incoming, sender: incoming.ownerId, serverTime: null);

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
    return _store(current, incoming);
  }

  Future<Resolution> _store(CalendarEvent? current, CalendarEvent incoming) async {
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
      case Resolution.deferred:
        break;
    }
    return r;
  }

  /// Fremdfassung eines Moderators (E-112). Prüft selbst, nicht nur der Codec: Absender = `editor`, geteilt, nicht gelöscht.
  Future<Resolution> _applyForeign(
    CalendarEvent incoming, {
    required String sender,
    required DateTime? serverTime,
    required bool hold,
  }) async {
    if (incoming.editorId != sender || incoming.deleted || !incoming.isShared) return Resolution.rejectOwner;
    final now = _now;
    if (serverTime == null ||
        serverTime.toUtc().isAfter(now.add(TaskLogEntry.maxSkew)) ||
        incoming.updatedAt.difference(serverTime.toUtc()).abs() > TaskLogEntry.maxSkew) {
      return Resolution.rejectOwner;
    }
    Resolution defer() {
      if (hold) _hold(incoming, sender, serverTime, now);
      return Resolution.deferred;
    }

    // Rolle: Moderator geprüft; Mitglied oder unbekannt kann ein veraltetes Familienbild sein (frisch befördert).
    if (roleOf(sender) != Role.moderator) return defer();
    final current = await store.get(incoming.id);
    if (current == null) return defer(); // Basis fehlt (Backfill: jüngste Seite zuerst)
    if (current.ownerId != incoming.ownerId || !current.isShared || current.deleted) return Resolution.rejectOwner;
    if (incoming.version > current.version + maxForeignStep) return defer();
    return _store(current, incoming);
  }

  void _hold(CalendarEvent e, String sender, DateTime serverTime, DateTime now) {
    final key = (e.id, sender);
    final old = _deferred[key];
    if (old != null && old.event.version >= e.version) return;
    _deferred[key] = _Deferred(e, sender, serverTime.toUtc(), now);
    // Grenzen: je Absender und gesamt. Es fällt der älteste Eintrag (nach lokaler Eingangszeit) des Absenders mit den
    // meisten Einträgen heraus; eine Flut verdrängt so zuerst die eigenen Einträge.
    int count(String s) => _deferred.keys.where((k) => k.$2 == s).length;
    void dropOldestOf(String s) {
      final keys = _deferred.entries.where((en) => en.key.$2 == s).toList()
        ..sort((a, b) => a.value.arrived.compareTo(b.value.arrived));
      _deferred.remove(keys.first.key);
    }

    while (count(sender) > maxDeferredPerSender) {
      dropOldestOf(sender);
    }
    while (_deferred.length > maxDeferredTotal) {
      final senders = _deferred.keys.map((k) => k.$2).toSet().toList()..sort();
      senders.sort((a, b) => count(b).compareTo(count(a)));
      dropOldestOf(senders.first);
    }
  }

  void _purgeDeferred() {
    final limit = _now.subtract(deferredLifetime);
    _deferred.removeWhere((_, v) => v.arrived.isBefore(limit));
  }

  /// Prüft die gepufferten Fassungen eines Termins nach der Annahme einer neuen Basis (in [_serial]).
  Future<void> _drainFor(String eventId) async {
    if (_deferred.isEmpty) return;
    await _drain(_deferred.keys.where((k) => k.$1 == eventId).toSet());
  }

  /// Läuft aufsteigend nach Version bis zum Fixpunkt (ein Durchlauf ohne Annahme). Jede Annahme entfernt einen Eintrag,
  /// der Lauf endet deshalb nach höchstens [maxDeferredTotal] Durchläufen. `true`, wenn etwas angenommen wurde.
  Future<bool> _drain(Set<(String, String)> keys) async {
    var any = false;
    for (var pass = 0; pass <= maxDeferredTotal; pass++) {
      final ready = keys.where(_deferred.containsKey).toList()
        ..sort((a, b) => _deferred[a]!.event.version.compareTo(_deferred[b]!.event.version));
      var accepted = false;
      for (final k in ready) {
        final d = _deferred[k];
        if (d == null) continue;
        final r = await _applyForeign(d.event, sender: d.sender, serverTime: d.serverTime, hold: false);
        if (r == Resolution.deferred) continue;
        _deferred.remove(k);
        if (r == Resolution.replace) accepted = true;
      }
      if (!accepted) break;
      any = true;
    }
    return any;
  }

  /// Wiederholungslauf über alle gepufferten Fassungen (Rollen-, Familien- oder Bestandsänderung, neues Mitglied).
  /// `true`, wenn mindestens eine angenommen wurde (der Kalender lädt dann neu).
  Future<bool> retryDeferred() => _serial(() async {
        _purgeDeferred();
        if (_deferred.isEmpty) return false;
        return _drain(_deferred.keys.toSet());
      });

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

class _Deferred {
  _Deferred(this.event, this.sender, this.serverTime, this.arrived);
  final CalendarEvent event;
  final String sender;
  final DateTime serverTime;

  /// Lokale Eingangszeit: nach ihr richten sich Verfall und Verdrängung, nicht nach der `serverTime` des Absenders.
  final DateTime arrived;
}
