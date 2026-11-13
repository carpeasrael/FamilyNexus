/// Eingebaute Avatare der Familienmitglieder (#422, E-101): zwölf feste Kennungen. Gespeichert wird nur die Kennung,
/// als Raumzustand im Familienraum (nicht Ende-zu-Ende-verschlüsselt, ein Wert aus zwölf, kein Bild, kein Text).
class AvatarPresets {
  const AvatarPresets._();

  /// Zustandstyp im Familienraum; der Zustandsschlüssel ist die Matrix-ID der Person.
  static const String type = 'de.inneso.familynexus.avatar';

  /// Feld im Inhalt des Zustandsereignisses.
  static const String field = 'preset';

  static const List<String> all = <String>[
    'p01',
    'p02',
    'p03',
    'p04',
    'p05',
    'p06',
    'p07',
    'p08',
    'p09',
    'p10',
    'p11',
    'p12',
  ];

  /// `null` heißt „kein Avatar“ und ist gültig; sonst zählt nur eine Kennung aus [all].
  static bool isValid(String? preset) => preset == null || all.contains(preset);

  /// Inhalt des Zustandsereignisses: `{}` für „kein Avatar“ (Zustand lässt sich nicht löschen), sonst `{preset}`.
  static Map<String, Object?> content(String? preset) =>
      preset == null ? <String, Object?>{} : <String, Object?>{field: preset};

  /// Liest die Kennung aus einem Inhalt; fehlendes oder ungültiges `preset` ergibt `null` („kein Avatar“).
  static String? fromContent(Map<String, Object?> content) {
    final v = content[field];
    return v is String && all.contains(v) ? v : null;
  }

  /// Schaltet den Typ für Mitglieder frei: ergänzt in den Power-Levels `events[type] = 0` und lässt alle übrigen
  /// Felder unverändert. `null`, wenn die Freigabe schon besteht (Wert höchstens 0): dann nichts senden.
  static Map<String, Object?>? withPermission(Map<String, Object?> powerLevels) {
    final events = powerLevels['events'];
    if (events is Map && events[type] is int && (events[type] as int) <= 0) return null;
    return <String, Object?>{
      ...powerLevels,
      'events': <String, Object?>{
        if (events is Map) ...events.cast<String, Object?>(),
        type: 0,
      },
    };
  }

  /// Gilt die Freigabe nach diesem Stand der Power-Levels als gesetzt?
  static bool isPermitted(Map<String, Object?>? powerLevels) {
    final events = powerLevels?['events'];
    return events is Map && events[type] is int && (events[type] as int) <= 0;
  }
}

/// Ob die eigene Person ihren Avatar setzen darf.
enum AvatarAvailability {
  /// Familie noch nicht aufgebaut (vor dem ersten Abgleich): weder Hinweis noch Auswahl.
  unknown,
  settable,

  /// Ein Moderator muss die Funktion in dieser (älteren) Familie erst freischalten.
  needsModerator,
}
