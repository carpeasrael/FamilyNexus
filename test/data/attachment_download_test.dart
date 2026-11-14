// Begrenzter Anhang-Download (E-28, #458) gegen nachgestellte Serverantworten. Reiner Unit-Test ohne SDK-Anmeldung,
// vodozemac oder Datenbank. Echtzeit mit kurzen Zeitschranken; eine äußere Schutz-Schranke lässt einen hängenden
// Download rot werden, statt den Test ewig laufen zu lassen, und bleibt von der inneren `TimeoutException` unterscheidbar.
import 'dart:async';
import 'dart:typed_data';

import 'package:family_nexus/data/matrix/https_only_client.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uri _uri = Uri.parse('https://hs.example/_matrix/client/v1/media/download/hs.example/abc');
const Duration _short = Duration(milliseconds: 100);
const Duration _guard = Duration(seconds: 3);

/// Antwort, deren Kopfzeilen da sind, deren Körper aber nie endet. [first] wird beim Abonnieren noch geliefert.
http.StreamedResponse _hanging(int status, {int? contentLength, void Function()? onCancel, List<int>? first}) {
  late final StreamController<List<int>> ctrl;
  ctrl = StreamController<List<int>>(
    onListen: first == null ? null : () => ctrl.add(first),
    onCancel: onCancel,
  );
  return http.StreamedResponse(ctrl.stream, status, contentLength: contentLength);
}

HttpsOnlyClient _client(Future<http.StreamedResponse> Function(http.BaseRequest req) handler) =>
    HttpsOnlyClient(MockClient.streaming((req, _) => handler(req)));

Future<Uint8List> _download(http.Client client, {Uri? uri, Duration timeout = _short, Duration guard = _guard}) =>
    SdkMatrixGateway.boundedDownload(client, uri ?? _uri, accessToken: 'tok', timeout: timeout)
        .timeout(guard, onTimeout: () => fail('Download hängt'));

Matcher _gatewayError(GatewayError error) =>
    isA<GatewayException>().having((e) => e.error, 'error', error);

void main() {
  test('Körper hängt nach den Kopfzeilen: Zeitschranke greift und beendet das Abo (#458)', () async {
    var cancelled = false;
    final client = _client((_) async => _hanging(200, onCancel: () => cancelled = true));
    await expectLater(_download(client), throwsA(isA<TimeoutException>()));
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });

  test('erst ein Block, dann Stillstand: Zeitschranke wirkt auch nach Beginn der Übertragung (#458)', () async {
    var cancelled = false;
    final client = _client((_) async => _hanging(200, first: List<int>.filled(10, 7), onCancel: () => cancelled = true));
    await expectLater(_download(client), throwsA(isA<TimeoutException>()));
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });

  test('Status ≠ 200 mit hängendem Körper: notFound ohne Lesen, Abo beendet (#458)', () async {
    var cancelled = false;
    final client = _client((_) async => _hanging(404, onCancel: () => cancelled = true));
    await expectLater(_download(client), throwsA(_gatewayError(GatewayError.notFound)));
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });

  test('zu großes contentLength: attachmentRejected und Abo beendet (#458)', () async {
    var cancelled = false;
    final client = _client((_) async =>
        _hanging(200, contentLength: AttachmentPolicy.maxBytes + 2048, onCancel: () => cancelled = true));
    await expectLater(_download(client), throwsA(_gatewayError(GatewayError.attachmentRejected)));
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });

  test('langsamer, aber fortlaufender Download läuft durch (Leerlauf-, keine Gesamtschranke)', () async {
    final client = _client((_) async {
      late final StreamController<List<int>> ctrl;
      ctrl = StreamController<List<int>>(onListen: () async {
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          ctrl.add(<int>[i, i]);
        }
        await ctrl.close();
      });
      return http.StreamedResponse(ctrl.stream, 200);
    });
    final bytes = await _download(client, timeout: const Duration(milliseconds: 500), guard: const Duration(seconds: 5));
    expect(bytes, <int>[0, 0, 1, 1, 2, 2, 3, 3]);
  });

  test('Kopfzeilen kommen nie: TimeoutException', () async {
    final client = _client((_) => Completer<http.StreamedResponse>().future);
    await expectLater(_download(client), throwsA(isA<TimeoutException>()));
  });

  test('sendet den Zugangsschlüssel und liefert genau die Bytes', () async {
    String? auth;
    final client = _client((req) async {
      auth = req.headers['authorization'];
      return http.StreamedResponse(Stream<List<int>>.value(<int>[1, 2, 3]), 200, contentLength: 3);
    });
    expect(await _download(client), <int>[1, 2, 3]);
    expect(auth, 'Bearer tok');
  });

  test('Nicht-https-Adresse wird weiter abgewiesen', () async {
    var called = false;
    final client = _client((_) async {
      called = true;
      return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
    });
    await expectLater(
      _download(client, uri: Uri.parse('http://hs.example/_matrix/client/v1/media/download/hs.example/abc')),
      throwsA(isA<http.ClientException>()),
    );
    expect(called, isFalse);
  });
}
