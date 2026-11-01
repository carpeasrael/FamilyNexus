import 'package:flutter/material.dart';

import '../../core/platform_info.dart';
import '../../domain/data_inventory.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import 'data_report.dart';

/// Plattform für den Datenschutztext (#160): Schlüsselspeicher, Berechtigungen und Backups unterscheiden sich.
enum PrivacyPlatform {
  android(KeyStoreKind.androidKeystore),
  ios(KeyStoreKind.appleKeychain),
  macos(KeyStoreKind.appleKeychain),
  windows(KeyStoreKind.windowsCredentialManager),
  linux(KeyStoreKind.linuxSecretService),
  linuxFlatpak(KeyStoreKind.linuxFlatpakPortal),
  web(KeyStoreKind.browserVault);

  const PrivacyPlatform(this.keyStore);

  final KeyStoreKind keyStore;

  bool get isWeb => this == web;
  bool get isDesktopLinuxOrWindows =>
      this == windows || this == linux || this == linuxFlatpak;

  /// Die Plattform, auf der die App läuft; Erkennung wie bei „Speicherorte“ (E-50, [PlatformInfo]).
  static PrivacyPlatform get current {
    if (PlatformInfo.isWeb) return web;
    if (PlatformInfo.isAndroid) return android;
    if (PlatformInfo.isIOS) return ios;
    if (PlatformInfo.isMacOS) return macos;
    if (PlatformInfo.isWindows) return windows;
    return PlatformInfo.detectFlatpak() ? linuxFlatpak : linux;
  }
}

/// Abschnitt 6 „Berechtigungen“ aus Bausteinen je Plattform (#160).
String privacyPermissions(AppLocalizations l, PrivacyPlatform p) {
  if (p.isWeb) return l.privacy6BodyWeb;
  final items = <String>[
    l.privacy6Net,
    if (p == PrivacyPlatform.android) l.privacy6NotifAndroid,
    if (p == PrivacyPlatform.ios || p == PrivacyPlatform.macos)
      l.privacy6NotifApple,
    if (!p.isDesktopLinuxOrWindows || p == PrivacyPlatform.windows)
      l.privacy6Lock,
  ];
  return '${items.join(', ')}. ${p.isDesktopLinuxOrWindows ? '${l.privacy6DesktopNote} ' : ''}${l.privacy6Tail}';
}

/// Abschnitt 7 „Sicherung und Löschung“: Backup-Satz je Plattform, Rest gemeinsam (#160).
String privacyBackup(AppLocalizations l, PrivacyPlatform p) {
  final first = switch (p) {
    PrivacyPlatform.android => l.privacy7BackupAndroid,
    PrivacyPlatform.ios => l.privacy7BackupIos,
    PrivacyPlatform.macos => l.privacy7BackupMacos,
    _ => l.privacy7BackupOther,
  };
  return '$first ${l.privacy7Rest}';
}

/// Die Abschnitte der Datenschutzerklärung. Im Browser gibt es keine Erinnerungen und keine
/// Berechtigungen dafür (E-53, #145): Abschnitt 5 entfällt, Abschnitt 13 kommt hinzu. Schlüsselspeicher,
/// Berechtigungen und Backup-Aussage folgen [platform] (#160). [platform] ist ein Parameter, weil `kIsWeb`
/// im Test konstant false ist.
List<(String, String)> privacySections(
  AppLocalizations l, {
  required PrivacyPlatform platform,
}) => <(String, String)>[
  (l.privacy1Title, l.privacy1Body),
  (
    l.privacy2Title,
    l.privacy2Body(DataReport.keyStoreText(l, platform.keyStore)),
  ),
  (l.privacy3Title, l.privacy3Body),
  (l.privacy4Title, l.privacy4Body),
  if (!platform.isWeb) (l.privacy5Title, l.privacy5Body),
  (l.privacy6Title, privacyPermissions(l, platform)),
  (l.privacy7Title, privacyBackup(l, platform)),
  (l.privacy8Title, l.privacy8Body),
  (l.privacy9Title, l.privacy9Body),
  (l.privacy10Title, l.privacy10Body),
  (l.privacy11Title, l.privacy11Body),
  (l.privacy12Title, l.privacy12Body),
  if (platform.isWeb) (l.privacy13Title, l.privacy13Body),
];

/// Datenschutzerklärung (de/en aus den ARB-Dateien).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = privacySections(l, platform: PrivacyPlatform.current);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            for (final s in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          s.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(s.$2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
