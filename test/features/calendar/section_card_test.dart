import 'package:family_nexus/features/calendar/calendar_screen.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #274: Die Aktion der Kartenkopfzeile bleibt am Handy rechtsbündig (kein Wrap, der auf Inhaltsbreite schrumpft).
void main() {
  testWidgets('SectionCard: Aktion endet rechts an der Karte, Titel links', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: SectionCard(title: 'Titel', trailing: const Text('Aktion'), child: const SizedBox(height: 10)),
      ),
    ));
    final title = tester.getRect(find.text('Titel'));
    final action = tester.getRect(find.text('Aktion'));
    final card = tester.getRect(find.byType(SectionCard));
    expect(title.left - card.left, lessThan(40));
    expect(card.right - action.right, lessThan(40));
    expect(action.left - title.right, greaterThan(100));
  });
}
