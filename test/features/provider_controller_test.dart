import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/onboarding/provider_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

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
}
