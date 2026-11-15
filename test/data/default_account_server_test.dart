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
}
