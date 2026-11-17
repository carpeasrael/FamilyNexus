import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
import '../support/test_app.dart';

/// #526, E-106: Einstellung „Lesebestätigung senden“ (Standard an) und der Abgleich der Lesestände bei Änderung.
void main() {
  Future<TestApp> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp();
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('Schalter steht unter „Online-Status teilen“, Standard an, erklärt Gegenseitigkeit und Grenzen', (tester) async {
    final app = await open(tester);
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Lesebestätigung senden'), 300, scrollable: find.byType(Scrollable).first);
    final online = tester.getTopLeft(find.text('Online-Status teilen')).dy;
    final receipts = tester.getTopLeft(find.text('Lesebestätigung senden')).dy;
    expect(receipts, greaterThan(online));
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Lesebestätigung senden')).value, isTrue);
    expect(app.services.settings.settings.shareReadReceipts, isTrue);
    expect(find.textContaining('nur private Lesemarker'), findsOneWidget);
    expect(find.textContaining('nicht zurücknehmen'), findsOneWidget);
  });

  testWidgets('Umschalten ändert die Einstellung und löst genau einen Abgleich aus, andere Einstellungen nicht', (tester) async {
    final app = await open(tester);
    expect(app.gateway.readStateRefreshes, 0);
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Lesebestätigung senden'), 300, scrollable: find.byType(Scrollable).first);

    await tester.tap(find.text('Lesebestätigung senden'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.shareReadReceipts, isFalse);
    expect(app.gateway.readStateRefreshes, 1);

    await tester.tap(find.text('Online-Status teilen'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.shareOnlineStatus, isFalse);
    expect(app.gateway.readStateRefreshes, 1, reason: 'andere Einstellungen stoßen nichts an');

    await tester.tap(find.text('Lesebestätigung senden'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.shareReadReceipts, isTrue);
    expect(app.gateway.readStateRefreshes, 2);
  });
}
