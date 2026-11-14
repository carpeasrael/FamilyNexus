
import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

Future<void> _open(WidgetTester tester, TestApp app, String lang, double scale) async {
  await app.services.settings.update((st) => st.copyWith(languageCode: lang));
  tester.view.physicalSize = const Size(390, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(scale)),
    child: FamilyNexusApp(services: app.services),
  ));
  await tester.pumpAndSettle();
  await tester.tap(navTab(lang == 'de' ? 'Kalender' : 'Calendar'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(lang == 'de' ? 'Neuer Termin' : 'New event'));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in <String>['de', 'en']) {
    for (final allDay in <bool>[false, true]) {
      testWidgets('Beschriftung einzeilig bei 2,0: $lang ganztägig=$allDay', (tester) async {
        final app = await buildTestApp();
        await _open(tester, app, lang, 2.0);
        if (allDay) {
          await tester.tap(find.text(lang == 'de' ? 'Ganztägig' : 'All day'));
          await tester.pumpAndSettle();
        }
        for (final label in lang == 'de' ? <String>['Beginn', 'Ende'] : <String>['Start', 'End']) {
          final f = find.text(label);
          expect(f, findsOneWidget);
          final style = DefaultTextStyle.of(tester.element(f)).style;
          final p = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr, textScaler: const TextScaler.linear(2.0))..layout();
          final size = tester.getSize(f);
          // ignore: avoid_print
          print('$lang $allDay $label size=$size soll=${p.size}');
          expect(size.height, p.height, reason: '$label einzeilig');
          expect(size.width, greaterThanOrEqualTo(p.width));
          final row = find.ancestor(of: f, matching: find.byType(Padding)).first;
          final btn = find.descendant(of: row, matching: find.byType(OutlinedButton)).first;
          // ignore: avoid_print
          print('  btn=${tester.getRect(btn)} label=${tester.getRect(f)}');
          expect(tester.getRect(f).bottom, lessThanOrEqualTo(tester.getRect(btn).top));
          expect(tester.getSize(btn).width, greaterThan(0));
        }
        final ex = tester.takeException();
        // ignore: avoid_print
        print('exception: $ex');
        expect(ex, isNull);
      });
    }
  }

  testWidgets('Skalierung 1,0: Beschriftung links neben dem Datumsknopf', (tester) async {
    final app = await buildTestApp();
    await _open(tester, app, 'de', 1.0);
    final f = find.text('Beginn');
    final row = find.ancestor(of: f, matching: find.byType(Padding)).first;
    final btn = find.descendant(of: row, matching: find.byType(OutlinedButton)).first;
    expect(tester.getRect(f).right, lessThanOrEqualTo(tester.getRect(btn).left));
    expect((tester.getRect(f).center.dy - tester.getRect(btn).center.dy).abs(), lessThan(8));
  });
}
