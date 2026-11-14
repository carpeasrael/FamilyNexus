import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import 'browser_sign_in.dart';
import 'provider_controller.dart';
import 'provider_section.dart';
import 'widgets/sign_in_icons.dart';

part 'widgets/login_parts.dart';

/// „Anmelden“ mit einem bestehenden Konto. Auf Anbietern mit Anmeldung beim Anbieter (OAuth) öffnet sich
/// dessen Seite (in der App, E-91); sonst Benutzername und Passwort. Eine vollständige ID (`@anna:beispiel.de`) wählt den
/// Anbieter selbst aus.
class LoginStep extends StatefulWidget {
  const LoginStep({super.key, required this.provider, this.initialUsername, required this.onCreate});

  final ProviderController provider;
  final String? initialUsername;

  /// „Noch kein Konto? Jetzt erstellen“.
  final VoidCallback onCreate;

  @override
  State<LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends State<LoginStep> {
  late final TextEditingController _user = TextEditingController(text: widget.initialUsername);
  final TextEditingController _pass = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  bool _waitingForBrowser = false;
  String? _error;

  /// Der Vorgang beim Anbieter wurde nicht abgeschlossen (Abbruch): ein Hinweis, kein Fehler (#430).
  bool _errorNotice = false;
  Timer? _idTimer;

  late final AppServices _s;

  @override
  void initState() {
    super.initState();
    _s = AppScope.read(context);
  }

  @override
  void dispose() {
    if (_waitingForBrowser) _s.oauthRedirect?.cancel();
    _idTimer?.cancel();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// `@anna:beispiel.de` eingegeben: Anbieter `beispiel.de` verwenden (nach kurzer Pause).
  void _onUser(String v) {
    _idTimer?.cancel();
    final server = MatrixIds.serverName(v.trim());
    final url = server == null ? null : ServerUrl.tryParse(server);
    if (url != null) _idTimer = Timer(const Duration(milliseconds: 600), () => widget.provider.useServer(url));
    setState(() {});
  }

  Future<void> _run(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _errorNotice = false;
    });
    try {
      await op();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(l, e);
          _errorNotice = isNotice(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() => _run(() async {
        final server = widget.provider.server;
        if (server == null) throw const GatewayException(GatewayError.invalidInput);
        await _s.gateway.login(server: server, username: _user.text, password: _pass.text);
        _pass.clear();
      });

  Future<void> _loginInBrowser() => _run(() async {
        final server = widget.provider.server;
        if (server == null) return;
        setState(() => _waitingForBrowser = true);
        try {
          await signInWithBrowser(_s, server, create: false);
        } finally {
          if (mounted) setState(() => _waitingForBrowser = false);
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final p = widget.provider;
        final host = p.server?.host ?? '';
        final oauth = p.ready && p.usesOAuth && _s.oauthRedirect != null;
        final List<Widget> main;
        if (_waitingForBrowser) {
          main = <Widget>[_LoginBrowserWaiting(host: host, onCancel: () => _s.oauthRedirect?.cancel())];
        } else if (oauth) {
          main = <Widget>[_LoginOAuth(host: host, busy: _busy, onLogin: _loginInBrowser)];
        } else {
          // Vollständige ID eines anderen Anbieters: erst nach dem Wechsel anmelden, nie das Passwort an
          // den bisher gewählten Anbieter senden.
          final idServer = MatrixIds.serverName(_user.text.trim());
          final idUrl = idServer == null ? null : ServerUrl.tryParse(idServer);
          final providerMatches = idUrl == null || p.server == idUrl;
          final canLogin = p.ready &&
              providerMatches &&
              p.info!.supportsPasswordLogin &&
              _user.text.trim().isNotEmpty &&
              _pass.text.isNotEmpty;
          main = <Widget>[
            _LoginPasswordForm(
              user: _user,
              password: _pass,
              show: _showPassword,
              busy: _busy,
              canLogin: canLogin,
              noPasswordLogin: p.ready && !p.info!.supportsPasswordLogin,
              onUser: _onUser,
              onPassword: () => setState(() {}),
              onToggleShow: () => setState(() => _showPassword = !_showPassword),
              onLogin: _login,
            ),
          ];
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          ...main,
          if (_error != null) OnboardingMessage(text: _error!, notice: _errorNotice),
          if (!_waitingForBrowser) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _busy ? null : widget.onCreate, child: Text(l.loginNoAccount)),
            ),
            const Divider(),
            ProviderSection(controller: p),
          ],
        ]);
      },
    );
  }
}
