import 'package:flutter/services.dart';

import '../../core/app_log.dart';

/// Bildschirmschutz hinter Schnittstelle. Android: FLAG_SECURE (keine Screenshots, leere Vorschau).
/// iOS: Sichtschutz im App-Umschalter und bei Bildschirmaufnahme (Screenshots lassen sich nicht verhindern).
/// macOS: kein Schutz, Screenshots (auch `screencapture`) sind erlaubt (`NSWindow.sharingType = .readOnly`).
/// Windows: `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)`, das Fenster fehlt in Aufnahmen und Freigaben.
abstract class ScreenProtection {
  Future<void> setSecure(bool secure);
}

class PlatformScreenProtection implements ScreenProtection {
  static const MethodChannel _channel = MethodChannel('de.inneso.familynexus/window');

  @override
  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // Plattform ohne Adapter (z. B. Tests): kein Schutz möglich.
    } on PlatformException catch (e) {
      AppLog.e('screen', 'Bildschirmschutz konnte nicht gesetzt werden', e);
    }
  }
}
