part of '../sdk_matrix_gateway.dart';

/// Kontakt hinzufügen (#119, K3a-2b): Person prüfen ([probeContact]), Einzelchat anlegen ([startContactChat]),
/// Erreichbarkeit lesen. Der Datensatz entsteht **vor** dem Raum (Controller, K3b); das Gateway verlangt ihn und prüft nach
/// jedem `await` erneut. Fehler werden nur als Art und `errcode` geloggt, nie mit Kennung, Name oder Raum-ID.
mixin _ContactAddModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  bool? get _encryptionOverride;
  _ContactState get _contacts;
  ContactPolicy get _contactPolicy;
  int get _contactEpoch;
  bool get _disposed;
  Set<String> get _identityChanged;
  bool _contactMembersComplete();
  bool _isFamilyId(String userId);
  bool _anyDeviceBlocked(String uid);
  Map<String, String> get _contactSessionPins;
  Map<String, String> get _contactAcceptedPins;
  LocalIdentityPins get _localPins;
  IdentityStatus _identityOf(String uid, String me, {bool mirror = true});
  GatewayException _map(Object e);
  Future<void> _refresh();
  void _requestPeerMembership(Room r, String peer);
  Future<void> _leaveContactRoom(Room r);

  static const Duration probeTimeout = Duration(seconds: 15);
  static const Duration probeCacheAge = Duration(seconds: 60);
  static const int maxProbesPerHour = 20;
  static const int maxProbedIds = 50;
  static const int maxProbesInFlight = 4;

  /// Obergrenze der Personen je gemeinsamer Schlüsselabfrage ([_freshReachabilityMany]): Gruppen haben höchstens 50 Mitglieder.
  static const int maxFreshUsers = 50;

  /// Nur für Tests: Geräte der Person ohne Schlüsselabfrage (`null` = unbekannt; sonst je Gerät, ob Raumschlüssel dorthin
  /// geteilt würden). Ersetzt Abfrage **und** Lesen (Harness ohne vodozemac und Schlüsselserver).
  @visibleForTesting
  List<bool>? Function(String userId)? debugDevicesOf;

  /// Nur für Tests: Zahl der gemeinsamen Schlüsselabfragen für Gruppen ([_freshReachabilityMany]).
  @visibleForTesting
  int debugFreshQueries = 0;

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
    // Geänderter Hauptschlüssel hat Vorrang vor „nicht erreichbar“ (die Geräte sind dann gesperrt, B8).
    if (_identityChanged.contains(peer)) return ContactReachability.identityChanged;
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
    // Geänderter Schlüssel oder von der App gesperrte Geräte (auch nach einem Neustart): erst neu auswerten, dann entscheiden.
    if (_lockedByIdentity(userId)) return ContactReachability.identityChanged;
    final devices = _devicesOf(userId);
    return ContactReach.of(keysKnown: devices != null, encryptable: devices ?? const <bool>[]);
  }

  /// Fragt die Schlüssel **mehrerer** Personen mit **einer** Anfrage ab (Gruppen, #119, K4-2b, §3.3 Zeile 7), höchstens
  /// [maxFreshUsers]; darüber hinaus wird nicht gefragt (diese bleiben `unknown`). Wie [_freshReachability]: Fehler verschluckt das
  /// SDK, deshalb zählt nur, was danach vorliegt. Die Sondergrenzen von `probeContact` (20/h) gelten hier nicht.
  // ignore: unused_element
  Future<Map<String, ContactReachability>> _freshReachabilityMany(Iterable<String> userIds) async {
    debugFreshQueries++;
    final ids = userIds.toSet().take(maxFreshUsers).toSet();
    if (ids.isEmpty) return const <String, ContactReachability>{};
    if (debugDevicesOf == null) {
      final c = _client;
      if (c == null || !_encryptionAvailable) return <String, ContactReachability>{for (final id in ids) id: ContactReachability.unknown};
      try {
        await c.updateUserDeviceKeys(additionalUsers: ids);
      } catch (e) {
        AppLog.w('gateway', 'Schlüsselabfrage gescheitert (${e.runtimeType})');
        return <String, ContactReachability>{for (final id in ids) id: ContactReachability.unknown};
      }
    }
    final out = <String, ContactReachability>{};
    for (final id in ids) {
      _contacts.reachCache.remove(id);
      if (_lockedByIdentity(id)) {
        out[id] = ContactReachability.identityChanged;
        continue;
      }
      final devices = _devicesOf(id);
      out[id] = ContactReach.of(keysKnown: devices != null, encryptable: devices ?? const <bool>[]);
    }
    return out;
  }

  /// Ist [id] durch einen geänderten Schlüssel oder durch von der App gesperrte Geräte gesperrt (Pin-Sackgasse, K3c-1)?
  /// Nach der frischen Schlüsselabfrage wird die Identität **einmal neu berechnet**, aber nur, wenn die Person schon
  /// auffällig ist (geändert, gesperrt) oder ein Pin vorliegt. Ohne Sperre und ohne Pin entsteht beim bloßen Prüfen nie ein
  /// Erstpin (kein TOFU durch Hinsehen): `decide()` liefert bei jedem gesperrten Gerät `changed`, nie `firstSeen`.
  bool _lockedByIdentity(String id) {
    final me = _client?.userID;
    final known = _identityChanged.contains(id) ||
        _anyDeviceBlocked(id) ||
        _contactSessionPins.containsKey(id) ||
        _contactAcceptedPins.containsKey(id) ||
        _localPins.pins.containsKey(id);
    if (me != null && known) _identityOf(id, me, mirror: false);
    return _identityChanged.contains(id) || _anyDeviceBlocked(id);
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

  /// Grundprüfung für jede Person (ohne Familie, K3c-1): angemeldet, gültige Kennung, nicht ich, Bereich an, die Mitglieder-
  /// liste ist vollständig (**auch** „keine Familie“ muss gesichert sein, sonst könnte ein Familienmitglied wie ein Fremder
  /// aussehen, B6/I2), nicht blockiert. [me] kommt vom Client.
  void _requireUsable(String userId) {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (userId == c.userID || !_contactMembersComplete() || !_contactPolicy.enabled) throw const GatewayException(GatewayError.notAllowed);
    if (_contactPolicy.blocked.contains(userId)) throw const GatewayException(GatewayError.notAllowed);
  }

  @override
  Future<ContactProbe> probeContact(String rawUserId) async {
    final userId = _canonical(rawUserId);
    _requireUsable(userId);
    if (_isFamilyId(userId)) {
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
    final epoch = _contactEpoch;
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
    // Frisch prüfen (nicht über eine Epoche): Ein Familienwechsel während der Abfrage macht die Mitgliederliste unvollständig
    // oder die Person zum Mitglied; dann kein Ergebnis und kein Eintrag im Zwischenspeicher (fail-closed, I2/I8).
    if (_disposed || epoch != _contactEpoch || _client != client || !_contactMembersComplete() || _isFamilyId(userId)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    final probe = ContactProbe(userId: userId, existence: existence, displayName: name, reachability: reach);
    // Unbekanntes wird nie zwischengespeichert: ein Netzfehler darf die Wiederholung nicht eine Minute sperren.
    if (existence != ContactExistence.unknown && reach != ContactReachability.unknown) c.probeCache[userId] = (at: DateTime.now(), probe: probe);
    return probe;
  }

  /// Gilt der Datensatz `outgoing` jetzt noch (Bereich an, nicht blockiert, kein Familienmitglied, Liste geladen)?
  bool _stillOutgoing(String userId) {
    final p = _contactPolicy;
    return _contactMembersComplete() &&
        p.enabled &&
        p.contacts[userId] == ContactState.outgoing &&
        !p.blocked.contains(userId) &&
        !_isFamilyId(userId);
  }

  @override
  Future<String> startContactChat(String rawUserId) async {
    final userId = _canonical(rawUserId);
    _requireUsable(userId);
    if (_isFamilyId(userId) || _contactPolicy.contacts[userId] != ContactState.outgoing) {
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
    final epoch = _contactEpoch;
    try {
      final reach = await _freshReachability(userId);
      if (reach == ContactReachability.notReachable) throw const GatewayException(GatewayError.peerNotReachable);
      if (reach == ContactReachability.unknown) throw const GatewayException(GatewayError.serverUnreachable);
      // Geänderter Schlüssel oder gesperrte Geräte (K3c-1, Revision K3b-1): kein Abbruch mehr. Der Raum darf entstehen
      // (Wiederhinzufügen nach Entfernen, Neustart mit gesperrten Geräten); Senden bleibt über `_requireContactRoom`
      // gesperrt, Akzeptieren läuft über das Banner. Sonst wäre der Kontakt eine Sackgasse bis zum Abmelden.
      if (_disposed || epoch != _contactEpoch || _client != client || !_stillOutgoing(userId)) throw const GatewayException(GatewayError.notAllowed);
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
      if (_disposed || epoch != _contactEpoch || _client != client || !_stillOutgoing(userId)) {
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
