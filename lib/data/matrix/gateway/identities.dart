part of '../sdk_matrix_gateway.dart';

/// Identitäten der Mitglieder (AP-5): Abgleich der Cross-Signing-Hauptschlüssel mit den lokalen und den Konto-Vermerken,
/// Sperren der Geräte bei Schlüsselwechsel, ausdrückliches Akzeptieren. Die Felder (`_pinBook`, `_localPins`,
/// `_identityChanged`, `_pinConflictLogged`, `_pinsPersisting`) und `pinsAccountData` bleiben in der Klasse (andere Module und Tests lesen sie).
mixin _IdentitiesModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Set<String> get _identityChanged;
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

  IdentityStatus _identityOf(String uid, String me) {
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
    _pinBook.synced(accountPins);
    final local = _localPins.pins;
    final r = resolvePin(
      accepted: _pinBook.accepted(uid),
      local: local[uid],
      account: accountPins[uid],
      pending: _pinBook.pending(uid),
      pub: pub,
      anyBlocked: _anyDeviceBlocked(uid),
    );
    final pinned = r.pinned;
    final localPin = local[uid];
    final accountPin = accountPins[uid];
    if (localPin != null && accountPin != localPin && _pinConflictLogged.add(uid)) {
      // Einmal je Mitglied, ohne Schlüssel: Die Kontodaten weichen vom lokalen Vermerk ab oder fehlen.
      AppLog.w('gateway', 'Identitätsvermerk in den Kontodaten weicht vom lokalen Stand ab; lokal gilt');
    }
    final IdentityStatus status;
    switch (r.decision) {
      case IdentityDecision.firstSeen:
        _identityChanged.remove(uid);
        _pinBook.remember(uid, pub);
        _persistPins().ignore();
        status = master.verified ? IdentityStatus.verified : IdentityStatus.pinned;
      case IdentityDecision.changed:
        _identityChanged.add(uid);
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

  Future<void> _persistPins() async {
    final c = _client;
    if (_pinsPersisting || c == null || !c.isLogged() || !_pinBook.hasPending) return;
    _pinsPersisting = true;
    try {
      final merged = _pinBook.merged(_pins(), local: _localPins.pins);
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
    _requireMember(f, userId);
    final c = _client;
    final pub = c?.userDeviceKeys[userId]?.masterKey?.publicKey;
    if (c == null || pub == null || !canAccept(identityChanged: _identityChanged.contains(userId), anyBlocked: _anyDeviceBlocked(userId))) {
      throw const GatewayException(GatewayError.notFound);
    }
    final accountPins = _pins();
    try {
      await c.setAccountData(c.userID!, SdkMatrixGateway.pinsAccountData, <String, Object?>{..._pinBook.merged(accountPins, local: _localPins.pins), userId: pub});
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
}
