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
}
