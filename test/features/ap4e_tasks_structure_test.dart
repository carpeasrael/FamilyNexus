import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/tasks/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

/// AP-4e: Die Zerlegung von `TaskDetailScreen.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
Future<void> _openTasks(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Aufgabenliste: Übersicht und Detail mit Beschreibung, einer erledigten Aufgabe und Verlauf', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(clock: () => DateTime.utc(2026, 10, 22, 8));
    await _openTasks(tester, app);
    await tester.tap(find.byTooltip('Neue Aufgabenliste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'Haushalt');
    await tester.enterText(find.widgetWithText(TextField, 'Punkte (einer pro Zeile)'), 'Müll raus\nSpülmaschine');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haushalt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kommentar (optional)'), 'Schon am Morgen');
    await tester.tap(find.widgetWithText(FilledButton, 'Erledigt'));
    await tester.pumpAndSettle();
    final detail = semanticsSnapshot(tester, find.byType(TaskDetailScreen));
    expect(detail, _expectedDetail);
    handle.dispose();
  });
}

const List<String> _expectedDetail = <String>[
  'L=Zugewiesen an dich',
  'L=Täglich · Startet jeden Tag um Mitternacht neu',
  'L=Nächster Neustart: Freitag, 23. Oktober 2026',
  'L=1 von 2 erledigt',
  'L=Erledigung von Müll raus zurücknehmen | Müll raus | Erledigt am 22.10.2026 um hh:mm | Schon am Morgen checked tap',
  'L=Spülmaschine als erledigt markieren | Spülmaschine tap',
  'L=Verlauf',
  'L=Müll raus erledigt | Du · 22.10.2026, hh:mm | Schon am Morgen',
  'L=Zurück T=Zurück button tap',
  'L=Haushalt',
  'T=Aufgabenliste bearbeiten button tap',
  'T=Liste löschen button tap',
];
