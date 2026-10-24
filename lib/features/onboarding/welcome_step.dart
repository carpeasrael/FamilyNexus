import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../l10n/gen/app_localizations.dart';

/// Wege durch die Einrichtung (E-55).
enum OnboardingPath { create, invited, login }

/// Startseite: drei große Wege statt Fachbegriffen. Die Sprache lässt sich unten umschalten.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onChoose});

  final ValueChanged<OnboardingPath> onChoose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final lang = s.settings.settings.languageCode;
    Widget choice(OnboardingPath path, IconData icon, String title, String body) => Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChoose(path),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: <Widget>[
                Icon(icon, size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Semantics(
                    button: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(body, style: theme.textTheme.bodySmall),
                    ]),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.onbIntro),
      const SizedBox(height: 16),
      choice(OnboardingPath.create, Icons.family_restroom, l.startCreateTitle, l.startCreateBody),
      choice(OnboardingPath.invited, Icons.mark_email_unread_outlined, l.startInvitedTitle, l.startInvitedBody),
      choice(OnboardingPath.login, Icons.login, l.startLoginTitle, l.startLoginBody),
      const SizedBox(height: 16),
      for (final p in <String>[l.onbPoint1, l.onbPoint2, l.onbPoint3])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(p, style: theme.textTheme.bodySmall)),
          ]),
        ),
      const SizedBox(height: 16),
      Text(l.settingsLanguage, style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: <Widget>[
        for (final e in <String?, String>{null: l.languageSystem, 'de': l.languageGerman, 'en': l.languageEnglish}.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: lang == e.key,
            onSelected: (_) => s.settings.update((c) => c.copyWith(languageCode: e.key)),
          ),
      ]),
    ]);
  }
}
