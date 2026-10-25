import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

Future<void> _pump(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  // Schaltflächen bevorzugen: Der Titel in der AppBar kann denselben Text tragen.
  var finder = find.widgetWithText(FilledButton, text);
  if (finder.evaluate().isEmpty) finder = find.widgetWithText(OutlinedButton, text);
  if (finder.evaluate().isEmpty) finder = find.widgetWithText(TextButton, text);
  if (finder.evaluate().isEmpty) finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Wartet die Entprellung der Namensprüfung ab.
Future<void> _settleCheck(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Fachbegriffe, die auf dem normalen Weg nicht erscheinen dürfen (TP-L10N-01).
void _expectNoJargon(WidgetTester tester, {String? reason}) {
  final texts = <String>[
    for (final e in find.byType(Text).evaluate())
      if ((e.widget as Text).data != null) (e.widget as Text).data!
      else if ((e.widget as Text).textSpan != null) (e.widget as Text).textSpan!.toPlainText(),
  ];
  for (final t in texts) {
    expect(t.contains('Matrix'), isFalse, reason: '${reason ?? ''}: „$t“');
    expect(t.toLowerCase().contains('homeserver'), isFalse, reason: '${reason ?? ''}: „$t“');
    expect(RegExp(r'@[a-z0-9._=\-/+]+:').hasMatch(t), isFalse, reason: '${reason ?? ''}: „$t“');
  }
}

void main() {
  testWidgets('TP-START-01 Startseite: drei Wege, keine Fachbegriffe, keine Schrittanzeige', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    expect(find.text('Willkommen bei FamilyNexus'), findsOneWidget);
    expect(find.text('Neue Familie gründen'), findsOneWidget);
    expect(find.text('Ich wurde eingeladen'), findsOneWidget);
    expect(find.text('Ich habe schon ein Konto'), findsOneWidget);
    expect(find.textContaining('Schritt'), findsNothing);
    _expectNoJargon(tester, reason: 'Startseite');
  });

  testWidgets('TP-START-02 Sprache auf der Startseite umschaltbar', (tester) async {
    final app = await buildTestApp(lang: null, loggedIn: false);
    await _pump(tester, app);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to FamilyNexus'), findsOneWidget);
    expect(find.text('Start a new family'), findsOneWidget);
    expect(app.services.settings.settings.languageCode, 'en');
  });

  testWidgets(
      'TP-REG-01 Weg „Neue Familie“: Konto erstellen → Notfall-Schlüssel → Familie benennen → Jetzt einladen → Hauptansicht',
      (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');

    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    expect(find.text('Konto erstellen'), findsWidgets);
    expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget, reason: 'Anbieter wird automatisch geprüft, kein „Server prüfen“');
    expect(find.text('Server prüfen'), findsNothing);
    _expectNoJargon(tester, reason: 'Konto erstellen');

    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Carla Groß');
    await _settleCheck(tester);
    // TP-REG-02: Vorschlag aus dem Namen, Prüfung live.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Dein Benutzername')).controller!.text, 'carla.gross');
    expect(find.text('Der Benutzername ist frei.'), findsOneWidget);
    final create = find.widgetWithText(FilledButton, 'Konto erstellen');
    expect(tester.widget<FilledButton>(create).onPressed, isNull, reason: 'ohne Passwort kein Absenden');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'sicher-genug');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Konto erstellen');

    // TP-REG-11: Konto mit Anzeigename beim Anbieter.
    expect(app.gateway.userId, '@carla.gross:fake.test');
    expect(app.server.displayNameOf('@carla.gross:fake.test'), 'Carla Groß');
    expect(app.server.passwordOf('@carla.gross:fake.test'), 'sicher-genug');

    // Notfall-Schlüssel (Pflicht).
    expect(find.text('Schritt 2 von 3'), findsOneWidget);
    _expectNoJargon(tester, reason: 'Notfall-Schlüssel');
    await _tapText(tester, 'Notfall-Schlüssel erstellen');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Weiter');

    // Familie benennen.
    expect(find.text('Schritt 3 von 3'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing, reason: 'Weg „Neue Familie“ fragt nicht nach Beitreten');
    await tester.enterText(find.widgetWithText(TextField, 'Name der Familie'), 'Familie Groß');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Familie gründen');
    expect(find.text('Fertig! „Familie Groß“ ist eingerichtet.'), findsOneWidget);
    expect(app.services.settings.settings.onboardingDone, isFalse, reason: 'erst nach „Jetzt einladen“/„Später“');

    await _tapText(tester, 'Jetzt einladen');
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'Einladung mit QR, E-Mail und Link');
    await tester.tap(find.widgetWithText(FilledButton, 'Schließen'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.onboardingDone, isTrue);
    expect(app.gateway.family?.name, 'Familie Groß');
    expect(app.gateway.family!.myRole, Role.moderator);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('TP-REG-03 vergebener Benutzername schlägt eine freie Alternative vor', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Anna');
    await _settleCheck(tester);
    expect(find.text('Schon vergeben – wie wäre es mit „anna2“?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'sicher-genug');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Konto erstellen')).onPressed, isNull);
    await _tapText(tester, '„anna2“ verwenden');
    await _settleCheck(tester);
    expect(find.text('Der Benutzername ist frei.'), findsOneWidget);
    await _tapText(tester, 'Konto erstellen');
    expect(app.gateway.userId, '@anna2:fake.test');
  });

  testWidgets('TP-REG-04 zu kurzes Passwort: kein Absenden, Hinweis bleibt sichtbar', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Dora');
    await _settleCheck(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'kurz');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Konto erstellen')).onPressed, isNull);
    expect(find.textContaining('Mindestens 8 Zeichen'), findsOneWidget);
    expect(app.server.registerCalls, 0);
  });

  testWidgets('TP-REG-04b Passwortfeld ist verdeckt, ohne Tastatur-Lernen, mit Anzeigen-Schalter', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    TextField field() => tester.widget<TextField>(find.widgetWithText(TextField, 'Passwort'));
    expect(field().obscureText, isTrue);
    expect(field().enableSuggestions, isFalse);
    expect(field().enableIMEPersonalizedLearning, isFalse);
    await tester.tap(find.byTooltip('Passwort anzeigen'));
    await tester.pumpAndSettle();
    expect(field().obscureText, isFalse);
  });

  testWidgets('TP-SRV-01/02 anderer Anbieter unter „Erweitert“: wird nach kurzer Pause automatisch geprüft', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    expect(find.text('Anderen Anbieter verwenden'), findsNothing, reason: 'eingeklappt');
    await _tapText(tester, 'Erweitert');
    expect(find.text('fake.test (empfohlen)'), findsOneWidget);
    expect(find.text('Betreiber: fake.test'), findsOneWidget);
    expect(find.text('Kontakt: Fake-Betreiber'), findsOneWidget);
    await _tapText(tester, 'Anderen Anbieter verwenden');
    await tester.enterText(find.widgetWithText(TextField, 'Adresse des Anbieters'), 'anderer.example');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('anderer.example ist gerade nicht erreichbar. Prüfe deine Internetverbindung.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Konto erstellen')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Adresse des Anbieters'), 'fake.test');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
  });

  testWidgets('TP-SRV-03 unsichere Adresse (http) wird abgelehnt', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    await _tapText(tester, 'Erweitert');
    await _tapText(tester, 'Anderen Anbieter verwenden');
    await tester.enterText(find.widgetWithText(TextField, 'Adresse des Anbieters'), 'http://fake.test');
    await tester.pumpAndSettle();
    expect(find.text('Bitte eine gültige https-Adresse eingeben.'), findsOneWidget);
  });

  testWidgets('TP-SRV-04 Anbieter nicht erreichbar: verständliche Meldung ohne Rohtext, „Nochmal“ prüft erneut', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    app.server.reachable = false;
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    expect(find.text('fake.test ist gerade nicht erreichbar. Prüfe deine Internetverbindung.'), findsOneWidget);
    app.server.reachable = true;
    await _tapText(tester, 'Erneut versuchen');
    expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
  });

  testWidgets('TP-LOGIN-02 Weg „Ich habe schon ein Konto“: falsches, dann richtiges Passwort', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Ich habe schon ein Konto');
    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'falsch');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Anmelden');
    expect(find.text('Benutzername oder Passwort stimmen nicht.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Anmelden');
    expect(app.gateway.session, SessionState.ready);
    expect(find.text('Schritt 2 von 3'), findsOneWidget);
    expect(find.text('Notfall-Schlüssel erstellen'), findsOneWidget);
  });

  testWidgets('TP-LOGIN-01 vollständige ID @name:anbieter wählt den Anbieter selbst', (tester) async {
    // Andere Voreinstellung: Ohne die ID wäre der Anbieter unbekannt.
    final app = await buildTestApp(loggedIn: false, defaultProvider: 'unbekannt.example');
    await _pump(tester, app);
    await _tapText(tester, 'Ich habe schon ein Konto');
    expect(find.textContaining('unbekannt.example ist gerade nicht erreichbar'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), '@anna:fake.test');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Anmelden');
    expect(app.gateway.userId, '@anna:fake.test');
  });

  testWidgets('R6 vollständige ID eines anderen Anbieters: Anmelden erst nach dem Wechsel, Passwort nie an den alten', (tester) async {
    final other = FakeMatrixServer(host: 'andere.test')..addAccount('anna', 'geheim123');
    final app = await buildTestApp(loggedIn: false, server: other);
    await _pump(tester, app);
    await _tapText(tester, 'Ich habe schon ein Konto');
    // Standard ist andere.test (Voreinstellung im Test); die ID nennt fake.test.
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), '@anna:fake.test');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Anmelden')).onPressed, isNull,
        reason: 'Anbieter passt noch nicht zur ID');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('fake.test ist gerade nicht erreichbar'), findsOneWidget, reason: 'Wechsel zum Anbieter aus der ID');
    expect(app.gateway.session, SessionState.loggedOut);
  });

  testWidgets('Wechsel zwischen „Konto erstellen“ und „Anmelden“ behält den Benutzernamen', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await _tapText(tester, 'Neue Familie gründen');
    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Ben');
    await _settleCheck(tester);
    await _tapText(tester, 'Ich habe schon ein Konto');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Benutzername')).controller!.text, 'ben');
    await _tapText(tester, 'Noch kein Konto? Jetzt erstellen');
    expect(find.widgetWithText(TextField, 'Wie heißt du?'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Neue Familie gründen'), findsOneWidget, reason: 'zurück zur Startseite');
  });

  testWidgets('TP-START-03 eingeloggt ohne Familie: Einrichtung beginnt beim Familienschritt', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await app.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
    await app.gateway.setUpSecurity();
    await _pump(tester, app);
    expect(find.text('Schritt 3 von 3'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
  });

  testWidgets('TP-KEY-01 eingeloggt, aber Gerät nicht abgesichert: Notfall-Schlüssel zuerst, kein Überspringen', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await app.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
    await _pump(tester, app);
    expect(find.text('Schritt 2 von 3'), findsOneWidget);
    expect(find.text('Notfall-Schlüssel erstellen'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Weiter'), findsNothing, reason: 'kein Überspringen');
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('TP-START-03b nach dem Abmelden: direkt „Anmelden“ statt Startseite', (tester) async {
    final app = await buildTestApp();
    await app.gateway.logout();
    await _pump(tester, app);
    expect(find.text('Anmelden'), findsWidgets);
    expect(find.text('Neue Familie gründen'), findsNothing);
  });

  test('Gründer ist Moderator', () async {
    final app = await buildTestApp();
    expect(app.gateway.family!.myRole, Role.moderator);
    expect(app.gateway.session, SessionState.ready);
  });
}
