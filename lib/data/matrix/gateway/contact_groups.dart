part of '../sdk_matrix_gateway.dart';

/// Zustand der Gruppen mit Personen außerhalb der Familie (#119, K4-2a, E-114): alles in einem Halter, getrennt von
/// [_ContactState] (dessen `peers` gehören den Einzelchats; eine Gruppe darf nie wie eine Person behandelt werden).
/// Gruppen entstehen **nur** über [ConversationPolicy] (`contactGroup`, nur mit eigenem Datensatz).
class _GroupState {
  /// Eingestufte Gruppen: Raum-ID → bereinigter Titel.
  final Map<String, String> groups = <String, String>{};

  /// Zeitleisten **nur nach `openThread`**, Nachrichten nur für offene Zeitleisten.
  final Map<String, Timeline> timelines = <String, Timeline>{};
  final Map<String, List<ChatMessage>> messages = <String, List<ChatMessage>>{};

  /// Zwischenspeicher der bekannten Mitglieder (beigetreten und eingeladen) je Raum: lokal vollständig oder abgerufen.
  final Map<String, Map<String, GroupMembership>> members = <String, Map<String, GroupMembership>>{};

  /// Räume, deren Mitgliederliste bekannt ist (Eintrag in [members]).
  final Set<String> membersLoaded = <String>{};

  /// Räume, die diese Sitzung angelegt hat und für die noch kein Datensatz sichtbar ist (nur Speicher): erlaubt dem
  /// Controller das Verlassen, wenn das Schreiben des Datensatzes scheitert (D3).
  final Set<String> creatingGroups = <String>{};

  /// Gruppen, die in dieser Sitzung beigetreten bekannt waren und jetzt fehlen oder `leave`/`ban` sind (Entfernen durch andere,
  /// Austritt auf einem anderen Gerät). Das SDK 14.2.0 wirft verlassene Räume aus `client.rooms`, solange der Sync-Filter
  /// `includeLeave` nicht setzt; ohne diese Menge wäre ein Entfernen durch andere nicht von „unbekannt“ zu unterscheiden.
  /// Überlebt [clearRooms] (Familienwechsel), nicht [clearAll].
  final Set<String> left = <String>{};

  /// Läuft gerade eine Anlage (je Konto höchstens eine, Doppeltipp ⇒ `alreadyExists`)?
  final Set<String> creating = <String>{};
  final Set<String> joining = <String>{};
  final Set<String> opening = <String>{};

  /// Letzter Serverabruf der Mitgliederliste je Raum (Drosselung: höchstens alle [fetchEvery]) und laufende Abrufe.
  final Map<String, DateTime> fetchedAt = <String, DateTime>{};
  final Set<String> fetching = <String>{};

  static const Duration fetchEvery = Duration(minutes: 10);
  static const int maxJoining = 4;

  void forget(String roomId) {
    timelines.remove(roomId)?.cancelSubscriptions();
    groups.remove(roomId);
    messages.remove(roomId);
    members.remove(roomId);
    membersLoaded.remove(roomId);
  }

  void cancelTimelines() {
    for (final t in timelines.values) {
      t.cancelSubscriptions();
    }
    timelines.clear();
  }

  /// Sichtbare Gruppen verwerfen (Mitgliederliste unvollständig, Bereich aus, Familienwechsel). Laufende Anlagen,
  /// Beitritte und Abrufdrosselung überleben (kein doppeltes Anlegen, kein Abruf-Sturm).
  void clearRooms() {
    cancelTimelines();
    groups.clear();
    messages.clear();
    members.clear();
    membersLoaded.clear();
  }

  void clearAll() {
    clearRooms();
    creatingGroups.clear();
    left.clear();
    creating.clear();
    joining.clear();
    opening.clear();
    fetchedAt.clear();
    fetching.clear();
  }
}

