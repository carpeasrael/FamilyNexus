part of '../settings_screen.dart';

/// Die Aktionen der Einstellungen mit den Diensten der App (AP-6a); `reminders` wird erst beim Aufruf gelesen, weil der
/// Koordinator nach dem Öffnen der Familiendienste entsteht.
SettingsActions _actions(BuildContext context) {
  final s = AppScope.read(context);
  final scheduler = s.scheduler;
  return SettingsActions(
    settings: s.settings,
    gateway: s.gateway,
    inventory: s.dataInventory,
    requestNotifications: scheduler == null ? null : () => scheduler.requestNotifications(),
    reschedule: () async => s.reminders?.reschedule(),
  );
}

/// Darstellung: Sprache, Design, Akzentfarbe, reduzierte Effekte.
class _DisplaySection extends StatelessWidget {
  const _DisplaySection({required this.settings, required this.controller});
  final AppSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = settings;
    return _Section(title: l.settingsSectionDisplay, children: <Widget>[
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
    ]);
  }
}

/// Datenschutz: App-Sperre, Online-Status, gesperrte Personen, Bildschirmschutz.
class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.settings, required this.controller});
  final AppSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = settings;
    return _Section(title: l.settingsSectionPrivacy, children: <Widget>[
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
          subtitle: Text(secureScreenHint(l, secureScreenPlatform(ios: PlatformInfo.isIOS, windows: PlatformInfo.isWindows))),
          value: s.secureScreen,
          onChanged: (v) => controller.update((c) => c.copyWith(secureScreen: v)),
        ),
    ]);
  }
}

/// Über die App: Datenschutzerklärung, Speicher, Berichte, Daten löschen, Einführung, Empfehlen, Version.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(title: l.settingsSectionAbout, children: <Widget>[
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
    ]);
  }
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
