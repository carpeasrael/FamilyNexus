
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../app/app_version.dart';
import '../../core/platform_info.dart';
import '../../data/platform/reminder_scheduler.dart';
import '../../data/platform/store_launcher.dart';
import '../../domain/app_settings.dart';
import '../../domain/data_inventory.dart';
import '../../domain/security.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../calendar/event_editor_screen.dart' show kReminderChoices;
import '../common/error_text.dart';
import '../moderation/blocked_users_screen.dart';
import '../onboarding/intro_tour.dart';
import '../reminders/permission_hint.dart';
import '../reminders/reminder_coordinator.dart';
import '../security/security_panel.dart' show RecoveryKeyRenewScreen;
import 'account_deletion_dialog.dart';
import 'data_report.dart';
import 'data_report_screen.dart';
import 'password_change_dialog.dart';
import 'privacy_screen.dart';
import 'settings_controller.dart';

part 'widgets/settings_parts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.settings;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _DisplaySection(settings: s, controller: controller),
            const SizedBox(height: 16),
            _AccountSection(),
            const SizedBox(height: 16),
            _SecuritySection(),
            const SizedBox(height: 16),
            // Im Browser gibt es keine Erinnerungen (E-53, #145): kein Abschnitt.
            if (AppScope.of(context).reminders != null) ...<Widget>[
              _RemindersSection(),
              const SizedBox(height: 16),
            ],
            // Meldungen zu Chat und Einkauf gibt es nur mit Plattform-Meldungen (nicht im Browser, #254).
            if (AppScope.of(context).activityPlatform != null) ...<Widget>[
              _ActivitySection(),
              const SizedBox(height: 16),
            ],
            _PrivacySection(settings: s, controller: controller),
            const SizedBox(height: 16),
            const _AboutSection(),
          ],
        );
      },
    );
  }
}

/// Plattformen mit Schalter „Bildschirmschutz“ (alle außer `PlatformInfo.hasNoScreenProtection`).
enum SecureScreenPlatform { android, ios, windows }

/// Plattformauswahl für [secureScreenHint]; Parameter statt Abfrage, weil `Platform.isIOS` im Test false ist.
SecureScreenPlatform secureScreenPlatform({required bool ios, required bool windows}) =>
    ios ? SecureScreenPlatform.ios : (windows ? SecureScreenPlatform.windows : SecureScreenPlatform.android);

/// Hinweis zum Bildschirmschutz je Plattform (#144): Android sperrt Screenshots und verbirgt die App in der Übersicht
/// (`FLAG_SECURE`). iOS verdeckt nur App-Umschalter und Bildschirmaufnahme (SA-5, E-43). Windows nimmt das Fenster
/// von Aufnahmen aus (`SetWindowDisplayAffinity`); ob es in Alt-Tab verborgen ist, ist nicht belegt.
String secureScreenHint(AppLocalizations l, SecureScreenPlatform p) => switch (p) {
      SecureScreenPlatform.android => l.settingsSecureScreenHint,
      SecureScreenPlatform.ios => l.settingsSecureScreenHintIos,
      SecureScreenPlatform.windows => l.settingsSecureScreenHintWindows,
    };

/// Untertitel von „Alle lokalen Daten löschen“: Im Browser gibt es keine Erinnerungen (E-53, #237).
/// [web] ist ein Parameter, weil `kIsWeb` im Test konstant false ist.
String deleteDataHint(AppLocalizations l, {required bool web}) =>
    web ? l.settingsDeleteDataHintWeb : l.settingsDeleteDataHint;

Future<void> _confirmDelete(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final services = AppScope.read(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.deleteDataTitle),
      content: Text(l.deleteDataBody),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.deleteDataConfirm)),
      ],
    ),
  );
  if (ok == true) await services.onFullReset?.call();
}
