import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser.dart';
import '../support/fake_matrix.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openDeletion(WidgetTester tester) async {
  await openSettings(tester);
  await tester.ensureVisible(find.text('Konto löschen'));
  await tester.tap(find.text('Konto löschen'));
  await tester.pumpAndSettle();
}

/// Anna meldet sich im Browser an (OAuth) und hat ihre Familie eingerichtet.
Future<TestApp> _oauthApp() async {
  final fake = FakeMatrixServer()..registrationMode = RegistrationMode.oauth;
  fake.addAccount('anna', 'oauth-only', displayName: 'Anna');
  final app = await buildTestApp(server: fake, loggedIn: false);
  await app.gateway.startOAuth(server: ServerUrl.tryParse(fake.host)!, redirectUri: FakeOAuthRedirect.redirect, create: false);
  await app.gateway.completeOAuth(app.gateway.oauthCallback('anna'));
  await app.gateway.setUpSecurity();
  await app.gateway.createFamily('Familie Test');
  await app.services.settings.update((s) => s.copyWith(onboardingDone: true));
  return app;
}

void main() {
  testWidgets('Konto löschen mit Passwort: falsches Passwort scheitert, danach Konto gelöscht und lokale Daten entfernt', (tester) async {
    _tallView(tester);
    final app = await buildTestApp(lang: 'de');
    var resets = 0;
    app.services.onFullReset = () async => resets++;
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _openDeletion(tester);

    expect(find.text('Konto löschen?'), findsOneWidget);
    expect(find.textContaining('@anna:fake.test wird bei fake.test dauerhaft gelöscht'), findsOneWidget);
    expect(find.textContaining('einzige Moderator'), findsNothing, reason: 'allein in der Familie: kein Hinweis');
    final confirm = find.widgetWithText(FilledButton, 'Konto endgültig löschen');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'ohne Passwort nicht auslösbar');

    await tester.enterText(find.byType(TextField), 'falsch');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Konto löschen?'), findsOneWidget, reason: 'Dialog bleibt offen');
    expect(find.text('Das Passwort stimmt nicht.'), findsOneWidget, reason: '#36: nur das Passwort ist gefragt');
    expect(find.text('Benutzername oder Passwort stimmen nicht.'), findsNothing);
    expect(app.server.deactivated, isEmpty);
    expect(app.services.accountDeletionPending, isFalse);
    expect(resets, 0);

    await tester.enterText(find.byType(TextField), 'geheim123');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(app.server.deactivated, <String>['@anna:fake.test']);
    expect(app.server.hasAccount('anna'), isFalse);
    expect(app.server.rooms.values.single.membership.containsKey('@anna:fake.test'), isFalse, reason: 'Familie verlassen');
    expect(app.gateway.session, SessionState.loggedOut);
    expect(resets, 1, reason: 'lokale Daten werden wie bei „Alle lokalen Daten löschen“ entfernt');
    expect(find.text('Konto löschen?'), findsNothing);
  });

  testWidgets('Konto löschen: Abbrechen löscht nichts', (tester) async {
    _tallView(tester);
    final app = await buildTestApp(lang: 'de');
    var resets = 0;
    app.services.onFullReset = () async => resets++;
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _openDeletion(tester);
    await tester.enterText(find.byType(TextField), 'geheim123');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(app.server.deactivated, isEmpty);
    expect(app.gateway.session, SessionState.ready);
    expect(app.services.accountDeletionPending, isFalse);
    expect(resets, 0);
  });

  testWidgets('einziger Moderator mit weiteren Mitgliedern: Hinweis, Löschung bleibt möglich', (tester) async {
    _tallView(tester);
    final app = await buildTestApp(lang: 'de');
    app.server.addMember(app.server.rooms.values.single, '@ben:fake.test');
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _openDeletion(tester);
    expect(find.textContaining('einzige Moderator'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Anmeldung im Browser: Löschseite des Anbieters, danach Prüfung und lokale Löschung', (tester) async {
    _tallView(tester);
    final app = await _oauthApp();
    var resets = 0;
    app.services.onFullReset = () async => resets++;
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _openDeletion(tester);

    expect(find.byType(TextField), findsNothing, reason: 'kein Passwort: gelöscht wird beim Anbieter');
    await expectLater(app.gateway.deleteAccount(password: 'oauth-only'), throwsA(isA<GatewayException>()));
    await tester.tap(find.text('Zur Löschseite'));
    await tester.pumpAndSettle();
    expect(app.browser.opened.single.toString(), 'https://fake.test/account?action=org.matrix.account_deactivate');
    expect(find.textContaining('kehre dann hierher zurück'), findsOneWidget);

    // Noch nicht beim Anbieter bestätigt.
    await tester.tap(find.text('Löschung prüfen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Das Konto besteht noch'), findsOneWidget);
    expect(app.gateway.session, SessionState.ready);
    expect(resets, 0);

    app.server.deactivateAccount('@anna:fake.test');
    await tester.tap(find.text('Löschung prüfen'));
    await tester.pumpAndSettle();
    expect(app.gateway.session, SessionState.loggedOut);
    expect(resets, 1);
  });

  testWidgets('Anmeldung im Browser ohne Kontoseite: Fehlermeldung statt Dialog', (tester) async {
    _tallView(tester);
    final app = await _oauthApp();
    app.server.accountManagementPage = null;
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _openDeletion(tester);
    expect(find.text('Konto löschen?'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Browser öffnet nicht: Hinweis, nichts vorgemerkt', (tester) async {
    _tallView(tester);
    final app = await _oauthApp();
    app.browser.available = false;
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await _openDeletion(tester);
    await tester.tap(find.text('Zur Löschseite'));
    await tester.pumpAndSettle();
    expect(find.text('Der Browser konnte nicht geöffnet werden.'), findsOneWidget);
    expect(app.services.accountDeletionPending, isFalse);
  });

  testWidgets('B-1: nach dem Zurücksetzen (neue Dienste) „Willkommen“ statt „Anmelden“ der alten Sitzung', (tester) async {
    _tallView(tester);
    final before = await buildTestApp(lang: 'de');
    await tester.pumpWidget(FamilyNexusApp(services: before.services));
    await tester.pumpAndSettle();
    // Konto gelöscht: Sitzung weg, die Einrichtung startet mit „Anmelden“ (Einstellungen noch vorhanden).
    await before.gateway.logout();
    await tester.pumpAndSettle();
    expect(find.text('Noch kein Konto? Jetzt erstellen'), findsOneWidget);

    // _fullReset baut die Dienste neu auf, ohne gespeicherte Einstellungen – wie nach einer Neuinstallation.
    final after = await buildTestApp(loggedIn: false, secureScreen: false);
    await tester.pumpWidget(FamilyNexusApp(services: after.services));
    await tester.pumpAndSettle();
    expect(find.text('Neue Familie gründen'), findsOneWidget, reason: 'Startseite statt des alten Anmeldeschritts');
    expect(find.text('Noch kein Konto? Jetzt erstellen'), findsNothing);
    expect(after.protection.last, isFalse, reason: 'Einstellungen der neuen Dienste gelten');
  });

  group('Löschseite aus den OAuth-Metadaten', () {
    Uri? page(Map<String, Object?> m) => SdkMatrixGateway.accountDeletionPage(m);

    test('mit Aktion „Konto löschen“', () {
      expect(
        page(<String, Object?>{
          'account_management_uri': 'https://account.matrix.org/account/',
          'account_management_actions_supported': <String>['org.matrix.profile', 'org.matrix.sessions_list', 'org.matrix.account_deactivate'],
        }).toString(),
        'https://account.matrix.org/account/?action=org.matrix.account_deactivate',
      );
    });

    test('ohne die Aktion: Kontoseite selbst', () {
      expect(
        page(<String, Object?>{
          'account_management_uri': 'https://id.example/manage?lang=de',
          'account_management_actions_supported': <String>['org.matrix.profile'],
        }).toString(),
        'https://id.example/manage?lang=de',
      );
    });

    test('nur https ohne Zugangsdaten', () {
      expect(page(<String, Object?>{'account_management_uri': 'http://id.example/'}), isNull);
      expect(page(<String, Object?>{'account_management_uri': 'https://user:pw@id.example/'}), isNull);
      expect(page(<String, Object?>{'account_management_uri': 42}), isNull);
      expect(page(<String, Object?>{}), isNull);
    });
  });
}
