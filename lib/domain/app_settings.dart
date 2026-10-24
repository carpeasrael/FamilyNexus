import 'moderation.dart';
import 'server.dart';

enum AppThemeMode { system, dark, light }

/// Wählbare Neon-Akzentfarbe (Primärfarbe der Oberfläche). Die Farbwerte stehen im Design-System
/// (`AccentPalette`), hier nur die Kennung.
enum AccentChoice { teal, magenta, violet, sky, lime, orange, rose, green }

/// Allgemeine, nicht geheime Einstellungen (liegen dennoch in der
/// verschlüsselten Datenbank).
class AppSettings {
  const AppSettings({
    this.languageCode,
    this.themeMode = AppThemeMode.dark,
    this.reduceEffects = false,
    this.secureScreen = true,
    this.serverUrl = defaultServerUrl,
    this.onboardingDone = false,
    this.lockEnabled = false,
    this.lockTimeoutSeconds = 60,
    this.shareOnlineStatus = true,
    this.accent = AccentChoice.teal,
    this.defaultReminderMinutes = const <int>[10],
    this.blockedUsers = const <String>[],
    this.pendingInvite,
  });

  /// Öffentlicher Standardserver (E-07).
  static const String defaultServerUrl = 'https://matrix.org';

  /// `null` = Gerätesprache.
  final String? languageCode;
  final AppThemeMode themeMode;
  final bool reduceEffects;
  final bool secureScreen;
  final String serverUrl;
  final bool onboardingDone;
  final bool lockEnabled;
  final int lockTimeoutSeconds;

  /// Online-Status an die Familie melden (E-38).
  final bool shareOnlineStatus;

  /// Neon-Akzentfarbe (Standard: Teal der AURORA-Palette).
  final AccentChoice accent;
  final List<int> defaultReminderMinutes;

  /// Lokal blockierte Matrix-IDs (E-48).
  final List<String> blockedUsers;

  /// Einladungslink, der vor der Anmeldung geöffnet wurde (E-56). Bleibt erhalten, falls das System
  /// die App beendet, während die Person im Browser ihr Konto anlegt. Rohtext, wird beim Lesen erneut
  /// streng geprüft.
  final String? pendingInvite;

  AppSettings copyWith({
    Object? languageCode = _unset,
    AppThemeMode? themeMode,
    bool? reduceEffects,
    bool? secureScreen,
    String? serverUrl,
    bool? onboardingDone,
    bool? lockEnabled,
    int? lockTimeoutSeconds,
    bool? shareOnlineStatus,
    AccentChoice? accent,
    List<int>? defaultReminderMinutes,
    List<String>? blockedUsers,
    Object? pendingInvite = _unset,
  }) =>
      AppSettings(
        languageCode:
            identical(languageCode, _unset) ? this.languageCode : languageCode as String?,
        themeMode: themeMode ?? this.themeMode,
        reduceEffects: reduceEffects ?? this.reduceEffects,
        secureScreen: secureScreen ?? this.secureScreen,
        serverUrl: serverUrl == null ? this.serverUrl : (_validServer(serverUrl) ?? this.serverUrl),
        onboardingDone: onboardingDone ?? this.onboardingDone,
        lockEnabled: lockEnabled ?? this.lockEnabled,
        lockTimeoutSeconds: (lockTimeoutSeconds ?? this.lockTimeoutSeconds).clamp(0, 3600),
        shareOnlineStatus: shareOnlineStatus ?? this.shareOnlineStatus,
        accent: accent ?? this.accent,
        defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
        blockedUsers: blockedUsers ?? this.blockedUsers,
        pendingInvite: identical(pendingInvite, _unset) ? this.pendingInvite : _validInvite(pendingInvite as String?),
      );

  static const Object _unset = Object();

  Map<String, String> toMap() => <String, String>{
        'language': ?languageCode,
        'theme': themeMode.name,
        'reduceEffects': '$reduceEffects',
        'secureScreen': '$secureScreen',
        'serverUrl': serverUrl,
        'onboardingDone': '$onboardingDone',
        'lockEnabled': '$lockEnabled',
        'lockTimeout': '$lockTimeoutSeconds',
        'shareOnlineStatus': '$shareOnlineStatus',
        'accent': accent.name,
        'defaultReminders': defaultReminderMinutes.join(','),
        if (blockedUsers.isNotEmpty) 'blockedUsers': BlockedUsers.encode(blockedUsers),
        'pendingInvite': ?pendingInvite,
      };

  /// Liest Einstellungen defensiv: unbekannte oder ungültige Werte fallen auf
  /// den Standard zurück (Eingaben gelten als nicht vertrauenswürdig).
  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    final lang = m['language'];
    final timeout = int.tryParse(m['lockTimeout'] ?? '');
    final reminders = (m['defaultReminders'] ?? '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((v) => v >= 0 && v <= 60 * 24 * 60)
        .toList();
    return AppSettings(
      languageCode: (lang == 'de' || lang == 'en') ? lang : null,
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == m['theme'],
        orElse: () => d.themeMode,
      ),
      reduceEffects: m['reduceEffects'] == 'true',
      secureScreen: m['secureScreen'] != 'false',
      serverUrl: _validServer(m['serverUrl']) ?? d.serverUrl,
      onboardingDone: m['onboardingDone'] == 'true',
      lockEnabled: m['lockEnabled'] == 'true',
      lockTimeoutSeconds: (timeout != null && timeout >= 0 && timeout <= 3600) ? timeout : d.lockTimeoutSeconds,
      shareOnlineStatus: m['shareOnlineStatus'] != 'false',
      accent: AccentChoice.values.firstWhere((e) => e.name == m['accent'], orElse: () => d.accent),
      defaultReminderMinutes: m.containsKey('defaultReminders') ? reminders : d.defaultReminderMinutes,
      blockedUsers: BlockedUsers.parse(m['blockedUsers']),
      pendingInvite: _validInvite(m['pendingInvite']),
    );
  }

  /// Nur kurze Links im App-Schema; die eigentliche Prüfung macht `InviteLink.tryParse`.
  static String? _validInvite(String? raw) =>
      (raw != null && raw.length <= 1024 && raw.startsWith('familynexus://join?')) ? raw : null;

  /// Nur gültige https-Server werden übernommen (gespeicherte Werte gelten als
  /// nicht vertrauenswürdig).
  static String? _validServer(String? raw) =>
      raw == null ? null : ServerUrl.tryParse(raw)?.toString();

  @override
  bool operator ==(Object other) {
    if (other is! AppSettings) return false;
    final a = toMap();
    final b = other.toMap();
    return a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
  }

  @override
  int get hashCode => Object.hashAll(toMap().entries.map((e) => Object.hash(e.key, e.value)));
}
