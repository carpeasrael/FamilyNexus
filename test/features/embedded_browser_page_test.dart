import 'dart:async';
import 'dart:io';

import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/app/embedded_opener.dart';
import 'package:family_nexus/data/platform/embedded_auth.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../support/fake_webview_platform.dart';
import '../support/test_app.dart';

void main() {
  late TestApp app;
  late GlobalKey<NavigatorState> key;
  final page = Uri.parse('https://anbieter.test/authorize');
  final redirect = Uri.parse('io.github.carpeasrael.familynexus:/oauth');

  Future<(EmbeddedRequest, EmbeddedHandle)> open(WidgetTester tester,
      {Future<bool> Function()? ext, EmbeddedKind kind = EmbeddedKind.signIn}) async {
    final req = EmbeddedRequest(
      url: page,
      redirectUri: redirect,
      kind: kind,
      cancel: Completer<void>(),
      continueExternally: ext ?? () async => true,
    );
    final handle = await embeddedOpenerFor(key)(req);
    await tester.pumpAndSettle();
    return (req, handle!);
  }

  Widget host(Widget home) => AppScope(
        services: app.services,
        child: MaterialApp(
          navigatorKey: key,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  Future<void> boot(WidgetTester tester) async {
    key = GlobalKey<NavigatorState>();
    app = (await tester.runAsync(() => buildTestApp(loggedIn: false, lockEnabled: true)))!;
    WebViewPlatform.instance = FakePlatform();
    // Die Sperre ist mit lockEnabled zunächst zu; die Seite schließt bei gesperrter App sofort (#441).
    await app.services.lock.unlock('x');
    await tester.pumpWidget(host(const Scaffold(body: Text('home'))));
  }

  EmbeddedResult? track(EmbeddedHandle h, void Function(EmbeddedResult) set) {
    unawaited(h.result.then(set));
    return null;
  }

  NavigationRequest nr(String url, {bool main = true}) => NavigationRequest(url: url, isMainFrame: main);
  HttpResponseError http(int status, {String? req}) => HttpResponseError(
        request: req == null ? null : WebResourceRequest(uri: Uri.parse(req)),
        response: WebResourceResponse(uri: null, statusCode: status),
      );

  testWidgets('Opener kehrt nach dem Push zurück (Route aktiv, Ergebnis offen); Einstellungen, Löschen vor/nach, Permission deny', (tester) async {
    await boot(tester);
    final (req, handle) = await open(tester);
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    expect(find.byKey(const Key('cancel')), findsOneWidget);
    expect(res, isNull);
    final c = FakePlatform.last!;
    expect(c.calls, containsAllInOrder(<String>['js:unrestricted', 'zoom:false', 'clearCookies', 'clearCache', 'clearLocalStorage', 'load:$page']));
    final p = FakePermissionRequest();
    c.perm!(p);
    expect(p.denies, 1);
    expect(p.grants, 0);
    await tester.tap(find.byKey(const Key('cancel')));
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());
    expect(find.byKey(const Key('cancel')), findsNothing, reason: 'Route gezielt entfernt');
    expect(find.text('home'), findsOneWidget);
    expect(c.calls.where((e) => e == 'clearCache').length, 2, reason: 'vor dem Laden und beim Schließen');
    expect(c.calls.where((e) => e == 'channel' || e == 'runJS'), isEmpty);
    expect(req.cancel.isCompleted, isFalse);
  });

  testWidgets('Beschriftung: Anmeldung Abbrechen, Kontoseite Fertig', (tester) async {
    await boot(tester);
    await open(tester, kind: EmbeddedKind.page);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Rücksprung wird abgefangen und nicht ausgeführt; fremder Pfad/http blockiert', (tester) async {
    await boot(tester);
    final (_, handle) = await open(tester);
    final nav = FakePlatform.last!.nav!;
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    expect(await nav.onNav!(nr('io.github.carpeasrael.familynexus:/evil')), NavigationDecision.prevent);
    expect(await nav.onNav!(nr('http://x.test/')), NavigationDecision.prevent);
    expect(await nav.onNav!(nr('https://anbieter.test/a')), NavigationDecision.navigate);
    expect(res, isNull);
    expect(await nav.onNav!(nr('io.github.carpeasrael.familynexus:/oauth?code=1&state=s')), NavigationDecision.prevent);
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCallback>());
    expect((res! as EmbeddedCallback).uri.queryParameters['state'], 's');
  });

  testWidgets('Schleifenregel: 4. blockiert + Banner mit WebView; Neu laden setzt zurück', (tester) async {
    await boot(tester);
    await open(tester);
    final c = FakePlatform.last!;
    final nav = c.nav!;
    final r = <NavigationDecision>[];
    for (var i = 0; i < 4; i++) {
      r.add(await nav.onNav!(nr('https://anbieter.test/loop#$i')));
    }
    await tester.pump();
    expect(r, <NavigationDecision>[...List.filled(3, NavigationDecision.navigate), NavigationDecision.prevent]);
    expect(find.byKey(const Key('banner')), findsOneWidget);
    expect(find.byKey(const Key('webview')), findsOneWidget, reason: 'Banner ersetzt die WebView nicht');
    // `block` zählt nicht: weiter blockiert, bis Neu laden.
    expect(await nav.onNav!(nr('https://anbieter.test/loop')), NavigationDecision.prevent);
    await tester.tap(find.byKey(const Key('reload')));
    await tester.pump();
    // „Neu laden“ lädt die zuletzt bekannte Hauptseite per loadRequest (nicht controller.reload()).
    expect(c.calls, isNot(contains('reload')));
    expect(c.calls.where((e) => e == 'load:https://anbieter.test/loop#2').length, 1);
    expect(find.byKey(const Key('banner')), findsNothing);
    expect(await nav.onNav!(nr('https://anbieter.test/loop')), NavigationDecision.navigate);
  });

  testWidgets('Banner: iOS-403 (request == null) zeigt Banner mit Ausweg, WebView bleibt', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    nav.onHttp!(http(403));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsOneWidget);
    expect(find.byKey(const Key('external')), findsOneWidget);
    expect(find.byKey(const Key('reload')), findsOneWidget);
    expect(find.byKey(const Key('banner-cancel')), findsOneWidget);
    expect(find.byKey(const Key('webview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('banner-dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsNothing);
    nav.onHttp!(http(200));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsNothing, reason: 'Status < 400 kein Banner');
  });

  testWidgets('Banner Android: Favicon-404 still; Hauptseite (aus onPageStarted, auch ohne Fragment) zeigt Banner', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    nav.onStarted!('https://anbieter.test/main#frag');
    nav.onHttp!(http(404, req: 'https://anbieter.test/favicon.ico'));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsNothing);
    nav.onHttp!(http(404, req: 'https://anbieter.test/main'));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });

  testWidgets('Android: Hauptseiten-URL aus erlaubter Hauptframe-Navigation (vor onPageStarted)', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    await nav.onNav!(nr('https://anbieter.test/next'));
    nav.onHttp!(http(500, req: 'https://anbieter.test/next'));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });

  testWidgets('Kein Banner: -999, eigene Blockade (auch mit anderem Fehlercode), Unterframe-Fehler', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    nav.onResErr!(const WebResourceError(errorCode: -999, description: 'cancelled', isForMainFrame: true));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsNothing);
    expect(await nav.onNav!(nr('http://x.test/')), NavigationDecision.prevent);
    await tester.pump();
    expect(find.text('This link was not opened.'), findsOneWidget, reason: 'kurzer Hinweis statt Fehler-Banner');
    nav.onResErr!(const WebResourceError(errorCode: 102, description: 'interrupted', isForMainFrame: true));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsNothing, reason: 'eigene Blockade');
    expect(find.byKey(const Key('webview')), findsOneWidget);
    nav.onResErr!(const WebResourceError(errorCode: 1, description: 'x', isForMainFrame: false));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsNothing);
    // Nach neuer Seite zählt ein echter Fehler wieder.
    nav.onStarted!('https://anbieter.test/ok');
    nav.onResErr!(const WebResourceError(errorCode: -2, description: 'offline', isForMainFrame: true));
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });

  testWidgets('Ausweg: false lässt Seite offen (mit Hinweis), Wiederholung true schließt mit continueExternally', (tester) async {
    await boot(tester);
    var ok = false;
    var calls = 0;
    final (_, handle) = await open(tester, ext: () async {
      calls++;
      return ok;
    });
    final nav = FakePlatform.last!.nav!;
    nav.onResErr!(const WebResourceError(errorCode: -2, description: 'x', isForMainFrame: true));
    await tester.pump();
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    await tester.tap(find.byKey(const Key('external')));
    await tester.pumpAndSettle();
    expect(res, isNull);
    expect(find.byKey(const Key('open-failed')), findsOneWidget);
    ok = true;
    await tester.tap(find.byKey(const Key('external')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(res, isA<EmbeddedContinueExternally>());
  });

  testWidgets('Sperre schliesst die Seite; Abbruchsignal ebenso', (tester) async {
    await boot(tester);
    final (_, handle) = await open(tester);
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    app.services.lock.lockNow();
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());
  });

  testWidgets('Abbruchsignal schliesst Seite', (tester) async {
    await boot(tester);
    final (req, handle) = await open(tester);
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    req.cancel.complete();
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());
    expect(find.byKey(const Key('cancel')), findsNothing);
  });

  testWidgets('dispose ohne _finish (Navigator ersetzt): Ergebnis cancelled, Daten gelöscht, keine Ausnahme', (tester) async {
    await boot(tester);
    final (_, handle) = await open(tester);
    final c = FakePlatform.last!;
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    // Ganzer Baum wird ersetzt (wie ObjectKey(services) nach „Konto löschen“).
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());
    expect(c.calls.where((e) => e == 'clearCache').length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opener ohne Navigator: null (Rückfall)', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const SizedBox());
    final req = EmbeddedRequest(url: page, kind: EmbeddedKind.page, cancel: Completer<void>(), continueExternally: () async => true);
    expect(await embeddedOpenerFor(key)(req), isNull);
  });

  testWidgets('Host-Anzeige und neutraler Hinweis bei fremdem Host', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    nav.onUrl!(const UrlChange(url: 'https://anbieter.test/login'));
    await tester.pump();
    expect(find.text('anbieter.test/login'), findsOneWidget);
    expect(find.byKey(const Key('foreign')), findsNothing);
    nav.onUrl!(const UrlChange(url: 'https://accounts.google.com/signin'));
    await tester.pump();
    expect(find.byKey(const Key('foreign')), findsOneWidget);
    expect(find.textContaining('accounts.google.com'), findsWidgets);
  });

  testWidgets('Unterframe-Blockade zeigt keinen Hinweis; Seite und Banner bleiben unberührt', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    expect(await nav.onNav!(nr('http://x.test/', main: false)), NavigationDecision.prevent);
    await tester.pump();
    expect(find.text('This link was not opened.'), findsNothing);
    expect(find.byKey(const Key('banner')), findsNothing);
  });

  testWidgets('Zurück: erst eine Seite zurück (goBack), sonst Abbruch (cancelled)', (tester) async {
    await boot(tester);
    final (_, handle) = await open(tester);
    final c = FakePlatform.last!;
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    c.back = true;
    await key.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(c.calls.where((e) => e == 'goBack').length, 1);
    expect(res, isNull, reason: 'solange es eine Seite zurück gibt, bleibt die Ansicht offen');
    expect(find.byKey(const Key('cancel')), findsOneWidget);
    c.back = false;
    await key.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(c.calls.where((e) => e == 'goBack').length, 1);
    expect(res, isA<EmbeddedCancelled>());
    expect(find.byKey(const Key('cancel')), findsNothing);
  });

  testWidgets('Sperre schon beim Öffnen wahr: Seite schließt sofort (cancelled), nichts wird geladen', (tester) async {
    await boot(tester);
    app.services.lock.lockNow();
    expect(app.services.lock.locked, isTrue);
    final (_, handle) = await open(tester);
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());
    expect(FakePlatform.last!.calls.where((e) => e.startsWith('load:')), isEmpty);
    expect(find.byKey(const Key('cancel')), findsNothing);
  });

  /// Jeder Schließweg löscht Cookies, Cache und Speicher, und zwar **bevor** das Ergebnis die Route entfernt
  /// (solange der Controller lebt).
  group('Schließwege löschen vor dem Ergebnis', () {
    final paths = <String, Future<void> Function(WidgetTester t, EmbeddedRequest req, FakeCtl c)>{
      'Abbrechen': (t, req, c) async => t.tap(find.byKey(const Key('cancel'))),
      'Abbrechen im Banner': (t, req, c) async {
        c.nav!.onHttp!(http(403));
        await t.pump();
        await t.tap(find.byKey(const Key('banner-cancel')));
      },
      'Zurück': (t, req, c) async => key.currentState!.maybePop(),
      'Sperre': (t, req, c) async => app.services.lock.lockNow(),
      'Zeitablauf/Abbruchsignal': (t, req, c) async => req.cancel.complete(),
      'Ausweg': (t, req, c) async {
        c.nav!.onResErr!(const WebResourceError(errorCode: -2, description: 'x', isForMainFrame: true));
        await t.pump();
        await t.tap(find.byKey(const Key('external')));
      },
      'Rücksprung': (t, req, c) async {
        await c.nav!.onNav!(nr('io.github.carpeasrael.familynexus:/oauth?code=1&state=s'));
      },
    };
    for (final e in paths.entries) {
      testWidgets(e.key, (tester) async {
        await boot(tester);
        final (req, handle) = await open(tester);
        final c = FakePlatform.last!;
        List<String>? atResult;
        unawaited(handle.result.then((_) => atResult = List<String>.of(c.calls)));
        await e.value(tester, req, c);
        await tester.pumpAndSettle();
        expect(atResult, isNotNull, reason: 'Ergebnis geliefert');
        for (final clear in <String>['clearCookies', 'clearCache', 'clearLocalStorage']) {
          expect(atResult!.where((x) => x == clear).length, 2, reason: '${e.key}: $clear vor dem Laden und vor dem Ergebnis');
        }
        expect(find.byKey(const Key('cancel')), findsNothing, reason: 'Route entfernt');
      });
    }
  });

  testWidgets('Ladebalken nur bei laufendem Laden (0 < Fortschritt < 100)', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    expect(find.byType(LinearProgressIndicator), findsNothing);
    nav.onProg!(40);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    nav.onProg!(100);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Host-Zeile erst nach übernommener Adresse; blockierte Adresse ändert die Anzeige nicht', (tester) async {
    await boot(tester);
    await open(tester);
    final nav = FakePlatform.last!.nav!;
    expect(find.byKey(const Key('host')), findsNothing);
    nav.onUrl!(const UrlChange(url: 'https://anbieter.test/login'));
    await tester.pump();
    await nav.onNav!(nr('http://boese.test/'));
    await nav.onNav!(nr('https://ausstehend.test/x'));
    await tester.pump();
    expect(find.text('anbieter.test/login'), findsOneWidget);
    expect(find.textContaining('boese.test'), findsNothing);
    expect(find.textContaining('ausstehend.test'), findsNothing);
  });

  testWidgets('Opener: ohne WebView-Plattform null (Rückfall), ohne Aufbau der Seite', (tester) async {
    await boot(tester);
    final req = EmbeddedRequest(url: page, kind: EmbeddedKind.page, cancel: Completer<void>(), continueExternally: () async => true);
    expect(await embeddedOpenerFor(key, platformAvailable: () => false)(req), isNull);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel')), findsNothing);
  });

  test('Navigator-Schlüssel je AppServices-Instanz verschieden (nie statisch)', () async {
    final a = await buildTestApp(loggedIn: false);
    final b = await buildTestApp(loggedIn: false);
    expect(identical(a.services.navigatorKey, b.services.navigatorKey), isFalse);
  });

  test('Quelltext der Seite: keine JavaScript-Kanäle, kein runJavaScript, keine SSL-/HTTP-Auth-Ausnahmen', () {
    final src = File('lib/features/onboarding/embedded_browser_page.dart').readAsStringSync();
    for (final forbidden in <String>[
      'addJavaScriptChannel',
      'runJavaScript',
      'runJavaScriptReturningResult',
      'onSslAuthError',
      'onHttpAuthRequest',
    ]) {
      expect(src, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(src, contains('onPermissionRequest: (r) => r.deny()'));
    expect(src, contains('JavaScriptMode.unrestricted'));
    expect(src, contains('enableZoom(false)'));
  });

  testWidgets('Löschen hängt: Ergebnis kommt nach der Frist trotzdem; Löschen scheitert: Schließen klappt', (tester) async {
    await boot(tester);
    var (_, handle) = await open(tester);
    var c = FakePlatform.last!;
    c.clearGate = Completer<void>();
    EmbeddedResult? res;
    track(handle, (r) => res = r);
    await tester.tap(find.byKey(const Key('cancel')));
    await tester.pump(const Duration(seconds: 1));
    expect(res, isNull, reason: 'wartet auf das Löschen, höchstens kClearTimeout');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());

    (_, handle) = await open(tester);
    c = FakePlatform.last!;
    c.clearThrows = true;
    res = null;
    track(handle, (r) => res = r);
    await tester.tap(find.byKey(const Key('cancel')));
    await tester.pumpAndSettle();
    expect(res, isA<EmbeddedCancelled>());
    expect(tester.takeException(), isNull);
  });
}
