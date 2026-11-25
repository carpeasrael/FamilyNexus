import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/features/chat/chat_view_model.dart';
import 'package:family_nexus/features/contacts/contact_controller.dart';
import 'package:family_nexus/features/family/member_avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #119, K3b-2a (E-114): Chat-Tab für Kontakte: Umschalter, Banner, Imitationsschutz, Blockieren, Zustände.
void main() {
  const carla = '@carla:fake.test';
  late FakeRoom room;

  group('Domäne', () {
    test('ContactNames.collides: Gleichheit, Diakritika, Homoglyphen, Vollbreite, ganze Wörter; kein Treffer sonst', () {
      expect(ContactNames.collides('Mama', <String>['Mama']), isTrue);
      expect(ContactNames.collides('  MAMA ', <String>['Mama']), isTrue);
      expect(ContactNames.collides('Müller', <String>['Muller']), isTrue);
      expect(ContactNames.collides('Mаmа', <String>['Mama']), isTrue, reason: 'kyrillisches а');
      expect(ContactNames.collides('Ｍａｍａ', <String>['Mama']), isTrue, reason: 'vollbreit');
      expect(ContactNames.collides('𝐌𝐚𝐦𝐚', <String>['Mama']), isTrue, reason: 'mathematisch fett');
      expect(ContactNames.collides('Mama Anna', <String>['Mama']), isTrue, reason: 'ganzes Wort');
      expect(ContactNames.collides('Mama', <String>['Mama Anna']), isTrue);
      expect(ContactNames.collides('Carla', <String>['Mama', 'Papa']), isFalse);
      expect(ContactNames.collides('Mamas', <String>['Mama']), isFalse, reason: 'kein ganzes Wort');
      expect(ContactNames.collides('Al', <String>['Alex Al']), isFalse, reason: 'unter 3 Zeichen nur bei Gleichheit');
      expect(ContactNames.collides('', <String>['Mama']), isFalse);
      expect(ContactNames.collides(null, <String>['Mama']), isFalse);
    });

    test('resolveContactView: Liste, Gespräch, verschwundenes Gespräch ⇒ Liste (nie Familie)', () {
      const t = ChatThread(id: '!a', title: 'A', kind: ThreadKind.contact, peerId: carla);
      expect(resolveContactView(contactThreads: const <ChatThread>[t], open: null).kind, ChatViewKind.list);
      expect(resolveContactView(contactThreads: const <ChatThread>[], open: null).kind, ChatViewKind.list);
      final c = resolveContactView(contactThreads: const <ChatThread>[t], open: '!a');
      expect((c.kind, c.shownId, c.showHeader), (ChatViewKind.conversation, '!a', true));
      final gone = resolveContactView(contactThreads: const <ChatThread>[], open: '!a');
      expect((gone.kind, gone.vanished, gone.shownId), (ChatViewKind.list, true, null));
    });
  });

  Future<TestApp> setup(WidgetTester tester, {bool enabled = true, bool toJoined = true, String carlaName = 'Carla'}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(contactsEnabled: true);
    app.server.addAccount('carla', 'pw-carla', displayName: carlaName);
    room = toJoined
        ? app.server.createContactRoom(carla, app.gateway.userId!, toJoined: true)
        : app.server.createContactRoom(app.gateway.userId!, carla); // ausgehend, Gegenüber noch nicht beigetreten
    if (!enabled) app.gateway.setContactPolicy(const ContactPolicy(enabled: true, contacts: <String, ContactState>{carla: ContactState.accepted}));
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    if (enabled) {
      final cal = app.builtCalendars.single;
      await cal.contactController!.setEnabled(true);
      if (toJoined) {
        await cal.contactSync!.service.addAccepted(carla);
      } else {
        await cal.contactSync!.service.addOutgoing(carla);
      }
      await cal.contactSync!.pushPolicyNow();
      await tester.pumpAndSettle();
    }
    await tester.tap(navTab('Chat'));
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> toContacts(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<ChatScope>), matching: find.textContaining('Kontakte')));
    await tester.pumpAndSettle();
  }

  testWidgets('ohne eingeschaltete Kontakte: kein Umschalter, Kontakt-Threads nicht im Familien-Bereich', (tester) async {
    await setup(tester, enabled: false);
    expect(find.text('Familie'), findsNothing);
    expect(find.byKey(ValueKey<String>('thread-${room.id}')), findsNothing);
    await end(tester);
  });

  testWidgets('eingeschaltet: Umschalter; Familie ohne, Kontakte mit dem Kontakt-Gespräch', (tester) async {
    await setup(tester);
    expect(find.text('Familie'), findsOneWidget);
    expect(find.byKey(ValueKey<String>('thread-${room.id}')), findsNothing);
    await toContacts(tester);
    expect(find.byKey(ValueKey<String>('thread-${room.id}')), findsOneWidget);
    await end(tester);
  });

  testWidgets('Kontakt öffnen: openThread, Banner dauerhaft, Senden geht; Zurück führt zur Kontakte-Liste', (tester) async {
    final app = await setup(tester);
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(app.gateway.openCalls[room.id], 1);
    expect(find.textContaining('Außerhalb der Familie: \u2068Carla · fake.test\u2069'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Hallo Carla');
    await tester.tap(find.byTooltip('Senden'));
    await tester.pumpAndSettle();
    expect(room.events.where((e) => e.type == 'm.room.message').single.content['body'], 'Hallo Carla');
    await tester.tap(find.byTooltip('Zurück zu den Gesprächen'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey<String>('thread-${room.id}')), findsOneWidget);
    await end(tester);
  });

  testWidgets('Kontakt-Gespräch wird nie als letztes Gespräch gemerkt', (tester) async {
    final app = await setup(tester);
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.lastChatThread, isNot(room.id));
    await tester.tap(find.byTooltip('Zurück zu den Gesprächen'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.lastChatThread, isNot(room.id));
    await end(tester);
  });

  testWidgets('wartendes Gespräch: Erklärzeile statt Eingabe, kein openThread', (tester) async {
    final app = await setup(tester, toJoined: false);
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Wartet auf Annahme. Du kannst schreiben, sobald die Person beigetreten ist.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(app.gateway.openCalls[room.id], isNull);
    await end(tester);
  });

  testWidgets('Öffnen scheitert: Fehlertext mit „Erneut versuchen“ statt endlosem Laden', (tester) async {
    final app = await setup(tester);
    app.gateway.failOpenThread = true;
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Das Gespräch konnte nicht geöffnet werden.'), findsWidgets);
    app.gateway.failOpenThread = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await end(tester);
  });

  testWidgets('Fremder namens wie ein Familienmitglied: Name mit Server, neutrales Symbol, Warnung', (tester) async {
    final app = await setup(tester, carlaName: 'Anna');
    app.server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hi, ich bin es'});
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anna · fake.test'), findsWidgets);
    expect(find.textContaining('Nicht deine Familie'), findsWidgets);
    expect(find.byType(MemberAvatarView), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    await end(tester);
  });

  testWidgets('Blockieren im Chat: Datensatz blockiert, Gespräch weg, Kontakte-Liste', (tester) async {
    final app = await setup(tester);
    app.server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hallo'});
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockieren').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('erfährt nichts davon'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Blockieren')));
    await tester.pumpAndSettle();
    final c = app.builtCalendars.single.contactController!;
    expect(c.contacts.where((e) => e.id == carla).single.state, ContactStateView.blocked);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(ValueKey<String>('thread-${room.id}')), findsNothing);
    await end(tester);
  });

  testWidgets('Abzeichen: ungelesene Kontakt-Nachricht zählt bei „Kontakte“, nicht bei „Familie“', (tester) async {
    final app = await setup(tester);
    app.server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hallo'});
    await tester.pumpAndSettle();
    expect(find.text('Kontakte (1)'), findsOneWidget);
    expect(find.text('Familie'), findsOneWidget);
    await end(tester);
  });
}
