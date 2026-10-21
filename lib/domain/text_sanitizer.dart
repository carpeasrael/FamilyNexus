/// Bereinigung nicht vertrauenswürdiger Anzeigetexte (Namen, Dateinamen,
/// Reaktionen): entfernt Steuer- und Bidi-Zeichen, normalisiert Leerraum und
/// begrenzt die Länge (in Zeichen, nicht in UTF-16-Einheiten).
class TextSanitizer {
  const TextSanitizer._();

  static final RegExp _bad = RegExp(
    '[\\u0000-\\u001F\\u007F-\\u009F\\u061C\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
  );

  static String clean(String input, {int max = 64}) {
    var s = input.replaceAll(_bad, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = s.runes.toList();
    if (runes.length > max) s = String.fromCharCodes(runes.take(max));
    return s;
  }

  /// Anzeigename mit Rückfall auf die Matrix-ID, falls nach der Bereinigung leer.
  static String displayName(String? name, String fallbackId) {
    final c = clean(name ?? '');
    return c.isEmpty ? clean(fallbackId, max: 80) : c;
  }

  /// Akzeptiert nur kurze Zeichenfolgen, die nicht rein aus ASCII-Buchstaben/Ziffern bestehen
  /// (grobe Emoji-Prüfung; verhindert Text als „Reaktion“).
  static bool isReactionKey(String key) {
    if (key.isEmpty || key.runes.length > 8 || _bad.hasMatch(key)) return false;
    return !RegExp(r'^[A-Za-z0-9 ]+$').hasMatch(key);
  }
}
