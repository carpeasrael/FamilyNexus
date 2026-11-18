import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Öffnet über das Burger-Menü (rechts oben) die Einstellungen.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Einstellungen'));
  await tester.pumpAndSettle();
}

/// Öffnet über das Burger-Menü die Familie (eigene Seite mit Zurück-Pfeil, E-105).
Future<void> openFamily(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Familie'));
  await tester.pumpAndSettle();
}

/// Schritt „Anbieter wählen“ der Einrichtung (E-108, #545): bestätigt den vorgewählten Anbieter mit „Weiter“. Erwartet, dass
/// der Schritt sichtbar ist (Neu und Anmelden von der Startseite aus, ohne Einladung).
Future<void> continueFromServerStep(WidgetTester tester) async {
  expect(find.text('Anbieter wählen'), findsOneWidget, reason: 'Schritt „Anbieter wählen“ erwartet');
  await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
  await tester.pumpAndSettle();
}
