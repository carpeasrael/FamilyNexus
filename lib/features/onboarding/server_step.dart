import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'provider_controller.dart';
import 'provider_section.dart';

/// Schritt „Anbieter wählen“ vor Konto erstellen und Anmelden (E-108, #545): der empfohlene Anbieter oder ein anderer
/// bzw. eigener Server mit Adresse. „Weiter“ geht unabhängig vom Prüfstatus weiter (der Schritt „Anmelden“ leitet den
/// Server notfalls aus dem Benutzernamen ab, E-55); nur eine leere oder ungültige eigene Adresse hält auf und wird
/// am Feld genannt.
class ServerStep extends StatefulWidget {
  const ServerStep({super.key, required this.provider, required this.onContinue});

  final ProviderController provider;
  final VoidCallback onContinue;

  @override
  State<ServerStep> createState() => _ServerStepState();
}

class _ServerStepState extends State<ServerStep> {
  late final TextEditingController _text = TextEditingController(text: widget.provider.customText);
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_sync);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_sync);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Der Server kann auch von außen gesetzt werden: Feld nachführen.
  void _sync() {
    final c = widget.provider;
    if (_text.text != c.customText) _text.text = c.customText;
  }

  void _continue(AppLocalizations l) {
    final c = widget.provider;
    if (c.server == null) {
      setState(() => _error = c.status == ProviderStatus.empty ? l.advEnterProvider : l.serverUrlInvalid);
      _focus.requestFocus();
      return;
    }
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.provider;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.serverStepIntro),
        const SizedBox(height: 12),
        RadioGroup<bool>(
          groupValue: c.custom,
          onChanged: (v) {
            setState(() => _error = null);
            c.setCustom(v ?? false);
          },
          child: Column(children: <Widget>[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: RadioListTile<bool>(
                value: false,
                title: Text(l.advStandardProvider(c.standard.host)),
                subtitle: Text(l.serverStandardBody),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: RadioListTile<bool>(
                value: true,
                title: Text(l.serverOtherTitle),
                subtitle: Text(l.serverOtherBody),
              ),
            ),
          ]),
        ),
        if (c.custom) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            focusNode: _focus,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.advProviderLabel, hintText: l.advProviderHint, errorText: _error),
            onChanged: (v) {
              if (_error != null) setState(() => _error = null);
              c.setCustomText(v);
            },
            onSubmitted: (_) => _continue(l),
          ),
        ],
        const SizedBox(height: 12),
        ProviderStatusLine(controller: c, inStep: true),
        if (c.ready) ...<Widget>[
          const SizedBox(height: 8),
          Text(l.serverOperator(c.info!.url.host), style: theme.textTheme.bodySmall),
          Text(
            c.info!.contact == null ? l.serverContactUnknown : l.serverContact(c.info!.contact!),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(l.serverMetadataNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => _continue(l), child: Text(l.next)),
      ]),
    );
  }
}
