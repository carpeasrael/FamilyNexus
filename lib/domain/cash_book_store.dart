import 'cash_book.dart';

/// Port: lokale, verschlüsselte Ablage der Kassenbücher und ihrer Einträge (E-113).
abstract class CashBookStore {
  Future<CashBookMeta?> getBook(String roomId);

  /// Alle bekannten Bücher.
  Future<List<CashBookMeta>> books();

  /// Speichert Titel und Währung eines Buchs ([published]: dem Server bekannt).
  Future<void> putBook(CashBookMeta meta, {bool published = true});

  /// Eigene Bücher (Ersteller [owner]) mit echten Metadaten (Version ≥ 1), die noch nicht gesendet wurden. Das
  /// Platzhalter-Buch (Version 0) gehört nie dazu.
  Future<List<CashBookMeta>> pendingBooks(String owner);

  /// Markiert [sent] als gesendet, **nur** wenn Titel, Währung und Version des gespeicherten Buchs noch genau diesem
  /// Stand entsprechen (eine zwischenzeitliche Änderung bleibt in der Warteschlange).
  Future<void> markBookPublished(CashBookMeta sent);

  /// Merkt die Metadaten des Buchs erneut zum Senden vor (Resync für neue Mitglieder); nie das Platzhalter-Buch.
  Future<void> requeueBook(String roomId);

  /// Entfernt Buch und alle Einträge (Verlassen, Familienwechsel).
  Future<void> deleteBook(String roomId);

  /// Ist der Verlauf des Buchs vollständig geladen (Backfill beendet)? Bis dahin stehen Summen unter Vorbehalt.
  Future<bool> isComplete(String roomId);
  Future<void> setComplete(String roomId, bool complete);

  Future<CashEntry?> getEntry(String roomId, String author, String id);

  /// Aktuelle Fassungen aller Einträge des Buchs (auch Löschmarken).
  Future<List<CashEntry>> entries(String roomId);

  Future<int> countByAuthor(String roomId, String author);

  /// Speichert die aktuelle Fassung. [publishedVersion]: dem Server bereits bekannte Version (eingehend: die eigene;
  /// lokal geändert: bisheriger Wert, die Fassung wird noch gesendet).
  Future<void> putEntry(String roomId, CashEntry entry, {int? publishedVersion});

  /// Eigene Fassungen, deren Version noch nicht gesendet wurde.
  Future<List<({String roomId, CashEntry entry})>> pending(String author);
  Future<void> markPublished(String roomId, String author, String id, int version);

  /// Merkt alle eigenen (nicht gelöschten) Einträge des Buchs erneut zum Senden vor (Resync für neue Mitglieder).
  Future<void> requeueOwn(String roomId, String author);

  /// Entfernt endgültig alle Daten.
  Future<void> wipe();
}
