part of '../sdk_matrix_gateway.dart';

/// Einzelchats (AP-5, E-39): Räume zuordnen, Einladungen annehmen, Einzelchat eröffnen, Zurücksetzen. Die Felder
/// (`_dm*`, `_threads`) und `_isPairRoom` bleiben in der Klasse (andere Module und Tests lesen sie).
mixin _DirectChatsModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Future<void> _backfill(Timeline t, {int pages = SdkMatrixGateway.backfillPages});
  bool _canEncryptIn(Room? room);
  int get _dmEpoch;
  set _dmEpoch(int value);
  Set<String> get _dmCreating;
  Set<String> get _dmFailed;
  Set<String> get _dmJoining;
  Map<String, List<ChatMessage>> get _dmMessages;
  Map<String, String> get _dmPeers;
  Map<String, DateTime> get _dmRetryAfter;
  Map<String, Timeline> get _dmTimelines;
  Set<String> get _identityChanged;
  LocalSends get _localSends;
  GatewayException _map(Object e);
  bool get _participantsLoaded;
  Room? _privateRoom();
  Future<void> _refresh();
  Future<bool> _repairEchoes(Client client, Timeline t);
  Family _requireFamily();
  FamilyMember _requireMember(Family f, String userId);
  void _scheduleRefresh();
  set _threads(List<ChatThread> value);

  void _resetDirectChats() {
    for (final t in _dmTimelines.values) {
      t.cancelSubscriptions();
    }
    _dmTimelines.clear();
    _dmPeers.clear();
    _dmMessages.clear();
    _dmJoining.clear();
    _dmFailed.clear();
    _dmRetryAfter.clear();
    _dmCreating.clear();
    _dmEpoch++;
    _threads = const <ChatThread>[];
  }

  /// Verschlüsselte Einzelchat-Räume mit aktuellen, beigetretenen Familienmitgliedern
  /// (Raum-ID → Gegenüber). Bei mehreren Räumen für dasselbe Gegenüber gilt der mit der
  /// kleinsten Raum-ID, damit beide Seiten denselben Raum wählen.
  Map<String, String> _eligibleDirectRooms(Client client, Family f, Room familyRoom) {
    final byPeer = <String, String>{};
    final privateId = _privateRoom()?.id;
    for (final r in client.rooms) {
      if (r.membership != Membership.join || r.id == familyRoom.id || r.id == privateId) continue;
      final peer = r.directChatMatrixID;
      if (peer == null || peer == f.myUserId || f.member(peer)?.status != MemberStatus.joined) continue;
      if (!_canEncryptIn(r) || !SdkMatrixGateway._isPairRoom(r)) continue;
      final cur = byPeer[peer];
      if (cur == null || r.id.compareTo(cur) < 0) byPeer[peer] = r.id;
    }
    return <String, String>{for (final e in byPeer.entries) e.value: e.key};
  }

  Future<void> _syncDirectChats(Client client, Family f, Room familyRoom) async {
    // Erst nach vollständig geladener Mitgliederliste (Lazy Loading liefert anfangs nur Teile),
    // sonst würden Einzelchats kurz verschwinden.
    if (_participantsLoaded) {
      final eligible = _eligibleDirectRooms(client, f, familyRoom);
      for (final id in _dmTimelines.keys.toList()) {
        if (!eligible.containsKey(id)) {
          _dmTimelines.remove(id)?.cancelSubscriptions();
          _dmPeers.remove(id);
          _dmMessages.remove(id);
        }
      }
      for (final e in eligible.entries) {
        _dmPeers[e.key] = e.value;
        if (_dmTimelines.containsKey(e.key) || !_dmCreating.add(e.key)) continue;
        final room = client.getRoomById(e.key);
        if (room == null) {
          _dmCreating.remove(e.key);
          continue;
        }
        final epoch = _dmEpoch;
        try {
          final t = await room.getTimeline(
            onUpdate: _scheduleRefresh,
            onInsert: (_) => _scheduleRefresh(),
            onChange: (_) => _scheduleRefresh(),
            onRemove: (_) => _scheduleRefresh(),
            onNewEvent: _scheduleRefresh,
          );
          if (epoch != _dmEpoch || _client != client) {
            // Zwischenzeitlich abgemeldet oder Familie gewechselt: Ergebnis verwerfen.
            t.cancelSubscriptions();
            return;
          }
          _dmTimelines[e.key] = t;
          _backfill(t, pages: SdkMatrixGateway.dmBackfillPages).ignore();
        } catch (err) {
          // Ein defekter Einzelchat darf Kalender- und Einkaufsabgleich nicht blockieren.
          AppLog.e('gateway', 'Einzelchat konnte nicht geladen werden', err);
        } finally {
          _dmCreating.remove(e.key);
        }
      }
      for (final e in _dmTimelines.entries.toList()) {
        if (!await _repairEchoes(client, e.value)) return;
        if (!identical(_dmTimelines[e.key], e.value)) continue;
        _dmMessages[e.key] = ChatMapper.messages(e.value, threadId: e.key, sends: _localSends);
      }
    }
    final dms = <ChatThread>[
      for (final e in _dmPeers.entries)
        if (_dmTimelines.containsKey(e.key))
          ChatThread(
            id: e.key,
            kind: ThreadKind.direct,
            title: f.member(e.value)?.displayName ?? e.value,
            peerId: e.value,
            unread: unreadIn(e.key),
          ),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _threads = <ChatThread>[
      ChatThread(id: ChatThread.familyId, kind: ThreadKind.family, title: f.name, unread: unreadIn(ChatThread.familyId)),
      ...dms,
    ];
  }

  /// Einladungen in Einzelchats werden nur angenommen, wenn der Einladende ein beigetretenes
  /// Familienmitglied ist. Alle anderen werden ignoriert (nie angenommen, nie angezeigt).
  void _acceptDirectInvites(Client client, Family f) {
    if (!_participantsLoaded) return;
    final me = f.myUserId;
    for (final r in client.rooms) {
      if (r.membership != Membership.invite || _dmFailed.contains(r.id)) continue;
      final retry = _dmRetryAfter[r.id];
      if (retry != null && DateTime.now().isBefore(retry)) continue;
      final inv = r.getState(EventTypes.RoomMember, me);
      if (inv == null || inv.content['is_direct'] != true) continue;
      final from = inv.senderId;
      if (from == me || f.member(from)?.status != MemberStatus.joined || _identityChanged.contains(from)) continue;
      // Höchstens ein Einzelchat je anderem Mitglied und wenige gleichzeitige Beitritte.
      if (_dmTimelines.length + _dmJoining.length >= f.joined.length || _dmJoining.length >= 4) continue;
      // Pro Mitglied nur ein Einzelchat: weitere Einladungen desselben Einladenden werden ignoriert.
      if (_dmPeers.values.contains(from)) continue;
      if (!_dmJoining.add(r.id)) continue;
      _joinDirect(r).whenComplete(() => _dmJoining.remove(r.id)).ignore();
    }
  }

  Future<void> _joinDirect(Room r) async {
    try {
      await r.join(waitForSync: true).timeout(SdkMatrixGateway.roomOpTimeout);
      final joined = _client?.getRoomById(r.id);
      // Ein nicht verschlüsselter Raum oder einer mit weiteren Mitgliedern wird nie genutzt:
      // sofort wieder verlassen.
      if (joined == null || !_canEncryptIn(joined) || !SdkMatrixGateway._isPairRoom(joined)) {
        _dmFailed.add(r.id);
        await joined?.removeFromDirectChat();
        await joined?.leave();
        return;
      }
      _scheduleRefresh();
    } catch (e) {
      // Vorläufiger Fehler (Netz, Zeitüberschreitung): später erneut versuchen.
      _dmRetryAfter[r.id] = DateTime.now().add(const Duration(minutes: 1));
      AppLog.e('gateway', 'Einzelchat konnte nicht angenommen werden', e);
    }
  }

  @override
  Future<String> startDirectChat(String userId) async {
    final f = _requireFamily();
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final m = _requireMember(f, userId);
    if (userId == f.myUserId || m.status != MemberStatus.joined) throw const GatewayException(GatewayError.notAllowed);
    for (final e in _dmPeers.entries) {
      if (e.value == userId && _dmTimelines.containsKey(e.key)) return e.key;
    }
    if (!client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    try {
      // Nie einen vorhandenen, womöglich unverschlüsselten Raum wiederverwenden.
      // Ohne eigene Zeitschranke: ein Abbruch zwischen Anlegen und Eintrag in `m.direct` würde einen
      // Raum hinterlassen, den nur die Gegenseite sieht.
      final roomId = await client.startDirectChat(
        userId,
        enableEncryption: true,
        skipExistingChat: true,
        preset: CreateRoomPreset.privateChat,
        initialState: <StateEvent>[
          StateEvent(type: 'm.room.history_visibility', stateKey: '', content: <String, Object?>{'history_visibility': 'shared'}),
        ],
      );
      await _refresh();
      for (final e in _dmPeers.entries) {
        if (e.value == userId && _dmTimelines.containsKey(e.key)) return e.key;
      }
      return roomId;
    } catch (e) {
      AppLog.e('gateway', 'Einzelchat konnte nicht eröffnet werden', e);
      throw _map(e);
    }
  }
}
