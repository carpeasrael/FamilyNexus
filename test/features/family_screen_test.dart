import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Future<void> _openFamily(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Familie')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Moderator sieht Mitglieder mit Rolle als Text, Anfragen getrennt und die Moderator-Empfehlung', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership['@ben:fake.test'] = MemberStatus.joined;
    room.membership['@cara:fake.test'] = MemberStatus.requested;
    await _openFamily(tester, app);

    expect(find.text('Familie Test'), findsOneWidget);
    expect(find.text('Moderator'), findsOneWidget);
    expect(find.text('Mitglied'), findsOneWidget, reason: 'Rolle nie nur über Farbe');
    expect(find.text('Beitrittsanfragen'), findsOneWidget);
    expect(find.text('Bestätigen'), findsOneWidget);
    expect(find.text('Empfehlung: Ernenne einen zweiten Moderator.'), findsOneWidget);
    expect(find.text('Mitglied einladen'), findsOneWidget);
  });

  testWidgets('Mitglied sieht keine Verwaltung', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    // Anna wird zum einfachen Mitglied (Rolle zurückgestuft, z. B. durch einen anderen Moderator).
    room.power['@anna:fake.test'] = 0;
    room.membership['@ben:fake.test'] = MemberStatus.joined;
    room.power['@ben:fake.test'] = 50;
    await _openFamily(tester, app);
    expect(find.text('Mitglied einladen'), findsNothing);
    expect(find.text('Beitrittsanfragen'), findsNothing);
    expect(find.byTooltip('Familienname ändern'), findsNothing);
    expect(find.text('Nur Moderatoren verwalten die Familie.'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsWidgets, reason: 'Verifizieren bleibt für alle möglich');
  });

  testWidgets('Einladungslink als QR-Code: gültiger Link, 24 Stunden', (tester) async {
    final app = await buildTestApp();
    await _openFamily(tester, app);
    await tester.tap(find.text('Jemanden einladen'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Jemanden einladen')), findsOneWidget);
    expect(find.bySemanticsLabel('QR-Code anzeigen'), findsWidgets);
    expect(find.textContaining('24 Stunden gültig'), findsOneWidget);
    expect(find.text('Per E-Mail senden'), findsOneWidget);
    expect(find.text('Link kopieren'), findsOneWidget);
    final link = await app.gateway.createInviteLink();
    expect(link, startsWith('familynexus://join?'));
  });

  testWidgets('Einladungslink per E-Mail: Entwurf mit Anleitung und Link, ohne Mailprogramm wird kopiert', (tester) async {
    final app = await buildTestApp();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _openFamily(tester, app);
    await tester.tap(find.text('Jemanden einladen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Per E-Mail senden'));
    await tester.pumpAndSettle();
    final draft = app.mail.drafts.single;
    expect(draft.subject, 'Einladung zu FamilyNexus');
    expect(draft.body, contains('„Familie Test“'));
    expect(draft.body, contains('familynexus://join?'));
    expect(draft.body, contains('24 Stunden'));
    expect(draft.body, contains('„Ich wurde eingeladen“'), reason: 'Anleitung nennt den Weg in der App');
    expect(draft.body, isNot(contains('Matrix')), reason: 'keine Fachbegriffe');
    final link = RegExp(r'familynexus://join\?\S+').firstMatch(draft.body)!.group(0)!;
    expect(InviteLink.tryParse(link, now: DateTime.now()), isNotNull, reason: 'der Link im Entwurf ist gültig');

    app.mail.available = false;
    await tester.tap(find.text('Per E-Mail senden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(app.mail.drafts, hasLength(1));
    expect(find.text('Kein Mailprogramm gefunden. Der Link wurde stattdessen kopiert.'), findsOneWidget);
    expect(clipboard, startsWith('familynexus://join?'), reason: 'Fallback kopiert den Link');
  });

  testWidgets('Anfrage bestätigen und ablehnen', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership['@ben:fake.test'] = MemberStatus.requested;
    room.membership['@cara:fake.test'] = MemberStatus.requested;
    // Ben nennt einen gültigen, ausgegebenen Link; Cara einen unbekannten (S2).
    room.issued['0' * 32] = DateTime.now().add(const Duration(days: 1));
    room.knockNonce['@ben:fake.test'] = '0' * 32;
    room.knockNonce['@cara:fake.test'] = 'f' * 32;
    await _openFamily(tester, app);
    expect(find.text('Gültiger Einladungslink'), findsOneWidget);
    expect(find.text('Unbekannter Link – von keinem Moderator ausgegeben'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Bestätigen').last).onPressed, isNull, reason: 'unbekannter Link nicht bestätigbar');
    await tester.tap(find.text('Bestätigen').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('@ben:fake.test in die Familie aufnehmen'), findsOneWidget, reason: 'Rückfrage mit voller ID');
    expect(room.membership['@ben:fake.test'], MemberStatus.requested);
    await tester.tap(find.widgetWithText(FilledButton, 'Bestätigen').last);
    await tester.pumpAndSettle();
    expect(room.membership['@ben:fake.test'], MemberStatus.invited);
    await tester.tap(find.text('Ablehnen').first);
    await tester.pumpAndSettle();
    expect(room.membership.containsKey('@cara:fake.test'), isFalse);
  });

  testWidgets('Ernennen und Entfernen verlangen Bestätigung', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership['@ben:fake.test'] = MemberStatus.joined;
    await _openFamily(tester, app);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zum Moderator ernennen').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Moderatoren können einladen'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(room.power['@ben:fake.test'], isNot(50), reason: 'ohne Bestätigung nichts geändert');

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entfernen').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Raumschlüssel werden erneuert'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Entfernen'));
    await tester.pumpAndSettle();
    expect(room.membership.containsKey('@ben:fake.test'), isFalse);
    expect(room.keyEpoch, 1);
  });

  testWidgets('Einladen per Matrix-ID prüft die Eingabe', (tester) async {
    final app = await buildTestApp();
    await _openFamily(tester, app);
    expect(find.widgetWithText(TextField, 'Per Benutzer-ID einladen'), findsNothing, reason: 'nur unter „Erweitert“');
    await tester.ensureVisible(find.text('Erweitert'));
    await tester.tap(find.text('Erweitert'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Per Benutzer-ID einladen'), 'kein-mxid');
    await tester.ensureVisible(find.text('Einladen'));
    await tester.tap(find.text('Einladen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Per Benutzer-ID einladen'), '@ben:fake.test');
    await tester.tap(find.text('Einladen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nachrichtenschlüssel der Familie'), findsOneWidget, reason: 'Rückfrage vor dem Einladen');
    expect(app.gateway.familyRoom!.membership['@ben:fake.test'], isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Einladen').last);
    await tester.pumpAndSettle();
    expect(app.gateway.familyRoom!.membership['@ben:fake.test'], MemberStatus.invited);
  });

  testWidgets('Geänderte Identität: Warnung, Badge mit Text, Akzeptieren nur nach Rückfrage', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership['@ben:fake.test'] = MemberStatus.joined;
    room.identityChanged.add('@ben:fake.test');
    await _openFamily(tester, app);
    expect(find.text('Identität geändert'), findsOneWidget);
    expect(find.textContaining('Sicherheitsschlüssel von Ben'), findsOneWidget);
    await tester.tap(find.byTooltip('Aktionen für Ben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Änderung akzeptieren').last);
    await tester.pumpAndSettle();
    expect(room.identityChanged, isNotEmpty, reason: 'ohne Bestätigung unverändert');
    await tester.tap(find.widgetWithText(FilledButton, 'Änderung akzeptieren'));
    await tester.pumpAndSettle();
    expect(room.identityChanged, isEmpty);
    expect(find.text('Identität geändert'), findsNothing);
  });

  testWidgets('Familie umbenennen (Moderator)', (tester) async {
    final app = await buildTestApp();
    await _openFamily(tester, app);
    await tester.tap(find.byTooltip('Familienname ändern'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name der Familie'), 'Neue Familie');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(app.gateway.family!.name, 'Neue Familie');
  });
}
