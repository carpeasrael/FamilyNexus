import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
  await tester.pumpAndSettle();
}

/// Bens Gerät als Mitglied (kein Moderator) in Annas Familie.
Future<TestApp> _benAsMember(TestApp anna, {DateTime Function()? clock}) async {
  final ben = await buildTestApp(loggedIn: false, server: anna.server, clock: clock);
  await ben.gateway.login(server: ServerUrl.tryParse(anna.server.host)!, username: 'ben', password: 'geheim456');
  await ben.gateway.setUpSecurity();
  final room = anna.gateway.familyRoom!;
  room.membership['@ben:${anna.server.host}'] = MemberStatus.joined;
  ben.gateway.attachFamilyRoom(room.id);
  await ben.services.settings.update((x) => x.copyWith(onboardingDone: true));
  return ben;
}

void main() {
  testWidgets('Moderatorin legt Liste an, weist sie sich selbst zu, hakt mit Kommentar ab; Reset am nächsten Tag, Verlauf bleibt', (tester) async {
    _tall(tester);
    var now = DateTime.utc(2026, 10, 22, 8);
    final app = await buildTestApp(clock: () => now);
    await _open(tester, app);

    await _openTasks(tester);
    expect(find.text('Noch keine Aufgabenlisten.'), findsOneWidget);

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

    final list = (await app.taskStore.lists()).single;
    expect((list.title, list.interval, list.assignee, list.items.length), ('Haushalt', TaskInterval.daily, app.gateway.userId, 2));
    expect(find.text('Haushalt'), findsOneWidget);
    expect(find.text('0 von 2 erledigt', findRichText: true), findsNothing, reason: 'steht im Untertitel mit Name');

    await tester.tap(find.text('Haushalt'));
    await tester.pumpAndSettle();
    expect(find.text('Startet jeden Tag um Mitternacht neu', findRichText: true), findsNothing);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kommentar (optional)'), 'Schon am Morgen');
    await tester.tap(find.widgetWithText(FilledButton, 'Erledigt'));
    await tester.pumpAndSettle();

    final log = await app.taskStore.log();
    expect(log, hasLength(1));
    expect((log.single.doneOn, log.single.comment, log.single.by), ('2026-10-22', 'Schon am Morgen', app.gateway.userId));
    expect(find.text('1 von 2 erledigt'), findsOneWidget);
    expect(find.textContaining('Schon am Morgen'), findsWidgets);
    expect(find.text('Müll raus erledigt'), findsOneWidget, reason: 'Verlauf');

    // Nächster Tag in Berlin (ab 22:00 UTC): die Liste ist zurückgesetzt, der Verlauf bleibt.
    now = DateTime.utc(2026, 10, 22, 22, 5);
    await app.services.tasks!.load();
    await tester.pumpAndSettle();
    expect(find.text('0 von 2 erledigt'), findsOneWidget);
    expect(find.text('Müll raus erledigt'), findsOneWidget, reason: 'Verlauf bleibt erhalten');
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
  });

  testWidgets('Mitglied ohne Moderatorenrecht: kein Anlegen; zugewiesene Liste kann abgehakt werden, fremde nicht', (tester) async {
    _tall(tester);
    final now = DateTime.utc(2026, 10, 22, 8);
    final anna = await buildTestApp(clock: () => now);
    final ben = await _benAsMember(anna, clock: () => now);
    // Bens Gerät muss zuhören, bevor Anna sendet (der Fake-Strom speichert nichts zwischen).
    await ben.services.openCalendar();
    await _open(tester, ben);
    // Anna (Moderatorin) legt zwei Listen an: eine für Ben, eine für sich.
    await anna.services.openCalendar();
    final svcAnna = anna.services.tasks!.service;
    final forBen = await svcAnna.createList(
        title: 'Bens Liste', assignee: ben.gateway.userId!, interval: TaskInterval.weekly, timeZone: 'Europe/Berlin', items: ['Zimmer']);
    await svcAnna.createList(
        title: 'Annas Liste', assignee: anna.gateway.userId!, interval: TaskInterval.monthly, timeZone: 'Europe/Berlin', items: ['Steuer']);
    await anna.services.tasks!.sync.publishPending();
    await ben.services.tasks!.sync.idle();
    await ben.services.tasks!.load();
    await tester.pumpAndSettle();
    await _openTasks(tester);
    expect(find.byTooltip('Neue Aufgabenliste'), findsNothing, reason: 'Nur Moderatoren legen an');
    expect(find.text('Mir zugewiesen'), findsOneWidget);
    expect(find.text('Weitere Listen'), findsOneWidget);

    // Fremde Liste: Haken sind gesperrt.
    await tester.tap(find.text('Annas Liste'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.byTooltip('Aufgabenliste bearbeiten'), findsNothing);
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();

    // Eigene Liste: abhaken ohne Kommentar.
    await tester.tap(find.text('Bens Liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Erledigt'));
    await tester.pumpAndSettle();
    expect(find.text('1 von 1 erledigt'), findsOneWidget);
    final e = (await ben.taskStore.log()).single;
    expect((e.by, e.listId, e.periodKey), (ben.gateway.userId, forBen.id, '2026-W43'));
    anna.services.closeCalendar(); // nie im Widget-Baum: Zeitgeber selbst beenden
  });
}
