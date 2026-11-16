import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #507: Wer die Einführungstour beendet hat, bekommt sie nach Abmelden und erneutem Anmelden mit demselben Konto nicht
/// wieder. `tourSeen` ist ein Gerätemerker (E-95); Abmelden räumt nur Familiendaten, Blockierliste und Einladungslink auf (#450).
/// Grenze: Fake-Gateway und Speicher im Arbeitsspeicher; ein Lauf mit echtem Speicher auf dem Gerät ist damit nicht ersetzt.
void main() {
  for (final finish in ['Los geht’s', 'Überspringen']) {
    testWidgets('#507: Tour mit „$finish“ beenden, abmelden, mit demselben Konto anmelden: keine Tour', (tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp(tourSeen: false);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      expect(find.text('Schritt 1 von 3'), findsOneWidget);
      if (finish == 'Überspringen') {
        await tester.tap(find.text('Überspringen'));
      } else {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(finish));
      }
      await tester.pumpAndSettle();
      expect(app.services.settings.settings.tourSeen, isTrue);

      await app.services.logout();
      await tester.pumpAndSettle();
      expect(app.gateway.session, SessionState.loggedOut, reason: 'abgemeldet');
      expect(app.services.settings.settings.tourSeen, isTrue, reason: 'Abmelden lässt den Merker');
      expect(app.store.data['tourSeen'], 'true');

      await app.gateway.login(server: ServerUrl.tryParse(app.server.host)!, username: 'anna', password: 'geheim123');
      await tester.pumpAndSettle();
      expect(app.gateway.session, SessionState.ready, reason: 'wieder angemeldet');
      expect(find.textContaining('Schritt'), findsNothing, reason: '#507: keine Tour nach erneuter Anmeldung');
      expect(app.services.settings.settings.tourSeen, isTrue);
    });
  }
}
