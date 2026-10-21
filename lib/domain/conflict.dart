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
}

/// Konfliktauflösung (E-13): höhere Version gewinnt; bei gleicher Version der
/// spätere `updatedAt`; bei völligem Gleichstand entscheidet die kanonische
/// Darstellung – so konvergieren alle Geräte unabhängig von der Reihenfolge.
class ConflictResolver {
  const ConflictResolver._();

  static Resolution resolve(CalendarEvent? current, CalendarEvent incoming) {
    if (current == null) return Resolution.insert;
    if (incoming.ownerId != current.ownerId) return Resolution.rejectOwner;
    if (incoming.version != current.version) {
      return incoming.version > current.version ? Resolution.replace : Resolution.ignoreStale;
    }
    if (incoming == current) return Resolution.ignoreDuplicate;
    final byTime = incoming.updatedAt.compareTo(current.updatedAt);
    if (byTime != 0) return byTime > 0 ? Resolution.replace : Resolution.ignoreStale;
    final byContent = EventCodec.canonical(incoming).compareTo(EventCodec.canonical(current));
    return byContent > 0 ? Resolution.replace : Resolution.ignoreStale;
  }
}
