import 'package:flutter/services.dart';

const _channel = MethodChannel('de.inneso.familynexus/window');

/// Kopiert ein Geheimnis (Notfall-Schlüssel) in die Zwischenablage. Android markiert es als vertraulich
/// (keine Vorschau, kein Tastatur-Verlauf); iOS und macOS halten es nur auf diesem Gerät (kein Universal
/// Clipboard), iOS lässt es nach 60 s verfallen, macOS markiert es als vertraulich. Andere Plattformen
/// nutzen die normale Zwischenablage. Das Leeren nach 60 s übernimmt `clearClipboardLater`.
Future<void> copySecret(String secret) => _copy('copySecret', secret);

/// Wie [copySecret], aber für längere sensible Texte (Datenprotokoll, #157): Die Adapter lassen hier bis zu
/// 100 000 Zeichen zu (Notfall-Schlüssel: 512). Scheitert der Adapter (zu groß, Fehler), bleibt es bei der
/// normalen Zwischenablage; der Aufrufer leert sie trotzdem mit `clearClipboardLater`.
Future<void> copySensitive(String text) => _copy('copySensitive', text);

Future<void> _copy(String method, String text) async {
  try {
    await _channel.invokeMethod<void>(method, text);
    return;
  } on MissingPluginException {
    // Plattform ohne Adapter: normale Zwischenablage.
  } on PlatformException {
    // Fehler im Adapter: normale Zwischenablage.
  }
  await Clipboard.setData(ClipboardData(text: text));
}
