import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Future<void> _pump(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  // Schaltflächen bevorzugen: Der Titel in der AppBar kann denselben Text tragen.
  var finder = find.widgetWithText(FilledButton, text);
  if (finder.evaluate().isEmpty) finder = find.widgetWithText(OutlinedButton, text);
  if (finder.evaluate().isEmpty) finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('vier Schritte: Sprache → Server → Konto → Familie → Hauptansicht', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);

    expect(find.text('Willkommen bei FamilyNexus'), findsOneWidget);
    expect(find.text('Schritt 1 von 4'), findsOneWidget);
    await _tapText(tester, 'Weiter');

    // Server: eigener Server, ungültige Eingaben zuerst
    expect(find.text('Schritt 2 von 4'), findsOneWidget);
    await _tapText(tester, 'Eigener Server');
    await tester.enterText(find.byType(TextField), 'http://fake.test');
    await _tapText(tester, 'Server prüfen');
    expect(find.text('Bitte eine gültige https-Adresse eingeben.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fake.test');
    await _tapText(tester, 'Server prüfen');
    expect(find.textContaining('Server erreichbar'), findsOneWidget);
    expect(find.text('Betreiber: fake.test'), findsOneWidget);
    expect(find.text('Kontakt: Fake-Betreiber'), findsOneWidget);
    expect(app.services.settings.settings.serverUrl, 'https://fake.test');
    await _tapText(tester, 'Weiter');

    // Konto: falsches, dann richtiges Passwort
    expect(find.text('Schritt 3 von 4'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'falsch');
    await _tapText(tester, 'Anmelden');
    expect(find.text('Benutzername oder Passwort stimmen nicht.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
    await _tapText(tester, 'Anmelden');

    // Schlüsselsicherung (Pflicht): einrichten, Schlüssel bestätigen
    expect(find.text('Schritt 3 von 4'), findsOneWidget);
    expect(find.text('Schlüsselsicherung'), findsOneWidget);
    await _tapText(tester, 'Schlüsselsicherung einrichten');
    expect(find.text('Dein Wiederherstellungsschlüssel'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Weiter'); // Schlüssel bestätigt
    expect(app.gateway.securityState.name, 'ready');
    await _tapText(tester, 'Weiter'); // weiter zum Familienschritt

    // Familie
    expect(find.text('Schritt 4 von 4'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name der Familie'), 'Familie Beispiel');
    await _tapText(tester, 'Familie gründen');

    expect(app.services.settings.settings.onboardingDone, isTrue);
    expect(app.gateway.family?.name, 'Familie Beispiel');
    expect(find.byTooltip('Menü öffnen'), findsOneWidget, reason: 'Hauptansicht mit Menü');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Passwortfeld ist verdeckt und ohne Tastatur-Lernen', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Weiter');
    await _tapText(tester, 'Eigener Server');
    await tester.enterText(find.byType(TextField), 'fake.test');
    await _tapText(tester, 'Server prüfen');
    await _tapText(tester, 'Weiter');
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Passwort'));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
  });

  testWidgets('nicht erreichbarer Server zeigt lokalisierte Meldung ohne Rohtext', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.reachable = false;
    await _pump(tester, app);
    await _tapText(tester, 'Weiter');
    await _tapText(tester, 'Eigener Server');
    await tester.enterText(find.byType(TextField), 'fake.test');
    await _tapText(tester, 'Server prüfen');
    expect(find.text('Server nicht erreichbar. Prüfe die Verbindung.'), findsOneWidget);
  });

  testWidgets('eingeloggt ohne Familie: Einrichtung startet bei Schritt 4', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await app.gateway.login(
      server: ServerUrl.tryParse('fake.test')!,
      username: 'anna',
      password: 'geheim123',
    );
    await app.gateway.setUpSecurity();
    await _pump(tester, app);
    expect(find.text('Schritt 4 von 4'), findsOneWidget);
  });

  testWidgets('eingeloggt, aber Gerät nicht verifiziert: Einrichtung beginnt bei der Schlüsselsicherung', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await app.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
    await _pump(tester, app);
    expect(find.text('Schritt 3 von 4'), findsOneWidget);
    expect(find.text('Schlüsselsicherung einrichten'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Weiter')).onPressed, isNull, reason: 'kein Überspringen');
  });

  testWidgets('Sprache in Schritt 1 umschaltbar', (tester) async {
    final app = await buildTestApp(lang: null, loggedIn: false);
    await _pump(tester, app);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to FamilyNexus'), findsOneWidget);
    expect(app.services.settings.settings.languageCode, 'en');
  });

  test('Gründer ist Moderator', () async {
    final app = await buildTestApp();
    expect(app.gateway.family!.myRole, Role.moderator);
    expect(app.gateway.session, SessionState.ready);
  });
}
