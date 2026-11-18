import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #516, E-107: „Letztes Gespräch wieder öffnen“ (Standard aus) und Ungelesenes zuerst in der Liste.
Future<FakeMatrixGateway> _member(TestApp app, String name, String display) async {
  final password = name == 'ben' ? 'geheim456' : 'pw-$name';
  if (!app.server.hasAccount(name)) app.server.addAccount(name, password, displayName: display);
  final device = app.server.newDevice();
  await device.login(server: ServerUrl.tryParse(app.server.host)!, username: name, password: password);
  final room = app.gateway.familyRoom!;
  room.membership['@$name:${app.server.host}'] = MemberStatus.joined;
  device.attachFamilyRoom(room.id);
  return device;
}

Future<void> _start(WidgetTester tester, TestApp app, {bool chatTab = true}) async {
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  if (chatTab) await _tapChat(tester);
}

Future<void> _tapChat(WidgetTester tester) async {
  await tester.tap(navTab('Chat'));
  await tester.pumpAndSettle();
}

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _row(String id) => find.byKey(ValueKey<String>('thread-$id'));
Finder get _back => find.byTooltip('Zurück zu den Gesprächen');
const String _benConversation = 'Nur zwischen dir und Ben, Ende-zu-Ende-verschlüsselt';
const String _caraConversation = 'Nur zwischen dir und Cara, Ende-zu-Ende-verschlüsselt';

Future<void> _enable(TestApp app, {String? last}) =>
    app.services.settings.update((c) => c.copyWith(restoreLastChat: true, lastChatThread: last));

/// Familie, Ben und Cara mit je einem Einzelchat.
Future<({TestApp app, FakeMatrixGateway ben, FakeMatrixGateway cara, String dmBen, String dmCara})> _setup() async {
  final app = await buildTestApp();
  final ben = await _member(app, 'ben', 'Ben');
  final cara = await _member(app, 'cara', 'Cara');
  final dmBen = await app.gateway.startDirectChat(ben.userId!);
  final dmCara = await app.gateway.startDirectChat(cara.userId!);
  return (app: app, ben: ben, cara: cara, dmBen: dmBen, dmCara: dmCara);
}

