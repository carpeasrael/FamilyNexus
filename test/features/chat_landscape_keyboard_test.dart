import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

/// #548 (Lauf 36, B-25): Querformat eines Handys mit eingeblendeter Tastatur lässt nur etwa 100 dp Höhe
/// für den Chat. Kopfzeile und Verschlüsselungshinweis dürfen die Eingabeleiste dann nicht überlaufen lassen.
void main() {
  Future<void> openChat(WidgetTester tester, Size size, double keyboard) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    final app = await buildTestApp();
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Chat'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
  }

  for (final free in <double>[200, 160, 130]) {
    const h = 412.0;
    testWidgets('Querformat, ${free.toInt()} dp über der Tastatur: kein Überlauf, Eingabefeld sichtbar (#548)', (tester) async {
      await openChat(tester, const Size(915, h), h - free);
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(free + 0.5), reason: 'Eingabefeld über der Tastatur');
      expect(field.height, greaterThan(0));
    });
  }

  testWidgets('knapp: Hinweis weg, mit Tastatur weg wieder da', (tester) async {
    await openChat(tester, const Size(915, 412), 412 - 130);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('Fokus im Eingabefeld bleibt, wenn die Tastatur den Hinweis verdrängt', (tester) async {
    await openChat(tester, const Size(915, 412), 0);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Entwurf');
    final focus = FocusManager.instance.primaryFocus;
    tester.view.viewInsets = const FakeViewPadding(bottom: 412 - 130);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(focus), reason: 'Eingabefeld nicht neu aufgebaut');
    expect(find.text('Entwurf'), findsOneWidget);
  });

  testWidgets('mit viel Platz bleibt der Verschlüsselungshinweis sichtbar', (tester) async {
    await openChat(tester, const Size(412, 915), 0);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
