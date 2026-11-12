import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/registration_form.dart';
import '../support/test_app.dart';

/// #411: Scheitert das Speichern von `onboardingDone` am Ende der Einrichtung, bleibt die Einrichtung nicht mit einem
/// Spinner stehen, sondern zeigt den Fehler und erlaubt einen neuen Versuch.
Future<void> _tapText(WidgetTester tester, String text) async {
  var finder = find.widgetWithText(FilledButton, text);
  if (finder.evaluate().isEmpty) finder = find.widgetWithText(OutlinedButton, text);
  if (finder.evaluate().isEmpty) finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Begrenzt pumpen: Der Spinner des Abschlusses animiert endlos, `pumpAndSettle` käme nie zur Ruhe.
Future<void> _pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 600)]) async {
  await tester.pump();
  await tester.pump(d);
  await tester.pump(d);
}

void main() {
  testWidgets('Mitglied an einem weiteren Gerät: Speichern scheitert → Fehler und „Erneut versuchen“, danach geht es weiter', (tester) async {
    final first = await buildTestApp();
    final recoveryKey = first.server.recoveryKeys[first.gateway.userId]!;
    final second = await buildTestApp(loggedIn: false, server: first.server);
    await tester.pumpWidget(FamilyNexusApp(services: second.services));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Ich habe schon ein Konto');
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Anmelden');
    await tester.enterText(find.widgetWithText(TextField, 'Notfall-Schlüssel'), recoveryKey);
    await tester.pumpAndSettle();

    // Erst jetzt scheitert das Speichern der Einstellungen: alles davor lief schon.
    second.store.failWrites = true;
    final unlock = find.widgetWithText(FilledButton, 'Freischalten');
    await tester.ensureVisible(unlock);
    await tester.tap(unlock);
    await _pumpFor(tester);

    expect(second.services.settings.settings.onboardingDone, isFalse, reason: 'nichts gespeichert');
    expect(find.widgetWithText(FilledButton, 'Erneut versuchen'), findsOneWidget, reason: 'neuer Versuch möglich (#411)');
    expect(find.text('Unbekannter Fehler.'), findsOneWidget);
    expect(findNavigation(), findsNothing);

    // Ablage wieder beschreibbar: ein Tipp schließt die Einrichtung ab.
    second.store.failWrites = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Erneut versuchen'));
    await _pumpFor(tester);
    await tester.pumpAndSettle();
    expect(second.services.settings.settings.onboardingDone, isTrue);
    expect(findNavigation(), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsNothing);
  });

  testWidgets('Neue Familie: „Später“ scheitert zweimal, „Jetzt einladen“ einmal; Fehler als Zeile, danach klappt es', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(loggedIn: false);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Neue Familie gründen');
    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Carla Groß');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await enterNewPassword(tester, 'sicher-genug');
    await _tapText(tester, 'Konto erstellen');
    await _tapText(tester, 'Notfall-Schlüssel erstellen');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Weiter');
    await tester.enterText(find.widgetWithText(TextField, 'Name der Familie'), 'Familie Groß');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Familie gründen');
    expect(find.text('Fertig! „Familie Groß“ ist eingerichtet.'), findsOneWidget);

    app.store.failWrites = true;
    // „Später“ scheitert zweimal hintereinander: jedes Mal eine Fehlerzeile, die Schaltflächen bleiben bedienbar.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.widgetWithText(TextButton, 'Später'));
      await tester.pumpAndSettle();
      expect(find.text('Unbekannter Fehler.'), findsOneWidget, reason: 'Versuch ${i + 1}');
      expect(app.services.settings.settings.onboardingDone, isFalse);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Später')).onPressed, isNotNull);
    }
    // „Jetzt einladen“: Der Dialog schließt, der Abschluss scheitert, der Fehler steht da.
    await tester.tap(find.widgetWithText(FilledButton, 'Jetzt einladen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Unbekannter Fehler.'), findsOneWidget);
    expect(app.services.settings.settings.onboardingDone, isFalse);

    app.store.failWrites = false;
    await tester.tap(find.widgetWithText(TextButton, 'Später'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.onboardingDone, isTrue);
    expect(findNavigation(), findsOneWidget);
  });
}
