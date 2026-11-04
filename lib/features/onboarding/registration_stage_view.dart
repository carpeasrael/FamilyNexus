import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/registration.dart';
import '../../l10n/gen/app_localizations.dart';

/// Zusatzschritt, den der Anbieter bei der Kontoanlage verlangt (E-55): Bedingungen, E-Mail,
/// Einladungscode oder „kein Roboter“ auf der Seite des Anbieters (in der App, E-91). Jede Antwort geht über [onInput] an das Gateway.
class RegistrationStageView extends StatefulWidget {
  const RegistrationStageView({
    super.key,
    required this.stage,
    required this.busy,
    required this.onInput,
    required this.onCancel,
  });

  final RegistrationStage stage;
  final bool busy;
  final ValueChanged<RegistrationInput> onInput;
  final VoidCallback onCancel;

  @override
  State<RegistrationStageView> createState() => _RegistrationStageViewState();
}

class _RegistrationStageViewState extends State<RegistrationStageView> with WidgetsBindingObserver {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _token = TextEditingController();
  bool _agreed = false;
  bool _captchaOpened = false;

  /// Die Captcha-Seite ist offen und die Plattform meldet ihr Ende selbst (iOS/macOS): `resumed` zählt nicht.
  bool _sessionWaiting = false;

  /// Die Captcha-Seite ließ sich nicht öffnen (Hinweis unter dem Knopf).
  bool _noPage = false;

  /// Zählt die Öffnungen; nur die letzte darf die Prüfung auslösen.
  int _captchaRun = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RegistrationStageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stage != oldWidget.stage) _noPage = false;
  }

  /// Zurück von der Seite des Anbieters (Ende der Sitzung bzw. `resumed`): Captcha automatisch erneut
  /// prüfen (kein zusätzlicher Tipp nötig). Solange die Sitzung offen ist, zählt `resumed` nicht (Face ID,
  /// Autofill und das Erscheinen der Sitzung selbst lösen es aus).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_sessionWaiting) _checkCaptcha();
  }

  void _checkCaptcha() {
    if (mounted && _captchaOpened && widget.stage is CaptchaStage && !widget.busy) {
      _captchaOpened = false;
      widget.onInput(const CaptchaDone());
    }
  }

  Future<void> _open(Uri uri) => AppScope.read(context).browser.open(uri, inApp: true);

  Future<void> _openCaptcha(Uri page) async {
    final run = ++_captchaRun;
    setState(() => _noPage = false);
    _captchaOpened = true;
    _sessionWaiting = true;
    final opening = await AppScope.read(context).browser.openInApp(page);
    if (!mounted || run != _captchaRun) return;
    if (!opening.opened) {
      setState(() {
        _sessionWaiting = false;
        _captchaOpened = false;
        _noPage = true;
      });
      return;
    }
    final ended = await opening.waited;
    if (!mounted || run != _captchaRun) return;
    _sessionWaiting = false;
    // Ende gemeldet (iOS/macOS): jetzt prüfen. Sonst (Android, Desktop, externer Rückfall) prüft `resumed`.
    if (ended) _checkCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final err = TextStyle(color: theme.colorScheme.error);
    final busy = widget.busy;
    final List<Widget> body = switch (widget.stage) {
      TermsStage(:final policies) => <Widget>[
          Text(l.regTermsBody),
          const SizedBox(height: 8),
          for (final p in policies)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () => _open(p.url), label: Text(p.name)),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            title: Text(l.regTermsAgree),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: !_agreed || busy ? null : () => widget.onInput(const AcceptTerms()), child: Text(l.next)),
          ),
        ],
      EmailStage(:final sent, :final notConfirmedYet) when !sent => <Widget>[
          Text(l.regEmailBody),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.regEmailLabel, errorText: _localError),
          ),
          if (notConfirmedYet) Text(l.regEmailNotYet, style: err),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: busy ? null : _sendEmail, child: Text(l.regEmailSend))),
        ],
      EmailStage(:final notConfirmedYet) => <Widget>[
          Text(l.regEmailSent(_email.text.trim())),
          if (notConfirmedYet) ...<Widget>[const SizedBox(height: 8), Semantics(liveRegion: true, child: Text(l.regEmailNotYet, style: err))],
          const SizedBox(height: 12),
          // Hauptaktion zuerst und in voller Breite, Nebenaktion darunter.
          FilledButton(onPressed: busy ? null : () => widget.onInput(const EmailConfirmed()), child: Text(l.regEmailConfirmed)),
          const SizedBox(height: 8),
          TextButton(onPressed: busy ? null : _sendEmail, child: Text(l.regEmailResend)),
        ],
      TokenStage(:final wrong) => <Widget>[
          Text(l.regTokenBody),
          const SizedBox(height: 8),
          TextField(
            controller: _token,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.regTokenLabel, errorText: wrong ? l.regTokenWrong : null),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: busy ? null : () => widget.onInput(SubmitToken(_token.text)), child: Text(l.next)),
          ),
        ],
      CaptchaStage(:final page, :final notDoneYet) => <Widget>[
          Text(l.regCaptchaBody),
          if (notDoneYet) ...<Widget>[const SizedBox(height: 8), Semantics(liveRegion: true, child: Text(l.regCaptchaNotYet, style: err))],
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: busy ? null : () => _openCaptcha(page),
            label: Text(l.regCaptchaOpen),
          ),
          if (_noPage) ...<Widget>[const SizedBox(height: 8), Semantics(liveRegion: true, child: Text(l.regCaptchaNoPage, style: err))],
          const SizedBox(height: 8),
          OutlinedButton(onPressed: busy ? null : () => widget.onInput(const CaptchaDone()), child: Text(l.regCaptchaDone)),
        ],
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Semantics(header: true, child: Text(l.regExtraTitle, style: theme.textTheme.titleMedium)),
      const SizedBox(height: 8),
      ...body,
      const SizedBox(height: 4),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: busy ? null : widget.onCancel, child: Text(l.cancel))),
    ]);
  }

  void _sendEmail() {
    final l = AppLocalizations.of(context);
    if (!isPlausibleEmail(_email.text)) {
      setState(() => _localError = l.regEmailInvalid);
      return;
    }
    setState(() => _localError = null);
    widget.onInput(SubmitEmail(_email.text.trim()));
  }
}