/// Gruppen im Gateway (#119, K4-2a): Räume einstufen, Zeitleisten bei Bedarf, Anlegen, Beitritt mit Nachprüfung,
/// Verlassen. **Senden in Gruppen ist hier gesperrt** ([_requireGroupRoom] ist ein Platzhalter, K4-2b liefert das volle
/// Tor samt Schlüsselwisch). Der Datensatz entsteht vor dem Beitritt und nach der Anlage durch den Controller (K4-3);
/// dieses Modul schreibt nie einen Datensatz und nie `familyAccountData`.
mixin _ContactGroupsModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  _GroupState get _groups;
  _ContactState get _contacts;
  ContactPolicy get _contactPolicy;
  int get _contactEpoch;
  bool get _disposed;
  bool get _encryptionAvailable;
  bool _canEncryptIn(Room? room);
  bool _contactMembersComplete();
  PolicyContext _contactPolicyContext();
  RoomFacts _roomFacts(Room r, String me);
  bool _anyDeviceBlocked(String uid);
  Set<String> get _identityChanged;
  ContactReachability _reachabilityOf(String peer);
  Future<Map<String, Object?>?> _serverState(String roomId, String type);
  Future<bool> _repairEchoes(Client client, Timeline t);
  Future<void> _backfill(Timeline t, {int pages = SdkMatrixGateway.backfillPages});
  Future<void> _refresh();
  void _scheduleRefresh();
  LocalSends get _localSends;
  bool get _showReadBy;
  GatewayException _map(Object e);

  /// Gruppen, die diese Sitzung verlassen oder die der Server entfernt hat (Quelle für das Aufräumen der Datensätze durch
  /// den Controller, K4-3): Räume mit Datensatz, deren Mitgliedschaft `leave`/`ban` ist, oder die bewusst verlassen oder
  /// abgelehnt wurden (`failed`). Nie unbekannte Räume.
  @override
  Set<String> get leftGroupRooms {
    final client = _client;
    if (client == null) return const <String>{};
    final out = <String>{};
    for (final id in _contactPolicy.groups) {
      final r = client.getRoomById(id);
      if (_contacts.failed.contains(id) || _groups.left.contains(id) || (r != null && (r.membership == Membership.leave || r.membership == Membership.ban))) {
        out.add(id);
      }
    }
    return out;
  }

  /// Größenmaß G = beigetreten + (eingeladen ?? 0) (§3.6): der größere Wert aus `summary` und der bekannten Liste;
  /// `null` nur, wenn beides fehlt (Größe unbekannt, fail-closed).
  int? _groupSizeOf(Room r) {
    final s = GroupHealth.size(joined: r.summary.mJoinedMemberCount, invited: r.summary.mInvitedMemberCount);
    final l = _groups.members[r.id]?.length;
    if (s == null) return l;
    if (l == null) return s;
    return l > s ? l : s;
  }

  /// Sperrgrund aus dem Raumzustand ([GroupHealth]); `keineMitglieder` und `wechsel` gibt es erst mit K4-2b.
  GroupSendLock _groupLockOf(Room r) {
    final rule = r.getState(EventTypes.RoomJoinRules)?.content['join_rule'];
    final history = r.getState(EventTypes.HistoryVisibility)?.content['history_visibility'];
    return GroupHealth.evaluate(
      megolm: _canEncryptIn(r),
      joinRule: rule is String ? rule : null,
      historyVisibility: history is String ? history : null,
      joined: _groupSizeOf(r),
      invited: 0,
    );
  }

  String _groupTitleOf(Room r) {
    final n = ContactNames.groupTitle(r.name);
    return n.isNotEmpty ? n : ContactNames.groupTitle(r.getLocalizedDisplayname());
  }

  /// Gruppen-Threads für `threads` (Titel, Mitgliederzahl, Ausgelassene aus bekannten Schlüsseln ohne Netz, Rechte, Sperre).
  // ignore: unused_element
  List<ChatThread> _groupThreads() {
    final client = _client;
    final me = client?.userID;
    if (client == null || me == null) return const <ChatThread>[];
    final out = <ChatThread>[];
    for (final e in _groups.groups.entries) {
      final r = client.getRoomById(e.key);
      if (r == null || r.membership != Membership.join) continue;
      var unreachable = 0;
      var changed = 0;
      for (final uid in (_groups.members[e.key] ?? const <String, GroupMembership>{}).keys) {
        if (uid == me) continue;
        final idChanged = _identityChanged.contains(uid) || _anyDeviceBlocked(uid);
        if (idChanged) changed++;
        if (idChanged || _reachabilityOf(uid) == ContactReachability.notReachable) unreachable++;
      }
      out.add(ChatThread(
        id: e.key,
        kind: ThreadKind.group,
        title: e.value,
        unread: unreadIn(e.key),
        memberCount: _groupSizeOf(r) ?? 0,
        unreachableCount: unreachable,
        canManage: GroupRights(myUserId: me, myLevel: r.ownPowerLevel.level).isAdmin,
        identityChangedCount: changed,
        sendLock: _groupLockOf(r),
      ));
    }
    return out;
  }

  /// Gleicht Gruppenräume und Zeitleisten mit der Richtlinie ab (aufgerufen aus `_syncContactChats`; nur bei eingeschaltetem
  /// Bereich und vollständiger Mitgliederliste, sonst räumt der Aufrufer). **Kein** Mitgliederabgleich und kein Wisch (K4-2b).
  /// Liefert `false`, wenn der Abgleich abgebrochen werden muss (Client gewechselt).
  // ignore: unused_element
  Future<bool> _syncGroupRooms(Client client, PolicyContext ctx, String me) async {
    final g = _groups;
    final eligible = <String, Room>{};
    for (final r in client.rooms) {
      if (r.membership != Membership.join || _contacts.failed.contains(r.id) || !_contactPolicy.groups.contains(r.id)) continue;
      if (ConversationPolicy.classify(_roomFacts(r, me), ctx) != RoomClass.contactGroup) continue;
      eligible[r.id] = r;
    }
    for (final id in g.groups.keys.toList()) {
      if (eligible.containsKey(id)) continue;
      // Verschwunden oder verlassen/verbannt (nicht: Datensatz entfallen, Bereich aus): merken für den Prune des Controllers.
      final gone = client.getRoomById(id);
      if (gone == null || gone.membership == Membership.leave || gone.membership == Membership.ban) g.left.add(id);
      g.forget(id);
    }
    g.left.removeWhere(eligible.containsKey);
    // Ein sichtbarer Datensatz beendet den Schwebezustand der Anlage.
    g.creatingGroups.removeWhere(_contactPolicy.groups.contains);
    for (final r in eligible.values) {
      g.groups[r.id] = _groupTitleOf(r);
      _updateGroupMembers(r);
    }
    for (final e in g.timelines.entries.toList()) {
      if (!await _repairEchoes(client, e.value)) return false;
      if (!identical(g.timelines[e.key], e.value)) continue;
      g.messages[e.key] = ChatMapper.messages(e.value, threadId: e.key, sends: _localSends, showReadBy: _showReadBy);
    }
    return true;
  }

  /// Abrufregel für die Mitgliederliste (§3.2, Hinweis 3): **nur bei bekannter G und G ≤ 50**, nie bei G > 50 oder
  /// unbekannter Größe, auch nicht beim Öffnen. Je Sync nur lokal ([Room.getParticipants], ohne Netz); ein Serverabruf nur,
  /// wenn die lokale Liste nicht vollständig ist, höchstens einmal alle 10 Minuten je Raum (bei unbekannter Einladungszahl ist
  /// [Room.participantListComplete] immer `false`). Nach einem Abruf folgt G exakt aus der Liste ([_groupSizeOf]).
  void _updateGroupMembers(Room r) {
    final g = _groups;
    final summary = GroupHealth.size(joined: r.summary.mJoinedMemberCount, invited: r.summary.mInvitedMemberCount);
    if (summary == null || summary > ContactGroupSpec.maxMembers) {
      g.members.remove(r.id);
      g.membersLoaded.remove(r.id);
      return;
    }
    if (r.participantListComplete) {
      _rememberMembers(r, r.getParticipants());
      return;
    }
    _fetchGroupMembers(r);
  }

  void _rememberMembers(Room r, Iterable<User> users) {
    final list = <String, GroupMembership>{};
    for (final u in users) {
      if (u.membership == Membership.join) {
        list[u.id] = GroupMembership.join;
      } else if (u.membership == Membership.invite) {
        list[u.id] = GroupMembership.invite;
      }
    }
    _groups.members[r.id] = list;
    _groups.membersLoaded.add(r.id);
  }

  /// Serverabruf der Mitgliederliste: gedrosselt (höchstens alle 10 Minuten je Raum, ein Abruf je Raum gleichzeitig), nur
  /// über [_updateGroupMembers] nach der Größenprüfung. Fehler lassen den Zwischenspeicher unberührt.
  void _fetchGroupMembers(Room r) {
    final g = _groups;
    final last = g.fetchedAt[r.id];
    if (last != null && DateTime.now().difference(last) < _GroupState.fetchEvery) return;
    if (!g.fetching.add(r.id)) return;
    g.fetchedAt[r.id] = DateTime.now();
    final epoch = _contactEpoch;
    final client = _client;
    () async {
      try {
        final users = await r.requestParticipants(const <Membership>[Membership.join, Membership.invite]);
        if (_disposed || epoch != _contactEpoch || _client != client || !g.groups.containsKey(r.id)) return;
        _rememberMembers(r, users);
        _scheduleRefresh();
      } catch (e) {
        AppLog.e('gateway', 'Gruppenmitglieder konnten nicht geladen werden', e);
      } finally {
        g.fetching.remove(r.id);
      }
    }().ignore();
  }

  /// Ist [room] jetzt (mit frischem Kontext) eine beigetretene Gruppe mit Datensatz?
  bool _stillGroup(Room room) {
    final me = _client?.userID;
    if (me == null || room.membership != Membership.join || !_contactMembersComplete()) return false;
    return ConversationPolicy.classify(_roomFacts(room, me), _contactPolicyContext()) == RoomClass.contactGroup;
  }

  /// Öffnet die Zeitleiste einer Gruppe (Konzept §7.1 „bei Bedarf“); die Mitgliederliste nur nach der Abrufregel.
  // ignore: unused_element
  Future<void> _openGroupThread(String threadId) async {
    final g = _groups;
    if (g.timelines.containsKey(threadId) || !g.opening.add(threadId)) return;
    final epoch = _contactEpoch;
    final client = _client;
    try {
      final room = client?.getRoomById(threadId);
      if (client == null || room == null || room.membership != Membership.join) return;
      final t = await room.getTimeline(
        onUpdate: _scheduleRefresh,
        onInsert: (_) => _scheduleRefresh(),
        onChange: (_) => _scheduleRefresh(),
        onRemove: (_) => _scheduleRefresh(),
        onNewEvent: _scheduleRefresh,
      );
      // Nach dem Warten erneut prüfen: Abmelden, Familienwechsel, Richtlinie aus, Datensatz entfallen.
      if (_disposed || epoch != _contactEpoch || _client != client || !g.groups.containsKey(threadId) || !_stillGroup(room)) {
        t.cancelSubscriptions();
        return;
      }
      g.timelines[threadId] = t;
      _backfill(t, pages: SdkMatrixGateway.dmBackfillPages).ignore();
      _updateGroupMembers(room);
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Gruppe konnte nicht geöffnet werden', e);
    } finally {
      g.opening.remove(threadId);
    }
  }

  /// **Platzhalter (K4-2a):** Senden in Gruppen ist gesperrt, bis K4-2b das volle Tor (Zeilen 1-7, Wisch, Wechselsperre)
  /// liefert. Wirft immer; so sendet nie eine Gruppe ohne Wisch-Logik (Text, Anhang, Antwort, Wiederholen).
  // ignore: unused_element
  Room _requireGroupRoom(String threadId, Room room) => throw const GatewayException(GatewayError.notAllowed);

  /// Legt eine Gruppe **ohne Mitglieder** an und gibt die Raum-ID zurück (D3). Nur über [ContactGroupSpec]; schreibt keinen
  /// Datensatz (das tut der Controller, K4-3) und lädt niemanden ein. Je Konto höchstens eine Anlage zugleich.
  @override
  Future<String> createGroup(String name) async {
    final title = ContactNames.groupTitle(name);
    if (title.isEmpty || name.trim().length > ContactGroupSpec.nameMax) throw const GatewayException(GatewayError.invalidInput);
    final client = _client;
    final me = client?.userID;
    if (client == null || me == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!_contactPolicy.enabled || !_contactMembersComplete() || _contactPolicy.groups.length >= ContactLimits.maxGroups) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    if (!_encryptionAvailable) throw const GatewayException(GatewayError.encryptionUnavailable);
    final g = _groups;
    if (!g.creating.add(me)) throw const GatewayException(GatewayError.alreadyExists);
    final epoch = _contactEpoch;
    String? roomId;
    try {
      roomId = await client.createRoom(
        name: title,
        roomVersion: ContactGroupSpec.roomVersion,
        preset: CreateRoomPreset.privateChat,
        visibility: Visibility.private,
        initialState: <StateEvent>[
          for (final s in ContactGroupSpec.initialState()) StateEvent(type: s.type, stateKey: '', content: s.content),
        ],
        powerLevelContentOverride: ContactGroupSpec.powerLevels(me),
      );
      g.creatingGroups.add(roomId);
      // Abmelden, Kontowechsel, Bereich aus oder unvollständige Mitgliederliste (Familienwechsel) während des Anlegens: der
      // Raum gehört nicht mehr in diesen Zustand (kein verwaister Raum).
      if (_disposed || epoch != _contactEpoch || _client != client || !_contactPolicy.enabled || !_contactMembersComplete()) {
        await _leaveGroupQuietly(client, roomId);
        throw const GatewayException(GatewayError.notAllowed);
      }
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Gruppe noch nicht im Sync; Anzeige folgt beim nächsten Abgleich');
      }
      await _refresh();
      return roomId;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Gruppe konnte nicht angelegt werden (${e.runtimeType})', null);
      throw _map(e);
    } finally {
      g.creating.remove(me);
    }
  }

  Future<void> _leaveGroupQuietly(Client client, String roomId) async {
    _contacts.rememberFailed(roomId);
    _groups.creatingGroups.remove(roomId);
    try {
      // Ein eben angelegter oder beigetretener Raum steht womöglich noch nicht im lokalen Zustand: dann direkt über die API.
      final room = client.getRoomById(roomId);
      if (room != null) {
        await room.leave();
      } else {
        await client.leaveRoom(roomId);
      }
    } catch (e) {
      AppLog.e('gateway', 'Gruppe konnte nicht verlassen werden (${e.runtimeType})', null);
    }
  }

  /// Nimmt die Einladung in eine Gruppe an (nach Tipp, nie automatisch, D1) und prüft **nach** dem Beitritt vom Server
  /// ([ContactGroupSpec.verifyJoined]: Megolm, Regel `invite`, Verlauf `invited`, G ≤ 50); jeder Verstoß verlässt den Raum
  /// sofort. Der Datensatz steht vorher (D2, Controller K4-3); dieses Modul schreibt keinen und nie `familyAccountData`.
  @override
  Future<void> acceptGroupInvite(String roomId) async {
    final client = _client;
    final me = client?.userID;
    if (client == null || me == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    final room = client.getRoomById(roomId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (room.membership == Membership.join && _groups.groups.containsKey(roomId)) return; // idempotent (erneuter Tipp)
    final g = _groups;
    // Frische Einstufung vor dem Beitritt: nur eine Gruppenanfrage (Einladung, nicht `is_direct`, Regel `invite`).
    final facts = _roomFacts(room, me);
    if (room.membership != Membership.invite ||
        _contacts.failed.contains(roomId) ||
        facts.inviteIsDirect ||
        facts.joinRule != 'invite' ||
        !_contactMembersComplete() ||
        ConversationPolicy.classify(facts, _contactPolicyContext()) != RoomClass.contactRequest) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    if (g.joining.length >= _GroupState.maxJoining) throw const GatewayException(GatewayError.rateLimited);
    if (!g.joining.add(roomId)) throw const GatewayException(GatewayError.alreadyExists);
    final epoch = _contactEpoch;
    var joined = false;
    try {
      await client.joinRoomById(roomId).timeout(SdkMatrixGateway.roomOpTimeout);
      joined = true;
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Beitritt zur Gruppe noch nicht im Sync');
      }
      final joinedRoom = client.getRoomById(roomId);
      if (_disposed || epoch != _contactEpoch || _client != client) {
        // Abmelden oder Kontowechsel während des Beitritts: der Raum gehört nicht mehr in diesen Zustand.
        await _leaveGroupQuietly(client, roomId);
        throw const GatewayException(GatewayError.notAllowed);
      }
      // Der Zustand kommt **vom Server** (das SDK hält ihn bei einem partiellen Raum nicht im Speicher, und ein Heimserver
      // kann ihn aus der Einladung weglassen): fehlt er oder ist er nicht abrufbar, gilt er als verletzt (fail-closed).
      final rule = await _serverState(roomId, EventTypes.RoomJoinRules);
      final history = await _serverState(roomId, EventTypes.HistoryVisibility);
      final algorithm = joinedRoom?.getState(EventTypes.Encryption)?.content['algorithm'];
      final ok = joinedRoom != null &&
          _canEncryptIn(joinedRoom) &&
          ContactGroupSpec.verifyJoined(
            encryptionAlgorithm: algorithm is String ? algorithm : null,
            joinRule: rule?['join_rule'] as String?,
            historyVisibility: history?['history_visibility'] as String?,
            joined: joinedRoom.summary.mJoinedMemberCount,
            invited: joinedRoom.summary.mInvitedMemberCount,
          );
      if (!ok) {
        await _leaveGroupQuietly(client, roomId);
        throw const GatewayException(GatewayError.notAllowed);
      }
      await _refresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Gruppeneinladung konnte nicht angenommen werden (${e.runtimeType})', null);
      // Fehler nach dem Beitritt (z. B. Zeitüberschreitung der Nachprüfung): nie unverifiziert Mitglied bleiben.
      if (joined) await _leaveGroupQuietly(client, roomId);
      throw _map(e);
    } finally {
      g.joining.remove(roomId);
    }
  }

  /// Verlässt eine Gruppe (auch überfüllte, sendegesperrte oder unverschlüsselte; nie ein Einzelchat, nie die Familie).
  /// Scheitert `leave()`, bleibt alles unverändert (ein zweiter Versuch ist möglich). Kein `removeFromDirectChat`: eine
  /// Gruppe mit `m.direct`-Eintrag bleibt dessen Sache nicht (der Datensatz gewinnt, D4).
  // ignore: unused_element
  Future<void> _leaveGroup(String threadId) async {
    final room = _client?.getRoomById(threadId);
    if (room == null || room.membership != Membership.join) throw const GatewayException(GatewayError.notAllowed);
    try {
      await room.leave();
    } catch (e) {
      AppLog.e('gateway', 'Gruppe konnte nicht verlassen werden (${e.runtimeType})', null);
      throw _map(e);
    }
    _contacts.rememberFailed(threadId);
    _groups.forget(threadId);
    _groups.creatingGroups.remove(threadId);
    _scheduleRefresh();
  }
}
