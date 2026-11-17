import 'anniversaries.dart';

/// Port: lokale, verschlüsselte Ablage der Geburts- und Gedenktage (E-104).
abstract class AnniversaryStore {
  Future<AnniversaryPerson?> get(String id);

  /// Aktuelle Fassungen aller Personen (auch Löschmarken).
  Future<List<AnniversaryPerson>> all();

  Future<({int active, int total})> counts();

  /// Speichert die aktuelle Fassung. [publishedVersion]: dem Server bereits bekannte Version
  /// (eingehend: die eigene; lokal geändert: 0, wird noch gesendet).
  Future<void> put(AnniversaryPerson person, {int? publishedVersion});

  Future<List<AnniversaryPerson>> pending();

  Future<void> markPublished(String id, int version);

  /// Entfernt die ältesten **veröffentlichten** Löschmarken, sodass höchstens [keep] bleiben.
  Future<void> pruneTombstones({required int keep});

  /// Merkt alle eigenen (nicht gelöschten) Einträge erneut zum Senden vor (Resync für neue Mitglieder).
  Future<void> requeueLastEditedBy(String userId);

  /// Entfernt endgültig alle Daten.
  Future<void> wipe();
}
