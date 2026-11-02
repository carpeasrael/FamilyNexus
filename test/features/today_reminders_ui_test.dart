import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/features/calendar/calendar_screen.dart';
import 'package:family_nexus/features/calendar/event_detail_screen.dart';
import 'package:family_nexus/features/reminders/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #218: „Heute“ zeigt höchstens drei Termine; Erinnerungen in einer Übersicht ansehen und bestätigen.
void main() {
  late DateTime now;

  setUp(() => now = DateTime.utc(2026, 3, 20, 10));

  Future<TestApp> open(WidgetTester tester, {bool withReminders = true}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(clock: () => now, withReminders: withReminders);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> make(WidgetTester tester, TestApp app, String title, DateTime start) async {
    await app.services.calendar!.create(title: title, start: start, end: start.add(const Duration(minutes: 30)), visibility: EventVisibility.private);
    await tester.pump(const Duration(milliseconds: 500)); // Neuplanung (Entprellung)
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> overview(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Übersicht'));
    await tester.pumpAndSettle();
  }

  group('Nächste Termine', () {
    testWidgets('höchstens drei, in zeitlicher Reihenfolge', (tester) async {
      final app = await open(tester);
      for (var i = 1; i <= 5; i++) {
        await make(tester, app, 'T$i', DateTime.utc(2026, 3, 20, 10 + i));
      }
      for (final t in <String>['T1', 'T2', 'T3']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('T4'), findsNothing);
      expect(find.text('T5'), findsNothing);
    });

    testWidgets('„Alle Termine“ öffnet die Agenda ab heute, auch nach Blättern im Kalender', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'Bald', DateTime.utc(2026, 3, 20, 12));
      await tab(tester, 'Kalender');
      await tester.tap(find.byTooltip('Weiter'));
      await tester.tap(find.byTooltip('Weiter'));
      await tester.pumpAndSettle();
      await tab(tester, 'Heute');
      await tester.tap(find.widgetWithText(TextButton, 'Alle Termine'));
      await tester.pumpAndSettle();
      final seg = tester.widget<SegmentedButton<CalendarMode>>(find.byType(SegmentedButton<CalendarMode>));
      expect(seg.selected, <CalendarMode>{CalendarMode.agenda});
      expect(find.text('Bald'), findsOneWidget);

      // Zweites Mal: nach Wechsel in den Monat wirkt der Knopf erneut.
      await tester.tap(find.text('Monat'));
      await tester.pumpAndSettle();
      await tab(tester, 'Heute');
      await tester.tap(find.widgetWithText(TextButton, 'Alle Termine'));
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<CalendarMode>>(find.byType(SegmentedButton<CalendarMode>)).selected, <CalendarMode>{CalendarMode.agenda});
    });
  });

  group('Erinnerungen', () {
    testWidgets('Karte zählt fällige; Übersicht zeigt Fällig und Geplant; Bestätigen entfernt und ruft dismiss', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'Arzt', DateTime.utc(2026, 3, 20, 10, 5)); // 10 Min vorher: fällig
      await make(tester, app, 'Später', DateTime.utc(2026, 3, 20, 12)); // geplant
      expect(find.text('1 Erinnerung fällig'), findsOneWidget);
      await overview(tester);
      expect(find.text('Fällig (1)'), findsOneWidget);
      expect(find.text('Geplant (1)'), findsOneWidget);
      expect(find.textContaining('10 Minuten vorher'), findsNWidgets(2));
      expect(find.text('Alle bestätigen'), findsNothing, reason: 'erst ab zwei fälligen');

      await tester.tap(find.byTooltip('Erinnerung an Arzt bestätigen'));
      await tester.pumpAndSettle();
      expect(find.text('Fällig (1)'), findsNothing);
      expect(app.scheduler.dismissed, hasLength(1));
      Navigator.of(tester.element(find.byType(RemindersScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('1 Erinnerung fällig'), findsNothing);
    });

    testWidgets('„Alle bestätigen“ bei zwei fälligen', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'A', DateTime.utc(2026, 3, 20, 10, 5));
      await make(tester, app, 'B', DateTime.utc(2026, 3, 20, 10, 8));
      expect(find.text('2 Erinnerungen fällig'), findsOneWidget);
      await overview(tester);
      await tester.tap(find.text('Alle bestätigen'));
      await tester.pumpAndSettle();
      expect(find.text('Fällig (2)'), findsNothing);
      expect(app.scheduler.dismissed, hasLength(2));
      expect(find.text('Keine Erinnerungen fällig oder geplant.'), findsOneWidget);
    });

    testWidgets('Tipp auf eine Erinnerung öffnet den Termin', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'Arzt', DateTime.utc(2026, 3, 20, 10, 5));
      await overview(tester);
      await tester.tap(find.text('Arzt'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsOneWidget);
    });

    testWidgets('Knopf trägt Beschriftung für den Screenreader', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await open(tester);
      await make(tester, app, 'Arzt', DateTime.utc(2026, 3, 20, 10, 5));
      await overview(tester);
      final node = tester.getSemantics(find.byTooltip('Erinnerung an Arzt bestätigen'));
      expect(node.getSemanticsData().tooltip, 'Erinnerung an Arzt bestätigen');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('leer', (tester) async {
      await open(tester);
      await overview(tester);
      expect(find.text('Keine Erinnerungen fällig oder geplant.'), findsOneWidget);
    });

    testWidgets('fällig wird es mit der Zeit, ohne Datenänderung', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'Arzt', DateTime.utc(2026, 3, 20, 10, 20));
      expect(find.textContaining('fällig'), findsNothing);
      now = DateTime.utc(2026, 3, 20, 10, 11);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('1 Erinnerung fällig'), findsOneWidget);
    });

    testWidgets('die offene Übersicht wird mit der Zeit aktualisiert', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'Arzt', DateTime.utc(2026, 3, 20, 10, 20));
      await overview(tester);
      expect(find.text('Geplant (1)'), findsOneWidget);
      now = DateTime.utc(2026, 3, 20, 10, 11);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Fällig (1)'), findsOneWidget);
      expect(find.text('Geplant (1)'), findsNothing);
    });

    testWidgets('T7 nach einer Auslösung ohne Datenänderung: Karte zählt geplant und fällig wie die Übersicht (#223)', (tester) async {
      final app = await open(tester);
      await make(tester, app, 'A', DateTime.utc(2026, 3, 20, 12));
      await make(tester, app, 'B', DateTime.utc(2026, 3, 20, 13));
      await make(tester, app, 'C', DateTime.utc(2026, 3, 20, 14));
      expect(find.text('3 Erinnerungen geplant'), findsOneWidget);
      now = DateTime.utc(2026, 3, 20, 11, 51); // erste Auslösung 11:50
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('2 Erinnerungen geplant'), findsOneWidget);
      expect(find.text('1 Erinnerung fällig'), findsOneWidget);
      await overview(tester);
      expect(find.text('Geplant (2)'), findsOneWidget);
      expect(find.text('Fällig (1)'), findsOneWidget);
    });

    testWidgets('im Browser keine Erinnerungskarte, „Alle Termine“ bleibt', (tester) async {
      await open(tester, withReminders: false);
      expect(find.text('Übersicht'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Alle Termine'), findsOneWidget);
    });
  });
}
