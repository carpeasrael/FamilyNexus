import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/platform/oauth_redirect.dart';
import '../../../ui/theme/tokens.dart';

/// Symbol für eine Schaltfläche, die eine Seite des Anbieters öffnet (#430, E-91). Öffnet die Seite in der
/// Sitzung der App (iOS/macOS-Anmeldesitzung, Android-Custom-Tab), steht [inSession]; nur dort, wo wirklich der
/// externe Browser öffnet (Linux, Windows, Web), bleibt „extern öffnen“.
IconData providerPageIcon(BuildContext context, IconData inSession) =>
    providerPageIconFor(oauthFlowFor(isWeb: kIsWeb, platform: Theme.of(context).platform), inSession);

/// Wie [providerPageIcon], aber mit gegebenem Ablauf (für Tests).
IconData providerPageIconFor(OAuthFlow flow, IconData inSession) => switch (flow) {
      OAuthFlow.authSession || OAuthFlow.customTab => inSession,
      OAuthFlow.loopback || OAuthFlow.none => Icons.open_in_new,
    };

/// Meldung unter dem Formular. Ein Fehler steht in der Fehlerfarbe; ein Hinweis (der Vorgang beim Anbieter wurde
/// nicht abgeschlossen, kein Fehler) in der zweiten Textfarbe mit Info-Symbol, damit der Status nicht nur an der
/// Farbe hängt. Das Symbol ist rein dekorativ, der Screenreader liest nur den Text.
class OnboardingMessage extends StatelessWidget {
  const OnboardingMessage({super.key, required this.text, this.notice = false});

  final String text;
  final bool notice;

  @override
  Widget build(BuildContext context) {
    final color = notice ? AuroraTokens.of(context).textSecondary : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          if (notice) ...<Widget>[
            ExcludeSemantics(child: Icon(Icons.info_outline, size: 18, color: color)),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ]),
      ),
    );
  }
}
