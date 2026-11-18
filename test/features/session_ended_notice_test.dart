import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #556, E-110: Beendet der Server die Sitzung (z. B. Konto gelöscht), sagt „Anmelden“ das mit einem neutralen Hinweis.
/// Beim eigenen Abmelden steht er nicht da. Grenze: Fake-Gateway; die Zuordnung der SDK-Gründe und die echte
/// Sitzungsbeendigung prüft `test/data/session_ended_by_server_test.dart`.
void main() {
  const de = 'Deine Sitzung wurde beendet, zum Beispiel weil das Konto oder die Anmeldung beim Anbieter nicht mehr gültig ist. Melde dich neu an.';
  const en = 'Your session was ended, for example because your account or sign-in at the provider is no longer valid. Sign in again.';

  Future<TestApp> start(WidgetTester tester, String lang) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(lang: lang);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    expect(app.gateway.session, SessionState.ready, reason: 'angemeldet gestartet');
    return app;
  }

  for (final (lang, text, create) in <(String, String, String)>[
    ('de', de, 'Noch kein Konto? Jetzt erstellen'),
    ('en', en, 'No account yet? Create one'),
  ]) {
    testWidgets('#556 ($lang): Server beendet die Sitzung: „Anmelden“ mit Hinweis', (tester) async {
      final app = await start(tester, lang);
      expect(find.text(text), findsNothing, reason: 'vorher kein Hinweis');

      app.gateway.endSessionByServer();
      await tester.pumpAndSettle();

      expect(app.gateway.session, SessionState.loggedOut);
      expect(find.text(create), findsOneWidget, reason: 'Anmeldeschritt');
      expect(find.text(text), findsOneWidget, reason: 'Hinweis „Sitzung beendet“');
      expect(find.textContaining('existiert nicht mehr'), findsNothing, reason: 'keine Behauptung zur Ursache');
    });
  }

  testWidgets('#556: eigenes Abmelden zeigt den Hinweis nicht', (tester) async {
    final app = await start(tester, 'de');

    await app.services.logout();
    await tester.pumpAndSettle();

    expect(app.gateway.session, SessionState.loggedOut);
    expect(find.text('Noch kein Konto? Jetzt erstellen'), findsOneWidget, reason: 'Anmeldeschritt');
    expect(find.text(de), findsNothing);
  });

  testWidgets('#556: nach erneuter Anmeldung und eigenem Abmelden ist der Hinweis weg', (tester) async {
    final app = await start(tester, 'de');
    app.gateway.endSessionByServer();
    await tester.pumpAndSettle();
    expect(find.text(de), findsOneWidget);

    await app.gateway.login(server: ServerUrl.tryParse(app.server.host)!, username: 'anna', password: 'geheim123');
    await tester.pumpAndSettle();
    expect(app.gateway.sessionEndedByServer, isFalse, reason: 'angemeldet');

    await app.services.logout();
    await tester.pumpAndSettle();
    expect(find.text(de), findsNothing, reason: 'eigenes Abmelden nach früherem Serverende');
  });
}
