import 'package:url_launcher/url_launcher.dart';

import '../../core/app_log.dart';

/// Öffnet Seiten des Anbieters im Browser (Anmeldung, Bedingungen, Captcha; E-55).
///
/// Nur https-Adressen ohne Zugangsdaten; alles andere wird verweigert. Gibt `false` zurück, wenn kein
/// Browser antwortet.
abstract class BrowserLauncher {
  Future<bool> open(Uri uri);

  static bool isAllowed(Uri uri) => uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
}

class SystemBrowserLauncher implements BrowserLauncher {
  const SystemBrowserLauncher();

  @override
  Future<bool> open(Uri uri) async {
    if (!BrowserLauncher.isAllowed(uri)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLog.e('browser', 'Browser konnte nicht geöffnet werden', e);
      return false;
    }
  }
}
