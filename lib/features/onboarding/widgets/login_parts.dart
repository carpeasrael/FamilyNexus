part of '../login_step.dart';

/// Wartet auf die Rückkehr aus der Browser-Anmeldung (OAuth).
class _LoginBrowserWaiting extends StatelessWidget {
  const _LoginBrowserWaiting({required this.host, required this.onCancel});
  final String host;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Semantics(liveRegion: true, child: Text(l.oauthWaiting(host)))),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: onCancel, child: Text(l.cancel)),
      ),
    ]);
  }
}

/// Anbieter mit Anmeldung beim Anbieter (OAuth): Hinweis und Schaltfläche.
class _LoginOAuth extends StatelessWidget {
  const _LoginOAuth({required this.host, required this.busy, required this.onLogin});
  final String host;
  final bool busy;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.loginOAuthIntro(host)),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          icon: Icon(providerPageIcon(context, Icons.login), size: 18),
          onPressed: busy ? null : onLogin,
          label: Text(l.loginOAuth(host)),
        ),
      ),
    ]);
  }
}

/// Benutzername, Passwort und „Anmelden“.
class _LoginPasswordForm extends StatelessWidget {
  const _LoginPasswordForm({
    required this.user,
    required this.password,
    required this.show,
    required this.busy,
    required this.canLogin,
    required this.noPasswordLogin,
    required this.onUser,
    required this.onPassword,
    required this.onToggleShow,
    required this.onLogin,
  });
  final TextEditingController user;
  final TextEditingController password;
  final bool show;
  final bool busy;
  final bool canLogin;

  /// Der Anbieter bietet keine Anmeldung mit Passwort an.
  final bool noPasswordLogin;
  final ValueChanged<String> onUser;
  final VoidCallback onPassword;
  final VoidCallback onToggleShow;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      TextField(
        controller: user,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        onChanged: onUser,
        decoration: InputDecoration(labelText: l.accountUsername),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: password,
        obscureText: !show,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        onChanged: (_) => onPassword(),
        onSubmitted: (_) => canLogin && !busy ? onLogin() : null,
        decoration: InputDecoration(
          labelText: l.accountPassword,
          suffixIcon: IconButton(
            tooltip: show ? l.passwordHide : l.passwordShow,
            icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: onToggleShow,
          ),
        ),
      ),
      if (noPasswordLogin)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.serverNoPassword, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(onPressed: busy || !canLogin ? null : onLogin, child: Text(busy ? l.accountLoggingIn : l.accountLogin)),
      ),
    ]);
  }
}
