part of '../sdk_matrix_gateway.dart';

/// Einladungen und Rollen (AP-5): Beitrittsanfrage, Einladungslinks, Rollen, Ablehnungs-Abfrage. Die `static`-Member
/// des Abschnitts bleiben in der Klasse (Tests rufen sie als `SdkMatrixGateway.<name>` auf); die Felder liegen hier.
mixin _InvitationsModule on ChangeNotifier implements MatrixGateway {
  Duration get _joinOpTimeout;
  Duration get _joinPollInterval;
  _AppClient? get _client;
  Family? get _family;
  Room? _familyRoom();
  Room? _familyRoomAnyState();
  HttpsOnlyClient get _http;
  bool _isCurrentFamily(Room room);
  Map<String, String> get _knockNonces;
  GatewayException _map(Object e);
  Future<void> _refresh();
  void _scheduleRefresh();
  Future<String?> _sendCalendar(Room room, String type, Map<String, Object?> content);
  void _warnPlaintext(Event e);

  @override
  List<PendingInvitation> get invitations {
    final client = _client;
    if (client == null || !client.isLogged()) return const <PendingInvitation>[];
    final me = client.userID!;
    return <PendingInvitation>[
      for (final r in client.rooms)
        // Einladungen in Einzelchats (is_direct) sind keine Familieneinladungen (E-39).
        if (r.membership == Membership.invite && r.getState(EventTypes.RoomMember, me)?.content['is_direct'] != true)
          PendingInvitation(
            roomId: r.id,
            roomName: TextSanitizer.clean(r.getLocalizedDisplayname(), max: FamilyRoomSpec.nameMax),
            inviterId: TextSanitizer.clean(r.getState(EventTypes.RoomMember, me)?.senderId ?? '', max: 80),
            inviterName: SdkMatrixGateway._inviterName(r, r.getState(EventTypes.RoomMember, me)?.senderId),
            requested: _joinRequest()?['room_id'] == r.id,
          ),
    ];
  }

  String? _joinRequestCache;

  /// Zeitpunkt der Anfrage in [_joinRequestCache], derselbe Wert wie `ts` im Vermerk.
  int? _joinRequestCacheTs;

  /// Lokal als beendet vermerkt, bis die geänderten Kontodaten per Sync eintreffen.
  bool _joinRequestCleared = false;

  Map<String, Object?>? _joinRequest() {
    final c = _client;
    if (c == null || !c.isLogged() || _joinRequestCleared) return null;
    final raw = c.accountData[SdkMatrixGateway.joinRequestAccountData]?.content;
    if (raw != null && raw['room_id'] is String && raw['ts'] is int) {
      final age = DateTime.now().toUtc().difference(DateTime.fromMillisecondsSinceEpoch(raw['ts']! as int, isUtc: true));
      if (age < SdkMatrixGateway.joinRequestMaxAge && !age.isNegative) return raw;
      return null;
    }
    final cached = _joinRequestCache;
    return cached == null ? null : <String, Object?>{'room_id': cached, 'ts': DateTime.now().toUtc().millisecondsSinceEpoch};
  }

  @override
  bool get joinRequestPending => _family == null && _joinRequest() != null && !_joinRejected;

  /// Abgelehnt = ein anderes Konto hat uns aus dem Raum entfernt, nachdem wir angeklopft haben. Das SDK
  /// führt weder den Knock noch den späteren Austritt in seinem Zustand; deshalb fragt ein Zeitgeber
  /// solange eine Anfrage offen ist den Server gezielt für diesen einen Raum ab ([_pollRejection]). Ein
  /// `leave` im normalen Sync löst dieselbe Abfrage sofort aus, entscheidet aber nicht selbst: Es ist
  /// Verlauf und kann zu einer früheren Anfrage gehören (E-81).
  @override
  bool get joinRequestRejected => _joinRejected && _family == null && _joinRequest() != null;

  bool _joinRejected = false;

  Timer? _rejectionTimer;

  /// Steigt mit jeder neuen oder beendeten Anfrage: Eine laufende Abfrage gehört dann zu einem alten Stand.
  int _joinRequestGeneration = 0;

  /// Ein `leave` im Sync kam während einer laufenden Abfrage: genau einmal wiederholen.
  bool _pollAgain = false;

  _JoinDiagnostic _joinDiagnostic = _JoinDiagnostic();

  @override
  String get joinRequestDiagnostic => _joinDiagnostic.render(timerActive: _rejectionTimer != null, now: DateTime.now());

  /// Nur für Tests: Läuft der Zeitgeber der Ablehnungs-Abfrage?
  @visibleForTesting
  bool get rejectionTimerActive => _rejectionTimer != null;

  void _watchJoinRequest() {
    _rejectionTimer ??= Timer.periodic(_joinPollInterval, (_) => _pollRejection('timer').ignore());
  }

  void _stopWatchingJoinRequest() {
    _rejectionTimer?.cancel();
    _rejectionTimer = null;
  }

  /// Ein `leave` des angefragten Raums im normalen Sync: sofort abfragen, statt auf den Zeitgeber zu warten.
  void _onSyncForJoinRequest(SyncUpdate update) {
    try {
      final req = _joinRequest();
      if (req == null || _family != null || _joinRejected) return;
      if (update.rooms?.leave?.containsKey(req['room_id']) != true) return;
      _pollRejection('sync').ignore();
    } catch (e) {
      AppLog.w('gateway', 'Ablehnung der Beitrittsanfrage: Sync konnte nicht ausgewertet werden');
    }
  }

  /// Zähler der Abfragen; macht jeden Filter einmalig (siehe [SdkMatrixGateway.rejectionPollFilter]). Startwert aus der Uhr,
  /// damit auch nach einem Neustart keine Antwort aus der vorigen Sitzung wiederkommt.
  int _rejectionPolls = DateTime.now().millisecondsSinceEpoch;

  bool _rejectionPollRunning = false;

  /// Nur für Tests: eine Abfrage wie vom Zeitgeber.
  @visibleForTesting
  Future<void> pollRejectionForTest() => _pollRejection('timer');

  /// [trigger]: `timer`, `sync` oder `start`.
  Future<void> _pollRejection(String trigger) async {
    final c = _client;
    final req = _joinRequest();
    if (c == null || !c.isLogged() || req == null || _family != null) {
      _stopWatchingJoinRequest();
      return;
    }
    if (_joinRejected) return;
    // Eine hängende Abfrage nicht mit weiteren überholen: Antworten kämen sonst durcheinander an.
    if (_rejectionPollRunning) {
      if (trigger == 'sync') _pollAgain = true;
      return;
    }
    // Bei stehendem Sync läge im Vermerk noch die alte Anfrage. Ein neuerer Vermerk (anderes Gerät) gewinnt.
    final cached = _joinRequestCache;
    final cachedTs = _joinRequestCacheTs;
    if (cached != null && cachedTs != null && req['room_id'] != cached && (req['ts']! as int) < cachedTs) {
      // Die Abfrage-Schleife läuft: Ohne Zeit läse sich der Dauerfall in Anhang G als „App fragt nicht ab“.
      _joinDiagnostic.checked(trigger, DateTime.now());
      _noteJoinState('staleNote');
      return;
    }
    _rejectionPollRunning = true;
    try {
      await _pollRejectionOnce(c, req, trigger);
    } finally {
      _rejectionPollRunning = false;
    }
    if (_pollAgain) {
      _pollAgain = false;
      await _pollRejection('sync');
    }
  }

  void _noteJoinState(String state) {
    final changed = _joinDiagnostic.state != state;
    _joinDiagnostic.note(state);
    if (changed && (state == 'noRoom' || state == 'knock')) {
      AppLog.w('gateway', 'Ablehnung der Beitrittsanfrage: Zustand $state');
    }
  }

  Future<void> _pollRejectionOnce(Client c, Map<String, Object?> req, String trigger) async {
    final roomId = req['room_id']! as String;
    final me = c.userID!;
    final generation = _joinRequestGeneration;
    var phase = 'auth';
    _joinDiagnostic.polled(trigger, DateTime.now());
    try {
      final base = c.homeserver;
      if (base == null || base.scheme != 'https') {
        _noteJoinState('notHttps');
        return;
      }
      await c.ensureNotSoftLoggedOut().timeout(_joinOpTimeout);
      final filter = SdkMatrixGateway.rejectionPollFilter(roomId, ++_rejectionPolls);
      final uri = base.replace(
        path: '/_matrix/client/v3/sync',
        queryParameters: <String, String>{'filter': filter, 'timeout': '0', 'set_presence': 'offline'},
      );
      final req2 = http.Request('GET', uri)..headers['authorization'] = 'Bearer ${c.accessToken}';
      phase = 'headers';
      final res = await _http.send(req2).timeout(_joinOpTimeout);
      phase = 'body';
      // `timeout` am Strom beendet das Abo; am Future hinge der Körper weiter und damit jede spätere Abfrage.
      final body = await http.ByteStream(res.stream.timeout(_joinOpTimeout)).bytesToString();
      if (generation != _joinRequestGeneration) return;
      if (res.statusCode != 200) {
        // Nur der Status (keine Raum- oder Personendaten): So lässt sich eine nie eintreffende Ablehnung (#43) zuordnen.
        AppLog.w('gateway', 'Ablehnung der Beitrittsanfrage: Abfrage lieferte HTTP ${res.statusCode}');
        _noteJoinState('http(${res.statusCode})');
        return;
      }
      final data = json.decode(body);
      final rooms = JsonRead.map(JsonRead.at(data, 'rooms'));
      final leave = JsonRead.map(JsonRead.path(rooms, <Object?>['leave', roomId]));
      if (leave == null) {
        bool inSection(String section) => JsonRead.map(JsonRead.at(rooms, section))?.containsKey(roomId) == true;
        _noteJoinState(inSection('knock') ? 'knock' : (inSection('invite') ? 'invite' : (inSection('join') ? 'join' : 'noRoom')));
        return;
      }
      final events = <Object?>[
        ...?JsonRead.list(JsonRead.path(leave, <Object?>['state', 'events'])),
        ...?JsonRead.list(JsonRead.path(leave, <Object?>['timeline', 'events'])),
      ];
      Map<Object?, Object?>? last;
      for (final e in events) {
        if (e is! Map || e['type'] != 'm.room.member' || e['state_key'] != me) continue;
        if (last == null || (JsonRead.integer(e['origin_server_ts']) ?? 0) >= (JsonRead.integer(last['origin_server_ts']) ?? 0)) last = e;
      }
      if (last == null) {
        AppLog.w('gateway', 'Ablehnung der Beitrittsanfrage: Raum unter „verlassen“, aber ohne eigenes Mitgliedsereignis');
        _noteJoinState('leaveNoOwnEvent');
        return;
      }
      final rejected = SdkMatrixGateway.isKnockRejection(last, me: me, requestedAt: req['ts']! as int);
      if (!rejected) {
        final content = last['content'];
        final unsigned = last['unsigned'];
        final membership = SdkMatrixGateway.membershipLabel(JsonRead.at(content, 'membership'));
        final previous = SdkMatrixGateway.membershipLabel(JsonRead.at(JsonRead.at(unsigned, 'prev_content'), 'membership'));
        final own = last['sender'] == me;
        final offset = ((JsonRead.integer(last['origin_server_ts']) ?? 0) - (req['ts']! as int)) ~/ 1000;
        AppLog.w(
          'gateway',
          'Ablehnung der Beitrittsanfrage: Ereignis nicht als Ablehnung gewertet '
          '(membership=$membership, eigenes=$own, vorher=$previous, Versatz=${offset}s)',
        );
        _noteJoinState('leaveOther');
        _joinDiagnostic.leaveOther(membership: membership, previous: previous, own: own, offsetSeconds: offset);
      }
      if (rejected) {
        _joinRejected = true;
        _noteJoinState('leaveRejected');
        _joinDiagnostic.detectedAt = DateTime.now();
        _stopWatchingJoinRequest();
        notifyListeners();
      }
    } on TimeoutException {
      if (generation != _joinRequestGeneration) return;
      _joinDiagnostic.timedOut(phase);
      _noteJoinState('timeout($phase)');
      AppLog.w('gateway', 'Ablehnung der Beitrittsanfrage: Zeitüberschreitung ($phase)');
    } catch (e) {
      if (generation != _joinRequestGeneration) return;
      _noteJoinState('failed(${SdkMatrixGateway.failureClass(e)})');
      AppLog.w('gateway', 'Ablehnung der Beitrittsanfrage konnte nicht geprüft werden');
    }
  }

  Future<void> _clearJoinRequest() async {
    _joinRejected = false;
    _joinRequestGeneration++;
    _pollAgain = false;
    _stopWatchingJoinRequest();
    _joinRequestCache = null;
    _joinRequestCacheTs = null;
    _joinRequestCleared = true;
    final c = _client;
    if (c == null || !c.isLogged() || c.accountData[SdkMatrixGateway.joinRequestAccountData]?.content.isEmpty != false) return;
    try {
      await c.setAccountData(c.userID!, SdkMatrixGateway.joinRequestAccountData, <String, Object?>{});
    } catch (e) {
      AppLog.e('gateway', 'Anfrage-Vermerk nicht entfernt', e);
    }
  }

  @override
  Future<void> cancelJoinRequest() async {
    final client = _client;
    final req = _joinRequest();
    if (client == null || req == null) return;
    try {
      await client.leaveRoom(req['room_id']! as String).timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (e) {
      AppLog.w('gateway', 'Zurückziehen der Anfrage serverseitig nicht bestätigt');
    }
    await _clearJoinRequest();
    notifyListeners();
  }

  /// Familie und eigene Rolle; Moderatorrechte werden hier erneut geprüft.
  Family _requireFamily() {
    final f = _family;
    if (f == null) throw const GatewayException(GatewayError.notFound);
    return f;
  }

  FamilyMember _requireMember(Family f, String userId) {
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    final m = f.member(userId);
    if (m == null) throw const GatewayException(GatewayError.notFound);
    return m;
  }

  Map<String, int> _issuedInvites() {
    final raw = _client?.accountData[SdkMatrixGateway.invitesAccountData]?.content;
    final out = <String, int>{};
    if (raw == null) return out;
    for (final e in raw.entries) {
      final v = e.value;
      if (InviteLink.isNonce(e.key) && v is int) out[e.key] = v;
    }
    return out;
  }

  Future<void> _storeInvites(Map<String, int> invites) async {
    final c = _client;
    if (c == null || !c.isLogged()) return;
    await c.setAccountData(c.userID!, SdkMatrixGateway.invitesAccountData, <String, Object?>{...invites});
  }

  @override
  Future<String> createInviteLink({Duration validity = InviteLink.defaultValidity, String? accountServer}) async {
    final f = _requireFamily();
    if (!Permissions.canInvite(f)) throw const GatewayException(GatewayError.notAllowed);
    final via = f.roomId.substring(f.roomId.indexOf(':') + 1);
    final now = DateTime.now();
    final nonce = SdkMatrixGateway._randomNonce();
    final String link;
    try {
      link = InviteLink.create(
        roomId: f.roomId,
        via: via,
        inviter: f.myUserId,
        now: now,
        validity: validity,
        nonce: nonce,
        ownHost: SdkMatrixGateway._ownHostOf(f.myUserId),
        inviterName: f.member(f.myUserId)?.displayName,
        accountServer: accountServer,
      );
    } on ArgumentError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final invites = _issuedInvites()..removeWhere((_, exp) => exp < nowSec - 86400);
    invites[nonce] = now.toUtc().add(validity).millisecondsSinceEpoch ~/ 1000;
    try {
      await _storeInvites(invites);
    } catch (e) {
      AppLog.e('gateway', 'Einladung konnte nicht vermerkt werden', e);
      throw _map(e);
    }
    _roomTickets[nonce] = invites[nonce]!;
    await _publishTicket(InviteTicket(nonce: nonce, expires: invites[nonce]!));
    return link;
  }

  /// Link-IDs, die Moderatoren im Familienraum vermerkt haben (`{id: Ablauf in Unix-Sekunden}`), und
  /// verbrauchte IDs. Ergänzt die eigenen Kontodaten, damit jeder Moderator Anfragen prüfen kann (E-49).
  final Map<String, int> _roomTickets = <String, int>{};

  final Set<String> _usedTickets = <String>{};

  /// Meldet einen Link-Vermerk an die anderen Moderatoren. Scheitert das, bleibt der Link für den
  /// Aussteller selbst gültig; deshalb nur eine Warnung statt eines Fehlers.
  Future<void> _publishTicket(InviteTicket ticket) async {
    final room = _familyRoom();
    if (room == null) return;
    if (!_isCurrentFamily(room)) {
      AppLog.w('gateway', 'Link-Vermerk nicht gesendet: Familie wechselt gerade');
      return;
    }
    try {
      await _sendCalendar(room, InviteTicket.type, ticket.encode());
    } catch (e) {
      AppLog.w('gateway', 'Link-Vermerk konnte nicht an andere Moderatoren gesendet werden');
    }
  }

  /// Liest die Link-Vermerke aus dem Verlauf des Familienraums. Nur verschlüsselt angekommene Vermerke von Moderatoren
  /// zählen (#138).
  void _readTickets(Room room, Timeline timeline) {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    for (final e in timeline.events) {
      if (e.type != InviteTicket.type || e.redacted || e.status.isError) continue;
      if (!arrivedEncrypted(e)) {
        _warnPlaintext(e);
        continue;
      }
      if (room.getPowerLevelByUserId(e.senderId).level < PowerLevels.moderator) continue;
      final t = InviteTicket.decode(e.content, nowSeconds: nowSec);
      if (t == null) continue;
      if (t.used) {
        _usedTickets.add(t.nonce);
      } else {
        _roomTickets[t.nonce] = t.expires;
      }
    }
  }

  RequestCheck _checkRequest(String? reason) {
    if (reason == null || !reason.startsWith(SdkMatrixGateway.knockReasonPrefix)) return RequestCheck.unknown;
    final nonce = reason.substring(SdkMatrixGateway.knockReasonPrefix.length);
    if (nonce == SdkMatrixGateway.knockCodeMarker) return RequestCheck.code;
    if (!InviteLink.isNonce(nonce)) return RequestCheck.unknown;
    if (_usedTickets.contains(nonce)) return RequestCheck.unknown;
    final exp = _issuedInvites()[nonce] ?? _roomTickets[nonce];
    if (exp == null) return RequestCheck.unknown;
    return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 < exp ? RequestCheck.valid : RequestCheck.expired;
  }

  @override
  Future<void> requestToJoin(InviteLink link) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!link.isValidAt(DateTime.now())) throw const GatewayException(GatewayError.invalidInput);
    if (!InviteLink.viaMatchesRoom(link.roomId, link.via, ownHost: SdkMatrixGateway._ownHostOf(client.userID!))) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    await _knock(link.roomId, link.via, '${SdkMatrixGateway.knockReasonPrefix}${link.nonce}');
  }

  @override
  Future<void> requestToJoinByCode(String code) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final roomId = FamilyCode.parse(code);
    if (roomId == null) throw const GatewayException(GatewayError.invalidInput);
    await _knock(roomId, FamilyCode.serverOf(roomId), '${SdkMatrixGateway.knockReasonPrefix}${SdkMatrixGateway.knockCodeMarker}');
  }

  Future<void> _knock(String roomId, String via, String reason) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final existing = _familyRoomAnyState();
    if (existing != null && existing.membership != Membership.leave && existing.membership != Membership.ban) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    if (ServerUrl.tryParse(via) == null) throw const GatewayException(GatewayError.invalidInput);
    try {
      // Das SDK bietet keinen Knock-Aufruf; schmaler Rohaufruf gemäß Matrix-Spezifikation.
      // Kurzlebige Zugangsdaten (OAuth) vorher auffrischen, weil der Rohaufruf das nicht selbst tut.
      await client.ensureNotSoftLoggedOut().timeout(_joinOpTimeout);
      final base = client.homeserver;
      if (base == null || base.scheme != 'https') throw const GatewayException(GatewayError.serverUnsupported);
      final uri = base.replace(
        path: '/_matrix/client/v3/knock/${Uri.encodeComponent(roomId)}',
        queryParameters: <String, String>{'server_name': via},
      );
      final req = http.Request('POST', uri)
        ..headers['authorization'] = 'Bearer ${client.accessToken}'
        ..headers['content-type'] = 'application/json'
        ..body = json.encode(<String, Object?>{'reason': reason});
      final res = await _http.send(req).timeout(_joinOpTimeout);
      if (res.statusCode != 200) {
        final body = await http.ByteStream(res.stream.timeout(_joinOpTimeout)).bytesToString();
        final error = SdkMatrixGateway.knockError(res.statusCode, body);
        // Nur Status und Fehlercode protokollieren (keine Raum- oder Personendaten), damit sich ein
        // „Unbekannter Fehler.“ beim nächsten Mal zuordnen lässt (#25).
        AppLog.w('gateway', 'Beitrittsanfrage abgelehnt: HTTP ${res.statusCode} ${SdkMatrixGateway._errcodeOf(body) ?? '-'} → ${error.error.name}');
        throw error;
      }
      // Die Anfrage gilt; der Körper wird nicht gebraucht. Verwerfen statt warten, damit ein hängender
      // Strom weder die Anfrage scheitern lässt noch eine zweite auslöst.
      res.stream.listen(null).cancel().ignore();
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
      _joinRequestGeneration++;
      _joinRequestCache = roomId;
      _joinRequestCacheTs = ts;
      _joinRequestCleared = false;
      _joinRejected = false;
      // Die Diagnose gehört zu einer Anfrage: Ein altes `Erkannt` stünde sonst neben dem neuen Zustand.
      _joinDiagnostic = _JoinDiagnostic();
      _watchJoinRequest();
      await client.setAccountData(client.userID!, SdkMatrixGateway.joinRequestAccountData, <String, Object?>{
        'room_id': roomId,
        'ts': ts,
      });
      notifyListeners();
      _scheduleRefresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Beitrittsanfrage fehlgeschlagen', e);
      throw _map(e);
    }
  }

  Future<void> _roomOp(Future<void> Function(Room room) op) async {
    final room = _familyRoom();
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (!_isCurrentFamily(room)) throw const GatewayException(GatewayError.serverUnreachable);
    try {
      await op(room).timeout(SdkMatrixGateway.roomOpTimeout);
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Raumaktion fehlgeschlagen', e);
      throw _map(e);
    }
  }

  @override
  Future<void> inviteUser(String userId) async {
    final f = _requireFamily();
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (!Permissions.canInvite(f)) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.invite(userId));
  }

  @override
  Future<void> approveRequest(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canDecideRequest(f, m)) throw const GatewayException(GatewayError.notAllowed);
    // Nur Anfragen mit eigenem, gültigem Link (wird dabei verbraucht, S2) oder per Familien-Code (E-65).
    if (m.request != RequestCheck.valid && m.request != RequestCheck.code) throw const GatewayException(GatewayError.notAllowed);
    final nonce = _knockNonces[userId];
    final viaLink = nonce != null && InviteLink.isNonce(nonce);
    if (viaLink) {
      // Der Stand aus [m] kann veraltet sein: erneut prüfen und den Link vor dem ersten `await` verbrauchen,
      // damit eine zweite, gleichzeitige Bestätigung mit derselben Link-ID scheitert (Pen-Test F-01).
      if (_checkRequest('${SdkMatrixGateway.knockReasonPrefix}$nonce') != RequestCheck.valid) throw const GatewayException(GatewayError.notAllowed);
      _usedTickets.add(nonce);
    }
    try {
      // Die Link-ID steht im Grund der Einladung; so erkennen auch andere Moderator-Geräte den Link als verbraucht.
      await _roomOp((room) => room.invite(userId, reason: viaLink ? '${SdkMatrixGateway.knockReasonPrefix}$nonce' : null));
    } catch (_) {
      // Einladung gescheitert: Link-ID wieder freigeben, Fehler unverändert weiter.
      if (viaLink) _usedTickets.remove(nonce);
      rethrow;
    }
    if (viaLink) {
      await _publishTicket(InviteTicket(nonce: nonce, expires: _roomTickets[nonce] ?? _issuedInvites()[nonce] ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 60, used: true));
      final invites = _issuedInvites()..remove(nonce);
      try {
        await _storeInvites(invites);
      } catch (e) {
        AppLog.w('gateway', 'Verbrauchter Link nicht entfernt');
      }
    }
  }

  @override
  Future<void> rejectRequest(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canDecideRequest(f, m) && !Permissions.canRemove(f, m)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    await _roomOp((room) => room.kick(userId));
  }

  @override
  Future<void> promote(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canPromote(f, m)) throw const GatewayException(GatewayError.notAllowed);
    // Der Stand kommt vom Server, nicht aus dem lokalen Zwischenspeicher: `Room.setPower` kopiert den
    // Zwischenspeicher, und ein veralteter Stand (z. B. zweite Ernennung vor dem Abgleich) würde einen
    // eben ernannten, gleichrangigen Moderator wieder herabstufen – der Server lehnt das ab (Issue #7).
    await _roomOp((room) async {
      final current = await room.client.getRoomStateWithKey(room.id, EventTypes.RoomPowerLevels, '');
      final users = <String, Object?>{
        if (current['users'] case final Map<String, Object?> known) ...known,
        userId: PowerLevels.moderator,
      };
      await room.client.setRoomStateWithKey(room.id, EventTypes.RoomPowerLevels, '', <String, Object?>{...current, 'users': users});
    });
  }

  @override
  Future<void> removeMember(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canRemove(f, m)) throw const GatewayException(GatewayError.notAllowed);
    // Das SDK verwirft beim Weggang eines Mitglieds die ausgehende Megolm-Sitzung;
    // die nächste Nachricht nutzt eine neue Sitzung (Schlüsselrotation).
    await _roomOp((room) => room.kick(userId));
  }

  @override
  Future<void> renameFamily(String name) async {
    final f = _requireFamily();
    final n = name.trim();
    if (n.isEmpty || n.length > FamilyRoomSpec.nameMax) throw const GatewayException(GatewayError.invalidInput);
    if (!Permissions.canConfigure(f)) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.setName(n));
  }

  @override
  Future<void> acceptInvitation(String roomId) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.invite) throw const GatewayException(GatewayError.notFound);
    final existing = _familyRoomAnyState();
    if (existing != null && existing.membership != Membership.leave && existing.membership != Membership.ban) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    final previous = client.accountData[SdkMatrixGateway.familyAccountData]?.content;
    var joined = false;
    try {
      // Zuerst der Vermerk, dann der Beitritt: scheitert der Beitritt, wird der Vermerk zurückgenommen
      // (kein halber Beitritt, K2).
      await client.setAccountData(client.userID!, SdkMatrixGateway.familyAccountData, <String, Object?>{'room_id': roomId});
      await client.joinRoomById(roomId).timeout(SdkMatrixGateway.roomOpTimeout);
      joined = true;
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Beitritt noch nicht im Sync');
      }
      // Ein fremder Raum ohne Ende-zu-Ende-Verschlüsselung wird nie zur Familie (S5).
      final joinedRoom = client.getRoomById(roomId);
      if (joinedRoom == null || !joinedRoom.encrypted || joinedRoom.getState(EventTypes.Encryption)?.content['algorithm'] != 'm.megolm.v1.aes-sha2') {
        await joinedRoom?.leave();
        throw const GatewayException(GatewayError.encryptionUnavailable);
      }
      await _clearJoinRequest();
      await _refresh();
    } catch (e) {
      AppLog.e('gateway', 'Einladung konnte nicht angenommen werden', e);
      if (!joined || e is GatewayException) {
        try {
          await client.setAccountData(client.userID!, SdkMatrixGateway.familyAccountData, previous ?? <String, Object?>{});
        } catch (_) {
          AppLog.w('gateway', 'Familienvermerk nicht zurückgesetzt');
        }
      }
      throw _map(e);
    }
  }

  @override
  Future<void> declineInvitation(String roomId) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.invite) throw const GatewayException(GatewayError.notFound);
    try {
      await room.leave().timeout(SdkMatrixGateway.roomOpTimeout);
      _scheduleRefresh();
    } catch (e) {
      throw _map(e);
    }
  }
}
