// Pen-Test 2026-10-30 – Netzwerk. Echte TLS-Verbindungen gegen lokale Server:
//  * „MITM“: Server mit selbstsigniertem Zertifikat (nicht vertrauenswürdig) → App muss abbrechen.
//  * „Bösartiger Homeserver“: gültig erreichbarer, aber feindlicher Server (Testclient vertraut dem
//    Zertifikat, um einen Server mit gültigem Zertifikat nachzustellen) → Downgrade, Weiterleitungen,
//    übergroße Antworten, unsichere OAuth-Endpunkte.
//  * OAuth-Loopback-Empfänger (Desktop): Bindung, Pfade, Lebensdauer.
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/https_only_client.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

final String _dir = '${Directory.current.path}/pen-Test/tests';

/// Bösartiger HTTPS-Server mit selbstsigniertem Zertifikat.
Future<HttpServer> _evilServer(Future<void> Function(HttpRequest req) handler) async {
  final ctx = SecurityContext()
    ..useCertificateChain('$_dir/pt_evil_cert.pem')
    ..usePrivateKey('$_dir/pt_evil_key.pem');
  final s = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
  s.listen((req) async {
    try {
      await handler(req);
    } catch (_) {}
    await req.response.close().catchError((Object _) {});
  });
  return s;
}

/// Client, der dem Testzertifikat vertraut (stellt einen Server mit gültigem Zertifikat dar).
http.Client _trusting() => IOClient(HttpClient()..badCertificateCallback = (c, h, p) => true);

void _json(HttpRequest req, int status, Object body) {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(json.encode(body));
}

