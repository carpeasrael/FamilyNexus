import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import '../../core/app_log.dart';

/// Obergrenze für das Löschen des Website-Datenspeichers (#486). Eigene Konstante, damit `lib/data` nichts aus
/// `lib/features` einbindet; sie entspricht der Frist der eingebetteten Seite (`kClearTimeout`).
const Duration kWebsiteDataTimeout = Duration(seconds: 3);

/// Löscht den gesamten Website-Datenspeicher der Systemansicht (iOS, macOS: `WKWebsiteDataStore`, #486).
///
/// Das Paket `webview_flutter_wkwebview` nutzt den persistenten Standardspeicher von WebKit und löscht nur
/// Cookies, Cache und `localStorage`; IndexedDB, WebSQL, Service Worker und CacheStorage der besuchten Seiten
/// blieben im App-Container. Der Aufruf geht über den Fensterkanal (`clearWebsiteData`). Auf anderen
/// Plattformen und im Browser geschieht nichts. Die Methode wirft nie und wartet höchstens [kWebsiteDataTimeout].
class ChannelWebsiteData {
  const ChannelWebsiteData({this.platform, this.isWeb});

  static const MethodChannel _channel = MethodChannel('de.inneso.familynexus/window');

  /// Test: Plattform vorgeben (sonst `defaultTargetPlatform`).
  final TargetPlatform? platform;

  /// Test: Browser vorgeben (sonst `kIsWeb`).
  final bool? isWeb;

  bool get _supported {
    if (isWeb ?? kIsWeb) return false;
    final p = platform ?? defaultTargetPlatform;
    return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
  }

  Future<void> clear() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('clearWebsiteData').timeout(kWebsiteDataTimeout);
    } on MissingPluginException {
      AppLog.w('website-data', 'Kein Adapter für den Website-Datenspeicher');
    } catch (e) {
      AppLog.w('website-data', 'Website-Datenspeicher nicht gelöscht (${e.runtimeType})');
    }
  }
}
