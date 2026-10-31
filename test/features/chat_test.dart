import 'dart:convert';
import 'dart:typed_data';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// Kleinstes gültiges PNG (1 × 1 Pixel).
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// Lässt Ben dem Familienraum beitreten und liefert sein Gerät.
Future<FakeMatrixGateway> _joinBen(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@ben:${app.server.host}'] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  return ben;
}

Future<void> _openChat(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
  await tester.pumpAndSettle();
}

Future<void> _openChatEn(WidgetTester tester, TestApp app, {required bool use24h}) async {
  // Plattformwerte kommen aus der übergeordneten MediaQuery (siehe clock_format_test.dart).
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData.fromView(tester.view).copyWith(alwaysUse24HourFormat: use24h),
    child: FamilyNexusApp(services: app.services),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Nachricht senden erscheint im Verlauf, Eingabe wird geleert', (tester) async {
    final app = await buildTestApp();
    await _openChat(tester, app);
    expect(find.text('Noch keine Nachrichten.'), findsOneWidget);
    expect(find.text('Ende-zu-Ende-verschlüsselt'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hallo Familie');
    await tester.tap(find.byTooltip('Senden'));
    await tester.pumpAndSettle();

    expect(find.text('Hallo Familie'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(app.gateway.messages.single.body, 'Hallo Familie');
  });

  testWidgets('#162: Uhrzeit der Nachricht folgt der 12-h-Einstellung des Geräts (englisch)', (tester) async {
    final app = await buildTestApp(lang: 'en');
    final ben = await _joinBen(app);
    await ben.sendMessage('Ich bin da');
    await _openChatEn(tester, app, use24h: false);
    final t = app.gateway.messages.single.time.toLocal();
    expect(find.text(DateFormat.jm('en').format(t)), findsOneWidget);
    expect(find.text('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'), findsNothing);
  });

  testWidgets('Nachricht von Ben wird mit Absendernamen angezeigt', (tester) async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await ben.sendMessage('Ich bin da');
    await _openChat(tester, app);
    expect(find.text('Ich bin da'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
  });

  testWidgets('Antworten zeigt Zitat; Abbrechen entfernt die Vorschau', (tester) async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await ben.sendMessage('Wer holt die Kinder ab?');
    await _openChat(tester, app);

    await tester.longPress(find.text('Wer holt die Kinder ab?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antworten'));
    await tester.pumpAndSettle();
    expect(find.text('Antwort an Ben'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ich');
    await tester.tap(find.byTooltip('Senden'));
    await tester.pumpAndSettle();

    final reply = app.gateway.messages.last;
    expect(reply.replyToId, app.gateway.messages.first.id);
    expect(find.text('Antwort an Ben'), findsNothing);
  });

  testWidgets('Reaktion wird gesendet und gezählt', (tester) async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await ben.sendMessage('Pizza heute?');
    await _openChat(tester, app);

    await tester.longPress(find.text('Pizza heute?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();

    expect(app.gateway.messages.first.reactions['👍'], <String>{'@anna:fake.test'});
    expect(find.text('👍 1'), findsOneWidget);
  });

  test('Anhänge: erlaubt/abgelehnt über die Richtlinie', () async {
    final app = await buildTestApp();
    final png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0, 0]);
    await app.gateway.sendAttachment(fileName: '../foto.png', bytes: png);
    expect(app.gateway.messages.single.attachment!.name, 'foto.png');

    for (final bad in <(String, Uint8List)>[
      ('virus.exe', png),
      ('getarnt.png', Uint8List.fromList(<int>[0x4D, 0x5A, 0, 0])),
      ('leer.png', Uint8List(0)),
    ]) {
      await expectLater(
        app.gateway.sendAttachment(fileName: bad.$1, bytes: bad.$2),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.attachmentRejected)),
        reason: bad.$1,
      );
    }
    expect(app.gateway.messages.length, 1);
  });

  test('leere/überlange Eingaben werden abgelehnt', () async {
    final app = await buildTestApp();
    await expectLater(app.gateway.sendMessage('   '), throwsA(isA<GatewayException>()));
    await expectLater(app.gateway.sendReaction('x', ''), throwsA(isA<GatewayException>()));
    await expectLater(app.gateway.createFamily('x' * 61), throwsA(isA<GatewayException>()));
  });

  test('eine bestehende Familie wird nie überschrieben', () async {
    final app = await buildTestApp();
    await expectLater(
      app.gateway.createFamily('Zweite Familie'),
      throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.alreadyExists)),
    );
    expect(app.gateway.family!.name, 'Familie Test');
  });

  test('der Fake kennt keinen unverschlüsselten Raum', () async {
    final app = await buildTestApp();
    expect(app.gateway.familyRoom!.encrypted, isTrue);
  });

  testWidgets('#40: Bild-Anhänge lassen sich speichern – vor und nach dem Laden, mit Warnung', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    final png = base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    await ben.sendAttachment(fileName: 'testbild.png', bytes: Uint8List.fromList(png));
    await _openChat(tester, app);
    expect(find.text('testbild.png'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Anhang laden'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unverschlüsselt im gewählten Ordner'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final files = app.services.files as FakeFileAccess;
    expect(files.saved, <String>['testbild.png']);
    expect(files.contents['testbild.png'], png);

    // Zum Speichern geladen: das Bild wird gezeigt, Speichern bleibt möglich.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);
  });

  group('#130: Anhänge bleiben an ihrer Nachricht', () {
    Uint8List pngWith(int marker) => Uint8List.fromList(<int>[...base64.decode(_png), marker]);

    Finder image(String name) => find.byWidgetPredicate((w) => w is Image && w.semanticLabel == name);

    Finder inBubbleOf(String name, Finder what) => find.descendant(
          of: find
              .ancestor(of: find.text(name).first, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Bubble'))
              .first,
          matching: what,
        );

    Future<void> tallView(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('eine neue Nachricht übernimmt das geladene Bild nicht, Speichern schreibt die eigenen Bytes', (tester) async {
      await tallView(tester);
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final oldBytes = pngWith(1);
      final newBytes = pngWith(2);
      await ben.sendAttachment(fileName: 'alt.png', bytes: oldBytes);
      await _openChat(tester, app);
      await tester.tap(find.widgetWithText(TextButton, 'Anhang laden'));
      await tester.pumpAndSettle();
      expect(image('alt.png'), findsOneWidget);

      await ben.sendAttachment(fileName: 'neu.png', bytes: newBytes);
      await tester.pumpAndSettle();

      expect(image('neu.png'), findsNothing, reason: 'nie automatisch geladen, schon gar nicht mit fremden Bytes');
      expect(image('alt.png'), findsOneWidget, reason: 'das geladene Bild bleibt an seiner Nachricht');
      expect(find.widgetWithText(TextButton, 'Anhang laden'), findsOneWidget);

      await tester.tap(inBubbleOf('neu.png', find.widgetWithText(TextButton, 'Speichern')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      final files = app.services.files as FakeFileAccess;
      expect(files.saved, <String>['neu.png']);
      expect(files.contents['neu.png'], newBytes);
    });

    testWidgets('beim Gesprächswechsel erscheint kein Bild aus dem anderen Gespräch', (tester) async {
      await tallView(tester);
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final direct = await app.gateway.startDirectChat(ben.userId!);
      await app.gateway.sendAttachment(fileName: 'nur-ben.png', bytes: pngWith(2), threadId: direct);
      await ben.sendAttachment(fileName: 'familie.png', bytes: pngWith(1));
      await _openChat(tester, app);
      await tester.tap(find.widgetWithText(TextButton, 'Anhang laden'));
      await tester.pumpAndSettle();
      expect(image('familie.png'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.widgetWithText(TextButton, 'Anhang laden'), findsOneWidget);
    });

    testWidgets('eine doppelt gelieferte Nachricht erscheint einmal und stört die Liste nicht', (tester) async {
      await tallView(tester);
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await ben.sendMessage('einmal');
      await _openChat(tester, app);
      final room = app.gateway.familyRoom!;
      room.events.add(room.events.last);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('einmal'), findsOneWidget);

      await ben.sendMessage('danach');
      await tester.pumpAndSettle();
      expect(find.text('einmal'), findsOneWidget);
      expect(find.text('danach'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
