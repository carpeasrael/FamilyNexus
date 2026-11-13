import 'dart:async';
import 'dart:convert';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/chat/chat_view_model.dart';
import 'package:family_nexus/features/chat/thread_preview.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #423, E-100: Gesprächsliste als Startseite des Chat-Tabs bei mehreren Gesprächen, Kopfzeile mit Zurück-Pfeil im
/// Gespräch, Zurück-Taste, Vorschau und Reihenfolge.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<FakeMatrixGateway> _member(TestApp app, String name, String display) async {
  // Ben legt `buildTestApp` selbst an (Passwort geheim456), weitere Mitglieder entstehen hier.
  final password = name == 'ben' ? 'geheim456' : 'pw-$name';
  if (!app.server.hasAccount(name)) app.server.addAccount(name, password, displayName: display);
  final device = app.server.newDevice();
  await device.login(server: ServerUrl.tryParse(app.server.host)!, username: name, password: password);
  final room = app.gateway.familyRoom!;
  room.membership['@$name:${app.server.host}'] = MemberStatus.joined;
  device.attachFamilyRoom(room.id);
  return device;
}

Future<void> _start(WidgetTester tester, TestApp app, {bool chatTab = true, MediaQueryData Function(MediaQueryData)? media}) async {
  Widget home = FamilyNexusApp(services: app.services);
  if (media != null) home = MediaQuery(data: media(MediaQueryData.fromView(tester.view)), child: home);
  await tester.pumpWidget(home);
  await tester.pumpAndSettle();
  if (chatTab) {
    await tester.tap(navTab('Chat'));
    await tester.pumpAndSettle();
  }
}

Finder _row(String id) => find.byKey(ValueKey<String>('thread-$id'));
Finder get _back => find.byTooltip('Zurück zu den Gesprächen');

Future<void> _open(WidgetTester tester, String id) async {
  await tester.tap(_row(id));
  await tester.pumpAndSettle();
}

Future<void> _toList(WidgetTester tester) async {
  await tester.tap(_back);
  await tester.pumpAndSettle();
}

