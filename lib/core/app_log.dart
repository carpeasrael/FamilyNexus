import 'dart:developer' as developer;

/// Zentrales Logging. Gibt nie Klartextinhalte aus: Matrix-IDs, Tokens und
/// URLs-Parameter werden maskiert. Aufrufer sollen ohnehin nur Metadaten loggen.
class AppLog {
  AppLog._();

  /// Test-Hook: sammelt alle (bereits redigierten) Zeilen.
  static final List<String> captured = <String>[];
  static bool capture = false;

  static final RegExp _mxid = RegExp(r'@[A-Za-z0-9._=\-/+]+:[A-Za-z0-9.\-]+');
  static final RegExp _room = RegExp(r'![A-Za-z0-9._~\-]+:[A-Za-z0-9.\-]+');
  // Schlüsselwort + beliebiger Trenner (: = Leerzeichen, auch JSON `"key":`) + Wert.
  static final RegExp _secret = RegExp(
    r'''\b(access[_-]?token|refresh[_-]?token|token|password|passwort|passphrase|secret|authorization|bearer|recovery[_-]?key|key)\b["']?[\s:=]*(?:bearer\s+)?(?:"[^"]*"|'[^']*'|[^\s,;&}"']+)''',
    caseSensitive: false,
  );
  // Notfall-Schlüssel im Matrix-Format: 12 Vierergruppen Base58, durch Leerzeichen getrennt.
  static final RegExp _recovery = RegExp(r'\b(?:[1-9A-HJ-NP-Za-km-z]{4}\s+){11}[1-9A-HJ-NP-Za-km-z]{4}\b');
  // Lange Base64-/Hex-artige Zeichenketten (Schlüssel, Token).
  static final RegExp _blob = RegExp(r'[A-Za-z0-9_\-+/=]{32,}');

  static String redact(String s) => s
      .replaceAll(_recovery, '***')
      .replaceAll(_mxid, '@***:***')
      .replaceAll(_room, '!***:***')
      .replaceAllMapped(_secret, (m) => '${m.group(1)}=***')
      .replaceAll(_blob, '***');

  static void d(String tag, String message) => _emit('D', tag, message);
  static void w(String tag, String message) => _emit('W', tag, message);

  /// Loggt nur den Typ des Fehlers, nie dessen Text (kann Inhalte enthalten).
  static void e(String tag, String message, [Object? error]) =>
      _emit('E', tag, error == null ? message : '$message (${error.runtimeType})');

  static void _emit(String level, String tag, String message) {
    final line = '$level/$tag: ${redact(message)}';
    if (capture) captured.add(line);
    developer.log(line, name: 'FamilyNexus');
  }
}
