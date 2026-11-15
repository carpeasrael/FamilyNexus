import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

/// #445: Scheitert das Löschen eines Termins, nennt die Meldung das Löschen und nicht das Speichern. Erreichbar,
/// wenn der Termin bei offenem Löschdialog schon gelöscht wurde (z. B. auf einem anderen eigenen Gerät).
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

Future<void> _start(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _openAndAskToDelete(WidgetTester tester, String title) async {
  await tester.tap(navTab('Kalender'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Termin löschen'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget, reason: 'Der Löschdialog ist offen');
}

void _expectDeleteError() {
  expect(find.text('Der Termin konnte nicht gelöscht werden.'), findsOneWidget);
  expect(find.textContaining('gespeichert'), findsNothing);
}

void main() {
  testWidgets('Termin: bei offenem Dialog schon gelöscht → Meldung nennt das Löschen', (tester) async {
    final app = await buildTestApp(clock: () => _now);
    await _start(tester, app);
    final c = app.services.calendar!;
    final e = await c.create(
      title: 'Zahnarzt',
      start: DateTime.utc(2026, 3, 20, 14),
      end: DateTime.utc(2026, 3, 20, 15),
      visibility: EventVisibility.private,
    );
    await _openAndAskToDelete(tester, 'Zahnarzt');
    await c.delete(e.id);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'Der Dialog bleibt offen');
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
    _expectDeleteError();
  });

  testWidgets('Serie, „Nur dieses“: bei offenem Dialog schon gelöscht → Meldung nennt das Löschen', (tester) async {
    final app = await buildTestApp(clock: () => _now);
    await _start(tester, app);
    final c = app.services.calendar!;
    final e = await c.create(
      title: 'Turnen',
      start: DateTime.utc(2026, 3, 20, 14),
      end: DateTime.utc(2026, 3, 20, 15),
      visibility: EventVisibility.private,
      recurrence: const Recurrence(frequency: Frequency.weekly, interval: 1, weekdays: <int>{5}),
    );
    await _openAndAskToDelete(tester, 'Turnen');
    await c.delete(e.id);
    await tester.tap(find.widgetWithText(TextButton, 'Nur dieses'));
    await tester.pumpAndSettle();
    _expectDeleteError();
  });
}
