import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/features/chat/chat_view_model.dart';
import 'package:family_nexus/features/contacts/contact_controller.dart';
import 'package:family_nexus/features/contacts/not_your_family_warning.dart';
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
  late FakeMatrixServer server;

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

  test('ContactEntry: collides gehört zur Gleichheit (sonst bleibt die Ansicht ohne Neuaufbau)', () {
    const a = ContactEntry(id: carla, title: 'Carla', state: ContactStateView.confirmed);
    const b = ContactEntry(id: carla, title: 'Carla', state: ContactStateView.confirmed, collides: true);
    expect(a == b, isFalse);
    expect(a.hashCode == b.hashCode, isFalse);
    expect(a, const ContactEntry(id: carla, title: 'Carla', state: ContactStateView.confirmed));
  });

  Future<TestApp> setup(WidgetTester tester, {bool enabled = true, bool toJoined = true, String carlaName = 'Carla'}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(contactsEnabled: true);
    server = app.server;
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

  testWidgets('kein Rückfall in den Familienchat nach dem Warten (20 s) im Kontakt-Gespräch', (tester) async {
    await setup(tester);
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.textContaining('Außerhalb der Familie: \u2068Carla'), findsOneWidget);
    expect(find.text('Das Gespräch konnte nicht geöffnet werden.'), findsNothing);
    await end(tester);
  });

  testWidgets('„Letztes Gespräch merken“ an: ein Kontakt-Gespräch überschreibt das gemerkte Familiengespräch nie', (tester) async {
    final app = await setup(tester);
    await app.services.settings.update((c) => c.copyWith(restoreLastChat: true, lastChatThread: ChatThread.familyId));
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zurück zu den Gesprächen'));
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.lastChatThread, ChatThread.familyId);
    await end(tester);
  });

  testWidgets('Warnung „Nicht deine Familie“ in Liste, Banner und Blase (je einmal)', (tester) async {
    await setup(tester, carlaName: 'Anna');
    await toContacts(tester);
    expect(find.byType(NotYourFamilyWarning), findsOneWidget, reason: 'Listenzeile');
    await end(tester);
  });

  testWidgets('Warnung im Gespräch: Banner und Blase', (tester) async {
    await setup(tester, carlaName: 'Anna');
    server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hi'});
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(NotYourFamilyWarning), findsNWidgets(2));
    await end(tester);
  });

  testWidgets('Melden im Kontakt-Gespräch: das Angebot „Absender blockieren“ geht über den Controller', (tester) async {
    final app = await setup(tester);
    server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Ärger'});
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Ärger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nachricht melden'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Melden')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Absender blockieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('erfährt nichts davon'), findsOneWidget, reason: 'Kontakt-Dialog, nicht der Familientext');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Blockieren')));
    await tester.pumpAndSettle();
    final c = app.builtCalendars.single.contactController!;
    expect(c.contacts.where((e) => e.id == carla).single.state, ContactStateView.blocked);
    await end(tester);
  });

  testWidgets('Abzeichen: ein blockierter Kontakt zählt nicht mit', (tester) async {
    final app = await setup(tester);
    server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hallo'});
    await tester.pumpAndSettle();
    expect(find.text('Kontakte (1)'), findsOneWidget);
    await app.builtCalendars.single.contactController!.block(carla);
    await tester.pumpAndSettle();
    expect(find.text('Kontakte (1)'), findsNothing);
    await end(tester);
  });

  testWidgets('Abzeichen: lokal blockierter Kontakt (Thread bleibt im Gateway) zählt nicht mit', (tester) async {
    final app = await setup(tester);
    server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hallo'});
    await tester.pumpAndSettle();
    expect(find.text('Kontakte (1)'), findsOneWidget);
    await app.services.settings.update((c) => c.copyWith(blockedUsers: <String>[carla]));
    await tester.pumpAndSettle();
    expect(app.gateway.threads.any((x) => x.id == room.id), isTrue, reason: 'nur die Ansicht filtert');
    expect(find.text('Kontakte (1)'), findsNothing);
    await end(tester);
  });

  testWidgets('Banner bleibt bei knapper Höhe sichtbar', (tester) async {
    await setup(tester);
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(900, 330);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Außerhalb der Familie: \u2068Carla'), findsOneWidget);
    await end(tester);
  });

  testWidgets('große Schrift (2,0) und kleines Fenster: kein Überlauf im Kontakt-Gespräch (auch mit Warnung)', (tester) async {
    await setup(tester, carlaName: 'Anna');
    server.post(room, carla, 'm.room.message', <String, Object?>{'body': 'Hi'});
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await end(tester);
  });

  testWidgets('Kontakte ausschalten im offenen Gespräch: der Entwurf ist verworfen und kehrt nicht zurück', (tester) async {
    final app = await setup(tester);
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'geheimer Entwurf');
    final c = app.builtCalendars.single.contactController!;
    await c.setEnabled(false);
    await tester.pumpAndSettle();
    expect(find.text('Familie'), findsNothing);
    await c.setEnabled(true);
    await tester.pumpAndSettle();
    await toContacts(tester);
    await tester.tap(find.byKey(ValueKey<String>('thread-${room.id}')));
    await tester.pumpAndSettle();
    expect(find.text('geheimer Entwurf'), findsNothing);
    await end(tester);
  });
}
