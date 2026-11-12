import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

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
  final gate = Completer<void>();
  addTearDown(() {
    if (!gate.isCompleted) gate.complete();
  });
  return (app: app, ben: ben, dm: dm, gate: gate);
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
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'für Ben');
    await _release(tester, t.gate);
    expect(_field(tester), 'für Ben');
  });

  testWidgets('F2b Gespräch gewechselt, nichts getippt: der gesendete Text bleibt nicht im neuen Gespräch', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
    await tester.pump();
    await _release(tester, t.gate);
    expect(_field(tester), isEmpty);
  });

  testWidgets('F2c Gespräch gewechselt und dort eine Antwort gewählt: die Antwortvorschau bleibt', (tester) async {
    final t = await _open(tester);
    await _sendHeld(tester, t.gate, t.app.server, 'hallo');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Hallo Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();
    await _sendHeld(tester, t.gate, t.app.server, 'Antwort');
    await _release(tester, t.gate);
    expect(_field(tester), isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
