import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
import '../support/test_app.dart';

/// #145: Im Browser gibt es keine Erinnerungen (E-53, `services.reminders == null`). Dann bietet die App sie
/// auch nicht an: weder in den Einstellungen noch im Termin-Editor, in der Detailansicht oder auf „Heute“.
void main() {
  final now = DateTime.utc(2026, 3, 20, 10);

  Future<TestApp> start(WidgetTester tester, {required bool withReminders}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(clock: () => now, withReminders: withReminders);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    expect(app.services.reminders == null, !withReminders, reason: 'Koordinator entsteht mit dem Öffnen des Kalenders');
    return app;
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(name)));
    await tester.pumpAndSettle();
  }

  for (final withReminders in [true, false]) {
    final label = withReminders ? 'mit Koordinator' : 'ohne Koordinator (Browser)';

    testWidgets('Heute: Erinnerungs-Karte $label', (tester) async {
      await start(tester, withReminders: withReminders);
      expect(find.text('Keine Erinnerung geplant'), withReminders ? findsOneWidget : findsNothing);
    });

    testWidgets('Einstellungen: Abschnitt „Erinnerungen“ $label', (tester) async {
      await start(tester, withReminders: withReminders);
      await openSettings(tester);
      // Die Liste baut ihre Einträge lazy: ans Ende scrollen, damit der Abschnitt gebaut ist, falls es ihn gibt.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text('Erinnerungen'), withReminders ? findsOneWidget : findsNothing);
    });

    testWidgets('Termin-Editor: Erinnerungs-Karte $label', (tester) async {
      await start(tester, withReminders: withReminders);
      await tab(tester, 'Kalender');
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      expect(find.text('Erinnerungen'), withReminders ? findsOneWidget : findsNothing);
      expect(find.byType(FilterChip), withReminders ? findsWidgets : findsNothing);
    });

    testWidgets('Detailansicht: „Deine Erinnerungen“ $label', (tester) async {
      final app = await start(tester, withReminders: withReminders);
      await app.services.calendar!.create(
        title: 'Schwimmen',
        start: DateTime.utc(2026, 3, 21, 8),
        end: DateTime.utc(2026, 3, 21, 9),
        visibility: EventVisibility.shared,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schwimmen').first);
      await tester.pumpAndSettle();
      expect(find.text('Deine Erinnerungen'), withReminders ? findsOneWidget : findsNothing);
    });
  }
}
