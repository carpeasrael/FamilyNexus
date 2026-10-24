import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../common/error_text.dart';
import 'provider_controller.dart';

/// Anbieter-Zeile mit aufklappbarem Bereich „Erweitert“ (E-55). Im Normalfall sieht die Person nur, bei
/// wem ihr Konto liegt; Anbieterwechsel, Betreiberangaben und Hinweise stehen eingeklappt darunter.
class ProviderSection extends StatefulWidget {
  const ProviderSection({super.key, required this.controller});

  final ProviderController controller;

  @override
  State<ProviderSection> createState() => _ProviderSectionState();
}

class _ProviderSectionState extends State<ProviderSection> {
  late final TextEditingController _text = TextEditingController(text: widget.controller.customText);
  final ExpansibleController _tile = ExpansibleController();
  late bool _wasCustom;

  @override
  void initState() {
    super.initState();
    _wasCustom = widget.controller.custom;
    widget.controller.addListener(_sync);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }

  /// Der Server kann auch von außen gewählt werden (Einladung, E-63): Feld nachführen und „Erweitert“
  /// aufklappen, damit die Adresse sichtbar im Feld „Anderer Anbieter“ steht.
  void _sync() {
    final c = widget.controller;
    if (_text.text != c.customText) _text.text = c.customText;
    if (c.custom && !_wasCustom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_tile.isExpanded) _tile.expand();
      });
    }
    _wasCustom = c.custom;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final host = c.server?.host ?? '';
        final Widget status = switch (c.status) {
          ProviderStatus.empty => Text(l.advEnterProvider),
          ProviderStatus.needsConsent => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(l.advLocalConsent(host), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: c.connect, child: Text(l.advLocalConnect(host))),
            ]),
          ProviderStatus.checking => Row(children: <Widget>[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Expanded(child: Text(l.advChecking(host))),
            ]),
          ProviderStatus.ready => Row(children: <Widget>[
              Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(l.advServerInfo(host))),
            ]),
          ProviderStatus.invalid => Text(l.serverUrlInvalid, style: TextStyle(color: theme.colorScheme.error)),
          ProviderStatus.failed => Row(children: <Widget>[
              Expanded(
                child: Text(
                  c.error == GatewayError.serverUnreachable
                      ? l.advUnreachable(host)
                      : errorText(l, GatewayException(c.error ?? GatewayError.unknown)),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              TextButton(onPressed: c.retry, child: Text(l.retry)),
            ]),
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Semantics(liveRegion: true, child: status),
          ExpansionTile(
            controller: _tile,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            initiallyExpanded: c.custom,
            title: Text(l.advTitle),
            children: <Widget>[
              Text(l.advExplain, style: theme.textTheme.bodySmall),
              RadioGroup<bool>(
                groupValue: c.custom,
                onChanged: (v) => c.setCustom(v ?? false),
                child: Column(children: <Widget>[
                  RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: false, title: Text(l.advStandardProvider(c.standard.host))),
                  RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: true, title: Text(l.advOtherProvider)),
                ]),
              ),
              if (c.custom)
                TextField(
                  controller: _text,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: l.advProviderLabel, hintText: l.advProviderHint),
                  onChanged: c.setCustomText,
                ),
              if (c.ready) ...<Widget>[
                const SizedBox(height: 8),
                Text(l.serverOperator(c.info!.url.host), style: theme.textTheme.bodySmall),
                Text(c.info!.contact == null ? l.serverContactUnknown : l.serverContact(c.info!.contact!), style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Text(l.serverMetadataNote, style: theme.textTheme.bodySmall),
            ],
          ),
        ]);
      },
    );
  }
}
