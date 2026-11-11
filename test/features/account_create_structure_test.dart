import 'dart:ui' show Tristate;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/features/onboarding/account_create_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// AP-4b: Die Zerlegung von `AccountCreateStep.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
Future<void> _open(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Neue Familie gründen'));
  await tester.pumpAndSettle();
}

List<String> _semantics(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    final parts = <String>[
      if (d.label.isNotEmpty) 'L=${d.label.replaceAll('\n', ' | ')}',
      if (d.value.isNotEmpty) 'V=${d.value}',
      if (d.hint.isNotEmpty) 'H=${d.hint}',
      if (d.tooltip.isNotEmpty) 'T=${d.tooltip}',
      if (d.flagsCollection.isTextField) 'textfield',
      if (d.flagsCollection.isObscured) 'obscured',
      if (d.flagsCollection.isButton) 'button',
      if (d.flagsCollection.isLiveRegion) 'live',
      if (d.flagsCollection.isEnabled == Tristate.isFalse) 'disabled',
      if (d.hasAction(SemanticsAction.tap)) 'tap',
    ];
    if (parts.isNotEmpty) out.add(parts.join(' '));
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(AccountCreateStep)));
  return out;
}

void main() {
  testWidgets('Kontoanlage in der App: Formular mit Namen und abweichender Passwortwiederholung', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(loggedIn: false);
    await _open(tester, app);
    await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Emil');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), 'sicher-genug');
    await tester.enterText(fields.at(3), 'anders');
    await tester.pumpAndSettle();
    expect(_semantics(tester), _expectedInApp);
    handle.dispose();
  });

  testWidgets('Kontoanlage beim Anbieter ohne Registrierung: Hinweis, Webseite, Element, Download', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(loggedIn: false);
    app.server.registrationMode = RegistrationMode.disabled;
    app.element.installed = false;
    await _open(tester, app);
    await tester.tap(find.text('Element starten'));
    await tester.pumpAndSettle();
    expect(_semantics(tester), _expectedExternal);
    handle.dispose();
  });
}

const List<String> _expectedInApp = <String>[
  'L=Wie heißt du? V=Emil textfield tap',
  'L=Dein Benutzername V=emil textfield tap',
  'L=Der Benutzername ist frei.',
  'L=Passwort V=•••••••••••• textfield obscured tap',
  'T=Passwort anzeigen button tap',
  'L=Mindestens 8 Zeichen. Mit Benutzername und Passwort meldest du dich später auch auf einem neuen Gerät an.',
  'L=Passwort wiederholen V=•••••• H=Die Passwörter stimmen nicht überein. textfield obscured tap',
  'L=Die Passwörter stimmen nicht überein.',
  'L=Konto erstellen button disabled',
  'L=Ich habe schon ein Konto button tap',
  'L=Dein Konto liegt bei fake.test. live',
  'L=Minimiert live',
  'L=Erweitert H=Minimiert tap',
];

const List<String> _expectedExternal = <String>[
  'L=Bei fake.test kann die App kein Konto anlegen. Erstelle es auf der Webseite des Anbieters und melde dich danach hier an.',
  'L=Webseite öffnen button tap',
  'L=Element starten button tap',
  'L=Ich habe ein Konto – anmelden button tap',
  'L=Element ist nicht installiert. Du kannst es hier laden und dort ein Konto beim Server fake.test anlegen. Danach hier „Ich habe ein Konto – anmelden“ wählen. live',
  'L=Element laden button tap',
  'L=Ich habe schon ein Konto button tap',
  'L=Dein Konto liegt bei fake.test. live',
  'L=Minimiert live',
  'L=Erweitert H=Minimiert tap',
];
