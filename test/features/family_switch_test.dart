import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/shell/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
import '../support/test_app.dart';

/// #140: Die Familie wechselt, ohne dass die Oberfläche „keine Familie“ sieht (Join B, Leave A und Kontodaten in einer
/// Sync-Antwort). Die Dienste der alten Familie schließen, die der neuen öffnen genau einmal.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  Future<void> start(WidgetTester tester, TestApp app) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
  }

  testWidgets('Familie springt direkt von A auf B: Dienste schließen und öffnen genau einmal neu', (tester) async {
    final app = await buildTestApp();
    final roomA = app.gateway.familyRoom!.id;
    final roomB = app.server.addFamilyRoom('Familie B', '@anna:fake.test').id;
    await start(tester, app);
    final old = app.services.calendar;
    expect(app.calendarRooms, <String>[roomA]);

    app.gateway.attachFamilyRoom(roomB);
    await tester.pumpAndSettle();

    expect(app.calendarRooms, <String>[roomA, roomB], reason: 'genau ein Neuaufbau');
    expect(app.shoppingRooms, <String>[roomA, roomB]);
    expect(app.taskRooms, <String>[roomA, roomB]);
    expect(app.services.openFamilyRoom, roomB);
    expect(app.services.calendar, isNot(same(old)));
    expect(app.services.calendar!.sync.sameFamily, isTrue);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('geöffnete Seiten schließen beim direkten Wechsel, wie beim Verlassen der Hauptansicht', (tester) async {
    final app = await buildTestApp();
    final roomB = app.server.addFamilyRoom('Familie B', '@anna:fake.test').id;
    await start(tester, app);
    await openSettings(tester);
    expect(find.byType(NavigationBar), findsNothing);

    app.gateway.attachFamilyRoom(roomB);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(app.services.openFamilyRoom, roomB);
  });

  testWidgets('Familie wechselt zurück: wieder genau ein Neuaufbau je Wechsel', (tester) async {
    final app = await buildTestApp();
    final roomA = app.gateway.familyRoom!.id;
    final roomB = app.server.addFamilyRoom('Familie B', '@anna:fake.test').id;
    await start(tester, app);

    app.gateway.attachFamilyRoom(roomB);
    await tester.pumpAndSettle();
    app.gateway.attachFamilyRoom(roomA);
    await tester.pumpAndSettle();

    expect(app.calendarRooms, <String>[roomA, roomB, roomA]);
    expect(app.services.openFamilyRoom, roomA);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  for (final phase in <String>['Kalender', 'Einkauf', 'Aufgaben']) {
    testWidgets('Wechsel während des Öffnens ($phase): genau ein Neuaufbau, danach Dienste für B, kein Ladekreis', (tester) async {
      late TestApp app;
      late String roomB;
      var first = true;
      Future<void> jump(String _) async {
        if (first) app.gateway.attachFamilyRoom(roomB);
        first = false;
      }

      app = await buildTestApp(
        beforeCalendarBuild: phase == 'Kalender' ? jump : null,
        beforeShoppingBuild: phase == 'Einkauf' ? jump : null,
        beforeTasksBuild: phase == 'Aufgaben' ? jump : null,
      );
      final roomA = app.gateway.familyRoom!.id;
      roomB = app.server.addFamilyRoom('Familie B', '@anna:fake.test').id;
      await start(tester, app);

      expect(app.calendarRooms, <String>[roomA, roomB]);
      expect(app.services.openFamilyRoom, roomB);
      expect(app.services.calendar, isNotNull);
      expect(app.services.calendar!.sync.sameFamily, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }
}
