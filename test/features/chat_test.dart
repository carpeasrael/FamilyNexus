import 'dart:convert';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/shell_finders.dart';
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
  await tester.tap(navTab('Chat'));
  await tester.pumpAndSettle();
}

/// Öffnet in der Gesprächsliste (Startseite bei mehreren Gesprächen, #423) die Zeile [id].
Future<void> _openThread(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey<String>('thread-$id')));
  await tester.pumpAndSettle();
}

/// Zurück zur Gesprächsliste über den Pfeil der Kopfzeile.
Future<void> _backToList(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Zurück zu den Gesprächen'));
  await tester.pumpAndSettle();
}

Future<void> _openChatEn(WidgetTester tester, TestApp app, {required bool use24h}) async {
  // Plattformwerte kommen aus der übergeordneten MediaQuery (siehe clock_format_test.dart).
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData.fromView(tester.view).copyWith(alwaysUse24HourFormat: use24h),
    child: FamilyNexusApp(services: app.services),
  ));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Chat'));
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

  testWidgets('#236: Eingabe begrenzt nach UTF-16-Einheiten wie die Prüfung, kein halbes Emoji', (tester) async {
    final app = await buildTestApp();
    await _openChat(tester, app);
    final composer = find.widgetWithText(TextField, 'Nachricht schreiben');
    // 7000 sichtbare Zeichen, aber 9000 UTF-16-Einheiten: früher nahm das Feld alles, das Gateway lehnte ab.
    await tester.enterText(composer, '${'a' * 5000}${'😀' * 2000}');
    await tester.pump();
    final text = tester.widget<TextField>(composer).controller!.text;
    expect(text.length, ChatMessage.maxBody);
    expect(text, '${'a' * 5000}${'😀' * 1500}');
  });

  group('#138: gescheiterte Nachricht', () {
    testWidgets('wiederholbar: Knopf löst retryMessage aus', (tester) async {
      final app = await buildTestApp();
      await app.gateway.sendMessage('Hallo');
      final id = app.gateway.messages.single.id;
      app.gateway.sendStates[id] = (status: MessageStatus.failed, retryable: true);
      await _openChat(tester, app);

      expect(find.text('Nicht gesendet. Bitte erneut schreiben.'), findsNothing);
      await tester.tap(find.text('Senden fehlgeschlagen – tippen zum Wiederholen'));
      await tester.pumpAndSettle();
      expect(app.gateway.retried, <String>[id]);
    });

    testWidgets('im Einzelchat wiederholt der Knopf in diesem Thread', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await app.gateway.sendMessage('Nur für Ben', threadId: dm);
      final id = app.gateway.messagesIn(dm).single.id;
      app.gateway.sendStates[id] = (status: MessageStatus.failed, retryable: true);
      await _openChat(tester, app);
      await _openThread(tester, dm);

      await tester.tap(find.text('Senden fehlgeschlagen – tippen zum Wiederholen'));
      await tester.pumpAndSettle();
      expect(app.gateway.retried, <String>[id]);
      expect(app.gateway.retriedThreads, <String>[dm]);
    });

    testWidgets('nicht wiederholbar: Hinweis statt Knopf, Tippen löst nichts aus', (tester) async {
      final app = await buildTestApp();
      await app.gateway.sendMessage('Hallo');
      app.gateway.sendStates[app.gateway.messages.single.id] = (status: MessageStatus.failed, retryable: false);
      await _openChat(tester, app);

      expect(find.text('Senden fehlgeschlagen – tippen zum Wiederholen'), findsNothing);
      await tester.tap(find.text('Nicht gesendet. Bitte erneut schreiben.'));
      await tester.pumpAndSettle();
      expect(app.gateway.retried, isEmpty);
    });

    testWidgets('englisch', (tester) async {
      final app = await buildTestApp(lang: 'en');
      await app.gateway.sendMessage('Hello');
      app.gateway.sendStates[app.gateway.messages.single.id] = (status: MessageStatus.failed, retryable: false);
      await _openChatEn(tester, app, use24h: true);
      expect(find.text('Not sent. Please write it again.'), findsOneWidget);
    });

    testWidgets('„wird gesendet“ zeigt die Uhr, keinen Hinweis', (tester) async {
      final app = await buildTestApp();
      await app.gateway.sendMessage('Hallo');
      app.gateway.sendStates[app.gateway.messages.single.id] = (status: MessageStatus.sending, retryable: false);
      await _openChat(tester, app);

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.text('Nicht gesendet. Bitte erneut schreiben.'), findsNothing);
      expect(find.text('Senden fehlgeschlagen – tippen zum Wiederholen'), findsNothing);
    });
  });

  group('#224: Reaktionen nur auf gesendete Nachrichten', () {
    for (final state in <({MessageStatus status, bool retryable, String label})>[
      (status: MessageStatus.failed, retryable: false, label: 'nicht gesendet'),
      (status: MessageStatus.failed, retryable: true, label: 'gescheitert, wiederholbar'),
      (status: MessageStatus.sending, retryable: false, label: 'wird gesendet'),
    ]) {
      testWidgets('${state.label}: Menü ohne Reaktionsleiste, „Antworten“ bleibt', (tester) async {
        final app = await buildTestApp();
        await app.gateway.sendMessage('Hallo');
        app.gateway.sendStates[app.gateway.messages.single.id] = (status: state.status, retryable: state.retryable);
        await _openChat(tester, app);

        await tester.longPress(find.text('Hallo'));
        await tester.pumpAndSettle();
        expect(find.text('Antworten'), findsOneWidget, reason: 'Menü ist offen');
        expect(find.bySemanticsLabel(RegExp('^Reagieren ')), findsNothing);
        expect(find.text('👍'), findsNothing);
      });
    }

    testWidgets('gesendet: Reaktionsleiste ist da', (tester) async {
      final app = await buildTestApp();
      await app.gateway.sendMessage('Hallo');
      await _openChat(tester, app);

      await tester.longPress(find.text('Hallo'));
      await tester.pumpAndSettle();
      expect(find.text('Antworten'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Reagieren ')), findsWidgets);
      expect(find.text('👍'), findsOneWidget);
    });
  });

  testWidgets('#138: Nicht Entschlüsseltes bietet „Antworten“ nicht an', (tester) async {
    final app = await buildTestApp();
    await app.gateway.sendMessage('Lesbar');
    await app.gateway.sendMessage('Verborgen');
    app.gateway.undecryptable.add(app.gateway.messages.last.id);
    await _openChat(tester, app);

    await tester.longPress(find.text('Nachricht kann nicht entschlüsselt werden'));
    await tester.pumpAndSettle();
    expect(find.text('Antworten'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Lesbar'));
    await tester.pumpAndSettle();
    expect(find.text('Antworten'), findsOneWidget);
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

  testWidgets('#332: Screenreader-Label eigener Nachricht „Nachricht von dir“, nie „von Du“; Bens bleibt „von Ben“', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await app.gateway.sendMessage('Hallo eigene');
    await ben.sendMessage('Hallo von Ben');
    await _openChat(tester, app);
    // Das Label steht im Semantics-Baum zusammengeführt mit Text und Uhrzeit, daher Anfang statt exakter Text.
    expect(find.bySemanticsLabel(RegExp('^Nachricht von dir')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Nachricht von Du')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Nachricht von Ben')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('#332: Screenreader-Label eigener Nachricht auf Englisch „Message from you“', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await buildTestApp(lang: 'en');
    await app.gateway.sendMessage('Hello own');
    await _openChatEn(tester, app, use24h: true);
    expect(find.bySemanticsLabel(RegExp('^Message from you')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Message from You')), findsNothing);
    semantics.dispose();
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
      await _openThread(tester, ChatThread.familyId);
      await tester.tap(find.widgetWithText(TextButton, 'Anhang laden'));
      await tester.pumpAndSettle();
      expect(image('familie.png'), findsOneWidget);

      await _backToList(tester);
      await _openThread(tester, direct);

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

  group('#254: Datum, Ungelesen-Marke, Zitat', () {
    Finder inHistory(Finder f) => find.descendant(of: find.byType(ListView).last, matching: f);
    Finder composer() => find.widgetWithText(TextField, 'Nachricht schreiben');

    testWidgets('#295: nicht zeitgeordnete Zeitleiste (Tag N, N+1, N): Datumszeilen ohne Schlüsselkonflikt', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      app.server.nextTime = DateTime(2026, 10, 21, 23, 59, 58).toUtc();
      await ben.sendMessage('eins');
      app.server.nextTime = DateTime(2026, 10, 22, 0, 0, 1).toUtc();
      await ben.sendMessage('zwei');
      app.server.nextTime = DateTime(2026, 10, 21, 23, 59, 59).toUtc();
      await ben.sendMessage('drei');
      await _openChat(tester, app);

      // Neue Nachrichten verschieben alle Indizes: findChildIndexCallback sucht die Datumszeilen über ihren Schlüssel.
      app.server.nextTime = DateTime(2026, 10, 22, 0, 0, 5).toUtc();
      await ben.sendMessage('vier');
      await tester.pumpAndSettle();
      app.server.nextTime = DateTime(2026, 10, 21, 23, 59, 59).toUtc();
      await ben.sendMessage('fuenf');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(inHistory(find.text('Mittwoch, 21. Oktober 2026')), findsWidgets);
      expect(inHistory(find.text('Donnerstag, 22. Oktober 2026')), findsWidgets);
      expect(inHistory(find.text('fuenf')), findsOneWidget);
    });

    testWidgets('Datumszeile „Heute“ bzw. ausgeschrieben, volles Datum für den Screenreader', (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      // Ortszeit Mittag: Der Tag hängt nicht von der Zeitzone des Rechners ab.
      app.server.nextTime = DateTime(2026, 10, 21, 12).toUtc();
      await ben.sendMessage('alt');
      app.server.nextTime = DateTime.now().toUtc();
      await ben.sendMessage('neu');
      await _openChat(tester, app);

      expect(inHistory(find.text('Mittwoch, 21. Oktober 2026')), findsOneWidget);
      expect(inHistory(find.text('Heute')), findsOneWidget);
      double y(String text) => tester.getCenter(inHistory(find.text(text))).dy;
      expect(y('Mittwoch, 21. Oktober 2026') < y('alt'), isTrue);
      expect(y('alt') < y('Heute') && y('Heute') < y('neu'), isTrue);
      expect(find.bySemanticsLabel(RegExp(r'Mittwoch, 21\. Oktober 2026, \d\d:\d\d')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('englisch: „Today“ und Datum nach Sprache', (tester) async {
      final app = await buildTestApp(lang: 'en');
      final ben = await _joinBen(app);
      app.server.nextTime = DateTime(2026, 10, 21, 12).toUtc();
      await ben.sendMessage('old');
      app.server.nextTime = DateTime.now().toUtc().subtract(const Duration(days: 1));
      await ben.sendMessage('yesterday');
      await _openChatEn(tester, app, use24h: true);
      expect(inHistory(find.text('Wednesday, October 21, 2026')), findsOneWidget);
      // Je nach Uhrzeit fällt „gestern minus 24 h“ auf gestern; nie auf heute.
      expect(inHistory(find.text('Yesterday')), findsOneWidget);
    });

    testWidgets('Marke steht über der ersten ungelesenen Nachricht und bleibt nach dem Gelesen-Markieren', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await ben.sendMessage('gelesen');
      await app.gateway.markChatRead();
      await ben.sendMessage('neu eins');
      await ben.sendMessage('neu zwei');
      await _openChat(tester, app);

      expect(app.gateway.unreadIn(ChatThread.familyId), 0, reason: 'Öffnen markiert gelesen');
      expect(find.text('Neue Nachrichten'), findsOneWidget);
      double y(String text) => tester.getCenter(find.text(text)).dy;
      expect(y('gelesen') < y('Neue Nachrichten') && y('Neue Nachrichten') < y('neu eins'), isTrue);

      // Neue Nachricht bei offenem Gespräch: keine zweite Marke, die alte bleibt.
      await ben.sendMessage('neu drei');
      await tester.pumpAndSettle();
      expect(find.text('Neue Nachrichten'), findsOneWidget);
      expect(y('Neue Nachrichten') < y('neu eins'), isTrue);

      // Tab verlassen und zurück: alles gelesen, keine Marke mehr.
      await tester.tap(navTab('Einkauf'));
      await tester.pumpAndSettle();
      await tester.tap(navTab('Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Neue Nachrichten'), findsNothing);
    });

    testWidgets('Gesprächswechsel gibt die Marke frei', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      final dm = await app.gateway.startDirectChat(ben.userId!);
      await ben.sendMessage('gelesen');
      await app.gateway.markChatRead();
      await ben.sendMessage('neu');
      await _openChat(tester, app);
      await _openThread(tester, ChatThread.familyId);
      expect(find.text('Neue Nachrichten'), findsOneWidget);

      await _backToList(tester);
      await _openThread(tester, dm);
      expect(find.text('Neue Nachrichten'), findsNothing, reason: 'Einzelchat ohne Ungelesenes');
      expect(app.gateway.unreadIn(dm), 0);

      await _backToList(tester);
      await _openThread(tester, ChatThread.familyId);
      expect(find.text('neu'), findsOneWidget);
      expect(find.text('Neue Nachrichten'), findsNothing, reason: 'beim ersten Öffnen gelesen, keine neue Marke');
    });

    testWidgets('ohne Ungelesenes keine Marke, auch nicht für Nachrichten bei offenem Gespräch', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await ben.sendMessage('eins');
      await app.gateway.markChatRead();
      await _openChat(tester, app);
      expect(find.text('Neue Nachrichten'), findsNothing);
      await ben.sendMessage('zwei');
      await tester.pumpAndSettle();
      expect(find.text('zwei'), findsOneWidget);
      expect(find.text('Neue Nachrichten'), findsNothing);
    });

    testWidgets('Rückkehr aus dem Hintergrund setzt eine neue Marke', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await ben.sendMessage('eins');
      await app.gateway.markChatRead();
      await _openChat(tester, app);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await ben.sendMessage('im Hintergrund');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Neue Nachrichten'), findsOneWidget);
      expect(tester.getCenter(find.text('Neue Nachrichten')).dy < tester.getCenter(find.text('im Hintergrund')).dy, isTrue);
    });

    group('Zitat', () {
      const long = 'Zeile 1\nZeile 2\nZeile 3\nZeile 4\nZeile 5\nZeile 6';
      // Das Zitat ist das private Widget `_Quote` in der Antwort; die Originalnachricht steht außerhalb.
      Text quote(WidgetTester tester) => tester.widget<Text>(find.descendant(
          of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Quote'), matching: find.text(long)));

      Future<FakeMatrixGateway> setUpReply(WidgetTester tester, TestApp app, String quoted) async {
        final ben = await _joinBen(app);
        await ben.sendMessage(quoted);
        await app.gateway.sendMessage('ok', replyToId: app.gateway.messages.first.id);
        await app.gateway.markChatRead();
        await _openChat(tester, app);
        return ben;
      }

      testWidgets('ab 4 Zeilen eingeklappt; Tippen klappt auf und zu; Tippen ins Eingabefeld klappt zu', (tester) async {
        final app = await buildTestApp();
        await setUpReply(tester, app, long);
        expect(quote(tester).maxLines, 4);
        expect(find.text('Mehr anzeigen'), findsOneWidget);
        expect(find.text('Du'), findsNothing);

        await tester.tap(find.text('Mehr anzeigen'));
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, isNull);
        expect(find.text('Weniger anzeigen'), findsOneWidget);

        await tester.tap(find.text('Weniger anzeigen'));
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, 4);

        await tester.tap(find.text('Mehr anzeigen'));
        await tester.pumpAndSettle();
        await tester.tap(composer());
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, 4, reason: 'Tippen außerhalb klappt zu');
      });

      testWidgets('Tippen aufs Zitat lässt dem Eingabefeld den Fokus (Finger und Maus)', (tester) async {
        final app = await buildTestApp();
        await setUpReply(tester, app, long);
        bool composerFocused() => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
        for (final kind in <PointerDeviceKind>[PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
          await tester.tap(composer());
          await tester.pumpAndSettle();
          expect(composerFocused(), isTrue, reason: 'vorher $kind');
          await tester.tap(find.text(quote(tester).maxLines == null ? 'Weniger anzeigen' : 'Mehr anzeigen'), kind: kind);
          await tester.pumpAndSettle();
          expect(composerFocused(), isTrue, reason: '$kind');
        }
      });

      testWidgets('Tastatur: Enter und Leertaste schalten um, Fokuswechsel klappt zu', (tester) async {
        final app = await buildTestApp();
        await setUpReply(tester, app, long);
        final node = tester
            .widget<Focus>(find.byWidgetPredicate((w) => w is Focus && w.focusNode?.debugLabel == 'quote'))
            .focusNode!;
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, isNull);
        node.nextFocus();
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, 4);

        // Leertaste schaltet ebenso um.
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, 4);
      });

      testWidgets('Tab verlassen klappt zu', (tester) async {
        final app = await buildTestApp();
        await setUpReply(tester, app, long);
        await tester.tap(find.text('Mehr anzeigen'));
        await tester.pumpAndSettle();
        await tester.tap(navTab('Einkauf'));
        await tester.pumpAndSettle();
        await tester.tap(navTab('Chat'));
        await tester.pumpAndSettle();
        expect(quote(tester).maxLines, 4);
      });

      testWidgets('kurzes Zitat: ganz sichtbar, ohne Knopf; Absender wird genannt', (tester) async {
        final app = await buildTestApp();
        await setUpReply(tester, app, 'Zeile 1\nZeile 2\nZeile 3');
        expect(find.text('Zeile 1\nZeile 2\nZeile 3'), findsNWidgets(2));
        expect(find.text('Mehr anzeigen'), findsNothing);
        expect(find.byWidgetPredicate((w) => w is Focus && w.focusNode?.debugLabel == 'quote'), findsNothing);
        expect(find.text('Ben'), findsNWidgets(2), reason: 'Absender der Nachricht und des Zitats');
      });

      testWidgets('Ziel von einem blockierten Mitglied: neutraler Hinweis, kein Zitattext', (tester) async {
        final app = await buildTestApp();
        final ben = await _joinBen(app);
        await ben.sendMessage('Geheimes Original');
        await app.gateway.sendMessage('ok', replyToId: app.gateway.messages.first.id);
        await app.services.settings.update((s) => s.copyWith(blockedUsers: <String>[ben.userId!]));
        await _openChat(tester, app);
        expect(find.text('ok'), findsOneWidget);
        expect(find.text('Geheimes Original'), findsNothing);
        expect(find.text('Antwort auf eine Nachricht, die hier nicht angezeigt wird'), findsOneWidget);
      });

      testWidgets('große Schrift (2.0): Messung folgt der Textgröße', (tester) async {
        // Drei Zeilen à 38 Zeichen (Testschrift: Zeichen so breit wie die Schriftgröße): bei 1.0 drei Zeilen ohne Knopf,
        // bei 2.0 umbrochen auf mehr als vier.
        final text = List<String>.generate(3, (i) => 'Zeile ${i + 1} ${'abcdefghij' * 3}').join('\n');
        for (final scale in <double>[1.0, 2.0]) {
          final app = await buildTestApp();
          final ben = await _joinBen(app);
          await ben.sendMessage(text);
          await app.gateway.sendMessage('ok', replyToId: app.gateway.messages.first.id);
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(scale)),
            child: FamilyNexusApp(services: app.services),
          ));
          await tester.pumpAndSettle();
          await tester.tap(navTab('Chat'));
          await tester.pumpAndSettle();
          expect(find.text('Mehr anzeigen'), scale == 1.0 ? findsNothing : findsOneWidget, reason: 'Textfaktor $scale');
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('Ziel nicht sichtbar: neutraler Hinweis statt nichts', (tester) async {
        final app = await buildTestApp();
        await _joinBen(app);
        await app.gateway.sendMessage('ok', replyToId: r'$unbekannt');
        await _openChat(tester, app);
        expect(find.text('Antwort auf eine Nachricht, die hier nicht angezeigt wird'), findsOneWidget);
      });

      testWidgets('englisch: „Show more“', (tester) async {
        final app = await buildTestApp(lang: 'en');
        final ben = await _joinBen(app);
        await ben.sendMessage(long);
        await app.gateway.sendMessage('ok', replyToId: app.gateway.messages.first.id);
        await _openChatEn(tester, app, use24h: true);
        expect(find.text('Show more'), findsOneWidget);
      });

      testWidgets('Antwortleiste zeigt das Zitat einzeilig', (tester) async {
        final app = await buildTestApp();
        final ben = await _joinBen(app);
        await ben.sendMessage(long);
        await _openChat(tester, app);
        await tester.longPress(find.text(long));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Antworten'));
        await tester.pumpAndSettle();
        final preview = tester.widgetList<Text>(find.text(long)).where((t) => t.maxLines == 1);
        expect(preview, hasLength(1));
      });
    });
  });

  group('#254 Teil B: Sichtbarkeit und Gelesen-Markieren', () {
    testWidgets('Chat meldet das sichtbare Gespräch; Tab verlassen gibt es frei', (tester) async {
      final app = await buildTestApp();
      await _openChat(tester, app);
      expect(app.services.visibleChatThread, ChatThread.familyId);
      expect(app.services.chatThreadVisible(ChatThread.familyId), isTrue);
      await tester.tap(navTab('Einkauf'));
      await tester.pumpAndSettle();
      expect(app.services.visibleChatThread, isNull);
      expect(app.services.chatThreadVisible(ChatThread.familyId), isFalse);
    });

    testWidgets('im Hintergrund wird nichts gelesen markiert, nach der Rückkehr schon', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await _openChat(tester, app);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(app.services.chatThreadVisible(ChatThread.familyId), isFalse);
      await ben.sendMessage('im Hintergrund');
      await tester.pump();
      await tester.pump();
      expect(app.gateway.unreadIn(ChatThread.familyId), 1, reason: 'nicht gelesen markiert');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(app.gateway.unreadIn(ChatThread.familyId), 0);
      expect(find.text('Neue Nachrichten'), findsOneWidget);
    });

    testWidgets('inaktiv (unfokussiertes Fenster) gilt als sichtbar und markiert gelesen', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      await _openChat(tester, app);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await ben.sendMessage('Fenster ohne Fokus');
      await tester.pumpAndSettle();
      expect(app.gateway.unreadIn(ChatThread.familyId), 0);
      expect(app.services.chatThreadVisible(ChatThread.familyId), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('#294: bei aktiver App-Sperre wird nichts gelesen markiert; Entsperren markiert und setzt die Marke', (tester) async {
      final app = await buildTestApp(lockEnabled: true);
      final ben = await _joinBen(app);
      await _openChat(tester, app);
      expect(app.services.lock.locked, isFalse);
      app.auth.succeed = false;
      app.services.lock.lockNow();
      await tester.pumpAndSettle();
      await ben.sendMessage('während der Sperre');
      await tester.pumpAndSettle();
      expect(app.gateway.unreadIn(ChatThread.familyId), 1, reason: 'gesperrt: nicht gelesen markiert');
      app.auth.succeed = true;
      await tester.tap(find.text('Entsperren'));
      await tester.pumpAndSettle();
      expect(app.gateway.unreadIn(ChatThread.familyId), 0, reason: 'Entsperren markiert gelesen');
      expect(find.text('Neue Nachrichten'), findsOneWidget, reason: 'Marke entsteht beim Entsperren (E-42)');
    });
  });
}
