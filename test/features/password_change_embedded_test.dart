import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/embedded_opener.dart';
import 'package:family_nexus/data/platform/embedded_auth.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/fake_browser.dart';
import '../support/fake_matrix.dart';
import '../support/fake_webview_platform.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

/// #483: „Passwort ändern“ bei Anmeldung beim Anbieter öffnet die Kontoseite in der App. Der Dialog darf die
/// Seite nicht entfernen (sie liegt auf demselben Navigator), sondern schließt sich erst danach über seine
/// eigene Route.
void main() {
  late FakeBrowser ext;
  late TestApp app;
  late GlobalKey<NavigatorState> key;

  final tile = find.widgetWithText(ListTile, 'Passwort ändern');
  final page = find.byKey(const Key('cancel'));
  final dialog = find.byType(AlertDialog, skipOffstage: false);

  Future<void> boot(
    WidgetTester tester, {
    bool webView = true,
    bool lockEnabled = false,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    key = GlobalKey<NavigatorState>();
    ext = FakeBrowser();
    final fake = FakeMatrixServer()..registrationMode = RegistrationMode.oauth;
    fake.addAccount('anna', 'oauth-only', displayName: 'Anna');
    app = await buildTestApp(
      server: fake,
      loggedIn: false,
      lockEnabled: lockEnabled,
      navigatorKey: key,
      browserLauncher: EmbeddedBrowserLauncher(
        embeddedOpenerFor(key, platformAvailable: () => webView),
        ext,
      ),
    );
    WebViewPlatform.instance = FakePlatform();
    {
      await app.gateway.startOAuth(
        server: ServerUrl.tryParse(fake.host)!,
        redirectUri: FakeOAuthRedirect.redirect,
        create: false,
      );
      await app.gateway.completeOAuth(app.gateway.oauthCallback('anna'));
      await app.gateway.setUpSecurity();
      await app.gateway.createFamily('Familie Test');
      await app.services.settings.update(
        (s) => s.copyWith(onboardingDone: true),
      );
    }
    if (lockEnabled) await app.services.lock.unlock('x');
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
  }

  /// Öffnet den Dialog und tippt „Kontoseite öffnen“.
  Future<void> openPage(WidgetTester tester) async {
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kontoseite öffnen'));
    await tester.pumpAndSettle();
  }

  /// Weder Seite noch Dialog sind übrig; auf dem Navigator liegt nur noch die Einstellungsseite über dem Start.
  void expectNothingOpen() {
    expect(page, findsNothing);
    expect(dialog, findsNothing);
    expect(tile, findsOneWidget);
    final nav = key.currentState!;
    expect(
      nav.canPop(),
      isTrue,
      reason: 'Einstellungen liegen noch auf dem Start',
    );
    nav.pop();
    expect(nav.canPop(), isFalse, reason: 'keine weitere Route übrig');
  }

  testWidgets(
    'A: Seite bleibt offen, Dialog darunter; nach Abbrechen sind beide weg',
    (tester) async {
      await boot(tester);
      await openPage(tester);
      expect(page, findsOneWidget, reason: 'eingebettete Seite offen');
      expect(dialog, findsOneWidget, reason: 'Dialog liegt darunter');
      await tester.tap(page);
      await tester.pumpAndSettle();
      expectNothingOpen();
    },
  );

  testWidgets('B: Zurück-Geste schließt erst die Seite, dann den Dialog', (
    tester,
  ) async {
    await boot(tester);
    await openPage(tester);
    expect(await key.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expectNothingOpen();
  });

  testWidgets(
    'C: Sitzung wartet (iOS/macOS) und eingebettete Seite: Dialog bleibt bis zum Seitenende',
    (tester) async {
      await boot(tester);
      ext.sessionWaits = true;
      await openPage(tester);
      expect(page, findsOneWidget);
      expect(dialog, findsOneWidget);
      await tester.tap(page);
      await tester.pumpAndSettle();
      expect(page, findsNothing);
      expectNothingOpen();
    },
  );

  testWidgets(
    'D: Ausweg „Im Browser fortsetzen“ (Android): Seite und Dialog weg, keine Route übrig',
    (tester) async {
      await boot(tester);
      await openPage(tester);
      final nav = FakePlatform.last!.nav!;
      nav.onResErr!(
        const WebResourceError(
          errorCode: -2,
          description: 'offline',
          isForMainFrame: true,
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('external')), findsOneWidget);
      ext.sessionWaits = false;
      // Das Löschen beim Schließen hängt: Die Seite bleibt deterministisch oben, während der Dialog weiterläuft (Android:
      // `waited` ist sofort `false`). Ein blindes `pop()` entfernte hier die Seite statt des Dialogs.
      final gate = FakePlatform.last!.clearGate = Completer<void>();
      await tester.tap(find.byKey(const Key('external')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(ext.opened.length, 1, reason: 'Seite extern fortgesetzt');
      expect(page, findsOneWidget, reason: 'die Seite liegt noch oben');
      expect(dialog, findsNothing, reason: 'der Dialog ist über seine eigene Route weg');
      gate.complete();
      await tester.pumpAndSettle();
      expectNothingOpen();
    },
  );

  testWidgets(
    'E: Rückfall ohne WebView, Sitzung wartet: Dialog bleibt bis finishSession()',
    (tester) async {
      await boot(tester, webView: false);
      ext.sessionWaits = true;
      await openPage(tester);
      expect(page, findsNothing);
      expect(ext.sessionOpen, isTrue);
      expect(dialog, findsOneWidget);
      ext.finishSession();
      await tester.pumpAndSettle();
      expectNothingOpen();
    },
  );

  testWidgets(
    'F: Sperre schließt die Seite, danach den Dialog (Sperre bleibt aktiv)',
    (tester) async {
      await boot(tester, lockEnabled: true);
      await openPage(tester);
      expect(page, findsOneWidget);
      app.auth.succeed =
          false; // Die Sperre bleibt zu, bis der Test sie öffnet.
      app.services.lock.lockNow();
      await tester.pumpAndSettle();
      expect(app.services.lock.locked, isTrue, reason: 'Sperre blieb aktiv');
      expect(page, findsNothing);
      expect(dialog, findsNothing);
      await app.services.lock.unlock('x');
      await tester.pumpAndSettle();
      expectNothingOpen();
    },
  );

  testWidgets('G: Seite nicht zu öffnen: Hinweis, Dialog bleibt', (
    tester,
  ) async {
    // Ohne WebView-Plattform greift der Rückfall; der meldet „nicht geöffnet“.
    await boot(tester, webView: false);
    ext.available = false;
    await openPage(tester);
    expect(
      find.text('Die Seite des Anbieters konnte nicht geöffnet werden.'),
      findsOneWidget,
    );
    expect(dialog, findsOneWidget);
    expect(page, findsNothing);
  });
}
