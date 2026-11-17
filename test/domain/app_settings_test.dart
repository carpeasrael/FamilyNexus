import 'package:family_nexus/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Standardwerte: Dunkel, Bildschirmschutz an, https-Standardserver', () {
    const s = AppSettings();
    expect(s.themeMode, AppThemeMode.dark);
    expect(s.secureScreen, isTrue);
    expect(s.serverUrl, startsWith('https://'));
    expect(s.languageCode, isNull);
  });

  test('Roundtrip toMap/fromMap', () {
    const s = AppSettings(
      languageCode: 'en',
      themeMode: AppThemeMode.light,
      reduceEffects: true,
      secureScreen: false,
      serverUrl: 'https://example.org',
      onboardingDone: true,
      lockEnabled: true,
      lockTimeoutSeconds: 30,
      defaultReminderMinutes: <int>[10, 60],
    );
    expect(AppSettings.fromMap(s.toMap()), s);
  });

  test('ungültige Werte fallen auf Standard zurück', () {
    final s = AppSettings.fromMap(<String, String>{
      'language': 'xx',
      'theme': 'neon',
      'lockTimeout': '-5',
      'defaultReminders': 'a,-3,10,99999999',
    });
    expect(s.languageCode, isNull);
    expect(s.themeMode, AppThemeMode.dark);
    expect(s.lockTimeoutSeconds, 60);
    expect(s.defaultReminderMinutes, <int>[10]);
  });

  test('unsichere/ungültige Server-URL aus dem Speicher wird verworfen', () {
    for (final bad in <String>['http://evil.example', 'https://u:p@x.org', '']) {
      expect(AppSettings.fromMap(<String, String>{'serverUrl': bad}).serverUrl, AppSettings.defaultServerUrl, reason: bad);
    }
    expect(AppSettings.fromMap(<String, String>{'serverUrl': 'https://example.org'}).serverUrl, 'https://example.org');
  });

  test('copyWith validiert Server und klemmt Sperrzeit', () {
    final s = const AppSettings().copyWith(serverUrl: 'http://x.org', lockTimeoutSeconds: -9);
    expect(s.serverUrl, AppSettings.defaultServerUrl);
    expect(s.lockTimeoutSeconds, 0);
    expect(const AppSettings().copyWith(lockTimeoutSeconds: 99999).lockTimeoutSeconds, 3600);
  });

  test('copyWith kann Sprache auf Gerätesprache zurücksetzen', () {
    final s = const AppSettings(languageCode: 'de').copyWith(languageCode: null);
    expect(s.languageCode, isNull);
  });

  test('Online-Status teilen: Standard an, Rundreise, Unsinn fällt auf „an“ zurück', () {
    expect(const AppSettings().shareOnlineStatus, isTrue);
    final off = const AppSettings().copyWith(shareOnlineStatus: false);
    expect(AppSettings.fromMap(off.toMap()).shareOnlineStatus, isFalse);
    expect(AppSettings.fromMap(const <String, String>{'shareOnlineStatus': 'vielleicht'}).shareOnlineStatus, isTrue);
    expect(AppSettings.fromMap(const <String, String>{}).shareOnlineStatus, isTrue);
  });

  test('Akzentfarbe: Standard Türkis, Rundreise, Unsinn fällt zurück', () {
    expect(const AppSettings().accent, AccentChoice.teal);
    final lime = const AppSettings().copyWith(accent: AccentChoice.lime);
    expect(AppSettings.fromMap(lime.toMap()).accent, AccentChoice.lime);
    expect(AppSettings.fromMap(const <String, String>{'accent': 'knallpink'}).accent, AccentChoice.teal);
    expect(AppSettings.fromMap(const <String, String>{}).accent, AccentChoice.teal);
  });

  test('#254: Meldungen zu Chat und Einkauf standardmäßig an, Abschalten bleibt erhalten', () {
    const d = AppSettings();
    expect(d.notifyChat, isTrue);
    expect(d.notifyShopping, isTrue);
    final off = d.copyWith(notifyChat: false, notifyShopping: false);
    final back = AppSettings.fromMap(off.toMap());
    expect(back.notifyChat, isFalse);
    expect(back.notifyShopping, isFalse);
    expect(AppSettings.fromMap(const <String, String>{}).notifyChat, isTrue);
    expect(AppSettings.fromMap(const <String, String>{'notifyShopping': 'kaputt'}).notifyShopping, isTrue);
  });

  group('anniversaryLeadDays (E-104)', () {
    test('Standard 7, Roundtrip, Grenzwerte 0 und 60', () {
      expect(const AppSettings().anniversaryLeadDays, 7);
      for (final d in <int>[0, 1, 7, 60]) {
        expect(AppSettings.fromMap(AppSettings(anniversaryLeadDays: d).toMap()).anniversaryLeadDays, d);
      }
    });

    test('ungültig, negativ oder über 60 beim Lesen: 7', () {
      for (final v in <String>['abc', '-1', '61', '', '7.5']) {
        expect(AppSettings.fromMap(<String, String>{'anniversaryLeadDays': v}).anniversaryLeadDays, 7, reason: v);
      }
      expect(AppSettings.fromMap(const <String, String>{}).anniversaryLeadDays, 7);
    });

    test('copyWith klemmt auf 0 bis 60; Gleichheit berücksichtigt den Wert', () {
      expect(const AppSettings().copyWith(anniversaryLeadDays: 99).anniversaryLeadDays, 60);
      expect(const AppSettings().copyWith(anniversaryLeadDays: -2).anniversaryLeadDays, 0);
      expect(const AppSettings(anniversaryLeadDays: 3) == const AppSettings(anniversaryLeadDays: 4), isFalse);
    });
  });
}
