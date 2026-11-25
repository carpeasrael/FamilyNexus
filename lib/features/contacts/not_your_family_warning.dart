import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'contact_text.dart';

/// Warnung „Nicht deine Familie: …“ (mit Kennung) bei Namensgleichheit mit einem Familienmitglied (§9.1): Symbol **und** Text
/// (nie nur Farbe), die Kennung mit Unicode-Isolierung.
class NotYourFamilyWarning extends StatelessWidget {
  const NotYourFamilyWarning({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        container: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(l.contactsNotYourFamily(isolateText(userId)), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
        ]),
      ),
    );
  }
}
