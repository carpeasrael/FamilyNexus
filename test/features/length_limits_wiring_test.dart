import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/ui/widgets/length_limit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #221: Jedes betroffene Feld begrenzt mit dem Maß der Prüfung; Flutters Begrenzung bleibt auf dem
/// Standard, damit Screenreader die Höchstlänge weiter erfahren.
void _expectMeasured(WidgetTester tester, Finder field, int max, LengthMeasure measure) {
  final f = tester.widget<TextField>(field);
  final formatter = f.inputFormatters!.whereType<MeasuredLengthFormatter>().single;
  expect((formatter.max, formatter.measure, f.maxLength, f.maxLengthEnforcement), (max, measure, max, null));
}

Finder _in(Type parent, Finder field) => find.descendant(of: find.byType(parent), matching: field);

Future<TestApp> _start(WidgetTester tester, {String? tab}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = await buildTestApp(clock: () => DateTime.utc(2026, 3, 20, 10));
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
    await tester.pumpAndSettle();
  }
  return app;
}

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Einkauf: Eingabezeile und Bearbeiten-Dialog zählen Codepunkte', (tester) async {
    final app = await _start(tester, tab: 'Einkauf');
    _expectMeasured(tester, find.byType(TextField).at(0), ShoppingItem.maxTitle, LengthMeasure.codePoints);
    _expectMeasured(tester, find.byType(TextField).at(1), ShoppingItem.maxQuantity, LengthMeasure.codePoints);
    _expectMeasured(tester, find.byType(TextField).at(2), ShoppingItem.maxGroup, LengthMeasure.codePoints);
    expect(find.text('0/${ShoppingItem.maxGroup}'), findsNothing, reason: 'Eingabezeile bleibt ohne Zähler');

    await app.services.shopping!.add('Eier', quantity: '6', group: 'Aldi');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    final dialog = _in(AlertDialog, find.byType(TextField));
    _expectMeasured(tester, dialog.at(0), ShoppingItem.maxTitle, LengthMeasure.codePoints);
    _expectMeasured(tester, dialog.at(1), ShoppingItem.maxQuantity, LengthMeasure.codePoints);
    _expectMeasured(tester, dialog.at(2), ShoppingItem.maxGroup, LengthMeasure.codePoints);
    await tester.enterText(dialog.at(1), '6 😀');
    await tester.pump();
    expect(find.text('3/${ShoppingItem.maxQuantity}'), findsOneWidget, reason: 'Menge: 3 Codepunkte');
  });

  testWidgets('Aufgaben: Titel, Erklärung und Kommentar zählen Codepunkte, Punkte der Liste bleiben frei', (tester) async {
    final app = await _start(tester);
    await app.services.tasks!.create(
      title: 'Haushalt',
      assignee: app.gateway.userId!,
      rule: TaskRule.fromInterval(TaskInterval.daily),
      items: <String>['Müll raus'],
    );
    await _openTasks(tester);
    await tester.tap(find.text('Haushalt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final comment = find.widgetWithText(TextField, 'Kommentar (optional)');
    _expectMeasured(tester, comment, TaskLogEntry.maxComment, LengthMeasure.codePoints);
    await tester.enterText(comment, '👍🏽');
    await tester.pump();
    expect(find.text('2/${TaskLogEntry.maxComment}'), findsOneWidget, reason: 'Emoji mit Hautfarbe: 2 Codepunkte');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aufgabenliste bearbeiten'));
    await tester.pumpAndSettle();
    _expectMeasured(tester, find.widgetWithText(TextField, 'Titel'), TaskList.maxTitle, LengthMeasure.codePoints);
    _expectMeasured(tester, find.widgetWithText(TextField, 'Erklärung (optional)'), TaskList.maxDescription, LengthMeasure.codePoints);
    final items = tester.widget<TextField>(find.widgetWithText(TextField, 'Punkte (einer pro Zeile)'));
    expect(items.inputFormatters, isNull, reason: 'ein Formatter würde die ganze Liste begrenzen');
    expect(items.maxLength, isNull);
  });

  testWidgets('Termine: Titel, Ort und Notiz zählen UTF-16-Einheiten', (tester) async {
    await _start(tester, tab: 'Kalender');
    await tester.tap(find.byTooltip('Neuer Termin'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.descendant(of: find.widgetWithText(TextFormField, label), matching: find.byType(TextField));
    _expectMeasured(tester, field('Titel'), CalendarEvent.maxTitle, LengthMeasure.utf16);
    _expectMeasured(tester, field('Ort'), CalendarEvent.maxLocation, LengthMeasure.utf16);
    _expectMeasured(tester, field('Notiz'), CalendarEvent.maxNote, LengthMeasure.utf16);
    await tester.enterText(field('Ort'), 'Zoo 😀');
    await tester.pump();
    expect(find.text('6/${CalendarEvent.maxLocation}'), findsOneWidget, reason: '😀 sind 2 UTF-16-Einheiten');
  });

  testWidgets('Zähler nennt Screenreadern die verbleibende Anzahl nach dem Maß der Prüfung', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester, tab: 'Kalender');
    await tester.tap(find.byTooltip('Neuer Termin'));
    await tester.pumpAndSettle();
    final ort = find.descendant(of: find.widgetWithText(TextFormField, 'Ort'), matching: find.byType(TextField));
    await tester.enterText(ort, '😀');
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('${CalendarEvent.maxLocation - 2}')), findsWidgets);
    handle.dispose();
  });
  testWidgets('Chat: Eingabe zählt UTF-16-Einheiten wie sendMessage (#236)', (tester) async {
    await _start(tester, tab: 'Chat');
    _expectMeasured(tester, find.widgetWithText(TextField, 'Nachricht schreiben'), ChatMessage.maxBody, LengthMeasure.utf16);
    expect(SdkMatrixGateway.maxMessageLength, ChatMessage.maxBody, reason: 'Feld und Prüfung nutzen dieselbe Grenze');
  });
}
