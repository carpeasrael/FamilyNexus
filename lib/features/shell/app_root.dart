import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../core/app_log.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../data/platform/oauth_redirect.dart';
import '../../domain/invite_link.dart';
import '../../domain/server.dart';
import '../../domain/security.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/invite_link_text.dart';
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
    _restorePendingInvite(services);
    _linkSub = services.links.links.listen((s) => _handleLink(services, s));
    services.links.initialLink().then((s) {
      if (s != null) _handleLink(services, s);
    }).ignore();
  }

  /// Vor der Anmeldung geöffneter Einladungslink (E-56): nach einem Neustart weiter verwenden,
  /// sofern er noch gültig ist; sonst verwerfen.
  void _restorePendingInvite(AppServices services) {
    final raw = services.settings.settings.pendingInvite;
    if (raw == null || services.pendingInvite.value != null) return;
    final check = InviteLink.check(raw, now: DateTime.now(), ownHost: MatrixIds.serverName(services.gateway.userId ?? ''));
    if (check.ok && services.gateway.family == null) {
      services.pendingInvite.value = check.link;
    } else {
      // Nicht während des Aufbaus benachrichtigen.
      Future<void>.microtask(() => services.settings.update((c) => c.copyWith(pendingInvite: null))).ignore();
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel().ignore();
    super.dispose();
  }

  /// Einladungslink (Deep Link/QR): streng prüfen, nie automatisch handeln – nur vormerken.
  void _handleLink(AppServices services, String raw) {
    // Rücksprung der Browser-Anmeldung: gehört dem wartenden OAuthRedirect, keine Einladung.
    if (AppLinkOAuthRedirect.isCallback(raw)) return;
    final l = AppLocalizations.of(context);
    final ownHost = MatrixIds.serverName(services.gateway.userId ?? '');
    final check = InviteLink.check(raw, now: DateTime.now(), ownHost: ownHost);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final problem = check.problem;
    if (problem != null) {
      messenger?.showSnackBar(SnackBar(content: Text(inviteLinkProblemText(l, problem))));
      return;
    }
    final link = check.link!;
    if (services.gateway.family != null) {
      messenger?.showSnackBar(SnackBar(content: Text(l.joinAlreadyInFamily)));
      return;
    }
    // Vormerken (auch über einen Neustart hinweg); gehandelt wird erst nach Bestätigung.
    services.settings.update((c) => c.copyWith(pendingInvite: check.raw)).ignore();
    services.pendingInvite.value = link;
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[services.settings, services.gateway]),
      builder: (context, _) {
        final session = services.gateway.session == SessionState.ready;
        if (session && services.keepAccountData) {
          WidgetsBinding.instance.addPostFrameCallback((_) => services.sessionConfirmed().ignore());
        }
        // Ohne verifiziertes Gerät keine Hauptansicht (Schlüsselsicherung ist Pflicht, SA-1).
        final secure = services.gateway.securityState == SecurityState.ready;
        // Familie direkt gewechselt (#140), ohne Zwischenstand „keine Familie“: Die offenen Dienste gehören noch zur alten.
        // Der Abbau darunter setzt `openFamilyRoom` zurück, danach öffnet die neue Hauptansicht die Dienste für die neue Familie.
        final family = services.gateway.family;
        final open = services.openFamilyRoom;
        final familyChanged = open != null && family != null && open != family.roomId;
        final ready = services.settings.settings.onboardingDone && session && family != null && secure && !familyChanged;
        if (session && services.settings.settings.onboardingDone && services.gateway.securityState == SecurityState.unknown) {
          return Scaffold(body: Center(child: Semantics(label: AppLocalizations.of(context).loading, child: const CircularProgressIndicator())));
        }
        if (!ready) {
          // Nicht bereit: Synchronisation stoppen. Geplante Erinnerungen werden nur bei Abmeldung
          // entfernt, nicht bei vorübergehenden Zuständen (z. B. Kaltstart offline).
          final lostReady = _wasReady;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            services.closeCalendar(cancelReminders: !session && !services.keepAccountData);
            // Sitzung beendet (Abmelden, Konto wechseln, auf einem anderen Gerät entfernt): Familiendaten vom Gerät.
            if (!session && !services.accountDeletionPending) {
              services.wipeAccountData().catchError((Object e) => AppLog.e('app', 'Lokale Familiendaten nicht gelöscht', e)).ignore();
            }
            // Konto gelöscht: auch die lokalen Daten des Kontos entfernen (wie „Alle lokalen Daten löschen“).
            if (!session && services.accountDeletionPending) {
              services.accountDeletionPending = false;
              services.onFullReset?.call().ignore();
            }
            // Beim Verlassen der Hauptansicht geöffnete Seiten (z. B. Einstellungen) schließen, sonst
            // blieben sie über der Einrichtung stehen. Dialoge der Einrichtung bleiben unberührt.
            if (lostReady && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            if (familyChanged && mounted) setState(() {});
          });
        }
        _wasReady = ready;
        return VerificationListener(child: ready ? const HomeShell() : const OnboardingScreen());
      },
    );
  }
}
