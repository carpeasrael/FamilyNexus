import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/shopping_peer.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

Future<FakeMatrixGateway> _joinBen(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@ben:${app.server.host}'] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  return ben;
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

void main() {
  group('Einkaufszettel', () {
    testWidgets('Eintrag anlegen, abhaken, bearbeiten, löschen und Erledigte entfernen', (tester) async {
      _tall(tester);
      final app = await buildTestApp();
      await _open(tester, app);
      await _tab(tester, 'Einkauf');
      expect(find.text('Der Einkaufszettel ist leer. Füge oben etwas hinzu.'), findsOneWidget);
      expect(find.text('Gemeinsam mit der Familie, Ende-zu-Ende-verschlüsselt'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Milch');
      await tester.enterText(find.widgetWithText(TextField, 'Menge (optional)'), '2 Liter');
      await tester.tap(find.byTooltip('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('2 Liter'), findsOneWidget);
      expect(find.text('Zu besorgen (1)'), findsOneWidget);
      expect(app.shoppingStore.items.values.single.by, app.gateway.userId);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Erledigt (1)'), findsOneWidget);
      expect(find.text('Zu besorgen (0)'), findsNothing);

      await tester.tap(find.byTooltip('Milch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'Hafermilch');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Hafermilch'), findsOneWidget);

      await tester.tap(find.text('Erledigte entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('1 erledigte Einträge für die ganze Familie entfernen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Erledigte entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('Hafermilch'), findsNothing);
      expect(find.text('Der Einkaufszettel ist leer. Füge oben etwas hinzu.'), findsOneWidget);
    });

    testWidgets('leere und überlange Eingaben legen nichts an', (tester) async {
      _tall(tester);
      final app = await buildTestApp();
      await _open(tester, app);
      await _tab(tester, 'Einkauf');
      await tester.enterText(find.widgetWithText(TextField, 'Was wird gebraucht?'), '   ');
      await tester.tap(find.byTooltip('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(app.shoppingStore.items, isEmpty);
    });

    testWidgets('Änderungen von Ben erscheinen und tragen seinen Namen', (tester) async {
      _tall(tester);
      final app = await buildTestApp();
      final room = app.gateway.familyRoom!;
      app.server.addMember(room, '@ben:fake.test');
      final ben = await ShoppingPeer.create(app.server, 'ben', 'geheim456', familyRoomId: room.id);
      await _open(tester, app);
      await _tab(tester, 'Einkauf');
      await ben.service.add('Käse', quantity: '200 g');
      await ben.sync.publishPending();
      await tester.pumpAndSettle();
      expect(find.text('Käse'), findsOneWidget);
      expect(find.text('zuletzt von Ben'), findsOneWidget);
      // Anna hakt ab; Ben erhält die Änderung.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await app.services.shopping!.sync.publishPending();
      await tester.pumpAndSettle();
      expect((await ben.store.all()).single.checked, isTrue);
      ben.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Heute zeigt die Zahl offener Einträge', (tester) async {
      final app = await buildTestApp();
      await _open(tester, app);
      expect(find.text('Einkaufszettel: 0 offen'), findsOneWidget);
      await app.services.shopping!.add('Brot');
      await tester.pumpAndSettle();
      expect(find.text('Einkaufszettel: 1 offen'), findsOneWidget);
    });
  });

  group('Online-Status', () {
    testWidgets('Mitgliederliste zeigt Text und Punkt: online, offline, zuletzt', (tester) async {
      _tall(tester);
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await _open(tester, app);
      await _tab(tester, 'Familie');
      expect(find.text('Status unbekannt'), findsOneWidget);
      expect(find.text('Du bist online'), findsOneWidget);

      await ben.announcePresence(online: true);
      await tester.pumpAndSettle();
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Status unbekannt'), findsNothing);

      await ben.announcePresence(online: false);
      await tester.pumpAndSettle();
      expect(find.text('Online'), findsNothing);
      expect(find.textContaining('Zuletzt online'), findsOneWidget);
    });

    testWidgets('Heute listet online befindliche Mitglieder', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await _open(tester, app);
      expect(find.text('Gerade ist sonst niemand online.'), findsOneWidget);
      await ben.announcePresence(online: true);
      await tester.pumpAndSettle();
      expect(find.text('Ben – Online'), findsOneWidget);
    });

    testWidgets('Einstellung „Online-Status teilen“ steuert die Meldungen', (tester) async {
      _tall(tester);
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await _open(tester, app);
      await tester.pumpAndSettle();
      expect(app.server.presenceLog.where((e) => e.sender == app.gateway.userId && e.online), isNotEmpty,
          reason: 'standardmäßig wird geteilt');
      expect(ben.presence[app.gateway.userId], isNotNull);

      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Online-Status teilen'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Online-Status teilen'));
      await tester.pumpAndSettle();
      expect(app.services.settings.settings.shareOnlineStatus, isFalse);
      expect(app.server.presenceLog.where((e) => e.sender == app.gateway.userId).last.online, isFalse);
    });

    testWidgets('Fünf Tabs passen in Telefonbreite ohne Überlauf', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625; // ≈ 411 dp Breite
      addTearDown(tester.view.reset);
      final app = await buildTestApp();
      await _open(tester, app);
      expect(tester.takeException(), isNull);
      for (final label in <String>['Heute', 'Kalender', 'Chat', 'Einkauf', 'Familie']) {
        final f = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
        expect(f, findsOneWidget, reason: label);
        final render = tester.renderObject<RenderParagraph>(f);
        expect(render.didExceedMaxLines, isFalse, reason: '$label wird abgeschnitten');
        expect(render.size.width, lessThanOrEqualTo(411 / 5 + 1), reason: label);
      }
    });
  });
}
