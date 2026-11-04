import 'dart:io';

import 'package:family_nexus/data/platform/browser_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser.dart';

/// Wo Anbieterseiten öffnen (#268, E-91): in der App (iOS/macOS-Sitzung, Android-Custom-Tab), sonst bzw. als
/// Rückfall extern. Nie mit dem echten `launchUrl`.
class _FakeTab implements CustomTabLauncher {
  _FakeTab(this.result);
  final bool result;
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

void main() {
  final page = Uri.parse('https://anbieter.test/account?action=delete');
  late List<Uri> launched;
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }

  setUp(() => launched = <Uri>[]);

  for (final p in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.macOS]) {
    test('${p.name}: inApp startet die Sitzung (ohne Schema), kein launch; waited true nach dem Ende', () async {
      final session = FakeWebAuthSession();
      final b = SystemBrowserLauncher(webAuth: session, platform: p, isWeb: false, launch: launch);
      final r = await b.openInApp(page);
      expect(r.opened, isTrue);
      expect(session.starts.single.uri, page);
      expect(session.starts.single.scheme, isNull);
      expect(launched, isEmpty);
      var ended = false;
      r.waited.then((v) => ended = v).ignore();
      await pumpEventQueue();
      expect(ended, isFalse, reason: 'Sitzung noch offen');
      session.finish(null); // „Abbrechen“
      expect(await r.waited, isTrue);
      expect(await b.open(page, inApp: true), isTrue);
      expect(session.starts, hasLength(2));
      expect(launched, isEmpty);
    });

    test('${p.name}: Startfehler der Sitzung → genau ein launch (Rückfall extern), waited false', () async {
      final session = FakeWebAuthSession()..startResult = false;
      final b = SystemBrowserLauncher(webAuth: session, platform: p, isWeb: false, launch: launch);
      final r = await b.openInApp(page);
      expect(r.opened, isTrue);
      expect(launched, <Uri>[page]);
      expect(await r.waited, isFalse);
    });
  }

  test('Android: inApp öffnet den Custom Tab, kein launch; false → launch', () async {
    final tab = _FakeTab(true);
    final b = SystemBrowserLauncher(customTab: tab, platform: TargetPlatform.android, isWeb: false, launch: launch);
    final r = await b.openInApp(page);
    expect(r.opened, isTrue);
    expect(await r.waited, isFalse);
    expect(tab.opened, <Uri>[page]);
    expect(launched, isEmpty);

    final none = _FakeTab(false);
    final b2 = SystemBrowserLauncher(customTab: none, platform: TargetPlatform.android, isWeb: false, launch: launch);
    expect(await b2.open(page, inApp: true), isTrue);
    expect(none.opened, <Uri>[page]);
    expect(launched, <Uri>[page]);
  });

  test('Linux, Windows und Web: launch, waited false', () async {
    for (final (p, web) in <(TargetPlatform, bool)>[
      (TargetPlatform.linux, false),
      (TargetPlatform.windows, false),
      (TargetPlatform.android, true),
    ]) {
      launched.clear();
      final session = FakeWebAuthSession();
      final tab = _FakeTab(true);
      final b = SystemBrowserLauncher(webAuth: session, customTab: tab, platform: p, isWeb: web, launch: launch);
      final r = await b.openInApp(page);
      expect(r.opened, isTrue);
      expect(await r.waited, isFalse);
      expect(launched, <Uri>[page], reason: '$p web=$web');
      expect(session.starts, isEmpty);
      expect(tab.opened, isEmpty);
    }
  });

  test('ohne Sitzung bzw. Custom-Tab-Kanal immer launch (iOS, macOS, Android)', () async {
    for (final p in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android]) {
      launched.clear();
      final b = SystemBrowserLauncher(platform: p, isWeb: false, launch: launch);
      expect(await b.open(page, inApp: true), isTrue, reason: '$p');
      expect(launched, <Uri>[page], reason: '$p');
    }
  });

  test('open ohne inApp öffnet extern, auch wenn Sitzung und Custom Tab vorhanden sind', () async {
    final session = FakeWebAuthSession();
    final tab = _FakeTab(true);
    for (final p in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
      launched.clear();
      final b = SystemBrowserLauncher(webAuth: session, customTab: tab, platform: p, isWeb: false, launch: launch);
      expect(await b.open(page), isTrue);
      expect(launched, <Uri>[page]);
    }
    expect(session.starts, isEmpty);
    expect(tab.opened, isEmpty);
  });

  test('const SystemBrowserLauncher() ist ein const-Ausdruck (Standard in AppServices)', () {
    const b = SystemBrowserLauncher();
    expect(b.webAuth, isNull);
    expect(b.customTab, isNull);
  });

  test('Nicht-https → false ohne Aufruf', () async {
    final session = FakeWebAuthSession();
    final tab = _FakeTab(true);
    for (final p in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.linux]) {
      final b = SystemBrowserLauncher(webAuth: session, customTab: tab, platform: p, isWeb: false, launch: launch);
      for (final bad in <String>['http://anbieter.test/', 'javascript:alert(1)', 'https://u:p@anbieter.test/']) {
        expect(await b.open(Uri.parse(bad)), isFalse);
        expect(await b.open(Uri.parse(bad), inApp: true), isFalse);
        expect((await b.openInApp(Uri.parse(bad))).opened, isFalse);
      }
    }
    expect(launched, isEmpty);
    expect(session.starts, isEmpty);
    expect(tab.opened, isEmpty);
  });

  test('Quelltext ohne eingebettete WebView (inAppBrowserView/inAppWebView)', () {
    final src = File('lib/data/platform/browser_launcher.dart').readAsStringSync();
    expect(src, isNot(contains('inAppBrowserView')));
    expect(src, isNot(contains('inAppWebView')));
  });
}
