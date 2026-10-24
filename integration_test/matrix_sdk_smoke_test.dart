// Rauchtest des echten SDK-Gateways auf dem Gerät. Benötigt Netz nur für die
// Serverprüfung gegen den öffentlichen Standardserver (nur lesende Anfragen
// und ein Anmeldeversuch mit absichtlich ungültigen Zugangsdaten).
import 'dart:io';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/bootstrap.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App startet mit echtem Bootstrap und zeigt die Einrichtung', (tester) async {
    final ks = SecureKeyStore();
    await resetLocalData(keyStore: ks);
    final services = await bootstrap(keyStore: ks);
    await services.settings.update((s) => s.copyWith(languageCode: 'de'));
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    // Startseite der Einrichtung (E-55): drei Wege, noch keine Schrittanzeige.
    expect(find.text('Neue Familie gründen'), findsOneWidget);
    expect(find.text('Ich wurde eingeladen'), findsOneWidget);
    expect(find.text('Ich habe schon ein Konto'), findsOneWidget);
    expect(services.gateway.session, SessionState.loggedOut);
    await resetLocalData(keyStore: ks);
  });

  testWidgets('SDK-Gateway: Serverprüfung und abgelehnte Anmeldung gegen matrix.org', (tester) async {
    await ensureCryptoInitialized();
    final ks = SecureKeyStore();
    final dir = await Directory.systemTemp.createTemp('fn_sdk');
    final gw = SdkMatrixGateway(keyStore: ks, dbDirectory: dir.path);
    await gw.restore();
    expect(gw.session, SessionState.loggedOut);

    final url = ServerUrl.tryParse(' https://matrix.org ')!;
    final info = await gw.probeServer(url);
    expect(info.versions, isNotEmpty);
    expect(info.supportsPasswordLogin, isTrue);

    await expectLater(
      gw.login(server: url, username: 'familynexus-smoketest-gibt-es-nicht', password: 'ungueltig-ungueltig'),
      throwsA(isA<GatewayException>().having(
        (e) => e.error,
        'error',
        anyOf(GatewayError.invalidCredentials, GatewayError.notAllowed),
      )),
    );
    expect(gw.session, SessionState.loggedOut);
    gw.dispose();
    await dir.delete(recursive: true);
    await ks.deleteKey(SdkMatrixGateway.matrixDbKeyName);
  });
}
