part of '../sdk_matrix_gateway.dart';

/// Identitäten der Mitglieder (AP-5): Abgleich der Cross-Signing-Hauptschlüssel mit den lokalen und den Konto-Vermerken,
/// Sperren der Geräte bei Schlüsselwechsel, ausdrückliches Akzeptieren. Die Felder (`_pinBook`, `_localPins`,
/// `_identityChanged`, `_pinConflictLogged`, `_pinsPersisting`) und `pinsAccountData` bleiben in der Klasse (andere Module und Tests lesen sie).
mixin _IdentitiesModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Set<String> get _identityChanged;

  /// Kontakte außerhalb der Familie (K3b-2b, E-114): Sitzungs-Pin (erster gesehener Schlüssel) und ausdrücklich akzeptierter
  /// Schlüssel, **nur im Speicher**; sie gelangen nie in die Kontodaten.
  Map<String, String> get _contactSessionPins;
  Map<String, String> get _contactAcceptedPins;
  _ContactState get _contacts;
  String? _contactRoomOf(String peer);
  Family? get _family;
  ContactPolicy get _contactPolicy;
  bool get _participantsLoaded;
  LocalIdentityPins get _localPins;
  IdentityPinBook get _pinBook;
  Set<String> get _pinConflictLogged;
  bool get _pinsPersisting;
  set _pinsPersisting(bool value);
  Family _requireFamily();
  FamilyMember _requireMember(Family f, String userId);
  GatewayException _map(Object e);
  void _scheduleRefresh();

  Map<String, String> _pins() {
    final raw = _client?.accountData[SdkMatrixGateway.pinsAccountData]?.content;
    return <String, String>{
      if (raw != null)
        for (final e in raw.entries)
          if (JsonRead.string(e.value) case final v? when MatrixIds.isUserId(e.key)) e.key: v,
    };
  }

  void _setBlocked(String userId, bool blocked) {
    final list = _client?.userDeviceKeys[userId];
    if (list == null) return;
    for (final d in list.deviceKeys.values) {
      if (d.blocked != blocked) {
        d.setBlocked(blocked).catchError((Object e) {
          AppLog.w('gateway', 'Gerät konnte nicht (ent)sperrt werden');
        }).ignore();
      }
    }
  }

  /// Ob ein Gerät des Mitglieds von der App gesperrt wurde (nur Geräte, nicht der Hauptschlüssel; #133).
  bool _anyDeviceBlocked(String uid) {
    final list = _client?.userDeviceKeys[uid];
    if (list == null) return false;
    return anyBlocked(list.deviceKeys.values.map((d) => (blocked: d.blocked, selfSigned: d.selfSigned)));
  }

  /// [mirror] `false` für Kontakte außerhalb der Familie: kein Eintrag im Spiegel der Kontodaten (`_pinBook.remember`,
  /// `_persistPins`), kein Konfliktvermerk; der erste Schlüssel gilt lokal ([_localPins]) und als Sitzungs-Pin (auch bei
  /// inaktiver lokaler Ablage), ein ausdrücklich akzeptierter Schlüssel hat Vorrang.
  IdentityStatus _identityOf(String uid, String me, {bool mirror = true}) {
    final c = _client;
    if (c == null) return IdentityStatus.unknown;
    if (uid == me) return IdentityStatus.verified;
    final master = c.userDeviceKeys[uid]?.masterKey;
    final pub = master?.publicKey;
    if (master == null || pub == null) return IdentityStatus.unknown;
    final userId = c.userID;
    // Nur mit angemeldetem Client: Ein verspäteter Abgleich nach dem Abmelden legt nichts neu an (#142).
    if (c.isLogged() && userId != null) _localPins.bind(userId);
    final accountPins = _pins();
    if (mirror) _pinBook.synced(accountPins);
    final local = _localPins.pins;
    final r = resolvePin(
      accepted: mirror ? _pinBook.accepted(uid) : _contactAcceptedPins[uid],
      local: local[uid],
      account: accountPins[uid],
      pending: mirror ? _pinBook.pending(uid) : _contactSessionPins[uid],
      pub: pub,
      anyBlocked: _anyDeviceBlocked(uid),
    );
    final pinned = r.pinned;
    final localPin = local[uid];
    final accountPin = accountPins[uid];
    if (mirror && localPin != null && accountPin != localPin && _pinConflictLogged.add(uid)) {
      // Einmal je Mitglied, ohne Schlüssel: Die Kontodaten weichen vom lokalen Vermerk ab oder fehlen.
      AppLog.w('gateway', 'Identitätsvermerk in den Kontodaten weicht vom lokalen Stand ab; lokal gilt');
    }
    final IdentityStatus status;
    switch (r.decision) {
      case IdentityDecision.firstSeen:
        _identityChanged.remove(uid);
        if (mirror) {
          _pinBook.remember(uid, pub);
          _persistPins().ignore();
        } else {
          _contactSessionPins[uid] = pub;
        }
        status = master.verified ? IdentityStatus.verified : IdentityStatus.pinned;
      case IdentityDecision.changed:
        _identityChanged.add(uid);
        if (!mirror) _contacts.reachCache.remove(uid);
        // Neu sperren nur bei einem anderen Schlüssel; entsperrt wird ausschließlich beim Akzeptieren (E-37).
        if (pinned != null && pinned != pub) _setBlocked(uid, true);
        status = IdentityStatus.changed;
      case IdentityDecision.ok:
        _identityChanged.remove(uid);
        status = master.verified ? IdentityStatus.verified : IdentityStatus.pinned;
    }
    if (r.adopt) _localPins.adopt(uid, pub);
    _localPins.flushIfDirty().ignore();
    return status;
  }

  /// Lokale Pins der **aktuellen Mitglieder**: Kontakt-Pins gelangen nie in den Spiegel der Kontodaten (K3b-2b);
  /// Einträge ehemaliger Mitglieder bleiben über die Kontodaten erhalten (`merged` führt sie weiter).
  Map<String, String> _memberPins() {
    final f = _family;
    final local = _localPins.pins;
    if (f == null) return const <String, String>{};
    return <String, String>{
      for (final e in local.entries)
        if (f.member(e.key) != null) e.key: e.value,
    };
  }

  Future<void> _persistPins() async {
    final c = _client;
    if (_pinsPersisting || c == null || !c.isLogged() || !_pinBook.hasPending) return;
    _pinsPersisting = true;
    try {
      final merged = _pinBook.merged(_pins(), local: _memberPins());
      await c.setAccountData(c.userID!, SdkMatrixGateway.pinsAccountData, <String, Object?>{...merged});
      _pinBook.persisted(merged);
    } catch (e) {
      AppLog.w('gateway', 'Identitätsvermerke nicht gespeichert');
    } finally {
      _pinsPersisting = false;
    }
  }

  @override
  Future<void> acceptIdentityChange(String userId) async {
    final f = _requireFamily();
    if (f.member(userId) == null) {
      _acceptContactIdentityChange(f, userId);
      return;
    }
    _requireMember(f, userId);
    final c = _client;
    final pub = c?.userDeviceKeys[userId]?.masterKey?.publicKey;
    if (c == null || pub == null || !canAccept(identityChanged: _identityChanged.contains(userId), anyBlocked: _anyDeviceBlocked(userId))) {
      throw const GatewayException(GatewayError.notFound);
    }
    final accountPins = _pins();
    try {
      await c.setAccountData(c.userID!, SdkMatrixGateway.pinsAccountData, <String, Object?>{..._pinBook.merged(accountPins, local: _memberPins()), userId: pub});
    } catch (e) {
      throw _map(e);
    }
    // Erst nach erfolgreichem Schreiben: Bis der Sync die Kontodaten bringt, gilt der akzeptierte Pin lokal.
    _pinBook.accept(userId, pub, base: accountPins[userId]);
    _localPins.accept(userId, pub);
    _localPins.flushIfDirty().ignore();
    _identityChanged.remove(userId);
    _setBlocked(userId, false);
    _scheduleRefresh();
  }

  /// Ob [userId] ein Kontakt ist, dessen Änderung akzeptiert werden darf (Richtlinie ohne Raumbindung).
  bool _contactAcceptable(String userId) => VerificationPolicy.contactAllowed(
        contactState: _contactPolicy.enabled && _participantsLoaded ? _contactPolicy.contacts[userId] : null,
        blocked: _contactPolicy.blocked.contains(userId),
        contactRoomId: _contactRoomOf(userId),
      );

  /// Akzeptieren für einen **Kontakt**: kein `setAccountData`, kein `await` (keine Race zwischen Prüfung und Wirkung);
  /// der Schlüssel gilt nur im Speicher ([_contactAcceptedPins], höchster Vorrang) und lokal ([_localPins], wenn aktiv).
  void _acceptContactIdentityChange(Family f, String userId) {
    final c = _client;
    final pub = c?.userDeviceKeys[userId]?.masterKey?.publicKey;
    if (c == null || pub == null || !_contactAcceptable(userId) || !canAccept(identityChanged: _identityChanged.contains(userId), anyBlocked: _anyDeviceBlocked(userId))) {
      throw const GatewayException(GatewayError.notFound);
    }
    _contactAcceptedPins[userId] = pub;
    _contactSessionPins[userId] = pub;
    _localPins.accept(userId, pub);
    _localPins.flushIfDirty().ignore();
    _identityChanged.remove(userId);
    _contacts.reachCache.remove(userId);
    _contacts.identity.remove(userId);
    _setBlocked(userId, false);
    _scheduleRefresh();
  }
}
