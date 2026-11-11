
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.settings;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _Section(title: l.settingsSectionDisplay, children: <Widget>[
              _DropdownTile<String?>(
                label: l.settingsLanguage,
                value: s.languageCode,
                items: <String?, String>{
                  null: l.languageSystem,
                  'de': l.languageGerman,
                  'en': l.languageEnglish,
                },
                onChanged: (v) => controller.update((c) => c.copyWith(languageCode: v)),
              ),
              _DropdownTile<AppThemeMode>(
                label: l.settingsTheme,
                value: s.themeMode,
                items: <AppThemeMode, String>{
                  AppThemeMode.system: l.themeSystem,
                  AppThemeMode.dark: l.themeDark,
                  AppThemeMode.light: l.themeLight,
                },
                onChanged: (v) => controller.update((c) => c.copyWith(themeMode: v)),
              ),
              _AccentPicker(selected: s.accent, onChanged: (a) => controller.update((c) => c.copyWith(accent: a))),
              SwitchListTile(
                title: Text(l.settingsReduceEffects),
                subtitle: Text(l.settingsReduceEffectsHint),
                value: s.reduceEffects,
                onChanged: (v) => controller.update((c) => c.copyWith(reduceEffects: v)),
              ),
            ]),
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
            _Section(title: l.settingsSectionPrivacy, children: <Widget>[
              // Ohne Geräteanmeldung (Linux, Browser) lässt sich die App-Sperre nicht einschalten: Schalter ausgeblendet (#67).
              if (AppScope.of(context).lock.auth.supported) _LockTiles(),
              SwitchListTile(
                title: Text(l.settingsShareOnlineStatus),
                subtitle: Text(l.settingsShareOnlineStatusHint),
                value: s.shareOnlineStatus,
                onChanged: (v) => controller.update((c) => c.copyWith(shareOnlineStatus: v)),
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l.settingsBlockedUsers),
                subtitle: Text(l.settingsBlockedUsersHint),
                trailing: s.blockedUsers.isEmpty ? null : Text('${s.blockedUsers.length}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BlockedUsersScreen())),
              ),
              // Linux und Browser bieten keinen Schutz vor Bildschirmaufnahmen (SA-6, SA-7), macOS erlaubt sie bewusst: Schalter ausgeblendet.
              if (!PlatformInfo.hasNoScreenProtection)
                SwitchListTile(
                  title: Text(l.settingsSecureScreen),
                  subtitle: Text(secureScreenHint(
                      l, secureScreenPlatform(ios: PlatformInfo.isIOS, windows: PlatformInfo.isWindows))),
                  value: s.secureScreen,
                  onChanged: (v) => controller.update((c) => c.copyWith(secureScreen: v)),
                ),
            ]),
            const SizedBox(height: 16),
            _Section(title: l.settingsSectionAbout, children: <Widget>[
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l.settingsPrivacyPolicy),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen())),
              ),
              _StorageTiles(),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(l.settingsReportLocal),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DataReportScreen(kind: DataReportKind.local)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(l.settingsReportOnline),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DataReportScreen(kind: DataReportKind.online)),
                ),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                title: Text(l.settingsDeleteData),
                subtitle: Text(deleteDataHint(l, web: PlatformInfo.isWeb)),
                onTap: () => _confirmDelete(context),
              ),
              // Version und Build wie in App Store Connect (für Testberichte und Bildschirmaufnahmen, #14).
              ListTile(
                leading: const Icon(Icons.tour_outlined),
                title: Text(l.settingsTourRestart),
                onTap: () => showIntroTour(context),
              ),
              const _RecommendTiles(),
              ListTile(leading: const Icon(Icons.info_outline), title: Text(l.menuVersion(appVersionWithBuild))),
              ListTile(title: Text(l.settingsNoTelemetry)),
              ListTile(title: Text(l.settingsLicense)),
            ]),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Semantics(
                header: true,
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            ...children,
          ],
        ),
      );
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Bei großer Schrift ist neben dem Titel kein Platz: Die Auswahl rutscht unter den Titel (#274).
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final dropdown = Semantics(
      label: label,
      container: true,
      child: DropdownButton<T>(
        isExpanded: large,
        value: value,
        underline: const SizedBox.shrink(),
        items: <DropdownMenuItem<T>>[
          for (final e in items.entries)
            DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v is T) onChanged(v);
        },
      ),
    );
    return ListTile(title: Text(label), subtitle: large ? dropdown : null, trailing: large ? null : dropdown);
  }
}

/// Speicherorte der lokalen Daten (Pfade zum Markieren und Kopieren) und der Online-Anbieter.
class _StorageTiles extends StatefulWidget {
  @override
  State<_StorageTiles> createState() => _StorageTilesState();
}

class _StorageTilesState extends State<_StorageTiles> {
  Future<StorageLocations>? _locations;

