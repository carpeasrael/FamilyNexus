import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
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

void main() {
  group('Gateway (Fake): Einzelchats', () {
    test('nur mit beigetretenen Familienmitgliedern, ohne Doppel', () async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final id = await app.gateway.startDirectChat(ben.userId!);
      expect(await app.gateway.startDirectChat(ben.userId!), id, reason: 'vorhandener Raum wird wiederverwendet');
      expect(await ben.startDirectChat(app.gateway.userId!), id, reason: 'beide Seiten teilen denselben Raum');
      await expectLater(app.gateway.startDirectChat(app.gateway.userId!), throwsA(isA<Object>()));
      await expectLater(app.gateway.startDirectChat('@fremd:fake.test'), throwsA(isA<Object>()));
      app.gateway.familyRoom!.membership['@cara:fake.test'] = MemberStatus.invited;
      await expectLater(app.gateway.startDirectChat('@cara:fake.test'), throwsA(isA<Object>()), reason: 'Eingeladene sind keine Mitglieder');
    });

    test('Nachrichten bleiben im Gespräch und erscheinen nicht im Familienchat', () async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final id = await app.gateway.startDirectChat(ben.userId!);
      await app.gateway.sendMessage('nur für Ben', threadId: id);
      await app.gateway.sendMessage('für alle');
      expect(ben.messagesIn(id).map((m) => m.body), <String>['nur für Ben']);
      expect(ben.messages.map((m) => m.body), <String>['für alle']);
      expect(app.gateway.messages.map((m) => m.body), <String>['für alle']);
    });

    test('Ungelesenes wird je Gespräch gezählt und einzeln als gelesen markiert', () async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final id = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('privat', threadId: id);
      await ben.sendMessage('öffentlich');
      expect((app.gateway.unreadIn(id), app.gateway.unreadIn(ChatThread.familyId), app.gateway.unreadCount), (1, 1, 2));
      await app.gateway.markChatRead(threadId: id);
      expect((app.gateway.unreadIn(id), app.gateway.unreadIn(ChatThread.familyId), app.gateway.unreadCount), (0, 1, 1));
    });

    test('nach dem Entfernen ist das Gespräch weg und Senden wird verweigert', () async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final id = await app.gateway.startDirectChat(ben.userId!);
      expect(app.gateway.threads.map((t) => t.id), contains(id));
      await app.gateway.removeMember(ben.userId!);
      expect(app.gateway.threads.map((t) => t.id), <String>[ChatThread.familyId]);
      await expectLater(app.gateway.sendMessage('hallo?', threadId: id), throwsA(isA<Object>()));
    });

    test('Dritte sehen fremde Einzelchats nicht', () async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      app.server.addAccount('cara', 'pw3', displayName: 'Cara');
      final cara = app.server.newDevice();
      await cara.login(server: ServerUrl.tryParse(app.server.host)!, username: 'cara', password: 'pw3');
      app.server.addMember(app.gateway.familyRoom!, cara.userId!);
      cara.attachFamilyRoom(app.gateway.familyRoom!.id);
      final id = await app.gateway.startDirectChat(ben.userId!);
      await app.gateway.sendMessage('geheim', threadId: id);
      expect(cara.threads.map((t) => t.id), <String>[ChatThread.familyId]);
      expect(cara.messagesIn(id), isEmpty);
      await expectLater(cara.sendMessage('mitlesen', threadId: id), throwsA(isA<Object>()));
    });
  });

  group('Oberfläche', () {
    testWidgets('ohne Einzelchats keine Gesprächsleiste; mit Ben erscheint sie', (tester) async {
      final app = await buildTestApp();
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await _tab(tester, 'Chat');
      expect(find.byType(ChoiceChip), findsNothing);
      final ben = await _joinBen(app);
      await app.gateway.startDirectChat(ben.userId!);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.widgetWithText(ChoiceChip, 'Familie Test'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Ben'), findsOneWidget);
    });

    testWidgets('Schreiben im Einzelchat landet nur dort; Hinweis nennt das Gegenüber', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final id = await app.gateway.startDirectChat(ben.userId!);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await _tab(tester, 'Chat');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hallo Ben');
      await tester.tap(find.byTooltip('Senden'));
      await tester.pumpAndSettle();
      expect(find.text('Hallo Ben'), findsOneWidget);
      expect(app.gateway.messagesIn(id).single.body, 'Hallo Ben');
      expect(app.gateway.messages, isEmpty);
      expect(ben.messagesIn(id).single.body, 'Hallo Ben');
    });

    testWidgets('Ungelesene Nachrichten werden in der Leiste gezeigt und beim Öffnen gelesen', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final id = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Hast du Zeit?', threadId: id);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await _tab(tester, 'Chat');
      expect(app.gateway.unreadIn(id), 1);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Hast du Zeit?'), findsOneWidget);
      expect(app.gateway.unreadIn(id), 0);
    });

    testWidgets('„Nachricht schreiben“ in der Familie öffnet den Einzelchat', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp();
      await _joinBen(app);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await _tab(tester, 'Familie');
      await tester.tap(find.byTooltip('Nachricht schreiben: Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      expect(app.gateway.threads, hasLength(2));
    });

    testWidgets('verschwindet das Gespräch, geht es zurück zum Familienchat', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await app.gateway.startDirectChat(ben.userId!);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await _tab(tester, 'Chat');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
      await tester.pumpAndSettle();
      await app.gateway.removeMember(ben.userId!);
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);
    });
  });
}
