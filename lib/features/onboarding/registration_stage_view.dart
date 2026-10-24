import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/registration.dart';
import '../../l10n/gen/app_localizations.dart';

/// Zusatzschritt, den der Anbieter bei der Kontoanlage verlangt (E-55): Bedingungen, E-Mail,
/// Einladungscode oder „kein Roboter“ im Browser. Jede Antwort geht über [onInput] an das Gateway.
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

  /// Zurück aus dem Browser: Captcha automatisch erneut prüfen (kein zusätzlicher Tipp nötig).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _captchaOpened && widget.stage is CaptchaStage && !widget.busy) {
      _captchaOpened = false;
      widget.onInput(const CaptchaDone());
    }
  }

  Future<void> _open(Uri uri) => AppScope.read(context).browser.open(uri);

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
            onPressed: busy
                ? null
                : () {
                    _captchaOpened = true;
                    _open(page);
                  },
            label: Text(l.regCaptchaOpen),
          ),
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
