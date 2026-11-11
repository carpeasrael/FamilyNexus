part of '../sdk_matrix_gateway.dart';

/// Datenprotokoll (AP-5): Inventar der Online- und lokalen Daten für den Datenbericht (#261).
mixin _DataInventoryModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  Room? _privateRoom();
  Room? _familyRoom();
  Room? _familyRoomAnyState();

  static const Duration inventoryTimeout = Duration(seconds: 10);

  /// Eigener Anzeigename für das lokale Protokoll (#261): nur aus dem, was lokal liegt, ohne Netzabfrage und ohne
  /// Zustandsänderung am Raum. Reihenfolge: eigenes `m.room.member` im beigetretenen Familienraum, dann im privaten
  /// Raum (erst Speicher, dann Datenbank), zuletzt der Profil-Zwischenspeicher des SDK. Der Name im
  /// `m.room.member` kann ein raumbezogener Name sein (E-89).
  Future<String?> _localDisplayName(Client c, String me) async {
    String? clean(String? raw) {
      final name = TextSanitizer.clean(raw ?? '', max: 80);
      return name.isEmpty ? null : name;
    }

    for (final room in [_familyRoom(), _privateRoom()]) {
      if (room == null) continue;
      try {
        final fromState = clean(room.getState(EventTypes.RoomMember, me)?.asUser(room).displayName);
        if (fromState != null) return fromState;
        final fromDb = clean((await c.database.getUser(me, room))?.displayName);
        if (fromDb != null) return fromDb;
      } catch (e) {
        AppLog.e('gateway', 'Anzeigename für das lokale Protokoll nicht lesbar', e);
      }
    }
    try {
      return clean((await c.database.getUserProfile(me))?.displayname);
    } catch (e) {
      AppLog.e('gateway', 'Profil-Zwischenspeicher für das lokale Protokoll nicht lesbar', e);
      return null;
    }
  }

  @override
  Future<OnlineInventory> dataInventory({bool refresh = true}) async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final me = c.userID!;
    String? displayName;
    var hasAvatar = false;
    if (refresh) {
      try {
        // Frisch vom Server, nicht aus dem Zwischenspeicher.
        final profile = await c.getUserProfile(me, maxCacheAge: Duration.zero).timeout(inventoryTimeout);
        final name = TextSanitizer.clean(profile.displayname ?? '', max: 80);
        displayName = name.isEmpty ? null : name;
        hasAvatar = profile.avatarUrl != null;
      } catch (e) {
        AppLog.e('gateway', 'Profil für das Datenprotokoll nicht abrufbar', e);
      }
      try {
        await refreshSecurity().timeout(inventoryTimeout);
      } catch (e) {
        AppLog.e('gateway', 'Geräteliste für das Datenprotokoll nicht abrufbar', e);
      }
    } else {
      displayName = await _localDisplayName(c, me);
    }
    final familyId = _familyRoomAnyState()?.id;
    final privateId = _privateRoom()?.id;
    final rooms = <InventoryRoom>[];
    for (final r in c.rooms) {
      final events = await c.database.getEventList(r);
      final types = <String, int>{};
      var attachments = 0;
      for (final e in events) {
        types.update(e.type, (n) => n + 1, ifAbsent: () => 1);
        if (e.type == EventTypes.Message && (e.content['file'] is Map || e.content['url'] is String)) attachments++;
      }
      rooms.add(InventoryRoom(
        id: r.id,
        kind: r.id == familyId
            ? InventoryRoomKind.family
            : r.id == privateId
                ? InventoryRoomKind.private
                : r.isDirectChat
                    ? InventoryRoomKind.direct
                    : InventoryRoomKind.other,
        name: TextSanitizer.clean(r.name, max: 80),
        encrypted: r.encrypted,
        membership: r.membership.name,
        joinedMembers: r.summary.mJoinedMemberCount ?? 0,
        invitedMembers: r.summary.mInvitedMemberCount ?? 0,
        cachedEvents: events.length,
        eventTypes: types,
        attachments: attachments,
      ));
    }
    return OnlineInventory(
      server: server?.toString() ?? '',
      homeserver: c.homeserver?.toString(),
      userId: me,
      deviceId: c.deviceID ?? '',
      displayName: displayName,
      hasAvatar: hasAvatar,
      devices: devices,
      crossSigning: c.userDeviceKeys[me]?.masterKey != null,
      keyBackup: c.encryption?.keyManager.enabled ?? false,
      accountDataTypes: c.accountData.keys.toList()..sort(),
      rooms: rooms,
      family: _family,
    );
  }
}
