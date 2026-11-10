part of '../sdk_matrix_gateway.dart';

/// Kontolöschung (Probe für AP-5): Löschen in der App, Prüfung, ob das Konto schon gelöscht ist, und das lokale
/// Aufräumen nach dem Ende der Sitzung. Abhängigkeiten stehen unten als abstrakte Member.
mixin _AccountDeletionModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  LocalIdentityPins get _localPins;
  GatewayException _map(Object e);
  Future<bool> _signedInViaOAuth(Client c);
  Future<Uri?> _accountManagementPage(Client c, Uri? Function(Map<String, Object?> metadata) pick);
  void _dropOAuth();
  Future<void> _forgetProvider();
  void _resetLocal();

  @override
  Future<AccountDeletion> accountDeletion() async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    try {
      if (!await _signedInViaOAuth(c)) return const AccountDeletionInApp();
      final page = await _accountManagementPage(c, SdkMatrixGateway.accountDeletionPage);
      if (page == null) throw const GatewayException(GatewayError.serverUnsupported);
      return AccountDeletionInBrowser(page);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Kontoseite des Anbieters nicht ermittelt', e);
      throw _map(e);
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (password.isEmpty || password.length > 1024) throw const GatewayException(GatewayError.invalidInput);
    try {
      if (await _signedInViaOAuth(c)) throw const GatewayException(GatewayError.notAllowed);
      // `erase`: Später beitretende sehen die Nachrichten des Kontos nur noch geschwärzt.
      try {
        await c.deactivateAccount(erase: true);
      } on MatrixException catch (e) {
        final session = e.session;
        if (session == null || e.authenticationFlows == null) rethrow;
        if (!SdkMatrixGateway._offersPassword(e.authenticationFlows!)) {
          throw const GatewayException(GatewayError.serverUnsupported);
        }
        await c.deactivateAccount(
          erase: true,
          auth: AuthenticationPassword(session: session, password: password, identifier: AuthenticationUserIdentifier(user: c.userID!)),
        );
      }
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Kontolöschung fehlgeschlagen', e);
      if (e is MatrixException && (e.errcode == 'M_FORBIDDEN' || e.errcode == 'M_UNAUTHORIZED')) {
        throw const GatewayException(GatewayError.invalidCredentials);
      }
      throw _map(e);
    }
    await _endDeletedSession(c);
  }

  @override
  Future<bool> checkAccountDeleted() async {
    final c = _client;
    if (c == null) return true;
    if (c.isLogged()) {
      try {
        await c.getTokenOwner();
        return false;
      } on MatrixException catch (e) {
        if (e.errcode != 'M_UNKNOWN_TOKEN' && e.errcode != 'M_USER_DEACTIVATED') throw _map(e);
      } catch (e) {
        // Das SDK kann die Sitzung beim gescheiterten Auffrischen des Tokens selbst beenden.
        if (c.isLogged()) {
          AppLog.e('gateway', 'Kontostatus nicht prüfbar', e);
          throw _map(e);
        }
      }
    }
    await _endDeletedSession(c);
    return true;
  }

  /// Das Konto ist beim Anbieter gelöscht: Sitzung nur noch lokal beenden (der Server kennt sie nicht mehr).
  Future<void> _endDeletedSession(Client c) async {
    cancelRegistration();
    _dropOAuth();
    try {
      await c.clear();
    } catch (e) {
      AppLog.e('gateway', 'Lokales Bereinigen fehlgeschlagen', e);
    }
    await _forgetProvider();
    await _localPins.forget();
    _resetLocal();
    notifyListeners();
  }
}
