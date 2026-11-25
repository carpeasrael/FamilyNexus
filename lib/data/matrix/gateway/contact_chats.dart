part of '../sdk_matrix_gateway.dart';

/// Zustand der Kontakt-Einzelchats (#119, K3a-2, E-114): alles in einem Halter, damit `sdk_matrix_gateway.dart` nur ein Feld
/// bekommt. Räume entstehen **nur** über [ConversationPolicy] (`contactDirect`, `contactRequest`, `autoAcceptContact`).
class _ContactState {
  /// Kontakt-Einzelchats: Raum-ID → Gegenüber.
  final Map<String, String> peers = <String, String>{};

  /// Zeitleisten **nur nach `openThread`** (Konzept §7.1), Nachrichten nur für offene Zeitleisten.
  final Map<String, Timeline> timelines = <String, Timeline>{};
  final Map<String, List<ChatMessage>> messages = <String, List<ChatMessage>>{};
  final Map<String, String> titles = <String, String>{};
  final Map<String, String> names = <String, String>{}; // bereinigter Name ohne Server (Vergleich mit Familiennamen)

  /// Identitätszustand je Gespräch (Raum-ID), im Abgleich gesetzt (K3b-2b); nur bei beigetretenem Gegenüber.
  final Map<String, IdentityStatus> identity = <String, IdentityStatus>{};

  /// Gegenüber nur eingeladen (wartet auf Annahme): Senden gesperrt.
  final Set<String> pending = <String>{};
  final Set<String> joining = <String>{};
  final Set<String> opening = <String>{};

  /// Abgelehnte oder verlassene Räume; verdrängt die ältesten Einträge, leert nie alles.
  final LinkedHashSet<String> failed = LinkedHashSet<String>();
  final Map<String, DateTime> retryAfter = <String, DateTime>{};
  static const int maxFailed = 500;

  /// Anfragen (ohne Rauminhalt) und die Zahl der nicht angezeigten.
  List<ContactRequest> requests = const <ContactRequest>[];
  int requestsHidden = 0;

  /// Einladungszustand ist unveränderlich: Einladender und `is_direct` je Einladungsraum, solange er eine Einladung ist.
  final Map<String, ({String? from, bool direct})> inviteMeta = <String, ({String? from, bool direct})>{};
  final Map<String, int> requestSeen = <String, int>{};
  int requestSeq = 0;

  /// Mitgliedszustand des Gegenübers nachladen (Lazy Loading, Neustart): höchstens 4 gleichzeitig, je Raum höchstens
  /// einmal je Minute.
  final Set<String> peerLoading = <String>{};
  final Map<String, DateTime> peerRetryAfter = <String, DateTime>{};
  final Map<String, PeerMembership> peerCache = <String, PeerMembership>{};

  /// Kontakt hinzufügen (K3a-2b): Abfragen begrenzen, Ergebnisse kurz merken, Anlegen nie doppelt.
  final Map<String, ({DateTime at, ContactProbe probe})> probeCache = <String, ({DateTime at, ContactProbe probe})>{};
  final Map<String, Future<ContactProbe>> probeInFlight = <String, Future<ContactProbe>>{};
  final Set<Future<void>> probeSlots = <Future<void>>{};
  final List<DateTime> probeTimes = <DateTime>[];
  final Set<String> probedIds = <String>{};
  final Set<String> creating = <String>{};

  /// Erreichbarkeit je Gegenüber kurz merken (die Signaturprüfung je Gerät ist teuer): Zeit und Ergebnis.
  final Map<String, ({DateTime at, ContactReachability reach})> reachCache = <String, ({DateTime at, ContactReachability reach})>{};

  void rememberFailed(String roomId) {
    failed.remove(roomId);
    failed.add(roomId);
    while (failed.length > maxFailed) {
      failed.remove(failed.first);
    }
    if (retryAfter.length > maxFailed) retryAfter.remove(retryAfter.keys.first);
  }

  void cancelTimelines() {
    for (final t in timelines.values) {
      t.cancelSubscriptions();
    }
    timelines.clear();
  }

