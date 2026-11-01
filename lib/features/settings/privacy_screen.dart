import 'package:flutter/material.dart';

import '../../core/platform_info.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';

/// Die Abschnitte der Datenschutzerklärung. Im Browser ([web]) gibt es keine Erinnerungen und keine
/// Berechtigungen dafür (E-53, #145): Abschnitt 5 entfällt, Abschnitt 6 hat eine eigene Fassung, Abschnitt 13
/// kommt hinzu. [web] ist ein Parameter, weil `kIsWeb` im Test konstant false ist.
List<(String, String)> privacySections(AppLocalizations l, {required bool web}) => <(String, String)>[
      (l.privacy1Title, l.privacy1Body),
      (l.privacy2Title, l.privacy2Body),
      (l.privacy3Title, l.privacy3Body),
      (l.privacy4Title, l.privacy4Body),
      if (!web) (l.privacy5Title, l.privacy5Body),
      (l.privacy6Title, web ? l.privacy6BodyWeb : l.privacy6Body),
      (l.privacy7Title, l.privacy7Body),
      (l.privacy8Title, l.privacy8Body),
      (l.privacy9Title, l.privacy9Body),
      (l.privacy10Title, l.privacy10Body),
      (l.privacy11Title, l.privacy11Body),
      (l.privacy12Title, l.privacy12Body),
      if (web) (l.privacy13Title, l.privacy13Body),
    ];

/// Datenschutzerklärung (de/en aus den ARB-Dateien).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = privacySections(l, web: PlatformInfo.isWeb);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Semantics(header: true, child: Text(s.$1, style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(height: 6),
                  Text(s.$2),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
