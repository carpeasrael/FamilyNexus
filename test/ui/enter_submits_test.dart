import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #37: Auf dem Desktop schickt Enter ab (Chat senden, Einkauf hinzufügen); Umschalt+Enter macht im
/// Chat keinen Versand. Mobil bleibt die Tastatur-Aktion unverändert.
Future<TestApp> _open(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = await buildTestApp();
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  final desktop = TargetPlatformVariant(<TargetPlatform>{TargetPlatform.linux, TargetPlatform.windows, TargetPlatform.macOS});

  testWidgets('Desktop: Enter sendet im Chat, Umschalt+Enter nicht', (tester) async {
    final app = await _open(tester, 'Chat');
    final field = find.byType(TextField);
    await _type(tester, field, 'Hallo Testfamilie');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(app.gateway.messages, isEmpty, reason: 'Umschalt+Enter: Zeilenumbruch statt Senden');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(app.gateway.messages.single.body, 'Hallo Testfamilie');
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
  }, variant: desktop);

  testWidgets('Desktop: Enter im Feld „Was wird gebraucht?“ fügt hinzu', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await _type(tester, find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Milch');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(app.shoppingStore.items.values.single.title, 'Milch');
  }, variant: desktop);

  testWidgets('Mobil: „Weiter“ im Einkaufsfeld springt nur zur Menge, Enter sendet im Chat nicht', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await _type(tester, find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Milch');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(app.shoppingStore.items, isEmpty);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
    await tester.pumpAndSettle();
    await _type(tester, find.byType(TextField), 'Hallo');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(app.gateway.messages, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
