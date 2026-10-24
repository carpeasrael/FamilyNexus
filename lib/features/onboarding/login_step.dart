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

/// „Anmelden“ mit einem bestehenden Konto. Auf Anbietern mit Browser-Anmeldung (OAuth) öffnet sich
/// deren Seite; sonst Benutzername und Passwort. Eine vollständige ID (`@anna:beispiel.de`) wählt den
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
  Timer? _idTimer;

  late final AppServices _s = AppScope.read(context);

  @override
  void dispose() {
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
    if (url != null) _idTimer = Timer(const Duration(milliseconds: 600), () => widget.provider.useStandard(url));
    setState(() {});
  }

  Future<void> _run(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
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
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final p = widget.provider;
        final host = p.server?.host ?? '';
        final oauth = p.ready && p.usesOAuth && _s.oauthRedirect != null;
        final List<Widget> main;
        if (_waitingForBrowser) {
          main = <Widget>[
            Row(children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Semantics(liveRegion: true, child: Text(l.oauthWaiting(host)))),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => _s.oauthRedirect?.cancel(), child: Text(l.cancel)),
            ),
          ];
        } else if (oauth) {
          main = <Widget>[
            Text(l.loginOAuthIntro(host)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: _busy ? null : _loginInBrowser,
                label: Text(l.loginOAuth(host)),
              ),
            ),
          ];
        } else {
          final canLogin = p.ready && p.info!.supportsPasswordLogin && _user.text.trim().isNotEmpty && _pass.text.isNotEmpty;
          main = <Widget>[
            TextField(
              controller: _user,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: _onUser,
              decoration: InputDecoration(labelText: l.accountUsername),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => canLogin && !_busy ? _login() : null,
              decoration: InputDecoration(
                labelText: l.accountPassword,
                suffixIcon: IconButton(
                  tooltip: _showPassword ? l.passwordHide : l.passwordShow,
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            if (p.ready && !p.info!.supportsPasswordLogin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.serverNoPassword, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _busy || !canLogin ? null : _login, child: Text(_busy ? l.accountLoggingIn : l.accountLogin)),
            ),
          ];
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          ...main,
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
            ),
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
