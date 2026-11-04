import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';
import '../helpers/shell_finders.dart';

/// #221: Die Eingabefelder zählen wie die Prüfung der Domäne (Einkauf und Aufgaben Codepunkte,
/// Termine UTF-16-Einheiten), nicht sichtbare Zeichen.
const String _family = '👨‍👩‍👧‍👦'; // 1 Graphem, 7 Codepunkte, 11 UTF-16-Einheiten

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<TestApp> _start(WidgetTester tester, {String? tab}) async {
  _tall(tester);
  final app = await buildTestApp(clock: () => DateTime.utc(2026, 3, 20, 10));
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.tap(navTab(tab));
    await tester.pumpAndSettle();
  }
  return app;
}

String _text(WidgetTester tester, Finder field) => tester.widget<TextField>(field).controller!.text;

void main() {
  test('Testdaten: das Familien-Emoji ist ein Graphem aus 7 Codepunkten', () {
    expect((_family.characters.length, _family.runes.length, _family.length), (1, 7, 11));
  });

  group('Einkauf', () {
    testWidgets('Gruppe aus 24 Buchstaben und Familien-Emoji: das Feld kürzt, Hinzufügen gelingt', (tester) async {
      final app = await _start(tester, tab: 'Einkauf');
      final group = find.byType(TextField).at(2);
      await tester.enterText(find.byType(TextField).at(0), 'Eier');
      await tester.enterText(group, '${'a' * 24}$_family');
      await tester.pump();
      expect(_text(tester, group).runes.length, lessThanOrEqualTo(ShoppingItem.maxGroup));
      expect(_text(tester, group), 'a' * 24, reason: 'nie ein halbes Emoji');

      await tester.tap(find.byTooltip('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ungültig'), findsNothing);
      expect(app.shoppingStore.items.values.single.group, 'a' * 24);
    });

    testWidgets('Zähler im Bearbeiten-Dialog zeigt Codepunkte', (tester) async {
      final app = await _start(tester, tab: 'Einkauf');
      await app.services.shopping!.add('Eier', group: 'Aldi$_family');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.text('11/${ShoppingItem.maxGroup}'), findsOneWidget);
      expect(find.text('5/${ShoppingItem.maxGroup}'), findsNothing);
    });
  });

  testWidgets('Aufgaben: Titel aus maxTitle-1 Buchstaben und Familien-Emoji lässt sich speichern', (tester) async {
    final app = await _start(tester);
    await tester.tap(find.byTooltip('Menü öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Neue Aufgabenliste'));
    await tester.pumpAndSettle();

    final title = find.widgetWithText(TextField, 'Titel');
    await tester.enterText(title, '${'a' * (TaskList.maxTitle - 1)}$_family');
    await tester.enterText(find.widgetWithText(TextField, 'Punkte (einer pro Zeile)'), 'Tonne raus');
    await tester.pump();
    expect(_text(tester, title).runes.length, lessThanOrEqualTo(TaskList.maxTitle));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    final lists = await app.taskStore.lists();
    expect(lists, hasLength(1));
    expect(lists.single.title, 'a' * (TaskList.maxTitle - 1));
  });

  testWidgets('Termine: Titel aus maxTitle Emoji außerhalb der BMP wird auf UTF-16-Einheiten gekürzt und gespeichert', (tester) async {
    final app = await _start(tester, tab: 'Kalender');
    await tester.tap(find.byTooltip('Neuer Termin'));
    await tester.pumpAndSettle();
    final title = find.descendant(of: find.widgetWithText(TextFormField, 'Titel'), matching: find.byType(TextField));
    await tester.enterText(title, '😀' * CalendarEvent.maxTitle);
    await tester.pump();
    expect(_text(tester, title).length, lessThanOrEqualTo(CalendarEvent.maxTitle));
    expect(_text(tester, title), '😀' * (CalendarEvent.maxTitle ~/ 2));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final stored = await app.events.all();
    expect(stored, hasLength(1));
    expect(stored.single.title, '😀' * (CalendarEvent.maxTitle ~/ 2));
  });
}
