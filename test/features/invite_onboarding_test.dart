import 'dart:convert';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> _tap(WidgetTester tester, String text, {bool settle = true}) async {
  var f = find.widgetWithText(FilledButton, text);
  if (f.evaluate().isEmpty) f = find.widgetWithText(OutlinedButton, text);
  if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, text);
  if (f.evaluate().isEmpty) f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Anna (Moderatorin) mit Familie und einem frischen Einladungslink; dazu ein neues Gerät ohne Konto.
Future<({TestApp anna, TestApp guest, String link})> _annaInvites({bool matrixOrgDefault = false}) async {
  final anna = await buildTestApp();
  // Die App prüft Links gegen die echte Uhr.
  anna.server.now = () => DateTime.now().toUtc();
  final link = await anna.gateway.createInviteLink();
  final guest = await buildTestApp(loggedIn: false, server: anna.server, matrixOrgDefault: matrixOrgDefault);
  return (anna: anna, guest: guest, link: link);
}

Future<void> _createAccount(WidgetTester tester, {required String name}) async {
  await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), name);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'sicher-genug');
  await tester.pumpAndSettle();
  await _tap(tester, 'Konto erstellen');
}

Future<void> _emergencyKey(WidgetTester tester) async {
  await _tap(tester, 'Notfall-Schlüssel erstellen');
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await _tap(tester, 'Weiter');
}

