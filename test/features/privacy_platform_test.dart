import 'package:family_nexus/features/settings/privacy_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #160: Die Datenschutzerklärung beschreibt je Plattform den richtigen Schlüsselspeicher, die richtigen
/// Berechtigungen und die richtige Backup-Aussage. Geprüft wird je Abschnitt (2, 6, 7), nicht die ganze Seite.
void main() {
  String section(AppLocalizations l, PrivacyPlatform p, String title) =>
      privacySections(l, platform: p).singleWhere((s) => s.$1 == title).$2;

  for (final lang in ['de', 'en']) {
    final l = lookupAppLocalizations(Locale(lang));
    final de = lang == 'de';
    final apple = RegExp('Apple|Keychain|Schlüsselbund des Geräts|iCloud', caseSensitive: false);
    final android = RegExp('Android', caseSensitive: false);
    const noApple = <PrivacyPlatform>[
      PrivacyPlatform.android,
      PrivacyPlatform.windows,
      PrivacyPlatform.linux,
      PrivacyPlatform.linuxFlatpak,
      PrivacyPlatform.web,
    ];

    test('$lang: Abschnitt 2 nennt den Schlüsselspeicher der Plattform', () {
      String s2(PrivacyPlatform p) => section(l, p, l.privacy2Title);
      expect(s2(PrivacyPlatform.android), contains('Android Keystore'));
      expect(s2(PrivacyPlatform.ios), contains(de ? 'Schlüsselbund des Geräts' : 'Device keychain'));
      expect(s2(PrivacyPlatform.macos), contains(de ? 'Schlüsselbund des Geräts' : 'Device keychain'));
      expect(s2(PrivacyPlatform.windows), contains(de ? 'Anmeldeinformationsverwaltung' : 'Credential Manager'));
      expect(s2(PrivacyPlatform.linux), contains('Secret Service'));
      expect(s2(PrivacyPlatform.linuxFlatpak), contains('Flatpak'));
      expect(s2(PrivacyPlatform.web), contains('localStorage'));
      for (final p in noApple) {
        expect(apple.hasMatch(s2(p)), isFalse, reason: '$p: ${s2(p)}');
      }
      for (final p in PrivacyPlatform.values.where((p) => p != PrivacyPlatform.android)) {
        expect(android.hasMatch(s2(p)), isFalse, reason: '$p');
      }
      expect(s2(PrivacyPlatform.linuxFlatpak), isNot(contains('Secret Service')));
      expect(s2(PrivacyPlatform.android), isNot(contains(de ? 'nie in einer Datei' : 'never in a file')));
    });

    test('$lang: Abschnitt 6 – Berechtigungen je Plattform', () {
      String s6(PrivacyPlatform p) => section(l, p, l.privacy6Title);
      final alarms = RegExp('genaue Alarme|exact alarms', caseSensitive: false);
      final lock = RegExp('Geräteanmeldung|device credentials', caseSensitive: false);
      final remind = RegExp('Erinnerung|reminder', caseSensitive: false);
      for (final p in PrivacyPlatform.values) {
        expect(alarms.hasMatch(s6(p)), p == PrivacyPlatform.android, reason: '$p: ${s6(p)}');
        final hasLock = const {
          PrivacyPlatform.android,
          PrivacyPlatform.ios,
          PrivacyPlatform.macos,
          PrivacyPlatform.windows,
        }.contains(p);
        // Im Web wird die Geräteanmeldung nur verneint (eigene Fassung), nicht als nötig genannt.
        if (p != PrivacyPlatform.web) expect(lock.hasMatch(s6(p)), hasLock, reason: '$p: ${s6(p)}');
      }
      for (final p in noApple.where((p) => p != PrivacyPlatform.android)) {
        expect(apple.hasMatch(s6(p)), isFalse, reason: '$p');
        expect(android.hasMatch(s6(p)), isFalse, reason: '$p');
      }
      expect(s6(PrivacyPlatform.web), contains(de ? 'keine Berechtigung' : 'no permission'));
      expect(remind.hasMatch(s6(PrivacyPlatform.windows)), isTrue);
      for (final p in [PrivacyPlatform.windows, PrivacyPlatform.linux, PrivacyPlatform.linuxFlatpak]) {
        expect(s6(p), contains(de ? 'solange die App läuft' : 'while the app is running'), reason: '$p');
      }
      for (final p in [PrivacyPlatform.ios, PrivacyPlatform.macos]) {
        expect(s6(p), contains(de ? 'Benachrichtigungen' : 'notifications'), reason: '$p');
      }
    });

    test('$lang: Abschnitt 7 – Backup-Aussage je Plattform', () {
      String s7(PrivacyPlatform p) => section(l, p, l.privacy7Title);
      expect(s7(PrivacyPlatform.android), startsWith(de ? 'Android-Backups sind ausgeschaltet.' : 'Android backups are disabled.'));
      for (final p in [PrivacyPlatform.ios, PrivacyPlatform.macos]) {
        expect(s7(p), contains(de ? 'ausgenommen' : 'excluded'), reason: '$p');
        expect(android.hasMatch(s7(p)), isFalse, reason: '$p');
      }
      expect(s7(PrivacyPlatform.macos), contains('Time Machine'));
      for (final p in [PrivacyPlatform.windows, PrivacyPlatform.linux, PrivacyPlatform.linuxFlatpak, PrivacyPlatform.web]) {
        expect(android.hasMatch(s7(p)), isFalse, reason: '$p: ${s7(p)}');
        expect(s7(p), contains(de ? 'legt selbst keine Sicherung' : 'does not create a backup'), reason: '$p');
      }
      // Der gemeinsame Rest (Löschen, Notfall-Schlüssel, Zwischenablage) steht überall.
      for (final p in PrivacyPlatform.values) {
        expect(s7(p), contains(l.privacy7Rest));
      }
    });

    test('$lang: jede Plattform liefert alle Abschnitte ohne leere Texte', () {
      for (final p in PrivacyPlatform.values) {
        final secs = privacySections(l, platform: p);
        expect(secs.every((s) => s.$1.isNotEmpty && s.$2.trim().isNotEmpty), isTrue, reason: '$p');
      }
    });
  }
}
