import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
import '../support/test_app.dart';

/// #347: Einführungstour nach der Einrichtung: genau einmal, überspringbar, in den Einstellungen wiederholbar.
void main() {
  group('Einstellung tourSeen', () {
    test('Standard: nicht gesehen; Speichern und Lesen', () {
      expect(const AppSettings().tourSeen, isFalse);
      final back = AppSettings.fromMap(const AppSettings().copyWith(tourSeen: true).toMap());
      expect(back.tourSeen, isTrue);
      expect(AppSettings.fromMap(const <String, String>{'tourSeen': 'kaputt'}).tourSeen, isFalse);
    });

    test('bestehende Einrichtung ohne den Schlüssel (Stand vor #347) bekommt die Tour nicht, neue schon', () {
      expect(AppSettings.fromMap(const <String, String>{'onboardingDone': 'true'}).tourSeen, isTrue);
      expect(AppSettings.fromMap(const <String, String>{}).tourSeen, isFalse);
      expect(AppSettings.fromMap(const <String, String>{'onboardingDone': 'true', 'tourSeen': 'false'}).tourSeen, isFalse);
    });
  });

  Future<void> start(WidgetTester tester, TestApp app) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
  }

  testWidgets('erster Start: Tour mit drei Schritten, danach lokal als gesehen gespeichert', (tester) async {
    final app = await buildTestApp(tourSeen: false);
    await start(tester, app);
    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    expect(find.text('Kalender'), findsWidgets);
    expect(find.text('Überspringen'), findsOneWidget);
    expect(find.text('Zurück'), findsNothing);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 2 von 3'), findsOneWidget);
    expect(find.text('Zurück'), findsOneWidget);
    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 1 von 3'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 3 von 3'), findsOneWidget);
    expect(find.text('Überspringen'), findsNothing);
    expect(app.services.settings.settings.tourSeen, isFalse, reason: 'erst nach dem Beenden');
    await tester.tap(find.text('Los geht’s'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Schritt'), findsNothing);
    expect(app.services.settings.settings.tourSeen, isTrue);
    expect(app.store.data['tourSeen'], 'true');
  });

  testWidgets('Überspringen zählt als gesehen', (tester) async {
    final app = await buildTestApp(tourSeen: false);
    await start(tester, app);
    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Schritt'), findsNothing);
    expect(app.services.settings.settings.tourSeen, isTrue);
  });

  testWidgets('bereits gesehen: keine Tour; Einstellungen: erneut ansehen', (tester) async {
    final app = await buildTestApp();
    await start(tester, app);
    expect(find.textContaining('Schritt'), findsNothing);
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Einführung erneut ansehen'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Einführung erneut ansehen'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Schritt'), findsNothing);
    expect(app.services.settings.settings.tourSeen, isTrue);
  });

  testWidgets('englisch, Screenreader-Ansage und große Schrift ohne Überlauf', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(lang: 'en', tourSeen: false);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Step 1 of 3\. Calendar\.')), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
