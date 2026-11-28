part of '../sdk_matrix_gateway.dart';

/// Verwaltung der Gruppen im Gateway (#119, K4-3, KONTAKTE §8.5): Mitglieder auflisten, einladen, entfernen (kick), Admin ernennen
/// und abstufen. Ergänzt [_ContactGroupsModule] (Zustand, Abgleich, Senden, Anlegen, Beitritt) und nutzt dessen Zwischenspeicher
/// und Sperren. Schreibt nie einen Datensatz und nie `familyAccountData`; der Controller (K4-3) schreibt die Datensätze.
mixin _ContactGroupAdminModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  _GroupState get _groups;
  ContactPolicy get _contactPolicy;
  int get _contactEpoch;
  bool get _disposed;
  bool _contactMembersComplete();
  bool _canEncryptIn(Room? room);
  bool _stillGroup(Room room);
  int? _groupSizeOf(Room r);
  Future<bool> _awaitMembers(Room r);
  void _throwIfLocked(GroupSendLock lock);
  Future<void> _refresh();
  void _scheduleRefresh();
  GatewayException _map(Object e);
  String _canonical(String raw);
  bool _isFamilyId(String userId);
  Future<ContactReachability> _freshReachability(String userId);
  ContactReachability _reachabilityOf(String peer);
  Set<String> get _identityChanged;
  bool _anyDeviceBlocked(String uid);
  Future<Map<String, Object?>?> _serverState(String roomId, String type);

  // ------------------------------------------------------------ Verwaltung (K4-3, §8.5)

  /// Die Gruppe für eine Verwaltungsoperation: angemeldet, Bereich an, Mitgliederliste der Familie vollständig, der Raum ist eine
  /// **beigetretene Gruppe**: Eintrag in [_GroupState.groups] **oder** (frische Einstufung `contactGroup`, Datensatz, beigetreten),
  /// dann läuft **einmal** ein Abgleich, danach muss der Eintrag da sein (so scheitert eine Einladung unmittelbar nach
  /// `createGroup` nicht am noch nicht gelaufenen Abgleich). Nach dem `await` werden Epoche und Client geprüft.
  Future<Room> _requireGroupForAdmin(String roomId) async {
    final client = _client;
    final me = client?.userID;
    if (client == null || me == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    if (!_contactPolicy.enabled || !_contactMembersComplete()) throw const GatewayException(GatewayError.notAllowed);
    var room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.join) throw const GatewayException(GatewayError.notAllowed);
    final epoch = _contactEpoch;
    if (!_groups.groups.containsKey(roomId)) {
      if (!_contactPolicy.groups.contains(roomId) || !_stillGroup(room)) throw const GatewayException(GatewayError.notAllowed);
      try {
        await _refresh();
      } catch (e) {
        AppLog.e('gateway', 'Gruppe konnte nicht abgeglichen werden (${e.runtimeType})', null);
        throw _map(e);
      }
      if (_disposed || epoch != _contactEpoch || _client != client) throw const GatewayException(GatewayError.notAllowed);
      room = client.getRoomById(roomId);
      if (room == null || !_groups.groups.containsKey(roomId)) throw const GatewayException(GatewayError.notAllowed);
    }
    // Das SDK hält Stufen (`m.room.power_levels`) und die meisten Mitgliedsereignisse eines nur teilweise geladenen Raums nicht im
    // Speicher (`Room.partial`, `client.dart:3161`); ohne das Nachladen aus der Datenbank (kein Netz) fiele `ownPowerLevel` auf
    // „Ersteller ⇒ 100, sonst 0“ zurück und das Ziel eines Entfernens hätte keinen lokalen Eintrag.
    try {
      await room.postLoad();
    } catch (e) {
      AppLog.e('gateway', 'Gruppenzustand konnte nicht geladen werden (${e.runtimeType})', null);
      throw _map(e);
    }
    if (_disposed || epoch != _contactEpoch || _client != client || !_groups.groups.containsKey(roomId)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    return room;
  }

  /// Nach einem `await` einer Verwaltungsoperation: Abmelden, Kontowechsel, Familienwechsel oder Datensatz weg ⇒ `notAllowed`.
  void _stillAdminValid(int epoch, Client? client, String roomId) {
    if (_disposed || epoch != _contactEpoch || _client != client || !_groups.groups.containsKey(roomId)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
  }

  static int _plInt(Object? v, int fallback) => v is int ? v : fallback;

  /// Stufe von [uid] aus dem Inhalt von `m.room.power_levels` (`users`, sonst `users_default`, sonst 0).
  static int _levelIn(Map<String, Object?> pl, String uid) {
    final users = pl['users'];
    final specific = users is Map ? users[uid] : null;
    return specific is int ? specific : _plInt(pl['users_default'], PowerLevels.member);
  }

  /// Rechte aus Stufe und Schwellen des Raumzustands (Matrix-Vorgaben, wenn eine Schwelle fehlt: `invite` 0, `kick` 50,
  /// `m.room.power_levels` und `m.room.name` über `state_default`, sonst 50).
  static GroupRights _rightsFor(String me, int myLevel, Map<String, Object?> pl) {
    final events = pl['events'];
    int ev(String type) {
      final v = events is Map ? events[type] : null;
      return v is int ? v : _plInt(pl['state_default'], PowerLevels.moderator);
    }

    return GroupRights(
      myUserId: me,
      myLevel: myLevel,
      inviteLevel: _plInt(pl['invite'], 0),
      kickLevel: _plInt(pl['kick'], PowerLevels.moderator),
      nameLevel: ev(EventTypes.RoomName),
      powerLevelsLevel: ev(EventTypes.RoomPowerLevels),
    );
  }

  GroupRights _localRights(Room room, String me) =>
      _rightsFor(me, room.ownPowerLevel.level, room.getState(EventTypes.RoomPowerLevels)?.content ?? const <String, Object?>{});

  /// Die Mitglieder der Gruppe für die Verwaltung. Quelle ist der Zwischenspeicher ([_GroupState.members], lokal vollständig oder
  /// abgerufen); bei G > 50 oder unbekannter Größe hält [_updateGroupMembers] keine Liste, dann kommen die **lokal bekannten**
  /// Einträge (`getParticipants`): möglicherweise unvollständig, nie ein Beleg für „leer“. Kein Netzzugriff.
  @override
  Future<List<GroupMember>> groupMembers(String roomId) async {
    final room = await _requireGroupForAdmin(roomId);
    final me = _client!.userID!;
    final g = _groups;
    final known = <String, GroupMembership>{};
    final cached = g.members[roomId];
    if (cached != null && g.membersLoaded.contains(roomId)) {
      known.addAll(cached);
    } else {
      for (final u in room.getParticipants(const <Membership>[Membership.join, Membership.invite])) {
        if (u.membership == Membership.join) {
          known[u.id] = GroupMembership.join;
        } else if (u.membership == Membership.invite) {
          known[u.id] = GroupMembership.invite;
        }
      }
    }
    final out = <GroupMember>[];
    for (final e in known.entries) {
      final uid = e.key;
      final isMe = uid == me;
      final family = !isMe && _isFamilyId(uid);
      final name = room.getState(EventTypes.RoomMember, uid)?.content['displayname'];
      final clean = ContactNames.cleanName(name is String ? name : null);
      final IdentityStatus identity;
      if (isMe) {
        identity = IdentityStatus.verified;
      } else if (family) {
        identity = (_identityChanged.contains(uid) || _anyDeviceBlocked(uid)) ? IdentityStatus.changed : IdentityStatus.unknown;
      } else {
        identity = (_identityChanged.contains(uid) || _anyDeviceBlocked(uid)) ? IdentityStatus.changed : (g.identity[uid] ?? IdentityStatus.unknown);
      }
      out.add(GroupMember(
        userId: uid,
        displayName: clean.isNotEmpty ? clean : ContactNames.title(null, uid),
        membership: e.value,
        power: room.getPowerLevelByUserId(uid).level,
        reachability: isMe ? ContactReachability.unknown : _reachabilityOf(uid),
        identity: identity,
        isFamily: family,
        isMe: isMe,
      ));
    }
    out.sort((a, b) {
      if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
      if (a.power != b.power) return b.power.compareTo(a.power);
      final n = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      return n != 0 ? n : a.userId.compareTo(b.userId);
    });
    return out;
  }

  /// Lädt eine Person ein. **Reihenfolge verbindlich:** (a) Gesundheit (Verschlüsselung, Regel `invite`, Verlauf `invited`;
  /// eine sendegesperrte Element-Gruppe lädt niemanden ein), (b) Recht, (c) Ziel (bestätigter Kontakt oder Familienmitglied,
  /// nicht ich, nicht blockiert, nicht schon dabei), (d) Größe **zuerst** ohne Netz (unbekannt ⇒ `serverUnreachable`, G ≥ 50 ⇒
  /// `groupFull`, jeweils ohne Abruf), nur bei bekanntem G ≤ 49 eine frische Liste, (e) frische Erreichbarkeit, (f) `invite`.
  /// Kein Datensatz, kein Pin (der Pin entsteht erst beim Beitritt).
  @override
  Future<void> inviteToGroup(String roomId, String rawUserId) async {
    final room = await _requireGroupForAdmin(roomId);
    final client = _client;
    final me = client!.userID!;
    final userId = _canonical(rawUserId);
    final g = _groups;
    if (!g.adminOps.add(roomId)) throw const GatewayException(GatewayError.groupBusy);
    final epoch = _contactEpoch;
    try {
      // (a) Gesundheit ohne Größe (joined: 0, invited: 0): die Größe prüft (d), eine zu große Gruppe meldet dort `groupFull`.
      final rule = room.getState(EventTypes.RoomJoinRules)?.content['join_rule'];
      final history = room.getState(EventTypes.HistoryVisibility)?.content['history_visibility'];
      _throwIfLocked(GroupHealth.evaluate(
        megolm: _canEncryptIn(room),
        joinRule: rule is String ? rule : null,
        historyVisibility: history is String ? history : null,
        joined: 0,
        invited: 0,
      ));
      // (b) Recht aus dem Raumzustand.
      if (!_localRights(room, me).canInvite) throw const GatewayException(GatewayError.notAllowed);
      // (c) Ziel: nur bestätigter Kontakt oder Familienmitglied.
      if (userId == me || _contactPolicy.blocked.contains(userId)) throw const GatewayException(GatewayError.notAllowed);
      if (!_isFamilyId(userId) && _contactPolicy.contacts[userId] != ContactState.accepted) throw const GatewayException(GatewayError.notAllowed);
      bool already() {
        final m = room.getState(EventTypes.RoomMember, userId)?.content['membership'];
        return m == 'join' || m == 'invite' || (g.members[roomId]?.containsKey(userId) ?? false);
      }

      if (already()) throw const GatewayException(GatewayError.alreadyExists);
      // (d) Größe zuerst, ohne Netz.
      final size = _groupSizeOf(room);
      if (size == null) throw const GatewayException(GatewayError.serverUnreachable);
      if (size >= ContactLimits.maxGroupMembers) throw const GatewayException(GatewayError.groupFull);
      final fresh = await _awaitMembers(room);
      _stillAdminValid(epoch, client, roomId);
      if (!fresh || g.members[roomId] == null) throw const GatewayException(GatewayError.serverUnreachable);
      if (already()) throw const GatewayException(GatewayError.alreadyExists);
      final exact = _groupSizeOf(room);
      if (exact == null) throw const GatewayException(GatewayError.serverUnreachable);
      if (exact >= ContactLimits.maxGroupMembers) throw const GatewayException(GatewayError.groupFull);
      // (e) Erreichbarkeit frisch.
      final reach = await _freshReachability(userId);
      _stillAdminValid(epoch, client, roomId);
      switch (reach) {
        case ContactReachability.reachable:
          break;
        case ContactReachability.notReachable:
          throw const GatewayException(GatewayError.peerNotReachable);
        case ContactReachability.unknown:
          throw const GatewayException(GatewayError.serverUnreachable);
        case ContactReachability.identityChanged:
          throw const GatewayException(GatewayError.notAllowed);
      }
      // (f) Einladen. Ohne Warten auf den Sync (`waitForSync: false`): die Schlüsselabfrage hat (e) erledigt, und ein
      // Zeitablauf des Wartens würde eine angekommene Einladung als Fehler melden.
      await room.invite(userId, waitForSync: false).timeout(SdkMatrixGateway.roomOpTimeout);
      g.members[roomId]?[userId] = GroupMembership.invite;
      if (!_disposed) _scheduleRefresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Einladung in die Gruppe fehlgeschlagen (${e.runtimeType})', null);
      throw _map(e);
    } finally {
      g.adminOps.remove(roomId);
    }
  }

  /// Entfernt ein Mitglied (kick). Das Ziel muss im **lokalen Raumzustand** `join` oder `invite` sein (fail-closed: bei Lazy
  /// Loading ist ein Entfernen nur für lokal bekannte Mitglieder möglich). [_GroupState.removing] sperrt das Senden **vor** dem
  /// `kick`; bei einer **definitiven** Fehlerantwort des Servers (Matrix-Fehler mit `errcode`) kam der `kick` nicht an und die
  /// Sperre fällt sofort, bei Zeitablauf oder Netzfehler bleibt sie (der `kick` kann noch ankommen) bis zum Beleg
  /// ([_releaseRemoving]) oder zur Obergrenze. Der Schlüsselwisch bleibt allein in [_wipeOutbound]. Die entfernte Person wird
  /// nicht blockiert.
  @override
  Future<void> removeFromGroup(String roomId, String rawUserId) async {
    final room = await _requireGroupForAdmin(roomId);
    final me = _client!.userID!;
    if (!MatrixIds.isUserId(rawUserId)) throw const GatewayException(GatewayError.invalidInput);
    final userId = rawUserId;
    final g = _groups;
    if (!g.adminOps.add(roomId)) throw const GatewayException(GatewayError.groupBusy);
    try {
      final m = room.getState(EventTypes.RoomMember, userId)?.content['membership'];
      if (m != 'join' && m != 'invite') throw const GatewayException(GatewayError.notFound);
      if (!_localRights(room, me).canRemove(userId, room.getPowerLevelByUserId(userId).level)) {
        throw const GatewayException(GatewayError.notAllowed);
      }
      final entry = _Removal(DateTime.now());
      g.removing.putIfAbsent(roomId, () => <String, _Removal>{})[userId] = entry;
      try {
        await room.kick(userId).timeout(SdkMatrixGateway.roomOpTimeout);
      } catch (e) {
        AppLog.e('gateway', 'Mitglied konnte nicht entfernt werden (${e.runtimeType})', null);
        // Nur eine Matrix-Fehlerantwort ist definitiv („kam nicht an“); Zeitablauf und Netzfehler lassen die Sperre stehen.
        if (e is MatrixException) {
          final map = g.removing[roomId];
          if (map != null && identical(map[userId], entry)) {
            map.remove(userId);
            if (map.isEmpty) g.removing.remove(roomId);
          }
        }
        throw _map(e);
      }
      if (!_disposed) _scheduleRefresh();
    } finally {
      g.adminOps.remove(roomId);
    }
  }

  /// Ernennt ein Mitglied zum Admin (Stufe 50, nie 100) oder entzieht ihm die Stufe (der Eintrag in `users` entfällt, dann gilt
  /// `users_default`). `m.room.power_levels` wird **frisch vom Server** gelesen (fehlt oder nicht abrufbar ⇒ Fehler ohne
  /// Schreiben); [GroupRights.canSetAdmin] läuft gegen die frisch gelesenen Stufen und Schwellen, geändert wird nur
  /// `users[userId]`. **Selbstabstufung** nur, wenn [GroupRights.isLastAdmin] für die bekannten beigetretenen Mitglieder (Stufen
  /// aus dem frischen `users`) `false` ergibt; bei G > 50 oder unvollständiger Liste ⇒ `notAllowed` (fail-closed). Das
  /// Lesen-Ändern-Schreiben ist gegen einen gleichzeitigen zweiten Admin nicht atomar (Risiko).
  @override
  Future<void> setGroupAdmin(String roomId, String rawUserId, {required bool admin}) async {
    final room = await _requireGroupForAdmin(roomId);
    final client = _client;
    final me = client!.userID!;
    if (!MatrixIds.isUserId(rawUserId)) throw const GatewayException(GatewayError.invalidInput);
    final userId = rawUserId;
    final g = _groups;
    if (!g.adminOps.add(roomId)) throw const GatewayException(GatewayError.groupBusy);
    final epoch = _contactEpoch;
    try {
      final current = await _serverState(roomId, EventTypes.RoomPowerLevels);
      _stillAdminValid(epoch, client, roomId);
      if (current == null) throw const GatewayException(GatewayError.serverUnreachable);
      final rights = _rightsFor(me, _levelIn(current, me), current);
      if (!rights.canSetAdmin(userId, _levelIn(current, userId), admin: admin)) throw const GatewayException(GatewayError.notAllowed);
      final m = room.getState(EventTypes.RoomMember, userId)?.content['membership'];
      if (userId != me && m != 'join') throw const GatewayException(GatewayError.notFound); // nur beigetretene Mitglieder
      if (userId == me && !admin) {
        // Der einzige Admin darf sich nicht abstufen (die Sperre liegt hier, `canSetAdmin` bleibt unverändert).
        final list = g.members[roomId];
        if (list == null || !g.membersLoaded.contains(roomId)) throw const GatewayException(GatewayError.notAllowed);
        final members = <GroupMember>[
          for (final e in list.entries) GroupMember(userId: e.key, displayName: '', membership: e.value, power: _levelIn(current, e.key), isMe: e.key == me),
        ];
        if (GroupRights.isLastAdmin(members)) throw const GatewayException(GatewayError.notAllowed);
      }
      final users = <String, Object?>{
        if (current['users'] is Map) ...(current['users']! as Map).cast<String, Object?>(),
      };
      if (admin) {
        users[userId] = GroupRights.levelFor(admin: true);
      } else {
        users.remove(userId);
      }
      final next = <String, Object?>{...current, 'users': users};
      await client.setRoomStateWithKey(roomId, EventTypes.RoomPowerLevels, '', next).timeout(SdkMatrixGateway.roomOpTimeout);
      if (!_disposed) _scheduleRefresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Stufe konnte nicht geändert werden (${e.runtimeType})', null);
      throw _map(e);
    } finally {
      g.adminOps.remove(roomId);
    }
  }
}