  /// Sichtbare Räume und Anfragen verwerfen (Mitgliederliste unvollständig, Bereich aus, Familienwechsel).
  void clearRooms() {
    cancelTimelines();
    peers.clear();
    messages.clear();
    titles.clear();
    names.clear();
    identity.clear();
    pending.clear();
    requests = const <ContactRequest>[];
    requestsHidden = 0;
  }

  void clearAll() {
    clearRooms();
    joining.clear();
    opening.clear();
    failed.clear();
    retryAfter.clear();
    inviteMeta.clear();
    requestSeen.clear();
    requestSeq = 0;
    peerLoading.clear();
    peerRetryAfter.clear();
    peerCache.clear();
    probeCache.clear();
    probeInFlight.clear();
    probeSlots.clear();
    probeTimes.clear();
    probedIds.clear();
    creating.clear();
    reachCache.clear();
  }
}

/// Ergebnis der Nachprüfung nach dem Beitritt: ein sicherer Verstoß führt zum Verlassen, „unbekannt“ nie.
enum _ContactVerdict { ok, violation, unknown }

/// Kontakt-Einzelchats im Gateway (#119, K3a-2a): Räume einstufen, Zeitleisten bei Bedarf, Anfragen, Auto-Annahme eigener
/// Kontakte, Ablehnen, Verlassen. Der Datensatz entsteht **vor** dem Raum (Controller, K3b); das Gateway prüft nur die
/// Richtlinie ([setContactPolicy]).
mixin _ContactChatsModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  bool _canEncryptIn(Room? room);
  _ContactState get _contacts;
  ContactPolicy get _contactPolicy;
  int get _dmEpoch;
  Map<String, String> get _dmPeers;
  bool get _disposed;
  Map<String, Timeline> get _dmTimelines;
  Family? get _family;
  Room? _familyRoom();
  bool get _participantsLoaded;
  LocalSends get _localSends;
  bool get _showReadBy;
  Future<void> _backfill(Timeline t, {int pages = SdkMatrixGateway.backfillPages});
  Future<bool> _repairEchoes(Client client, Timeline t);
  PolicyContext _policyContext(Family f, String familyRoomId);
  RoomFacts _roomFacts(Room r, String me);
  GatewayException _map(Object e);
  ContactReachability _reachabilityOf(String peer);
  IdentityStatus _identityOf(String uid, String me, {bool mirror = true});
  Set<String> get _identityChanged;
  void _scheduleRefresh();

  /// Nur für Tests: lädt den Mitgliedszustand des Gegenübers (Harness ohne diesen HTTP-Weg).
  @visibleForTesting
  Future<PeerMembership?> Function(Room room, String peer)? debugPeerMembershipLoader;

  @override
  List<ContactRequest> get contactRequests => _contacts.requests;

  @override
  int get contactRequestsHidden => _contacts.requestsHidden;

  /// Mitgliedszustand des Gegenübers aus `m.room.member` (nicht aus Zählern); nicht geladen: Zwischenspeicher der
  /// Test-Naht, sonst `unknown`.
  // ignore: unused_element
  PeerMembership _peerMembershipOf(Room r, String peer) {
    final m = r.getState(EventTypes.RoomMember, peer)?.content['membership'];
    if (m is String) {
      return switch (m) {
        'join' => PeerMembership.join,
        'invite' => PeerMembership.invite,
        _ => PeerMembership.other,
      };
    }
    return _contacts.peerCache['${r.id}|$peer'] ?? PeerMembership.unknown;
  }

  /// Fordert den Mitgliedszustand des Gegenübers an (Lazy Loading, Neustart): höchstens 4 gleichzeitig, je Raum höchstens
  /// einmal je Minute, Ergebnis nur über den Raumzustand gelesen; Fehler bleiben `unknown` (fail-closed).
  void _requestPeerMembership(Room r, String peer) {
    final c = _contacts;
    final retry = c.peerRetryAfter[r.id];
    if (retry != null && DateTime.now().isBefore(retry)) return;
    if (c.peerLoading.length >= 4 || !c.peerLoading.add(r.id)) return;
    c.peerRetryAfter[r.id] = DateTime.now().add(const Duration(minutes: 1));
    final epoch = _dmEpoch;
    final client = _client;
    () async {
      try {
        final loader = debugPeerMembershipLoader;
        if (loader != null) {
          final m = await loader(r, peer);
          if (m != null && epoch == _dmEpoch) c.peerCache['${r.id}|$peer'] = m;
        } else {
          await r.requestUser(peer, ignoreErrors: true);
        }
        if (_disposed || epoch != _dmEpoch || _client != client) return;
        _scheduleRefresh();
      } catch (e) {
        AppLog.e('gateway', 'Mitgliedszustand konnte nicht geladen werden', e);
      } finally {
        c.peerLoading.remove(r.id);
      }
    }().ignore();
  }

  /// Der gewählte Kontakt-Raum des Gegenübers (beigetretenes Gegenüber), sonst `null`; wartende Räume zählen nicht.
  // ignore: unused_element
  String? _contactRoomOf(String peer) {
    final c = _contacts;
    String? best;
    for (final e in c.peers.entries) {
      if (e.value != peer || c.pending.contains(e.key)) continue;
      if (best == null || e.key.compareTo(best) < 0) best = e.key;
    }
    return best;
  }

  /// Einladender und `is_direct` einer Einladung, aus dem Zwischenspeicher oder einmal aus dem Zustand gelesen.
  ({String? from, bool direct}) _inviteMetaOf(Room r, String me) {
    final cached = _contacts.inviteMeta[r.id];
    if (cached != null) return cached;
    final f = _roomFacts(r, me);
    final meta = (from: f.inviterId, direct: f.inviteIsDirect);
    _contacts.inviteMeta[r.id] = meta;
    return meta;
  }

  /// Kontakt-Threads für `threads` (nach Titel sortiert).
  // ignore: unused_element
  List<ChatThread> _contactThreads() => <ChatThread>[
        for (final e in _contacts.peers.entries)
          if (!_dmPeers.containsKey(e.key))
            ChatThread(
              id: e.key,
              kind: ThreadKind.contact,
              title: _contacts.titles[e.key] ?? e.value,
              peerName: _contacts.names[e.key] ?? '',
              peerId: e.value,
              unread: unreadIn(e.key),
              pending: _contacts.pending.contains(e.key),
              reachable: _reachabilityOf(e.value) != ContactReachability.notReachable,
              identity: _identityChanged.contains(e.value) ? IdentityStatus.changed : (_contacts.identity[e.key] ?? IdentityStatus.unknown),
            ),
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  /// Gleicht Kontakt-Räume, Zeitleisten und Anfragen mit der Richtlinie ab. Solange die Mitgliederliste der Familie nicht
  /// geladen ist (auch nach einem Familienwechsel), gibt es **keine** Kontakt-Threads und keine Anfragen (fail-closed).
  // ignore: unused_element
  Future<void> _syncContactChats(Client client, Family f, Room familyRoom) async {
    final c = _contacts;
    if (!_participantsLoaded || !_contactPolicy.enabled) {
      c.clearRooms();
      if (!_contactPolicy.enabled) c.inviteMeta.clear();
      return;
    }
    final ctx = _policyContext(f, familyRoom.id);
    final me = f.myUserId;

    // 1. Beigetretene Räume: je Gegenüber ein Raum (beigetretenes Gegenüber vor wartendem, dann kleinste Raum-ID).
    final chosen = <String, Room>{};
    final chosenPending = <String, bool>{};
    for (final r in client.rooms) {
      if (r.membership != Membership.join || c.failed.contains(r.id)) continue; // bewusst verlassene Räume nie wieder zeigen
      final peer = r.directChatMatrixID;
      if (peer == null || !_contactPolicy.contacts.containsKey(peer) || f.member(peer) != null || peer == me) continue;
      final facts = _roomFacts(r, me);
      if (facts.peerMembership == PeerMembership.unknown) _requestPeerMembership(r, peer);
      if (ConversationPolicy.classify(facts, ctx) != RoomClass.contactDirect) continue;
      final waiting = facts.peerMembership != PeerMembership.join;
      final cur = chosen[peer];
      final curWaiting = chosenPending[peer] ?? true;
      final better = cur == null || (curWaiting && !waiting) || (curWaiting == waiting && r.id.compareTo(cur.id) < 0);
      if (better) {
        chosen[peer] = r;
        chosenPending[peer] = waiting;
      }
    }
    final eligible = <String, String>{for (final e in chosen.entries) e.value.id: e.key};
    for (final id in c.peers.keys.toList()) {
      if (!eligible.containsKey(id)) {
        c.timelines.remove(id)?.cancelSubscriptions();
        c.peers.remove(id);
        c.messages.remove(id);
        c.titles.remove(id);
        c.names.remove(id);
        c.identity.remove(id);
        c.pending.remove(id);
      }
    }
    for (final e in chosen.entries) {
      final r = e.value;
      c.peers[r.id] = e.key;
      final name = r.getState(EventTypes.RoomMember, e.key)?.content['displayname'];
      c.titles[r.id] = ContactNames.title(name is String ? name : null, e.key);
      c.names[r.id] = ContactNames.cleanName(name is String ? name : null);
      if (chosenPending[e.key] ?? false) {
        c.pending.add(r.id);
        c.identity.remove(r.id); // wartende Räume werden nicht gepinnt (Grenze (a) aus E-37)
      } else {
        c.pending.remove(r.id);
        // Nur mit Familie (der lokale Anteil im Spiegel bleibt sonst leer, Kontakte gehören aber zum Konto).
        c.identity[r.id] = _identityOf(e.key, me, mirror: false);
      }
    }
    // Zeitleisten, die nicht mehr zulässig sind, sind mit den Räumen entfernt; offene werden neu abgebildet.
    for (final e in c.timelines.entries.toList()) {
      if (!await _repairEchoes(client, e.value)) return;
      if (!identical(c.timelines[e.key], e.value)) continue;
      c.messages[e.key] = ChatMapper.messages(e.value, threadId: e.key, sends: _localSends, showReadBy: _showReadBy);
    }

    // 2. Anfragen: Einladungen `is_direct` von Fremden ohne Datensatz, ohne Rauminhalt.
    _rebuildRequests(client, f, ctx, me);
  }

  void _rebuildRequests(Client client, Family f, PolicyContext ctx, String me) {
    final c = _contacts;
    final invites = <Room>[];
    final liveIds = <String>{};
    for (final r in client.rooms) {
      if (r.membership != Membership.invite) continue;
      liveIds.add(r.id);
      invites.add(r);
    }
    c.inviteMeta.removeWhere((id, _) => !liveIds.contains(id));
    c.requestSeen.removeWhere((id, _) => !liveIds.contains(id));
    // Aufwandsgrenze: nur die ersten 500 Direkteinladungen in der Reihenfolge der Erstsichtung (stabil, nicht verdrängbar).
    final direct = <Room>[];
    for (final r in invites) {
      if (c.failed.contains(r.id)) continue;
      final meta = _inviteMetaOf(r, me);
      if (!meta.direct || meta.from == null) continue;
      if (_contactPolicy.contacts.containsKey(meta.from)) continue; // Kontakte nehmen den Weg der Auto-Annahme
      c.requestSeen.putIfAbsent(r.id, () => c.requestSeq++);
      direct.add(r);
    }
    direct.sort((a, b) {
      final k = c.requestSeen[a.id]!.compareTo(c.requestSeen[b.id]!);
      return k != 0 ? k : a.id.compareTo(b.id);
    });
    final bySender = <String, Room>{};
    for (final r in direct.take(500)) {
      if (ConversationPolicy.classify(_roomFacts(r, me), ctx) != RoomClass.contactRequest) continue;
      final from = c.inviteMeta[r.id]!.from!;
      final cur = bySender[from];
      if (cur == null || r.id.compareTo(cur.id) < 0) bySender[from] = r;
    }
    final ordered = bySender.values.toList()
      ..sort((a, b) {
        final k = c.requestSeen[a.id]!.compareTo(c.requestSeen[b.id]!);
        return k != 0 ? k : a.id.compareTo(b.id);
      });
    final perServer = <String, int>{};
    final out = <ContactRequest>[];
    var hidden = 0;
    for (final r in ordered) {
      final from = c.inviteMeta[r.id]!.from!;
      final server = MatrixIds.serverName(from) ?? '';
      final n = perServer[server] ?? 0;
      if (n >= 5 || out.length >= 50) {
        hidden++;
        continue;
      }
      perServer[server] = n + 1;
      final name = r.getState(EventTypes.RoomMember, from)?.content['displayname'];
      out.add(ContactRequest(
        roomId: r.id,
        fromUserId: from,
        fromName: ContactNames.title(name is String ? name : null, from),
        name: ContactNames.cleanName(name is String ? name : null),
      ));
    }
    c.requests = out;
    c.requestsHidden = hidden;
  }

  /// Nimmt Einladungen **eigener Kontakte** an ([ConversationPolicy.autoAcceptContact]): erst alle Einladungen von
  /// Absendern mit Datensatz (Kartenzugriff, ohne Obergrenze), je Einladendem die kleinste Raum-ID unter den zulässigen;
  /// ein beigetretener Raum des Einladenden blockiert, ein nur wartender nicht (gegenseitiges Hinzufügen).
  // ignore: unused_element
  void _acceptContactInvites(Client client, Family f) {
    if (!_participantsLoaded || !_contactPolicy.enabled) return;
    final c = _contacts;
    final me = f.myUserId;
    final ctx = _policyContext(f, f.roomId);
    final byFrom = <String, Room>{};
    for (final r in client.rooms) {
      if (r.membership != Membership.invite || c.failed.contains(r.id)) continue;
      final retry = c.retryAfter[r.id];
      if (retry != null && DateTime.now().isBefore(retry)) continue;
      final meta = _inviteMetaOf(r, me);
      final from = meta.from;
      if (!meta.direct || from == null || !_contactPolicy.contacts.containsKey(from)) continue;
      if (!ConversationPolicy.autoAcceptContact(_roomFacts(r, me), ctx)) continue;
      final cur = byFrom[from];
      if (cur == null || r.id.compareTo(cur.id) < 0) byFrom[from] = r;
    }
    for (final e in byFrom.entries) {
      final from = e.key;
      final r = e.value;
      // Ein beigetretener Raum mit dem Einladenden gilt schon; ein nur wartender (pending) hindert die Annahme nicht.
      final hasJoined = c.peers.entries.any((p) => p.value == from && !c.pending.contains(p.key));
      if (hasJoined) continue;
      if (c.peers.length + c.joining.length >= ContactLimits.maxContacts || c.joining.length >= 4) break;
      if (!c.joining.add(r.id)) continue;
      _joinContact(r, from).whenComplete(() => c.joining.remove(r.id)).ignore();
    }
  }

  Future<void> _joinContact(Room r, String from) async {
    final c = _contacts;
    final epoch = _dmEpoch;
    final client = _client;
    try {
      await r.join(waitForSync: true).timeout(SdkMatrixGateway.roomOpTimeout);
      final joined = _client?.getRoomById(r.id);
      if (_disposed || epoch != _dmEpoch || _client != client) {
        // Familienwechsel oder Abmelden während des Beitritts: der Raum gehört nicht mehr in diesen Zustand.
        await _leaveContactRoom(joined ?? r);
        return;
      }
      switch (_verifyJoined(joined, from)) {
        case _ContactVerdict.ok:
          _scheduleRefresh();
        case _ContactVerdict.violation:
          await _leaveContactRoom(joined ?? r);
        case _ContactVerdict.unknown:
          // Noch nicht entscheidbar (Zustand nicht geladen): nie verlassen, anfordern; der Raum bleibt bis dahin unsichtbar.
          if (joined != null) _requestPeerMembership(joined, from);
          _scheduleRefresh();
      }
    } catch (e) {
      // Vorläufiger Fehler (Netz, Zeitüberschreitung): später erneut versuchen.
      c.retryAfter[r.id] = DateTime.now().add(const Duration(minutes: 1));
      AppLog.e('gateway', 'Kontakt-Einzelchat konnte nicht angenommen werden', e);
    }
  }

  /// Nachprüfung nach dem Beitritt mit **neu** gebautem Kontext: sicherer Verstoß, in Ordnung oder noch unbekannt.
  _ContactVerdict _verifyJoined(Room? joined, String from) {
    final f = _family;
    final familyRoom = _familyRoom();
    if (joined == null || f == null || familyRoom == null || !_participantsLoaded) return _ContactVerdict.unknown;
    final p = _contactPolicy;
    final state = p.contacts[from];
    if (!p.enabled || p.blocked.contains(from) || f.member(from) != null || from == f.myUserId) return _ContactVerdict.violation;
    if (state != ContactState.outgoing && state != ContactState.accepted) return _ContactVerdict.violation;
    if (!_canEncryptIn(joined)) return _ContactVerdict.violation;
    final count = joined.summary.mJoinedMemberCount;
    if (count == null) return _ContactVerdict.unknown;
    if (count + (joined.summary.mInvitedMemberCount ?? 0) > 2) return _ContactVerdict.violation;
    final facts = _roomFacts(joined, f.myUserId);
    if (facts.peerId != from) return facts.peerId == null ? _ContactVerdict.unknown : _ContactVerdict.violation;
    if (facts.peerMembership == PeerMembership.unknown) return _ContactVerdict.unknown;
    return ConversationPolicy.classify(facts, _policyContext(f, familyRoom.id)) == RoomClass.contactDirect
        ? _ContactVerdict.ok
        : _ContactVerdict.violation;
  }

  Future<void> _leaveContactRoom(Room r) async {
    _contacts.rememberFailed(r.id);
    // Das Austragen aus `m.direct` darf das Verlassen nicht verhindern: jedes für sich.
    try {
      await r.removeFromDirectChat();
    } catch (e) {
      AppLog.e('gateway', 'Kontakt-Raum konnte nicht aus den Direktchats entfernt werden', e);
    }
    try {
      await r.leave();
    } catch (e) {
      AppLog.e('gateway', 'Kontakt-Raum konnte nicht verlassen werden', e);
    }
  }

  @override
  bool isThreadOpen(String threadId) =>
      threadId == ChatThread.familyId || _dmTimelines.containsKey(threadId) || _contacts.timelines.containsKey(threadId);

  @override
  Future<void> openThread(String threadId) async {
    final c = _contacts;
    if (!c.peers.containsKey(threadId) || _dmPeers.containsKey(threadId) || c.timelines.containsKey(threadId)) return;
    if (!c.opening.add(threadId)) return;
    final epoch = _dmEpoch;
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
      // Nach dem Warten erneut prüfen: Familienwechsel, Blockieren, Richtlinie aus, Gegenüber nicht mehr beigetreten.
      final peer = c.peers[threadId];
      if (_disposed || epoch != _dmEpoch || _client != client || peer == null || !_stillContact(room, peer)) {
        t.cancelSubscriptions();
        return;
      }
      c.timelines[threadId] = t;
      _backfill(t, pages: SdkMatrixGateway.dmBackfillPages).ignore();
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Kontakt-Gespräch konnte nicht geöffnet werden', e);
    } finally {
      c.opening.remove(threadId);
    }
  }

  /// Ist [room] jetzt (mit frischem Kontext) ein beigetretener, zulässiger Kontakt-Einzelchat?
  bool _stillContact(Room room, String peer) {
    final f = _family;
    final familyRoom = _familyRoom();
    if (f == null || familyRoom == null || !_participantsLoaded) return false;
    final facts = _roomFacts(room, f.myUserId);
    return facts.peerId == peer &&
        facts.peerMembership == PeerMembership.join &&
        ConversationPolicy.classify(facts, _policyContext(f, familyRoom.id)) == RoomClass.contactDirect;
  }

  /// Raum eines Kontakt-Threads zum Senden: nur nach `openThread`, nur bei beigetretenem Gegenüber und eingestuftem Raum.
  // ignore: unused_element
  Room _requireContactRoom(String threadId, Room room) {
    final peer = _contacts.peers[threadId];
    if (peer == null || !_contacts.timelines.containsKey(threadId)) throw const GatewayException(GatewayError.notAllowed);
    if (!_canEncryptIn(room)) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!_stillContact(room, peer)) throw const GatewayException(GatewayError.notAllowed);
    // Geänderter Hauptschlüssel (B8): synchron neu auswerten (kein Netz) und vor „nicht erreichbar“ prüfen; alle Sendewege
    // (Text, Anhänge) laufen hierüber.
    final me = _family?.myUserId;
    if (me != null) _identityOf(peer, me, mirror: false);
    if (_identityChanged.contains(peer)) throw const GatewayException(GatewayError.notAllowed);
    // Ohne Schlüssel, mit denen das Gegenüber lesen kann, käme die Nachricht still unlesbar an (B5).
    if (_reachabilityOf(peer) == ContactReachability.notReachable) throw const GatewayException(GatewayError.peerNotReachable);
    return room;
  }

  @override
  Future<void> declineContactRequest(String roomId) async {
    final f = _family;
    final familyRoom = _familyRoom();
    final client = _client;
    final room = client?.getRoomById(roomId);
    if (f == null || familyRoom == null || client == null || room == null || !_participantsLoaded || !_contactPolicy.enabled) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    if (_contacts.failed.contains(roomId)) throw const GatewayException(GatewayError.notAllowed); // schon abgelehnt
    if (room.membership != Membership.invite ||
        ConversationPolicy.classify(_roomFacts(room, f.myUserId), _policyContext(f, familyRoom.id)) != RoomClass.contactRequest) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    _contacts.rememberFailed(roomId);
    try {
      await room.leave();
    } catch (e) {
      AppLog.e('gateway', 'Kontaktanfrage konnte nicht abgelehnt werden', e);
      throw _map(e);
    }
    _scheduleRefresh();
  }

  /// Verlässt ein Kontakt-Gespräch (nie den Familienchat, nie einen Einzelchat mit einem Mitglied). **Reihenfolge für den
  /// Controller:** erst hier verlassen, dann den Datensatz löschen (nach dem Löschen wäre der Raum nicht mehr
  /// `contactDirect` und damit nicht mehr erreichbar). Scheitert `leave()`, bleibt **alles unverändert** (auch `m.direct`,
  /// der Raum bleibt Kontakt-Thread, ein zweiter Versuch ist möglich); nur bei Erfolg wird `m.direct` bereinigt
  /// (bestmöglich), der Raum als verlassen gemerkt und der Zustand geräumt.
  @override
  Future<void> leaveConversation(String threadId) async {
    final c = _contacts;
    final room = _client?.getRoomById(threadId);
    if (threadId == ChatThread.familyId || _dmPeers.containsKey(threadId) || !c.peers.containsKey(threadId) || room == null) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    try {
      await room.leave();
    } catch (e) {
      AppLog.e('gateway', 'Kontakt-Gespräch konnte nicht verlassen werden', e);
      throw _map(e);
    }
    // Erst nach dem Verlassen: `m.direct` bereinigen (bestmöglich, wirft nie) und den Zustand räumen.
    try {
      await room.removeFromDirectChat();
    } catch (e) {
      AppLog.e('gateway', 'Kontakt-Gespräch konnte nicht aus den Direktchats entfernt werden', e);
    }
    c.rememberFailed(threadId);
    c.timelines.remove(threadId)?.cancelSubscriptions();
    c.peers.remove(threadId);
    c.messages.remove(threadId);
    c.titles.remove(threadId);
    c.names.remove(threadId);
    c.identity.remove(threadId);
    c.pending.remove(threadId);
    _scheduleRefresh();
  }
}
