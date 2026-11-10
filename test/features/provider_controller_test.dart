import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/onboarding/provider_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

class _BrokenProbeGateway extends FakeMatrixGateway {
  _BrokenProbeGateway(super.fake);

  @override
  Future<ServerInfo> probeServer(ServerUrl url) async => throw StateError('kein Gateway-Fehler');
}

void main() {
  test('matrix.org bleibt der Standard, auch wenn zuletzt ein anderer Server gespeichert wurde', () async {
    final app = await buildTestApp();
    await app.services.settings.update((c) => c.copyWith(serverUrl: 'https://beispiel.de'));
    final c = ProviderController(gateway: app.gateway);
    addTearDown(c.dispose);
    expect(c.standard, ServerUrl.tryParse(AppSettings.defaultServerUrl));
    expect(c.server.toString(), 'https://matrix.org');
    expect(c.custom, isFalse);
  });

  test('ein anderer Server (Einladung, @anna:beispiel.de) wird „Anderer Anbieter“, der Standard bleibt', () async {
    final app = await buildTestApp();
    final c = ProviderController(gateway: app.gateway);
    addTearDown(c.dispose);
    c.useServer(ServerUrl.tryParse('beispiel.de')!);
    expect(c.custom, isTrue);
    expect(c.customText, 'beispiel.de');
    expect(c.standard.host, 'matrix.org');
    c.useServer(ServerUrl.tryParse('matrix.org')!);
    expect(c.custom, isFalse);
    expect(c.server.toString(), 'https://matrix.org');
  });

  test('#359 ein Fehler, der kein Gateway-Fehler ist: Anzeige „unbekannt“ wie bisher, Ursache im Protokoll (nur Typ)', () async {
    AppLog.captured.clear();
    AppLog.capture = true;
    addTearDown(() => AppLog.capture = false);
    final c = ProviderController(gateway: _BrokenProbeGateway(FakeMatrixServer()));
    addTearDown(c.dispose);
    c.start();
    await Future<void>.delayed(Duration.zero);
    expect(c.status, ProviderStatus.failed);
    expect(c.error, GatewayError.unknown);
    expect(AppLog.captured, contains('E/onboarding: Anbieter-Prüfung fehlgeschlagen (StateError)'));
    expect(AppLog.captured.join('\n'), isNot(contains('kein Gateway-Fehler')), reason: 'nie der Fehlertext');
  });
}
