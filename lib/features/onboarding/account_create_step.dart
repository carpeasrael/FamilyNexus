import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/app_log.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../data/platform/element_launcher.dart';
import '../../domain/registration.dart';
import '../../domain/server.dart';
import '../../domain/username_suggestion.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import 'browser_sign_in.dart';
import 'provider_controller.dart';
import 'provider_section.dart';
import 'registration_stage_view.dart';

part 'widgets/account_create_parts.dart';

/// „Konto erstellen“ (E-55): Name, Benutzername (vorgeschlagen und live geprüft) und Passwort. Je nach
/// Anbieter wird das Konto direkt in der App, auf der Seite des Anbieters (in der App, E-91) oder – falls
/// die App es nicht kann – auf dessen Webseite angelegt.
/// Formularstelle, zu der ein Eingabegrund gehört; `provider` hat kein Feld.
enum _Input { provider, name, user, pass, repeat }

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
  final TextEditingController _passRepeat = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final FocusNode _passRepeatFocus = FocusNode();
  bool _userEdited = false;
  bool _showPassword = false;
  bool _busy = false;
  bool _waitingForBrowser = false;
  bool _elementMissing = false;
  String? _error;

  /// Warum Enter nicht abgeschickt hat. Getrennt von [_error]: Eingaben löschen nur diesen Grund,
  /// Serverfehler bleiben bis zum nächsten Absenden stehen.
  String? _inputError;
  _Input? _inputField;
  RegistrationStage? _stage;

  UsernameCheck? _check;
  String? _suggestion;
  Timer? _checkTimer;
  int _checkRun = 0;

  late final AppServices _s;
  ServerUrl? _checkedServer;

  @override
  void initState() {
    super.initState();
    _s = AppScope.read(context);
    widget.provider.addListener(_onProvider);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProvider);
    _checkTimer?.cancel();
    _name.dispose();
    _user.dispose();
    _pass.dispose();
    _passRepeat.dispose();
    _nameFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _passRepeatFocus.dispose();
    // Nichts darf weiterlaufen, wenn der Schritt verlassen wird: Registrierung (samt Passwort) und
    // Browser-Anmeldung beenden.
    _s.gateway.cancelRegistration();
    if (_waitingForBrowser) _s.oauthRedirect?.cancel();
    super.dispose();
  }

  /// Anderer Anbieter: „frei/vergeben“ galt für den alten und wird neu geprüft.
  void _onProvider() {
    final p = widget.provider;
    if (p.ready && p.server != _checkedServer && _user.text.trim().isNotEmpty) _scheduleCheck();
    if (p.ready && _inputField == _Input.provider) setState(_clearInputError);
  }

  void _clearInputError() {
    _inputError = null;
    _inputField = null;
  }

  void _onName(String v) {
    _clearInputError();
    if (!_userEdited) {
      _user.text = UsernameSuggestion.fromName(v);
      _scheduleCheck();
    }
    setState(() {});
  }

  void _onUser(String v) {
    _clearInputError();
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
    _checkedServer = server;
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
    _clearInputError();
    _user.text = s;
    _userEdited = true;
    _scheduleCheck();
  }

  Future<void> _run(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _clearInputError();
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
        if (stage == null) _clearPasswords();
        if (mounted) setState(() => _stage = stage);
      });

  void _clearPasswords() {
    _pass.clear();
    _passRepeat.clear();
  }

  Future<void> _continue(RegistrationInput input) => _run(() async {
        try {
          final stage = await _s.gateway.continueRegistration(input);
          if (stage == null) _clearPasswords();
          if (mounted) setState(() => _stage = stage);
        } on GatewayException catch (e) {
          // Vorübergehend (Netz, Überlastung, Eingabe): Schritt bleibt, erneut versuchen möglich – das
          // Gateway behält die Registrierung genau in diesen Fällen. Sonst endgültig: zurück zum Formular
          // und Registrierung samt Passwort verwerfen.
          const keep = <GatewayError>{
            GatewayError.invalidInput,
            GatewayError.rateLimited,
            GatewayError.emailInUse,
            GatewayError.serverUnreachable,
          };
          if (!keep.contains(e.error)) {
            _s.gateway.cancelRegistration();
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
          } catch (e) {
            // Der Name lässt sich später in den Einstellungen des Anbieters ändern; kein Abbruch.
            AppLog.w('onboarding', 'Anzeigename nicht gesetzt (${e.runtimeType})');
          }
        }
      });

  bool get _formOk =>
      widget.provider.ready &&
      _name.text.trim().isNotEmpty &&
      UsernameSuggestion.isValid(_user.text.trim()) &&
      _check != UsernameCheck.taken &&
      _check != UsernameCheck.invalid &&
      _pass.text.length >= 8 &&
      _pass.text == _passRepeat.text;

  /// Enter im letzten Feld und Knopf: absenden oder den ersten Grund nennen, der dagegen spricht.
  void _submit() {
    if (_busy) return;
    if (_formOk) {
      _register();
      return;
    }
    final l = AppLocalizations.of(context);
    final user = _user.text.trim();
    if (!widget.provider.ready) {
      _refuse(l.regProviderNotReady, _Input.provider);
    } else if (_name.text.trim().isEmpty) {
      _refuse(l.regNameMissing, _Input.name);
    } else if (!UsernameSuggestion.isValid(user) || _check == UsernameCheck.invalid) {
      _refuse(l.regUsernameInvalid, _Input.user);
    } else if (_check == UsernameCheck.taken) {
      _refuse(l.regUsernameTaken, _Input.user);
    } else if (_pass.text.length < 8) {
      _refuse(l.regPasswordTooShort, _Input.pass);
    } else {
      _refuse(l.regPasswordMismatch, _Input.repeat);
    }
  }

  /// Der Grund steht in der Fehlerzeile und am Feld: Das Vorlesen des fokussierten Feldes kann die
  /// Live-Region verdrängen, `errorText` wird mit dem Feld mitgelesen.
  void _refuse(String text, _Input field) {
    setState(() {
      _inputError = text;
      _inputField = field;
    });
    switch (field) {
      case _Input.provider:
        break;
      case _Input.name:
        _nameFocus.requestFocus();
      case _Input.user:
        _userFocus.requestFocus();
      case _Input.pass:
        _passFocus.requestFocus();
      case _Input.repeat:
        _passRepeatFocus.requestFocus();
    }
  }

  String? _errorAt(_Input field) => _inputField == field ? _inputError : null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
          main = <Widget>[_BrowserWaiting(host: host, onCancel: () => _s.oauthRedirect?.cancel())];
        } else if (p.ready && p.mode == RegistrationMode.oauth && _s.oauthRedirect != null) {
          main = <Widget>[
            _OAuthCreate(host: host, nameField: _nameField(l), busy: _busy, onCreate: _createInBrowser),
          ];
        } else if (p.ready && p.mode != RegistrationMode.inApp) {
          final page = p.options?.webPage;
          main = <Widget>[
            _ExternalCreate(
              host: host,
              elementMissing: _elementMissing,
              onOpenPage: page == null ? null : () => _s.browser.open(page, inApp: true),
              onOpenElement: _openElement,
              onLogin: () => widget.onLogin(null),
              onDownload: () => _s.browser.open(ElementLauncher.downloadPage),
            ),
          ];
        } else {
          main = <Widget>[
            _nameField(l),
            const SizedBox(height: 12),
            _UsernameFields(
              controller: _user,
              focusNode: _userFocus,
              check: _check,
              suggestion: _suggestion,
              inputError: _errorAt(_Input.user),
              onChanged: _onUser,
              onUseSuggestion: _useSuggestion,
            ),
            const SizedBox(height: 12),
            _PasswordFields(
              password: _pass,
              passwordFocus: _passFocus,
              repeat: _passRepeat,
              repeatFocus: _passRepeatFocus,
              show: _showPassword,
              passwordError: _errorAt(_Input.pass),
              repeatError: _errorAt(_Input.repeat),
              onChanged: () => setState(_clearInputError),
              onToggleShow: () => setState(() => _showPassword = !_showPassword),
              onSubmit: _submit,
            ),
            const SizedBox(height: 16),
            _SubmitButton(busy: _busy, enabled: _formOk, onSubmit: _submit),
          ];
        }
        final errorLine = _inputError ?? _error;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          ...main,
          if (errorLine != null) _CreateError(text: errorLine),
          if (stage == null && !_waitingForBrowser) ...<Widget>[
            const SizedBox(height: 8),
            _HaveAccountButton(
              onPressed: _busy ? null : () => widget.onLogin(_user.text.trim().isEmpty ? null : _user.text.trim()),
            ),
            const Divider(),
            ProviderSection(controller: p),
          ],
        ]);
      },
    );
  }

  /// Ausweg ohne Kontoanlage in der App: Element starten; fehlt es, Hinweis mit Download.
  Future<void> _openElement() async {
    final started = await _s.element.open();
    if (mounted) setState(() => _elementMissing = !started);
  }

  Widget _nameField(AppLocalizations l) => TextField(
        controller: _name,
        focusNode: _nameFocus,
        maxLength: 64,
        textCapitalization: TextCapitalization.words,
        onChanged: _onName,
        decoration: InputDecoration(
          labelText: l.regNameLabel,
          hintText: l.regNameHint,
          counterText: '',
          errorText: _errorAt(_Input.name),
          errorMaxLines: 3,
        ),
      );
}
