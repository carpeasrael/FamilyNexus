// Visuelle Rundreise durch die Aufgabenlisten für manuelle Prüfung (Screenshots per adb). Nutzt die
// Fake-Matrix aus test/support; nicht Teil der automatischen Gates.
import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/support/test_app.dart';

Future<void> _hold(WidgetTester t, [int s = 6]) async {
  await t.pumpAndSettle();
  await t.pump(const Duration(seconds: 1));
  await Future<void>.delayed(Duration(seconds: s));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Aufgabenlisten-Rundreise', (tester) async {
    final now = DateTime.now().toUtc();
    final app = await buildTestApp(lang: 'de', clock: () => now, screenProtection: PlatformScreenProtection(), secureScreen: false);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    final tasks = app.services.tasks!;
    final me = app.gateway.userId!;
    await tasks.create(title: 'Haushalt', assignee: me, rule: TaskRule.fromInterval(TaskInterval.daily), items: ['Müll raus', 'Spülmaschine ausräumen', 'Bad putzen']);
    await tasks.create(title: 'Garten', assignee: me, rule: TaskRule.fromInterval(TaskInterval.weekly), items: ['Rasen mähen', 'Beete jäten']);
    await tester.pumpAndSettle();

    await _hold(tester); // 1 Heute mit Aufgaben-Karte
    await tester.tap(find.byTooltip('Menü öffnen'));
    await _hold(tester, 3); // 2 Menü
    await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
    await _hold(tester); // 3 Übersicht
    await tester.tap(find.text('Haushalt'));
    await _hold(tester); // 4 Detail
    await tester.tap(find.byType(Checkbox).first);
    await _hold(tester, 4); // 5 Kommentar-Dialog
    await tester.enterText(find.widgetWithText(TextField, 'Kommentar (optional)'), 'Schon am Morgen erledigt');
    await tester.tap(find.widgetWithText(FilledButton, 'Erledigt'));
    await _hold(tester); // 6 Punkt erledigt + Verlauf
    await tester.tap(find.byTooltip('Aufgabenliste bearbeiten'));
    await _hold(tester); // 7 Editor
    expect(tasks.doneNow(tasks.lists.firstWhere((l) => l.title == 'Haushalt')), hasLength(1));
  });
}
