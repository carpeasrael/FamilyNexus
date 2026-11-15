import 'dart:io';

import 'package:family_nexus/data/platform/browser_launcher.dart';
import 'package:family_nexus/data/platform/embedded_auth.dart';
import 'package:family_nexus/data/platform/in_app_auth.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser.dart';
import '../support/fake_links.dart';

/// Ablauf je Plattform und Fabrik `buildInAppAuth` (#268, E-91; #441, E-102: iOS, macOS und Android zeigen die
/// Seite eingebettet, der alte Weg bleibt als Rückfall und Ausweg).
class _FakeTab implements CustomTabLauncher {
  _FakeTab(this.result);
  final bool result;
  int calls = 0;

  @override
  Future<bool> open(Uri uri) async {
    calls++;
    return result;
  }
}

void main() {
  final page = Uri.parse('https://anbieter.test/authorize');

  test('oauthFlowFor: Zuordnung je Plattform', () {
    // #441, E-102: eingebettete Ansicht statt Anmeldesitzung (iOS, macOS) und Custom Tab (Android).
    expect(oauthFlowFor(isWeb: false, platform: TargetPlatform.android), OAuthFlow.embedded);
    expect(oauthFlowFor(isWeb: false, platform: TargetPlatform.iOS), OAuthFlow.embedded);
    expect(oauthFlowFor(isWeb: false, platform: TargetPlatform.macOS), OAuthFlow.embedded);
    expect(oauthFlowFor(isWeb: false, platform: TargetPlatform.linux), OAuthFlow.loopback);
    expect(oauthFlowFor(isWeb: false, platform: TargetPlatform.windows), OAuthFlow.loopback);
    expect(oauthFlowFor(isWeb: false, platform: TargetPlatform.fuchsia), OAuthFlow.loopback);
    for (final p in TargetPlatform.values) {
      expect(oauthFlowFor(isWeb: true, platform: p), OAuthFlow.none, reason: 'Web $p');
    }
  });

  Future<EmbeddedHandle?> noPage(EmbeddedRequest r) async => null;

  for (final p in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android]) {
    test('${p.name}: mit Opener eingebettet, der alte Weg der Plattform bleibt Rückfall', () {
      final auth = buildInAppAuth(links: FakeLinkSource(), platform: p, isWeb: false, newSession: FakeWebAuthSession.new, embeddedOpener: noPage);
      expect(auth.browser, isA<EmbeddedBrowserLauncher>());
      expect(auth.oauthRedirect, isA<EmbeddedOAuthRedirect>());
    });
  }

  for (final p in <TargetPlatform>[TargetPlatform.linux, TargetPlatform.windows]) {
    test('${p.name}: ein übergebener Opener ändert nichts (externer Browser, Loopback)', () {
      final auth = buildInAppAuth(links: FakeLinkSource(), platform: p, isWeb: false, embeddedOpener: noPage);
      expect(auth.browser, isA<SystemBrowserLauncher>());
      expect(auth.oauthRedirect, isA<LoopbackOAuthRedirect>());
    });
  }

  test('Web: ein übergebener Opener ändert nichts (keine OAuth-Anmeldung)', () {
    final auth = buildInAppAuth(links: FakeLinkSource(), platform: TargetPlatform.iOS, isWeb: true, embeddedOpener: noPage);
    expect(auth.oauthRedirect, isNull);
    expect(auth.browser, isA<SystemBrowserLauncher>());
  });

  test('iOS/macOS mit Opener: Rückfall teilt genau eine Sitzung mit Launcher und Rücksprung', () async {
    var built = 0;
    final session = FakeWebAuthSession();
    final auth = buildInAppAuth(
      links: FakeLinkSource(),
      platform: TargetPlatform.iOS,
      isWeb: false,
      newSession: () {
        built++;
        return session;
      },
      embeddedOpener: noPage,
    );
    expect(built, 1);
    // Opener meldet „nicht verfügbar“: der Versuch öffnet dieselbe URL über die Sitzung (Rückfall zur Aufrufzeit).
    final attempt = await auth.oauthRedirect!.prepare();
    expect(await attempt.open(page), isTrue);
    expect(session.starts.single.uri, page);
    attempt.cancel();
  });

  test('Android mit Opener: Rückfall öffnet im Custom Tab', () async {
    final tab = _FakeTab(true);
    final auth = buildInAppAuth(links: FakeLinkSource(), platform: TargetPlatform.android, isWeb: false, customTab: tab, embeddedOpener: noPage);
    final attempt = await auth.oauthRedirect!.prepare();
    expect(await attempt.open(page), isTrue);
    expect(tab.calls, 1);
    attempt.cancel();
  });

  for (final p in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('${p.name} ohne Opener: genau eine Sitzung, die Launcher und Rücksprung teilen', () {
      var built = 0;
      final session = FakeWebAuthSession();
      final auth = buildInAppAuth(
        links: FakeLinkSource(),
        platform: p,
        isWeb: false,
        newSession: () {
          built++;
          return session;
        },
      );
      expect(built, 1);
      expect(auth.browser, isA<SystemBrowserLauncher>());
      expect(auth.oauthRedirect, isA<SessionOAuthRedirect>());
      expect((auth.browser as SystemBrowserLauncher).webAuth, same(session));
      expect((auth.oauthRedirect! as SessionOAuthRedirect).session, same(session));
    });
  }

  test('Android ohne Opener: AppLinkOAuthRedirect; Custom Tab true → kein launch, false → genau ein launch', () async {
    for (final (tabResult, launches) in <(bool, int)>[(true, 0), (false, 1)]) {
      final launched = <Uri>[];
      final tab = _FakeTab(tabResult);
      final auth = buildInAppAuth(
        links: FakeLinkSource(),
        platform: TargetPlatform.android,
        isWeb: false,
        customTab: tab,
        launch: (u) async {
          launched.add(u);
          return true;
        },
      );
      expect(auth.oauthRedirect, isA<AppLinkOAuthRedirect>());
      final attempt = await auth.oauthRedirect!.prepare();
      expect(await attempt.open(page), isTrue);
      expect(tab.calls, 1);
      expect(launched, hasLength(launches), reason: 'Custom Tab $tabResult');
      attempt.cancel();
    }
  });

  for (final p in <TargetPlatform>[TargetPlatform.linux, TargetPlatform.windows]) {
    test('${p.name}: LoopbackOAuthRedirect mit externem Launcher', () async {
      final launched = <Uri>[];
      final auth = buildInAppAuth(
        links: FakeLinkSource(),
        platform: p,
        isWeb: false,
        newSession: () => fail('keine Sitzung auf ${p.name}'),
        launch: (u) async {
          launched.add(u);
          return true;
        },
      );
      expect(auth.oauthRedirect, isA<LoopbackOAuthRedirect>());
      final b = auth.browser as SystemBrowserLauncher;
      expect(b.webAuth, isNull);
      expect(b.customTab, isNull);
      expect(await b.open(page, inApp: true), isTrue);
      expect(launched, <Uri>[page]);
    });
  }

  test('Web: keine OAuth-Anmeldung, externer Launcher', () {
    final auth = buildInAppAuth(links: FakeLinkSource(), platform: TargetPlatform.android, isWeb: true);
    expect(auth.oauthRedirect, isNull);
    final b = auth.browser as SystemBrowserLauncher;
    expect(b.webAuth, isNull);
    expect(b.customTab, isNull);
  });

  test('Quelltext: ChannelWebAuthSession( nur in in_app_auth.dart, buildInAppAuth( nur in bootstrap.dart', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    final session = <String>[];
    final factory = <String>[];
    for (final f in files) {
      final path = f.path.replaceAll(r'\', '/');
      final src = f.readAsStringSync();
      if (!path.endsWith('/web_auth_session.dart') && src.contains('ChannelWebAuthSession(')) session.add(path);
      if (!path.endsWith('/in_app_auth.dart') && src.contains('buildInAppAuth(')) factory.add(path);
    }
    expect(session, <String>['lib/data/platform/in_app_auth.dart']);
    expect(factory, <String>['lib/app/bootstrap.dart']);
  });
}
