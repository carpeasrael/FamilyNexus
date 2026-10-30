import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/registration.dart';
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

  test('Pen-Test I-03: TLS- und Netzfehler kommen als „nicht erreichbar“, nicht roh', () async {
    for (final error in <Exception>[const HandshakeException('CERTIFICATE_VERIFY_FAILED'), const SocketException('refused')]) {
      final probe = ServerProbe(client: MockClient((_) async => throw error));
      await expectLater(
        probe.probe(_url),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnreachable)),
        reason: '${error.runtimeType}',
      );
    }
  });

  test('Pen-Test F-08: Bidi- und unsichtbare Zeichen im Betreiber-Kontakt werden entfernt', () async {
    final probe = ServerProbe(client: _client(<String, (int, Object)>{
      '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.1']}),
      '/.well-known/matrix/support': (200, <String, Object>{
        'contacts': <Object>[<String, Object>{'matrix_id': '@admin\u202E:evil\u200B.org\u2066'}],
      }),
    }));
    final contact = (await probe.probe(_url)).contact!;
    expect(contact, isNot(matches(RegExp('[\u200B-\u200F\u202A-\u202E\u2066-\u2069]'))));
    expect(contact, '@admin :evil .org');
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

  group('Kontoanlage (E-55)', () {
    const meta = <String, Object>{
      'issuer': 'https://account.example.org/',
      'authorization_endpoint': 'https://account.example.org/authorize',
      'registration_endpoint': 'https://account.example.org/oauth2/registration',
      'token_endpoint': 'https://account.example.org/oauth2/token',
      'revocation_endpoint': 'https://account.example.org/oauth2/revoke',
    };

    test('TP-OAUTH-01 Anbieter mit OAuth (wie matrix.org): Browser-Weg, Hinweis in der Serverprüfung', () async {
      final seen = <String>[];
      final probe = ServerProbe(client: MockClient.streaming((req, body) async {
        seen.add('${req.method} ${req.url.path}');
        final routes = <String, (int, Object)>{
          '/_matrix/client/versions': (200, <String, Object>{'versions': <String>['v1.15']}),
          '/_matrix/client/v1/auth_metadata': (200, meta),
        };
        final r = routes[req.url.path];
        if (r == null) return http.StreamedResponse(Stream<List<int>>.value(<int>[]), 404);
        return http.StreamedResponse(Stream<List<int>>.value(utf8.encode(json.encode(r.$2))), r.$1);
      }));
      final options = await probe.registrationOptions(_url);
      expect(options.mode, RegistrationMode.oauth);
      expect(options.webPage.toString(), 'https://account.example.org/');
      expect(seen.where((s) => s.startsWith('POST')), isEmpty, reason: 'kein Registrierungsversuch bei OAuth');
      expect((await probe.probe(_url)).usesOAuth, isTrue);
    });

    test('unsichere OAuth-Angaben (http) zählen nicht', () async {
      final probe = ServerProbe(client: _client(<String, (int, Object)>{
        '/_matrix/client/v1/auth_metadata': (200, <String, Object>{...meta, 'authorization_endpoint': 'http://account.example.org/authorize'}),
        '/_matrix/client/v3/register': (401, <String, Object>{
          'session': 's',
          'flows': <Object>[<String, Object>{'stages': <String>['m.login.dummy']}],
        }),
      }));
      expect((await probe.registrationOptions(_url)).mode, RegistrationMode.inApp);
    });

    test('R11 nur der stabile Pfad zählt (das SDK nutzt nur v1); Token-Endpunkt ohne https zählt nicht', () async {
      final unstable = ServerProbe(client: _client(<String, (int, Object)>{
        '/_matrix/client/unstable/org.matrix.msc2965/auth_metadata': (200, meta),
      }));
      expect((await unstable.registrationOptions(_url)).mode, RegistrationMode.disabled);
      final insecureToken = ServerProbe(client: _client(<String, (int, Object)>{
        '/_matrix/client/v1/auth_metadata': (200, <String, Object>{...meta, 'token_endpoint': 'http://account.example.org/t'}),
      }));
      expect(await insecureToken.oauthIssuer(_url), isNull);
    });

    test('R10 vorübergehende Fehler der Registrierungsabfrage: kein „abgeschaltet“, sondern Fehler zum erneuten Versuch', () async {
      for (final (status, error) in <(int, GatewayError)>[(429, GatewayError.rateLimited), (502, GatewayError.serverUnreachable)]) {
        final probe = ServerProbe(client: _client(<String, (int, Object)>{
          '/_matrix/client/v3/register': (status, <String, Object>{'errcode': 'X'}),
        }));
        await expectLater(
          probe.registrationOptions(_url),
          throwsA(isA<GatewayException>().having((e) => e.error, 'error', error)),
          reason: '$status',
        );
      }
    });

    test('klassische Registrierung: 401 mit unterstützten Abläufen → in der App; Anfrage ohne Zugangsdaten', () async {
      String? body;
      final probe = ServerProbe(client: MockClient.streaming((req, stream) async {
        if (req.url.path == '/_matrix/client/v3/register') {
          body = await utf8.decodeStream(stream);
          expect(req.method, 'POST');
          expect(req.url.queryParameters['kind'], 'user');
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(json.encode(<String, Object>{
              'session': 'abc',
              'flows': <Object>[
                <String, Object>{'stages': <String>['m.login.recaptcha', 'm.login.terms']},
              ],
            }))),
            401,
          );
        }
        return http.StreamedResponse(Stream<List<int>>.value(<int>[]), 404);
      }));
      expect((await probe.registrationOptions(_url)).mode, RegistrationMode.inApp);
      expect(json.decode(body!), <String, Object?>{'inhibit_login': true}, reason: 'weder Benutzername noch Passwort, kein Token');
    });

    test('TP-REG-09 abgeschaltet (403) oder nur Telefon → disabled, Hilfeseite des Anbieters', () async {
      final off = ServerProbe(client: _client(<String, (int, Object)>{
        '/_matrix/client/v3/register': (403, <String, Object>{'errcode': 'M_FORBIDDEN'}),
        '/.well-known/matrix/support': (200, <String, Object>{'support_page': 'https://example.org/konto'}),
      }));
      final o = await off.registrationOptions(_url);
      expect(o.mode, RegistrationMode.disabled);
      expect(o.webPage.toString(), 'https://example.org/konto');
      final phone = ServerProbe(client: _client(<String, (int, Object)>{
        '/_matrix/client/v3/register': (401, <String, Object>{
          'flows': <Object>[<String, Object>{'stages': <String>['m.login.msisdn']}],
        }),
      }));
      expect((await phone.registrationOptions(_url)).mode, RegistrationMode.disabled);
    });

    test('Benutzername: frei, vergeben, ungültig, Fehler → unbekannt', () async {
      ServerProbe answer(int status, Object body) => ServerProbe(client: _client(<String, (int, Object)>{
            '/_matrix/client/v3/register/available': (status, body),
          }));
      expect(await answer(200, <String, Object>{'available': true}).checkUsername(_url, 'anna'), UsernameCheck.available);
      expect(await answer(400, <String, Object>{'errcode': 'M_USER_IN_USE'}).checkUsername(_url, 'anna'), UsernameCheck.taken);
      expect(await answer(400, <String, Object>{'errcode': 'M_INVALID_USERNAME'}).checkUsername(_url, 'anna'), UsernameCheck.invalid);
      expect(await answer(429, <String, Object>{'errcode': 'M_LIMIT_EXCEEDED'}).checkUsername(_url, 'anna'), UsernameCheck.unknown);
      final offline = ServerProbe(client: MockClient((_) => throw http.ClientException('offline')));
      expect(await offline.checkUsername(_url, 'anna'), UsernameCheck.unknown);
    });

    test('Abläufe aus der Serverantwort werden begrenzt gelesen', () {
      final flows = ServerProbe.flowsFrom(<String, Object?>{
        'flows': <Object?>[
          for (var i = 0; i < 50; i++) <String, Object?>{'stages': <Object?>['m.login.dummy', 7, 'x' * 100]},
          'kein-objekt',
        ],
      });
      expect(flows, hasLength(20));
      expect(flows.first, <String>['m.login.dummy']);
    });
  });
}
