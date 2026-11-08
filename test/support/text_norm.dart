import 'dart:io';

/// Plattformunabhängige Tests (#325): Windows liefert Pfade mit `\` und checkt Textdateien
/// mit `core.autocrlf=true` als CRLF aus. Die Tests prüfen den Inhalt, nicht das Zeilenende.

/// Pfad mit `/` als Trenner.
String posix(String path) => path.replaceAll(r'\', '/');

/// Datei lesen, `\r\n` zu `\n`.
String readNormalized(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');
