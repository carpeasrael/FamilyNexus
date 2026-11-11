part of '../sdk_matrix_gateway.dart';

/// Sicherheit und Verifizierung (AP-5): Schlüsselsicherung, Notfall-Schlüssel, Geräteverifizierung. Abhängigkeiten
/// stehen als abstrakte Member am Anfang; `_verification` wird hier gelesen und gesetzt, `_syncedOnce` nur gelesen.
mixin _SecurityVerificationModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  bool get _syncedOnce;
  KeyVerification? get _verification;
  set _verification(KeyVerification? value);
  GatewayException _map(Object e);

  @override
  SecurityState get securityState {
    final c = _client;
    if (c == null || !c.isLogged() || !c.encryptionEnabled || !_syncedOnce) return SecurityState.unknown;
    final me = c.userID!;
    final hasServerSecurity = c.accountData.containsKey(EventTypes.SecretStorageDefaultKey) ||
        c.userDeviceKeys[me]?.masterKey != null;
    if (!hasServerSecurity) return SecurityState.needsSetup;
    return c.isUnknownSession ? SecurityState.needsRestore : SecurityState.ready;
  }

  @override
  List<DeviceEntry> get devices {
    final c = _client;
    if (c == null || !c.isLogged()) return const <DeviceEntry>[];
    final me = c.userID!;
    final list = c.userDeviceKeys[me]?.deviceKeys.values ?? const Iterable<DeviceKeys>.empty();
    return <DeviceEntry>[
      for (final d in list)
        DeviceEntry(
          userId: me,
          deviceId: TextSanitizer.clean(d.deviceId ?? '', max: 40),
          name: TextSanitizer.clean(d.deviceDisplayName ?? d.deviceId ?? '', max: 40),
          verified: d.deviceId == c.deviceID ? !c.isUnknownSession : d.verified,
          isCurrent: d.deviceId == c.deviceID,
        ),
    ];
  }

  @override
  Future<void> refreshSecurity() async {
    final c = _client;
    if (c == null || !c.isLogged()) return;
    try {
      await c.updateUserDeviceKeys(additionalUsers: <String>{c.userID!});
    } catch (e) {
      AppLog.e('gateway', 'Geräteliste konnte nicht aktualisiert werden', e);
    }
    notifyListeners();
  }

  @visibleForTesting
  KeyVerification? get sdkVerification => _verification;

  @override
  VerificationInfo? get verification {
    final v = _verification;
    if (v == null) return null;
    final peer = TextSanitizer.clean(v.userId, max: 80);
    final dev = v.deviceId == null ? null : TextSanitizer.clean(v.deviceId!, max: 40);
    VerificationPhase phase;
    var emojis = const <VerificationEmoji>[];
    switch (v.state) {
      case KeyVerificationState.askAccept:
        phase = VerificationPhase.incomingRequest;
      case KeyVerificationState.askSas:
        phase = VerificationPhase.comparing;
        emojis = <VerificationEmoji>[for (final e in v.sasEmojis) VerificationEmoji(emoji: e.emoji, name: e.name)];
      case KeyVerificationState.waitingSas:
        phase = VerificationPhase.waitingForPeerConfirmation;
      case KeyVerificationState.done:
        phase = VerificationPhase.done;
      case KeyVerificationState.error:
        phase = VerificationPhase.cancelled;
      default:
        phase = VerificationPhase.waiting;
    }
    return VerificationInfo(
      phase: phase,
      peerUserId: peer,
      peerDeviceId: dev,
      emojis: emojis,
      incoming: !v.startedVerification,
    );
  }

  /// Eingehende Anfragen: nur vom eigenen Konto oder von Mitgliedern der Familie, und nur eine
  /// zur Zeit (S4). Alles andere wird still abgebrochen (`m.user`), ohne Dialog.
  void _onIncomingVerification(KeyVerification v) {
    final f = _family;
    final known = v.userId == _client?.userID || (f != null && f.member(v.userId)?.status == MemberStatus.joined);
    final busy = _verification != null && !_verification!.isDone && _verification!.state != KeyVerificationState.error;
    if (!known || busy) {
      v.cancel('m.user').catchError((Object e) {
        AppLog.w('gateway', 'Verifizierungsanfrage konnte nicht abgelehnt werden');
      }).ignore();
      return;
    }
    _setVerification(v);
  }

  void _setVerification(KeyVerification v) {
    _verification = v;
    v.onUpdate = () {
      // Wir unterstützen nur den Emoji-Vergleich: Auswahl und Schlüsselabfrage automatisch.
      // Nur die Seite, die die Anfrage gestellt hat, sendet den Start (sonst Start-Kollision
      // mit abweichenden Emoji auf beiden Seiten).
      if (v.state == KeyVerificationState.askChoice && v.startedVerification) {
        v.continueVerification(EventTypes.Sas).catchError((Object e) {
          AppLog.e('gateway', 'Verifizierung konnte nicht fortgesetzt werden', e);
        }).ignore();
      } else if (v.state == KeyVerificationState.askSSSS) {
        v.openSSSS(skip: true).catchError((Object e) {
          AppLog.e('gateway', 'Verifizierung konnte nicht abgeschlossen werden', e);
        }).ignore();
      } else if (v.state == KeyVerificationState.done) {
        refreshSecurity().ignore();
      }
      notifyListeners();
    };
    notifyListeners();
  }

  @override
  Future<void> startVerification({required String userId, String? deviceId}) async {
    final c = _client;
    if (c == null || !c.isLogged() || c.encryption == null) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (_verification != null && !_verification!.isDone) throw const GatewayException(GatewayError.alreadyExists);
    try {
      await c.updateUserDeviceKeys(additionalUsers: <String>{userId});
      final KeyVerification v;
      if (deviceId != null) {
        final dev = c.userDeviceKeys[userId]?.deviceKeys[deviceId];
        if (dev == null || dev.deviceId == c.deviceID) throw const GatewayException(GatewayError.notFound);
        v = await dev.startVerification();
      } else {
        final list = c.userDeviceKeys[userId];
        if (list == null) throw const GatewayException(GatewayError.notFound);
        v = await list.startVerification();
      }
      _setVerification(v);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Verifizierung konnte nicht gestartet werden', e);
      throw _map(e);
    }
  }

  KeyVerification _requireVerification() {
    final v = _verification;
    if (v == null) throw const GatewayException(GatewayError.notFound);
    return v;
  }

  @override
  Future<void> acceptVerification() async {
    final v = _requireVerification();
    try {
      await v.acceptVerification();
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> confirmEmojiMatch(bool matches) async {
    final v = _requireVerification();
    try {
      if (matches) {
        await v.acceptSas();
      } else {
        await v.rejectSas();
      }
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> cancelVerification() async {
    final v = _verification;
    if (v == null) return;
    try {
      if (!v.isDone) await v.cancel();
    } catch (e) {
      AppLog.e('gateway', 'Abbrechen der Verifizierung fehlgeschlagen', e);
    }
    _verification = null;
    notifyListeners();
  }

  /// Beantwortet die Passwortabfrage des Servers (UIA) beim Hochladen der Cross-Signing-Schlüssel.
  /// Ohne [password] wird die Abfrage abgebrochen und über [onReauthNeeded] gemeldet.
  StreamSubscription<UiaRequest<dynamic>> _answerUiaWithPassword(Client client, String? password, void Function() onReauthNeeded) {
    void answer(UiaRequest<dynamic> uia) {
      if (uia.state != UiaRequestState.waitForUser) return;
      if (!uia.nextStages.contains(AuthenticationTypes.password)) {
        uia.cancel(Exception('Passwort-Stufe nicht angeboten'));
        return;
      }
      if (password == null) {
        onReauthNeeded();
        uia.cancel(Exception('Passwort erforderlich'));
        return;
      }
      uia
          .completeStage(AuthenticationPassword(
            session: uia.session,
            password: password,
            identifier: AuthenticationUserIdentifier(user: client.userID!),
          ))
          .catchError((Object e) {
        AppLog.e('gateway', 'Passwortbestätigung fehlgeschlagen', e);
        return null;
      }).ignore();
    }

    return client.onUiaRequest.stream.listen((uia) {
      uia.onUpdate = (_) => answer(uia);
      answer(uia);
    });
  }

  /// Führt den Bootstrap-Zustandsautomaten des SDK automatisch durch.
  /// [recoveryKey] != null → Wiederherstellung; [keepSecrets] != null → neuer Schlüssel für ein
  /// verifiziertes Gerät, die Geheimnisse (Typ → Wert) kommen unter den neuen Schlüssel (#11);
  /// sonst Ersteinrichtung. Ersteinrichtung und neuer Schlüssel liefern den neuen Schlüssel.
  Future<String?> _driveBootstrap(Client client, {String? recoveryKey, Map<String, String>? keepSecrets}) {
    final enc = client.encryption;
    if (enc == null) throw const GatewayException(GatewayError.encryptionUnavailable);
    final done = Completer<String?>();
    String? created;
    var busy = false;
    BootstrapState? lastHandled;
    Bootstrap? current;

    void fail(Object e) {
      if (!done.isCompleted) done.completeError(e);
    }

    Future<void> step() async {
      final bs = current;
      if (bs == null || busy || done.isCompleted) return;
      final state = bs.state;
      if (state == lastHandled && state != BootstrapState.loading) return;
      lastHandled = state;
      busy = true;
      try {
        switch (state) {
          case BootstrapState.loading:
            break;
          case BootstrapState.askWipeSsss:
            // Ersteinrichtung darf bestehende Sicherungen nie überschreiben.
            if (keepSecrets != null) {
              bs.wipeSsss(true);
            } else if (recoveryKey == null) {
              fail(const GatewayException(GatewayError.alreadyExists));
            } else {
              bs.wipeSsss(false);
            }
          case BootstrapState.askUseExistingSsss:
            bs.useExistingSsss(true);
          case BootstrapState.askBadSsss:
            bs.ignoreBadSecrets(true);
          case BootstrapState.askUnlockSsss:
            bs.unlockedSsss();
          case BootstrapState.askNewSsss:
            if (recoveryKey != null) {
              fail(const GatewayException(GatewayError.notFound));
            } else {
              await bs.newSsss();
              created = bs.newSsssKey?.recoveryKey;
            }
          case BootstrapState.openExistingSsss:
            await bs.newSsssKey!.unlock(keyOrPassphrase: recoveryKey);
            await bs.openExistingSsss();
          case BootstrapState.askWipeCrossSigning:
            // Neuer Schlüssel: Identität behalten, ihre Geheimnisse aber unter dem neuen Schlüssel ablegen.
            if (keepSecrets != null) {
              for (final e in keepSecrets.entries) {
                await bs.newSsssKey!.store(e.key, e.value);
              }
            }
            await bs.wipeCrossSigning(false);
          case BootstrapState.askSetupCrossSigning:
            // Wiederherstellung und neuer Schlüssel dürfen nie eine neue Identität anlegen (würde die alte ersetzen).
            if (recoveryKey != null || keepSecrets != null) {
              fail(const GatewayException(GatewayError.notFound));
              break;
            }
            await bs.askSetupCrossSigning(setupMasterKey: true, setupSelfSigningKey: true, setupUserSigningKey: true);
          case BootstrapState.askWipeOnlineKeyBackup:
            // Neuer Schlüssel ohne bekannten Backup-Schlüssel: neues Backup (Sitzungen werden neu hochgeladen).
            bs.wipeOnlineKeyBackup(keepSecrets != null && !keepSecrets.containsKey(EventTypes.MegolmBackup));
          case BootstrapState.askSetupOnlineKeyBackup:
            await bs.askSetupOnlineKeyBackup(true);
          case BootstrapState.error:
            fail(bs.errorResult?.error ?? const GatewayException(GatewayError.unknown));
          case BootstrapState.done:
            if (!done.isCompleted) done.complete(created);
        }
      } catch (e) {
        fail(e);
      } finally {
        busy = false;
      }
      // Weiter, falls sich der Zustand während der Arbeit geändert hat.
      if (!done.isCompleted && bs.state != lastHandled) unawaited(step());
    }

    // Der Konstruktor meldet den Anfangszustand bereits während der Erzeugung.
    current = enc.bootstrap(onUpdate: (b) {
      current = b;
      unawaited(step());
    });
    unawaited(step());
    return done.future;
  }

  @override
  Future<String> setUpSecurity({String? password}) async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!c.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (password != null && (password.isEmpty || password.length > 1024)) throw const GatewayException(GatewayError.invalidInput);
    if (securityState != SecurityState.needsSetup) throw const GatewayException(GatewayError.alreadyExists);
    var reauth = false;
    final sub = _answerUiaWithPassword(c, password, () => reauth = true);
    try {
      final key = await _driveBootstrap(c).timeout(const Duration(minutes: 2));
      if (key == null || key.isEmpty) throw const GatewayException(GatewayError.unknown);
      await refreshSecurity();
      return key;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Einrichtung der Schlüsselsicherung fehlgeschlagen', e);
      if (reauth) throw const GatewayException(GatewayError.reauthRequired);
      if (e is MatrixException && (e.errcode == 'M_FORBIDDEN' || e.errcode == 'M_UNAUTHORIZED')) {
        throw const GatewayException(GatewayError.invalidCredentials);
      }
      throw _map(e);
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> restoreSecurity(String recoveryKey) async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final key = recoveryKey.trim();
    if (key.isEmpty || key.length > 200) throw const GatewayException(GatewayError.invalidInput);
    try {
      await _driveBootstrap(c, recoveryKey: key).timeout(const Duration(minutes: 2));
      await _selfSign(c, key);
      try {
        // Ältere Nachrichtenschlüssel kommen notfalls später; die Freischaltung wartet nicht ewig (#24).
        await c.encryption!.keyManager.loadAllKeys().timeout(const Duration(seconds: 30));
      } catch (e) {
        AppLog.w('gateway', 'Schlüsselsicherung konnte nicht geladen werden');
      }
      await refreshSecurity();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Wiederherstellung fehlgeschlagen', e);
      // Falscher Schlüssel: die SDK-Prüfung wirft beim Entsperren (kein Netzwerkfehler).
      if (e is! MatrixException && e is! TimeoutException && e is! StateError && e is! SocketException && e is! http.ClientException) {
        throw const GatewayException(GatewayError.invalidInput);
      }
      throw _map(e);
    }
  }

  /// Bestätigt dieses Gerät nach dem Entsperren mit [recoveryKey]. Nach einem neuen Schlüssel (#11)
  /// liegt der Master-Key nur noch unter dem alten (das SDK hält ihn nicht lokal vor); dann
  /// signiert der Self-Signing-Key, der unter dem neuen liegt – wie nach einer Emoji-Verifizierung.
  Future<void> _selfSign(Client c, String recoveryKey) async {
    final enc = c.encryption!;
    final masterKeyIds = enc.ssss.keyIdsFromType(EventTypes.CrossSigningMasterKey);
    if (masterKeyIds != null && masterKeyIds.contains(enc.ssss.defaultKeyId)) {
      await enc.crossSigning.selfSign(recoveryKey: recoveryKey);
      return;
    }
    final mine = c.userDeviceKeys[c.userID];
    final master = mine?.masterKey;
    final device = mine?.deviceKeys[c.deviceID];
    if (master == null || device == null || await enc.ssss.getCached(EventTypes.CrossSigningSelfSigning) == null) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    // Das SDK lässt die Kette Gerät → Self-Signing → Master nur bei bestätigtem eigenem Master gelten.
    // Passt der Self-Signing-Key nicht zum veröffentlichten, bricht die Kette: Bestätigung zurücknehmen.
    await master.setVerified(true, false);
    await enc.crossSigning.sign(<SignableKey>[master, device]);
    await c.updateUserDeviceKeys(additionalUsers: <String>{c.userID!});
    if (c.isUnknownSession) {
      await c.userDeviceKeys[c.userID]?.masterKey?.setVerified(false, false);
      throw const GatewayException(GatewayError.invalidInput);
    }
  }

  @override
  Future<String> resetRecoveryKey() async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final enc = c.encryption;
    if (enc == null) throw const GatewayException(GatewayError.encryptionUnavailable);
    // Nur ein verifiziertes Gerät hält die Signaturschlüssel vor, die unter den neuen Schlüssel kommen.
    if (securityState != SecurityState.ready || !await enc.crossSigning.isCached()) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    final keep = <String, String>{};
    for (final type in <String>[EventTypes.CrossSigningSelfSigning, EventTypes.CrossSigningUserSigning, EventTypes.MegolmBackup]) {
      final secret = await enc.ssss.getCached(type);
      if (secret != null) keep[type] = secret;
    }
    try {
      final key = await _driveBootstrap(c, keepSecrets: keep).timeout(const Duration(minutes: 2));
      if (key == null || key.isEmpty) throw const GatewayException(GatewayError.unknown);
      await refreshSecurity();
      return key;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Neuer Wiederherstellungsschlüssel fehlgeschlagen', e);
      throw _map(e);
    }
  }
}
