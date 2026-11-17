import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/task_period.dart';
import 'package:family_nexus/domain/task_rule.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/family/family_screen.dart';
import 'package:family_nexus/features/tasks/tasks_screen.dart';
import 'package:family_nexus/features/today/today_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/nav.dart';
import '../../support/semantics_snapshot.dart';
import '../../support/test_app.dart';

/// #524, E-105: Fußzeile Heute, Kalender, Chat, Einkauf, Aufgaben; Familie, Einstellungen und Datenschutz im Menü.
/// Aufgaben mit Badge (eigene offene Aufgaben), Anfragen-Badge am Menüknopf und Menüeintrag.
const List<String> _labels = <String>['Heute', 'Kalender', 'Chat', 'Einkauf', 'Aufgaben'];

Future<TestApp> _start(WidgetTester tester, {Size size = const Size(400, 800), TestApp? existing}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final app = existing ?? await buildTestApp(clock: () => DateTime.utc(2026, 3, 20, 10));
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _addList(TestApp app, {int items = 3}) async {
  final c = app.services.tasks!;
  await c.create(
    title: 'Haushalt',
    assignee: c.me,
    rule: TaskRule.fromInterval(TaskInterval.daily),
    items: <String>[for (var i = 0; i < items; i++) 'Punkt $i'],
  );
}

Finder get _menuBadge => find.descendant(of: find.byType(AppBar), matching: find.byType(Badge));

bool _badgeVisible(Finder f) => f.evaluate().any((e) => (e.widget as Badge).isLabelVisible);

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Fußzeile', () {
    for (final size in const <Size>[Size(400, 800), Size(900, 800)]) {
      testWidgets('genau fünf Ziele in der Reihenfolge, kein Ziel „Familie“ (${size.width.toInt()} dp)', (tester) async {
        await _start(tester, size: size);
        final nav = findNavigation();
        expect(nav, findsOneWidget);
        final texts = find.descendant(of: nav, matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
        expect(texts, _labels);
        expect(navTab('Familie'), findsNothing);
        expect(navTab('Einstellungen'), findsNothing);
      });
    }

    testWidgets('Aufgaben: Badge mit eigener Zahl offener Aufgaben und Semantik „Aufgaben – n offene“', (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _start(tester);
      expect(find.descendant(of: findNavigation(), matching: find.byType(Badge)).evaluate().where((e) => (e.widget as Badge).isLabelVisible), isEmpty);
      await _addList(app);
      await tester.pumpAndSettle();
      expect(find.descendant(of: findNavigation(), matching: find.text('3')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Aufgaben – 3 offene')), findsOneWidget);
      final list = app.services.tasks!.lists.single;
      await app.services.tasks!.complete(list.id, list.items.first.id);
      await tester.pumpAndSettle();
      expect(find.descendant(of: findNavigation(), matching: find.text('2')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('ohne Aufgabendienst: Tab bleibt sichtbar, Inhalt leer, kein Absturz', (tester) async {
      final app = await _start(tester);
      app.services.tasks?.dispose();
      app.services.tasks = null;
      await tester.tap(navTab('Kalender')); // baut die Shell neu auf
      await tester.pumpAndSettle();
      expect(navTab('Aufgaben'), findsOneWidget);
      expect(find.descendant(of: findNavigation(), matching: find.byType(Badge)).evaluate().where((e) => (e.widget as Badge).isLabelVisible), isEmpty);
      await tester.tap(navTab('Aufgaben'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Aufgaben'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TasksTab ohne Aufgabendienst: leerer Inhalt, keine AppBar, kein FAB', (tester) async {
      final app = await buildTestApp();
      app.services.tasks = null;
      await tester.pumpWidget(AppScope(services: app.services, child: const MaterialApp(
            locale: Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TasksTab(),
          ),));
      expect(find.byType(TasksTab), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final size in const <Size>[Size(400, 800), Size(1100, 800)]) {
      testWidgets('in keinem Tab eine zweite sichtbare AppBar; Aufgaben-FAB tippbar und nicht überdeckt (${size.width.toInt()} dp)', (tester) async {
        final app = await _start(tester, size: size);
        await _addList(app);
        await tester.pumpAndSettle();
        for (final t in _labels) {
          await tester.tap(navTab(t));
          await tester.pumpAndSettle();
          expect(find.byType(AppBar), findsOneWidget, reason: t);
        }
        await tester.tap(navTab('Aufgaben'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Aufgaben'), findsOneWidget);
        final fab = find.byTooltip('Neue Aufgabenliste');
        expect(fab, findsOneWidget);
        expect(fab.hitTestable(), findsOneWidget, reason: 'FAB wird von nichts überdeckt');
        if (size.width < 600) {
          expect(tester.getRect(fab).bottom, lessThanOrEqualTo(tester.getRect(findNavigation()).top), reason: 'FAB nicht von der Leiste überdeckt');
        } else {
          await tester.tap(fab);
          await tester.pumpAndSettle();
          expect(find.widgetWithText(TextField, 'Titel'), findsOneWidget);
        }
      });
    }

    testWidgets('Heute-Karte „Aufgaben“ wechselt in den Tab, keine neue Route', (tester) async {
      await _start(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
      final card = find.descendant(of: find.byType(TodayScreen), matching: find.widgetWithText(TextButton, 'Aufgaben'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(TasksTab), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
      expect(findNavigation(), findsOneWidget, reason: 'Shell bleibt oben, keine Route darüber');
      expect(find.widgetWithText(AppBar, 'Aufgaben'), findsOneWidget);
      final nav = tester.widget<NavigationBar>(findNavigation());
      expect(nav.selectedIndex, 4);
    });
  });

  group('Menü', () {
    testWidgets('Reihenfolge Familie, Einstellungen, Datenschutz; kein Eintrag Aufgaben', (tester) async {
      await _start(tester);
      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
      final titles = find
          .descendant(of: find.byType(Drawer), matching: find.byType(ListTile))
          .evaluate()
          .map((e) => ((e.widget as ListTile).title! as Text).data)
          .toList();
      expect(titles, <String?>['Familie', 'Einstellungen', 'Datenschutzerklärung']);
      expect(find.descendant(of: find.byType(Drawer), matching: find.text('Aufgaben')), findsNothing);
    });

    testWidgets('Familie öffnet eine eigene Seite mit AppBar „Familie“ und FamilyScreen', (tester) async {
      await _start(tester);
      await openFamily(tester);
      expect(find.widgetWithText(AppBar, 'Familie'), findsOneWidget);
      expect(find.byType(FamilyScreen), findsOneWidget);
      expect(find.byTooltip('Zurück'), findsOneWidget);
      await tester.tap(find.byTooltip('Zurück'));
      await tester.pumpAndSettle();
      expect(find.byType(FamilyScreen), findsNothing);
      expect(findNavigation(), findsOneWidget);
    });
  });

  group('Beitrittsanfragen am Menü (Moderator)', () {
    Future<TestApp> requests(WidgetTester tester, {int n = 2}) async {
      final app = await buildTestApp(clock: () => DateTime.utc(2026, 3, 20, 10));
      final room = app.gateway.familyRoom!;
      for (final name in <String>['ben', 'cara'].take(n)) {
        room.membership['@$name:fake.test'] = MemberStatus.requested;
      }
      await _start(tester, existing: app);
      return app;
    }

    testWidgets('Badge „2“ am Menüknopf, Hinweis, Badge im Menüeintrag, der offene Drawer aktualisiert sich', (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await requests(tester);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('2')), findsOneWidget);
      expect(find.byTooltip('Menü öffnen'), findsOneWidget, reason: 'Tooltip unverändert');
      final menuSnapshot = semanticsSnapshot(tester, find.byType(AppBar));
      expect(menuSnapshot, contains('H=Familie – 2 offene Anfragen T=Menü öffnen button tap'));
      // Kein zusätzlich vorlesbares „2“ vom Badge: die Zahl steht nur im Hinweis (das Badge-Label ist ausgeschlossen).
      expect(menuSnapshot.where((e) => e == 'L=2'), isEmpty, reason: 'Badge-Zahl darf nicht als eigener Knoten vorgelesen werden');
      expect(navTab('2'), findsNothing, reason: 'kein Badge mehr am Tab');

      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
      final drawerBadge = find.descendant(of: find.byType(Drawer), matching: find.byType(Badge));
      expect(find.descendant(of: find.byType(Drawer), matching: find.text('2')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Familie – 2 offene Anfragen')), findsWidgets);
      await app.gateway.rejectRequest('@ben:fake.test');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(Drawer), matching: find.text('1')), findsOneWidget, reason: 'offener Drawer zählt neu');
      expect(find.bySemanticsLabel(RegExp('Familie – 1 offene Anfrage')), findsWidgets);
      expect(drawerBadge, findsOneWidget);
      semantics.dispose();
    });

    testWidgets('ohne Anfragen: kein Badge, Semantik des Menüknopfs unverändert „T=Menü öffnen button tap“', (tester) async {
      final semantics = tester.ensureSemantics();
      await _start(tester);
      expect(_menuBadge, findsNothing);
      expect(semanticsSnapshot(tester, find.byType(AppBar)), <String>['L=Heute', 'T=Menü öffnen button tap']);
      semantics.dispose();
    });

    testWidgets('Nichtmoderator sieht kein Badge trotz offener Anfrage', (tester) async {
      final anna = await buildTestApp(clock: () => DateTime.utc(2026, 3, 20, 10));
      final ben = await buildTestApp(loggedIn: false, server: anna.server);
      await ben.gateway.login(server: ServerUrl.tryParse(anna.server.host)!, username: 'ben', password: 'geheim456');
      await ben.gateway.setUpSecurity();
      final room = anna.gateway.familyRoom!;
      room.membership['@ben:${anna.server.host}'] = MemberStatus.joined;
      room.membership['@cara:${anna.server.host}'] = MemberStatus.requested;
      ben.gateway.attachFamilyRoom(room.id);
      await ben.services.settings.update((x) => x.copyWith(onboardingDone: true));
      await _start(tester, existing: ben);
      expect(_badgeVisible(_menuBadge), isFalse);
      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
      expect(_badgeVisible(find.descendant(of: find.byType(Drawer), matching: find.byType(Badge))), isFalse);
    });
  });
}
