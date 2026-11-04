import 'dart:async';
import 'dart:io';

import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser.dart';
import '../support/fake_links.dart';

DateTime _in(int seconds) => DateTime.now().add(Duration(seconds: seconds));

void main() {
  test('TP-OAUTH-06 Desktop: Rücksprung über 127.0.0.1 mit zufälligem Port, nur GET /oauth, danach geschlossen', () async {
    final r = LoopbackOAuthRedirect(FakeBrowser());
    final attempt = await r.prepare();
    final target = attempt.redirectUri;
    expect(target.scheme, 'http');
    expect(target.host, '127.0.0.1');
    expect(target.path, '/oauth');
    expect(target.port, greaterThan(0));

    final client = HttpClient();
    final wrong = await (await client.getUrl(target.replace(path: '/evil'))).close();
    expect(wrong.statusCode, 404, reason: 'falscher Pfad wird abgewiesen');
    final res = await (await client.getUrl(target.replace(query: 'code=abc&state=xyz'))).close();
    expect(res.statusCode, 200);
    expect(res.headers.value('cache-control'), 'no-store');
    final page = await res.transform(const SystemEncoding().decoder).join();
    expect(page, isNot(contains('abc')), reason: 'Code erscheint nicht in der Seite');
    final cb = await attempt.next(deadline: _in(5));
    expect(cb!.queryParameters, <String, String>{'code': 'abc', 'state': 'xyz'});

    // Ein zweiter (z. B. fremder) Rücksprung wird ebenfalls zugestellt; das Gateway entscheidet per state.
    await (await client.getUrl(target.replace(query: 'code=2&state=fremd'))).close();
    expect((await attempt.next(deadline: _in(5)))!.queryParameters['state'], 'fremd');

    attempt.cancel();
    client.close(force: true);
    final fresh = HttpClient();
    await expectLater(
      fresh.getUrl(target).then((q) => q.close()),
      throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
      reason: 'Empfänger ist nach dem Versuch zu',
    );
    fresh.close(force: true);
  });

  test('Abbrechen beendet das Warten ohne Ergebnis', () async {
    final r = LoopbackOAuthRedirect(FakeBrowser());
    final attempt = await r.prepare();
    final waiting = attempt.next(deadline: _in(5));
    r.cancel();
    expect(await waiting, isNull);
  });

  test('Mobil: nur Links im App-Schema mit Pfad /oauth zählen', () async {
    final links = FakeLinkSource();
    final attempt = await AppLinkOAuthRedirect(links, FakeBrowser()).prepare();
    expect(attempt.redirectUri.toString(), 'io.github.carpeasrael.familynexus:/oauth');
    final waiting = attempt.next(deadline: _in(5));
    links.controller.add('familynexus://join?v=2');
    links.controller.add('io.github.carpeasrael.familynexus:/oauth?code=1&state=2');
    expect((await waiting)!.queryParameters['code'], '1');
    expect(AppLinkOAuthRedirect.isCallback('familynexus://join?x'), isFalse);
  });

  test('R2: ein neuer Versuch beendet den alten, der alte stört den neuen nicht', () async {
    final links = FakeLinkSource();
    final r = AppLinkOAuthRedirect(links, FakeBrowser());
    final a = await r.prepare();
    final aWaiting = a.next(deadline: _in(5));
    final b = await r.prepare();
    expect(await aWaiting, isNull, reason: 'alter Versuch endet');
    a.cancel(); // wie das finally des alten Vorgangs
    final bWaiting = b.next(deadline: _in(5));
    links.controller.add('io.github.carpeasrael.familynexus:/oauth?code=neu&state=b');
    expect((await bWaiting)!.queryParameters['code'], 'neu');
  });

  test('Zeitüberschreitung liefert null', () async {
    final attempt = await AppLinkOAuthRedirect(FakeLinkSource(), FakeBrowser()).prepare();
    expect(await attempt.next(deadline: DateTime.now().add(const Duration(milliseconds: 50))), isNull);
  });

  group('Öffnen der Anbieterseite je Art (#268, E-91)', () {
    final page = Uri.parse('https://anbieter.test/authorize?x=1');

    test('Loopback öffnet extern (inApp false), AppLink in der App (inApp true)', () async {
      final b1 = FakeBrowser();
      final loop = LoopbackOAuthRedirect(b1);
      final a1 = await loop.prepare();
      expect(await a1.open(page), isTrue);
      expect(b1.opened, <Uri>[page]);
      expect(b1.inApp, <bool>[false]);
      a1.cancel();

      final b2 = FakeBrowser();
      final a2 = await AppLinkOAuthRedirect(FakeLinkSource(), b2).prepare();
      expect(await a2.open(page), isTrue);
      expect(b2.opened, <Uri>[page]);
      expect(b2.inApp, <bool>[true]);
      a2.cancel();
    });

    test('open() nach cancel() öffnet nichts und liefert false (Loopback und AppLink)', () async {
      final b1 = FakeBrowser();
      final loop = LoopbackOAuthRedirect(b1);
      final a1 = await loop.prepare();
      loop.cancel();
      expect(await a1.open(page), isFalse);
      expect(b1.opened, isEmpty);

      final b2 = FakeBrowser();
      final app = AppLinkOAuthRedirect(FakeLinkSource(), b2);
      final a2 = await app.prepare();
      a2.cancel();
      expect(await a2.open(page), isFalse);
      expect(b2.opened, isEmpty);
    });
  });

  group('SessionOAuthRedirect (iOS/macOS, #268, E-91)', () {
    final page = Uri.parse('https://anbieter.test/authorize?x=1');
    final ok = Uri.parse('io.github.carpeasrael.familynexus:/oauth?code=1&state=s');

    test('Rücksprung, während next() bereits wartet → URI; Sitzung mit App-Schema gestartet', () async {
      final session = FakeWebAuthSession();
      final attempt = await SessionOAuthRedirect(session).prepare();
      expect(attempt.redirectUri.toString(), 'io.github.carpeasrael.familynexus:/oauth');
      expect(await attempt.open(page), isTrue);
      expect(session.starts.single.uri, page);
      expect(session.starts.single.scheme, 'io.github.carpeasrael.familynexus');
      final waiting = attempt.next(deadline: _in(5));
      session.finish(ok);
      expect(await waiting, ok);
    });

    test('Ende vor next(): erst die URI, danach sofort null (geschlossen)', () async {
      final session = FakeWebAuthSession();
      final attempt = await SessionOAuthRedirect(session).prepare();
      await attempt.open(page);
      session.finish(ok);
      await pumpEventQueue();
      expect(await attempt.next(deadline: _in(5)), ok);
      final sw = Stopwatch()..start();
      expect(await attempt.next(deadline: _in(5)), isNull, reason: 'eine Sitzung liefert höchstens eine Antwort');
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('cancel() nach eingetroffenem Rücksprung verwirft ihn', () async {
      final session = FakeWebAuthSession();
      final attempt = await SessionOAuthRedirect(session).prepare();
      await attempt.open(page);
      session.finish(ok);
      await pumpEventQueue();
      attempt.cancel();
      expect(await attempt.next(deadline: _in(5)), isNull);
    });

    test('Abbruch der Sitzung (null) → sofort null', () async {
      final session = FakeWebAuthSession();
      final attempt = await SessionOAuthRedirect(session).prepare();
      await attempt.open(page);
      final waiting = attempt.next(deadline: _in(5));
      final sw = Stopwatch()..start();
      session.finish(null);
      expect(await waiting, isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('Startfehler → open() false und next() sofort null, kein Rückfall extern', () async {
      final session = FakeWebAuthSession()..startResult = false;
      final attempt = await SessionOAuthRedirect(session).prepare();
      expect(await attempt.open(page), isFalse);
      final sw = Stopwatch()..start();
      expect(await attempt.next(deadline: _in(5)), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('nach einer Antwort mit fremdem state ist der Versuch zu: nächster next() sofort null', () async {
      final session = FakeWebAuthSession();
      final attempt = await SessionOAuthRedirect(session).prepare();
      await attempt.open(page);
      session.finish(Uri.parse('io.github.carpeasrael.familynexus:/oauth?code=1&state=fremd'));
      expect((await attempt.next(deadline: _in(5)))!.queryParameters['state'], 'fremd');
      final sw = Stopwatch()..start();
      expect(await attempt.next(deadline: _in(5)), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)), reason: 'kein Warten bis zur Frist');
    });

    test('Abbruch zwischen prepare und open → kein start', () async {
      final session = FakeWebAuthSession();
      final r = SessionOAuthRedirect(session);
      final attempt = await r.prepare();
      r.cancel();
      expect(await attempt.open(page), isFalse);
      expect(session.starts, isEmpty);
      expect(session.cancels, <int>[1]);
    });

    test('Abbruch bei ausstehender Startantwort → cancel mit der richtigen ID', () async {
      final session = FakeWebAuthSession()..startGate = Completer<void>();
      final r = SessionOAuthRedirect(session);
      final attempt = await r.prepare();
      final opening = attempt.open(page);
      await pumpEventQueue();
      expect(session.starts.single.id, 1);
      r.cancel();
      expect(session.cancels, <int>[1]);
      session.startGate!.complete();
      await opening;
      expect(await attempt.next(deadline: _in(5)), isNull);
    });

    test('cancel() beendet die native Sitzung; ein neuer Versuch beendet den alten', () async {
      final session = FakeWebAuthSession();
      final r = SessionOAuthRedirect(session);
      final a = await r.prepare();
      await a.open(page);
      final aWaiting = a.next(deadline: _in(5));
      final b = await r.prepare();
      expect(session.cancels, <int>[1], reason: 'alte Sitzung beendet');
      expect(await aWaiting, isNull);
      await b.open(page);
      expect(session.starts.map((s) => s.id), <int>[1, 2]);
      b.cancel();
      expect(session.cancels, <int>[1, 2]);
      expect(session.isOpen(2), isFalse);
    });

    test('verspätetes Ende bzw. cancel() eines alten Versuchs beendet den neuen nicht', () async {
      final session = FakeWebAuthSession();
      final r = SessionOAuthRedirect(session);
      final a = await r.prepare();
      await a.open(page);
      final b = await r.prepare();
      await b.open(page);
      session.finish(null, id: 1); // verspätetes ended(nil) der ersetzten Sitzung
      a.cancel(); // finally des alten Vorgangs
      await pumpEventQueue();
      expect(session.isOpen(2), isTrue);
      final waiting = b.next(deadline: _in(5));
      session.finish(ok, id: 2);
      expect(await waiting, ok);
    });

    test('open() wartet nicht auf das Ende der Sitzung', () async {
      final session = FakeWebAuthSession();
      final attempt = await SessionOAuthRedirect(session).prepare();
      expect(await attempt.open(page).timeout(const Duration(seconds: 2)), isTrue);
      expect(session.isOpen(1), isTrue);
      attempt.cancel();
    });
  });
}
