part of '../sdk_matrix_gateway.dart';

/// Kassenbücher (#311, E-113): Jedes Buch ist ein eigener verschlüsselter Raum. Alles in diesem Abschnitt ist
/// gesperrt, solange `cashBooksEnabled` (Standard `CashBookFlags.enabled`) `false` ist: Listen sind leer, alle
/// Aktionen werfen `notAllowed`, es entsteht keine Anfrage an den Server.
mixin _BooksModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  bool get _cashBooksEnabled;
  bool get _requireEncryptionForBooks;
  bool get _participantsLoaded;
  BookReconciler get _bookReconciler;
  GatewayException _map(Object e);
  void _scheduleRefresh();

  /// Ersteller laut `m.room.create` (Raumversion 10: Absender des Create-Ereignisses).
  String? _creatorOf(Room room) => room.getState(EventTypes.RoomCreate)?.senderId;

  bool _isBookOfCurrentFamily(Room room) =>
      BookRoomMarker.isBook(room.getState(EventTypes.RoomCreate)?.content) &&
      room.getState(EventTypes.RoomCreate)?.content[BookRoomMarker.familyKey] == _family?.roomId;

  Room _bookRoom(String roomId, {required Membership membership}) {
    final client = _client;
    if (!_cashBooksEnabled || client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != membership) throw const GatewayException(GatewayError.notFound);
    if (!BookRoomMarker.isBook(room.getState(EventTypes.RoomCreate)?.content)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    return room;
  }

  @override
  List<BookRoomInfo> get books {
    final client = _client;
    if (!_cashBooksEnabled || client == null || !client.isLogged()) return const <BookRoomInfo>[];
    return <BookRoomInfo>[
      for (final r in client.rooms)
        if (r.membership == Membership.join && _isBookOfCurrentFamily(r) && _creatorOf(r) != null)
          BookRoomInfo(roomId: r.id, creatorId: _creatorOf(r)!),
    ];
  }

  @override
  List<BookInvitationInfo> get bookInvitations {
    final client = _client;
    if (!_cashBooksEnabled || client == null || !client.isLogged()) return const <BookInvitationInfo>[];
    final me = client.userID!;
    final family = _family;
    return <BookInvitationInfo>[
      for (final r in client.rooms)
        if (r.membership == Membership.invite && BookRoomMarker.isBook(r.getState(EventTypes.RoomCreate)?.content))
          if (BookPolicy.mayAccept(family, inviterId: r.getState(EventTypes.RoomMember, me)?.senderId ?? '', creatorId: _creatorOf(r)))
            BookInvitationInfo(
              roomId: r.id,
              inviterId: TextSanitizer.clean(r.getState(EventTypes.RoomMember, me)?.senderId ?? '', max: 80),
              inviterName: TextSanitizer.clean(family!.member(_creatorOf(r)!)?.displayName ?? '', max: FamilyRoomSpec.nameMax),
            ),
    ];
  }

  @override
  Future<String> createBook() async {
    final client = _client;
    final family = _family;
    if (!_cashBooksEnabled || client == null || !client.isLogged() || family == null) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    if (!Permissions.isModerator(family)) throw const GatewayException(GatewayError.notAllowed);
    if (_requireEncryptionForBooks && !client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (books.length >= CashBookLimits.maxBooksPerFamily) throw const GatewayException(GatewayError.invalidInput);
    try {
      final me = client.userID!;
      final roomId = await client.createRoom(
        name: BookRoomSpec.name,
        roomVersion: BookRoomSpec.roomVersion,
        preset: CreateRoomPreset.privateChat,
        visibility: Visibility.private,
        creationContent: BookRoomMarker.cashCreationContent(family.roomId),
        initialState: <StateEvent>[
          for (final s in BookRoomSpec.initialState()) StateEvent(type: s.type, stateKey: '', content: s.content),
        ],
        powerLevelContentOverride: BookRoomSpec.powerLevels(me),
      );
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Buch noch nicht im Sync; Anzeige folgt beim nächsten Abgleich');
      }
      await _muteBook(roomId);
      _scheduleRefresh();
      return roomId;
    } catch (e) {
      AppLog.e('gateway', 'Buch konnte nicht angelegt werden', e);
      throw _map(e);
    }
  }

  /// Raum-Push-Regel „stumm“ (kein „Neue Nachricht“ für verschlüsselte Einträge). Ein Fehlschlag ist nur eine Warnung:
  /// Er macht weder Anlegen noch Beitritt rückgängig.
  Future<void> _muteBook(String roomId) async {
    try {
      await _client?.getRoomById(roomId)?.setPushRuleState(PushRuleState.dontNotify);
    } catch (e) {
      AppLog.w('gateway', 'Buch nicht stumm geschaltet');
    }
  }

  @override
  Future<void> inviteToBook(String roomId, String userId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    final me = _client!.userID!;
    if (_creatorOf(room) != me) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isUserId(userId) || !BookPolicy.canInvite(_family, userId)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    try {
      await room.requestParticipants();
      final members = room.getParticipants().where((u) => u.membership == Membership.join || u.membership == Membership.invite);
      if (members.length >= CashBookLimits.maxMembersPerBook) throw const GatewayException(GatewayError.invalidInput);
      await room.invite(userId).timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (e) {
      if (e is GatewayException) rethrow;
      throw _map(e);
    }
  }

  @override
  Future<void> removeFromBook(String roomId, String userId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    final me = _client!.userID!;
    if (_creatorOf(room) != me || userId == me || !MatrixIds.isUserId(userId)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    try {
      await room.kick(userId).timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> leaveBook(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    try {
      await room.leave().timeout(SdkMatrixGateway.roomOpTimeout);
      _scheduleRefresh();
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> declineBookInvitation(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.invite);
    try {
      await room.leave().timeout(SdkMatrixGateway.roomOpTimeout);
      _scheduleRefresh();
    } catch (e) {
      throw _map(e);
    }
  }

  /// Zustandsereignis **vom Server** lesen (nicht aus dem Zwischenspeicher des SDK, der nur wichtige Typen im Speicher
  /// hält): Die Nachprüfung nach dem Beitritt verlässt sich nie auf einen lokalen Stand. `null`, wenn es fehlt oder der
  /// Abruf scheitert (dann besteht die Prüfung nicht).
  Future<Map<String, Object?>?> _serverState(String roomId, String type) async {
    try {
      return await _client!.getRoomStateWithKey(roomId, type, '').timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (_) {
      // Jeder Fehler des Abrufs heißt: Der Zustand ist nicht belegt, die Nachprüfung besteht nicht (fail-safe).
      return null;
    }
  }

  @override
  Future<void> acceptBookInvitation(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.invite);
    final client = _client!;
    final inviter = room.getState(EventTypes.RoomMember, client.userID!)?.senderId ?? '';
    // Einladender == Ersteller und Moderator meiner Familie; das Create-Feld `family` zählt nicht.
    if (!BookPolicy.mayAccept(_family, inviterId: inviter, creatorId: _creatorOf(room))) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    var joined = false;
    try {
      await client.joinRoomById(roomId).timeout(SdkMatrixGateway.roomOpTimeout);
      joined = true;
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Beitritt zum Buch noch nicht im Sync');
      }
      final joinedRoom = client.getRoomById(roomId);
      final creator = joinedRoom == null ? null : _creatorOf(joinedRoom);
      var ok = joinedRoom != null &&
          creator != null &&
          creator == inviter &&
          BookRoomMarker.isBook(joinedRoom.getState(EventTypes.RoomCreate)?.content);
      if (ok) {
        final enc = await _serverState(roomId, EventTypes.Encryption);
        final hist = await _serverState(roomId, EventTypes.HistoryVisibility);
        final rule = await _serverState(roomId, EventTypes.RoomJoinRules);
        final pl = await _serverState(roomId, EventTypes.RoomPowerLevels);
        ok = BookRoomSpec.verifyJoined(
          encryptionAlgorithm: enc?['algorithm'] as String?,
          historyVisibility: hist?['history_visibility'] as String?,
          joinRule: rule?['join_rule'] as String?,
          powerLevels: pl,
          creatorId: creator,
        );
      }
      if (!ok) {
        // Der Raum hält nicht, was die Einladung versprach: nicht dableiben. Über die Raum-ID verlassen, nicht über das
        // Raumobjekt: Der Beitritt kann serverseitig gelungen, im lokalen Stand aber noch nicht angekommen sein.
        await client.leaveRoom(roomId);
        throw const GatewayException(GatewayError.notAllowed);
      }
      await _muteBook(roomId);
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Buch-Einladung konnte nicht angenommen werden', e);
      if (joined && e is! GatewayException) {
        try {
          await client.leaveRoom(roomId);
        } catch (_) {
          // Der ursprüngliche Fehler wird unten weitergegeben; das Verlassen war nur ein Versuch der Aufräumung.
          AppLog.w('gateway', 'Buch nach Fehler nicht verlassen');
        }
      }
      throw _map(e);
    }
  }

  @override
  Future<void> verifyBookRecipients(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    final family = _family;
    final me = _client!.userID!;
    if (family == null) throw const GatewayException(GatewayError.notAllowed);
    try {
      // Immer frisch lesen: kein Zwischenspeicher wie beim privaten Raum (`_privateVerified`).
      await room.requestParticipants();
    } catch (e) {
      throw _map(e);
    }
    final members = <BookMember>[
      for (final u in room.getParticipants())
        if (u.membership == Membership.join) BookMember(u.id, BookMembership.joined),
      for (final u in room.getParticipants())
        if (u.membership == Membership.invite) BookMember(u.id, BookMembership.invited),
    ];
    final bad = BookPolicy.unauthorized(members, family, me: me);
    if (bad.isNotEmpty) {
      AppLog.w('gateway', 'Buch hat nicht berechtigte Mitglieder, Senden verweigert');
      throw const GatewayException(GatewayError.notAllowed);
    }
  }

  @override
  Future<List<String>> reconcileBook(String roomId) async {
    final room = _bookRoom(roomId, membership: Membership.join);
    final family = _family;
    final me = _client!.userID!;
    // Nur der Ersteller darf entfernen, und nur bei belastbarem Stand.
    if (_creatorOf(room) != me) return const <String>[];
    if (family == null || !initialSyncDone || !_participantsLoaded) {
      _bookReconciler.reset(roomId);
      return const <String>[];
    }
    try {
      await room.requestParticipants();
    } catch (e) {
      _bookReconciler.reset(roomId);
      throw _map(e);
    }
    final members = <BookMember>[
      for (final u in room.getParticipants())
        if (u.membership == Membership.join || u.membership == Membership.invite)
          BookMember(u.id, u.membership == Membership.join ? BookMembership.joined : BookMembership.invited),
    ];
    // Ausstehende Einladungen eines Moderators sind kein Abgleichsgrund, wenn er (noch) Moderator ist; wer nicht
    // (mehr) berechtigt ist, fällt auf.
    final confirmed = _bookReconciler.observe(roomId, BookPolicy.unauthorized(members, family, me: me));
    final removed = <String>[];
    for (final userId in confirmed) {
      try {
        await room.kick(userId).timeout(SdkMatrixGateway.roomOpTimeout);
        removed.add(userId);
      } catch (e) {
        AppLog.w('gateway', 'Entfernen aus dem Buch gescheitert');
      }
    }
    return removed;
  }
}
