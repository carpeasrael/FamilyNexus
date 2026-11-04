import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/registration_form.dart';
import '../support/test_app.dart';

Future<void> _pump(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  var f = find.widgetWithText(FilledButton, text);
  if (f.evaluate().isEmpty) f = find.widgetWithText(OutlinedButton, text);
  if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, text);
  if (f.evaluate().isEmpty) f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// „Neue Familie gründen“ → Formular ausfüllen → „Konto erstellen“.
Future<void> _fillAndSubmit(WidgetTester tester, {String name = 'Emil', String password = 'sicher-genug'}) async {
  await _tap(tester, 'Neue Familie gründen');
  await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), name);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await enterNewPassword(tester, password);
  await _tap(tester, 'Konto erstellen');
}

void main() {
  testWidgets('#27: Kontoanlage direkt nach „Alle lokalen Daten löschen“ (neue Dienste) geht zu Schritt 2', (tester) async {
    final before = await buildTestApp();
    await _pump(tester, before);
    await before.gateway.logout();
    await tester.pumpAndSettle();
    // _fullReset baut die Dienste neu auf; die Einrichtung muss die neuen verwenden.
    final after = await buildTestApp(loggedIn: false);
    await _pump(tester, after);
    await _fillAndSubmit(tester);
    expect(after.gateway.userId, '@emil:fake.test');
    expect(find.text('Notfall-Schlüssel erstellen'), findsOneWidget, reason: 'nicht auf „Schritt 1 von 3“ stehen bleiben');
    expect(find.text('Dafür fehlt die Berechtigung.'), findsNothing);
  });

  testWidgets('TP-REG-05 Bedingungen: lesen im Browser, ohne Zustimmung kein Weiter', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.terms],
    ];
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    expect(find.text('Noch ein kurzer Schritt'), findsOneWidget);
    expect(find.text('Der Anbieter möchte, dass du seinen Bedingungen zustimmst.'), findsOneWidget);
    await _tap(tester, 'Nutzungsbedingungen');
    expect(app.browser.opened.single.toString(), 'https://fake.test/terms');
    expect(app.browser.inApp.single, isTrue, reason: 'Bedingungen öffnen in der App (E-91)');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Weiter')).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tap(tester, 'Weiter');
    expect(app.gateway.userId, '@emil:fake.test');
    expect(find.text('Notfall-Schlüssel erstellen'), findsOneWidget);
  });

  testWidgets('TP-REG-06 E-Mail: senden, „noch nicht bestätigt“, nach Bestätigung angelegt', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.email],
    ];
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    expect(find.textContaining('geht nur an den Anbieter'), findsOneWidget, reason: 'Datenschutzhinweis');
    await tester.enterText(find.widgetWithText(TextField, 'E-Mail-Adresse'), 'keine-adresse');
    await _tap(tester, 'Bestätigung senden');
    expect(find.text('Bitte eine gültige E-Mail-Adresse eingeben.'), findsOneWidget);
    expect(app.server.emailsSent, isEmpty);
    await tester.enterText(find.widgetWithText(TextField, 'E-Mail-Adresse'), 'emil@beispiel.de');
    await _tap(tester, 'Bestätigung senden');
    expect(app.server.emailsSent, <String>['emil@beispiel.de']);
    expect(find.textContaining('Der Anbieter hat eine E-Mail an emil@beispiel.de geschickt.'), findsOneWidget);

    await _tap(tester, 'Ich habe bestätigt');
    expect(find.textContaining('Noch nicht bestätigt.'), findsOneWidget);
    expect(app.gateway.userId, isNull);

    await _tap(tester, 'E-Mail erneut senden');
    expect(app.server.emailsSent, hasLength(2));
    app.server.emailConfirmed = true;
    await _tap(tester, 'Ich habe bestätigt');
    expect(app.gateway.userId, '@emil:fake.test');
  });

  testWidgets('TP-REG-06b bereits verwendete E-Mail-Adresse: Meldung, Schritt bleibt offen', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.email],
    ];
    app.server.emailsInUse.add('anna@beispiel.de');
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    await tester.enterText(find.widgetWithText(TextField, 'E-Mail-Adresse'), 'anna@beispiel.de');
    await _tap(tester, 'Bestätigung senden');
    expect(find.text('Diese E-Mail-Adresse wird schon für ein anderes Konto verwendet.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'E-Mail-Adresse'), findsOneWidget);
  });

  testWidgets('TP-REG-07 Zugangscode des Anbieters: falscher Code, dann richtiger', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.token, RegistrationFlows.dummy],
    ];
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Zugangscode des Anbieters'), 'FALSCH');
    await _tap(tester, 'Weiter');
    expect(find.text('Der Code passt nicht. Bitte prüfe ihn.'), findsOneWidget);
    expect(app.gateway.userId, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Zugangscode des Anbieters'), 'FAMILIE-2026');
    await _tap(tester, 'Weiter');
    expect(app.gateway.userId, '@emil:fake.test');
  });

  testWidgets('TP-REG-08 „Kein Roboter“: im Browser öffnen, „Ich bin fertig“ prüft; Rückkehr in die App prüft automatisch', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.recaptcha],
    ];
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    expect(find.textContaining('auf der Seite des Anbieters kurz, dass du kein Roboter bist'), findsOneWidget);
    await _tap(tester, 'Ich bin fertig');
    expect(find.text('Noch nicht abgeschlossen. Bitte beende die Bestätigung auf der Seite des Anbieters.'), findsOneWidget);

    await _tap(tester, 'Seite öffnen');
    expect(app.browser.opened.last.host, 'fake.test');
    app.server.captchaSolved = true;
    // Rückkehr aus dem Browser: App wird wieder aktiv.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(app.gateway.userId, '@emil:fake.test');
  });

  testWidgets('TP-REG-08c „Kein Roboter“ in der Sitzung (iOS/macOS): Ende der Sitzung prüft ohne resumed, resumed während der Sitzung nicht',
      (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.recaptcha],
    ];
    app.browser.sessionWaits = true;
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    await _tap(tester, 'Seite öffnen');
    expect(app.browser.inApp.last, isTrue, reason: 'Captcha öffnet in der App');
    expect(app.browser.sessionOpen, isTrue);
    app.server.captchaSolved = true;
    // Face ID, Autofill oder das Erscheinen der Sitzung selbst: inactive → resumed bei offener Sitzung.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(app.gateway.userId, isNull, reason: 'keine Prüfung, solange die Sitzung offen ist');
    // „Abbrechen“ beendet die Sitzung: jetzt wird automatisch geprüft, ohne resumed.
    app.browser.finishSession();
    await tester.pumpAndSettle();
    expect(app.gateway.userId, '@emil:fake.test');
  });

  testWidgets('TP-REG-08c Captcha-Seite öffnet nicht: Hinweis, resumed prüft nicht; erneutes Tippen bzw. Stufenwechsel entfernt ihn',
      (tester) async {
    const noPage = 'Die Seite konnte nicht geöffnet werden. Bitte versuche es noch einmal.';
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.recaptcha],
    ];
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    app.browser.available = false;
    await _tap(tester, 'Seite öffnen');
    expect(find.text(noPage), findsOneWidget);
    app.server.captchaSolved = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(app.gateway.userId, isNull, reason: 'nichts geöffnet → keine Prüfung');

    // Stufenwechsel („Ich bin fertig“, noch nicht gelöst) entfernt den Hinweis.
    app.server.captchaSolved = false;
    await _tap(tester, 'Ich bin fertig');
    expect(find.text('Noch nicht abgeschlossen. Bitte beende die Bestätigung auf der Seite des Anbieters.'), findsOneWidget);
    expect(find.text(noPage), findsNothing);

    // Erneut nicht geöffnet, dann erneutes Tippen mit verfügbarer Seite: Hinweis weg, Rückkehr prüft.
    await _tap(tester, 'Seite öffnen');
    expect(find.text(noPage), findsOneWidget);
    app.browser.available = true;
    await _tap(tester, 'Seite öffnen');
    expect(find.text(noPage), findsNothing);
    app.server.captchaSolved = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(app.gateway.userId, '@emil:fake.test');
  });

  testWidgets('TP-REG-08b mehrere Schritte nacheinander (Bedingungen, dann Captcha)', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.terms, RegistrationFlows.recaptcha],
    ];
    app.server.captchaSolved = true;
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tap(tester, 'Weiter');
    expect(find.textContaining('kein Roboter'), findsOneWidget);
    await _tap(tester, 'Ich bin fertig');
    expect(app.gateway.userId, '@emil:fake.test');
  });

  testWidgets('TP-REG-09 Registrierung beim Anbieter abgeschaltet: Webseite öffnen oder anmelden', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationMode = RegistrationMode.disabled;
    await _pump(tester, app);
    await _tap(tester, 'Neue Familie gründen');
    expect(find.textContaining('kann die App kein Konto anlegen'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Wie heißt du?'), findsNothing);
    await _tap(tester, 'Webseite öffnen');
    expect(app.browser.opened.single.toString(), 'https://fake.test/signup');
    expect(app.browser.inApp.single, isTrue, reason: 'Webseite des Anbieters öffnet in der App (E-91)');
    await _tap(tester, 'Ich habe ein Konto – anmelden');
    expect(find.widgetWithText(TextField, 'Benutzername'), findsOneWidget);
  });

  testWidgets('TP-REG-09c Registrierung abgeschaltet: Element starten, sonst Hinweis mit Download', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationMode = RegistrationMode.disabled;
    await _pump(tester, app);
    await _tap(tester, 'Neue Familie gründen');
    await _tap(tester, 'Element starten');
    expect(app.element.starts, 1);
    expect(find.textContaining('nicht installiert'), findsNothing);
    app.element.installed = false;
    await _tap(tester, 'Element starten');
    expect(find.textContaining('nicht installiert'), findsOneWidget);
    await _tap(tester, 'Element laden');
    expect(app.browser.opened.last.toString(), 'https://element.io/download');
    expect(app.browser.inApp.last, isFalse, reason: 'Download-Link bleibt extern');
  });

  testWidgets('TP-REG-09b nur nicht unterstützte Schritte (Telefonnummer): wie abgeschaltet', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>['m.login.msisdn'],
    ];
    await _pump(tester, app);
    await _tap(tester, 'Neue Familie gründen');
    expect(find.textContaining('kann die App kein Konto anlegen'), findsOneWidget);
  });

  testWidgets('TP-REG-10 Abbrechen eines Zusatzschritts vergisst das Passwort', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationFlows = <List<String>>[
      <String>[RegistrationFlows.terms],
    ];
    await _pump(tester, app);
    await _fillAndSubmit(tester);
    expect(app.gateway.registrationInProgress, isTrue);
    await _tap(tester, 'Abbrechen');
    expect(app.gateway.registrationInProgress, isFalse, reason: 'Sitzung samt Passwort verworfen');
    expect(find.widgetWithText(TextField, 'Wie heißt du?'), findsOneWidget);
    expect(app.store.data.values.any((v) => v.contains('sicher-genug')), isFalse, reason: 'Passwort nie gespeichert');
  });

  testWidgets('Name inzwischen vergeben (Server meldet es beim Absenden): Meldung im Formular', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tap(tester, 'Neue Familie gründen');
    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Fritz');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await enterNewPassword(tester, 'sicher-genug');
    app.server.addAccount('fritz', 'anderes'); // jemand war schneller
    await _tap(tester, 'Konto erstellen');
    expect(find.text('Dieser Benutzername ist schon vergeben.'), findsWidgets);
    expect(app.gateway.session, SessionState.loggedOut);
  });
}
