import 'dart:convert';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient _client(Map<String, (int, Object)> routes, {List<Uri>? seen}) =>
    MockClient.streaming((req, body) async {
      seen?.add(req.url);
      final r = routes[req.url.path];
      if (r == null) return http.StreamedResponse(Stream<List<int>>.value(<int>[]), 404);
      final data = r.$2 is String ? r.$2 as String : json.encode(r.$2);
      return http.StreamedResponse(Stream<List<int>>.value(utf8.encode(data)), r.$1);
    });

final _url = ServerUrl.tryParse('example.org')!;

void main() {
  test('liefert Versionen, Passwort-Login und Betreiber', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1', 'v1.11']}),
      '/_matrix/client/v3/login': (200, <String, Object>{'flows': <Object>[<String, Object>{'type': 'm.login.password'}]}),
      '/.well-known/matrix/support': (200, <String, Object>{
        'contacts': <Object>[<String, Object>{'matrix_id': '@admin:example.org'}],
        'support_page': 'https://example.org/support',
      }),
    }));
    final info = await probe.probe(_url);
    expect(info.versions, contains('v1.11'));
    expect(info.supportsPasswordLogin, isTrue);
    expect(info.contact, '@admin:example.org');
    expect(info.supportPage, 'https://example.org/support');
  });

  test('folgt well-known nur zu https-Zielen', () async {
    final seen = <Uri>[];
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/.well-known/matrix/client': (200, <String, Object>{
        'm.homeserver': <String, Object>{'base_url': 'http://evil.example'},
      }),
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
    }, seen: seen));
    final info = await probe.probe(_url);
    expect(info.url.host, 'example.org');
    expect(seen.every((u) => u.scheme == 'https'), isTrue);
  });

  test('übernimmt gültiges https-well-known', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/.well-known/matrix/client': (200, <String, Object>{
        'm.homeserver': <String, Object>{'base_url': 'https://matrix.example.org/'},
      }),
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
    }));
    expect((await probe.probe(_url)).url.host, 'matrix.example.org');
  });

  test('Server ohne Versionen → nicht unterstützt', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{}));
    await expectLater(
      probe.probe(_url),
      throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnsupported)),
    );
  });

  test('Müll-/Übergrößen-Antworten werden ignoriert', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
      '/.well-known/matrix/support': (200, 'x' * (70 * 1024)),
      '/_matrix/client/v3/login': (200, 'kein json'),
    }));
    final info = await probe.probe(_url);
    expect(info.contact, isNull);
    expect(info.supportsPasswordLogin, isFalse);
  });

  test('Betreiberangaben werden bereinigt und gekürzt', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
      '/.well-known/matrix/support': (200, <String, Object>{
        'contacts': <Object>[<String, Object>{'email_address': 'a\u0000b\n${'z' * 200}'}],
        'support_page': 'javascript:alert(1)',
      }),
    }));
    final info = await probe.probe(_url);
    expect(info.contact!.length, lessThanOrEqualTo(80));
    expect(info.contact, isNot(contains('\n')));
    expect(info.supportPage, isNull);
  });

  test('Mindestversion v1.1 wird verlangt; höchste Version wird zuletzt geführt', () async {
    final old = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['r0.6.1']}),
    }));
    await expectLater(
      old.probe(_url),
      throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnsupported)),
    );
    final mixed = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.11', 'r0.6.1', 'v1.2', 'v1.17', 'v1.9']}),
    }));
    expect((await mixed.probe(_url)).versions.last, 'v1.17');
  });

  test('Nicht-Map in well-known/m.homeserver wirft nicht, sondern wird ignoriert', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/.well-known/matrix/client': (200, <String, Object>{'m.homeserver': 'kein-objekt'}),
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
    }));
    expect((await probe.probe(_url)).url.host, 'example.org');
  });

  test('Admin-Kontakt wird bevorzugt', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
      '/.well-known/matrix/support': (200, <String, Object>{
        'contacts': <Object>[
          <String, Object>{'role': 'm.role.security', 'email_address': 'sec@example.org'},
          <String, Object>{'role': 'm.role.admin', 'email_address': 'admin@example.org'},
        ],
      }),
    }));
    expect((await probe.probe(_url)).contact, 'admin@example.org');
  });

  test('Nicht-200-Antworten werden wie „nicht vorhanden“ behandelt', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
      '/.well-known/matrix/support': (500, 'Fehler'),
      '/_matrix/client/v3/login': (403, 'verboten'),
    }));
    final info = await probe.probe(_url);
    expect(info.contact, isNull);
    expect(info.supportsPasswordLogin, isFalse);
  });
}