void main() {
  group('Wiederherstellung', () {
    testWidgets('Schalter an, Einzelgespräch gemerkt und geladen: der Chat-Tab öffnet es, Start bleibt „Heute“', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app, last: s.dmBen);
      await _start(tester, s.app, chatTab: false);
      expect(find.text('Gespräche'), findsNothing, reason: 'Chat-Tab nicht aktiv: Start auf „Heute“');
      expect(find.byType(TextField), findsNothing);
      await _tapChat(tester);
      expect(find.text(_benConversation), findsOneWidget);
      expect(find.text('Gespräche'), findsNothing);
      expect(_back, findsOneWidget);
      expect(s.app.services.settings.settings.lastChatThread, s.dmBen, reason: 'Wiederherstellung schreibt nichts');
    });

    testWidgets('gemerkte Familie bei mehreren Gesprächen: Familienchat statt Liste', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app, last: ChatThread.familyId);
      await _start(tester, s.app);
      expect(find.text('Gespräche'), findsNothing);
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      expect(_back, findsOneWidget);
    });

    testWidgets('Schalter aus: Liste, nichts wird gespeichert, auch beim Öffnen und Zurück', (tester) async {
      _wide(tester);
      final s = await _setup();
      await s.app.services.settings.update((c) => c.copyWith(lastChatThread: null));
      await _start(tester, s.app);
      expect(find.text('Gespräche'), findsOneWidget);
      await tester.tap(_row(s.dmBen));
      await tester.pumpAndSettle();
      expect(find.text(_benConversation), findsOneWidget);
      expect(s.app.services.settings.settings.lastChatThread, isNull);
      expect(s.app.store.data, isNot(contains(AppSettings.lastChatThreadKey)));
      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(s.app.store.data, isNot(contains(AppSettings.lastChatThreadKey)));
    });

    testWidgets('Schalter aus, Kennung vorhanden (Altlast): Liste, die Kennung wirkt nicht', (tester) async {
      _wide(tester);
      final s = await _setup();
      await s.app.services.settings.update((c) => c.copyWith(lastChatThread: s.dmBen));
      await _start(tester, s.app);
      expect(find.text('Gespräche'), findsOneWidget);
    });

    testWidgets('Öffnen speichert die Kennung, Zurück zur Liste speichert null (auch in der Ablage)', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app);
      await _start(tester, s.app);
      expect(find.text('Gespräche'), findsOneWidget);
      await tester.tap(_row(s.dmCara));
      await tester.pumpAndSettle();
      expect(find.text(_caraConversation), findsOneWidget);
      expect(s.app.services.settings.settings.lastChatThread, s.dmCara);
      expect(s.app.store.data[AppSettings.lastChatThreadKey], s.dmCara);
      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(s.app.services.settings.settings.lastChatThread, isNull);
      expect(s.app.store.data, isNot(contains(AppSettings.lastChatThreadKey)));
    });

    testWidgets('Timeout-Rückfall auf die Familie speichert die Familien-Kennung', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app);
      await _start(tester, s.app);
      s.app.services.chatRequest.value = '!gibtsnicht:fake.test';
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(s.app.services.settings.settings.lastChatThread, ChatThread.familyId);
    });

    testWidgets('Ziel beim ersten Aktivieren noch nicht geladen: Liste, kein Toast, Kennung bleibt, erscheint später nicht plötzlich', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final cara = await _member(app, 'cara', 'Cara');
      final dmCara = await app.gateway.startDirectChat(cara.userId!);
      app.gateway.delayNewDirectChats = true;
      final dmBen = await app.gateway.startDirectChat(ben.userId!);
      await _enable(app, last: dmBen);
      await _start(tester, app);
      expect(find.text('Gespräche'), findsOneWidget);
      expect(_row(dmCara), findsOneWidget);
      expect(_row(dmBen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      app.gateway.hiddenThreads.clear();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Gespräche'), findsOneWidget, reason: 'bleibt bei der Liste');
      expect(_row(dmBen), findsOneWidget);
      expect(find.text(_benConversation), findsNothing);
      expect(app.services.settings.settings.lastChatThread, dmBen, reason: 'gemerkt bleibt gemerkt');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Ziel vor der ersten Aktivierung geladen: der Tab öffnet es direkt', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final cara = await _member(app, 'cara', 'Cara');
      final ben = await _member(app, 'ben', 'Ben');
      final dmCara = await app.gateway.startDirectChat(cara.userId!);
      app.gateway.delayNewDirectChats = true;
      final dmBen = await app.gateway.startDirectChat(ben.userId!);
      await _enable(app, last: dmBen);
      await _start(tester, app, chatTab: false);
      app.gateway.hiddenThreads.clear();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(_row(dmCara), findsNothing, reason: 'Chat-Tab noch nicht sichtbar');
      await _tapChat(tester);
      expect(find.text(_benConversation), findsOneWidget);
      expect(find.text('Gespräche'), findsNothing);
    });

    testWidgets('Pinnen: nur der Familienchat sichtbar, Tab aktiv: Wiederherstellung verfällt, Familienchat gepinnt wie bisher', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      app.gateway.delayNewDirectChats = true;
      final dmBen = await app.gateway.startDirectChat(ben.userId!);
      await _enable(app, last: dmBen);
      await _start(tester, app);
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);
      expect(_back, findsNothing);
      app.gateway.hiddenThreads.clear();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget, reason: 'bleibt im Familienchat');
      expect(find.text(_benConversation), findsNothing);
      expect(app.services.settings.settings.lastChatThread, dmBen, reason: 'Pinnen speichert nichts');
    });

    testWidgets('gemerktes Gespräch blockiert: Liste statt Wiederherstellung', (tester) async {
      _wide(tester);
      final s = await _setup();
      await s.app.services.settings.update((c) => c.copyWith(blockedUsers: <String>[s.ben.userId!]));
      await _enable(s.app, last: s.dmBen);
      await _start(tester, s.app);
      expect(find.text('Gespräche'), findsOneWidget);
      expect(_row(s.dmBen), findsNothing);
      expect(_row(s.dmCara), findsOneWidget);
    });

    testWidgets('chatRequest vor dem Start: Anforderung gewinnt, kein Build-Fehler, Kennung nach dem ersten Frame gemerkt', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app, last: s.dmBen);
      s.app.services.chatRequest.value = s.dmCara;
      await _start(tester, s.app);
      expect(tester.takeException(), isNull);
      expect(find.text(_caraConversation), findsOneWidget);
      expect(s.app.services.settings.settings.lastChatThread, s.dmCara);
    });

    testWidgets('chatRequest vor der ersten Aktivierung verwirft die Wiederherstellung', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app, last: s.dmBen);
      await _start(tester, s.app, chatTab: false);
      s.app.services.chatRequest.value = s.dmCara;
      await tester.pumpAndSettle();
      await _tapChat(tester);
      expect(find.text(_caraConversation), findsOneWidget);
      expect(find.text(_benConversation), findsNothing);
    });

    testWidgets('Ausschalten vor der Wiederherstellung verwirft sie und löscht die Kennung', (tester) async {
      _wide(tester);
      final app = await buildTestApp();
      final ben = await _member(app, 'ben', 'Ben');
      final cara = await _member(app, 'cara', 'Cara');
      await app.gateway.startDirectChat(cara.userId!);
      app.gateway.delayNewDirectChats = true;
      final dmBen = await app.gateway.startDirectChat(ben.userId!);
      await _enable(app, last: dmBen);
      await _start(tester, app, chatTab: false);
      await app.services.settings.update((c) => c.copyWith(restoreLastChat: false, lastChatThread: null));
      await tester.pumpAndSettle();
      app.gateway.hiddenThreads.clear();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      await _tapChat(tester);
      expect(find.text('Gespräche'), findsOneWidget);
      expect(find.text(_benConversation), findsNothing);
      expect(app.store.data, isNot(contains(AppSettings.lastChatThreadKey)));
    });

    testWidgets('nach der ersten Aktivierung wird nicht erneut wiederhergestellt (Liste → anderer Tab → Chat)', (tester) async {
      _wide(tester);
      final s = await _setup();
      await _enable(s.app, last: s.dmBen);
      await _start(tester, s.app);
      expect(find.text(_benConversation), findsOneWidget);
      await tester.tap(_back);
      await tester.pumpAndSettle();
      await tester.tap(navTab('Heute'));
      await tester.pumpAndSettle();
      await _tapChat(tester);
      expect(find.text('Gespräche'), findsOneWidget, reason: 'Zurück zur Liste war die letzte Handlung');
    });
  });

  group('Ungelesene zuerst in der Liste', () {
    testWidgets('Ungelesenes älteres Gespräch steht vor dem gelesenen neueren, Familie bleibt oben', (tester) async {
      _wide(tester);
      final s = await _setup();
      await s.ben.sendMessage('alt, ungelesen', threadId: s.dmBen);
      await s.app.gateway.sendMessage('neu, eigene', threadId: s.dmCara);
      await s.app.gateway.sendMessage('Familie');
      await _start(tester, s.app);
      final rows = tester
          .widgetList<InkWell>(find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey<String>))
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(rows, <String>['thread-family', 'thread-${s.dmBen}', 'thread-${s.dmCara}']);
    });
  });
}
