import 'dart:async';
import 'dart:convert';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// #410: Das Eingabefeld gehört allen Gesprächen und bleibt beim Senden beschreibbar. Nach dem Senden darf nur der
/// unveränderte, schon gesendete Stand geleert werden, nicht, was der Nutzer inzwischen getippt oder gewählt hat.
Future<({TestApp app, FakeMatrixGateway ben, String dm, Completer<void> gate})> _open(WidgetTester tester) async {
  final app = await buildTestApp();
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@ben:${app.server.host}'] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  final dm = await app.gateway.startDirectChat(ben.userId!);
  await ben.sendMessage('Hallo Anna', threadId: dm);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Chat'));
  await tester.pumpAndSettle();
  // Die Gesprächsliste ist die Startseite (#423): der Familienchat wird wie bisher geöffnet.
  await tester.tap(find.byKey(const ValueKey<String>('thread-family')));
  await tester.pumpAndSettle();
  final gate = Completer<void>();
  addTearDown(() {
    if (!gate.isCompleted) gate.complete();
  });
  return (app: app, ben: ben, dm: dm, gate: gate);
}

/// Wechselt über den Zurück-Pfeil und die Zeile ins Gespräch [id] (früher ein Tipp auf den Chip, #423).
Future<void> _switchTo(WidgetTester tester, String id, {bool settle = false}) async {
  await tester.tap(find.byTooltip('Zurück zu den Gesprächen'));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey<String>('thread-$id')));
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

String _field(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// Tippt [text] ab und sendet; die Nachricht hängt am geschlossenen Gate.
Future<void> _sendHeld(WidgetTester tester, Completer<void> gate, FakeMatrixServer server, String text) async {
  server.sendGate = gate;
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump();
}

Future<void> _release(WidgetTester tester, Completer<void> gate) async {
  gate.complete();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('F1 weitergetippt während des Sendens: der neue Text bleibt', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await tester.enterText(find.byType(TextField), 'hallo welt');
    await _release(tester, t.gate);
    expect(_field(tester), 'hallo welt');
  });

  testWidgets('F2 Gespräch gewechselt und dort getippt: der Text bleibt', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await _switchTo(tester, t.dm);
    await tester.enterText(find.byType(TextField), 'für Ben');
    await _release(tester, t.gate);
    expect(_field(tester), 'für Ben');
  });

  testWidgets('F2b Gespräch gewechselt, nichts getippt: der gesendete Text bleibt nicht im neuen Gespräch', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await _switchTo(tester, t.dm);
    await _release(tester, t.gate);
    expect(_field(tester), isEmpty);
  });

  testWidgets('F2c Gespräch gewechselt und dort eine Antwort gewählt: die Antwortvorschau bleibt', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await _switchTo(tester, t.dm, settle: true);
    await tester.longPress(find.text('Hallo Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'Vorschau steht');
    await _release(tester, t.gate);
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'bisher mit der alten Antwort gelöscht');
  });

  testWidgets('F3 unverändert: Feld leer, Antwortvorschau weg', (tester) async {
    final t = await _open(tester);
    await _switchTo(tester, t.dm, settle: true);
    await tester.longPress(find.text('Hallo Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();
    await _sendHeld(tester, t.gate, t.app.server, 'Antwort');
    await _release(tester, t.gate);
    expect(_field(tester), isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // --- #119, K1, B4: Entwurf und Antwortbezug gehören dem Gespräch, in dem sie entstanden sind ---

  testWidgets('D1 gesendeter Entwurf wird nicht wieder sichtbar: Senden im Familienchat, Wechsel, zurück', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await _switchTo(tester, t.dm);
    await _release(tester, t.gate);
    await _switchTo(tester, ChatThread.familyId, settle: true);
    expect(_field(tester), isEmpty, reason: 'gesendet, nicht als Entwurf zurückgekehrt');
  });

  testWidgets('D2 Entwürfe je Gespräch: Senden im Einzelchat sendet nie den Familienentwurf', (tester) async {
    final t = await _open(tester);
    await tester.enterText(find.byType(TextField), 'Familien-Entwurf');
    await _switchTo(tester, t.dm, settle: true);
    expect(_field(tester), isEmpty);
    await tester.enterText(find.byType(TextField), 'Hi Ben');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(t.app.gateway.messagesIn(t.dm).map((m) => m.body), contains('Hi Ben'));
    expect(t.app.gateway.messages.map((m) => m.body), isNot(contains('Familien-Entwurf')));
    await _switchTo(tester, ChatThread.familyId, settle: true);
    expect(_field(tester), 'Familien-Entwurf');
  });

  testWidgets('D3 Antwortbezug je Gespräch: im Einzelchat gewählt, in der Familie nicht da, zurück wieder da', (tester) async {
    final t = await _open(tester);
    await _switchTo(tester, t.dm, settle: true);
    await tester.longPress(find.text('Hallo Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
    await _switchTo(tester, ChatThread.familyId, settle: true);
    expect(find.byIcon(Icons.close), findsNothing, reason: 'der Bezug gehört dem Einzelchat');
    await _switchTo(tester, t.dm, settle: true);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('D4 verschwindet das Gespräch (blockiert), fällt die Anzeige auf die Familie zurück: der Entwurf geht nicht mit', (tester) async {
    final t = await _open(tester);
    await tester.enterText(find.byType(TextField), 'Familie');
    await _switchTo(tester, t.dm, settle: true);
    await tester.enterText(find.byType(TextField), 'Ben-Entwurf');
    await t.app.services.settings.update((s) => s.copyWith(blockedUsers: <String>[t.ben.userId!]));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.send), findsOneWidget, reason: 'ein Gespräch ist offen (Familie)');
    expect(_field(tester), isNot('Ben-Entwurf'), reason: 'der Entwurf des Einzelchats gelangt nie in die Familie');
  });

  testWidgets('D5 Anhang nach einem Wechsel: die Antwort gehört dem Gespräch der Auswahl, der Bezug des neuen bleibt', (tester) async {
    final t = await _open(tester);
    final files = t.app.services.files as FakeFileAccess;
    files.next = PickedFile(name: 'foto.png', bytes: base64Decode(_png));
    final pick = Completer<void>();
    files.pickGate = pick;
    addTearDown(() {
      if (!pick.isCompleted) pick.complete();
    });
    await _switchTo(tester, t.dm, settle: true);
    await tester.longPress(find.text('Hallo Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Datei anhängen'));
    await tester.pump();
    await _switchTo(tester, ChatThread.familyId, settle: true);
    pick.complete();
    await tester.pumpAndSettle();
    expect(t.app.gateway.messagesIn(t.dm).where((m) => m.attachment?.name == 'foto.png'), hasLength(1));
    expect(t.app.gateway.messages.where((m) => m.attachment != null), isEmpty);
    await _switchTo(tester, t.dm, settle: true);
    expect(find.byIcon(Icons.close), findsNothing, reason: 'der gesendete Antwortbezug des Einzelchats ist verbraucht');
  });
}
