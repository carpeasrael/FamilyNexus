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
