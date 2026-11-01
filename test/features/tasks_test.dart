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
    // #38: Datum in der Schreibweise der App-Sprache, nicht ISO.
    // Datum und Uhrzeit stammen aus der Zeitzone der Liste (#163).
    expect(find.textContaining('Erledigt am 22.10.2026 um '), findsOneWidget);
    expect(find.textContaining('Du · 22.10.2026, '), findsOneWidget);
    expect(find.textContaining('2026-10-22'), findsNothing);

    // Nächster Tag in Berlin (ab 22:00 UTC): die Liste ist zurückgesetzt, der Verlauf bleibt.
    now = DateTime.utc(2026, 10, 22, 22, 5);
    await app.services.tasks!.load();
    await tester.pumpAndSettle();
    expect(find.text('0 von 2 erledigt'), findsOneWidget);
    expect(find.text('Müll raus erledigt'), findsOneWidget, reason: 'Verlauf bleibt erhalten');
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
  });

  testWidgets('#76: „Montag bis Freitag“ wird beim Anlegen als Regel gespeichert', (tester) async {
    _tall(tester);
    final app = await buildTestApp(clock: () => DateTime.utc(2026, 10, 24, 8));
    await _open(tester, app);
    await _openTasks(tester);
    await tester.tap(find.byTooltip('Neue Aufgabenliste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'Müll rausbringen');
    await tester.enterText(find.widgetWithText(TextField, 'Punkte (einer pro Zeile)'), 'Tonne raus');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montag bis Freitag (ohne Wochenende)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect((await app.taskStore.lists()).single.rule, const TaskRule.weekdays());
  });

  testWidgets('Issue #1: Erklärung und Wiederholung „monatlich am zweiten Dienstag“ anlegen, anzeigen und ändern', (tester) async {
    _tall(tester);
    final now = DateTime.utc(2026, 10, 24, 8); // Samstag
    final app = await buildTestApp(clock: () => now);
    await _open(tester, app);
    await _openTasks(tester);
    await tester.tap(find.byTooltip('Neue Aufgabenliste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Titel'), 'Papiertonne');
    await tester.enterText(find.widgetWithText(TextField, 'Erklärung (optional)'), 'Kartons vorher zerkleinern.');
    await tester.enterText(find.widgetWithText(TextField, 'Punkte (einer pro Zeile)'), 'Tonne rausstellen');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du').last);
    await tester.pumpAndSettle();

    // Täglich bietet die Wahl mit/ohne Wochenende.
    expect(find.text('Alle Wochentage (auch Samstag und Sonntag)'), findsOneWidget);
    expect(find.text('Montag bis Freitag (ohne Wochenende)'), findsOneWidget);

    await tester.tap(find.text('Täglich'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monatlich nach Wochentag').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erster'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zweiter').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dienstag').last);
    await tester.pumpAndSettle();
    expect(find.text('Startet jeden Monat am zweiten Dienstag neu'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    final list = (await app.taskStore.lists()).single;
    expect(list.rule, const TaskRule.monthlyByWeekday(2, DateTime.tuesday));
    expect(list.description, 'Kartons vorher zerkleinern.');
    expect(find.text('Monatlich'), findsOneWidget, reason: 'Kurzlabel auf der Kachel');

    await tester.tap(find.text('Papiertonne'));
    await tester.pumpAndSettle();
    expect(find.text('Monatlich am zweiten Dienstag · Startet jeden Monat am zweiten Dienstag neu'), findsOneWidget);
    expect(find.text('Kartons vorher zerkleinern.'), findsOneWidget);
    expect(find.textContaining('Nächster Neustart:'), findsOneWidget);
    expect(find.textContaining('10. November 2026'), findsOneWidget, reason: 'zweiter Dienstag im November');

    // Ändern: monatlich am 31. (Hinweis zu kürzeren Monaten).
    await tester.tap(find.byTooltip('Aufgabenliste bearbeiten'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Erklärung (optional)')).controller!.text, 'Kartons vorher zerkleinern.');
    await tester.tap(find.text('Monatlich nach Wochentag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monatlich nach Datum').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('31.').last, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('31.').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('am letzten Tag des Monats'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect((await app.taskStore.lists()).single.rule, const TaskRule.monthlyByDate(31));
  });

  testWidgets('Review R9: bestehende Liste (wöchentlich, v1) unverändert gespeichert bleibt v1', (tester) async {
    _tall(tester);
    final app = await buildTestApp(clock: () => DateTime.utc(2026, 10, 24, 8));
    await _open(tester, app);
    await app.services.tasks!.create(
      title: 'Wochenputz',
      assignee: app.gateway.userId!,
      rule: TaskRule.fromInterval(TaskInterval.weekly),
      items: <String>['Bad'],
    );
    await _openTasks(tester);
    await tester.tap(find.text('Wochenputz'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wöchentlich am Montag'), findsOneWidget);
    await tester.tap(find.byTooltip('Aufgabenliste bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Montag'), findsOneWidget, reason: 'Editor zeigt die bisherige Regel');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final saved = (await app.taskStore.lists()).single;
    expect(saved.version, 2);
    expect(TaskCodec.encodeList(saved)['v'], 1);
  });

  testWidgets('#163: „Erledigt am … um …“ zeigt die Uhrzeit in der Zone der Liste, nicht die des Geräts', (tester) async {
    _tall(tester);
    // 12:00 UTC am 22.10. = 02:00 am 23.10. auf Kiritimati (UTC+14); jedes Gerät außer UTC+14 sähe eine andere Uhrzeit.
    final now = DateTime.utc(2026, 10, 22, 12);
    final app = await buildTestApp(clock: () => now);
    await app.services.openCalendar();
    await _open(tester, app);
    await app.services.tasks!.service.createList(
        title: 'Ferne Liste', assignee: app.gateway.userId!, interval: TaskInterval.daily, timeZone: 'Pacific/Kiritimati', items: ['Müll raus']);
    await app.services.tasks!.load();
    await tester.pumpAndSettle();
    await _openTasks(tester);
    await tester.tap(find.text('Ferne Liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Erledigt'));
    await tester.pumpAndSettle();

    expect((await app.taskStore.log()).single.doneOn, '2026-10-23', reason: 'auf Kiritimati ist es schon der 23.');
    expect(find.text('Erledigt am 23.10.2026 um 02:00'), findsOneWidget);
    expect(find.text('Du · 23.10.2026, 02:00'), findsOneWidget, reason: 'Verlaufszeile');
  });

  testWidgets('#162: Erledigt-Uhrzeit folgt der 24-h-Einstellung des Geräts (englisch), Zone der Liste bleibt', (tester) async {
    _tall(tester);
    final now = DateTime.utc(2026, 10, 22, 12); // 02:00 am 23.10. auf Kiritimati
    final app = await buildTestApp(clock: () => now, lang: 'en');
    await app.services.openCalendar();
    // 24-h-Gerät: Plattformwerte kommen aus der übergeordneten MediaQuery (siehe clock_format_test.dart).
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(alwaysUse24HourFormat: true),
      child: FamilyNexusApp(services: app.services),
    ));
    await tester.pumpAndSettle();
    await app.services.tasks!.service.createList(
        title: 'Far list', assignee: app.gateway.userId!, interval: TaskInterval.daily, timeZone: 'Pacific/Kiritimati', items: ['Bins']);
    await app.services.tasks!.load();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Far list'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'Done on .* at 02:00$')), findsOneWidget, reason: '24 h, nicht „2:00 AM“');
    expect(find.textContaining(RegExp(r', 02:00$')), findsOneWidget, reason: 'Verlaufszeile');
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

  testWidgets('#98: Liste für ein nicht mehr vorhandenes Mitglied zeigt „Ehemaliges Mitglied“, nie die Matrix-ID', (tester) async {
    _tall(tester);
    final app = await buildTestApp(clock: () => DateTime.utc(2026, 10, 24, 8));
    await _open(tester, app);
    await app.services.tasks!.create(
      title: 'Müll rausbringen',
      assignee: '@geloescht:fake.test',
      rule: const TaskRule.weekdays(),
      items: <String>['Tonne raus'],
    );
    await _openTasks(tester);
    expect(find.textContaining('Zugewiesen an Ehemaliges Mitglied'), findsOneWidget);
    expect(find.textContaining('@geloescht'), findsNothing);
  });
}
