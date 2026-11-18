import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/onboarding/provider_controller.dart';
import 'package:family_nexus/features/onboarding/provider_section.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/nav.dart';
import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

Future<void> _pump(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
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

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// Entprellung der Adressprüfung abwarten.
Future<void> _settleCheck(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

Finder get _addressField => find.widgetWithText(TextField, 'Adresse des Anbieters');

bool _customSelected(WidgetTester tester) => tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue!;

/// Fachbegriffe, die auf dem normalen Weg nicht erscheinen dürfen (TP-L10N-01).
void _expectNoJargon(WidgetTester tester) {
  final texts = <String>[
    for (final e in find.byType(Text).evaluate())
      if ((e.widget as Text).data != null) (e.widget as Text).data!
      else if ((e.widget as Text).textSpan != null) (e.widget as Text).textSpan!.toPlainText(),
  ];
  for (final t in texts) {
    expect(t.contains('Matrix'), isFalse, reason: '„$t“');
    expect(t.toLowerCase().contains('homeserver'), isFalse, reason: '„$t“');
  }
}

/// Anbieter, der nicht unterstützt wird (#545: Hinweis im Schritt ohne „Erweitert“).
class _UnsupportedGateway extends Fake implements MatrixGateway {
  @override
  Future<ServerInfo> probeServer(ServerUrl url) async => throw const GatewayException(GatewayError.serverUnsupported);

  @override
  Future<RegistrationOptions> registrationOptions(ServerUrl server) async =>
      throw const GatewayException(GatewayError.serverUnsupported);
}

void main() {
  group('Schritt „Anbieter wählen“ (E-108, #545)', () {
    testWidgets('Neue Familie: Schritt 1 von 4, empfohlener Anbieter vorgewählt (standard.host), Weiter → Konto erstellen',
        (tester) async {
      final app = await buildTestApp(loggedIn: false, defaultProvider: 'fake.test');
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      expect(find.text('Schritt 1 von 4'), findsOneWidget);
      expect(find.text('fake.test (empfohlen)'), findsOneWidget, reason: 'Standard aus defaultProvider, nicht fest verdrahtet');
      expect(_customSelected(tester), isFalse);
      expect(find.text('Anderer Anbieter oder eigener Server'), findsOneWidget);
      _expectNoJargon(tester);
      await continueFromServerStep(tester);
      expect(find.text('Schritt 2 von 4'), findsOneWidget);
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
    });

    testWidgets('Anmelden: derselbe Schritt, danach der Anmeldeschritt (Schritt 2 von 4)', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await _pump(tester, app);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      expect(find.text('Schritt 1 von 4'), findsOneWidget);
      await continueFromServerStep(tester);
      expect(find.text('Schritt 2 von 4'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Benutzername'), findsOneWidget);
    });

    testWidgets('Englisch: Titel, Karten und „Next“ ohne Fachbegriffe', (tester) async {
      final app = await buildTestApp(loggedIn: false, lang: 'en');
      await _pump(tester, app);
      await _tap(tester, 'Start a new family');
      expect(find.text('Choose a provider'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Another provider or your own server'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
      for (final e in find.byType(Text).evaluate()) {
        final d = (e.widget as Text).data ?? '';
        expect(d.contains('Matrix'), isFalse, reason: d);
        expect(d.toLowerCase().contains('homeserver'), isFalse, reason: d);
      }
    });

    testWidgets('Eigener Server: Adresse prüfen, Weiter, der Konto-Schritt nutzt diesen Server', (tester) async {
      final other = FakeMatrixServer(host: 'andere.test')..addAccount('anna', 'geheim123');
      final app = await buildTestApp(loggedIn: false, server: other, defaultProvider: 'andere.test');
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Anderer Anbieter oder eigener Server');
      expect(_customSelected(tester), isTrue);
      expect(_addressField, findsOneWidget);
      await tester.enterText(_addressField, 'andere.test');
      await _settleCheck(tester);
      expect(find.text('Dein Konto liegt bei andere.test.'), findsOneWidget);
      expect(find.text('Betreiber: andere.test'), findsOneWidget, reason: 'Betreiberangaben wie unter Erweitert');
      await continueFromServerStep(tester);
      expect(find.text('Dein Konto liegt bei andere.test.'), findsOneWidget);
      expect(find.text('Schritt 2 von 4'), findsOneWidget);
    });

    testWidgets('„Weiter“ bei leerer oder ungültiger Adresse: Grund am Feld, Fokus im Feld, kein Schrittwechsel; Enter wirkt wie Weiter',
        (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Anderer Anbieter oder eigener Server');
      await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('Anbieter wählen'), findsOneWidget, reason: 'kein Schrittwechsel');
      expect(tester.widget<TextField>(_addressField).decoration!.errorText, 'Bitte gib die Adresse des Anbieters ein.');
      expect(tester.widget<TextField>(_addressField).focusNode!.hasFocus, isTrue, reason: 'Fokus im Feld (wird mit dem Fehler vorgelesen)');
      await tester.enterText(_addressField, 'a b');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_addressField).decoration!.errorText, isNull, reason: 'Eingabe räumt den Fehler weg');
      await tester.testTextInput.receiveAction(TextInputAction.done); // Enter im Feld
      await tester.pumpAndSettle();
      expect(find.text('Anbieter wählen'), findsOneWidget);
      expect(tester.widget<TextField>(_addressField).decoration!.errorText, isNotNull, reason: 'Enter nennt den Grund wie „Weiter“');
    });

    testWidgets('„Weiter“ geht auch bei nicht erreichbarem Standard weiter (E-55-Abkürzung, TP-LOGIN-01)', (tester) async {
      final app = await buildTestApp(loggedIn: false, defaultProvider: 'unbekannt.example');
      await _pump(tester, app);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.textContaining('unbekannt.example ist gerade nicht erreichbar'), findsOneWidget);
      await continueFromServerStep(tester);
      expect(find.widgetWithText(TextField, 'Benutzername'), findsOneWidget);
    });

    testWidgets('Hinweis zu nicht unterstütztem Anbieter nennt im Schritt kein „Erweitert“', (tester) async {
      final controller = ProviderController(gateway: _UnsupportedGateway(), initial: ServerUrl.tryParse('x.test'))..start();
      addTearDown(controller.dispose);
      Widget host({required bool inStep}) => MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProviderStatusLine(controller: controller, inStep: inStep)),
          );
      await tester.pumpWidget(host(inStep: true));
      await tester.pumpAndSettle();
      expect(find.text('Dieser Anbieter wird von FamilyNexus nicht unterstützt. Bitte gib die Adresse eines anderen ein.'), findsOneWidget);
      expect(find.textContaining('Erweitert'), findsNothing);
      await tester.pumpWidget(host(inStep: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Erweitert'), findsOneWidget, reason: 'Konto/Anmelden: Text unverändert');
    });
  });

  group('Zählung und Zurück', () {
    testWidgets('Zurück: Konto → Anbieter (Auswahl und Adresse bleiben) → Startseite; neue Wegwahl beginnt wieder beim Standard', (tester) async {
      final other = FakeMatrixServer(host: 'andere.test');
      final app = await buildTestApp(loggedIn: false, server: other, defaultProvider: 'andere.test');
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      await _tap(tester, 'Anderer Anbieter oder eigener Server');
      await tester.enterText(_addressField, 'andere.test');
      await _settleCheck(tester);
      await continueFromServerStep(tester);
      await _back(tester);
      expect(find.text('Anbieter wählen'), findsOneWidget, reason: 'Zurück vom Konto führt zum Anbieter');
      expect(_customSelected(tester), isTrue);
      expect(tester.widget<TextField>(_addressField).controller!.text, 'andere.test', reason: 'Textfeld und Controller stimmen überein');
      await _back(tester);
      expect(find.text('Neue Familie gründen'), findsOneWidget);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      expect(_customSelected(tester), isFalse, reason: 'neue Wegwahl: wieder der Standard');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Abmelden im Notfall-Schlüssel-Schritt („Anderes Konto verwenden“): Merker aus, Schritt 1 von 3, Zurück → Startseite',
        (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await _pump(tester, app);
      await _tap(tester, 'Ich habe schon ein Konto');
      await continueFromServerStep(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Benutzername'), 'anna');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort'), 'geheim123');
      await tester.pumpAndSettle();
      await _tap(tester, 'Anmelden');
      expect(find.text('Schritt 3 von 4'), findsOneWidget);
      await _tap(tester, 'Anderes Konto verwenden');
      expect(find.widgetWithText(TextField, 'Benutzername'), findsOneWidget);
      expect(find.text('Schritt 1 von 3'), findsOneWidget, reason: 'ohne Anbieter-Schritt wie bei Abmeldung/Neustart');
      await _back(tester);
      expect(find.text('Neue Familie gründen'), findsOneWidget, reason: 'nicht zum Anbieter');
    });

    testWidgets('Abmeldung in einer neu gebauten Einrichtung (Neustart): weiter „Schritt 1 von 3“ ohne Anbieter-Schritt', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await app.services.settings.update((c) => c.copyWith(onboardingDone: true));
      await _pump(tester, app);
      expect(find.text('Schritt 1 von 3'), findsOneWidget);
      expect(find.text('Anbieter wählen'), findsNothing);
    });
  });

  group('Einladung', () {
    Future<({TestApp guest, TestApp anna, String link})> invited({String host = 'fake.test', bool matrixOrgDefault = false}) async {
      final server = FakeMatrixServer(host: host)..addAccount('anna', 'geheim123', displayName: 'Anna');
      final anna = await buildTestApp(server: server);
      server.now = () => DateTime.now().toUtc();
      final link = await anna.gateway.createInviteLink();
      final guest = await buildTestApp(loggedIn: false, server: server, matrixOrgDefault: matrixOrgDefault);
      return (guest: guest, anna: anna, link: link);
    }

    testWidgets('Einladung beim Start: kein Anbieter-Schritt, „Schritt 1 von 3“', (tester) async {
      final s = await invited();
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);
      expect(find.text('Anbieter wählen'), findsNothing);
      expect(find.text('Schritt 1 von 3'), findsOneWidget);
    });

    testWidgets('Einladung kommt im Anbieter-Schritt auf dem Weg „Konto“ an: Konto erstellen beim Server aus der Einladung', (tester) async {
      final s = await invited();
      await _pump(tester, s.guest);
      await _tap(tester, 'Neue Familie gründen');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      s.guest.links.controller.add(s.link);
      await tester.pumpAndSettle();
      expect(find.text('Anbieter wählen'), findsNothing);
      expect(find.text('Schritt 1 von 3'), findsOneWidget, reason: 'Merker aus');
      expect(find.text('Dein Konto liegt bei fake.test.'), findsOneWidget);
    });

    testWidgets('Einladung kommt im Anbieter-Schritt auf dem Weg „Anmelden“ an: Anmeldeschritt mit Server aus der Einladung', (tester) async {
      final s = await invited();
      await _pump(tester, s.guest);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      s.guest.links.controller.add(s.link);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Benutzername'), findsOneWidget, reason: 'bleibt bei der Anmeldung, nicht Kontoanlage');
      expect(find.text('Schritt 1 von 3'), findsOneWidget);
    });

    testWidgets('Einladung kommt im Anmeldeschritt (nach dem Anbieter-Schritt) an: Merker aus, Zurück → Startseite, Link verworfen',
        (tester) async {
      final s = await invited();
      await _pump(tester, s.guest);
      await _tap(tester, 'Ich habe schon ein Konto');
      await continueFromServerStep(tester);
      s.guest.links.controller.add(s.link);
      await tester.pumpAndSettle();
      expect(find.text('Schritt 1 von 3'), findsOneWidget, reason: 'Merker aus, Anbieter-Schritt zählt nicht mehr');
      await _back(tester);
      expect(find.text('Neue Familie gründen'), findsOneWidget, reason: 'nicht zum Anbieter-Schritt, der den Einladungs-Server überschriebe');
      expect(s.guest.services.pendingInvite.value, isNull);
    });

    testWidgets('Verworfene Einladung (öffentlicher Server): neue Wegwahl beginnt beim Standard, genau eine Prüfung', (tester) async {
      final s = await invited();
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);
      await _back(tester); // Konto → Startseite, Einladung verworfen
      final before = s.guest.gateway.probeCalls;
      await _tap(tester, 'Neue Familie gründen');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      expect(_customSelected(tester), isFalse);
      expect(s.guest.gateway.probeCalls - before, 1, reason: 'Standard genau einmal geprüft');
    });

    testWidgets('Verworfene Einladung mit Heimnetz-Server: nach neuer Wegwahl wird nur der Standard geprüft, nie der Heimnetz-Server (R2)',
        (tester) async {
      final s = await invited(host: 'nas', matrixOrgDefault: true);
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);
      expect(find.textContaining('Server im Heimnetz (nas)'), findsOneWidget, reason: 'wartet auf Zustimmung');
      expect(s.guest.gateway.probedHosts, isEmpty);
      await _back(tester);
      await _tap(tester, 'Ich habe schon ein Konto');
      expect(find.text('Anbieter wählen'), findsOneWidget);
      expect(_customSelected(tester), isFalse);
      expect(find.textContaining('Server im Heimnetz'), findsNothing);
      expect(s.guest.gateway.probedHosts, <String>['matrix.org'], reason: 'genau eine Prüfung, nur der Standard');
    });

    testWidgets('Verworfene Einladung, dann „Ich wurde eingeladen“ ohne Link: Standard, keine Prüfung des alten Servers', (tester) async {
      final s = await invited(host: 'nas', matrixOrgDefault: true);
      s.guest.links.initial = s.link;
      await _pump(tester, s.guest);
      await _back(tester);
      await _tap(tester, 'Ich wurde eingeladen');
      expect(find.text('Anbieter wählen'), findsNothing, reason: 'der eingeladene Weg hat keinen Anbieter-Schritt');
      expect(s.guest.gateway.probedHosts, <String>['matrix.org'], reason: 'nur der Standard, nie „nas“');
    });
  });

  group('Barrierefreiheit', () {
    testWidgets('große Schrift: Karten und Knopf bleiben ohne Überlauf erreichbar', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await _pump(tester, app);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _tap(tester, 'Neue Familie gründen');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Anderer Anbieter oder eigener Server');
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(FilledButton, 'Weiter'), findsOneWidget);
    });

    testWidgets('Auswahl als Radiogruppe mit zwei Karten, die Adresse trägt ein Beschriftungs- und Fehlerfeld', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await _pump(tester, app);
      await _tap(tester, 'Neue Familie gründen');
      expect(find.byType(RadioListTile<bool>), findsNWidgets(2));
      final handle = tester.ensureSemantics();
      final snap = semanticsSnapshot(tester, find.byType(RadioGroup<bool>));
      final otherAt = snap.indexWhere((s) => s.contains('Anderer Anbieter oder eigener Server'));
      expect(otherAt, greaterThan(0), reason: '$snap');
      expect(snap.sublist(0, otherAt).any((s) => s.contains('checked')), isTrue, reason: 'der Standard ist vorgewählt: $snap');
      expect(snap.sublist(otherAt).any((s) => s.contains('checked')), isFalse, reason: 'die zweite Karte ist nicht gewählt: $snap');
      handle.dispose();
    });
  });
}
