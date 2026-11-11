import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/shopping/shopping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

/// AP-4e: Die Zerlegung von `ShoppingScreen.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
Future<void> _open(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Einkauf'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Einkauf: leer; dann Einträge mit Gruppen, offen und erledigt', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp();
    await _open(tester, app);
    final empty = semanticsSnapshot(tester, find.byType(ShoppingScreen));
    final c = app.services.shopping!;
    await c.add('Milch', quantity: '2 l', group: 'Supermarkt');
    await c.add('Brot', quantity: '', group: 'Bäcker');
    await c.add('Butter', quantity: '', group: 'Supermarkt');
    await c.setChecked(c.open.firstWhere((i) => i.title == 'Butter').id, true);
    await tester.pumpAndSettle();
    final full = semanticsSnapshot(tester, find.byType(ShoppingScreen));
    expect(empty, _expectedEmpty);
    expect(full, _expectedFull);
    handle.dispose();
  });
}

const List<String> _expectedEmpty = <String>[
  'L=Heute | Tab 1 von 5 tap',
  'L=Kalender | Tab 2 von 5 tap',
  'L=Chat | Tab 3 von 5 tap',
  'L=Einkauf | Tab 4 von 5 selected tap',
  'L=Familie | Tab 5 von 5 tap',
  'L=Gemeinsam mit der Familie, Ende-zu-Ende-verschlüsselt',
  'L=Was wird gebraucht? textfield tap',
  'L=Menge (optional) textfield tap',
  'L=Gruppe (optional) textfield tap',
  'T=Hinzufügen button tap',
  'L=Der Einkaufszettel ist leer. Füge oben etwas hinzu.',
  'L=Einkauf',
  'T=Menü öffnen button tap',
];
const List<String> _expectedFull = <String>[
  'L=Heute | Tab 1 von 5 tap',
  'L=Kalender | Tab 2 von 5 tap',
  'L=Chat | Tab 3 von 5 tap',
  'L=Einkauf | Tab 4 von 5 selected tap',
  'L=Familie | Tab 5 von 5 tap',
  'L=Gemeinsam mit der Familie, Ende-zu-Ende-verschlüsselt',
  'L=Was wird gebraucht? textfield tap',
  'L=Menge (optional) textfield tap',
  'L=Gruppe (optional) textfield tap',
  'T=Hinzufügen button tap',
  'L=Gruppe Bäcker übernehmen button tap',
  'L=Gruppe Supermarkt übernehmen button tap',
  'L=Zu besorgen (2)',
  'L=Bäcker (1)',
  'L=Brot als erledigt markieren | Brot | zuletzt von dir tap',
  'T=Brot button tap',
  'L=Supermarkt (1)',
  'L=Milch als erledigt markieren | Milch | zuletzt von dir | 2 l tap',
  'T=Milch button tap',
  'L=Erledigt (1)',
  'L=Erledigte entfernen button tap',
  'L=Butter wieder auf die Liste setzen | Butter | zuletzt von dir checked tap',
  'T=Butter button tap',
  'L=Einkauf',
  'T=Menü öffnen button tap',
];
