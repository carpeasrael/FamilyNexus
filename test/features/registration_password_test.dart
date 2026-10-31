import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/registration_form.dart';
import '../support/test_app.dart';

const _mismatch = 'Die Passwörter stimmen nicht überein.';

Finder _field(String label) => find.widgetWithText(TextField, label);
TextField _widget(WidgetTester tester, String label) => tester.widget<TextField>(_field(label));
bool _focused(WidgetTester tester, String label) => _widget(tester, label).focusNode!.hasFocus;
FilledButton _create(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Konto erstellen'));

Future<TestApp> _open(WidgetTester tester, {void Function(TestApp app)? before}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = await buildTestApp(loggedIn: false);
  before?.call(app);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Neue Familie gründen'));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _name(WidgetTester tester, String name) async {
  await tester.enterText(_field('Wie heißt du?'), name);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(_field(label), text);
  await tester.pumpAndSettle();
}

/// Enter im Feld „Passwort wiederholen“.
Future<void> _enter(WidgetTester tester) async {
  await tester.showKeyboard(_field('Passwort wiederholen'));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Grund steht in der Live-Zeile und am Feld, und die Semantik des Feldes nennt ihn (#117).
Future<void> _expectReason(WidgetTester tester, String text, {required String at}) async {
  final semantics = tester.ensureSemantics();
  await tester.pump();
  final live = find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false));
  expect(find.descendant(of: live, matching: find.text(text)), findsOneWidget, reason: 'Live-Zeile');
  expect(find.descendant(of: _field(at), matching: find.text(text)), findsOneWidget, reason: 'errorText am Feld');
  expect(tester.getSemantics(find.descendant(of: _field(at), matching: find.byType(EditableText))).hint, contains(text));
  expect(_focused(tester, at), isTrue, reason: 'Fokus auf „$at“');
  semantics.dispose();
}

void main() {
  group('Kontrolleingabe (#117)', () {
    testWidgets('TP-REG-15 Knopf nur bei Gleichheit, Fehler erst, wenn die Eingabe nicht mehr passen kann', (tester) async {
      final app = await _open(tester);
      await _name(tester, 'Carla');
      await _type(tester, 'Passwort', 'sicher-genug');
      expect(_create(tester).onPressed, isNull, reason: 'Wiederholung fehlt');

      await _type(tester, 'Passwort wiederholen', 'sicher');
      expect(_create(tester).onPressed, isNull, reason: 'erst ein Anfang');
      expect(find.text(_mismatch), findsNothing, reason: 'passender Anfang ist kein Fehler');

      await _type(tester, 'Passwort wiederholen', 'sicher-gemein');
      expect(_create(tester).onPressed, isNull);
      expect(find.text(_mismatch), findsOneWidget);

      await _type(tester, 'Passwort wiederholen', 'sicher-genug');
      expect(find.text(_mismatch), findsNothing);
      expect(_create(tester).onPressed, isNotNull);

      // Auch eine spätere Änderung am ersten Feld zählt.
      await _type(tester, 'Passwort', 'sicher-genug!');
      expect(_create(tester).onPressed, isNull);
      expect(find.text(_mismatch), findsNothing, reason: 'Wiederholung ist wieder ein Anfang');
      await _type(tester, 'Passwort', 'sicher-gen');
      expect(find.text(_mismatch), findsOneWidget);
      expect(app.server.registerCalls, 0);
    });

    testWidgets('TP-REG-15b Wiederholung verdeckt wie das Passwort, ein gemeinsamer Schalter', (tester) async {
      await _open(tester);
      final repeat = _widget(tester, 'Passwort wiederholen');
      expect(repeat.obscureText, isTrue);
      expect(repeat.autocorrect, isFalse);
      expect(repeat.enableSuggestions, isFalse);
      expect(repeat.enableIMEPersonalizedLearning, isFalse);
      expect(repeat.smartDashesType, SmartDashesType.disabled);
      expect(repeat.smartQuotesType, SmartQuotesType.disabled);
      expect(_widget(tester, 'Passwort').smartDashesType, SmartDashesType.disabled);
      expect(_widget(tester, 'Passwort').smartQuotesType, SmartQuotesType.disabled);
      expect(find.byTooltip('Passwort anzeigen'), findsOneWidget, reason: 'kein doppelter Tooltip');
      await tester.tap(find.byTooltip('Passwort anzeigen'));
      await tester.pumpAndSettle();
      expect(_widget(tester, 'Passwort wiederholen').obscureText, isFalse);
    });

    testWidgets('TP-REG-16 Enter springt vom Passwort zur Wiederholung, dort sendet es', (tester) async {
      final app = await _open(tester);
      await _name(tester, 'Carla');
      await _type(tester, 'Passwort', 'sicher-genug');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_focused(tester, 'Passwort wiederholen'), isTrue);
      expect(app.server.registerCalls, 0);

      app.server.registrationFlows = <List<String>>[<String>[RegistrationFlows.terms]];
      await _type(tester, 'Passwort wiederholen', 'sicher-genug');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.server.registerCalls, 1);
    });

    testWidgets('TP-REG-16b nach Abschluss sind beide Passwortfelder leer', (tester) async {
      final app = await _open(tester);
      await _name(tester, 'Carla');
      await enterNewPassword(tester, 'sicher-genug');
      final pass = _widget(tester, 'Passwort').controller!;
      final repeat = _widget(tester, 'Passwort wiederholen').controller!;
      await _enter(tester);
      expect(app.gateway.userId, '@carla:fake.test');
      expect(pass.text, isEmpty);
      expect(repeat.text, isEmpty);
    });

    testWidgets('TP-REG-16c Enter während des Absendens löst keinen zweiten Aufruf aus', (tester) async {
      final gate = Completer<void>();
      final app = await _open(tester, before: (a) => a.server.registerGate = gate);
      await _name(tester, 'Carla');
      await enterNewPassword(tester, 'sicher-genug');
      await tester.showKeyboard(_field('Passwort wiederholen'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Erstelle Konto …'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(app.server.registerCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(app.gateway.userId, '@carla:fake.test');
    });

    testWidgets('TP-REG-16d Enter und Knopf im selben Frame lösen genau einen Aufruf aus', (tester) async {
      final gate = Completer<void>();
      final app = await _open(tester, before: (a) => a.server.registerGate = gate);
      await _name(tester, 'Carla');
      await enterNewPassword(tester, 'sicher-genug');
      await tester.showKeyboard(_field('Passwort wiederholen'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      // Bewusst kein `pump`: Der Knopf ist noch der aus dem letzten Frame.
      expect(_create(tester).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Konto erstellen'));
      expect(app.server.registerCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(app.server.registerCalls, 1);
      expect(app.gateway.userId, '@carla:fake.test');
    });

    testWidgets('TP-REG-17 Anbieter nicht bereit: Grund ohne Fokuswechsel, verschwindet, wenn er bereit wird', (tester) async {
      final app = await _open(tester, before: (a) => a.server.reachable = false);
      await _enter(tester);
      const text = 'Der Anbieter ist noch nicht bereit. Warte einen Moment oder prüfe die Adresse.';
      expect(find.text(text), findsOneWidget);
      expect(_focused(tester, 'Passwort wiederholen'), isTrue, reason: 'kein Fokuswechsel');
      expect(app.server.registerCalls, 0);

      app.server.reachable = true;
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(find.text(text), findsNothing);
    });

    testWidgets('TP-REG-17b Name fehlt', (tester) async {
      await _open(tester);
      await _enter(tester);
      await _expectReason(tester, 'Bitte gib deinen Namen ein.', at: 'Wie heißt du?');
      await _name(tester, 'Carla');
      expect(find.text('Bitte gib deinen Namen ein.'), findsNothing, reason: 'verschwindet bei Eingabe');
    });

    testWidgets('TP-REG-17c Benutzername leer oder ungültig', (tester) async {
      await _open(tester);
      await _name(tester, 'Carla');
      await tester.enterText(_field('Dein Benutzername'), '');
      await tester.pumpAndSettle();
      await _enter(tester);
      const text = 'Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.';
      await _expectReason(tester, text, at: 'Dein Benutzername');
    });

    testWidgets('TP-REG-17d Benutzername vergeben; der Grund verschwindet auch über den Vorschlag', (tester) async {
      await _open(tester);
      await _name(tester, 'Anna');
      await _enter(tester);
      await _expectReason(tester, 'Dieser Benutzername ist schon vergeben.', at: 'Dein Benutzername');
      await tester.tap(find.text('„anna2“ verwenden'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Dieser Benutzername ist schon vergeben.'), findsNothing);
    });

    testWidgets('TP-REG-17e Passwort zu kurz', (tester) async {
      await _open(tester);
      await _name(tester, 'Carla');
      await _type(tester, 'Passwort', 'kurz');
      await _enter(tester);
      await _expectReason(tester, 'Das Passwort braucht mindestens 8 Zeichen.', at: 'Passwort');
      await _type(tester, 'Passwort', 'kurz-und-gut');
      expect(find.text('Das Passwort braucht mindestens 8 Zeichen.'), findsNothing);
    });

    testWidgets('TP-REG-17f Wiederholung leer oder nur ein Anfang: Grund erscheint über Enter', (tester) async {
      final app = await _open(tester);
      await _name(tester, 'Carla');
      await _type(tester, 'Passwort', 'sicher-genug');
      await _enter(tester);
      await _expectReason(tester, _mismatch, at: 'Passwort wiederholen');
      await _type(tester, 'Passwort wiederholen', 'sicher');
      expect(find.text(_mismatch), findsNothing, reason: 'verschwindet bei Eingabe');
      await _enter(tester);
      await _expectReason(tester, _mismatch, at: 'Passwort wiederholen');
      expect(app.server.registerCalls, 0);
    });

    testWidgets('TP-REG-17g Serverfehler bleibt neben dem Eingabegrund stehen, bis neu abgesendet wird', (tester) async {
      final app = await _open(tester);
      await _name(tester, 'Carla');
      await enterNewPassword(tester, 'sicher-genug');
      app.server.reachable = false;
      await _enter(tester);
      const server = 'Server nicht erreichbar. Prüfe die Verbindung.';
      expect(find.text(server), findsOneWidget);
      app.server.reachable = true;

      await _type(tester, 'Passwort wiederholen', 'x');
      expect(find.text(server), findsOneWidget, reason: 'Eingabe allein löscht den Serverfehler nicht');
      await _enter(tester);
      expect(find.text(server), findsNothing, reason: 'Der Eingabegrund steht davor');
      await _expectReason(tester, _mismatch, at: 'Passwort wiederholen');
      await _type(tester, 'Passwort wiederholen', 'sicher');
      expect(find.text(server), findsOneWidget);
      expect(find.text(_mismatch), findsNothing);
    });
  });
}
