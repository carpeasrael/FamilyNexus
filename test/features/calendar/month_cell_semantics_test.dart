import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/test_app.dart';

/// #463: Die Screenreader-Beschriftung der Monatszellen nennt das volle Datum nach App-Sprache
/// (nicht fest „20. …“ ohne Monat), sodass Tage des Nachbarmonats eindeutig sind.
final DateTime _now = DateTime.utc(2026, 3, 20, 10); // 11:00 in Berlin

Future<TestApp> _seededApp(String lang) async {
  final app = await buildTestApp(clock: () => _now, lang: lang);
  final c = await app.services.calendarBuilder!('@anna:fake.test', null);
  await c.service.create(
    title: 'Zahnarzt',
    start: DateTime.utc(2026, 3, 20, 13),
    end: DateTime.utc(2026, 3, 20, 14),
    timeZone: 'Europe/Berlin',
    visibility: EventVisibility.shared,
  );
  c.dispose();
  return app;
}

Future<void> _openCalendar(WidgetTester tester, TestApp app, String tab) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab(tab));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('de: Monatszellen nennen volles Datum, Anzahl und Heute', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _seededApp('de');
    await _openCalendar(tester, app, 'Kalender');

    final today = find.bySemanticsLabel('Freitag, 20. März 2026, 1 Termin, Heute');
    expect(today, findsOneWidget);
    expect(tester.getSemantics(today), isSemantics(isButton: true, isSelected: true));

    final empty = find.bySemanticsLabel('Samstag, 21. März 2026, Keine Termine');
    expect(empty, findsOneWidget);
    expect(tester.getSemantics(empty), isSemantics(isButton: true, isSelected: false));

    // Nachbarmonat: 1. März und 1. April sind unterscheidbar.
    expect(find.bySemanticsLabel('Sonntag, 1. März 2026, Keine Termine'), findsOneWidget);
    expect(find.bySemanticsLabel('Mittwoch, 1. April 2026, Keine Termine'), findsOneWidget);

    // Altes Muster „20. …“ kommt nicht mehr vor.
    expect(find.bySemanticsLabel(RegExp(r'^\d{1,2}\. ')), findsNothing);
    handle.dispose();
  });

  testWidgets('en: Monatszellen nennen volles Datum auf Englisch', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _seededApp('en');
    await _openCalendar(tester, app, 'Calendar');

    final today = find.bySemanticsLabel('Friday, March 20, 2026, 1 event, Today');
    expect(today, findsOneWidget);
    expect(tester.getSemantics(today), isSemantics(isButton: true, isSelected: true));

    final empty = find.bySemanticsLabel('Saturday, March 21, 2026, No events');
    expect(empty, findsOneWidget);
    expect(tester.getSemantics(empty), isSemantics(isButton: true, isSelected: false));

    expect(find.bySemanticsLabel(RegExp(r'^\d{1,2}\. ')), findsNothing);
    handle.dispose();
  });

  testWidgets('en: Tage des Nachbarmonats nennen ihren eigenen Monat (Szenario #463)', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _seededApp('en');
    await _openCalendar(tester, app, 'Calendar');

    expect(find.bySemanticsLabel('Sunday, March 1, 2026, No events'), findsOneWidget);
    expect(find.bySemanticsLabel('Wednesday, April 1, 2026, No events'), findsOneWidget);
    expect(find.bySemanticsLabel('Saturday, February 28, 2026, No events'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('de: Auswahl wechselt, Label bleibt gleich', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _seededApp('de');
    await _openCalendar(tester, app, 'Kalender');

    const otherLabel = 'Samstag, 21. März 2026, Keine Termine';
    const todayLabel = 'Freitag, 20. März 2026, 1 Termin, Heute';
    await tester.tap(find.bySemanticsLabel(otherLabel));
    await tester.pumpAndSettle();

    final other = find.bySemanticsLabel(otherLabel);
    expect(other, findsOneWidget);
    expect(tester.getSemantics(other), isSemantics(isButton: true, isSelected: true));

    final today = find.bySemanticsLabel(todayLabel);
    expect(today, findsOneWidget);
    expect(tester.getSemantics(today), isSemantics(isButton: true, isSelected: false));
    handle.dispose();
  });
}
