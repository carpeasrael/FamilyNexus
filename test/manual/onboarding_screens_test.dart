// Bildschirmfotos der Einrichtung für die manuelle Prüfung (Testplan „Onboarding“, TP-MAN-*).
// Läuft auf dem Rechner (ohne Gerät) mit den echten Schriften der App und der Fake-Matrix aus
// test/support. Nicht Teil der automatischen Gates: nur mit FN_SCREENSHOTS=1, siehe
// tool/onboarding_screens.sh. Ergebnis: build/onboarding_tour/NN-name.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

final bool _enabled = Platform.environment['FN_SCREENSHOTS'] == '1';
final Directory _out = Directory(Platform.environment['FN_SCREENSHOTS_DIR'] ?? 'build/onboarding_tour');
final GlobalKey _shot = GlobalKey();
int _count = 0;

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await family('SpaceGrotesk', <String>['assets/fonts/SpaceGrotesk-Variable.ttf']);
  await family('IBMPlexSans', <String>['assets/fonts/IBMPlexSans-Variable.ttf']);
  await family('IBMPlexMono', <String>['assets/fonts/IBMPlexMono-Regular.ttf', 'assets/fonts/IBMPlexMono-Medium.ttf']);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/tools/flutter';
  await family('MaterialIcons', <String>['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

Future<void> _start(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(780, 1688); // 390 × 844 dp, Handy hochkant
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _shot, child: FamilyNexusApp(services: app.services)));
  await tester.pumpAndSettle();
}

/// Speichert den aktuellen Bildschirm; laufende Fortschrittsanzeigen werden nicht abgewartet.
Future<void> _snap(WidgetTester tester, String name, {bool settle = true}) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
  final n = (++_count).toString().padLeft(2, '0');
  await tester.runAsync(() async {
    final boundary = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File('${_out.path}/$n-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
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

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump(const Duration(milliseconds: 900)); // Entprellung der automatischen Prüfungen
  await tester.pumpAndSettle();
}

/// Bildschirm ganz nach oben bzw. unten schieben (für Fotos langer Seiten).
Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  group('Bildschirmfotos der Einrichtung', skip: _enabled ? false : 'Nur mit FN_SCREENSHOTS=1 (tool/onboarding_screens.sh)', () {
    testWidgets('Weg A: Neue Familie gründen (mit Zusatzschritten des Anbieters)', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationFlows = <List<String>>[
        <String>[RegistrationFlows.terms, RegistrationFlows.recaptcha],
      ];
      app.server.captchaSolved = true;
      await _start(tester, app);
      await _snap(tester, 'start');
      await _tap(tester, 'Neue Familie gründen');
      await _snap(tester, 'konto-erstellen-leer');
      await _type(tester, 'Wie heißt du?', 'Anna');
      await _type(tester, 'Passwort', 'sicher-genug');
      await _snap(tester, 'benutzername-vergeben');
      await _type(tester, 'Wie heißt du?', 'Carla Groß');
      await _snap(tester, 'konto-erstellen-ausgefuellt');
      await _tap(tester, 'Erweitert');
      await _scroll(tester, -600);
      await _snap(tester, 'erweitert-anbieter');
      await _scroll(tester, 600);
      await _tap(tester, 'Konto erstellen');
      await _snap(tester, 'zusatzschritt-bedingungen');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tap(tester, 'Weiter');
      await _snap(tester, 'zusatzschritt-kein-roboter');
      await _tap(tester, 'Ich bin fertig');
      await _snap(tester, 'notfall-schluessel-start');
      await _tap(tester, 'Notfall-Schlüssel erstellen');
      await _snap(tester, 'notfall-schluessel-anzeige');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tap(tester, 'Weiter');
      await _type(tester, 'Name der Familie', 'Familie Groß');
      await _snap(tester, 'familie-benennen');
      await _tap(tester, 'Familie gründen');
      await _snap(tester, 'familie-fertig');
      await _tap(tester, 'Jetzt einladen');
      await _snap(tester, 'einladen-dialog');
      await _tap(tester, 'Schließen');
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Familie')));
      await _snap(tester, 'familie-ansicht');
    });

    testWidgets('Weg B: Ich wurde eingeladen (Link geöffnet)', (tester) async {
      final anna = await buildTestApp();
      anna.server.now = () => DateTime.now().toUtc();
      final link = await anna.gateway.createInviteLink();
      final guest = await buildTestApp(loggedIn: false, server: anna.server);
      guest.links.initial = link;
      await _start(tester, guest);
      await _snap(tester, 'eingeladen-konto-erstellen');
      await _type(tester, 'Wie heißt du?', 'Ben Neu');
      await _type(tester, 'Passwort', 'sicher-genug');
      await _tap(tester, 'Konto erstellen');
      await _tap(tester, 'Notfall-Schlüssel erstellen');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await _tap(tester, 'Weiter');
      await _snap(tester, 'eingeladen-beitrittskarte');
      await _tap(tester, 'Details');
      await _snap(tester, 'eingeladen-details');
      await _tap(tester, 'Beitritt anfragen');
      await _snap(tester, 'eingeladen-wartet');

      // Sicht der Moderatorin: Anfrage mit Namen.
      await tester.pumpWidget(const SizedBox());
      await _start(tester, anna);
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Familie')));
      await _snap(tester, 'moderatorin-anfrage');
      await anna.gateway.approveRequest(guest.gateway.userId!);
      expect(anna.gateway.family!.member(guest.gateway.userId!)!.status, MemberStatus.invited);
    });

    testWidgets('Weg B ohne Link und Weg C (Anmelden, Gerät freischalten)', (tester) async {
      final first = await buildTestApp();
      final app = await buildTestApp(loggedIn: false, server: first.server);
      await _start(tester, app);
      await _tap(tester, 'Ich wurde eingeladen');
      await _snap(tester, 'eingeladen-link-einfuegen');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _tap(tester, 'Ich habe schon ein Konto');
      await _snap(tester, 'anmelden');
      await _type(tester, 'Benutzername', 'anna');
      await _type(tester, 'Passwort', 'geheim123');
      await _tap(tester, 'Anmelden');
      await _snap(tester, 'geraet-freischalten');
    });

    testWidgets('Anbieter mit Browser-Anmeldung (wie matrix.org) und englische Startseite', (tester) async {
      final server = FakeMatrixServer()..registrationMode = RegistrationMode.oauth;
      final app = await buildTestApp(loggedIn: false, server: server);
      await _start(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _type(tester, 'Wie heißt du?', 'Greta');
      await _snap(tester, 'oauth-konto-erstellen');
      await _tap(tester, 'Konto bei fake.test erstellen', settle: false);
      await _snap(tester, 'oauth-wartet-auf-browser', settle: false);
      app.oauth.cancel();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await _snap(tester, 'start-englisch');
    });
  });
}
