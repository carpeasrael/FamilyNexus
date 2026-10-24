import 'dart:io';

import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_links.dart';

void main() {
  test('Desktop: Rücksprung über 127.0.0.1 mit zufälligem Port, genau ein Aufruf, danach geschlossen', () async {
    final r = LoopbackOAuthRedirect();
    final target = await r.prepare();
    expect(target.scheme, 'http');
    expect(target.host, '127.0.0.1');
    expect(target.path, '/oauth');
    expect(target.port, greaterThan(0));

    final client = HttpClient();
    // Falscher Pfad wird abgewiesen und beendet das Warten nicht.
    final wrong = await (await client.getUrl(target.replace(path: '/evil'))).close();
    expect(wrong.statusCode, 404);
    final waiting = r.wait(timeout: const Duration(seconds: 5));
    final res = await (await client.getUrl(target.replace(query: 'code=abc&state=xyz'))).close();
    expect(res.statusCode, 200);
    expect(res.headers.value('cache-control'), 'no-store');
    final page = await res.transform(const SystemEncoding().decoder).join();
    expect(page, isNot(contains('abc')), reason: 'Code erscheint nicht in der Seite');
    final cb = await waiting;
    expect(cb!.queryParameters, <String, String>{'code': 'abc', 'state': 'xyz'});
    client.close(force: true);
    final fresh = HttpClient();
    await expectLater(
      fresh.getUrl(target).then((q) => q.close()),
      throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
      reason: 'Empfänger ist zu',
    );
    fresh.close(force: true);
  });

  test('Desktop: Abbrechen beendet das Warten ohne Ergebnis', () async {
    final r = LoopbackOAuthRedirect();
    await r.prepare();
    final waiting = r.wait(timeout: const Duration(seconds: 5));
    r.cancel();
    expect(await waiting, isNull);
  });

  test('Mobil: nur Links im App-Schema mit Pfad /oauth zählen', () async {
    final links = FakeLinkSource();
    final r = AppLinkOAuthRedirect(links);
    final target = await r.prepare();
    expect(target.toString(), 'io.github.carpeasrael.familynexus:/oauth');
    final waiting = r.wait(timeout: const Duration(seconds: 5));
    links.controller.add('familynexus://join?v=2');
    links.controller.add('io.github.carpeasrael.familynexus:/oauth?code=1&state=2');
    final cb = await waiting;
    expect(cb!.queryParameters['code'], '1');
    expect(AppLinkOAuthRedirect.isCallback('familynexus://join?x'), isFalse);
  });

  test('Zeitüberschreitung liefert null', () async {
    final r = AppLinkOAuthRedirect(FakeLinkSource());
    await r.prepare();
    expect(await r.wait(timeout: const Duration(milliseconds: 50)), isNull);
  });
}
