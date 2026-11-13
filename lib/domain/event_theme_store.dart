import 'event_themes.dart';

/// Port: lokale, verschlüsselte Ablage der Kalender-Themen (E-99).
abstract class EventThemeStore {
  Future<EventTheme?> get(String id);

  /// Aktuelle Fassungen aller Themen (auch Löschmarken).
  Future<List<EventTheme>> all();

  Future<({int active, int total})> counts();

  /// Speichert die aktuelle Fassung. [publishedVersion]: dem Server bereits bekannte Version
  /// (eingehend: die eigene; lokal geändert: 0, wird noch gesendet).
  Future<void> put(EventTheme theme, {int? publishedVersion});

  Future<List<EventTheme>> pending();

  Future<void> markPublished(String id, int version);

  /// Entfernt die ältesten **veröffentlichten** Löschmarken, sodass höchstens [keep] bleiben.
  Future<void> pruneTombstones({required int keep});

  /// Merkt alle eigenen (nicht gelöschten) Themen erneut zum Senden vor (Resync für neue Mitglieder).
  Future<void> requeueLastEditedBy(String userId);

  /// Entfernt endgültig alle Daten.
  Future<void> wipe();
}
