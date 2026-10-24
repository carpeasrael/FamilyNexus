import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Future<void> _tapText(WidgetTester tester, String text) async {
  var finder = find.widgetWithText(FilledButton, text);
  if (finder.evaluate().isEmpty) finder = find.widgetWithText(OutlinedButton, text);
  if (finder.evaluate().isEmpty) finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Anmeldung eines bestehenden Familienmitglieds an einem weiteren Gerät: Schlüssel eingeben, dann Hauptansicht', (tester) async {
    // Gerät 1: Anna ist bereits Mitglied der Familie, Schlüsselsicherung eingerichtet.
    final first = await buildTestApp();
    final recoveryKey = first.server.recoveryKeys[first.gateway.userId]!;
    // Gerät 2: frische Installation am selben Server.
    final second = await buildTestApp(loggedIn: false, server: first.server);
    await tester.pumpWidget(FamilyNexusApp(services: second.services));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Ich habe schon ein Konto');
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Anmelden');

    // Kein neuer Schlüssel: dieses Gerät ist unbekannt und muss freigeschaltet werden.
    expect(find.text('Dieses Gerät freischalten'), findsWidgets);
    expect(find.text('Notfall-Schlüssel erstellen'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Notfall-Schlüssel'), recoveryKey);
    await _tapText(tester, 'Freischalten');

    // Die Familie besteht bereits: nichts gründen, die Einrichtung schließt sich ab.
    expect(second.services.settings.settings.onboardingDone, isTrue);
    expect(second.gateway.family?.name, 'Familie Test');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Familie gründen'), findsNothing);
  });

  testWidgets('Anmeldung eines Mitglieds ohne Gerät mit Schlüssel: Verifizierung per Emoji mit dem ersten Gerät', (tester) async {
    final first = await buildTestApp();
    final second = await buildTestApp(loggedIn: false, server: first.server);
    await second.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
    await tester.pumpWidget(FamilyNexusApp(services: second.services));
    await tester.pumpAndSettle();
    expect(find.text('Dieses Gerät freischalten'), findsWidgets);
    expect(find.textContaining('Gerät DEV1'), findsOneWidget, reason: 'das erste Gerät ist als Verifizierungspartner wählbar');
  });
}
