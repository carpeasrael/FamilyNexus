import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

Future<void> _pump(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

/// Zwei Bilder: Dialog-Route öffnen (Post-Frame) und aufbauen. `pumpAndSettle` wäre wegen
/// laufender Fortschrittsanzeigen nie fertig.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, String text) async {
  var f = find.widgetWithText(FilledButton, text);
  if (f.evaluate().isEmpty) f = find.widgetWithText(OutlinedButton, text);
  if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, text);
  if (f.evaluate().isEmpty) f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Anna (Moderatorin) hat eine Familie; Ben meldet sich neu an und hat keine.
Future<({TestApp ben, FakeMatrixGateway anna, String link})> _benWithoutFamily({bool securityReady = true}) async {
  final annaApp = await buildTestApp();
  final server = annaApp.server;
  // Die App prüft Links gegen die echte Uhr; eine feste Test-Uhr ließe sie nach 24 h ablaufen.
  server.now = () => DateTime.now().toUtc();
  final link = await annaApp.gateway.createInviteLink();
  final ben = await buildTestApp(loggedIn: false, server: server);
  await ben.gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'ben', password: 'geheim456');
  if (securityReady) await ben.gateway.setUpSecurity();
  return (ben: ben, anna: annaApp.gateway, link: link);
}

void main() {
  group('Beitreten per Link', () {
    testWidgets('Link einfügen → Bestätigung → Anfrage wartet → Moderator bestätigt → Einladung annehmen', (tester) async {
      final s = await _benWithoutFamily();
      await _pump(tester, s.ben);
      expect(find.text('Schritt 4 von 4'), findsOneWidget);
      await _tap(tester, 'Beitreten');
      await tester.enterText(find.widgetWithText(TextField, 'Einladungslink'), s.link);
      await _tap(tester, 'Beitrittsanfrage senden');
      expect(find.text('Beitritt anfragen?'), findsOneWidget);
      expect(find.textContaining('@anna:fake.test'), findsOneWidget, reason: 'Einladende Person wird genannt');
      await tester.tap(find.widgetWithText(FilledButton, 'Beitrittsanfrage senden').last);
      await tester.pumpAndSettle();
      expect(find.text('Anfrage gesendet. Warte auf die Bestätigung eines Moderators.'), findsOneWidget);
      expect(s.anna.family!.requests.single.userId, '@ben:fake.test');

      await s.anna.approveRequest('@ben:fake.test');
      await tester.pumpAndSettle();
      // Die eigene, bestätigte Anfrage wird ohne weiteren Tipp angenommen (E-49).
      expect(s.ben.gateway.family!.myRole, Role.member);
      expect(s.ben.store.data['onboardingDone'], 'true');
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'Hauptansicht');
    });

    testWidgets('abgelaufener oder manipulierter Link wird abgelehnt, nichts wird gesendet', (tester) async {
      final s = await _benWithoutFamily();
      await _pump(tester, s.ben);
      await _tap(tester, 'Beitreten');
      final expired = InviteLink.create(
        roomId: s.anna.family!.roomId,
        via: 'fake.test',
        inviter: '@anna:fake.test',
        now: DateTime.now().subtract(const Duration(days: 3)),
        validity: const Duration(hours: 1),
        nonce: '0123456789abcdef0123456789abcdef',
      );
      for (final bad in <String>[expired, 'familynexus://join?v=1&room=x', 'hallo', s.link.replaceFirst('familynexus', 'https')]) {
        await tester.enterText(find.widgetWithText(TextField, 'Einladungslink'), bad);
        await _tap(tester, 'Beitrittsanfrage senden');
        expect(find.text('Dieser Link ist ungültig oder abgelaufen.'), findsOneWidget, reason: bad);
      }
      expect(s.anna.family!.requests, isEmpty);
    });

    testWidgets('Anfrage zurückziehen', (tester) async {
      final s = await _benWithoutFamily();
      await _pump(tester, s.ben);
      await _tap(tester, 'Beitreten');
      await tester.enterText(find.widgetWithText(TextField, 'Einladungslink'), s.link);
      await _tap(tester, 'Beitrittsanfrage senden');
      await tester.tap(find.widgetWithText(FilledButton, 'Beitrittsanfrage senden').last);
      await tester.pumpAndSettle();
      await _tap(tester, 'Anfrage zurückziehen');
      expect(s.anna.family!.requests, isEmpty);
      expect(find.text('Einladungslink'), findsOneWidget);
    });

    testWidgets('Deep Link/QR aus der Kamera-App: Bestätigungsdialog erscheint im Familienschritt', (tester) async {
      final s = await _benWithoutFamily();
      s.ben.links.initial = s.link;
      await _pump(tester, s.ben);
      expect(find.text('Beitritt anfragen?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(s.anna.family!.requests, isEmpty, reason: 'ohne Bestätigung wird nie gesendet');
    });

    testWidgets('ungültiger Deep Link zeigt Hinweis und löst nichts aus', (tester) async {
      final s = await _benWithoutFamily();
      await _pump(tester, s.ben);
      s.ben.links.controller.add('familynexus://join?v=1&room=!x:y&evil=1');
      await tester.pumpAndSettle();
      expect(find.text('Dieser Link ist ungültig oder abgelaufen.'), findsOneWidget);
      expect(find.text('Beitritt anfragen?'), findsNothing);
    });

    testWidgets('Per Matrix-ID eingeladenes Konto: Einladungskarte statt „Gründen oder Beitreten“, ein Tipp genügt', (tester) async {
      final s = await _benWithoutFamily();
      await s.anna.inviteUser('@ben:fake.test');
      await _pump(tester, s.ben);
      expect(find.text('Du wurdest eingeladen'), findsOneWidget);
      expect(find.text('Familie Test'), findsOneWidget);
      expect(find.text('Einladung von @anna:fake.test'), findsOneWidget);
      expect(find.textContaining('zu keiner Beitrittsanfrage'), findsOneWidget, reason: 'Warnung bei unerwarteter Einladung');
      expect(find.byType(SegmentedButton<bool>), findsNothing, reason: 'keine Frage nach Gründen/Beitreten');
      expect(find.text('Gründe eine neue Familie oder tritt einer bestehenden bei.'), findsNothing);
      expect(s.ben.gateway.family, isNull, reason: 'ohne Tipp kein Beitritt');

      await _tap(tester, '„Familie Test“ beitreten');
      expect(s.ben.gateway.family!.myRole, Role.member);
      expect(s.ben.store.data['onboardingDone'], 'true');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Trotz Einladung: „andere Familie gründen oder beitreten“ zeigt die Auswahl', (tester) async {
      final s = await _benWithoutFamily();
      await s.anna.inviteUser('@ben:fake.test');
      await _pump(tester, s.ben);
      await _tap(tester, 'Stattdessen eine andere Familie gründen oder beitreten');
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('Gründe eine neue Familie oder tritt einer bestehenden bei.'), findsOneWidget);
      expect(s.ben.gateway.family, isNull);
    });

    testWidgets('Einladung ablehnen', (tester) async {
      final s = await _benWithoutFamily();
      await s.anna.inviteUser('@ben:fake.test');
      await _pump(tester, s.ben);
      await _tap(tester, 'Ablehnen');
      expect(s.ben.gateway.invitations, isEmpty);
      expect(s.ben.gateway.family, isNull);
    });
  });

  group('Schlüsselsicherung', () {
    testWidgets('Ersteinrichtung: Schlüssel wird einmalig gezeigt, ohne Bestätigung kein Weiter', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await app.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await _pump(tester, app);
      await _tap(tester, 'Schlüsselsicherung einrichten');
      expect(find.text('Dein Wiederherstellungsschlüssel'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Weiter').first).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tap(tester, 'Weiter');
      expect(find.text('Dein Wiederherstellungsschlüssel'), findsNothing, reason: 'Schlüssel verschwindet nach Bestätigung');
      expect(app.gateway.securityState, SecurityState.ready);
    });

    testWidgets('Server verlangt Passwort: Dialog, falsches Passwort scheitert, richtiges gelingt', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.requirePasswordForSecurity = true;
      await app.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await _pump(tester, app);
      await _tap(tester, 'Schlüsselsicherung einrichten');
      expect(find.text('Passwort bestätigen'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'falsch');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Weiter')));
      await tester.pumpAndSettle();
      expect(find.text('Benutzername oder Passwort stimmen nicht.'), findsOneWidget);
      expect(app.gateway.securityState, SecurityState.needsSetup);
      await _tap(tester, 'Schlüsselsicherung einrichten');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Weiter')));
      await tester.pumpAndSettle();
      expect(find.text('Dein Wiederherstellungsschlüssel'), findsOneWidget);
    });

    testWidgets('zweites Gerät: Wiederherstellung mit Schlüssel (falscher, dann richtiger)', (tester) async {
      final first = await buildTestApp();
      final key = first.server.recoveryKeys['@anna:fake.test']!;
      final second = await buildTestApp(loggedIn: false, server: first.server);
      await second.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await _pump(tester, second);
      expect(find.text('Dieses Gerät verifizieren'), findsOneWidget);
      expect(find.textContaining('Mit einem anderen Gerät verifizieren'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Wiederherstellungsschlüssel'), 'falsch');
      await _tap(tester, 'Mit Schlüssel wiederherstellen');
      expect(find.text('Der Schlüssel passt nicht.'), findsOneWidget);
      expect(second.gateway.securityState, SecurityState.needsRestore);
      await tester.enterText(find.widgetWithText(TextField, 'Wiederherstellungsschlüssel'), key);
      await _tap(tester, 'Mit Schlüssel wiederherstellen');
      expect(second.gateway.securityState, SecurityState.ready);
    });

    testWidgets('zweites Gerät: Emoji-Verifizierung über beide Geräte', (tester) async {
      final first = await buildTestApp();
      final second = await buildTestApp(loggedIn: false, server: first.server);
      await second.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await _pump(tester, second);

      // Gerät 2 startet die Verifizierung mit Gerät 1.
      await tester.tap(find.text('Mit einem anderen Gerät verifizieren: Gerät DEV1'));
      await _pumpFrames(tester);
      expect(find.text('Warte auf die Gegenseite …'), findsOneWidget);
      // Gerät 1 erhält die Anfrage (eigene App-Instanz) und nimmt an.
      expect(first.gateway.verification!.phase, VerificationPhase.incomingRequest);
      await first.gateway.acceptVerification();
      await _pumpFrames(tester);
      expect(find.textContaining('Vergleiche diese Symbole'), findsOneWidget);
      expect(find.text('🐶'), findsOneWidget);
      await tester.tap(find.text('Sie stimmen überein'));
      await _pumpFrames(tester);
      expect(find.text('Warte auf Bestätigung der Gegenseite …'), findsOneWidget);
      await first.gateway.confirmEmojiMatch(true);
      await _pumpFrames(tester);
      expect(find.text('Verifiziert.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Schließen'));
      await tester.pumpAndSettle();
      expect(second.gateway.securityState, SecurityState.ready);
    });

    testWidgets('eingehende Verifizierungsanfrage erscheint als Dialog (Gerät 1) und lässt sich ablehnen', (tester) async {
      final first = await buildTestApp();
      await _pump(tester, first);
      final second = first.server.newDevice();
      await second.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await second.startVerification(userId: '@anna:fake.test', deviceId: 'DEV1');
      await tester.pumpAndSettle();
      expect(find.textContaining('möchte die Verifizierung starten'), findsOneWidget);
      await tester.tap(find.text('Ablehnen'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(second.securityState, SecurityState.needsRestore);
    });

    testWidgets('abweichende Emoji: Verifizierung wird abgebrochen, Gerät bleibt unverifiziert', (tester) async {
      final first = await buildTestApp();
      await _pump(tester, first);
      final second = first.server.newDevice();
      await second.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await second.startVerification(userId: '@anna:fake.test', deviceId: 'DEV1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annehmen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sie stimmen nicht überein'));
      await tester.pumpAndSettle();
      expect(find.text('Die Verifizierung wurde abgebrochen.'), findsOneWidget);
      expect(second.securityState, SecurityState.needsRestore);
    });
  });

  testWidgets('ohne verifiziertes Gerät keine Hauptansicht (SA-1), auch wenn Familie vorhanden', (tester) async {
    final first = await buildTestApp();
    final second = await buildTestApp(loggedIn: false, server: first.server);
    await second.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
    second.gateway.attachFamilyRoom(first.gateway.familyRoom!.id);
    second.store.data['onboardingDone'] = 'true';
    final services = (await buildTestApp(loggedIn: false, server: first.server));
    expect(second.gateway.family, isNotNull);
    expect(services.gateway.session.name, 'loggedOut');
    await _pump(tester, second);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Dieses Gerät verifizieren'), findsOneWidget);
  });
}
