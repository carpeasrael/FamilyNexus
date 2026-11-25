import 'contacts.dart';

/// Port: lokale, verschlüsselte Ablage der Kontakte, Gruppen und der Einstellung (#119, E-114). Der Schlüssel ist
/// `(kind, id)`; es liegt immer nur die aktuelle Fassung vor (auch Löschmarken).
abstract class ContactStore {
  Future<ContactRecord?> get(ContactKind kind, String id);

  /// Aktuelle Fassungen aller Datensätze (auch Löschmarken), bei [kind] nur dieser Art.
  Future<List<ContactRecord>> all([ContactKind? kind]);

  /// Speichert die aktuelle Fassung. [publishedVersion]: dem Server bereits bekannte Version (empfangen: die eigene;
  /// lokal geändert: `null`, der bisherige Wert bleibt, die Fassung wird noch gesendet; neue Zeile: 0).
  Future<void> put(ContactRecord record, {int? publishedVersion});

  /// Eigene Fassungen, deren Version noch nicht gesendet wurde.
  Future<List<ContactRecord>> pending();

  /// Merkt [version] als gesendet; eine neuere gespeicherte Fassung bleibt in der Warteschlange.
  Future<void> markPublished(ContactKind kind, String id, int version);

  /// Entfernt die ältesten **veröffentlichten** Löschmarken, sodass höchstens [keep] veröffentlichte bleiben.
  /// Unveröffentlichte Löschmarken bleiben immer (sonst ginge eine eigene Löschung verloren). Liefert die Zahl.
  Future<int> pruneTombstones({required int keep});

  /// Merkt alle eigenen (nicht gelöschten) Datensätze erneut zum Senden vor (Resync für neue Geräte).
  Future<void> requeueAll();

  /// Entfernt endgültig alle Daten.
  Future<void> wipe();
}
