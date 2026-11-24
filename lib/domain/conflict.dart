import 'calendar_event.dart';
import 'event_codec.dart';

enum Resolution {
  /// Neuer Termin.
  insert,

  /// Eingehende Fassung ersetzt die gespeicherte; die alte kommt in den Verlauf.
  replace,

  /// Eingehende Fassung ist älter; nur für den Verlauf relevant.
  ignoreStale,

  /// Identisch zur gespeicherten Fassung (z. B. Resync).
  ignoreDuplicate,

  /// Anderer Absender als der Besitzer: wird verworfen.
  rejectOwner,

  /// Fremdfassung (Moderator, #431), die noch nicht beurteilt werden kann (Rolle, Basis oder Versionsfenster):
  /// wird kurz im Speicher gehalten und später erneut geprüft.
  deferred,
}

/// Konfliktauflösung (E-13, E-112): lexikografische Totalordnung `(deleted, version, ohne editor, updatedAt,
/// kanonische Darstellung)`, größer gewinnt – so konvergieren alle Geräte unabhängig von der Reihenfolge.
///
/// * Eine Löschmarke schlägt jede nicht gelöschte Fassung, auch mit höherer Version (Löschen ist endgültig). Das gilt
///   nur bei gleicher Sichtbarkeit; beim erlaubten Übergang privat → geteilt zweier Geräte des Besitzers entscheidet
///   weiter die Version.
/// * Bei gleicher Version schlägt eine Fassung ohne `editorId` (Besitzer) eine Moderatorfassung, unabhängig von der
///   frei wählbaren `updatedAt`.
class ConflictResolver {
  const ConflictResolver._();

  static Resolution resolve(CalendarEvent? current, CalendarEvent incoming) {
    if (current == null) return Resolution.insert;
    if (incoming.ownerId != current.ownerId) return Resolution.rejectOwner;
    if (incoming == current) return Resolution.ignoreDuplicate;
    return _compare(incoming, current) > 0 ? Resolution.replace : Resolution.ignoreStale;
  }

  static int _compare(CalendarEvent a, CalendarEvent b) {
    if (a.visibility == b.visibility && a.deleted != b.deleted) return a.deleted ? 1 : -1;
    if (a.version != b.version) return a.version.compareTo(b.version);
    final aOwner = a.editorId == null;
    if (aOwner != (b.editorId == null)) return aOwner ? 1 : -1;
    final byTime = a.updatedAt.compareTo(b.updatedAt);
    if (byTime != 0) return byTime;
    return EventCodec.canonical(a).compareTo(EventCodec.canonical(b));
  }
}
