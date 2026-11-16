import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// #497: Konto-Server im Einladungslink, wenn der Servername nicht der Erreichbarkeits-Adresse entspricht.
void main() {
  String? srv(String url, String own) => SdkMatrixGateway.defaultAccountServer(Uri.parse(url), own);

  test('Heimnetz-Server mit ausdrücklichem Port: host:port', () {
    expect(srv('https://localhost:18448', 'localhost'), 'localhost:18448');
    expect(srv('https://LocalHost:18448', 'localhost'), 'localhost:18448');
    expect(srv('https://192.168.0.5:8448', '192.168.0.5'), '192.168.0.5:8448');
  });

  test('kein Port oder Standardport: Servername aus der Matrix-ID gilt', () {
    expect(srv('https://localhost', 'localhost'), isNull);
    expect(srv('https://localhost:443', 'localhost'), isNull);
    expect(srv('https://localhost:0', 'localhost'), isNull, reason: 'Port 0 ist kein gültiger Port');
  });

  test('anderer Host, nicht lokal, kein https, kein Homeserver: null', () {
    expect(srv('https://matrix.example.org:8448', 'example.org'), isNull, reason: 'Delegierung, nicht lokal');
    expect(srv('https://nas:8448', 'localhost'), isNull, reason: 'anderer Host');
    expect(srv('https://example.org:8448', 'example.org'), isNull, reason: 'gleicher Host, aber nicht im Heimnetz');
    expect(srv('http://localhost:18448', 'localhost'), isNull);
    expect(SdkMatrixGateway.defaultAccountServer(null, 'localhost'), isNull);
  });

  group('effectiveAccountServer (#510)', () {
    String? eff(String? e, String url, String own) => SdkMatrixGateway.effectiveAccountServer(e, Uri.parse(url), own);

    test('Platzhalter (eigener Servername) gilt wie ein leeres Feld: Standard mit Port', () {
      expect(eff('localhost', 'https://localhost:18448', 'localhost'), 'localhost:18448');
      expect(eff(' LocalHost ', 'https://localhost:18448', 'localhost'), 'localhost:18448');
      expect(eff('', 'https://localhost:18448', 'localhost'), 'localhost:18448');
      expect(eff(null, 'https://localhost:18448', 'localhost'), 'localhost:18448');
    });

    test('ausdrückliche andere Eingaben bleiben', () {
      expect(eff('localhost:9999', 'https://localhost:18448', 'localhost'), 'localhost:9999');
      expect(eff('localhost:18448', 'https://localhost:18448', 'localhost'), 'localhost:18448');
      expect(eff('nas.lan', 'https://localhost:18448', 'localhost'), 'nas.lan');
      expect(eff('example.org', 'https://localhost:18448', 'localhost'), 'example.org');
    });

    test('ohne Port am Server, Delegation, http oder kein Homeserver: Servername entspricht dem Standard (null)', () {
      expect(eff('localhost', 'https://localhost', 'localhost'), isNull);
      expect(eff('example.org', 'https://matrix.example.org:8448', 'example.org'), isNull, reason: 'Delegation: kein Standard, Servername gilt');
      expect(eff('localhost', 'http://localhost:18448', 'localhost'), isNull);
      expect(SdkMatrixGateway.effectiveAccountServer('localhost', null, 'localhost'), isNull);
    });

    test('Servername mit Port: Eingabe gleich Servername gilt als Platzhalter', () {
      expect(eff('localhost:8448', 'https://localhost:18448', 'localhost:8448'), 'localhost:18448');
      expect(eff('localhost', 'https://localhost:18448', 'localhost:8448'), 'localhost', reason: 'nicht der Platzhalter, bleibt ausdrücklich');
    });
  });
}
