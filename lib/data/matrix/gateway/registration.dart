part of '../sdk_matrix_gateway.dart';

/// Kontoanlage (AP-5, E-55): Registrierung in der App, Browser-Anmeldung (OAuth), Anzeigename. Die Felder (`_registration`,
/// `_oauth`, `_oauthPair`), `_dropOAuth` (auch von anderen Modulen genutzt), die Konstanten und `close`/`logout` bleiben in
/// der Klasse.
mixin _RegistrationModule on ChangeNotifier implements MatrixGateway {
  Future<void> _adoptProvider(Client client, _Entered? pair);
  _AppClient? get _client;
  Map<ServerUrl, ServerUrl> get _confirmedBase;
  void _dropOAuth();
  Future<_AppClient> _ensureClient();
  GatewayException _map(Object e, {bool forLogin = false});
  OidcLoginSession? get _oauth;
  set _oauth(OidcLoginSession? value);
  _Entered? get _oauthPair;
  set _oauthPair(_Entered? value);
  ServerProbe get _probe;
  Future<void> _refresh();
  void _scheduleRefresh();
  _RegistrationSession? get _registration;
  set _registration(_RegistrationSession? value);
  Future<(GetAuthMetadataResponse?, _Entered?)> _useHomeserver(Client client, ServerUrl server, {bool oauth = false});
  @override
  Future<RegistrationOptions> registrationOptions(ServerUrl server) async {
    try {
      return await _probe.registrationOptions(server);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Registrierungswege nicht ermittelbar', e);
      throw _map(e);
    }
  }

  @override
  Future<UsernameCheck> checkUsername(ServerUrl server, String username) async {
    if (!UsernameSuggestion.isValid(username)) return UsernameCheck.invalid;
    try {
      final base = _confirmedBase[server] ?? await _probe.resolveBase(server);
      return await _probe.checkUsername(base, username);
    } catch (e) {
      return UsernameCheck.unknown;
    }
  }

  @override
  Future<RegistrationStage?> register({
    required ServerUrl server,
    required String username,
    required String password,
    required String displayName,
    String language = 'de',
  }) async {
    if (!UsernameSuggestion.isValid(username)) throw const GatewayException(GatewayError.usernameInvalid);
    if (password.length < SdkMatrixGateway.minPasswordLength) throw const GatewayException(GatewayError.weakPassword);
    if (password.length > 1024) throw const GatewayException(GatewayError.invalidInput);
    if (_client?.isLogged() ?? false) throw const GatewayException(GatewayError.notAllowed);
    cancelRegistration();
    try {
      final client = await _ensureClient();
      final (_, pair) = await _useHomeserver(client, server);
      _registration = _RegistrationSession(
        username: username,
        password: password,
        displayName: TextSanitizer.clean(displayName, max: 64),
        language: language,
        provider: pair,
      );
      return await _registerAttempt(null);
    } on GatewayException {
      cancelRegistration();
      rethrow;
    } catch (e) {
      cancelRegistration();
      AppLog.e('gateway', 'Registrierung fehlgeschlagen', e);
      throw _map(e);
    }
  }

  @override
  Future<RegistrationStage?> continueRegistration(RegistrationInput input) async {
    final r = _registration;
    final client = _client;
    if (r == null || client == null) throw const GatewayException(GatewayError.notFound);
    try {
      switch (input) {
        case AcceptTerms():
          return await _registerAttempt(AuthenticationData(type: RegistrationFlows.terms, session: r.session));
        case SubmitToken(:final token):
          final t = token.trim();
          if (t.isEmpty || t.length > 256) throw const GatewayException(GatewayError.invalidInput);
          return await _registerAttempt(AuthenticationData(
            type: RegistrationFlows.token,
            session: r.session,
            additionalFields: <String, Object?>{'token': t},
          ));
        case CaptchaDone():
          // Nach der Bestätigung auf der Seite des Servers genügt die Sitzung (Spezifikation: Fallback).
          return await _registerAttempt(AuthenticationData(session: r.session), attempted: RegistrationFlows.recaptcha);
        case SubmitEmail(:final email):
          if (!isPlausibleEmail(email)) throw const GatewayException(GatewayError.invalidInput);
          r.clientSecret ??= SdkMatrixGateway._randomNonce();
          r.sendAttempt++;
          final res = await client.requestTokenToRegisterEmail(r.clientSecret!, email.trim(), r.sendAttempt);
          r.sid = res.sid;
          return const EmailStage(sent: true);
        case EmailConfirmed():
          final sid = r.sid;
          if (sid == null) return const EmailStage();
          return await _registerAttempt(AuthenticationThreePidCreds(
            type: RegistrationFlows.email,
            session: r.session,
            threepidCreds: ThreepidCreds(sid: sid, clientSecret: r.clientSecret!),
          ));
      }
    } on GatewayException catch (e) {
      const keep = <GatewayError>{
        GatewayError.invalidInput,
        GatewayError.rateLimited,
        GatewayError.emailInUse,
        GatewayError.serverUnreachable,
      };
      if (!keep.contains(e.error)) cancelRegistration();
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Registrierungsschritt fehlgeschlagen', e);
      final mapped = _mapRegistration(e);
      if (mapped.error != GatewayError.emailInUse &&
          mapped.error != GatewayError.rateLimited &&
          mapped.error != GatewayError.serverUnreachable) {
        cancelRegistration();
      }
      throw mapped;
    }
  }

  @override
  void cancelRegistration() {
    _registration?.password = null;
    _registration = null;
  }

  /// Ein Durchlauf von `/register`. Verlangt der Server weitere Schritte, wird der nächste
  /// ermittelt; Platzhalterschritte (`m.login.dummy`) erledigt die App selbst.
  Future<RegistrationStage?> _registerAttempt(AuthenticationData? auth, {String? attempted, int depth = 0}) async {
    final r = _registration;
    final client = _client;
    if (r == null || r.password == null || client == null) throw const GatewayException(GatewayError.notFound);
    if (depth > 5) throw const GatewayException(GatewayError.unknown);
    final tried = attempted ?? auth?.type;
    try {
      try {
        await client.register(
          kind: AccountKind.user,
          username: r.username,
          password: r.password,
          auth: auth,
          initialDeviceDisplayName: PlatformInfo.deviceName,
        );
      } finally {
        // [r] ist lokal gehalten: Hat der Kontoanlage-Schritt die Registrierung inzwischen verworfen (er wechselt,
        // sobald das SDK „angemeldet“ meldet), gilt das Paar trotzdem. Ohne Sitzung (weitere Schritte) wirkungslos.
        await _adoptProvider(client, r.provider);
      }
    } on MatrixException catch (e) {
      final flows = e.authenticationFlows;
      if (!e.requireAdditionalAuthentication || flows == null) throw _mapRegistration(e);
      r.session = e.session ?? r.session;
      r.flows = <List<String>>[for (final f in flows) f.stages];
      r.completed = e.completedAuthenticationFlows.toSet();
      r.params = e.authenticationParams;
      final next = RegistrationFlows.next(r.flows, r.completed);
      if (RegistrationFlows.choose(r.flows, r.completed) == null) {
        throw const GatewayException(GatewayError.registrationDisabled);
      }
      switch (next) {
        case RegistrationFlows.dummy:
          if (tried == RegistrationFlows.dummy) throw const GatewayException(GatewayError.unknown);
          return _registerAttempt(AuthenticationData(type: RegistrationFlows.dummy, session: r.session), depth: depth + 1);
        case RegistrationFlows.terms:
          return TermsStage(RegistrationFlows.termsFrom(r.params?[RegistrationFlows.terms], language: r.language));
        case RegistrationFlows.token:
          return TokenStage(wrong: tried == RegistrationFlows.token);
        case RegistrationFlows.recaptcha:
          final base = client.homeserver!;
          return CaptchaStage(
            base.replace(
              path: '/_matrix/client/v3/auth/${RegistrationFlows.recaptcha}/fallback/web',
              queryParameters: <String, String>{'session': r.session ?? ''},
            ),
            notDoneYet: tried == RegistrationFlows.recaptcha,
          );
        case RegistrationFlows.email:
          return EmailStage(sent: r.sid != null, notConfirmedYet: tried == RegistrationFlows.email);
        default:
          throw const GatewayException(GatewayError.unknown);
      }
    }
    // Konto angelegt, Sitzung läuft (das SDK hat `init` bereits ausgeführt).
    final name = r.displayName;
    cancelRegistration();
    if (name.isNotEmpty) {
      try {
        await setDisplayName(name);
      } catch (e) {
        AppLog.w('gateway', 'Anzeigename nicht gesetzt');
      }
    }
    await _refresh();
    return null;
  }

  GatewayException _mapRegistration(Object e) {
    if (e is GatewayException) return e;
    if (e is MatrixException) {
      final code = e.errcode;
      if (code == 'M_USER_IN_USE') return const GatewayException(GatewayError.usernameTaken);
      if (code == 'M_INVALID_USERNAME' || code == 'M_EXCLUSIVE') return const GatewayException(GatewayError.usernameInvalid);
      if (code == 'M_WEAK_PASSWORD' || code.startsWith('M_PASSWORD')) return const GatewayException(GatewayError.weakPassword);
      if (code == 'M_THREEPID_IN_USE') return const GatewayException(GatewayError.emailInUse);
      if (code == 'M_THREEPID_DENIED' || code == 'M_SERVER_NOT_TRUSTED') return const GatewayException(GatewayError.invalidInput);
      if (code == 'M_FORBIDDEN' || code == 'M_UNRECOGNIZED') return const GatewayException(GatewayError.registrationDisabled);
    }
    return _map(e);
  }

  @override
  Future<Uri> startOAuth({required ServerUrl server, required Uri redirectUri, required bool create}) async {
    if (_client?.isLogged() ?? false) throw const GatewayException(GatewayError.notAllowed);
    final loopback = redirectUri.scheme == 'http' && redirectUri.host == '127.0.0.1';
    if (!loopback && redirectUri.scheme != SdkMatrixGateway.oauthScheme) throw const GatewayException(GatewayError.invalidInput);
    cancelRegistration();
    // Eine ältere, nicht abgeschlossene Anmeldung ist damit verworfen; ihr Rücksprung ergibt `oauthCancelled`.
    _dropOAuth();
    try {
      final client = await _ensureClient();
      // Die Metadaten aus der Serverprüfung, ohne zweiten Abruf. Fehler beim Abruf fängt
      // `checkHomeserver` ab; ohne Metadaten gibt es keine Browser-Anmeldung (#222).
      final (meta, pair) = await _useHomeserver(client, server, oauth: true);
      if (meta == null) throw const GatewayException(GatewayError.serverUnsupported);
      // Alle Endpunkte, über die Code, Verifier und Tokens laufen: https, ohne Zugangsdaten und bei einem
      // öffentlichen Server nicht im Heimnetz (E-59). Danach festgehalten: Das SDK ruft `getAuthMetadata`
      // in `registerOidcClient`, `initOidcLoginSession` und `oidcLogin` selbst und erhält genau diese.
      final acceptable = ServerProbe.oauthEndpointsAcceptable(
        localServer: ServerUrl.isLocalHost(client.homeserver!.host.toLowerCase()),
        endpoints: <Uri>[
          meta.issuer,
          meta.authorizationEndpoint,
          meta.tokenEndpoint,
          meta.registrationEndpoint,
          meta.revocationEndpoint,
        ],
      );
      if (!acceptable) throw const GatewayException(GatewayError.serverUnsupported);
      client.pinnedAuthMetadata = meta;
      final data = await client.registerOidcClient(
        redirectUris: <Uri>[redirectUri],
        applicationType: OidcApplicationType.native,
        clientInformation: OidcClientInformation(
          clientName: 'FamilyNexus',
          clientUri: SdkMatrixGateway.oauthClientUri,
          logoUri: null,
          tosUri: null,
          policyUri: null,
        ),
      );
      final session = await client.initOidcLoginSession(
        oidcClientData: data,
        redirectUri: redirectUri,
        prompt: create ? 'create' : null,
      );
      if (session.authenticationUri.scheme != 'https') throw const GatewayException(GatewayError.serverUnsupported);
      _oauth = session;
      _oauthPair = pair;
      return session.authenticationUri;
    } on GatewayException {
      _dropOAuth();
      rethrow;
    } catch (e) {
      _dropOAuth();
      AppLog.e('gateway', 'Anmeldung im Browser nicht vorbereitet', e);
      throw _map(e);
    }
  }

  @override
  Future<void> completeOAuth(Uri callback) async {
    final session = _oauth;
    final pair = _oauthPair;
    final client = _client;
    if (session == null || client == null) throw const GatewayException(GatewayError.oauthCancelled);
    // Rücksprung nur an die eigene, gerade verwendete Adresse.
    if (callback.scheme != session.redirectUri.scheme || callback.path != session.redirectUri.path) {
      throw const GatewayException(GatewayError.oauthStateMismatch);
    }
    final params = <String, String>{
      ...callback.queryParameters,
      if (callback.fragment.isNotEmpty) ...Uri.splitQueryString(callback.fragment),
    };
    final code = params['code'];
    final state = params['state'];
    // Fremder Rücksprung (anderer Prozess, alte Anmeldung): verwerfen, die eigene läuft weiter – samt
    // der festgehaltenen Metadaten (#222).
    if (state != session.state) throw const GatewayException(GatewayError.oauthStateMismatch);
    if (params.containsKey('error') || code == null) {
      _dropOAuth();
      throw const GatewayException(GatewayError.oauthCancelled);
    }
    _oauth = null;
    _oauthPair = null;
    // Code und Verifier gehen nur an den beim Start geprüften Token-Endpunkt (doppelte Sicherung).
    final pinned = client.pinnedAuthMetadata;
    if (pinned == null) throw const GatewayException(GatewayError.oauthCancelled);
    try {
      try {
        await client.oidcLogin(session: session, code: code, state: session.state);
      } finally {
        await _adoptProvider(client, pair);
      }
      await _refresh();
    } catch (e) {
      // Angemeldet ist angemeldet (#28, #412): Scheitert nur ein Folgeschritt (erster Abgleich, Schlüssel), steht die
      // Sitzung. Vor `startOAuth` war der Client nicht angemeldet, `isLogged` stammt also aus diesem Vorgang.
      if (client.isLogged()) {
        AppLog.e('gateway', 'Nach der Browser-Anmeldung fehlgeschlagen (Anmeldung gilt)', e);
        _scheduleRefresh();
        notifyListeners();
        return;
      }
      AppLog.e('gateway', 'Anmeldung im Browser fehlgeschlagen', e);
      if (e is OidcException) throw const GatewayException(GatewayError.oauthCancelled);
      throw _map(e, forLogin: true);
    } finally {
      // Token-Erneuerung und -Widerruf nutzen danach wieder die Metadaten des SDK (E-59, #222).
      if (identical(client.pinnedAuthMetadata, pinned)) client.pinnedAuthMetadata = null;
    }
  }

  @override
  Future<void> setDisplayName(String name) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final n = TextSanitizer.clean(name, max: 64);
    if (n.isEmpty) throw const GatewayException(GatewayError.invalidInput);
    try {
      await client.setProfileField(client.userID!, 'displayname', <String, Object?>{'displayname': n});
    } catch (e) {
      throw _map(e);
    }
  }
}
