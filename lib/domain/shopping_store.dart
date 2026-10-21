import 'shopping.dart';

/// Port: lokale, verschlüsselte Ablage der Einkaufsliste (E-40).
abstract class ShoppingStore {
  Future<ShoppingItem?> get(String id);

  /// Aktuelle Fassungen aller Datensätze (auch Löschmarken).
  Future<List<ShoppingItem>> all();

  /// Anzahl aktiver (nicht gelöschter) und aller Datensätze.
  Future<({int active, int total})> counts();

  /// Speichert die aktuelle Fassung. [publishedVersion]: dem Server bereits bekannte Version
  /// (eingehende Einträge: ihre eigene; lokal geänderte: 0 – sie werden noch gesendet).
  Future<void> put(ShoppingItem item, {int? publishedVersion});

  /// Einträge, deren aktuelle Version noch nicht gesendet wurde.
  Future<List<ShoppingItem>> pendingPublish();

  Future<void> markPublished(String id, int version);

  /// Merkt alle aktiven Einträge, die zuletzt von [userId] bearbeitet wurden, erneut zum Senden
  /// vor (Resync für neue Mitglieder; überlebt Neustarts).
  Future<void> requeueLastEditedBy(String userId);

  /// Entfernt die ältesten **veröffentlichten** Löschmarken, sodass höchstens [keep] bleiben
  /// (Speicherschutz). Unveröffentlichte Löschmarken bleiben immer erhalten.
  Future<void> pruneTombstones({required int keep});

  /// Entfernt endgültig alle Daten (Konto-/Datenlöschung).
  Future<void> wipe();
}
