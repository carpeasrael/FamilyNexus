/// Typsicheres Lesen aus entschlüsseltem JSON, Serverantworten und Kontodaten (AP-6b).
///
/// Jede Funktion gibt `null` zurück, wenn der Wert fehlt oder einen anderen Typ hat; nie eine Ausnahme. Wer einen Wert
/// zwingend braucht, prüft das Ergebnis selbst und entscheidet, ob er den Eintrag verwirft oder den Vorgang abbricht.
/// Ersetzt Casts wie `x as int?` und `(x as Map)['a'] as Map?`, die bei einem falschen Typ werfen.
abstract final class JsonRead {
  static String? string(Object? v) => v is String ? v : null;

  /// Nur echte ganze Zahlen; `1.0` und Zeichenketten sind kein `int`.
  static int? integer(Object? v) => v is int ? v : null;

  static bool? boolean(Object? v) => v is bool ? v : null;

  /// Ein JSON-Objekt; die Schlüssel bleiben `Object?`, weil Antworten des SDK `Map<Object?, Object?>` liefern können.
  static Map<Object?, Object?>? map(Object? v) => v is Map<Object?, Object?> ? v : null;

  static List<Object?>? list(Object? v) => v is List<Object?> ? v : null;

  /// Wert zu [key] in [container], falls dieser ein Objekt ist, sonst `null`.
  static Object? at(Object? container, Object? key) => container is Map<Object?, Object?> ? container[key] : null;

  /// Pfad durch verschachtelte Objekte (`path(data, ['rooms', 'leave'])`); `null`, sobald ein Schritt kein Objekt ist.
  static Object? path(Object? root, List<Object?> keys) {
    Object? cur = root;
    for (final k in keys) {
      cur = at(cur, k);
      if (cur == null) return null;
    }
    return cur;
  }
}