void main() {
  group('Transportverschlüsselung', () {
    test('PT-N1: HttpsOnlyClient lehnt http:// ab (auch bei manipuliertem Ziel)', () async {
      final c = HttpsOnlyClient();
      for (final u in <String>['http://example.org/', 'ws://example.org/', 'file:///etc/passwd', 'ftp://example.org/']) {
        await expectLater(c.get(Uri.parse(u)), throwsA(isA<http.ClientException>()), reason: u);
      }
    });

    test('PT-N2: MITM mit selbstsigniertem Zertifikat – Serverprüfung bricht ab (Standard-Client der App)', () async {
      var hits = 0;
      final s = await _evilServer((req) async {
        hits++;
        _json(req, 200, <String, Object>{'versions': <String>['v1.11']});
      });
      final probe = ServerProbe(); // wie in der App: System-Vertrauensspeicher
      await expectLater(
        probe.probe(ServerUrl.tryParse('localhost:${s.port}')!),
        // I-03 behoben: ServerProbe meldet den TLS-Fehler als „nicht erreichbar“ statt ihn roh durchzureichen.
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnreachable)),
      );
      // Auch der HttpsOnlyClient (Gateway) prüft das Zertifikat.
      await expectLater(HttpsOnlyClient().get(Uri.parse('https://localhost:${s.port}/_matrix/client/versions')), throwsA(anything));
      expect(hits, 0, reason: 'keine HTTP-Anfrage darf den MITM-Server erreichen (TLS-Handshake scheitert vorher)');
      await s.close(force: true);
    });

    test('PT-N3: MITM gegen den lokalen Synapse (Caddy, selbstsigniert) – App-Client verweigert', () async {
      final probe = ServerProbe();
      await expectLater(
        probe.probe(ServerUrl.tryParse('https://localhost:18448')!),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnreachable)),
      );
    }, skip: Platform.environment['FN_E2E'] == '1' ? false : 'nur mit laufendem tool/synapse/up.sh');
  });

  group('Bösartiger Homeserver', () {
    test('PT-N4: Weiterleitung https → http wird nicht verfolgt (Downgrade)', () async {
      final seen = <String>[];
      final s = await _evilServer((req) async {
        seen.add(req.uri.path);
        req.response
          ..statusCode = 302
          ..headers.set('location', 'http://127.0.0.1:9/steal');
      });
      final c = HttpsOnlyClient(_trusting());
      final res = await c.get(Uri.parse('https://localhost:${s.port}/_matrix/client/v3/login'));
      expect(res.statusCode, 302, reason: 'Weiterleitung wird nicht verfolgt');
      await expectLater(
        ServerProbe(client: _trusting()).probe(ServerUrl.tryParse('localhost:${s.port}')!),
        throwsA(isA<GatewayException>()),
      );
      await s.close(force: true);
    });

    test('PT-N5: .well-known mit http-/Fremd-Basis wird ignoriert', () async {
      final seen = <String>[];
      late HttpServer s;
      s = await _evilServer((req) async {
        seen.add(req.uri.path);
        switch (req.uri.path) {
          case '/.well-known/matrix/client':
            _json(req, 200, <String, Object>{'m.homeserver': <String, String>{'base_url': 'http://127.0.0.1:${s.port}'}});
          case '/_matrix/client/versions':
            _json(req, 200, <String, Object>{'versions': <String>['v1.11']});
          default:
            _json(req, 404, <String, String>{'errcode': 'M_NOT_FOUND'});
        }
      });
      final info = await ServerProbe(client: _trusting()).probe(ServerUrl.tryParse('localhost:${s.port}')!);
      expect(info.url.uri.scheme, 'https');
      expect(info.url.host, 'localhost');
      await s.close(force: true);
    });

    test('PT-N6: Übergroße / endlose Antwort wird begrenzt (Speicher-DoS)', () async {
      final s = await _evilServer((req) async {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write('{"versions":["v1.11"],"x":"');
        final chunk = 'A' * 65536;
        for (var i = 0; i < 160; i++) {
          req.response.write(chunk); // ~10 MB
        }
        req.response.write('"}');
      });
      final sw = Stopwatch()..start();
      await expectLater(
        ServerProbe(client: _trusting()).probe(ServerUrl.tryParse('localhost:${s.port}')!),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.serverUnsupported)),
      );
      // ignore: avoid_print
      print('PT-N6: Abbruch nach ${sw.elapsedMilliseconds} ms');
      await s.close(force: true);
    });

    test('PT-N7: Hängender Server (Slowloris) – Zeitschranke greift', () async {
      final s = await _evilServer((req) async {
        req.response.statusCode = 200;
        req.response.write('{"versions":');
        await req.response.flush();
        await Future<void>.delayed(const Duration(seconds: 30));
      });
      final sw = Stopwatch()..start();
      await expectLater(
        ServerProbe(client: _trusting(), timeout: const Duration(seconds: 2)).probe(ServerUrl.tryParse('localhost:${s.port}')!),
        throwsA(isA<GatewayException>()),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
      await s.close(force: true);
    });

    test('PT-N8: OAuth-Metadaten mit http-Endpunkt / Zugangsdaten in URL → kein OAuth', () async {
      late HttpServer s;
      s = await _evilServer((req) async {
        switch (req.uri.path) {
          case '/_matrix/client/versions':
            _json(req, 200, <String, Object>{'versions': <String>['v1.15']});
          case '/_matrix/client/v1/auth_metadata':
            _json(req, 200, <String, String>{
              'issuer': 'https://localhost:${s.port}/',
              'authorization_endpoint': 'http://localhost:${s.port}/authorize',
              'registration_endpoint': 'https://user:pw@localhost:${s.port}/register',
              'token_endpoint': 'https://localhost:${s.port}/token',
              'revocation_endpoint': 'https://localhost:${s.port}/revoke',
            });
          case '/.well-known/matrix/support':
            _json(req, 200, <String, Object>{
              'contacts': <Object>[<String, String>{'matrix_id': '@admin\u202e:evil\n<script>'}],
              'support_page': 'javascript:alert(1)',
            });
          default:
            _json(req, 404, <String, String>{'errcode': 'M_NOT_FOUND'});
        }
      });
      final info = await ServerProbe(client: _trusting()).probe(ServerUrl.tryParse('localhost:${s.port}')!);
      expect(info.usesOAuth, isFalse);
      expect(info.supportPage, isNull, reason: 'javascript:-Hilfeseite verworfen');
      expect(info.contact, isNot(contains('\n')));
      expect(info.contact, isNot(contains('\u202e')), reason: 'F-08 behoben: Bidi-Zeichen entfernt');
      // ignore: avoid_print
      print('PT-N8: Kontakt nach Bereinigung: ${jsonEncode(info.contact)}');
      await s.close(force: true);
    });
  });

  group('OAuth-Loopback-Empfänger (Desktop)', () {
    test('PT-N9: nur 127.0.0.1, nur GET /oauth, nach Abbruch geschlossen', () async {
      final r = LoopbackOAuthRedirect();
      final attempt = await r.prepare();
      final port = attempt.redirectUri.port;
      expect(attempt.redirectUri.host, '127.0.0.1');
      // Von außen (andere Schnittstelle) nicht erreichbar: Bindung prüfen.
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final i in ifaces) {
        for (final a in i.addresses.where((a) => !a.isLoopback)) {
          await expectLater(Socket.connect(a, port, timeout: const Duration(seconds: 1)), throwsA(anything), reason: 'erreichbar über ${a.address}');
        }
      }
      final c = HttpClient();
      Future<int> call(String method, String path) async {
        final req = await c.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
        final res = await req.close();
        await res.drain<void>();
        return res.statusCode;
      }

      expect(await call('POST', '/oauth?code=x&state=y'), 404);
      expect(await call('GET', '/admin'), 404);
      expect(await call('GET', '/oauth/../etc?x=1'), anyOf(404, 200));
      expect(await call('GET', '/oauth?code=x&state=y'), 200);
      final got = await attempt.next(deadline: DateTime.now().add(const Duration(seconds: 2)));
      expect(got?.queryParameters['state'], 'y');
      attempt.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await expectLater(Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 1)), throwsA(anything));
      c.close(force: true);
    });
  });
}
