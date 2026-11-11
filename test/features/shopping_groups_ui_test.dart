import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/shopping/shopping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

/// #211: Gruppen im Einkaufszettel, mit Fokus, Tastatur, Überlauf und Screenreader.
Finder get _groupField => find.byType(TextField).at(2);
Finder _chip(String name) => find.widgetWithText(ActionChip, name);

void _size(WidgetTester tester, Size size, {double keyboard = 0, double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<TestApp> _open(WidgetTester tester, {Size size = const Size(900, 2400)}) async {
  _size(tester, size);
  final app = await buildTestApp();
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Einkauf'));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _seed(WidgetTester tester, TestApp app, Map<String, String> items) async {
  for (final e in items.entries) {
    await app.services.shopping!.add(e.key, group: e.value);
  }
  await tester.pumpAndSettle();
}

bool _focused(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText))).focusNode.hasFocus;

String _text(WidgetTester tester, Finder field) => tester.widget<TextField>(field).controller!.text;

Future<void> _openEdit(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bearbeiten'));
  await tester.pumpAndSettle();
}

void main() {
  group('Liste', () {
    testWidgets('ohne benannte Gruppe keine Unterüberschrift', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Milch': '', 'Brot': ''});
      expect(find.text('Zu besorgen (2)'), findsOneWidget);
      expect(find.text('Ohne Gruppe (2)'), findsNothing);
    });

    testWidgets('Unterüberschriften je Gruppe, „Ohne Gruppe“ zuletzt, Erledigt flach', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi', 'Mehl': 'aldi', 'Salz': '', 'Tee': 'Rewe'});
      expect(find.text('Zu besorgen (4)'), findsOneWidget);
      final aldi = tester.getTopLeft(find.text('Aldi (2)')).dy;
      final rewe = tester.getTopLeft(find.text('Rewe (1)')).dy;
      final none = tester.getTopLeft(find.text('Ohne Gruppe (1)')).dy;
      expect(aldi, lessThan(tester.getTopLeft(find.text('Eier')).dy));
      expect(tester.getTopLeft(find.text('Mehl')).dy, lessThan(rewe));
      expect(rewe, lessThan(none));
      expect(none, lessThan(tester.getTopLeft(find.text('Salz')).dy));

      final tee = app.shoppingStore.items.values.firstWhere((i) => i.title == 'Tee');
      await app.services.shopping!.setChecked(tee.id, true);
      await tester.pumpAndSettle();
      expect(find.text('Rewe (1)'), findsNothing, reason: 'Erledigt bleibt flach');
      expect(find.text('Erledigt (1)'), findsOneWidget);
      await app.services.shopping!.setChecked(tee.id, false);
      await tester.pumpAndSettle();
      expect(find.text('Rewe (1)'), findsOneWidget, reason: 'zurück in der Gruppe');
    });

    testWidgets('Haken in beide Richtungen, zurückgesetzt steht der Eintrag wieder in der Gruppe', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Erledigt (1)'), findsOneWidget);
      expect(app.shoppingStore.items.values.single.checked, isTrue);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Aldi (1)'), findsOneWidget);
      expect(app.shoppingStore.items.values.single.checked, isFalse);
    });

    testWidgets('Unterüberschrift ist eine Überschrift für den Screenreader', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      expect(tester.getSemantics(find.text('Aldi (1)')), matchesSemantics(label: 'Aldi (1)', isHeader: true));
      handle.dispose();
    });
  });

  group('Hinzufügen und Vorschläge', () {
    testWidgets('das Feld bleibt nach dem Hinzufügen gefüllt, Titel und Menge nicht', (tester) async {
      final app = await _open(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Eier');
      await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.enterText(_groupField, 'Aldi');
      await tester.tap(find.byTooltip('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(app.shoppingStore.items.values.single.group, 'Aldi');
      expect(_text(tester, find.byType(TextField).at(0)), isEmpty);
      expect(_text(tester, find.byType(TextField).at(1)), isEmpty);
      expect(_text(tester, _groupField), 'Aldi');
    });

    testWidgets('ein Chip übernimmt den Namen, fügt nichts hinzu und lässt den Fokus im Feld', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      await tester.tap(_chip('Aldi'));
      await tester.pumpAndSettle();
      expect(_text(tester, _groupField), 'Aldi');
      final selection = tester.widget<TextField>(_groupField).controller!.selection;
      expect(selection, const TextSelection.collapsed(offset: 4));
      expect(_focused(tester, _groupField), isTrue);
      expect(app.shoppingStore.items.length, 1);
    });

    testWidgets('Chips filtern nach dem Feldtext, ein genauer Treffer zeigt die übrigen', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi', 'Tee': 'Rewe'});
      await tester.enterText(_groupField, 're');
      await tester.pump();
      expect(_chip('Aldi'), findsNothing);
      expect(_chip('Rewe'), findsOneWidget);
      await tester.enterText(_groupField, 'rewe');
      await tester.pump();
      expect(_chip('Aldi'), findsOneWidget);
      expect(_chip('Rewe'), findsNothing);
    });

    testWidgets('höchstens sechs Chips, weitere findet man durch Tippen', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{for (var i = 0; i < 8; i++) 'Ding $i': 'Laden $i'});
      expect(find.byType(ActionChip), findsNWidgets(6));
      await tester.enterText(_groupField, 'den 7');
      await tester.pump();
      expect(_chip('Laden 7'), findsOneWidget);
    });

    testWidgets('auch Gruppen erledigter Einträge bleiben Vorschläge', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      await app.services.shopping!.setChecked(app.shoppingStore.items.values.single.id, true);
      await tester.pumpAndSettle();
      expect(_chip('Aldi'), findsOneWidget);
    });

    testWidgets('Gruppenfeld begrenzt die Länge in Hauptansicht und Dialog', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': ''});
      expect(tester.widget<TextField>(_groupField).maxLength, 30);
      await _openEdit(tester, 'Eier');
      final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(2);
      expect(tester.widget<TextField>(field).maxLength, 30);
    });

    testWidgets('Chip-Knoten trägt Beschriftung und Aktion', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      final node = tester.getSemantics(find.bySemanticsLabel('Gruppe Aldi übernehmen'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Gruppe Aldi übernehmen'));
      await tester.pumpAndSettle();
      expect(_text(tester, _groupField), 'Aldi');
      handle.dispose();
    });
  });

  group('Tastatur bleibt offen (FamilyNexusApp)', () {
    testWidgets('zwischen Pointer-Down und Up auf dem Chip bleiben Fokus und Tastatur', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      await tester.tap(_groupField);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      final g = await tester.startGesture(tester.getCenter(_chip('Aldi')));
      await tester.pump();
      expect(_focused(tester, _groupField), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(_focused(tester, _groupField), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('auch der Knopf „Hinzufügen“ lässt die Tastatur offen', (tester) async {
      final app = await _open(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Eier');
      await tester.tap(_groupField);
      await tester.pump();
      await tester.tap(find.byTooltip('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(app.shoppingStore.items.length, 1);
      expect(_focused(tester, find.byType(TextField).at(0)), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('Tippen in die Liste schließt sie weiterhin', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
      await tester.tap(_groupField);
      await tester.pump();
      await tester.tap(find.text('Aldi (1)'));
      await tester.pumpAndSettle();
      expect(_focused(tester, _groupField), isFalse);
    });

    for (final (name, from) in <(String, Finder Function())>[
      ('Chip', () => _chip('Aldi')),
      ('Hinweiszeile', () => find.text('Gemeinsam mit der Familie, Ende-zu-Ende-verschlüsselt')),
    ]) {
      testWidgets('Ziehen ab $name lässt den Fokus im Gruppenfeld', (tester) async {
        final app = await _open(tester, size: const Size(640, 360));
        await _seed(tester, app, <String, String>{'Eier': 'Aldi'});
        await tester.tap(_groupField);
        await tester.pump();
        await tester.ensureVisible(from());
        await tester.pumpAndSettle();
        await tester.drag(from(), const Offset(0, -80));
        await tester.pumpAndSettle();
        expect(_focused(tester, _groupField), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      });
    }
  });

  group('Überlauf', () {
    for (final (size, keyboard) in <(Size, double)>[(const Size(640, 360), 260), (const Size(844, 390), 200)]) {
      for (final seeded in <bool>[false, true]) {
        testWidgets('$size mit Tastatur $keyboard, Chips: $seeded', (tester) async {
          final app = await _open(tester, size: size);
          if (seeded) await _seed(tester, app, <String, String>{for (var i = 0; i < 8; i++) 'Ding $i': 'Laden $i'});
          await tester.ensureVisible(_groupField);
          await tester.pumpAndSettle();
          await tester.tap(_groupField, warnIfMissed: false);
          await tester.pump();
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(_focused(tester, _groupField), isTrue);
          await tester.ensureVisible(find.byTooltip('Hinzufügen'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('das Formular belegt höchstens 60 % der Höhe, die Liste behält den Rest', (tester) async {
      final app = await _open(tester, size: const Size(640, 360));
      await _seed(tester, app, <String, String>{for (var i = 0; i < 8; i++) 'Ding $i': 'Laden $i'});
      final body = tester.getSize(find.byType(ShoppingScreen)).height;
      final form = tester.getSize(find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(SingleChildScrollView))).height;
      expect(form, lessThanOrEqualTo(body * 0.6));
      expect(form, greaterThan(body * 0.5), reason: 'der Inhalt ist hier höher als die Grenze');
    });

    testWidgets('Textskala 1,3 im Hochformat', (tester) async {
      _size(tester, const Size(360, 640), textScale: 1.3);
      final app = await buildTestApp();
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(navTab('Einkauf'));
      await tester.pumpAndSettle();
      await _seed(tester, app, <String, String>{for (var i = 0; i < 8; i++) 'Ding $i': 'Laden mit langem Namen $i'});
      expect(tester.takeException(), isNull);
    });
  });

  group('Bearbeiten', () {
    Finder dialogField(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);

    testWidgets('Gruppe setzen, per Chip wechseln und entfernen', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': '', 'Tee': 'Rewe'});
      final eier = app.shoppingStore.items.values.firstWhere((i) => i.title == 'Eier').id;
      await _openEdit(tester, 'Eier');
      await tester.enterText(dialogField(2), 'Aldi');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(app.shoppingStore.items[eier]!.group, 'Aldi');

      await _openEdit(tester, 'Eier');
      expect(_text(tester, dialogField(2)), 'Aldi');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: _chip('Rewe')));
      await tester.pumpAndSettle();
      expect(_text(tester, dialogField(2)), 'Rewe');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(app.shoppingStore.items[eier]!.group, 'Rewe');

      await _openEdit(tester, 'Eier');
      await tester.enterText(dialogField(2), '');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(app.shoppingStore.items[eier]!.group, '');
    });

    testWidgets('Dialogbreite: unter 500 auf dem Desktop und unabhängig von den Chips', (tester) async {
      final app = await _open(tester, size: const Size(1400, 900));
      await _seed(tester, app, <String, String>{'Eier': 'Aldi', 'Tee': 'Rewe'});
      await _openEdit(tester, 'Eier');
      final material = find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first;
      final before = tester.getSize(material).width;
      expect(before, lessThan(500));
      expect(tester.getSize(dialogField(0)).width, 400, reason: 'feste Wunschbreite, auch bei kurzen Chips');
      await tester.enterText(dialogField(2), 'xyz');
      await tester.pump();
      expect(tester.getSize(material).width, before);
    });

    testWidgets('Chip im Dialog: Fokus und Tastatur bleiben zwischen Pointer-Down und Up', (tester) async {
      final app = await _open(tester);
      await _seed(tester, app, <String, String>{'Eier': 'Aldi', 'Tee': 'Rewe'});
      await _openEdit(tester, 'Eier');
      await tester.tap(dialogField(2));
      await tester.pump();
      final g = await tester.startGesture(tester.getCenter(find.descendant(of: find.byType(AlertDialog), matching: _chip('Rewe'))));
      await tester.pump();
      expect(_focused(tester, dialogField(2)), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(_focused(tester, dialogField(2)), isTrue);
    });

    testWidgets('Dialog auf 320×568 ohne Exception', (tester) async {
      final app = await _open(tester, size: const Size(320, 568));
      await _seed(tester, app, <String, String>{for (var i = 0; i < 8; i++) 'Ding $i': 'Laden mit langem Namen $i'});
      await _openEdit(tester, 'Ding 0');
      expect(tester.takeException(), isNull);
    });
  });
}