void main() {
  group('Neulinge mit Einladungslink (E-56)', () {
    testWidgets(
        'TP-JOIN-01 Link geöffnet → ohne Serverfrage „Konto erstellen“ → Notfall-Schlüssel → Beitrittskarte mit Namen → Anfrage → bestätigt → Hauptansicht',
        (tester) async {
      final s = await _annaInvites();
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);

      expect(find.text('Schritt 1 von 3'), findsOneWidget);
      expect(find.text('Konto erstellen'), findsWidgets);
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget, reason: 'Anbieter aus der Einladung');
      expect(find.text('Neue Familie gründen'), findsNothing, reason: 'Startseite übersprungen');
      expect(s.guest.services.settings.settings.pendingInvite, s.link, reason: 'Link bleibt über Neustarts erhalten');

      await _createAccount(tester, name: 'Carla');
      expect(s.guest.gateway.userId, '@carla:fake.test');
      expect(find.text('Schritt 2 von 3'), findsOneWidget);
      await _emergencyKey(tester);

      expect(find.text('Schritt 3 von 3'), findsOneWidget);
      expect(find.text('Du trittst der Familie „Familie Test“ bei. Eingeladen hat dich Anna (Konto bei fake.test).'), findsOneWidget);
      expect(s.anna.gateway.family!.requests, isEmpty, reason: 'ohne Tipp wird nie angefragt (E-14)');
      await _tap(tester, 'Beitritt anfragen');
      expect(find.textContaining('Fast geschafft! Anna muss dich noch bestätigen.'), findsOneWidget);
      expect(s.anna.gateway.family!.requests.single.displayName, 'Carla', reason: 'Moderatorin sieht den Namen');
      expect(s.guest.services.settings.settings.pendingInvite, isNull, reason: 'nach der Anfrage verbraucht');

      await s.anna.gateway.approveRequest('@carla:fake.test');
      await tester.pumpAndSettle();
      expect(s.guest.gateway.family!.myRole, Role.member);
      expect(s.guest.services.settings.settings.onboardingDone, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('TP-JOIN-02 Link überlebt einen Neustart der App (z. B. während der Browser offen war)', (tester) async {
      final s = await _annaInvites();
      // „Neustart“: der Link liegt nur noch in den gespeicherten Einstellungen.
      await s.guest.services.settings.update((c) => c.copyWith(pendingInvite: s.link));
      await _pump(tester, s.guest);
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
      expect(find.text('Schritt 1 von 3'), findsOneWidget);
      expect(s.guest.services.pendingInvite.value?.inviterName, 'Anna');
    });

    testWidgets('#103 Zurück zur Startseite verwirft den vorgemerkten Link; „Neue Familie gründen“ nutzt wieder matrix.org', (tester) async {
      final s = await _annaInvites();
      await s.guest.services.settings.update((c) => c.copyWith(pendingInvite: s.link));
      await _pump(tester, s.guest);
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget, reason: 'gespeicherter Link wirkt nach dem Neustart');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Neue Familie gründen'), findsOneWidget);
      expect(s.guest.services.pendingInvite.value, isNull);
      expect(s.guest.services.settings.settings.pendingInvite, isNull, reason: 'dauerhaft verworfen');
    });

    testWidgets('#103 „Neue Familie gründen“ verwirft einen vorgemerkten Link', (tester) async {
      final s = await _annaInvites();
      await s.guest.services.settings.update((c) => c.copyWith(pendingInvite: s.link));
      await _pump(tester, s.guest);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      s.guest.links.initial = null;
      await s.guest.services.settings.update((c) => c.copyWith(pendingInvite: s.link));
      s.guest.services.pendingInvite.value = null;
      await _tap(tester, 'Neue Familie gründen');
      expect(s.guest.services.settings.settings.pendingInvite, isNull);
    });

    testWidgets('TP-JOIN-02b abgelaufener gespeicherter Link wird beim Start verworfen', (tester) async {
      final s = await _annaInvites();
      await s.guest.services.settings.update((c) => c.copyWith(pendingInvite: 'familynexus://join?v=2&room=x'));
      await _pump(tester, s.guest);
      expect(s.guest.services.pendingInvite.value, isNull);
      expect(s.guest.services.settings.settings.pendingInvite, isNull);
      expect(find.text('Neue Familie gründen'), findsOneWidget);
    });

    testWidgets('TP-JOIN-06 „Ich wurde eingeladen“ ohne geöffneten Link: Link einfügen → Konto erstellen (4 Schritte)', (tester) async {
      final s = await _annaInvites();
      await _pump(tester, s.guest);
      await _tap(tester, 'Ich wurde eingeladen');
      expect(find.text('Schritt 1 von 4'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Einladungslink'), 'kein link');
      await _tap(tester, 'Weiter');
      expect(find.text('Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Einladungslink'), s.link);
      await _tap(tester, 'Weiter');
      expect(find.text('Schritt 2 von 4'), findsOneWidget);
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Schritt 1 von 4'), findsOneWidget, reason: 'zurück zum Link-Schritt');
    });

    testWidgets('TP-JOIN-07 Eingeladene mit bestehendem Konto: Anmelden, dann Beitrittskarte', (tester) async {
      final s = await _annaInvites();
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);
      await _tap(tester, 'Ich habe schon ein Konto');
      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ben');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim456');
      await tester.pumpAndSettle();
      await _tap(tester, 'Anmelden');
      await _emergencyKey(tester);
      expect(find.widgetWithText(FilledButton, 'Beitritt anfragen'), findsOneWidget);
    });

    testWidgets('TP-JOIN-10 Server aus dem Link (nicht matrix.org) steht im Feld „Anderen Anbieter verwenden“ und wird fürs Konto genutzt (E-63)', (tester) async {
      final s = await _annaInvites(matrixOrgDefault: true);
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);

      expect(tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue, isTrue, reason: '„Anderer Anbieter“ gewählt');
      final field = find.widgetWithText(TextField, 'Adresse des Anbieters');
      expect(field, findsOneWidget, reason: 'Erweitert ist aufgeklappt, die Adresse sichtbar');
      expect(tester.widget<TextField>(field).controller!.text, 'fake.test');
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);

      await _createAccount(tester, name: 'Carla');
      expect(s.guest.gateway.userId, '@carla:fake.test', reason: 'Konto liegt auf dem Server aus dem Link');
    });

    testWidgets('TP-JOIN-11 Server aus dem Link ist matrix.org: Standardanbieter bleibt gewählt, kein eigenes Feld', (tester) async {
      final s = await _annaInvites(matrixOrgDefault: true);
      final link = InviteLink.create(
        roomId: '!fam:matrix.org',
        via: 'matrix.org',
        inviter: '@anna:matrix.org',
        now: DateTime.now(),
        nonce: '0123456789abcdef0123456789abcdef',
        familyName: 'Familie Test',
      );
      s.guest.links.initial = link;
      await _pump(tester, s.guest);

      expect(find.byType(RadioGroup<bool>), findsNothing, reason: '„Erweitert“ bleibt zugeklappt, weil nichts Besonderes gewählt wurde');
      await _tap(tester, 'Erweitert');
      expect(tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue, isFalse);
      expect(find.widgetWithText(TextField, 'Adresse des Anbieters'), findsNothing);
      expect(find.text('matrix.org (empfohlen)'), findsOneWidget);
    });

    testWidgets('TP-JOIN-12 Anmelden mit bestehendem Konto: Link kommt erst auf der Anmeldeseite an → Server aus dem Link, am Ende die Familie', (tester) async {
      final s = await _annaInvites(matrixOrgDefault: true);
      await _pump(tester, s.guest);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.widgetWithText(TextField, 'Adresse des Anbieters'), findsNothing, reason: 'vorher der Standardanbieter');

      s.guest.links.controller.add(s.link);
      await tester.pumpAndSettle();
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget, reason: 'Anmeldung beim Server aus dem Link');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Adresse des Anbieters')).controller!.text, 'fake.test');

      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'ben');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim456');
      await tester.pumpAndSettle();
      await _tap(tester, 'Anmelden');
      expect(s.guest.gateway.userId, '@ben:fake.test');
      await _emergencyKey(tester);

      expect(find.text('Du trittst der Familie „Familie Test“ bei. Eingeladen hat dich Anna (Konto bei fake.test).'), findsOneWidget, reason: 'die Familie aus dem Link wird am Ende angeboten');
      await _tap(tester, 'Beitritt anfragen');
      expect(s.anna.gateway.family!.requests.single.displayName, 'Ben');
    });

    testWidgets('Issue #6: Familie auf Server im Heimnetz (Name ohne Punkt) – Beitritt vor der Anmeldung mit Warnung', (tester) async {
      final server = FakeMatrixServer(host: 'nas')
        ..addAccount('anna', 'geheim123', displayName: 'Anna');
      final anna = await buildTestApp(server: server);
      server.now = () => DateTime.now().toUtc();
      final link = await anna.gateway.createInviteLink();
      final guest = await buildTestApp(loggedIn: false, server: server);
      guest.links.initial = link;
      await _pump(tester, guest);
      // Review R2: ohne Zustimmung keine Verbindung zum Heimnetz-Server.
      expect(find.textContaining('Server im Heimnetz (nas)'), findsOneWidget);
      expect(find.text('Dein Konto liegt bei nas.'), findsNothing);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Konto erstellen')).onPressed, isNull);
      await _tap(tester, 'Mit nas verbinden');
      expect(find.text('Dein Konto liegt bei nas.'), findsOneWidget, reason: 'Link angenommen, Anbieter aus der Einladung');
      await _createAccount(tester, name: 'Carla');
      await _emergencyKey(tester);
      expect(find.textContaining('Server im Heimnetz (nas)'), findsOneWidget, reason: 'deutliche Warnung');
      expect(anna.gateway.family!.requests, isEmpty, reason: 'ohne Tipp keine Anfrage');
      await _tap(tester, 'Beitritt anfragen');
      expect(anna.gateway.family!.requests.single.displayName, 'Carla');
    });

    testWidgets('Review R3: Heimnetz-Link, aber angemeldet auf anderem Server: klare Meldung statt Anfrage', (tester) async {
      final home = FakeMatrixServer(host: 'nas')..addAccount('anna', 'geheim123', displayName: 'Anna');
      final anna = await buildTestApp(server: home);
      home.now = () => DateTime.now().toUtc();
      final link = await anna.gateway.createInviteLink();
      final other = await buildTestApp(loggedIn: false);
      await other.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'ben', password: 'geheim456');
      await other.gateway.setUpSecurity();
      other.links.initial = link;
      await _pump(tester, other);
      expect(find.textContaining('Mit deinem Konto bei fake.test kannst du ihr nicht beitreten'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Beitritt anfragen'), findsNothing);
    });

    testWidgets('Issue #6: eingefügter Link aus einer HTML-Mail (&amp;, in Klammern) wird angenommen', (tester) async {
      final s = await _annaInvites();
      await _pump(tester, s.guest);
      await _tap(tester, 'Ich wurde eingeladen');
      await tester.enterText(find.widgetWithText(TextField, 'Einladungslink'), 'Hier ist er: <${s.link.replaceAll('&', '&amp;')}>.');
      await _tap(tester, 'Weiter');
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
      expect(s.guest.services.settings.settings.pendingInvite, startsWith('familynexus://join?v=3&'), reason: 'bereinigt vorgemerkt');
    });

    testWidgets('TP-JOIN-03 Link geöffnet, obwohl bereits in einer Familie: Hinweis, nichts vorgemerkt', (tester) async {
      final s = await _annaInvites();
      await _pump(tester, s.anna);
      s.anna.links.controller.add(s.link);
      await tester.pumpAndSettle();
      expect(find.text('Du bist bereits in einer Familie.'), findsOneWidget);
      expect(s.anna.services.pendingInvite.value, isNull);
      expect(s.anna.services.settings.settings.pendingInvite, isNull);
    });

    testWidgets('OAuth-Rücksprung wird nicht als Einladung behandelt', (tester) async {
      final s = await _annaInvites();
      await _pump(tester, s.guest);
      s.guest.links.controller.add('io.github.carpeasrael.familynexus:/oauth?code=x&state=y');
      await tester.pumpAndSettle();
      expect(find.textContaining('Einladungslink'), findsNothing, reason: 'keine Fehlermeldung');
    });
  });

  group('Anmeldung und Kontoanlage im Browser (OAuth, E-55)', () {
    testWidgets('TP-OAUTH-01/02 Anbieter mit Browser-Anmeldung: Seite mit prompt=create, Rücksprung meldet an, Name wird gesetzt',
        (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      expect(find.widgetWithText(TextField, 'Passwort'), findsNothing, reason: 'Passwort nur beim Anbieter');
      await tester.enterText(find.widgetWithText(TextField, 'Wie heißt du?'), 'Greta');
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      expect(find.textContaining('Bitte im Browser bei fake.test fortfahren'), findsOneWidget);
      final opened = app.browser.opened.single;
      expect(opened.queryParameters['prompt'], 'create');
      expect(opened.scheme, 'https');

      app.oauth.deliver(app.gateway.oauthCallback('greta'));
      await tester.pumpAndSettle();
      expect(app.gateway.userId, '@greta:fake.test');
      expect(app.server.displayNameOf('@greta:fake.test'), 'Greta');
      expect(app.gateway.securityState, SecurityState.needsSetup);
      expect(find.text('Notfall-Schlüssel erstellen'), findsOneWidget);
    });

    testWidgets('TP-OAUTH-03 Rücksprung mit fremdem state wird verworfen, die echte Anmeldung läuft weiter (R8)', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      app.oauth.deliver(app.gateway.oauthCallback('mallory', state: 'gefälscht'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.gateway.session, SessionState.loggedOut, reason: 'fremder Rücksprung meldet nie an');
      expect(find.textContaining('Bitte im Browser bei fake.test fortfahren'), findsOneWidget, reason: 'weiter warten');
      app.oauth.deliver(app.gateway.oauthCallback('greta'));
      await tester.pumpAndSettle();
      expect(app.gateway.userId, '@greta:fake.test');
    });

    testWidgets('R3 „Zurück“ während der Browser-Anmeldung beendet sie; ein neuer Versuch funktioniert', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      expect(app.oauth.waiting, isTrue);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(app.oauth.waiting, isFalse, reason: 'Versuch beendet');
      expect(find.text('Neue Familie gründen'), findsOneWidget);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      app.oauth.deliver(app.gateway.oauthCallback('hanna'));
      await tester.pumpAndSettle();
      expect(app.gateway.userId, '@hanna:fake.test');
      expect(find.text('Notfall-Schlüssel erstellen'), findsOneWidget);
    });

    testWidgets('TP-OAUTH-04 Abbrechen bzw. Ablehnung beim Anbieter: verständliche Meldung, erneut möglich', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      await _tap(tester, 'Abbrechen');
      expect(find.text('Die Anmeldung im Browser wurde nicht abgeschlossen. Bitte versuche es noch einmal.'), findsOneWidget);
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      app.oauth.deliver(app.gateway.oauthCallback('x', denied: true));
      await tester.pumpAndSettle();
      expect(app.gateway.session, SessionState.loggedOut);
      expect(app.browser.opened, hasLength(2));
    });

    testWidgets('TP-OAUTH-04b kein Browser verfügbar: Meldung statt Hängen', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      app.browser.available = false;
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Konto bei fake.test erstellen');
      expect(find.text('Die Anmeldung im Browser wurde nicht abgeschlossen. Bitte versuche es noch einmal.'), findsOneWidget);
    });

    testWidgets('TP-OAUTH-05 Anmelden mit bestehendem Konto über den Browser (ohne prompt=create)', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      await _pump(tester, app);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.widgetWithText(TextField, 'Passwort'), findsNothing);
      await _tap(tester, 'Bei fake.test anmelden', settle: false);
      expect(app.browser.opened.single.queryParameters.containsKey('prompt'), isFalse);
      app.oauth.deliver(app.gateway.oauthCallback('anna'));
      await tester.pumpAndSettle();
      expect(app.gateway.userId, '@anna:fake.test');
      expect(find.text('Familie „Familie Test“ gefunden – du bist bereits Mitglied. Die Einrichtung wird abgeschlossen.'), findsNothing,
          reason: 'Anna hat in diesem Test noch keine Familie');
    });
  });

  group('Notfall-Schlüssel (E-57)', () {
    testWidgets('TP-KEY-02/03 Kopieren leert die Zwischenablage nach einer Minute; Datei enthält Schlüssel und Anleitung', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        if (call.method == 'Clipboard.getData') return <String, Object?>{'text': clipboard};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      // Android-Weg: Schlüssel wird über den eigenen Kanal als „vertraulich“ kopiert.
      const window = MethodChannel('de.inneso.familynexus/window');
      var sensitive = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(window, (call) async {
        if (call.method == 'copySecret') {
          sensitive++;
          clipboard = call.arguments as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(window, null));
      await _pump(tester, app);
      await _tap(tester, 'Ich habe schon ein Konto');
      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
      await tester.pumpAndSettle();
      await _tap(tester, 'Anmelden');
      await _tap(tester, 'Notfall-Schlüssel erstellen');
      final key = app.server.recoveryKeys['@anna:fake.test']!;

      await _tap(tester, 'Kopieren');
      expect(clipboard, key);
      expect(sensitive, 1, reason: 'als vertraulich markiert (Android)');
      expect(find.textContaining('Die Zwischenablage wird nach einer Minute geleert.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(clipboard, '', reason: 'Schlüssel bleibt nicht in der Zwischenablage');

      await _tap(tester, 'Als Datei speichern');
      final files = (app.services.files as FakeFileAccess).contents;
      final text = utf8.decode(files['FamilyNexus-Notfall-Schluessel.txt']!);
      expect(text, contains(key));
      expect(text, contains('@anna:fake.test'));
      expect(text, contains('Dieses Gerät freischalten'));
      expect(app.protection.last, isTrue, reason: 'Bildschirmschutz, solange der Schlüssel sichtbar ist (S6)');
    });

    testWidgets('TP-KEY-02b Kopieren überschreibt nichts, was die Person inzwischen kopiert hat', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        if (call.method == 'Clipboard.getData') return <String, Object?>{'text': clipboard};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await app.gateway.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
      await _pump(tester, app);
      await _tap(tester, 'Notfall-Schlüssel erstellen');
      await _tap(tester, 'Kopieren');
      clipboard = 'Einkaufsliste';
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(clipboard, 'Einkaufsliste');
    });
  });
}
