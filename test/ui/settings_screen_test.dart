import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_services.dart';
import '../support/memory_stores.dart';
import '../support/nav.dart';
import '../support/test_app.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(AppServices, NoopScreenProtection)> _services({String? lang}) async {
  final app = await buildTestApp(lang: lang);
  return (app.services, app.protection);
}

void main() {
  testWidgets('fünf Tabs und Burger-Menü auf Deutsch', (tester) async {
    final (services, _) = await _services(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    for (final t in <String>['Heute', 'Kalender', 'Chat', 'Einkauf', 'Familie']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Einstellungen')), findsNothing, reason: 'Einstellungen liegen im Menü oben rechts');
    expect(find.byTooltip('Menü öffnen'), findsOneWidget);
  });

  testWidgets('Sprachumschaltung wirkt sofort', (tester) async {
    final (services, _) = await _services(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Sprache'), findsOneWidget);
    await services.settings.update((s) => s.copyWith(languageCode: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Reduce effects'), findsOneWidget);
  });

  testWidgets('„Effekte reduzieren“ wird übernommen', (tester) async {
    final (services, _) = await _services(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.tap(find.text('Effekte reduzieren'));
    await tester.pumpAndSettle();
    expect(services.settings.settings.reduceEffects, isTrue);
  });

  testWidgets('Bildschirmschutz ist standardmäßig aktiv und schaltbar', (tester) async {
    final (services, protection) = await _services(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    expect(protection.last, isTrue);
    await services.settings.update((s) => s.copyWith(secureScreen: false));
    await tester.pump();
    expect(protection.last, isFalse);
  });

  testWidgets('Konto: zeigt Server und Benutzer, Abmelden führt zur Einrichtung', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('fake.test'), findsOneWidget);
    expect(find.text('@anna:fake.test'), findsOneWidget);
    await tester.ensureVisible(find.text('Abmelden'));
    await tester.tap(find.widgetWithText(ListTile, 'Abmelden'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Abmelden'));
    await tester.pumpAndSettle();
    expect(app.gateway.session.name, 'loggedOut');
    expect(app.scheduler.cancelled, greaterThan(0), reason: 'geplante Erinnerungen werden bei Abmeldung entfernt');
    expect(find.textContaining('Schritt 1 von 3'), findsOneWidget, reason: 'Abgemeldet: zurück zu „Anmelden“');
  });

  testWidgets('Datenschutzerklärung ist erreichbar (de)', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.text('Datenschutzerklärung'));
    await tester.tap(find.text('Datenschutzerklärung'));
    await tester.pumpAndSettle();
    expect(find.text('Wer verarbeitet deine Daten?'), findsOneWidget);
    expect(find.textContaining('keine Telemetrie'), findsOneWidget);
  });

  testWidgets('Alle lokalen Daten löschen: nur nach Bestätigung', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(lang: 'de');
    var resets = 0;
    app.services.onFullReset = () async => resets++;
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.text('Alle lokalen Daten löschen'));
    await tester.tap(find.text('Alle lokalen Daten löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Alle lokalen Daten löschen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    await tester.tap(find.text('Alle lokalen Daten löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endgültig löschen'));
    await tester.pumpAndSettle();
    expect(resets, 1);
  });

  testWidgets('Burger-Menü: Einstellungen und Datenschutz öffnen als eigene Seiten mit Zurück', (tester) async {
    final (services, _) = await _services(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menü öffnen'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Einstellungen'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Datenschutzerklärung'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Datenschutzerklärung'));
    await tester.pumpAndSettle();
    expect(find.text('Wer verarbeitet deine Daten?'), findsOneWidget);
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Sprache'), findsOneWidget);
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Akzentfarbe wählbar: Standard Türkis, Wechsel färbt die Oberfläche und bleibt gespeichert', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (services, _) = await _services(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle();
    expect(services.settings.settings.accent, AccentChoice.teal);
    await openSettings(tester);
    expect(find.text('Akzentfarbe'), findsOneWidget);
    for (final n in <String>['Türkis', 'Magenta', 'Violett', 'Himmelblau', 'Limette', 'Orange', 'Rosé', 'Grün']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    Color primary() => AuroraTokens.of(tester.element(find.text('Akzentfarbe'))).primary;
    final before = primary();
    await tester.tap(find.text('Magenta'));
    await tester.pumpAndSettle();
    expect(services.settings.settings.accent, AccentChoice.magenta);
    expect(primary(), isNot(before));
    expect(primary(), AccentPalette.of(AccentChoice.magenta).neon, reason: 'dunkles Design (Standard) nutzt die leuchtende Variante');
    expect(find.byIcon(Icons.check), findsWidgets, reason: 'Auswahl zusätzlich zur Farbe mit Häkchen');
  });
}
