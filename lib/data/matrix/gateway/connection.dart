part of '../sdk_matrix_gateway.dart';

/// Verbindung (AP-5): Server prüfen, Homeserver des SDK setzen, Passwort-Anmeldung. Die Felder und die statischen
/// Hilfen (`_usernameRe`, `_baseOf`) bleiben in der Klasse (Kontoanlage und Tests nutzen sie).
mixin _ConnectionModule on ChangeNotifier implements MatrixGateway {
  Future<void> _adoptProvider(Client client, _Entered? pair);
  _AppClient? get _client;
  Map<ServerUrl, ServerUrl> get _confirmedBase;
  void _dropOAuth();
  Future<_AppClient> _ensureClient();
  GatewayException _map(Object e, {bool forLogin = false});
  ServerProbe get _probe;
  Future<void> _refresh();
  void _scheduleRefresh();
  @override
  Future<ServerInfo> probeServer(ServerUrl url) async {
    try {
      final info = await _probe.probe(url);
      _confirmedBase[url] = info.url;
      return info;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Serverprüfung fehlgeschlagen', e);
      throw _map(e);
    }
  }

  /// Setzt den Homeserver des SDK auf die geprüfte Adresse. Das SDK darf keine eigene
  /// `.well-known`-Abfrage machen (ungeprüfte Ziele, Weiterleitungen, Zwischenspeicherung).
  /// Mit [oauth] liefert es die dabei abgerufenen OAuth-Metadaten (`null`, wenn keine abrufbar waren), dazu immer
  /// das Paar aus eingegebener Adresse und normalisierter Basis für den laufenden Vorgang (#259).
  Future<(GetAuthMetadataResponse?, _Entered?)> _useHomeserver(Client client, ServerUrl server, {bool oauth = false}) async {
    // Passwort-Anmeldung und Registrierung beenden eine offene Browser-Anmeldung samt festgehaltener
    // Metadaten (#222) – vor `checkHomeserver`, das ab Matrix v1.15 auch hier `getAuthMetadata` ruft.
    if (!oauth) _dropOAuth();
    final base = _confirmedBase[server] ?? await _probe.resolveBase(server);
    // Die OAuth-Metadaten nur für die Browser-Anmeldung abfragen: Fehlerseiten von Proxys würden
    // sonst auch die Passwort-Anmeldung verhindern.
    final (_, _, _, meta) = await client.checkHomeserver(base.uri, checkWellKnown: false, fetchAuthMetadata: oauth ? true : null);
    if (client.homeserver?.scheme != 'https') {
      client.homeserver = null;
      throw const GatewayException(GatewayError.serverUnsupported);
    }
    final resolved = SdkMatrixGateway._baseOf(client);
    final _Entered? pair = resolved == null ? null : (entered: server, base: resolved);
    return (oauth ? meta : null, pair);
  }

  @override
  Future<void> login({
    required ServerUrl server,
    required String username,
    required String password,
  }) async {
    final user = username.trim();
    if (!SdkMatrixGateway._usernameRe.hasMatch(user) || password.isEmpty || password.length > 1024) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    cancelRegistration();
    try {
      final client = await _ensureClient();
      final (_, pair) = await _useHomeserver(client, server);
      try {
        await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: user),
          password: password,
          initialDeviceDisplayName: PlatformInfo.deviceName,
        );
      } finally {
        // Auch wenn nach der Anmeldung ein Folgeschritt scheitert (#28): Die Sitzung steht.
        await _adoptProvider(client, pair);
      }
      await _refresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      // Angemeldet ist angemeldet: scheitert nur ein Folgeschritt (z. B. Schlüssel hochladen,
      // erster Abgleich), keine Fehlermeldung zeigen – der Abgleich holt ihn nach (#28).
      if (_client?.isLogged() ?? false) {
        AppLog.e('gateway', 'Nach der Anmeldung fehlgeschlagen (Anmeldung gilt)', e);
        _scheduleRefresh();
        notifyListeners();
        return;
      }
      AppLog.e('gateway', 'Anmeldung fehlgeschlagen', e);
      throw _map(e, forLogin: true);
    }
  }
}
