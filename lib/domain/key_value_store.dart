/// Port: einfache Schlüssel-Wert-Ablage für Einstellungen.
abstract class KeyValueStore {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Schreibt und löscht atomar (alles oder nichts).
  Future<void> apply({Map<String, String> writes = const <String, String>{}, Iterable<String> deletes = const <String>[]});
}
