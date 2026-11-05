import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/calendar_screen.dart';
import 'package:family_nexus/features/chat/chat_screen.dart';
import 'package:family_nexus/features/family/family_screen.dart';
import 'package:family_nexus/features/shopping/shopping_screen.dart';
import 'package:family_nexus/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/nav.dart';
import '../../support/test_app.dart';

/// #274, E-92: Fokus im Hauptfenster (nur sichtbare Seiten fokussierbar, Rail eigene Gruppe) und die Schwelle,
/// ab der die Auswahlfelder der Einstellungen unter den Titel rutschen (Schriftskala > 1,3).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  Future<void> start(WidgetTester tester, Size size, {double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final app = await buildTestApp();
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
  }

  bool excluded(WidgetTester tester, Type page) {
    final f = find.ancestor(of: find.byType(page, skipOffstage: false), matching: find.byType(ExcludeFocus, skipOffstage: false)).first;
    return tester.widget<ExcludeFocus>(f).excluding;
  }

  final pages = <(String, Type)>[
    ('Heute', TodayScreen),
    ('Kalender', CalendarScreen),
    ('Chat', ChatScreen),
    ('Einkauf', ShoppingScreen),
    ('Familie', FamilyScreen),
  ];

  for (final size in const <Size>[Size(390, 844), Size(800, 1280)]) {
    testWidgets('Fokus: nur die sichtbare Seite ist fokussierbar (${size.width.toInt()} × ${size.height.toInt()})', (tester) async {
      await start(tester, size);
      for (final (label, _) in pages) {
        await tester.tap(navTab(label));
        await tester.pumpAndSettle();
        for (final (other, type) in pages) {
          expect(excluded(tester, type), other != label, reason: 'Reiter $label, Seite $other');
        }
      }
    });
  }

  testWidgets('Fokus: Zweispalter macht Kalender und Chat zusammen fokussierbar, die übrigen nicht', (tester) async {
    await start(tester, const Size(1280, 800));
    await tester.tap(navTab('Kalender'));
    await tester.pumpAndSettle();
    expect(excluded(tester, CalendarScreen), isFalse);
    expect(excluded(tester, ChatScreen), isFalse);
    expect(excluded(tester, TodayScreen), isTrue);
    expect(excluded(tester, ShoppingScreen), isTrue);
    expect(excluded(tester, FamilyScreen), isTrue);
  });

  testWidgets('Fokus: Rail ist eine eigene Gruppe, der Inhalt liegt nicht in ihr', (tester) async {
    await start(tester, const Size(800, 1280));
    final railGroup = find.ancestor(of: find.byType(NavigationRail), matching: find.byType(FocusTraversalGroup)).first;
    expect(find.descendant(of: railGroup, matching: find.byType(TodayScreen, skipOffstage: false)), findsNothing);
    final contentGroup = find.ancestor(of: find.byType(TodayScreen, skipOffstage: false), matching: find.byType(FocusTraversalGroup)).first;
    expect(find.descendant(of: contentGroup, matching: find.byType(NavigationRail)), findsNothing);
  });

  for (final (scale, large) in <(double, bool)>[(1.0, false), (1.3, false), (1.31, true), (2.0, true)]) {
    testWidgets('Einstellungen: Auswahlfeld bei Schrift ${scale * 100} % ${large ? 'unter dem Titel' : 'neben dem Titel'}', (tester) async {
      await start(tester, const Size(390, 844), textScale: scale);
      await openSettings(tester);
      final dd = find.byType(DropdownButton<String?>);
      expect(dd, findsOneWidget);
      expect(tester.widget<DropdownButton<String?>>(dd).isExpanded, large);
      final tile = tester.widget<ListTile>(find.ancestor(of: dd, matching: find.byType(ListTile)).first);
      expect(tile.subtitle != null, large);
      expect(tile.trailing != null, !large);
      expect(tester.takeException(), isNull);
    });
  }
}
