import 'package:family_nexus/features/settings/settings_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #144: Der Hinweis zum Bildschirmschutz verspricht je Plattform nur, was sie kann. iOS kann Screenshots nicht
/// verhindern (SA-5, E-43); für Windows ist nur der Ausschluss von Aufnahmen belegt (`SetWindowDisplayAffinity`).
/// Kein Widget-Test: Auf dem Linux-Host fehlt der Schalter (`PlatformInfo.hasNoScreenProtection`).
void main() {
  test('Plattformauswahl', () {
    expect(secureScreenPlatform(ios: true, windows: false), SecureScreenPlatform.ios);
    expect(secureScreenPlatform(ios: false, windows: true), SecureScreenPlatform.windows);
    expect(secureScreenPlatform(ios: false, windows: false), SecureScreenPlatform.android);
  });

  for (final lang in ['de', 'en']) {
    final de = lang == 'de';
    test('$lang: iOS verspricht keinen Screenshot-Schutz', () {
      final l = lookupAppLocalizations(Locale(lang));
      final ios = secureScreenHint(l, SecureScreenPlatform.ios);
      expect(ios, isNot(contains(de ? 'Blockiert Screenshots' : 'Blocks screenshots')));
      expect(ios, contains(de ? 'nicht verhindern' : 'cannot be prevented'));
      expect(ios, contains(de ? 'App-Umschalter' : 'app switcher'));
    });

    test('$lang: Windows nennt nur den Ausschluss von Aufnahmen, nicht die Übersicht', () {
      final l = lookupAppLocalizations(Locale(lang));
      final win = secureScreenHint(l, SecureScreenPlatform.windows);
      expect(win, contains(de ? 'Screenshots' : 'screenshots'));
      expect(win, contains(de ? 'Bildschirmfreigaben' : 'screen sharing'));
      expect(win, isNot(contains(de ? 'Übersicht' : 'app switcher')));
    });

    test('$lang: Android behält den bisherigen Text', () {
      final l = lookupAppLocalizations(Locale(lang));
      expect(secureScreenHint(l, SecureScreenPlatform.android), l.settingsSecureScreenHint);
      expect(l.settingsSecureScreenHint, contains(de ? 'Blockiert Screenshots' : 'Blocks screenshots'));
    });
  }
}
