import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Future<void> _pump(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

bool _keyboardOpen(WidgetTester tester) => tester.testTextInput.isVisible;

/// Issue #2: Auf dem iPhone ließ sich die Bildschirmtastatur nicht mehr schließen.
void main() {
  final mobile = TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android});
  testWidgets('Tippen außerhalb des Textfelds schließt die Tastatur', (tester) async {
    final app = await buildTestApp(loggedIn: false);
    await _pump(tester, app);
    await tester.tap(find.text('Neue Familie gründen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'Wie heißt du?'));
    await tester.pump();
    expect(_keyboardOpen(tester), isTrue);
    await tester.tapAt(const Offset(450, 1900)); // freie Fläche unten
    await tester.pumpAndSettle();
    expect(_keyboardOpen(tester), isFalse);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()));
  }, variant: mobile);

  testWidgets('Chat: Senden lässt die Tastatur offen, Wischen im Verlauf schließt sie', (tester) async {
    final app = await buildTestApp();
    for (var i = 0; i < 30; i++) {
      await app.gateway.sendMessage('Nachricht $i');
    }
    await _pump(tester, app);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Hallo');
    await tester.tap(find.byTooltip('Senden'));
    await tester.pumpAndSettle();
    expect(app.gateway.messages.last.body, 'Hallo');
    expect(_keyboardOpen(tester), isTrue, reason: 'weiterschreiben ohne erneutes Antippen');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(_keyboardOpen(tester), isFalse);
  }, variant: mobile);
}
