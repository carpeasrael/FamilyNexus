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
    this.tourSeen = false,
    this.lockEnabled = false,
    this.lockTimeoutSeconds = 60,
    this.shareOnlineStatus = true,
    this.shareReadReceipts = true,
    this.notifyChat = true,
    this.notifyShopping = true,
    this.accent = AccentChoice.teal,
    this.defaultReminderMinutes = const <int>[10],
    this.blockedUsers = const <String>[],
    this.anniversaryLeadDays = defaultAnniversaryLeadDays,
    this.pendingInvite,
    this.restoreLastChat = false,
    this.lastChatThread,
  });

  /// Vorlaufzeit der Geburts- und Gedenktage auf „Heute“ in Tagen (E-104): Standard 7, 0 = nur am Tag selbst.
  static const int defaultAnniversaryLeadDays = 7;
  static const int maxAnniversaryLeadDays = 60;

  /// Auswahl in den Einstellungen.
  static const List<int> anniversaryLeadChoices = <int>[0, 1, 3, 7, 14, 30, 60];

  /// Öffentlicher Standardserver (E-07).
  static const String defaultServerUrl = 'https://matrix.org';

  /// `null` = Gerätesprache.
  final String? languageCode;
  final AppThemeMode themeMode;
  final bool reduceEffects;
  final bool secureScreen;
  final String serverUrl;
  final bool onboardingDone;

  /// Die Einführungstour wurde gesehen oder übersprungen (#347). Rein lokal, ohne Personenbezug.
  final bool tourSeen;
  final bool lockEnabled;
  final int lockTimeoutSeconds;

  /// Online-Status an die Familie melden (E-38).
  final bool shareOnlineStatus;

  /// Öffentliche Lesebestätigung senden und anzeigen, wer gelesen hat (#526, E-106). Aus: nur private Lesemarker.
  final bool shareReadReceipts;

  /// Meldung „Neue Nachrichten“ ohne Inhalt, solange die App geöffnet ist; auf Mobilgeräten im Hintergrund nicht zugesagt (#254, E-88, #273).
  final bool notifyChat;

  /// Meldung „Neue Einträge auf dem Einkaufszettel“ ohne Inhalt, solange die App geöffnet ist; auf Mobilgeräten im Hintergrund nicht zugesagt (#254, E-88, #273).
  final bool notifyShopping;

  /// Neon-Akzentfarbe (Standard: Teal der AURORA-Palette).
  final AccentChoice accent;
  final List<int> defaultReminderMinutes;

  /// Schlüssel in der Ablage (`settings`); die Liste gehört zu den lokalen Familiendaten und wird mit ihnen gelöscht (#450).
  static const String blockedUsersKey = 'blockedUsers';

  /// Lokal blockierte Matrix-IDs (E-48).
  final List<String> blockedUsers;

  /// Wie viele Tage vorher Geburts- und Gedenktage auf „Heute“ erscheinen (0–60). Rein lokal, je Gerät (E-104).
  final int anniversaryLeadDays;

  /// Einladungslink, der vor der Anmeldung geöffnet wurde (E-56). Bleibt erhalten, falls das System
  /// die App beendet, während die Person auf der Seite des Anbieters ihr Konto anlegt. Rohtext, wird
  /// beim Lesen erneut streng geprüft (`InviteLink.check`).
  final String? pendingInvite;

  /// Schlüssel in der Ablage; die Kennung gehört zu den lokalen Familiendaten und wird mit ihnen gelöscht (E-107).
  static const String lastChatThreadKey = 'lastChatThread';

  /// Im Chat-Tab das zuletzt offene Gespräch statt der Liste öffnen (#516, E-107). Standard aus, rein lokal.
  final bool restoreLastChat;

  /// Zuletzt offenes Gespräch (`ChatThread.familyId` oder Raum-ID); wird nur gespeichert, solange [restoreLastChat]
  /// an ist. `null` = Liste oder nichts gemerkt.
  final String? lastChatThread;

  AppSettings copyWith({
    Object? languageCode = _unset,
    AppThemeMode? themeMode,
    bool? reduceEffects,
    bool? secureScreen,
    String? serverUrl,
    bool? onboardingDone,
    bool? tourSeen,
    bool? lockEnabled,
    int? lockTimeoutSeconds,
    bool? shareOnlineStatus,
    bool? shareReadReceipts,
    bool? notifyChat,
    bool? notifyShopping,
    AccentChoice? accent,
    List<int>? defaultReminderMinutes,
    List<String>? blockedUsers,
    int? anniversaryLeadDays,
    Object? pendingInvite = _unset,
    bool? restoreLastChat,
    Object? lastChatThread = _unset,
  }) =>
      AppSettings(
        languageCode:
            identical(languageCode, _unset) ? this.languageCode : languageCode as String?,
        themeMode: themeMode ?? this.themeMode,
        reduceEffects: reduceEffects ?? this.reduceEffects,
        secureScreen: secureScreen ?? this.secureScreen,
        serverUrl: serverUrl == null ? this.serverUrl : (_validServer(serverUrl) ?? this.serverUrl),
        onboardingDone: onboardingDone ?? this.onboardingDone,
        tourSeen: tourSeen ?? this.tourSeen,
        lockEnabled: lockEnabled ?? this.lockEnabled,
        lockTimeoutSeconds: (lockTimeoutSeconds ?? this.lockTimeoutSeconds).clamp(0, 3600),
        shareOnlineStatus: shareOnlineStatus ?? this.shareOnlineStatus,
        shareReadReceipts: shareReadReceipts ?? this.shareReadReceipts,
        notifyChat: notifyChat ?? this.notifyChat,
        notifyShopping: notifyShopping ?? this.notifyShopping,
        accent: accent ?? this.accent,
        defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
        blockedUsers: blockedUsers ?? this.blockedUsers,
        anniversaryLeadDays: (anniversaryLeadDays ?? this.anniversaryLeadDays).clamp(0, maxAnniversaryLeadDays),
        pendingInvite: identical(pendingInvite, _unset) ? this.pendingInvite : _validInvite(pendingInvite as String?),
        restoreLastChat: restoreLastChat ?? this.restoreLastChat,
        lastChatThread: identical(lastChatThread, _unset) ? this.lastChatThread : _validThread(lastChatThread as String?),
      );

  static const Object _unset = Object();

  Map<String, String> toMap() => <String, String>{
        'language': ?languageCode,
        'theme': themeMode.name,
        'reduceEffects': '$reduceEffects',
        'secureScreen': '$secureScreen',
        'serverUrl': serverUrl,
        'onboardingDone': '$onboardingDone',
        'tourSeen': '$tourSeen',
        'lockEnabled': '$lockEnabled',
        'lockTimeout': '$lockTimeoutSeconds',
        'shareOnlineStatus': '$shareOnlineStatus',
        'shareReadReceipts': '$shareReadReceipts',
        'notifyChat': '$notifyChat',
        'notifyShopping': '$notifyShopping',
        'accent': accent.name,
        'defaultReminders': defaultReminderMinutes.join(','),
        if (blockedUsers.isNotEmpty) blockedUsersKey: BlockedUsers.encode(blockedUsers),
        'anniversaryLeadDays': '$anniversaryLeadDays',
        'pendingInvite': ?pendingInvite,
        'restoreLastChat': '$restoreLastChat',
        lastChatThreadKey: ?lastChatThread,
      };

  /// Liest Einstellungen defensiv: unbekannte oder ungültige Werte fallen auf
  /// den Standard zurück (Eingaben gelten als nicht vertrauenswürdig).
  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    final lang = m['language'];
    final timeout = int.tryParse(m['lockTimeout'] ?? '');
    final lead = int.tryParse(m['anniversaryLeadDays'] ?? '');
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
      // Bestehende Einrichtungen ohne den Schlüssel (Stand vor #347) bekommen die Tour nicht nachträglich.
      tourSeen: m['tourSeen'] == 'true' || (m['onboardingDone'] == 'true' && !m.containsKey('tourSeen')),
      lockEnabled: m['lockEnabled'] == 'true',
      lockTimeoutSeconds: (timeout != null && timeout >= 0 && timeout <= 3600) ? timeout : d.lockTimeoutSeconds,
      shareOnlineStatus: m['shareOnlineStatus'] != 'false',
      shareReadReceipts: m['shareReadReceipts'] != 'false',
      notifyChat: m['notifyChat'] != 'false',
      notifyShopping: m['notifyShopping'] != 'false',
      accent: AccentChoice.values.firstWhere((e) => e.name == m['accent'], orElse: () => d.accent),
      defaultReminderMinutes: m.containsKey('defaultReminders') ? reminders : d.defaultReminderMinutes,
      blockedUsers: BlockedUsers.parse(m[blockedUsersKey]),
      anniversaryLeadDays: (lead != null && lead >= 0 && lead <= maxAnniversaryLeadDays) ? lead : defaultAnniversaryLeadDays,
      pendingInvite: _validInvite(m['pendingInvite']),
      restoreLastChat: m['restoreLastChat'] == 'true',
      lastChatThread: _validThread(m[lastChatThreadKey]),
    );
  }

  /// Nur kurze Links im App-Schema; die eigentliche Prüfung macht `InviteLink.check`.
  static String? _validInvite(String? raw) =>
      (raw != null && raw.length <= 1024 && raw.startsWith('familynexus://join')) ? raw : null;

  /// Gemerkte Gesprächs-Kennung: nicht leer, höchstens 255 Zeichen, keine Steuerzeichen (gilt als nicht vertrauenswürdig).
  static String? _validThread(String? raw) =>
      (raw != null && raw.isNotEmpty && raw.length <= 255 && !RegExp(r'[\x00-\x1f\x7f]').hasMatch(raw)) ? raw : null;

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
