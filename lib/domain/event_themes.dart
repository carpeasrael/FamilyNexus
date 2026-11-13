import 'calendar_event.dart';
import 'server.dart';
import 'task_models.dart' show hasBadTitleText, isBlankTitleText;

/// Ein Kalender-Thema der Familie (E-99), z. B. „Schule“ in Lila.
///
/// Nur Moderatoren legen Themen an, ändern oder löschen sie. Jedes Thema ist ein eigener Datensatz mit
/// eigener Version und Löschmarke; gleichzeitige Änderungen konvergieren über [EventThemeMerge].
/// Himmelblau ([privateColorIndex]) gehört der Sichtbarkeit „privat“ und ist als Themenfarbe ausgeschlossen.
class EventTheme {
  EventTheme({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.by,
    required this.updatedAt,
    this.version = 1,
    this.deleted = false,
  });

  static const int maxName = 30;

  /// Höchstzahl aktiver Themen und aller Datensätze (inkl. Löschmarken), Speicherschutz.
  static const int maxActive = 12;
  static const int maxTotal = 40;
  static const int keepTombstones = 10;

  static const int maxVersion = 1000000;
  static const int maxFirstVersion = 10000;
  static const int maxVersionJump = 1000;

  /// Palettenindex (`AuroraTokens.personColors`), der für „privat“ reserviert ist (Himmelblau).
  static const int privateColorIndex = 3;

  /// Wählbare Themenfarben: alle Paletteneinträge außer [privateColorIndex].
  static List<int> get selectableColors =>
      <int>[for (var i = 0; i < CalendarEvent.colorCount; i++) if (i != privateColorIndex) i];

  final String id;
  final String name;
  final int colorIndex;
  final int version;
  final bool deleted;

  /// Letzter Bearbeiter (Matrix-ID); beim Empfang muss er dem authentischen Absender entsprechen.
  final String by;
  final DateTime updatedAt;

  List<String> validate() {
    final p = <String>[];
    if (!CalendarEvent.isValidId(id)) p.add('id');
    if (!MatrixIds.isUserId(by)) p.add('by');
    if (version < 1 || version > maxVersion) p.add('version');
    if (!updatedAt.isUtc || updatedAt.isBefore(CalendarEvent.minDate) || updatedAt.isAfter(CalendarEvent.maxDate)) p.add('time');
    if (colorIndex < 0 || colorIndex >= CalendarEvent.colorCount || colorIndex == privateColorIndex) p.add('color');
    if (name.runes.length > maxName || hasBadTitleText(name)) p.add('name');
    if (deleted) {
      if (name.isNotEmpty) p.add('tombstone');
    } else if (isBlankTitleText(name)) {
      p.add('name');
    }
    return p;
  }

  EventTheme copyWith({
    String? name,
    int? colorIndex,
    bool? deleted,
    int? version,
    String? by,
    DateTime? updatedAt,
  }) =>
      EventTheme(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        deleted: deleted ?? this.deleted,
        version: version ?? this.version,
        by: by ?? this.by,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is EventTheme &&
      other.id == id &&
      other.name == name &&
      other.colorIndex == colorIndex &&
      other.deleted == deleted &&
      other.version == version &&
      other.by == by &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, colorIndex, deleted, version, by, updatedAt);
}

/// Konfliktregel für Themen (wie E-40/E-51): höhere Version, dann Zeit, dann Absender-ID.
class EventThemeMerge {
  const EventThemeMerge._();

  static bool incomingWins(EventTheme? current, EventTheme incoming) {
    if (current == null) return true;
    if (incoming.version != current.version) return incoming.version > current.version;
    final byTime = incoming.updatedAt.compareTo(current.updatedAt);
    if (byTime != 0) return byTime > 0;
    final byAuthor = incoming.by.compareTo(current.by);
    if (byAuthor != 0) return byAuthor > 0;
    return _tie(incoming).compareTo(_tie(current)) > 0;
  }

  static String _tie(EventTheme t) => '${t.deleted}|${t.name}|${t.colorIndex}';
}
