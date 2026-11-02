import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
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

  testWidgets('#117 Desktop: Enter ändert im letzten Feld das Passwort, vorher springt es weiter', (tester) async {
    final app = await _open(tester, 'Familie');
    await openSettings(tester);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Passwort ändern'));
    await tester.tap(find.widgetWithText(ListTile, 'Passwort ändern'));
    await tester.pumpAndSettle();
    await _type(tester, find.widgetWithText(TextField, 'Aktuelles Passwort'), 'geheim123');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await _type(tester, find.widgetWithText(TextField, 'Neues Passwort'), 'neu-und-lang');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(app.server.passwordChangeCalls, 0, reason: 'bewusste Abweichung von #68: erst das letzte Feld sendet');
    await _type(tester, find.widgetWithText(TextField, 'Passwort wiederholen'), 'neu-und-lang');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(app.server.passwordOf('@anna:fake.test'), 'neu-und-lang');
  }, variant: desktop);

  testWidgets('#68 Desktop: Enter speichert im Dialog „Familienname ändern“', (tester) async {
    final app = await _open(tester, 'Familie');
    await tester.tap(find.byTooltip('Familienname ändern'));
    await tester.pumpAndSettle();
    await _type(tester, find.widgetWithText(TextField, 'Name der Familie'), 'Neue Familie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.gateway.family!.name, 'Neue Familie');
  }, variant: desktop);

  testWidgets('#68 Desktop: Enter speichert im Einkauf „Bearbeiten“ (Name und Menge)', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await _type(tester, find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Brot');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    for (final (field, value) in <(int, String)>[(0, 'Vollkornbrot'), (1, '2 Stück')]) {
      await tester.tap(find.byTooltip(field == 0 ? 'Brot' : 'Vollkornbrot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      final f = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(field);
      await _type(tester, f, value);
      await tester.testTextInput.receiveAction(field == 0 ? TextInputAction.next : TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: 'Feld $field: Enter schließt und speichert');
    }
    final item = app.shoppingStore.items.values.single;
    expect((item.title, item.quantity), ('Vollkornbrot', '2 Stück'));
  }, variant: desktop);

  testWidgets('#211 Desktop: Enter in Menge und Gruppe fügt hinzu, nimmt den getippten Text und keinen Vorschlag', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await app.services.shopping!.add('Eier', group: 'Aldi');
    await tester.pumpAndSettle();
    await _type(tester, find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Mehl');
    await _type(tester, find.byType(TextField).at(2), 'Al');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(app.shoppingStore.items.values.map((i) => (i.title, i.group)), contains(('Mehl', 'Al')));

    await _type(tester, find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Salz');
    await _type(tester, find.byType(TextField).at(1), '1 kg');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(app.shoppingStore.items.values.map((i) => (i.title, i.quantity)), contains(('Salz', '1 kg')));
  }, variant: desktop);

  testWidgets('#211 Desktop: Tab führt von Titel über Menge zur Gruppe', (tester) async {
    await _open(tester, 'Einkauf');
    await tester.tap(find.widgetWithText(TextField, 'Was wird gebraucht?'));
    await tester.pump();
    bool focused(int i) => tester.widget<EditableText>(find.descendant(of: find.byType(TextField).at(i), matching: find.byType(EditableText))).focusNode.hasFocus;
    expect(focused(0), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(1), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(2), isTrue);
  }, variant: desktop);

  testWidgets('#211 Desktop: Enter im Gruppenfeld speichert im Dialog', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await app.services.shopping!.add('Brot');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Brot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    await _type(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(2), 'Bäcker');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.shoppingStore.items.values.single.group, 'Bäcker');
  }, variant: desktop);

  testWidgets('#211 Mobil: „Weiter“ in der Menge springt zur Gruppe, „Fertig“ dort fügt hinzu', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await _type(tester, find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Milch');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final qty = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(qty).textInputAction, TextInputAction.next);
    await tester.enterText(qty, '2 l');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(app.shoppingStore.items, isEmpty, reason: '„Weiter“ fügt nichts hinzu');
    final group = find.byType(TextField).at(2);
    expect(tester.widget<EditableText>(find.descendant(of: group, matching: find.byType(EditableText))).focusNode.hasFocus, isTrue);
    await tester.enterText(group, 'Rewe');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final item = app.shoppingStore.items.values.single;
    expect((item.title, item.quantity, item.group), ('Milch', '2 l', 'Rewe'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('#211 Mobil: Im Dialog springt „Weiter“ zur Gruppe, „Fertig“ dort speichert', (tester) async {
    final app = await _open(tester, 'Einkauf');
    await app.services.shopping!.add('Brot');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Brot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await _type(tester, fields.at(1), '2');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget, reason: '„Weiter“ speichert nicht');
    await tester.enterText(fields.at(2), 'Bäcker');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final item = app.shoppingStore.items.values.single;
    expect((item.quantity, item.group), ('2', 'Bäcker'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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
