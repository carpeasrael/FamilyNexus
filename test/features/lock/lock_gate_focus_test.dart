import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/test_app.dart';

/// #298: Die App-Sperre schließt auch den Tastaturfokus des verdeckten Inhalts aus.
Future<TestApp> _open(WidgetTester tester) async {
  final app = await buildTestApp(lockEnabled: true);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle(); // Start gesperrt, Geräteabfrage gelingt, entsperrt
  expect(app.services.lock.locked, isFalse);
  await tester.tap(navTab('Chat'));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('Sperren entzieht dem Chatfeld den Fokus; Tastatur erreicht den Inhalt nicht', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull);

    app.auth.succeed = false;
    app.services.lock.lockNow();
    await tester.pumpAndSettle();
    expect(find.text('FamilyNexus ist gesperrt'), findsOneWidget);

    final primary = FocusManager.instance.primaryFocus;
    expect(primary?.context?.findAncestorWidgetOfExactType<TextField>(), isNull, reason: 'Fokus nicht im Inhalt');

    // Blind getippt: Text und Enter dürfen das verdeckte Feld nicht erreichen.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField, skipOffstage: false).last);
    expect(field.controller?.text ?? '', isEmpty);
  });

  testWidgets('ExcludeFocus allein: das verdeckte Feld kann den Fokus nicht anfordern', (tester) async {
    final app = await _open(tester);
    final input = tester.state<EditableTextState>(find.byType(EditableText).last).widget.focusNode;
    app.auth.succeed = false;
    app.services.lock.lockNow();
    await tester.pumpAndSettle();
    input.requestFocus();
    await tester.pumpAndSettle();
    expect(input.hasFocus, isFalse, reason: 'gesperrter Inhalt nimmt keinen Fokus an');
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
  });

  testWidgets('Tab bleibt auf dem Sperrbildschirm, Entsperren stellt den Inhalt wieder her', (tester) async {
    final app = await _open(tester);
    app.auth.succeed = false;
    app.services.lock.lockNow();
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ctx = FocusManager.instance.primaryFocus?.context;
      expect(ctx?.findAncestorWidgetOfExactType<TextField>(), isNull, reason: 'Tab $i erreicht das verdeckte Feld');
      expect(ctx?.findAncestorWidgetOfExactType<NavigationBar>(), isNull);
    }
    app.auth.succeed = true;
    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();
    expect(find.text('FamilyNexus ist gesperrt'), findsNothing);
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull,
        reason: 'Inhalt nach Entsperren wieder fokussierbar');
  });
}
