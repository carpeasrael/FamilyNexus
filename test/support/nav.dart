import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Öffnet über das Burger-Menü (rechts oben) die Einstellungen.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Einstellungen'));
  await tester.pumpAndSettle();
}
