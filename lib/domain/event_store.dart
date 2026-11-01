import 'calendar_event.dart';

/// Port: lokale, verschlüsselte Ablage der Termine (einzige Quelle der Wahrheit).
abstract class EventStore {
  Future<CalendarEvent?> get(String id);

  /// Aktuelle Fassungen aller Termine (auch gelöschte Markierungen).
  Future<List<CalendarEvent>> all();

  /// Speichert die aktuelle Fassung; eine ersetzte Fassung wandert in den Verlauf.
  /// [publishedVersion]: Version, die dem Server bereits bekannt ist
  /// (eingehende Termine: ihre eigene; lokal geänderte: bisheriger Wert).
  Future<void> put(CalendarEvent event, {CalendarEvent? replaced, int? publishedVersion});

  /// Anzahl gespeicherter Termine dieses Besitzers.
  Future<int> countOwnedBy(String owner);

  /// Merkt die eigenen geteilten Termine (nicht gelöscht) und alle eigenen Zusagen
  /// erneut zum Senden vor (Resync für neue Mitglieder; überlebt Neustarts).
  Future<void> requeueOwnShared(String owner);

  /// Höchstzahl älterer Fassungen je Termin.
  static const int maxHistoryPerEvent = 20;

  /// Legt eine unterlegene/ältere Fassung nur in den Verlauf (aktuelle bleibt).
  Future<void> addHistory(CalendarEvent event);

  /// Ältere Fassungen (neueste zuerst).
  Future<List<CalendarEvent>> history(String id);

  /// Eigene Termine, deren aktuelle Version noch nicht veröffentlicht wurde.
  Future<List<CalendarEvent>> pendingPublish();
  Future<void> markPublished(String id, int version);

  /// Persönliche Erinnerungen (Minuten vor Beginn). Fehlt ein Eintrag → Standard.
  Future<Map<String, List<int>>> reminders();
  Future<void> setReminders(String eventId, List<int>? minutes);

  /// Zusagen: Termin → Person → Status.
  Future<Map<String, Map<String, RsvpStatus>>> rsvps();

  /// Übernimmt die Zusage, wenn [timestamp] neuer ist als die gespeicherte. `true`, wenn geschrieben wurde (#131).
  Future<bool> putRsvp(
    String eventId,
    String userId,
    RsvpStatus status,
    DateTime timestamp, {
    bool published = true,
  });

  /// Eigene Zusagen, die noch nicht gesendet wurden.
  Future<List<({String eventId, RsvpStatus status, DateTime timestamp})>> pendingRsvps(String userId);

  Future<void> markRsvpPublished(String eventId, String userId, DateTime timestamp);

  /// Personenfarben (Matrix-ID → Palettenindex).
  Future<Map<String, int>> personColors();
  Future<void> setPersonColor(String userId, int colorIndex);

  /// Entfernt endgültig alle Daten (Konto-/Datenlöschung).
  Future<void> wipe();
}