  @override
  void initState() {
    super.initState();
    _locations = AppScope.read(context).dataInventory?.locations();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final server = AppScope.of(context).gateway.server?.toString();
    return FutureBuilder<StorageLocations>(
      future: _locations,
      builder: (context, snap) {
        final loc = snap.data;
        Widget tile(String title, String value) => ListTile(
              dense: true,
              title: Text(title),
              subtitle: SelectableText(value),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.settingsStorageTitle, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (loc != null) ...<Widget>[
            tile(l.settingsStorageDbDir, loc.inBrowser ? l.settingsStorageBrowser : loc.databaseDirectory),
            tile(l.settingsStorageAppDb, loc.appDatabase),
            tile(l.settingsStorageMatrixDb, loc.matrixDatabase),
            tile(l.settingsStorageKeys, DataReport.keyStoreText(l, loc.keyStore)),
          ],
          if (server != null) tile(l.settingsStorageOnline, server),
        ]);
      },
    );
  }
}

class _AccountSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gateway = AppScope.of(context).gateway;
    return ListenableBuilder(
      listenable: gateway,
      builder: (context, _) => _Section(title: l.settingsAccount, children: <Widget>[
        ListTile(title: Text(l.settingsServer), subtitle: Text(gateway.server?.host ?? '–')),
        ListTile(title: Text(l.accountUsername), subtitle: Text(gateway.userId ?? '–')),
        ListTile(
          leading: const Icon(Icons.password),
          title: Text(l.passwordChangeTitle),
          onTap: () => changePassword(context),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l.logout),
          onTap: () async {
            final services = AppScope.read(context);
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(l.logout),
                content: Text(l.logoutBody),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.logout)),
                ],
              ),
            );
            if (ok == true) await services.logout();
          },
        ),
        // Apple 5.1.1(v): Wer in der App ein Konto anlegen kann, muss es hier auch löschen können (#12).
        ListTile(
          leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
          title: Text(l.accountDelete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          subtitle: Text(l.accountDeleteHint),
          onTap: () => deleteAccount(context),
        ),
      ]),
    );
  }
}

class _RemindersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final settings = services.settings;
    final coordinator = services.reminders;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[settings, ?coordinator]),
      builder: (context, _) {
        final selected = settings.settings.defaultReminderMinutes.toSet();
        final perm = coordinator?.permission ?? ReminderPermission.granted;
        return _Section(title: l.settingsReminders, children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.remindersHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.remindersDefault, style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
              for (final m in kReminderChoices)
                FilterChip(
                  label: Text(m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m))),
                  selected: selected.contains(m),
                  onSelected: (v) {
                    final next = <int>{...selected};
                    v ? next.add(m) : next.remove(m);
                    settings.update((s) => s.copyWith(defaultReminderMinutes: next.toList()..sort((a, b) => b.compareTo(a))));
                  },
                ),
            ]),
          ),
          if (perm != ReminderPermission.granted)
            Builder(builder: (context) {
              final hint = reminderPermissionHint(l, coordinator, perm);
              // Kein ListTile: Eine lange Schaltfläche als trailing drückte den Text in eine schmale, abgeschnittene Spalte (#97).
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    const Padding(padding: EdgeInsets.only(top: 2, right: 16), child: Icon(Icons.notifications_off_outlined)),
                    Expanded(child: Text(hint.text)),
                  ]),
                  Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: hint.onPressed, child: Text(hint.action))),
                ]),
              );
            }),
        ]);
      },
    );
  }
}

/// Schalter für die Meldungen zu Chat und Einkauf (#254, E-88). Beim Einschalten wird nur die
/// Benachrichtigungsberechtigung angefragt (ohne genaue Alarme).
class _ActivitySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final controller = services.settings;
    Future<void> enable(AppSettings Function(AppSettings) change, bool on) async {
      await controller.update(change);
      if (!on) return;
      await services.scheduler?.requestNotifications();
      await services.reminders?.reschedule();
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.settings;
        return _Section(title: l.settingsActivity, children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.settingsActivityHint, style: Theme.of(context).textTheme.bodySmall),
          ),
          SwitchListTile(
            title: Text(l.settingsNotifyChat),
            value: s.notifyChat,
            onChanged: (v) => enable((c) => c.copyWith(notifyChat: v), v),
          ),
          SwitchListTile(
            title: Text(l.settingsNotifyShopping),
            value: s.notifyShopping,
            onChanged: (v) => enable((c) => c.copyWith(notifyShopping: v), v),
          ),
          if (PlatformInfo.isIOS || PlatformInfo.isMacOS)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l.settingsActivityBadgeApple, style: Theme.of(context).textTheme.bodySmall),
            ),
        ]);
      },
    );
  }
}

