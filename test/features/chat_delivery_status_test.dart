import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #526, E-106: Zustellstatus unter eigenen Nachrichten: Sendet, Gesendet, Gelesen (Einzelchat) bzw. Gelesen von n
/// (Familienchat, Tippen zeigt die Namen). Blockierte Nutzer zählen nicht.
Future<FakeMatrixGateway> _join(TestApp app, String name) async {
  if (name != 'ben') app.server.addAccount(name, 'geheim456', displayName: 'Cleo');
  final dev = app.server.newDevice();
  await dev.login(server: ServerUrl.tryParse(app.server.host)!, username: name, password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@$name:${app.server.host}'] = MemberStatus.joined;
  dev.attachFamilyRoom(room.id);
  return dev;
}

Future<void> _open(WidgetTester tester, TestApp app, {String? thread}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Chat'));
  await tester.pumpAndSettle();
  if (thread != null) {
    await tester.tap(find.byKey(ValueKey<String>('thread-$thread')));
    await tester.pumpAndSettle();
  }
}

Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

String _lastOwnId(TestApp app, String thread) => app.gateway.messagesIn(thread).lastWhere((m) => m.senderId == app.gateway.userId).id;

void main() {
  testWidgets('Familienchat: gesendet zeigt Haken mit Beschriftung, noch kein Text', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp();
    await _join(app, 'ben');
    await app.gateway.sendMessage('Hallo');
    await _open(tester, app);
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'Gesendet$')), findsOneWidget);
    expect(find.textContaining('Gelesen von'), findsNothing);
    handle.dispose();
  });

  testWidgets('wird gesendet: Uhr statt Haken', (tester) async {
    final app = await buildTestApp();
    await _join(app, 'ben');
    await app.gateway.sendMessage('Hallo');
    app.gateway.sendStates[_lastOwnId(app, ChatThread.familyId)] = (status: MessageStatus.sending, retryable: false);
    await _open(tester, app);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'Wird gesendet …$')), findsOneWidget);
  });

  testWidgets('gescheiterte Nachricht: keine Statuszeile, eigene Darstellung bleibt', (tester) async {
    final app = await buildTestApp();
    await _join(app, 'ben');
    await app.gateway.sendMessage('Hallo');
    app.gateway.sendStates[_lastOwnId(app, ChatThread.familyId)] = (status: MessageStatus.failed, retryable: false);
    await _open(tester, app);
    expect(find.byIcon(Icons.done), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.text('Nicht gesendet. Bitte erneut schreiben.'), findsOneWidget);
  });

  testWidgets('Familienchat: Gelesen von 1 und 2, Tippen zeigt die Namen; fremde Nachricht ohne Status', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp();
    final ben = await _join(app, 'ben');
    final cleo = await _join(app, 'cleo');
    await ben.sendMessage('Fremd');
    await app.gateway.sendMessage('Hallo');
    final id = _lastOwnId(app, ChatThread.familyId);
    await _open(tester, app);
    expect(find.byIcon(Icons.done), findsOneWidget, reason: 'nur die eigene Nachricht trägt einen Status');

    app.gateway.setReadMarker(ben.userId!, id);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.text('Gelesen von 1'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Gelesen von 1')), findsOneWidget);

    app.gateway.setReadMarker(cleo.userId!, id);
    await tester.pumpAndSettle();
    expect(find.text('Gelesen von 2'), findsOneWidget);

    await tester.tap(find.text('Gelesen von 2'));
    await tester.pumpAndSettle();
    expect(find.text('Gelesen von'), findsOneWidget, reason: 'Titel des Blatts');
    expect(_inSheet(app.server.displayNameOf(ben.userId!)), findsOneWidget);
    expect(_inSheet(app.server.displayNameOf(cleo.userId!)), findsOneWidget);
    handle.dispose();
  });

  testWidgets('blockierter Nutzer zählt nicht in „Gelesen von n“ und nicht im Namensblatt', (tester) async {
    final app = await buildTestApp();
    final ben = await _join(app, 'ben');
    final cleo = await _join(app, 'cleo');
    await app.gateway.sendMessage('Hallo');
    final id = _lastOwnId(app, ChatThread.familyId);
    app.gateway.setReadMarker(ben.userId!, id);
    app.gateway.setReadMarker(cleo.userId!, id);
    await app.services.settings.update((s) => s.copyWith(blockedUsers: <String>[ben.userId!]));
    await _open(tester, app);
    expect(find.text('Gelesen von 1'), findsOneWidget);
    expect(find.text('Gelesen von 2'), findsNothing);
    await tester.tap(find.text('Gelesen von 1'));
    await tester.pumpAndSettle();
    expect(_inSheet(app.server.displayNameOf(cleo.userId!)), findsOneWidget);
    expect(_inSheet(app.server.displayNameOf(ben.userId!)), findsNothing);
  });

  testWidgets('nur blockierte Leser: zurück auf Gesendet', (tester) async {
    final app = await buildTestApp();
    final ben = await _join(app, 'ben');
    await app.gateway.sendMessage('Hallo');
    app.gateway.setReadMarker(ben.userId!, _lastOwnId(app, ChatThread.familyId));
    await app.services.settings.update((s) => s.copyWith(blockedUsers: <String>[ben.userId!]));
    await _open(tester, app);
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('Einzelchat: Gelesen nur als Symbol mit Beschriftung, kein Text, kein Blatt', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp();
    final ben = await _join(app, 'ben');
    final dm = await app.gateway.startDirectChat(ben.userId!);
    await app.gateway.sendMessage('Hallo Ben', threadId: dm);
    app.gateway.setReadMarker(ben.userId!, _lastOwnId(app, dm), threadId: dm);
    await _open(tester, app, thread: dm);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Gelesen$')), findsOneWidget);
    expect(find.textContaining('Gelesen'), findsNothing, reason: 'im Einzelchat nur das Symbol');
    await tester.tap(find.byIcon(Icons.done_all));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    handle.dispose();
  });

  testWidgets('Großschrift 2.0 ohne Überlauf (Telefonbreite, Gelesen von 1)', (tester) async {
    final app = await buildTestApp();
    final ben = await _join(app, 'ben');
    await app.gateway.sendMessage('Hallo');
    app.gateway.setReadMarker(ben.userId!, _lastOwnId(app, ChatThread.familyId));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Chat'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
