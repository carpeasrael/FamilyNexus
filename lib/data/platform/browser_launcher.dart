import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_log.dart';
import 'web_auth_session.dart';

/// Ergebnis von [BrowserLauncher.openInApp]: [opened] = die Seite ist offen; [waited] schließt mit `true` ab,
/// wenn die Plattform das Ende der Seite meldet (iOS/macOS: Sitzung endet), sonst sofort mit `false`.
typedef InAppOpening = ({bool opened, Future<bool> waited});

/// Öffnet Seiten des Anbieters (Anmeldung, Kontoanlage, Bedingungen, Captcha, Kontoseiten; E-55, E-91):
/// mit `inApp` in der App (iOS/macOS: Anmeldesitzung des Systems, Android: Custom Tab des Standardbrowsers),
/// sonst bzw. als Rückfall extern im Standardbrowser. Nie in einer eingebetteten WebView.
///
/// Nur https-Adressen ohne Zugangsdaten; alles andere wird verweigert. Gibt `false` zurück, wenn sich keine
/// Seite öffnen ließ.
abstract class BrowserLauncher {
  /// Öffnet [uri] und kehrt nach dem Öffnen zurück (wartet nicht auf das Ende der Seite).
  Future<bool> open(Uri uri, {bool inApp = false});

  /// Öffnet [uri] in der App (Rückfall extern) und meldet, ob die Plattform das Ende der Seite kennt.
  Future<InAppOpening> openInApp(Uri uri);

  static bool isAllowed(Uri uri) => uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
}

/// Custom Tab des Standardbrowsers (Android, #268). `false`, wenn er keine Custom Tabs anbietet.
abstract class CustomTabLauncher {
  Future<bool> open(Uri uri);
}

/// Custom Tab über den Link-Kanal (`MainActivity.openCustomTab`); den Handler des Kanals setzt allein
/// `PlatformLinkSource`, hier wird nur gesendet.
class ChannelCustomTabLauncher implements CustomTabLauncher {
  const ChannelCustomTabLauncher();

  static const MethodChannel _channel = MethodChannel('de.inneso.familynexus/links');

  @override
  Future<bool> open(Uri uri) async {
    if (!BrowserLauncher.isAllowed(uri)) return false;
    try {
      return await _channel.invokeMethod<bool>('openCustomTab', <String, Object?>{'url': uri.toString()}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      AppLog.e('browser', 'Custom Tab konnte nicht geöffnet werden', e);
      return false;
    }
  }
}

/// Standard-Umsetzung. Ohne [webAuth] bzw. [customTab] öffnet sie immer extern; sie legt nie selbst einen
/// Kanal an (die Instanzen baut `buildInAppAuth`). [platform], [isWeb] und [launch] sind für Tests
/// austauschbar und werden erst beim Aufruf aufgelöst (`const`-fähig).
class SystemBrowserLauncher implements BrowserLauncher {
  const SystemBrowserLauncher({this.webAuth, this.customTab, this.platform, this.isWeb, this.launch});

  final WebAuthSession? webAuth;
  final CustomTabLauncher? customTab;
  final TargetPlatform? platform;
  final bool? isWeb;
  final Future<bool> Function(Uri uri)? launch;

  static Future<bool> _launchExternal(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<bool> _external(Uri uri) async {
    try {
      return await (launch ?? _launchExternal)(uri);
    } catch (e) {
      AppLog.e('browser', 'Browser konnte nicht geöffnet werden', e);
      return false;
    }
  }

  @override
  Future<bool> open(Uri uri, {bool inApp = false}) async {
    if (inApp) return (await openInApp(uri)).opened;
    if (!BrowserLauncher.isAllowed(uri)) return false;
    return _external(uri);
  }

  @override
  Future<InAppOpening> openInApp(Uri uri) async {
    if (!BrowserLauncher.isAllowed(uri)) return (opened: false, waited: Future<bool>.value(false));
    if (!(isWeb ?? kIsWeb)) {
      switch (platform ?? defaultTargetPlatform) {
        case TargetPlatform.iOS || TargetPlatform.macOS:
          final session = webAuth;
          if (session != null) {
            final started = await session.start(session.begin(), uri);
            if (started.started) return (opened: true, waited: started.result.then((_) => true));
            AppLog.w('browser', 'Anmeldesitzung nicht gestartet, öffne extern');
          }
        case TargetPlatform.android:
          final tab = customTab;
          if (tab != null) {
            if (await tab.open(uri)) return (opened: true, waited: Future<bool>.value(false));
            AppLog.w('browser', 'Kein Custom Tab, öffne extern');
          }
        case TargetPlatform.linux || TargetPlatform.windows || TargetPlatform.fuchsia:
          break;
      }
    }
    return (opened: await _external(uri), waited: Future<bool>.value(false));
  }
}
