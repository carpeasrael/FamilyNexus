import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// AP-4a: Die Zerlegung von `ChatScreen.build` ändert weder die Schlüssel (Anzahl, Reihenfolge) noch das, was ein
/// Screenreader liest. Der Schnappschuss wurde vor dem Umbau am unveränderten Code aufgenommen.
Future<FakeMatrixGateway> _joinBen(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@ben:${app.server.host}'] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  return ben;
}

/// Schlüssel unterhalb von [ChatScreen] in Baumreihenfolge, Nachrichten-IDs als `m<n>`.
List<String> _keys(WidgetTester tester, Map<String, String> ids) {
  final out = <String>[];
  void visit(Element e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      out.add('V:${ids[k.value] ?? k.value}');
    } else if (k is GlobalKey && k.toString().contains('unread-marker')) {
      out.add('G:unread-marker');
    }
    e.visitChildren(visit);
  }

  visit(tester.element(find.byType(ChatScreen)));
  return out;
}

List<String> _semantics(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    final parts = <String>[
      if (d.label.isNotEmpty) 'L=${d.label}',
      if (d.tooltip.isNotEmpty) 'T=${d.tooltip}',
      if (d.hint.isNotEmpty) 'H=${d.hint}',
      if (d.hasAction(SemanticsAction.tap)) 'tap',
      if (d.hasAction(SemanticsAction.longPress)) 'long',
    ];
    if (parts.isNotEmpty) out.add(parts.join(' ').replaceAll('\n', ' | '));
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(ChatScreen)));
  return out;
}

void main() {
  testWidgets('Chat: Schlüssel und Semantik unverändert (Familienchat, Einzelchat-Leiste, Antwortvorschau)', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await ben.sendMessage('Wer holt die Kinder ab?');
    await app.gateway.sendMessage('Ich');
    await app.gateway.startDirectChat(ben.userId!);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Chat'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Wer holt die Kinder ab?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();

    final ids = <String, String>{
      for (var i = 0; i < app.gateway.messages.length; i++) app.gateway.messages[i].id: 'm$i',
    };
    final keys = _keys(tester, ids);
    final sem = _semantics(tester);
    expect(keys, _expectedKeys);
    expect(sem, _expectedSemantics);
    handle.dispose();
  });
}

const List<String> _expectedKeys = <String>[
  'V:m1',
  'V:m0',
  'V:~fn-unread',
  'G:unread-marker',
  'V:~fn-day-2026-10-21',
];

const List<String> _expectedSemantics = <String>[
  'L=Heute | Tab 1 von 5 tap',
  'L=Kalender | Tab 2 von 5 tap',
  'L=Chat | Tab 3 von 5 tap',
  'L=Einkauf | Tab 4 von 5 tap',
  'L=Familie | Tab 5 von 5 tap',
  'L=Gespräche',
  'L=Familienchat Familie Test',
  'L=Einzelchat mit Ben, Status unbekannt',
  'L=Ende-zu-Ende-verschlüsselt',
  'L=Nachricht von dir | Ich | Mittwoch, 21. Oktober 2026, 14:00 long',
  'L=Nachricht von Ben | Ben | Wer holt die Kinder ab? | Mittwoch, 21. Oktober 2026, 14:00 long',
  'L=Neue Nachrichten',
  'L=Mittwoch, 21. Oktober 2026',
  'L=Antwort an Ben',
  'L=Wer holt die Kinder ab?',
  'T=Antwort abbrechen tap',
  'T=Datei anhängen tap',
  'L=Nachricht schreiben tap',
  'T=Senden tap',
  'L=Chat',
  'T=Menü öffnen tap',
];
