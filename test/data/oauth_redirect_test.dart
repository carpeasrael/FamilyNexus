import 'dart:io';

import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_links.dart';

DateTime _in(int seconds) => DateTime.now().add(Duration(seconds: seconds));

void main() {
  test('TP-OAUTH-06 Desktop: Rücksprung über 127.0.0.1 mit zufälligem Port, nur GET /oauth, danach geschlossen', () async {
    final r = LoopbackOAuthRedirect();
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
    final r = LoopbackOAuthRedirect();
    final attempt = await r.prepare();
    final waiting = attempt.next(deadline: _in(5));
    r.cancel();
    expect(await waiting, isNull);
  });

  test('Mobil: nur Links im App-Schema mit Pfad /oauth zählen', () async {
    final links = FakeLinkSource();
    final attempt = await AppLinkOAuthRedirect(links).prepare();
    expect(attempt.redirectUri.toString(), 'io.github.carpeasrael.familynexus:/oauth');
    final waiting = attempt.next(deadline: _in(5));
    links.controller.add('familynexus://join?v=2');
    links.controller.add('io.github.carpeasrael.familynexus:/oauth?code=1&state=2');
    expect((await waiting)!.queryParameters['code'], '1');
    expect(AppLinkOAuthRedirect.isCallback('familynexus://join?x'), isFalse);
  });

  test('R2: ein neuer Versuch beendet den alten, der alte stört den neuen nicht', () async {
    final links = FakeLinkSource();
    final r = AppLinkOAuthRedirect(links);
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
    final attempt = await AppLinkOAuthRedirect(FakeLinkSource()).prepare();
    expect(await attempt.next(deadline: DateTime.now().add(const Duration(milliseconds: 50))), isNull);
  });
}
