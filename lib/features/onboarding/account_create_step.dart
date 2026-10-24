import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/registration.dart';
import '../../domain/username_suggestion.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import 'browser_sign_in.dart';
import 'provider_controller.dart';
import 'provider_section.dart';
import 'registration_stage_view.dart';

/// „Konto erstellen“ (E-55): Name, Benutzername (vorgeschlagen und live geprüft) und Passwort. Je nach
/// Anbieter wird das Konto direkt in der App, auf der Seite des Anbieters im Browser oder – falls die
/// App es nicht kann – auf dessen Webseite angelegt.
class AccountCreateStep extends StatefulWidget {
  const AccountCreateStep({super.key, required this.provider, required this.onLogin});

  final ProviderController provider;

  /// „Ich habe schon ein Konto“ (mit dem bisher eingegebenen Benutzernamen).
  final ValueChanged<String?> onLogin;

  @override
  State<AccountCreateStep> createState() => _AccountCreateStepState();
}

class _AccountCreateStepState extends State<AccountCreateStep> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _userEdited = false;
  bool _showPassword = false;
  bool _busy = false;
  bool _waitingForBrowser = false;
  String? _error;
  RegistrationStage? _stage;

  UsernameCheck? _check;
  String? _suggestion;
  Timer? _checkTimer;
  int _checkRun = 0;

  late final AppServices _s = AppScope.read(context);

  @override
  void dispose() {
    _checkTimer?.cancel();
    _name.dispose();
    _user.dispose();
    _pass.dispose();
    if (_stage != null) _s.gateway.cancelRegistration();
    super.dispose();
  }

  void _onName(String v) {
    if (!_userEdited) {
      _user.text = UsernameSuggestion.fromName(v);
      _scheduleCheck();
    }
    setState(() {});
  }

  void _onUser(String v) {
    _userEdited = v.isNotEmpty;
    _scheduleCheck();
  }

  void _scheduleCheck() {
    _checkTimer?.cancel();
    final run = ++_checkRun;
    setState(() {
      _check = null;
      _suggestion = null;
    });
    final name = _user.text.trim();
    if (name.isEmpty) return;
    if (!UsernameSuggestion.isValid(name)) {
      setState(() => _check = UsernameCheck.invalid);
      return;
    }
    _checkTimer = Timer(const Duration(milliseconds: 600), () => _runCheck(name, run));
  }

  Future<void> _runCheck(String name, int run) async {
    final server = widget.provider.server;
    if (server == null) return;
    final result = await _s.gateway.checkUsername(server, name);
    String? alt;
    if (result == UsernameCheck.taken) {
      for (final candidate in UsernameSuggestion.alternatives(name)) {
        if (await _s.gateway.checkUsername(server, candidate) == UsernameCheck.available) {
          alt = candidate;
          break;
        }
      }
    }
    if (!mounted || run != _checkRun) return;
    setState(() {
      _check = result;
      _suggestion = alt;
    });
  }

  void _useSuggestion() {
    final s = _suggestion;
    if (s == null) return;
    _user.text = s;
    _userEdited = true;
    _scheduleCheck();
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
      if (!mounted) return;
      setState(() => _error = errorText(l, e));
      if (e is GatewayException && e.error == GatewayError.usernameTaken) _scheduleCheck();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() => _run(() async {
        final server = widget.provider.server;
        if (server == null || !widget.provider.ready) return;
        final stage = await _s.gateway.register(
          server: server,
          username: _user.text.trim(),
          password: _pass.text,
          displayName: _name.text,
          language: Localizations.localeOf(context).languageCode,
        );
        if (stage == null) _pass.clear();
        if (mounted) setState(() => _stage = stage);
      });

  Future<void> _continue(RegistrationInput input) => _run(() async {
        try {
          final stage = await _s.gateway.continueRegistration(input);
          if (stage == null) _pass.clear();
          if (mounted) setState(() => _stage = stage);
        } on GatewayException catch (e) {
          // Endgültig gescheitert (z. B. Name inzwischen vergeben): zurück zum Formular.
          if (e.error != GatewayError.invalidInput && e.error != GatewayError.rateLimited && e.error != GatewayError.emailInUse) {
            if (mounted) setState(() => _stage = null);
          }
          rethrow;
        }
      });

  void _cancelStage() {
    _s.gateway.cancelRegistration();
    setState(() {
      _stage = null;
      _error = null;
    });
  }

  Future<void> _createInBrowser() => _run(() async {
        final server = widget.provider.server;
        if (server == null) return;
        setState(() => _waitingForBrowser = true);
        try {
          await signInWithBrowser(_s, server, create: true);
        } finally {
          if (mounted) setState(() => _waitingForBrowser = false);
        }
        final name = _name.text.trim();
        if (name.isNotEmpty) {
          try {
            await _s.gateway.setDisplayName(name);
          } catch (_) {
            // Der Name lässt sich später in den Einstellungen des Anbieters ändern; kein Abbruch.
          }
        }
      });

  bool get _formOk =>
      widget.provider.ready &&
      _name.text.trim().isNotEmpty &&
      UsernameSuggestion.isValid(_user.text.trim()) &&
      _check != UsernameCheck.taken &&
      _check != UsernameCheck.invalid &&
      _pass.text.length >= 8;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final p = widget.provider;
        final host = p.server?.host ?? '';
        final stage = _stage;
        final List<Widget> main;
        if (stage != null) {
          main = <Widget>[
            RegistrationStageView(stage: stage, busy: _busy, onInput: _continue, onCancel: _cancelStage),
          ];
        } else if (_waitingForBrowser) {
          main = <Widget>[
            Row(children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Semantics(liveRegion: true, child: Text(l.oauthWaiting(host)))),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => _s.oauthRedirect?.cancel(), child: Text(l.cancel)),
            ),
          ];
        } else if (p.ready && p.mode == RegistrationMode.oauth && _s.oauthRedirect != null) {
          main = <Widget>[
            Text(l.regOAuthIntro(host)),
            const SizedBox(height: 12),
            _nameField(l),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: _busy ? null : _createInBrowser,
                label: Text(l.regOAuthCreate(host)),
              ),
            ),
          ];
        } else if (p.ready && p.mode != RegistrationMode.inApp) {
          final page = p.options?.webPage;
          main = <Widget>[
            Text(l.regExternalBody(host)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: <Widget>[
              if (page != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _s.browser.open(page),
                  label: Text(l.regExternalOpen),
                ),
              FilledButton(onPressed: () => widget.onLogin(null), child: Text(l.regExternalLogin)),
            ]),
          ];
        } else {
          main = <Widget>[
            _nameField(l),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: _onUser,
              decoration: InputDecoration(
                labelText: l.regUsernameLabel,
                helperText: switch (_check) {
                  UsernameCheck.available => l.regUsernameFree,
                  null || UsernameCheck.unknown => l.regUsernameHint,
                  _ => null,
                },
                errorText: switch (_check) {
                  UsernameCheck.taken => _suggestion == null ? l.regUsernameTaken : l.regUsernameTakenSuggest(_suggestion!),
                  UsernameCheck.invalid => l.regUsernameInvalid,
                  _ => null,
                },
                suffixIcon: _check == UsernameCheck.available ? Icon(Icons.check_circle_outline, color: theme.colorScheme.primary) : null,
              ),
            ),
            if (_suggestion != null)
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(label: Text(l.regUseSuggestion(_suggestion!)), onPressed: _useSuggestion),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.accountPassword,
                helperText: l.regPasswordHint,
                helperMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: _showPassword ? l.passwordHide : l.passwordShow,
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy || !_formOk ? null : _register,
                child: Text(_busy ? l.regCreating : l.regCreate),
              ),
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
          if (stage == null && !_waitingForBrowser) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : () => widget.onLogin(_user.text.trim().isEmpty ? null : _user.text.trim()),
                child: Text(l.startHaveAccount),
              ),
            ),
            const Divider(),
            ProviderSection(controller: p),
          ],
        ]);
      },
    );
  }

  Widget _nameField(AppLocalizations l) => TextField(
        controller: _name,
        maxLength: 64,
        textCapitalization: TextCapitalization.words,
        onChanged: _onName,
        decoration: InputDecoration(labelText: l.regNameLabel, hintText: l.regNameHint, counterText: ''),
      );
}
