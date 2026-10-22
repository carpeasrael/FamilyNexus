import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
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

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openChat(WidgetTester tester, TestApp app) async {
  _tallView(tester);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Fremde Nachricht melden: Dialog, Server-Meldung, Hinweis mit Blockieren-Angebot', (tester) async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await ben.sendMessage('Das ist gemein');
    await _openChat(tester, app);

    await tester.longPress(find.text('Das ist gemein'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nachricht melden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Betreiber deines Servers (fake.test)'), findsOneWidget);

    await tester.tap(find.text('Spam oder Werbung'));
    await tester.enterText(find.byType(TextField).last, 'Wiederholt');
    await tester.tap(find.widgetWithText(FilledButton, 'Melden'));
    await tester.pumpAndSettle();

    expect(app.server.reports, hasLength(1));
    final r = app.server.reports.single;
    expect(r.reporter, '@anna:fake.test');
    expect(r.reason, 'spam: Wiederholt');
    expect(find.text('Meldung gesendet.'), findsOneWidget);
    expect(find.text('Absender blockieren'), findsOneWidget);
    // Melden blendet nichts aus.
    expect(find.text('Das ist gemein'), findsOneWidget);
  });

  testWidgets('Eigene Nachrichten lassen sich weder melden noch blockieren', (tester) async {
    final app = await buildTestApp();
    await app.gateway.sendMessage('Meine Nachricht');
    await _openChat(tester, app);

    await tester.longPress(find.text('Meine Nachricht'));
    await tester.pumpAndSettle();
    expect(find.text('Antworten'), findsOneWidget);
    expect(find.text('Nachricht melden'), findsNothing);
    expect(find.textContaining('blockieren'), findsNothing);
  });

  test('Gateway: eigene und unbekannte Nachrichten werden abgelehnt', () async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await app.gateway.sendMessage('mein Text');
    await ben.sendMessage('Bens Text');
    final own = app.gateway.messages.firstWhere((m) => m.body == 'mein Text');
    await expectLater(
      app.gateway.reportMessage(ReportRequest(messageId: own.id, category: ReportCategory.spam)),
      throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
    );
    await expectLater(
      app.gateway.reportMessage(ReportRequest(messageId: r'$gibtsnicht', category: ReportCategory.spam)),
      throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notFound)),
    );
    expect(app.server.reports, isEmpty);
  });

  testWidgets('Blockieren blendet Nachrichten aus, Aufheben in den Einstellungen bringt sie zurück', (tester) async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await ben.sendMessage('Störende Nachricht');
    await _openChat(tester, app);
    expect(find.text('Störende Nachricht'), findsOneWidget);

    await tester.longPress(find.text('Störende Nachricht'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ben blockieren'));
    await tester.pumpAndSettle();
    expect(find.text('Ben blockieren?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Blockieren'));
    await tester.pumpAndSettle();

    expect(find.text('Störende Nachricht'), findsNothing);
    expect(app.services.settings.settings.blockedUsers, <String>['@ben:fake.test']);
    // Die Nachricht bleibt im Raum erhalten; nur die Anzeige ändert sich.
    expect(app.gateway.messages.any((m) => m.body == 'Störende Nachricht'), isTrue);

    await openSettings(tester);
    await tester.tap(find.text('Blockierte Mitglieder'));
    await tester.pumpAndSettle();
    expect(find.text('@ben:fake.test'), findsOneWidget);
    await tester.tap(find.text('Blockierung aufheben'));
    await tester.pumpAndSettle();
    expect(find.text('Du hast niemanden blockiert.'), findsOneWidget);
    expect(app.services.settings.settings.blockedUsers, isEmpty);
  });

  testWidgets('Familie: Blockieren aus dem Mitgliedermenü, Einzelchat ist dann ausgeblendet', (tester) async {
    final app = await buildTestApp();
    await _joinBen(app);
    _tallView(tester);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Familie')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Nachricht schreiben: Ben'), findsOneWidget);
    await tester.tap(find.byTooltip('Aktionen für Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ben blockieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Blockieren'));
    await tester.pumpAndSettle();

    expect(find.text('Blockiert'), findsOneWidget);
    expect(find.byTooltip('Nachricht schreiben: Ben'), findsNothing);

    await tester.tap(find.byTooltip('Aktionen für Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockierung aufheben'));
    await tester.pumpAndSettle();
    expect(find.text('Blockiert'), findsNothing);
    expect(find.byTooltip('Nachricht schreiben: Ben'), findsOneWidget);
  });
}
