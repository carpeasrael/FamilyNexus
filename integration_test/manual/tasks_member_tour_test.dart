// Visuelle Rundreise der Aufgabenlisten aus Sicht eines Mitglieds ohne Moderatorenrecht (Screenshots per adb).
// Nutzt die Fake-Matrix aus test/support; nicht Teil der automatischen Gates.
import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
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

  testWidgets('Aufgabenlisten aus Sicht von Ben (Mitglied)', (tester) async {
    final now = DateTime.now().toUtc();
    final anna = await buildTestApp(lang: 'de', clock: () => now);
    final ben = await buildTestApp(
      lang: 'de',
      loggedIn: false,
      server: anna.server,
      clock: () => now,
      screenProtection: PlatformScreenProtection(),
      secureScreen: false,
    );
    await ben.gateway.login(server: ServerUrl.tryParse(anna.server.host)!, username: 'ben', password: 'geheim456');
    await ben.gateway.setUpSecurity();
    final room = anna.gateway.familyRoom!;
    room.membership['@ben:${anna.server.host}'] = MemberStatus.joined;
    ben.gateway.attachFamilyRoom(room.id);
    await ben.services.settings.update((x) => x.copyWith(onboardingDone: true));

    // Bens Gerät hört zu, bevor Anna (Moderatorin) sendet.
    await ben.services.openCalendar();
    await tester.pumpWidget(FamilyNexusApp(services: ben.services));
    await tester.pumpAndSettle();
    await anna.services.openCalendar();
    final a = anna.services.tasks!;
    await a.create(title: 'Bens Zimmer', assignee: ben.gateway.userId!, interval: TaskInterval.weekly, items: ['Bett machen', 'Boden saugen']);
    await a.create(title: 'Annas Steuer', assignee: anna.gateway.userId!, interval: TaskInterval.monthly, items: ['Belege sortieren']);
    await a.sync.publishPending();
    await ben.services.tasks!.sync.idle();
    await ben.services.tasks!.load();
    await tester.pumpAndSettle();

    await _hold(tester); // 1 Heute (Ben)
    await tester.tap(find.byTooltip('Menü öffnen'));
    await _hold(tester, 3); // 2 Menü
    await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
    await _hold(tester); // 3 Übersicht ohne „+“
    await tester.tap(find.text('Annas Steuer'));
    await _hold(tester); // 4 Fremde Liste: Haken gesperrt, kein Bearbeiten/Löschen
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bens Zimmer'));
    await _hold(tester, 4); // 5 Eigene Liste
    await tester.tap(find.byType(Checkbox).first);
    await _hold(tester, 4); // 6 Kommentar-Dialog
    await tester.tap(find.widgetWithText(FilledButton, 'Erledigt'));
    await _hold(tester); // 7 Erledigt, Verlauf
    expect(find.byTooltip('Neue Aufgabenliste'), findsNothing);
    anna.services.closeCalendar();
  });
}
