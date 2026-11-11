import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/onboarding/login_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

/// AP-4e: Die Zerlegung von `LoginStep.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
Future<void> _open(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ich habe schon ein Konto'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Anmelden: leeres Formular, dann falsches Passwort mit Fehlerzeile', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(loggedIn: false);
    await _open(tester, app);
    final empty = semanticsSnapshot(tester, find.byType(LoginStep));
    await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
    await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'falsch');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pumpAndSettle();
    final failed = semanticsSnapshot(tester, find.byType(LoginStep));
    expect(empty, _expectedEmpty);
    expect(failed, _expectedWrongPassword);
    handle.dispose();
  });
}

const List<String> _expectedEmpty = <String>[
  'L=Benutzername textfield tap',
  'L=Passwort textfield obscured tap',
  'T=Passwort anzeigen button tap',
  'L=Anmelden button disabled',
  'L=Noch kein Konto? Jetzt erstellen button tap',
  'L=Dein Konto liegt bei fake.test. live',
  'L=Minimiert live',
  'L=Erweitert H=Minimiert tap',
];
const List<String> _expectedWrongPassword = <String>[
  'L=Benutzername V=anna textfield tap',
  'L=Passwort V=•••••• textfield obscured tap',
  'T=Passwort anzeigen button tap',
  'L=Anmelden button tap',
  'L=Benutzername oder Passwort stimmen nicht. live',
  'L=Noch kein Konto? Jetzt erstellen button tap',
  'L=Dein Konto liegt bei fake.test. live',
  'L=Minimiert live',
  'L=Erweitert H=Minimiert tap',
];
