import 'dart:io';

import 'package:family_nexus/data/platform/browser_launcher.dart';
import 'package:family_nexus/data/platform/in_app_auth.dart';
import 'package:family_nexus/data/platform/link_source.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Gerätetest Android (#268, E-91, TP-OAUTH-12): Anbieterseiten öffnen im Custom Tab des Standardbrowsers.
///
/// Voraussetzung: Chrome ist installiert **und Standardbrowser**
/// (`adb shell cmd role get-role-holders android.app.role.BROWSER` → `com.android.chrome`); sonst liefert
/// `CustomTabsClient.getPackageName` `null` und der erste Schritt schlägt (richtigerweise) fehl.
///
/// Start: `flutter test integration_test/custom_tab_device_test.dart -d <Emulator>`. Danach belegt der Tester per
/// `adb shell dumpsys activity activities`, dass `CustomTabActivity` im Task der App liegt und keine
/// `WebViewActivity` gestartet wurde; Rücksprung und Negativfälle laufen per `adb shell am start` (Testplan).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final page = Uri.parse('https://example.org/');

  testWidgets('Custom Tab direkt über den Kanal: true (kein externer Rückfall)', (tester) async {
    if (!Platform.isAndroid) return;
    expect(await const ChannelCustomTabLauncher().open(page), isTrue);
  });

  testWidgets('buildInAppAuth: Android-Ablauf, inApp öffnet die Seite', (tester) async {
    if (!Platform.isAndroid) return;
    final auth = buildInAppAuth(links: PlatformLinkSource());
    expect(auth.oauthRedirect, isA<AppLinkOAuthRedirect>());
    expect(await auth.browser.open(page, inApp: true), isTrue);
  });
}