class _SecuritySection extends StatefulWidget {
  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  @override
  void initState() {
    super.initState();
    // Geräteliste beim Öffnen auffrischen.
    AppScope.read(context).gateway.refreshSecurity().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final g = AppScope.of(context).gateway;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final ready = g.securityState == SecurityState.ready;
        return _Section(title: l.securityTitle, children: <Widget>[
          ListTile(
            leading: Icon(ready ? Icons.verified_outlined : Icons.warning_amber_outlined),
            title: Text(ready ? l.securityStatusReady : l.securityStatusNeeds),
          ),
          // Nur ein verifiziertes Gerät kann einen neuen Notfall-Schlüssel erstellen (#11).
          if (ready)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(l.keyRenew),
              subtitle: Text(l.securityKeyRenewHint),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RecoveryKeyRenewScreen())),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(l.securityDevices, style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final d in g.devices)
            ListTile(
              dense: true,
              title: Text(d.isCurrent ? '${d.name} (${l.securityDeviceThis})' : d.name),
              subtitle: Text(d.verified ? l.securityDeviceVerified : l.securityDeviceUnverified),
              leading: Icon(d.verified ? Icons.check_circle_outline : Icons.help_outline),
              trailing: (!d.isCurrent && !d.verified)
                  ? TextButton(
                      onPressed: () async {
                        final m = ScaffoldMessenger.of(context);
                        try {
                          await g.startVerification(userId: d.userId, deviceId: d.deviceId);
                        } catch (e) {
                          m.showSnackBar(SnackBar(content: Text(errorText(l, e))));
                        }
                      },
                      child: Text(l.securityVerifyDevice),
                    )
                  : null,
            ),
        ]);
      },
    );
  }
}

class _LockTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final settings = services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.settings;
        return Column(children: <Widget>[
          SwitchListTile(
            title: Text(l.settingsLock),
            subtitle: Text(l.settingsLockHint),
            value: s.lockEnabled,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              final available = await services.lock.auth.isAvailable();
              if (v && !available) {
                messenger.showSnackBar(SnackBar(content: Text(l.settingsLockUnavailable)));
                return;
              }
              final ok = await services.lock.setEnabled(v, l.lockReason);
              if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.settingsLockFailed)));
            },
          ),
          if (s.lockEnabled)
            _DropdownTile<int>(
              label: l.settingsLockTimeout,
              value: const <int>[0, 60, 300, 900].contains(s.lockTimeoutSeconds) ? s.lockTimeoutSeconds : 60,
              items: <int, String>{0: l.lockImmediately, 60: l.lock1min, 300: l.lock5min, 900: l.lock15min},
              onChanged: (v) => settings.update((c) => c.copyWith(lockTimeoutSeconds: v)),
            ),
        ]);
      },
    );
  }
}

/// Auswahl der Neon-Akzentfarbe. Jede Farbe trägt ihren Namen als Text und ein Häkchen bei Auswahl
/// (Farbe ist nie der einzige Informationsträger).
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onChanged});
  final AccentChoice selected;
  final void Function(AccentChoice) onChanged;

  static String _name(AppLocalizations l, AccentChoice a) => switch (a) {
        AccentChoice.teal => l.accentTeal,
        AccentChoice.magenta => l.accentMagenta,
        AccentChoice.violet => l.accentViolet,
        AccentChoice.sky => l.accentSky,
        AccentChoice.lime => l.accentLime,
        AccentChoice.orange => l.accentOrange,
        AccentChoice.rose => l.accentRose,
        AccentChoice.green => l.accentGreen,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.settingsAccent, style: Theme.of(context).textTheme.bodyLarge),
        Text(l.settingsAccentHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final a in AccentChoice.values)
            Semantics(
              button: true,
              selected: a == selected,
              label: _name(l, a),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(a),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: a == selected ? t.textPrimary : t.textMuted, width: a == selected ? 2 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: dark ? AccentPalette.of(a).neon : AccentPalette.of(a).deep,
                      child: a == selected ? Icon(Icons.check, size: 14, color: dark ? AuroraTokens.dark.bgBody : Colors.white) : null,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(_name(l, a))),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}


/// „App teilen“ und „App bewerten“ (#351, #350). Geteilt wird nur ein kurzer Satz mit dem öffentlichen Store-Link,
/// nie Familien-, Raum- oder Einladungsdaten. Das System-Teilen-Menü braucht eine neue Bibliothek mit nativen Teilen auf
/// allen Plattformen und ist ein eigener Schritt; bis dahin landet der Text in der Zwischenablage.
class _RecommendTiles extends StatelessWidget {
  const _RecommendTiles();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = AppScope.of(context).store;
    return Column(children: <Widget>[
      ListTile(
        leading: const Icon(Icons.ios_share),
        title: Text(l.settingsShareApp),
        subtitle: Text(l.settingsShareAppHint),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final copied = l.settingsShareAppCopied;
          await Clipboard.setData(ClipboardData(text: AppStoreListing.shareText(l.settingsShareAppText)));
          messenger.showSnackBar(SnackBar(content: Text(copied)));
        },
      ),
      if (store.canRate)
        ListTile(
          leading: const Icon(Icons.star_outline),
          title: Text(l.settingsRateApp),
          subtitle: Text(l.settingsRateAppHint),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final failed = l.settingsRateAppFailed;
            if (!await store.openListing()) messenger.showSnackBar(SnackBar(content: Text(failed)));
          },
        ),
    ]);
  }
}
