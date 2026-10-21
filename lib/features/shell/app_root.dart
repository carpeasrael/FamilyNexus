import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/invite_link.dart';
import '../../domain/security.dart';
import '../../l10n/gen/app_localizations.dart';
import '../security/verification_dialog.dart';
import '../onboarding/onboarding_screen.dart';
import 'home_shell.dart';

/// Entscheidet zwischen Einrichtung und Hauptoberfläche.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  StreamSubscription<String>? _linkSub;
  bool _wasReady = false;

  @override
  void initState() {
    super.initState();
    final services = AppScope.read(context);
    _linkSub = services.links.links.listen((s) => _handleLink(services, s));
    services.links.initialLink().then((s) {
      if (s != null) _handleLink(services, s);
    }).ignore();
  }

  @override
  void dispose() {
    _linkSub?.cancel().ignore();
    super.dispose();
  }

  /// Einladungslink (Deep Link/QR): streng prüfen, nie automatisch handeln – nur vormerken.
  void _handleLink(AppServices services, String raw) {
    final l = AppLocalizations.of(context);
    final link = InviteLink.tryParse(raw, now: DateTime.now());
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (link == null || !link.isValidAt(DateTime.now())) {
      messenger?.showSnackBar(SnackBar(content: Text(l.joinLinkInvalid)));
      return;
    }
    if (services.gateway.family != null) return; // bereits in einer Familie
    services.pendingInvite.value = link;
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[services.settings, services.gateway]),
      builder: (context, _) {
        final session = services.gateway.session == SessionState.ready;
        // Ohne verifiziertes Gerät keine Hauptansicht (Schlüsselsicherung ist Pflicht, SA-1).
        final secure = services.gateway.securityState == SecurityState.ready;
        final ready = services.settings.settings.onboardingDone && session && services.gateway.family != null && secure;
        if (session && services.settings.settings.onboardingDone && services.gateway.securityState == SecurityState.unknown) {
          return Scaffold(body: Center(child: Semantics(label: AppLocalizations.of(context).loading, child: const CircularProgressIndicator())));
        }
        if (!ready) {
          // Nicht bereit: Synchronisation stoppen. Geplante Erinnerungen werden nur bei Abmeldung
          // entfernt, nicht bei vorübergehenden Zuständen (z. B. Kaltstart offline).
          final lostReady = _wasReady;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            services.closeCalendar(cancelReminders: !session);
            // Beim Verlassen der Hauptansicht geöffnete Seiten (z. B. Einstellungen) schließen, sonst
            // blieben sie über der Einrichtung stehen. Dialoge der Einrichtung bleiben unberührt.
            if (lostReady && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          });
        }
        _wasReady = ready;
        return VerificationListener(child: ready ? const HomeShell() : const OnboardingScreen());
      },
    );
  }
}
