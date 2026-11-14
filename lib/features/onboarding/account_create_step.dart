import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/platform/element_launcher.dart';
import '../../domain/registration.dart';
import '../../l10n/gen/app_localizations.dart';
import 'account_create_controller.dart';
import 'browser_sign_in.dart';
import 'provider_controller.dart';
import 'provider_section.dart';
import 'registration_stage_view.dart';
import 'widgets/sign_in_icons.dart';

part 'widgets/account_create_parts.dart';

/// „Konto erstellen“ (E-55): Name, Benutzername (vorgeschlagen und live geprüft) und Passwort. Je nach
/// Anbieter wird das Konto direkt in der App, auf der Seite des Anbieters (in der App, E-91) oder – falls
/// die App es nicht kann – auf dessen Webseite angelegt. Zustand und Aktionen liegen im [AccountCreateController].
class AccountCreateStep extends StatefulWidget {
  const AccountCreateStep({super.key, required this.provider, required this.onLogin});

  final ProviderController provider;

  /// „Ich habe schon ein Konto“ (mit dem bisher eingegebenen Benutzernamen).
  final ValueChanged<String?> onLogin;

  @override
  State<AccountCreateStep> createState() => _AccountCreateStepState();
}

class _AccountCreateStepState extends State<AccountCreateStep> {
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final FocusNode _passRepeatFocus = FocusNode();
  late final AppServices _s;
  late final AccountCreateController _c;

  @override
  void initState() {
    super.initState();
    _s = AppScope.read(context);
    _c = AccountCreateController(
      gateway: _s.gateway,
      provider: widget.provider,
      signInInBrowser: (server) => signInWithBrowser(_s, server, create: true),
      cancelBrowserSignIn: () => _s.oauthRedirect?.cancel(),
      launchElement: () => _s.element.open(),
      requestFocus: _focus,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _nameFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _passRepeatFocus.dispose();
    super.dispose();
  }

  void _focus(AccountField field) {
    switch (field) {
      case AccountField.provider:
        break;
      case AccountField.name:
        _nameFocus.requestFocus();
      case AccountField.user:
        _userFocus.requestFocus();
      case AccountField.pass:
        _passFocus.requestFocus();
      case AccountField.repeat:
        _passRepeatFocus.requestFocus();
    }
  }

  void _submit() => _c.submit(AppLocalizations.of(context), Localizations.localeOf(context).languageCode);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[widget.provider, _c]),
      builder: (context, _) {
        final p = widget.provider;
        final host = p.server?.host ?? '';
        final stage = _c.stage;
        final List<Widget> main;
        if (stage != null) {
          main = <Widget>[
            RegistrationStageView(stage: stage, busy: _c.busy, onInput: _c.continueRegistration, onCancel: _c.cancelStage),
          ];
        } else if (_c.waitingForBrowser) {
          main = <Widget>[_BrowserWaiting(host: host, onCancel: () => _s.oauthRedirect?.cancel())];
        } else if (p.ready && p.mode == RegistrationMode.oauth && _s.oauthRedirect != null) {
          main = <Widget>[
            _OAuthCreate(host: host, nameField: _nameField(l), busy: _c.busy, onCreate: _c.createInBrowser),
          ];
        } else if (p.ready && p.mode != RegistrationMode.inApp) {
          final page = p.options?.webPage;
          main = <Widget>[
            _ExternalCreate(
              host: host,
              elementMissing: _c.elementMissing,
              onOpenPage: page == null ? null : () => _s.browser.open(page, inApp: true),
              onOpenElement: _c.openElement,
              onLogin: () => widget.onLogin(null),
              onDownload: () => _s.browser.open(ElementLauncher.downloadPage),
            ),
          ];
        } else {
          main = <Widget>[
            _nameField(l),
            const SizedBox(height: 12),
            _UsernameFields(
              controller: _c.user,
              focusNode: _userFocus,
              check: _c.check,
              suggestion: _c.suggestion,
              inputError: _c.errorAt(AccountField.user),
              onChanged: _c.onUser,
              onUseSuggestion: _c.useSuggestion,
            ),
            const SizedBox(height: 12),
            _PasswordFields(
              password: _c.password,
              passwordFocus: _passFocus,
              repeat: _c.passwordRepeat,
              repeatFocus: _passRepeatFocus,
              show: _c.showPassword,
              passwordError: _c.errorAt(AccountField.pass),
              repeatError: _c.errorAt(AccountField.repeat),
              onChanged: _c.clearInputError,
              onToggleShow: _c.toggleShowPassword,
              onSubmit: _submit,
            ),
            const SizedBox(height: 16),
            _SubmitButton(busy: _c.busy, enabled: _c.formOk, onSubmit: _submit),
          ];
        }
        final errorLine = _c.errorLine(l);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          ...main,
          if (errorLine != null) OnboardingMessage(text: errorLine, notice: _c.errorIsNotice),
          if (stage == null && !_c.waitingForBrowser) ...<Widget>[
            const SizedBox(height: 8),
            _HaveAccountButton(
              onPressed: _c.busy ? null : () => widget.onLogin(_c.user.text.trim().isEmpty ? null : _c.user.text.trim()),
            ),
            const Divider(),
            ProviderSection(controller: p),
          ],
        ]);
      },
    );
  }

  Widget _nameField(AppLocalizations l) => TextField(
        controller: _c.name,
        focusNode: _nameFocus,
        maxLength: 64,
        textCapitalization: TextCapitalization.words,
        onChanged: _c.onName,
        decoration: InputDecoration(
          labelText: l.regNameLabel,
          hintText: l.regNameHint,
          counterText: '',
          errorText: _c.errorAt(AccountField.name),
          errorMaxLines: 3,
        ),
      );
}
