import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/app_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../data/platform/reminder_scheduler.dart';
import '../../domain/security.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import '../calendar/event_editor_screen.dart' show kReminderChoices;
import '../reminders/reminder_coordinator.dart';
import '../moderation/blocked_users_screen.dart';
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
            _RemindersSection(),
            const SizedBox(height: 16),
            _Section(title: l.settingsSectionPrivacy, children: <Widget>[
              _LockTiles(),
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
              // Linux und Windows bieten keinen Schutz vor Bildschirmaufnahmen (SA-6): Schalter ausgeblendet.
              if (!Platform.isLinux && !Platform.isWindows)
                SwitchListTile(
                  title: Text(l.settingsSecureScreen),
                  subtitle: Text(l.settingsSecureScreenHint),
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
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                title: Text(l.settingsDeleteData),
                subtitle: Text(l.settingsDeleteDataHint),
                onTap: () => _confirmDelete(context),
              ),
              ListTile(title: Text(l.settingsNoTelemetry)),
              ListTile(title: Text(l.settingsLicense)),
            ]),
          ],
        );
      },
    );
  }
}

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
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: Semantics(
          label: label,
          container: true,
          child: DropdownButton<T>(
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
        ),
      );
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
          leading: const Icon(Icons.logout),
          title: Text(l.logout),
          onTap: () async {
            final services = AppScope.read(context);
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(l.logout),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.logout)),
                ],
              ),
            );
            if (ok == true) await services.logout();
          },
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
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(perm == ReminderPermission.notificationsDenied ? l.remindersPermissionNotifications : l.remindersPermissionExact),
              trailing: TextButton(onPressed: () => coordinator?.requestPermission().ignore(), child: Text(l.remindersAllow)),
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
                      child: a == selected ? Icon(Icons.check, size: 14, color: dark ? const Color(0xFF0B1120) : Colors.white) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(_name(l, a)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
