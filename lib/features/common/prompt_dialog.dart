import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Einfacher Texteingabe-Dialog. Der Controller gehört dem Dialog und wird erst nach
/// dem vollständigen Schließen (inkl. Ausblend-Animation) freigegeben.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initial = '',
    this.hint,
    this.obscure = false,
    this.maxLength,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initial;
  final String? hint;
  final bool obscure;
  final int? maxLength;

  static Future<String?> show(BuildContext context, TextPromptDialog dialog) =>
      showDialog<String>(context: context, builder: (_) => dialog);

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop(context, _ctrl.text);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (widget.hint != null) ...<Widget>[Text(widget.hint!), const SizedBox(height: 12)],
        TextField(
          controller: _ctrl,
          autofocus: true,
          obscureText: widget.obscure,
          maxLength: widget.maxLength,
          autocorrect: false,
          enableSuggestions: !widget.obscure,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: widget.label),
          // Enter (Desktop) bzw. „Fertig“ (Tastatur) bestätigt wie die Schaltfläche (#68).
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirm(),
        ),
      ]),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
