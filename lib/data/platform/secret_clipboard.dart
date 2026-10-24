import 'package:flutter/services.dart';

/// Kopiert ein Geheimnis (Notfall-Schlüssel) in die Zwischenablage. Android markiert es als vertraulich
/// (keine Vorschau, kein Tastatur-Verlauf); andere Plattformen nutzen die normale Zwischenablage.
Future<void> copySecret(String secret) async {
  try {
    await const MethodChannel('de.inneso.familynexus/window').invokeMethod<void>('copySecret', secret);
    return;
  } on MissingPluginException {
    // Plattform ohne Adapter: normale Zwischenablage.
  } on PlatformException {
    // Fehler im Adapter: normale Zwischenablage.
  }
  await Clipboard.setData(ClipboardData(text: secret));
}
