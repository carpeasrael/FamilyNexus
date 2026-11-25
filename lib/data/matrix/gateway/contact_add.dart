part of '../sdk_matrix_gateway.dart';

/// Kontakt hinzufügen (#119, K3a-2b): Person prüfen ([probeContact]), Einzelchat anlegen ([startContactChat]),
/// Erreichbarkeit lesen. Der Datensatz entsteht **vor** dem Raum (Controller, K3b); das Gateway verlangt ihn und prüft nach
/// jedem `await` erneut. Fehler werden nur als Art und `errcode` geloggt, nie mit Kennung, Name oder Raum-ID.
mixin _ContactAddModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  bool? get _encryptionOverride;
  _ContactState get _contacts;
  ContactPolicy get _contactPolicy;
  int get _dmEpoch;
  bool get _disposed;
  Set<String> get _identityChanged;
  Family? get _family;
  bool get _participantsLoaded;
  Family _requireFamily();
  GatewayException _map(Object e);
  Future<void> _refresh();
  void _requestPeerMembership(Room r, String peer);
  Future<void> _leaveContactRoom(Room r);

  static const Duration probeTimeout = Duration(seconds: 15);
  static const Duration probeCacheAge = Duration(seconds: 60);
  static const int maxProbesPerHour = 20;
  static const int maxProbedIds = 50;
  static const int maxProbesInFlight = 4;

  /// Nur für Tests: Geräte der Person ohne Schlüsselabfrage (`null` = unbekannt; sonst je Gerät, ob Raumschlüssel dorthin
  /// geteilt würden). Ersetzt Abfrage **und** Lesen (Harness ohne vodozemac und Schlüsselserver).
  @visibleForTesting
  List<bool>? Function(String userId)? debugDevicesOf;

  bool get _encryptionAvailable => _encryptionOverride ?? _client?.encryptionEnabled ?? false;

  /// Geräte der Person aus den **bereits bekannten** Schlüsseln, ohne Netz: je Gerät `encryptToDevice`; `null`, wenn keine
  /// aktuellen Schlüssel vorliegen oder die Verschlüsselung nicht verfügbar ist (dann gilt „unbekannt“, nie „nicht erreichbar“).
  List<bool>? _devicesOf(String userId) {
    final seam = debugDevicesOf;
    if (seam != null) return seam(userId);
    final c = _client;
    if (c == null || !_encryptionAvailable) return null;
    final list = c.userDeviceKeys[userId];
    if (list == null || list.outdated) return null;
    return <bool>[for (final d in list.deviceKeys.values) d.encryptToDevice];
  }

  /// Erreichbarkeit synchron und ohne Netz (Anzeige, Senden), je Gegenüber kurz zwischengespeichert.
  // ignore: unused_element
  ContactReachability _reachabilityOf(String peer) {
    final now = DateTime.now();
    final useCache = debugDevicesOf == null;
    final cached = useCache ? _contacts.reachCache[peer] : null;
    if (cached != null && now.difference(cached.at) < const Duration(seconds: 60)) return cached.reach;
    final devices = _devicesOf(peer);
    final reach = ContactReach.of(keysKnown: devices != null, encryptable: devices ?? const <bool>[]);
    if (useCache) _contacts.reachCache[peer] = (at: now, reach: reach);
    return reach;
  }

  /// Fragt die Schlüssel der Person frisch ab (Fehler verschluckt das SDK; deshalb zählt nur, was danach vorliegt).
  Future<ContactReachability> _freshReachability(String userId) async {
    if (debugDevicesOf == null) {
      final c = _client;
      if (c == null || !_encryptionAvailable) return ContactReachability.unknown;
      try {
        await c.updateUserDeviceKeys(additionalUsers: <String>{userId});
      } catch (e) {
        AppLog.w('gateway', 'Schlüsselabfrage gescheitert (${e.runtimeType})');
        return ContactReachability.unknown;
      }
    }
    _contacts.reachCache.remove(userId);
    if (_identityChanged.contains(userId)) return ContactReachability.identityChanged;
    final devices = _devicesOf(userId);
    return ContactReach.of(keysKnown: devices != null, encryptable: devices ?? const <bool>[]);
  }

  /// Profil über den direkten Endpunkt (kein SDK-Cache, keine Fremdprofile in der SDK-Datenbank). Nur `M_NOT_FOUND` heißt
  /// „gibt es nicht“; alles andere (auch `M_FORBIDDEN`, Netz, Zeitablauf) ist „unbekannt“ und blockiert nichts.
  Future<(ContactExistence, String)> _fetchProfile(String userId) async {
    final c = _client;
    if (c == null) return (ContactExistence.unknown, '');
    try {
      final r = await c.request(RequestType.GET, '/client/v3/profile/${Uri.encodeComponent(userId)}');
      final name = r['displayname'];
      return (ContactExistence.yes, ContactNames.cleanName(name is String ? name : null));
    } on MatrixException catch (e) {
      AppLog.w('gateway', 'Profilabfrage gescheitert (${e.errcode})');
      return (e.errcode == 'M_NOT_FOUND' ? ContactExistence.no : ContactExistence.unknown, '');
    } catch (e) {
      AppLog.w('gateway', 'Profilabfrage gescheitert (${e.runtimeType})');
      return (ContactExistence.unknown, '');
    }
  }

  /// Kanonische Kennung (Servername kleingeschrieben, wie `ContactId.parse`): Servernamen sind nicht groß-/
  /// kleinschreibungsabhängig, sonst würde die eigene Kennung oder die eines Familienmitglieds mit anderer Schreibweise
  /// des Servers als Fremder gelten.
  String _canonical(String raw) {
    final id = ContactId.parse(raw);
    if (id == null) throw const GatewayException(GatewayError.invalidInput);
    return id;
  }

  void _requireUsable(Family f, String userId) {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    // Ohne vollständige Mitgliederliste könnte ein Familienmitglied wie ein Fremder aussehen (fail-closed, B6).
    if (userId == f.myUserId || !_participantsLoaded || !_contactPolicy.enabled) throw const GatewayException(GatewayError.notAllowed);
    if (_contactPolicy.blocked.contains(userId)) throw const GatewayException(GatewayError.notAllowed);
  }

  @override
  Future<ContactProbe> probeContact(String rawUserId) async {
    final f = _requireFamily();
    final userId = _canonical(rawUserId);
    _requireUsable(f, userId);
    if (f.member(userId) != null) {
      return ContactProbe(
        userId: userId,
        existence: ContactExistence.unknown,
        displayName: '',
        reachability: ContactReachability.unknown,
        isFamilyMember: true,
      );
    }
    final c = _contacts;
    final now = DateTime.now();
    final cached = c.probeCache[userId];
    if (cached != null && now.difference(cached.at) < probeCacheAge) return cached.probe;
    final running = c.probeInFlight[userId];
    if (running != null) return running;
    c.probeTimes.removeWhere((t) => now.difference(t) >= const Duration(hours: 1));
    if (c.probeTimes.length >= maxProbesPerHour || (!c.probedIds.contains(userId) && c.probedIds.length >= maxProbedIds) || c.probeSlots.length >= maxProbesInFlight) {
      throw const GatewayException(GatewayError.rateLimited);
    }
    c.probeTimes.add(now);
    c.probedIds.add(userId);
    final epoch = _dmEpoch;
    final client = _client;
    final future = _collectProbe(userId, epoch, client);
    c.probeInFlight[userId] = future;
    future.whenComplete(() => c.probeInFlight.remove(userId)).ignore();
    return future;
  }

  Future<ContactProbe> _collectProbe(String userId, int epoch, Client? client) async {
    final c = _contacts;
    final both = Future.wait<Object>(<Future<Object>>[_fetchProfile(userId), _freshReachability(userId)]);
    // Der Platz bleibt belegt, bis die Abfragen wirklich enden (nicht schon beim Zeitablauf).
    final slot = both.then<void>((_) {}, onError: (Object _) {});
    c.probeSlots.add(slot);
    slot.whenComplete(() => c.probeSlots.remove(slot)).ignore();
    var existence = ContactExistence.unknown;
    var name = '';
    var reach = ContactReachability.unknown;
    try {
      final r = await both.timeout(probeTimeout);
      final profile = r[0] as (ContactExistence, String);
      existence = profile.$1;
      name = profile.$2;
      reach = r[1] as ContactReachability;
    } on TimeoutException {
      AppLog.w('gateway', 'Personenprüfung: Zeitablauf');
    } catch (e) {
      AppLog.w('gateway', 'Personenprüfung gescheitert (${e.runtimeType})');
    }
    if (_disposed || epoch != _dmEpoch || _client != client) throw const GatewayException(GatewayError.notAllowed);
    final probe = ContactProbe(userId: userId, existence: existence, displayName: name, reachability: reach);
    // Unbekanntes wird nie zwischengespeichert: ein Netzfehler darf die Wiederholung nicht eine Minute sperren.
    if (existence != ContactExistence.unknown && reach != ContactReachability.unknown) c.probeCache[userId] = (at: DateTime.now(), probe: probe);
    return probe;
  }

  /// Gilt der Datensatz `outgoing` jetzt noch (Bereich an, nicht blockiert, kein Familienmitglied, Liste geladen)?
  bool _stillOutgoing(String userId) {
    final f = _family;
    final p = _contactPolicy;
    return f != null &&
        _participantsLoaded &&
        p.enabled &&
        p.contacts[userId] == ContactState.outgoing &&
        !p.blocked.contains(userId) &&
        f.member(userId) == null;
  }

  @override
  Future<String> startContactChat(String rawUserId) async {
    final f = _requireFamily();
    final userId = _canonical(rawUserId);
    _requireUsable(f, userId);
    if (f.member(userId) != null || _contactPolicy.contacts[userId] != ContactState.outgoing) {
      throw const GatewayException(GatewayError.notAllowed); // ohne Datensatz kein Raum
    }
    final c = _contacts;
    final client = _client!;
    // Vorhandenen Raum wiederverwenden (ohne neue Abfrage): zuerst eingestufte Kontakt-Threads, dann beigetretene,
    // verschlüsselte Räume mit dieser Person (auch solange der Mitgliedszustand noch unbekannt ist).
    for (final e in c.peers.entries) {
      if (e.value == userId && !c.failed.contains(e.key)) return e.key;
    }
    for (final r in client.rooms) {
      if (r.membership == Membership.join && r.directChatMatrixID == userId && !c.failed.contains(r.id) && r.encrypted) {
        _requestPeerMembership(r, userId);
        return r.id;
      }
    }
    if (!_encryptionAvailable) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!c.creating.add(userId)) throw const GatewayException(GatewayError.alreadyExists);
    final epoch = _dmEpoch;
    try {
      final reach = await _freshReachability(userId);
      if (reach == ContactReachability.notReachable) throw const GatewayException(GatewayError.peerNotReachable);
      if (reach == ContactReachability.unknown) throw const GatewayException(GatewayError.serverUnreachable);
      if (_disposed || epoch != _dmEpoch || _client != client || !_stillOutgoing(userId)) throw const GatewayException(GatewayError.notAllowed);
      // Nie einen vorhandenen, womöglich unverschlüsselten Raum wiederverwenden (wie `startDirectChat`).
      final roomId = await client.startDirectChat(
        userId,
        enableEncryption: true,
        skipExistingChat: true,
        preset: CreateRoomPreset.privateChat,
        initialState: <StateEvent>[
          StateEvent(type: 'm.room.history_visibility', stateKey: '', content: <String, Object?>{'history_visibility': 'shared'}),
        ],
      );
      // Während des Anlegens kann sich alles geändert haben: der Raum darf nicht verwaist bleiben.
      if (_disposed || epoch != _dmEpoch || _client != client || !_stillOutgoing(userId)) {
        final created = client.getRoomById(roomId);
        if (created != null) {
          await _leaveContactRoom(created);
        } else {
          c.rememberFailed(roomId);
        }
        throw const GatewayException(GatewayError.notAllowed);
      }
      await _refresh();
      for (final e in c.peers.entries) {
        if (e.value == userId) return e.key;
      }
      return roomId;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Kontakt-Gespräch konnte nicht angelegt werden (${e.runtimeType})', null);
      throw _map(e);
    } finally {
      c.creating.remove(userId);
    }
  }
}