void _wide(WidgetTester tester, {double width = 900, double height = 3000}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Zählt, wie oft das System „App verlassen“ meldet (`SystemNavigator.pop`).
class _Exits {
  int count = 0;
}

_Exits _trackExits(WidgetTester tester) {
  final exits = _Exits();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemNavigator.pop') exits.count++;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return exits;
}

/// Alle Beschriftungen der Semantikbaums ab der Wurzel (was ein Screenreader erreicht).
List<String> _allLabels(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final label = n.getSemanticsData().label;
    if (label.isNotEmpty) out.add(label);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  SemanticsNode? root;
  tester.binding.rootPipelineOwner.visitChildren((o) => root ??= o.semanticsOwner?.rootSemanticsNode);
  visit(root!);
  return out;
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

ChatMessage _msg(
  String id,
  DateTime time, {
  String sender = '@ben:fake.test',
  String body = 'x',
  MessageStatus status = MessageStatus.sent,
  bool beforeJoin = false,
}) =>
    ChatMessage(id: id, senderId: sender, senderName: 'Ben', time: time, body: body, status: status, beforeJoin: beforeJoin);

ChatThread _thread(String id, String title, {bool family = false}) => ChatThread(
      id: id,
      kind: family ? ThreadKind.family : ThreadKind.direct,
      title: title,
      peerId: family ? null : '@$id:fake.test',
    );

/// Etwas mehr als `ChatScreen.openTimeout` (20 s).
const Duration _openTimeoutPlus = Duration(seconds: 21);

void main() {
  group('Ansichtsmodell: feste Rangfolge', () {
    final family = _thread(ChatThread.familyId, 'Familie', family: true);
    final ben = _thread('ben', 'Ben');
    ChatView view(List<ChatThread> t, {String? open, String? waiting, bool active = true, bool synced = true}) =>
        resolveChatView(threads: t, open: open, waitingFor: waiting, active: active, initialSyncDone: synced);

    test('Rang 1: angefordertes Gespräch fehlt noch, auch ohne weitere Gespräche; Pfeil nur bei mehreren', () {
      final single = view(<ChatThread>[family], open: 'neu', waiting: 'neu');
      expect((single.kind, single.shownId, single.showHeader), (ChatViewKind.opening, null, false));
      final multi = view(<ChatThread>[family, ben], open: 'neu', waiting: 'neu');
      expect((multi.kind, multi.shownId, multi.showHeader), (ChatViewKind.opening, null, true));
    });

    test('Rang 1 schlägt Rang 2 und 3: das Warten fällt nie auf den Familienchat zurück', () {
      final v = view(<ChatThread>[family], open: 'neu', waiting: 'neu', synced: true);
      expect(v.kind, ChatViewKind.opening);
      expect(v.pin, isFalse);
      expect(v.followFamily, isFalse);
    });

    test('Rang 2: verschwundenes Gespräch zeigt schon im selben Frame den Familienchat, bei mehreren mit Kopfzeile', () {
      final alone = view(<ChatThread>[family], open: 'ben');
      expect((alone.kind, alone.shownId, alone.followFamily, alone.showHeader), (ChatViewKind.conversation, ChatThread.familyId, true, false));
      final cara = _thread('cara', 'Cara');
      final more = view(<ChatThread>[family, cara], open: 'ben');
      expect((more.kind, more.shownId, more.followFamily, more.showHeader), (ChatViewKind.conversation, ChatThread.familyId, true, true));
      expect(more.current, family);
    });

    test('Rang 3: ein Gespräch ohne Kopfzeile; Pinnen nur aktiv, nach dem ersten Sync, ohne Warten und ohne Wunsch', () {
      expect(view(<ChatThread>[family]).showHeader, isFalse);
      expect(view(<ChatThread>[family]).pin, isTrue);
      expect(view(<ChatThread>[family], active: false).pin, isFalse);
      expect(view(<ChatThread>[family], synced: false).pin, isFalse);
      expect(view(<ChatThread>[family], open: ChatThread.familyId).pin, isFalse, reason: 'überschreibt nie ein vorhandenes _open');
      expect(view(<ChatThread>[family], waiting: 'x').pin, isFalse);
    });

    test('Rang 4: mehrere Gespräche, keines geöffnet: Liste ohne gezeigte ID', () {
      final v = view(<ChatThread>[family, ben]);
      expect((v.kind, v.shownId, v.showHeader), (ChatViewKind.list, null, false));
    });

    test('Rang 5: Gespräch mit Kopfzeile; das erschienene Warten endet', () {
      final v = view(<ChatThread>[family, ben], open: 'ben', waiting: 'ben');
      expect((v.kind, v.shownId, v.showHeader, v.endWaiting, v.current), (ChatViewKind.conversation, 'ben', true, true, ben));
      expect(view(<ChatThread>[family, ben], open: 'ben').endWaiting, isFalse);
    });
  });

  group('Vorschau und Reihenfolge', () {
    final t0 = DateTime.utc(2026, 10, 21, 12);

    test('die Nachricht mit dem größten Zeitstempel zählt, nicht die an letzter Stelle (#295)', () {
      final list = <ChatMessage>[
        _msg('a', t0.add(const Duration(minutes: 5))),
        _msg('b', t0.add(const Duration(minutes: 1))),
      ];
      expect(lastPreviewMessage(list, const <String>{}, '@me:fake.test')!.id, 'a');
    });

    test('gleicher Zeitstempel: die spätere Position gewinnt', () {
      expect(lastPreviewMessage(<ChatMessage>[_msg('a', t0), _msg('b', t0)], const <String>{}, null)!.id, 'b');
    });

    test('eigene gerade gesendete und fehlgeschlagene Nachrichten zählen', () {
      final sending = _msg('s', t0.add(const Duration(minutes: 3)), sender: '@me:fake.test', status: MessageStatus.sending);
      final failed = _msg('f', t0.add(const Duration(minutes: 4)), sender: '@me:fake.test', status: MessageStatus.failed);
      expect(lastPreviewMessage(<ChatMessage>[_msg('a', t0), sending], const <String>{}, '@me:fake.test')!.id, 's');
      expect(lastPreviewMessage(<ChatMessage>[_msg('a', t0), sending, failed], const <String>{}, '@me:fake.test')!.id, 'f');
    });

    test('blockierte Absender und der Sammelhinweis beforeJoin werden übersprungen, eigene Nachrichten bleiben', () {
      final blocked = <String>{'@ben:fake.test'};
      final list = <ChatMessage>[
        _msg('a', t0),
        _msg('b', t0.add(const Duration(minutes: 1)), sender: '@cara:fake.test'),
        _msg('c', t0.add(const Duration(minutes: 2))),
        _msg('d', t0.add(const Duration(minutes: 3)), sender: '@cara:fake.test', beforeJoin: true),
      ];
      expect(lastPreviewMessage(list, blocked, '@me:fake.test')!.id, 'b');
      expect(lastPreviewMessage(<ChatMessage>[_msg('x', t0, sender: '@me:fake.test')], <String>{'@me:fake.test'}, '@me:fake.test')!.id, 'x');
      expect(lastPreviewMessage(const <ChatMessage>[], blocked, null), isNull);
    });

    test('Reihenfolge: Familienchat zuerst, dann jüngste, dann ohne Nachricht nach Titel, dann ID', () {
      final threads = <ChatThread>[
        _thread('dora', 'Dora'),
        _thread('ben', 'Ben'),
        _thread(ChatThread.familyId, 'Familie', family: true),
        _thread('cara', 'Cara'),
        _thread('anton', 'anton'),
      ];
      final byThread = <String, List<ChatMessage>>{
        // Position ≠ Zeit: die zuletzt gelistete Nachricht von Ben ist die ältere.
        'ben': <ChatMessage>[_msg('b1', t0.add(const Duration(minutes: 9))), _msg('b2', t0.add(const Duration(minutes: 2)))],
        'cara': <ChatMessage>[_msg('c1', t0.add(const Duration(minutes: 5)))],
        ChatThread.familyId: <ChatMessage>[_msg('f1', t0.add(const Duration(hours: 5)))],
      };
      final rows = orderedThreadRows(threads, (id) => byThread[id] ?? const <ChatMessage>[], const <String>{}, null);
      expect(rows.map((r) => r.thread.id), <String>[ChatThread.familyId, 'ben', 'cara', 'anton', 'dora']);
      expect(rows[1].last!.id, 'b1');
    });

    test('Vorschautext: Text, Du:, Anhang, Termin, nicht lesbar, blockiert, Zeilenumbrüche (de)', () {
      final l = AppLocalizationsDe();
      String p(ChatMessage m, {bool mine = false}) => threadPreviewText(l, m, mine: mine);
      ChatMessage m({String body = '', AttachmentInfo? attachment, String? event, bool undecryptable = false, bool blockedAttachment = false}) =>
          ChatMessage(
            id: 'i',
            senderId: '@ben:fake.test',
            senderName: 'Ben',
            time: t0,
            body: body,
            attachment: attachment,
            sharedEventId: event,
            undecryptable: undecryptable,
            blockedAttachment: blockedAttachment,
          );
      expect(p(m(body: 'Hallo')), 'Hallo');
      expect(p(m(body: 'Hallo'), mine: true), 'Du: Hallo');
      expect(p(m(body: ' Zeile 1 \n\n  Zeile 2\r\nZeile 3 ')), 'Zeile 1 Zeile 2 Zeile 3');
      expect(p(m(attachment: const AttachmentInfo(name: 'a.png', mimeType: 'image/png', size: 3))), 'Anhang');
      expect(p(m(event: 'e1')), 'Termin');
      expect(p(m(event: 'e1'), mine: true), 'Du: Termin');
      expect(p(m(body: 'geheim', undecryptable: true)), 'Nachricht kann nicht entschlüsselt werden');
      expect(p(m(blockedAttachment: true)), 'Anhang blockiert (Typ oder Größe nicht erlaubt)');
      expect(p(m()), isEmpty);
      expect(p(m(), mine: true), isEmpty, reason: 'kein „Du: “ ohne Inhalt');
    });

    test('Vorschautext englisch', () {
      final l = AppLocalizationsEn();
      expect(threadPreviewText(l, _msg('a', t0, body: 'Hi'), mine: true), 'You: Hi');
      expect(threadPreviewText(l, _msg('a', t0, body: ''), mine: false), isEmpty);
      expect(l.chatPreviewAttachment, 'Attachment');
      expect(l.chatPreviewEvent, 'Event');
      expect(l.chatBackToList, 'Back to conversations');
    });
  });

  group('Gesprächsliste', () {
    testWidgets('Zeilen: Titel, Vorschau, Du:, Anhang, Termin, Zähler, fett bei Ungelesenem, Familienchat zuerst', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final cara = await _member(app, 'cara', 'Cara');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      final dmCara = await cara.startDirectChat(app.gateway.userId!);
      await app.gateway.sendMessage('Willkommen');
      await ben.sendMessage('Zeile 1\nZeile 2', threadId: dm);
      await ben.sendMessage('Hast du Zeit?', threadId: dm);
      await app.gateway.sendMessage('Ja, gleich', threadId: dmCara);
      await _start(tester, app);

      expect(find.text('Gespräche'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final rows = tester.widgetList<InkWell>(find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey<String>)).map((w) => (w.key! as ValueKey<String>).value);
      expect(rows.first, 'thread-family', reason: 'Familienchat zuerst');
      expect(rows.toList(), <String>['thread-family', 'thread-$dmCara', 'thread-$dm'], reason: 'Cara schrieb zuletzt');
      expect(find.descendant(of: _row(dm), matching: find.text('Hast du Zeit?')), findsOneWidget);
      expect(find.descendant(of: _row(dm), matching: find.text('2')), findsOneWidget, reason: 'Zähler');
      expect(find.descendant(of: _row(dmCara), matching: find.text('Du: Ja, gleich')), findsOneWidget);
      expect(find.descendant(of: _row(ChatThread.familyId), matching: find.text('Du: Willkommen')), findsOneWidget);
      Text title(String id, String text) => tester.widget<Text>(find.descendant(of: _row(id), matching: find.text(text)));
      expect(title(dm, 'Ben').style?.fontWeight, FontWeight.w700, reason: 'Ungelesenes fett');
      expect(title(dmCara, 'Cara').style?.fontWeight, isNot(FontWeight.w700));

      await ben.sendMessage('Zeile 1\nZeile 2', threadId: dm);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.descendant(of: _row(dm), matching: find.text('Zeile 1 Zeile 2')), findsOneWidget, reason: 'eine Zeile');
    });

    testWidgets('Anhang und Termin ohne Text, nicht lesbar und blockierter Absender in der Vorschau', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final cara = await _member(app, 'cara', 'Cara');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      final dmCara = await cara.startDirectChat(app.gateway.userId!);
      app.server.post(app.server.dmRooms[dm]!, ben.userId!, 'm.room.message', <String, Object?>{
        'body': '',
        'file_name': 'a.png',
        'mime': 'image/png',
        'size': 3,
      });
      await cara.sendMessage('x', threadId: dmCara);
      app.gateway.undecryptable.add(app.gateway.messagesIn(dmCara).single.id);
      await cara.sendMessage('Hallo Familie');
      await ben.sendMessage('Später von Ben');
      await app.services.settings.update((s) => s.copyWith(blockedUsers: <String>[ben.userId!]));
      await _start(tester, app);
      // Ben ist blockiert: sein Einzelchat fehlt, seine Familiennachricht ist keine Vorschau.
      expect(_row(dm), findsNothing);
      expect(find.descendant(of: _row(ChatThread.familyId), matching: find.text('Hallo Familie')), findsOneWidget);
      expect(find.descendant(of: _row(dmCara), matching: find.text('Nachricht kann nicht entschlüsselt werden')), findsOneWidget);

      await app.services.settings.update((s) => s.copyWith(blockedUsers: const <String>[]));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _row(dm), matching: find.text('Anhang')), findsOneWidget);
      app.server.post(app.server.dmRooms[dm]!, ben.userId!, 'm.room.message', <String, Object?>{'body': '', 'event_ref': 'ev1'});
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.descendant(of: _row(dm), matching: find.text('Termin')), findsOneWidget);
    });

    testWidgets('ohne Nachricht: Online-Status (Einzelchat) bzw. „Noch keine Nachrichten“; Status live', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await _start(tester, app);
      expect(find.descendant(of: _row(ChatThread.familyId), matching: find.text('Noch keine Nachrichten.')), findsOneWidget);
      expect(find.descendant(of: _row(dm), matching: find.text('Status unbekannt')), findsOneWidget);
      await ben.announcePresence(online: true);
      await tester.pumpAndSettle();
      expect(find.descendant(of: _row(dm), matching: find.text('Online')), findsOneWidget);
      expect(find.descendant(of: _row(dm), matching: find.text('Status unbekannt')), findsNothing);
    });

    testWidgets('Zeit: heute Uhrzeit (24 und 12 Stunden), gestern „Gestern“, sonst Datum', (tester) async {
      _wide(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 5);
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 5);
      for (final use24h in <bool>[true, false]) {
        final app = await buildTestApp();
        final ben = await _member(app, 'ben', 'Ben');
        final cara = await _member(app, 'cara', 'Cara');
        final dora = await _member(app, 'dora', 'Dora');
        final dmB = await ben.startDirectChat(app.gateway.userId!);
        final dmC = await cara.startDirectChat(app.gateway.userId!);
        final dmD = await dora.startDirectChat(app.gateway.userId!);
        app.server.nextTime = today.toUtc();
        await ben.sendMessage('heute', threadId: dmB);
        app.server.nextTime = yesterday.toUtc();
        await cara.sendMessage('gestern', threadId: dmC);
        await dora.sendMessage('früher', threadId: dmD);
        await _start(tester, app, media: (m) => m.copyWith(alwaysUse24HourFormat: use24h));
        final clock = (use24h ? DateFormat.Hm('de') : DateFormat.jm('de')).format(DateTime(2000, 1, 1, 10, 5));
        expect(find.descendant(of: _row(dmB), matching: find.text(clock)), findsOneWidget, reason: 'heute, 24h=$use24h');
        expect(find.descendant(of: _row(dmC), matching: find.text('Gestern')), findsOneWidget);
        final dateText = DateFormat.yMd('de').format(app.gateway.messagesIn(dmD).single.time.toLocal());
        expect(find.descendant(of: _row(dmD), matching: find.text(dateText)), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Tippen öffnet das Gespräch, Pfeil führt zurück, der Entwurf bleibt (#410)', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await _start(tester, app);
      await _open(tester, ChatThread.familyId);
      expect(_back, findsOneWidget);
      expect(find.descendant(of: find.byType(Row), matching: find.text('Familie Test')), findsWidgets);
      await tester.enterText(find.byType(TextField), 'Entwurf');
      await _toList(tester);
      expect(find.byType(TextField), findsNothing);
      await _open(tester, dm);
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Entwurf');
    });

    testWidgets('Semantik der Zeile (Gespräch, Status, Vorschau, Zähler) und des Pfeils', (tester) async {
      _wide(tester);
      final handle = tester.ensureSemantics();
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Hast du Zeit?', threadId: dm);
      await _start(tester, app);
      final row = tester.getSemantics(_row(dm));
      expect(row.label, 'Einzelchat mit Ben, Status unbekannt, Hast du Zeit?, 1 ungelesen');
      expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(_row(dm));
      await tester.pumpAndSettle();
      final arrow = tester.getSemantics(_back);
      expect(arrow.getSemanticsData().tooltip, 'Zurück zu den Gesprächen');
      expect(arrow.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('auch im Zweispalter (1000 px, Tab Kalender): Liste in der Chatspalte, Zeile öffnet das Gespräch', (tester) async {
      _wide(tester, width: 1000, height: 900);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Hallo Anna', threadId: dm);
      await _start(tester, app, chatTab: false);
      await tester.tap(navTab('Kalender'));
      await tester.pumpAndSettle();
      expect(_row(dm), findsOneWidget);
      expect(app.services.visibleChatThread, isNull, reason: 'die Liste zeigt kein Gespräch');
      expect(app.gateway.unreadIn(dm), 1, reason: 'nichts als gelesen markiert');
      await tester.tap(_row(dm));
      await tester.pumpAndSettle();
      expect(app.services.visibleChatThread, dm);
      expect(app.gateway.unreadIn(dm), 0);
      await _toList(tester);
      expect(app.services.visibleChatThread, isNull);
    });
  });

  group('Sichtbarkeit und Lesestatus', () {
    testWidgets('die Liste markiert nichts als gelesen, das geöffnete Gespräch schon', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('privat', threadId: dm);
      await ben.sendMessage('öffentlich');
      await _start(tester, app);
      expect(app.services.visibleChatThread, isNull);
      expect(app.gateway.markedRead, isEmpty);
      expect(app.gateway.unreadCount, 2);
      await _open(tester, dm);
      expect(app.services.visibleChatThread, dm);
      expect(app.gateway.markedRead, <String>[dm]);
      expect(app.gateway.unreadIn(ChatThread.familyId), 1, reason: 'der Familienchat blieb ungelesen');
    });

    testWidgets('Eintritt in die Liste gibt die Marke frei (Tab vor dem Sync aktiv, kein Pinnen)', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      await ben.sendMessage('alt');
      app.gateway.syncDone = false;
      await _start(tester, app);
      expect(find.text('alt'), findsOneWidget, reason: 'ein Gespräch: direkt der Familienchat, gelesen markiert');
      expect(app.gateway.unreadIn(ChatThread.familyId), 0);
      await ben.startDirectChat(app.gateway.userId!);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Gespräche'), findsOneWidget, reason: 'vor dem ersten Sync wird nichts festgehalten: Liste');
      await ben.sendMessage('neu');
      await tester.pumpAndSettle();
      await _open(tester, ChatThread.familyId);
      expect(find.text('neu'), findsOneWidget);
      expect(find.text('Neue Nachrichten'), findsOneWidget, reason: 'die Marke wird beim Öffnen neu bestimmt');
    });

    testWidgets('Sperre: die Vorschau ist weder sichtbar noch in der Semantik', (tester) async {
      _wide(tester);
      final handle = tester.ensureSemantics();
      final app = await buildTestApp(lockEnabled: true);
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Streng geheim', threadId: dm);
      await _start(tester, app);
      expect(_allLabels(tester).where((l) => l.contains('Streng geheim')), hasLength(1));
      app.auth.succeed = false;
      app.services.lock.lockNow();
      await tester.pumpAndSettle();
      expect(_allLabels(tester).where((l) => l.contains('Streng geheim')), isEmpty);
      expect(app.gateway.markedRead, isEmpty);
      handle.dispose();
    });
  });

  group('Zurück-Taste und Zurück-Geste', () {
    Future<(TestApp, String)> world(WidgetTester tester, {double width = 900, double height = 3000}) async {
      _wide(tester, width: width, height: height);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      return (app, dm);
    }

    testWidgets('im Gespräch führt Zurück zur Liste; auf der Liste verlässt es die App', (tester) async {
      final (app, dm) = await world(tester);
      final exits = _trackExits(tester);
      await _start(tester, app);
      await _open(tester, dm);
      await tester.enterText(find.byType(TextField), 'Entwurf');
      await _systemBack(tester);
      expect(find.text('Gespräche'), findsOneWidget);
      expect(exits.count, 0, reason: 'blockiert, nicht verlassen');
      await _systemBack(tester);
      expect(exits.count, 1, reason: 'auf der Liste wie bisher die App verlassen');
    });

    testWidgets('auf einem anderen Tab wird Zurück nicht blockiert, das Gespräch bleibt offen', (tester) async {
      final (app, dm) = await world(tester);
      final exits = _trackExits(tester);
      await _start(tester, app);
      await _open(tester, dm);
      await tester.tap(navTab('Einkauf'));
      await tester.pumpAndSettle();
      await _systemBack(tester);
      expect(exits.count, 1);
      await tester.tap(navTab('Chat'));
      await tester.pumpAndSettle();
      expect(_back, findsOneWidget, reason: 'das Gespräch blieb offen');
    });

    testWidgets('ohne Einzelchats wird Zurück im Chat nicht blockiert', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final exits = _trackExits(tester);
      await _start(tester, app);
      await _systemBack(tester);
      expect(exits.count, 1);
    });

    testWidgets('Zweispalter, Tab Kalender: Zurück wirkt auf die Chatspalte', (tester) async {
      final (app, dm) = await world(tester, width: 1000, height: 900);
      final exits = _trackExits(tester);
      await _start(tester, app, chatTab: false);
      await tester.tap(navTab('Kalender'));
      await tester.pumpAndSettle();
      await tester.tap(_row(dm));
      await tester.pumpAndSettle();
      await _systemBack(tester);
      expect(_row(dm), findsOneWidget, reason: 'zurück zur Liste');
      expect(exits.count, 0);
    });

    testWidgets('bei offenem Menü (Endrawer) schließt Zurück nur das Menü', (tester) async {
      final (app, dm) = await world(tester);
      final exits = _trackExits(tester);
      await _start(tester, app);
      await _open(tester, dm);
      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      await _systemBack(tester);
      expect(find.byType(Drawer), findsNothing);
      expect(_back, findsOneWidget, reason: 'das Gespräch bleibt offen');
      expect(exits.count, 0);
      await _systemBack(tester);
      expect(_row(dm), findsOneWidget, reason: 'jetzt zur Liste');
    });

    testWidgets('bei App-Sperre wird Zurück nicht vom Chat blockiert', (tester) async {
      _wide(tester);
      final app = await buildTestApp(lockEnabled: true);
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      final exits = _trackExits(tester);
      await _start(tester, app);
      await _open(tester, dm);
      app.auth.succeed = false;
      app.services.lock.lockNow();
      await tester.pumpAndSettle();
      await _systemBack(tester);
      expect(exits.count, 1);
    });

    testWidgets('Zurück bei offenem Nachrichtenblatt schließt nur das Blatt, ein zweites Zurück führt zur Liste', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Hallo Anna', threadId: dm);
      final exits = _trackExits(tester);
      await _start(tester, app);
      await _open(tester, dm);
      await tester.longPress(find.text('Hallo Anna'));
      await tester.pumpAndSettle();
      expect(find.text('Nachricht melden'), findsOneWidget, reason: 'Blatt offen');

      await _systemBack(tester);
      expect(find.text('Nachricht melden'), findsNothing, reason: 'das Blatt ist zu');
      expect(_back, findsOneWidget, reason: 'das Gespräch bleibt offen');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gespräche'), findsNothing);
      expect(app.services.visibleChatThread, dm);
      expect(exits.count, 0);

      await _systemBack(tester);
      expect(find.text('Gespräche'), findsOneWidget, reason: 'zweites Zurück: Liste');
      expect(_row(dm), findsOneWidget);
      expect(exits.count, 0);
    });
  });

  group('Übergänge', () {
    testWidgets('verschwindet das offene Gespräch bei mehreren Gesprächen: Familienchat mit Kopfzeile, schon im ersten Frame', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final cara = await _member(app, 'cara', 'Cara');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await app.gateway.startDirectChat(cara.userId!);
      await ben.sendMessage('privat', threadId: dm);
      await _start(tester, app);
      await _open(tester, dm);
      app.gateway.markedRead.clear();
      app.gateway.loadedOlder.clear();
      await app.gateway.removeMember(ben.userId!);
      await tester.pump();
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget, reason: 'derselbe Frame zeigt schon den Familienchat');
      expect(_back, findsOneWidget, reason: 'bei mehreren Gesprächen mit Kopfzeile');
      expect(app.gateway.markedRead, isNot(contains(dm)));
      expect(app.gateway.loadedOlder, isNot(contains(dm)));
      await tester.pumpAndSettle();
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      await _toList(tester);
      expect(_row(ChatThread.familyId), findsOneWidget);
      expect(_row(dm), findsNothing);
    });

    testWidgets('Blockieren blendet das offene Gespräch aus: Familienchat statt Liste', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await _start(tester, app);
      await _open(tester, dm);
      await app.services.settings.update((s) => s.copyWith(blockedUsers: <String>[ben.userId!]));
      await tester.pumpAndSettle();
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      expect(_back, findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('chatRequest öffnet ein Gespräch aus der Liste und auch ein schon gewähltes nach Zurück', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await _start(tester, app);
      expect(find.text('Gespräche'), findsOneWidget);
      app.services.chatRequest.value = dm;
      await tester.pumpAndSettle();
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      await _toList(tester);
      app.services.chatRequest.value = dm;
      await tester.pumpAndSettle();
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget, reason: 'wieder geöffnet');
      app.services.chatRequest.value = ChatThread.familyId;
      await tester.pumpAndSettle();
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      expect(_back, findsOneWidget);
    });

    Future<(TestApp, String)> waiting(WidgetTester tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final cara = await _member(app, 'cara', 'Cara');
      final ben = await _member(app, 'ben', 'Ben');
      await app.gateway.startDirectChat(cara.userId!);
      app.gateway.delayNewDirectChats = true;
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await _start(tester, app);
      app.services.chatRequest.value = dm;
      await tester.pump();
      await tester.pump();
      return (app, dm);
    }

    testWidgets('Warten bei mehreren Gesprächen: Ladeanzeige mit Pfeil, ohne Eingabefeld; Erscheinen beendet das Warten (kein Timeout)', (tester) async {
      final (app, _) = await waiting(tester);
      expect(find.text('Einzelchat wird geöffnet …'), findsOneWidget);
      expect(_back, findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      app.gateway.hiddenThreads.clear();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(find.text('Der Einzelchat konnte nicht geöffnet werden. Bitte versuche es erneut.'), findsNothing);
      expect(find.text('Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt'), findsOneWidget, reason: 'bleibt im Gespräch');
    });

    testWidgets('Zurück-Pfeil bricht das Warten ab: Liste, später kein Timeout-Hinweis', (tester) async {
      final (app, dm) = await waiting(tester);
      await _toList(tester);
      expect(find.text('Gespräche'), findsOneWidget);
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(find.text('Der Einzelchat konnte nicht geöffnet werden. Bitte versuche es erneut.'), findsNothing);
      expect(find.text('Gespräche'), findsOneWidget);
      app.gateway.hiddenThreads.clear();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Gespräche'), findsOneWidget, reason: 'das Erscheinen öffnet nichts von selbst');
      expect(_row(dm), findsOneWidget);
    });

    testWidgets('Pinnen: einem Nutzer im Familienchat kommt ein Einzelchat hinzu, er bleibt im Familienchat', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      await _start(tester, app);
      await tester.enterText(find.byType(TextField), 'Entwurf');
      await ben.startDirectChat(app.gateway.userId!);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(_back, findsOneWidget);
    });
  });

  group('Ziel-ID: Senden, Anhang, Reaktion, Melden, Nachladen', () {
    Future<(TestApp, FakeMatrixGateway, String)> world(WidgetTester tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Hallo Anna', threadId: dm);
      await ben.sendMessage('Hallo alle');
      return (app, ben, dm);
    }

    testWidgets('Senden: im Familienchat an die Familie, im Einzelchat an dessen ID', (tester) async {
      final (app, _, dm) = await world(tester);
      await _start(tester, app);
      await _open(tester, ChatThread.familyId);
      await tester.enterText(find.byType(TextField), 'an alle');
      await tester.tap(find.byTooltip('Senden'));
      await tester.pumpAndSettle();
      await _toList(tester);
      await _open(tester, dm);
      await tester.enterText(find.byType(TextField), 'nur Ben');
      await tester.tap(find.byTooltip('Senden'));
      await tester.pumpAndSettle();
      expect(app.gateway.messages.map((m) => m.body), contains('an alle'));
      expect(app.gateway.messages.map((m) => m.body), isNot(contains('nur Ben')));
      expect(app.gateway.messagesIn(dm).map((m) => m.body), contains('nur Ben'));
    });

    testWidgets('Anhang: ein Gesprächswechsel während der Dateiauswahl ändert das Ziel nicht', (tester) async {
      final (app, _, dm) = await world(tester);
      final files = app.services.files as FakeFileAccess;
      files.next = PickedFile(name: 'foto.png', bytes: base64Decode(_png));
      final gate = Completer<void>();
      files.pickGate = gate;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await _start(tester, app);
      await _open(tester, dm);
      await tester.tap(find.byTooltip('Datei anhängen'));
      await tester.pump();
      await _toList(tester);
      await _open(tester, ChatThread.familyId);
      gate.complete();
      await tester.pumpAndSettle();
      expect(app.gateway.messagesIn(dm).where((m) => m.attachment?.name == 'foto.png'), hasLength(1), reason: 'ging an das Gespräch, in dem gewählt wurde');
      expect(app.gateway.messages.where((m) => m.attachment != null), isEmpty, reason: 'nicht an die Familie');
    });

    testWidgets('Reaktion und Melden im Einzelchat gehen an dessen Raum', (tester) async {
      final (app, _, dm) = await world(tester);
      await _start(tester, app);
      await _open(tester, dm);
      await tester.longPress(find.text('Hallo Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('👍')).first);
      await tester.pumpAndSettle();
      expect(app.gateway.messagesIn(dm).firstWhere((m) => m.body == 'Hallo Anna').reactions.keys, contains('👍'));

      await tester.longPress(find.text('Hallo Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nachricht melden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam oder Werbung'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Melden'));
      await tester.pumpAndSettle();
      expect(app.server.reports.single.roomId, dm);
    });

    testWidgets('Nachladen: nur für das gezeigte Gespräch, auf der Liste nie', (tester) async {
      _wide(tester, height: 900);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      for (var i = 0; i < 40; i++) {
        await ben.sendMessage('Nachricht $i', threadId: dm);
      }
      await _start(tester, app);
      expect(app.gateway.loadedOlder, isEmpty, reason: 'Liste');
      await _open(tester, dm);
      final list = find.byType(ListView).last;
      await tester.fling(list, const Offset(0, 3000), 8000);
      await tester.pumpAndSettle();
      expect(app.gateway.loadedOlder, isNotEmpty);
      expect(app.gateway.loadedOlder.toSet(), <String>{dm});
      await _toList(tester);
      app.gateway.loadedOlder.clear();
      await tester.fling(find.byType(ListView).last, const Offset(0, 3000), 8000);
      await tester.pumpAndSettle();
      expect(app.gateway.loadedOlder, isEmpty, reason: 'auf der Liste hängt kein Nachladen');
    });
  });

  group('Lücken Teststärke #423', () {
    testWidgets('Eintritt in die Liste: Familienchat war sichtbar, danach kein Gespräch sichtbar, nichts gelesen markiert, Marke neu', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      await ben.sendMessage('alt');
      app.gateway.syncDone = false;
      await _start(tester, app);
      expect(app.services.visibleChatThread, ChatThread.familyId, reason: 'ein Gespräch: der Familienchat ist sichtbar');
      expect(app.gateway.markedRead, <String>[ChatThread.familyId]);
      expect(app.gateway.unreadIn(ChatThread.familyId), 0);

      // Zweites Gespräch ohne Pinnen (erster Sync noch nicht fertig): die Liste erscheint.
      final dm = await ben.startDirectChat(app.gateway.userId!);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Gespräche'), findsOneWidget);
      expect(app.services.visibleChatThread, isNull, reason: 'die Liste zeigt kein Gespräch');

      // Neu eintreffende Nachrichten bei offener Liste bleiben ungelesen.
      app.gateway.markedRead.clear();
      await ben.sendMessage('neu');
      await ben.sendMessage('privat', threadId: dm);
      await tester.pumpAndSettle();
      expect(find.text('Gespräche'), findsOneWidget);
      expect(app.gateway.markedRead, isEmpty, reason: 'auf der Liste wird nichts gelesen markiert');
      expect(app.gateway.unreadIn(ChatThread.familyId), 1);
      expect(app.gateway.unreadIn(dm), 1);
      expect(app.services.visibleChatThread, isNull);

      await _open(tester, ChatThread.familyId);
      expect(app.services.visibleChatThread, ChatThread.familyId);
      expect(find.text('Neue Nachrichten'), findsOneWidget, reason: 'die Marke wird beim Öffnen neu bestimmt');
      expect(app.gateway.markedRead, <String>[ChatThread.familyId], reason: 'erst das Öffnen markiert, und nur dieses Gespräch');
    });

    testWidgets('genau eine Überschrift je Ansicht: Liste „Gespräche“, Gespräch der Titel der Kopfzeile', (tester) async {
      _wide(tester);
      final handle = tester.ensureSemantics();
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      await ben.sendMessage('Hallo Anna', threadId: dm);
      await _start(tester, app);

      Finder headers(Finder within) => find.descendant(of: within, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true));
      // Beschriftungen aller Semantik-Header (die Shell hat eigene, etwa den Titel der App-Leiste).
      List<String> headerLabels() {
        final n = <String>[];
        void visit(SemanticsNode node) {
          final d = node.getSemanticsData();
          if (d.flagsCollection.isHeader) n.add(d.label);
          node.visitChildren((c) {
            visit(c);
            return true;
          });
        }

        SemanticsNode? root;
        tester.binding.rootPipelineOwner.visitChildren((o) => root ??= o.semanticsOwner?.rootSemanticsNode);
        visit(root!);
        return n;
      }

      // Liste: genau ein Header im Widgetbaum der Liste und im Semantikbaum.
      expect(headers(find.byType(ListView)), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: headers(find.byType(ListView)), matching: find.byType(Text))).data, 'Gespräche');
      expect(headerLabels().where((l) => l == 'Gespräche'), hasLength(1), reason: 'Liste: ein Semantik-Header „Gespräche“');
      final shell = headerLabels().length - 1;

      // Gespräch: genau ein Header in der Kopfzeile (Datumszeilen im Verlauf sind eigene Header und zählen nicht).
      await _open(tester, dm);
      final headerRow = find.ancestor(of: _back, matching: find.byType(Row)).first;
      expect(headers(headerRow), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: headers(headerRow), matching: find.byType(Text))).data, 'Ben');
      expect(find.text('Gespräche'), findsNothing, reason: 'die Listenüberschrift ist weg');
      final dayHeaders = headers(find.byType(ListView)).evaluate().length;
      expect(headerLabels().where((l) => l == 'Ben'), hasLength(1), reason: 'ein Semantik-Header mit dem Titel');
      expect(headerLabels().where((l) => l == 'Gespräche'), isEmpty);
      expect(headerLabels().length, shell + 1 + dayHeaders, reason: 'Shell, Kopfzeile und Datumszeilen, nichts doppelt');
      handle.dispose();
    });

    testWidgets('Timeout bei mehreren Gesprächen: Familienchat mit Kopfzeile und Pfeil plus Hinweis, nichts ging an ein anderes Gespräch', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final cara = await _member(app, 'cara', 'Cara');
      final ben = await _member(app, 'ben', 'Ben');
      final dmCara = await app.gateway.startDirectChat(cara.userId!);
      app.gateway.delayNewDirectChats = true;
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await _start(tester, app);
      expect(_row(dmCara), findsOneWidget);
      expect(_row(dm), findsNothing, reason: 'das angeforderte Gespräch erscheint nie');
      app.services.chatRequest.value = dm;
      await tester.pump();
      await tester.pump();
      expect(find.text('Einzelchat wird geöffnet …'), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'während des Wartens keine Eingabe');

      await tester.pump(_openTimeoutPlus);
      await tester.pumpAndSettle();
      expect(find.text('Der Einzelchat konnte nicht geöffnet werden. Bitte versuche es erneut.'), findsOneWidget);
      expect(find.text('Einzelchat wird geöffnet …'), findsNothing);
      expect(_back, findsOneWidget, reason: 'bei mehreren Gesprächen mit Kopfzeile und Pfeil');
      final headerRow = find.ancestor(of: _back, matching: find.byType(Row)).first;
      expect(find.descendant(of: headerRow, matching: find.text('Familie Test')), findsOneWidget);
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget, reason: 'Familienchat');
      expect(app.services.visibleChatThread, ChatThread.familyId);

      await tester.pump(const Duration(seconds: 10)); // Der Hinweis (Snackbar) verschwindet, er verdeckt sonst das Eingabefeld
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nur an die Familie');
      await tester.tap(find.byTooltip('Senden'));
      await tester.pumpAndSettle();
      expect(app.gateway.messages.map((m) => m.body), contains('nur an die Familie'));
      expect(app.gateway.messagesIn(dm), isEmpty, reason: 'nichts an das nie erschienene Gespräch');
      expect(app.gateway.messagesIn(dmCara), isEmpty, reason: 'nichts an ein anderes Gespräch');
    });

    testWidgets('viele Gespräche: Reihenfolge, jede Zeile erreichbar und mindestens 56 dp hoch, jede öffnet das richtige Gespräch', (tester) async {
      _wide(tester, width: 900, height: 500);
      final app = await buildTestApp();
      // Name, Minuten nach t0 der jüngsten Nachricht: bewusst nicht in Anlegereihenfolge.
      const people = <(String, String, int)>[('ben', 'Ben', 10), ('cara', 'Cara', 50), ('dora', 'Dora', 30), ('emil', 'Emil', 40), ('finn', 'Finn', 20)];
      final t0 = DateTime.utc(2026, 10, 21, 12);
      final ids = <String, String>{};
      app.server.nextTime = t0;
      await app.gateway.sendMessage('Familie alt');
      for (final (name, display, minutes) in people) {
        final device = await _member(app, name, display);
        final dm = await device.startDirectChat(app.gateway.userId!);
        ids[name] = dm;
        app.server.nextTime = t0.add(Duration(minutes: minutes));
        await device.sendMessage('Hallo von $display', threadId: dm);
      }
      await _start(tester, app);

      final expectedOrder = <String>[ChatThread.familyId, ids['cara']!, ids['emil']!, ids['dora']!, ids['finn']!, ids['ben']!];
      final titles = <String, String>{ChatThread.familyId: 'Familie Test', for (final (name, display, _) in people) ids[name]!: display};
      final scrollable = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

      for (final id in expectedOrder) {
        await tester.scrollUntilVisible(_row(id), 100, scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(_row(id), findsOneWidget, reason: 'Zeile $id erreichbar');
        expect(tester.getSize(find.ancestor(of: find.descendant(of: _row(id), matching: find.byType(Row)).first, matching: find.byType(ConstrainedBox)).first).height, greaterThanOrEqualTo(56), reason: 'Zeilenhöhe $id');
        expect(tester.getSize(_row(id)).height, greaterThanOrEqualTo(56), reason: 'Zeilenhöhe $id');
        await tester.tap(_row(id));
        await tester.pumpAndSettle();
        expect(app.services.visibleChatThread, id, reason: 'öffnet das richtige Gespräch');
        final headerRow = find.ancestor(of: _back, matching: find.byType(Row)).first;
        expect(find.descendant(of: headerRow, matching: find.text(titles[id]!)), findsOneWidget);
        await _toList(tester);
        expect(app.services.visibleChatThread, isNull);
      }

      // Reihenfolge: von oben nach unten (alle Zeilen untereinander, die Ordnung folgt aus der Position).
      _wide(tester, width: 900, height: 3000);
      await tester.pumpAndSettle();
      final tops = <String, double>{for (final id in expectedOrder) id: tester.getTopLeft(_row(id)).dy};
      final sorted = tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!));
      expect(sorted, expectedOrder, reason: 'Familienchat zuerst, dann nach jüngster Nachricht');
    });
  });

  group('Englisch', () {
    testWidgets('Liste, Vorschau „You:“, „Yesterday“, Pfeil und Kopfzeile', (tester) async {
      _wide(tester);
      final app = await buildTestApp(lang: 'en');
      final ben = await _member(app, 'ben', 'Ben');
      final dm = await ben.startDirectChat(app.gateway.userId!);
      final now = DateTime.now();
      app.server.nextTime = DateTime(now.year, now.month, now.day - 1, 9, 30).toUtc();
      await app.gateway.sendMessage('See you', threadId: dm);
      await _start(tester, app);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.descendant(of: _row(dm), matching: find.text('You: See you')), findsOneWidget);
      expect(find.descendant(of: _row(dm), matching: find.text('Yesterday')), findsOneWidget);
      await tester.tap(_row(dm));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to conversations'), findsOneWidget);
      expect(find.text('Only between you and Ben, end-to-end encrypted'), findsOneWidget);
    });
  });
}
