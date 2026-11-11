part of '../sdk_matrix_gateway.dart';

/// Passwort ändern (AP-5, #117): Art der Änderung ermitteln und im Konto ändern. Die statische Fehlerzuordnung
/// `passwordChangeError` bleibt in der Klasse (Tests rufen sie als `SdkMatrixGateway.<name>` auf).
mixin _PasswordChangeModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Future<Uri?> _accountManagementPage(Client c, Uri? Function(Map<String, Object?> metadata) pick);
  GatewayException _map(Object e);
  Future<bool> _signedInViaOAuth(Client c);

  @override
  Future<PasswordChange> passwordChange() async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    try {
      if (!await _signedInViaOAuth(c)) return const PasswordChangeInApp();
      final page = await _accountManagementPage(c, SdkMatrixGateway.accountManagementPage);
      return page == null ? const PasswordChangeUnavailable() : PasswordChangeInBrowser(page);
    } catch (e) {
      AppLog.e('gateway', 'Kontoseite des Anbieters nicht ermittelt', e);
      throw _map(e);
    }
  }

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword, required bool logoutOtherDevices}) async {
    try {
      final c = _client;
      if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
      if (await _signedInViaOAuth(c)) throw const GatewayException(GatewayError.notAllowed);
      if (newPassword.length < SdkMatrixGateway.minPasswordLength) throw const GatewayException(GatewayError.weakPassword);
      if (oldPassword.isEmpty || oldPassword.length > 1024 || newPassword.length > PasswordChange.maxLength) {
        throw const GatewayException(GatewayError.invalidInput);
      }
      // Das SDK schickt `oldPassword` schon im ersten Aufruf und wiederholt nur bei genau einem Flow.
      // Darum erst ohne Passwort fragen. `logoutDevices` immer senden: Ohne nimmt Synapse `true` an.
      try {
        await c.changePassword(newPassword, logoutDevices: logoutOtherDevices).timeout(SdkMatrixGateway.roomOpTimeout);
      } on MatrixException catch (e) {
        final session = e.session;
        final flows = e.authenticationFlows;
        if (session == null || flows == null || !SdkMatrixGateway._offersPassword(flows)) rethrow;
        await c
            .changePassword(
              newPassword,
              logoutDevices: logoutOtherDevices,
              auth: AuthenticationPassword(session: session, password: oldPassword, identifier: AuthenticationUserIdentifier(user: c.userID!)),
            )
            .timeout(SdkMatrixGateway.roomOpTimeout);
      }
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Passwortänderung fehlgeschlagen', e);
      if (e is MatrixException) {
        final mapped = SdkMatrixGateway.passwordChangeError(e);
        if (mapped != null) throw mapped;
      }
      throw _map(e);
    }
  }
}
