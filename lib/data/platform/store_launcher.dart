import 'package:url_launcher/url_launcher.dart';

import '../../core/app_log.dart';
import '../../core/platform_info.dart';

/// Der öffentliche Store-Eintrag der App (#350, #351). Mehr als dieser Link verlässt die App dabei nie: keine
/// Familien-, Raum- oder Einladungsdaten.
class AppStoreListing {
  const AppStoreListing._();

  static const String androidPackage = 'de.inneso.familynexus';
  static final Uri playStore = Uri.https('play.google.com', '/store/apps/details', <String, String>{'id': androidPackage});

  /// Text zum Weitergeben: ein kurzer Satz und der Store-Link, sonst nichts.
  static String shareText(String intro) => '$intro\n$playStore';
}

/// Öffnet den Store-Eintrag zum Bewerten. Ohne zusätzliche Bibliothek: Der Link öffnet unter Android die Play-Store-App.
abstract class StoreLauncher {
  /// Bewerten gibt es nur dort, wo der Eintrag bekannt ist (Android).
  bool get canRate;

  /// `false`, wenn nichts den Link öffnen konnte (kein Play Store, kein Browser).
  Future<bool> openListing();
}

class SystemStoreLauncher implements StoreLauncher {
  const SystemStoreLauncher();

  @override
  bool get canRate => PlatformInfo.isAndroid;

  @override
  Future<bool> openListing() async {
    try {
      return await launchUrl(AppStoreListing.playStore, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLog.e('store', 'Store-Eintrag konnte nicht geöffnet werden', e);
      return false;
    }
  }
}
