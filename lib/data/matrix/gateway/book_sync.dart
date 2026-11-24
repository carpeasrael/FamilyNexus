part of '../sdk_matrix_gateway.dart';

/// Zeitleisten, Signale, Historie, Backfill und Senden der Buch-Räume (#311, E-113). Alles hier ist gesperrt, solange
/// `cashBooksEnabled` `false` ist: keine Zeitleiste, kein Signal, kein Speicherzugriff, keine Warnung, `notAllowed`.
/// Steht in der Mixin-Liste **vor** `_BooksModule`, damit dessen Umsetzungen die abstrakten Deklarationen hier ersetzen.
mixin _BookSyncModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  bool get _cashBooksEnabled;
  bool get _requireEncryptionForBooks;
  bool get _syncedOnce;
  bool get _participantsLoaded;
  bool get _disposed;
  FamilyScope get _scope;
  GatewayException _map(Object e);
  void _scheduleRefresh();
  void _warnPlaintext(Event e);
  Room _bookRoom(String roomId, {required Membership membership});
  bool _isBookOfCurrentFamily(Room room);
  String? _creatorOf(Room room);
  Future<List<User>> _freshParticipants(Room room, List<Membership> filter);

  /// Obergrenze je Buch: 10 Mitglieder × 3000 Einträge (`CashBookLimits`) plus Meta. Darüber fällt der älteste Eintrag
  /// heraus und der Verlauf gilt in dieser Sitzung nie als vollständig.
  static const int maxBookEntries = CashBookLimits.maxMembersPerBook * CashBookLimits.maxEntriesPerAuthor;
  static const int maxBookBackfillPages = 200;
  static const int maxBookSendBatch = 50;
  static const int maxBookEventBytes = 16 * 1024;

  final Map<String, Timeline> _bookTimelines = <String, Timeline>{};
  final Set<String> _bookDirty = <String>{};
  final Map<String, Set<String>> _bookSignaled = <String, Set<String>>{};
  final Map<String, BookSignal> _bookMeta = <String, BookSignal>{};
  final Map<String, Map<(String, String), BookSignal>> _bookEntries = <String, Map<(String, String), BookSignal>>{};
  final Set<String> _bookComplete = <String>{};
  final Set<String> _bookTruncated = <String>{};
  final Set<String> _bookBackfilling = <String>{};
  final Set<String> _bookCapped = <String>{};
  final Map<String, int> _bookUndecryptable = <String, int>{};
  final Map<String, Set<String>> _bookJoinedBase = <String, Set<String>>{};
  final Set<String> _bookBaselining = <String>{};
  final StreamController<BookSignal> _bookSignalController = StreamController<BookSignal>.broadcast();

  @override
  Stream<BookSignal> get bookSignals => Stream<BookSignal>.multi((controller) {
        if (_cashBooksEnabled) {
          for (final room in _bookMeta.keys.toSet().union(_bookEntries.keys.toSet())) {
            final meta = _bookMeta[room];
            if (meta != null) controller.add(meta);
            final entries = _bookEntries[room];
            if (entries != null) {
              for (final s in entries.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp))) {
                controller.add(s);
              }
            }
          }
        }
        final sub = _bookSignalController.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });

  @override
  bool bookHistoryComplete(String roomId) =>
      _cashBooksEnabled && _bookComplete.contains(roomId) && !_bookTruncated.contains(roomId);

  @override
  int bookUndecryptableCount(String roomId) => _cashBooksEnabled ? (_bookUndecryptable[roomId] ?? 0) : 0;

  @override
  bool bookRoomGone(String roomId) {
    final client = _client;
    if (!_cashBooksEnabled || client == null || !client.isLogged() || !_syncedOnce || _family == null) return false;
    final room = client.getRoomById(roomId);
    return room == null || (room.membership != Membership.join && room.membership != Membership.invite);
  }

  @override
  Future<Set<String>> bookKnownMembers(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    if (!_isBookOfCurrentFamily(room)) throw const GatewayException(GatewayError.notAllowed);
    try {
      const known = <Membership>[Membership.join, Membership.leave, Membership.invite, Membership.ban];
      final users = await _freshParticipants(room, known);
      return <String>{
        for (final u in users)
          if (known.contains(u.membership)) u.id,
      };
    } catch (e) {
      if (e is GatewayException) rethrow;
      throw _map(e);
    }
  }

  @override
  Future<List<BookMember>> bookMembers(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    if (!_isBookOfCurrentFamily(room)) throw const GatewayException(GatewayError.notAllowed);
    try {
      final users = await _freshParticipants(room, const <Membership>[Membership.join, Membership.invite]);
      return <BookMember>[
        for (final u in users)
          if (u.membership == Membership.join)
            BookMember(u.id, BookMembership.joined)
          else if (u.membership == Membership.invite)
            BookMember(u.id, BookMembership.invited),
      ];
    } catch (e) {
      if (e is GatewayException) rethrow;
      throw _map(e);
    }
  }

  @override
  List<String> get staleBooks {
    final client = _client;
    final family = _family;
    if (!_cashBooksEnabled || client == null || !client.isLogged() || family == null || !_syncedOnce || !_participantsLoaded) {
      return const <String>[];
    }
    // Nur ein **vorhandener** Familienvermerk, der von der aktuellen Familie abweicht, macht ein Buch zum alten: Ein
    // Buch-Raum ohne Vermerk wird nie verlassen (die Aktion ist nicht umkehrbar).
    bool other(Room r) {
      final content = r.getState(EventTypes.RoomCreate)?.content;
      if (!BookRoomMarker.isBook(content)) return false;
      final f = content?[BookRoomMarker.familyKey];
      return f is String && f != family.roomId;
    }

    return <String>[
      for (final r in client.rooms)
        if (r.membership == Membership.join && other(r)) r.id,
    ];
  }

  @override
  Future<List<BookSendResult>> publishBookEvents(String roomId, List<BookOutgoing> events) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    final client = _client!;
    if (_family == null || !_isBookOfCurrentFamily(room)) throw const GatewayException(GatewayError.notAllowed);
    if (events.length > maxBookSendBatch) throw const GatewayException(GatewayError.invalidInput);
    if (events.isEmpty) return const <BookSendResult>[];
    if (_requireEncryptionForBooks && (!client.encryptionEnabled || room.encryptionAlgorithm != FamilyRoomSpec.megolm)) {
      throw const GatewayException(GatewayError.encryptionUnavailable);
    }
    // Sendeschutz: Fremde im Raum (oder keine belastbare Mitgliederliste) → nichts wird gesendet.
    try {
      await verifyBookRecipients(roomId);
    } on GatewayException catch (e) {
      final r = e.error == GatewayError.notAllowed ? BookSendResult.blocked : BookSendResult.failed;
      return List<BookSendResult>.filled(events.length, r);
    }
    final me = client.userID!;
    final results = List<BookSendResult>.filled(events.length, BookSendResult.failed);
    var stop = false;
    for (var i = 0; i < events.length; i++) {
      final ev = events[i];
      if (!_mayPublish(ev, me: me, creator: _creatorOf(room))) {
        results[i] = BookSendResult.invalid;
        continue;
      }
      if (stop) continue;
      try {
        final id = await room.sendEvent(ev.content, type: ev.type).timeout(SdkMatrixGateway.roomOpTimeout);
        if (id == null) {
          stop = true;
        } else {
          results[i] = BookSendResult.sent;
        }
      } catch (e) {
        AppLog.w('gateway', 'Buch-Ereignis nicht gesendet: ${e.runtimeType}');
        stop = true;
      }
    }
    return results;
  }

  /// Eigener Typ, eigener Autor, Größe: nur eigene Einträge, `bookmeta` nur vom Ersteller.
  static bool _mayPublish(BookOutgoing ev, {required String me, required String? creator}) {
    if (ev.type == CashBookCodec.entryType) {
      if (ev.content['author'] != me) return false;
    } else if (ev.type == CashBookCodec.metaType) {
      if (creator != me) return false;
    } else {
      return false;
    }
    try {
      return jsonEncode(ev.content).length <= maxBookEventBytes;
    } catch (_) {
      // Nicht kodierbarer Inhalt ist nicht sendbar.
      return false;
    }
  }

  // ------------------------------------------------------------- Zeitleisten

  /// Im Abgleich nach dem Familienraum: legt je Buch eine Zeitleiste an, baut die nicht mehr beigetretenen ab, liest
  /// geänderte Zeitleisten ein und erkennt neue Mitglieder. Ein Fehler hier überspringt nie den Familienabgleich.
  Future<void> _syncBookTimelines(Client client) async {
    if (!_cashBooksEnabled || !_syncedOnce) return;
    try {
      final generation = _scope.generation;
      final current = <String, BookRoomInfo>{for (final b in books) b.roomId: b};
      for (final id in _bookTimelines.keys.toList()) {
        if (!current.containsKey(id)) _teardownBook(id);
      }
      for (final b in current.values) {
        if (_bookTimelines.containsKey(b.roomId)) continue;
        final room = client.getRoomById(b.roomId);
        if (room == null) continue;
        final id = b.roomId;
        final t = await room.getTimeline(
          onUpdate: () => _markBookDirty(id),
          onInsert: (_) => _markBookDirty(id),
          onChange: (_) => _markBookDirty(id),
          onNewEvent: () => _markBookDirty(id),
        );
        if (_disposed || _client != client || generation != _scope.generation || !books.any((x) => x.roomId == id)) {
          t.cancelSubscriptions();
          continue;
        }
        _bookTimelines[id] = t;
        _bookDirty.add(id);
        _baselineBookMembers(room, generation).ignore();
      }
      for (final entry in _bookTimelines.entries.toList()) {
        final id = entry.key;
        final info = current[id];
        if (info == null) continue;
        if (_bookDirty.remove(id)) _ingestBookEvents(id, info.creatorId, entry.value.events.reversed);
        if (!_bookComplete.contains(id) && !_bookCapped.contains(id) && !_bookBackfilling.contains(id)) {
          _backfillBook(id, entry.value, generation).ignore();
        }
        _emitBookJoins(client.getRoomById(id), id, client.userID);
      }
    } catch (e) {
      AppLog.e('gateway', 'Buch-Zeitleisten konnten nicht abgeglichen werden', e);
    }
  }

  void _markBookDirty(String roomId) {
    if (_disposed) return;
    _bookDirty.add(roomId);
    _scheduleRefresh();
  }

  bool _bookTimelineCurrent(String roomId, Timeline t, int generation) =>
      !_disposed && identical(_bookTimelines[roomId], t) && generation == _scope.generation;

  /// Lädt ältere Ereignisse nach (höchstens [maxBookBackfillPages] Seiten). Vollständig gilt der Verlauf erst, wenn das
  /// SDK keine weitere Seite mehr anbietet; nach der Obergrenze bleibt er unvollständig und wird nicht erneut versucht.
  Future<void> _backfillBook(String roomId, Timeline t, int generation) async {
    if (!_bookBackfilling.add(roomId)) return;
    try {
      var pages = 0;
      var stalled = false;
      while (t.canRequestHistory && pages < maxBookBackfillPages) {
        if (!_bookTimelineCurrent(roomId, t, generation)) return;
        final before = t.events.length;
        await t.requestHistory();
        pages++;
        // Eine Seite ohne neue Ereignisse: Der Server kennt nichts Älteres mehr (kein Fehler, sonst wäre er geworfen).
        if (t.events.length == before) {
          stalled = true;
          break;
        }
      }
      if (!_bookTimelineCurrent(roomId, t, generation)) return;
      if (t.canRequestHistory && !stalled) {
        _bookCapped.add(roomId);
      } else {
        _bookComplete.add(roomId);
      }
      _markBookDirty(roomId);
    } catch (e) {
      AppLog.e('gateway', 'Verlauf des Buchs konnte nicht nachgeladen werden', e);
    } finally {
      _bookBackfilling.remove(roomId);
    }
  }

  /// Liest Ereignisse (älteste zuerst) eines Buchs ein. Gemeinsamer Weg von Abgleich und Test.
  void _ingestBookEvents(String roomId, String creatorId, Iterable<Event> events) {
    if (!_cashBooksEnabled) return;
    final seen = _bookSignaled.putIfAbsent(roomId, () => <String>{});
    var undecrypted = 0;
    for (final e in events) {
      final r = BookSignalScan.scan(e, roomId: roomId, creatorId: creatorId);
      switch (r.outcome) {
        case BookScanOutcome.ignored:
          break;
        case BookScanOutcome.undecrypted:
          undecrypted++;
        case BookScanOutcome.plaintext:
          _warnPlaintext(e);
        case BookScanOutcome.signal:
          if (seen.add(e.eventId)) _acceptBookSignal(r.signal!);
      }
    }
    _bookUndecryptable[roomId] = undecrypted;
  }

  static int? _versionOf(Map<String, Object?> c) {
    final v = c['version'];
    return v is int ? v : null;
  }

  /// Hält je Raum das `bookmeta` mit der höchsten Version und je (Absender, `id`) den Eintrag mit der höchsten Version
  /// und gibt neue Stände an den Strom.
  void _acceptBookSignal(BookSignal s) {
    final version = _versionOf(s.content);
    if (s.kind == BookSignalKind.meta) {
      final old = _bookMeta[s.roomId];
      final oldVersion = old == null ? null : _versionOf(old.content);
      if (old != null && (version == null || (oldVersion != null && version < oldVersion))) return;
      _bookMeta[s.roomId] = s;
    } else {
      final id = s.content['id'];
      if (id is String && version != null) {
        final map = _bookEntries.putIfAbsent(s.roomId, () => <(String, String), BookSignal>{});
        final key = (s.sender, id);
        final old = map[key];
        final oldVersion = old == null ? null : _versionOf(old.content);
        if (old != null && oldVersion != null && version < oldVersion) return;
        map[key] = s;
        if (map.length > maxBookEntries) {
          map.remove(map.keys.first);
          _bookTruncated.add(s.roomId);
        }
      }
    }
    _bookSignalController.add(s);
  }

  /// Basisstand der beigetretenen Mitglieder eines Buchs (einmal je Raum und Sitzung, vom Server).
  Future<void> _baselineBookMembers(Room room, int generation) async {
    final id = room.id;
    if (_bookJoinedBase.containsKey(id) || !_bookBaselining.add(id)) return;
    try {
      final users = await _freshParticipants(room, const <Membership>[Membership.join]);
      if (_disposed || generation != _scope.generation || !_bookTimelines.containsKey(id)) return;
      _bookJoinedBase[id] = <String>{for (final u in users) u.id};
    } catch (e) {
      AppLog.w('gateway', 'Mitglieder des Buchs nicht geladen: ${e.runtimeType}');
    } finally {
      _bookBaselining.remove(id);
    }
  }

  /// Jeder spätere Beitritt eines anderen Nutzers löst `memberJoined` aus (Resync). Nur im Livestrom, nie in der
  /// Historie; Beitritte bei geschlossener App erkennt der Basisstand nicht (Grenze, E-113).
  void _emitBookJoins(Room? room, String roomId, String? me) {
    final base = _bookJoinedBase[roomId];
    if (room == null || base == null) return;
    final now = <String>{
      for (final u in room.getParticipants())
        if (u.membership == Membership.join) u.id,
    };
    for (final id in now.difference(base)) {
      base.add(id);
      if (id == me) continue;
      _bookSignalController.add(BookSignal(
        roomId: roomId,
        creatorId: _creatorOf(room) ?? '',
        kind: BookSignalKind.memberJoined,
        sender: id,
        timestamp: DateTime.now().toUtc(),
      ));
    }
  }

  void _teardownBook(String roomId) {
    _bookTimelines.remove(roomId)?.cancelSubscriptions();
    _bookDirty.remove(roomId);
    _bookSignaled.remove(roomId);
    _bookMeta.remove(roomId);
    _bookEntries.remove(roomId);
    _bookComplete.remove(roomId);
    _bookTruncated.remove(roomId);
    _bookCapped.remove(roomId);
    _bookUndecryptable.remove(roomId);
    _bookJoinedBase.remove(roomId);
  }

  /// Abmelden und Familienwechsel: alles vergessen. (Der Strom bleibt offen; er wird erst in [dispose] geschlossen.)
  void _resetBooks() {
    for (final id in _bookTimelines.keys.toList()) {
      _teardownBook(id);
    }
    _bookDirty.clear();
    _bookSignaled.clear();
    _bookMeta.clear();
    _bookEntries.clear();
    _bookComplete.clear();
    _bookTruncated.clear();
    _bookBackfilling.clear();
    _bookCapped.clear();
    _bookUndecryptable.clear();
    _bookJoinedBase.clear();
    _bookBaselining.clear();
  }

  void _disposeBooks() {
    _resetBooks();
    _bookSignalController.close().ignore();
  }

  // --------------------------------------------------------------- Testnähte

  /// Test: liest Ereignisse wie der Abgleich ein (ohne echte Zeitleiste, ohne Verschlüsselung).
  @visibleForTesting
  void debugIngestBookEvents(String roomId, String creatorId, List<Event> eventsOldestFirst) =>
      _ingestBookEvents(roomId, creatorId, eventsOldestFirst);

  @visibleForTesting
  Set<String> get debugBookTimelineIds => _bookTimelines.keys.toSet();

  @visibleForTesting
  List<BookSignal> debugBookHistory(String roomId) => <BookSignal>[
        if (_bookMeta[roomId] != null) _bookMeta[roomId]!,
        ...?_bookEntries[roomId]?.values,
      ];

  /// Test: markiert den Verlauf als vollständig (wie nach dem Backfill) oder nicht.
  @visibleForTesting
  void debugMarkBookComplete(String roomId, {bool complete = true}) =>
      complete ? _bookComplete.add(roomId) : _bookComplete.remove(roomId);

  @visibleForTesting
  void debugResetBooks() => _resetBooks();
}
