import 'package:url_launcher/url_launcher.dart';

import '../../core/app_log.dart';

/// Startet die Element-App als Ausweg, wenn ein Server die Kontoanlage in dieser App nicht erlaubt.
///
/// Gibt `false` zurück, wenn Element nicht installiert ist; die Oberfläche verweist dann auf [downloadPage].
abstract class ElementLauncher {
  Future<bool> open();

  static final Uri downloadPage = Uri.parse('https://element.io/download');
}

class SystemElementLauncher implements ElementLauncher {
  const SystemElementLauncher();

  @override
  Future<bool> open() async {
    try {
      // Nur die App, nie der Browser: Ist Element nicht installiert, soll der Hinweis erscheinen.
      return await launchUrl(Uri.parse('element://'), mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      AppLog.w('element', 'Element konnte nicht gestartet werden');
      return false;
    }
  }
}
