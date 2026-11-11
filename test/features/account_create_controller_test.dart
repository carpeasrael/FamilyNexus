import 'dart:async';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/onboarding/account_create_controller.dart';
import 'package:family_nexus/features/onboarding/provider_controller.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';

/// AP-6a: Zustand und Aktionen von „Konto erstellen“, ohne Widget (Controller nach dem Muster `CalendarController`).
final AppLocalizationsDe _de = AppLocalizationsDe();
const Duration _wait = Duration(milliseconds: 30);

class _Setup {
  _Setup(this.server, this.gateway, this.provider);
  final FakeMatrixServer server;
  final FakeMatrixGateway gateway;
  final ProviderController provider;
  final List<ServerUrl> signedIn = <ServerUrl>[];
  final List<AccountField> focused = <AccountField>[];
  int browserCancels = 0;
  bool elementInstalled = true;
  Object? signInError;
  Completer<void>? signInGate;
  late AccountCreateController c;
}

Future<_Setup> _setup() async {
  final server = FakeMatrixServer()..addAccount('anna', 'geheim123', displayName: 'Anna');
  final gateway = server.newDevice();
  final provider = ProviderController(gateway: gateway, initial: ServerUrl.tryParse(server.host));
  final s = _Setup(server, gateway, provider);
  s.c = AccountCreateController(
    gateway: gateway,
    provider: provider,
    signInInBrowser: (url) async {
      s.signedIn.add(url);
      await s.signInGate?.future;
      final e = s.signInError;
      if (e != null) throw e;
    },
    cancelBrowserSignIn: () => s.browserCancels++,
    launchElement: () async => s.elementInstalled,
    requestFocus: s.focused.add,
    checkDelay: Duration.zero,
  );
  addTearDown(provider.dispose);
  provider.start();
  while (!provider.ready) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return s;
}

void _fill(_Setup s, {String name = 'Emil', String? user, String password = 'sicher-genug', String? repeat}) {
  s.c.name.text = name;
  s.c.onName(name);
  if (user != null) {
    s.c.user.text = user;
    s.c.onUser(user);
  }
  s.c.password.text = password;
  s.c.passwordRepeat.text = repeat ?? password;
}

Future<void> _settled() => Future<void>.delayed(_wait);

void main() {
  group('Formular', () {
    test('Anfang: leer, nichts geprüft, nicht absendbar', () async {
      final s = await _setup();
      expect((s.c.busy, s.c.check, s.c.suggestion, s.c.stage, s.c.showPassword, s.c.waitingForBrowser, s.c.elementMissing), (false, null, null, null, false, false, false));
      expect(s.c.formOk, isFalse);
      expect(s.c.errorLine(_de), isNull);
      s.c.dispose();
    });

    test('formOk braucht Name, gültigen freien Benutzernamen und zwei gleiche Passwörter ab 8 Zeichen', () async {
      final s = await _setup();
      _fill(s);
      await _settled();
      expect(s.c.check, UsernameCheck.available);
      expect(s.c.formOk, isTrue);
      s.c.passwordRepeat.text = 'anders-genug';
      expect(s.c.formOk, isFalse, reason: 'Wiederholung weicht ab');
      s.c.passwordRepeat.text = 'kurz';
      s.c.password.text = 'kurz';
      expect(s.c.formOk, isFalse, reason: 'unter 8 Zeichen');
      s.c.password.text = 'sicher-genug';
      s.c.passwordRepeat.text = 'sicher-genug';
      s.c.name.text = '  ';
      expect(s.c.formOk, isFalse, reason: 'Name leer');
      s.c.dispose();
    });

    test('Name füllt den Benutzernamen vor, bis dieser selbst geändert wird', () async {
      final s = await _setup();
      s.c.name.text = 'Emil Schmidt';
      s.c.onName('Emil Schmidt');
      expect(s.c.user.text, isNotEmpty);
      final suggested = s.c.user.text;
      s.c.user.text = 'eigener';
      s.c.onUser('eigener');
      s.c.name.text = 'Anderer Name';
      s.c.onName('Anderer Name');
      expect(s.c.user.text, 'eigener', reason: 'selbst gewählter Name bleibt');
      expect(suggested, isNot('eigener'));
      s.c.dispose();
    });

    test('toggleShowPassword und clearInputError melden Änderungen', () async {
      final s = await _setup();
      var n = 0;
      s.c.addListener(() => n++);
      s.c.toggleShowPassword();
      expect((s.c.showPassword, n), (true, 1));
      s.c.clearInputError();
      expect(n, 2);
      s.c.dispose();
    });
  });

  group('Prüfung des Benutzernamens', () {
    test('frei: available, kein Vorschlag', () async {
      final s = await _setup();
      s.c.user.text = 'emil';
      s.c.onUser('emil');
      await _settled();
      expect((s.c.check, s.c.suggestion), (UsernameCheck.available, null));
      s.c.dispose();
    });

    test('vergeben: taken mit freiem Vorschlag, der sich übernehmen lässt', () async {
      final s = await _setup();
      s.c.user.text = 'anna';
      s.c.onUser('anna');
      await _settled();
      expect(s.c.check, UsernameCheck.taken);
      final suggestion = s.c.suggestion;
      expect(suggestion, isNotNull);
      s.c.useSuggestion();
      expect(s.c.user.text, suggestion);
      await _settled();
      expect(s.c.check, UsernameCheck.available);
      s.c.dispose();
    });

    test('übernommener Vorschlag zählt als selbst gewählt: eine spätere Namensänderung überschreibt ihn nicht', () async {
      final s = await _setup();
      s.c.name.text = 'Anna';
      s.c.onName('Anna'); // der Benutzername kommt aus dem Namen, nicht von Hand
      await _settled();
      expect(s.c.user.text, 'anna');
      final suggestion = s.c.suggestion!;
      s.c.useSuggestion();
      s.c.name.text = 'Ganz Anderer';
      s.c.onName('Ganz Anderer');
      expect(s.c.user.text, suggestion);
      s.c.dispose();
    });

    test('ungültig: sofort invalid, ohne Anfrage beim Server', () async {
      final s = await _setup();
      s.c.user.text = 'a';
      s.c.onUser('a');
      expect(s.c.check, UsernameCheck.invalid);
      s.c.dispose();
    });

    test('leer: Ergebnis wird zurückgesetzt', () async {
      final s = await _setup();
      s.c.user.text = 'emil';
      s.c.onUser('emil');
      await _settled();
      s.c.user.text = '';
      s.c.onUser('');
      expect((s.c.check, s.c.suggestion), (null, null));
      s.c.dispose();
    });

    test('veraltete Antwort wird verworfen: Das Ergebnis gehört zur letzten Eingabe', () async {
      final s = await _setup();
      s.c.user.text = 'anna';
      s.c.onUser('anna');
      s.c.user.text = 'emil';
      s.c.onUser('emil');
      await _settled();
      expect(s.c.check, UsernameCheck.available);
      s.c.dispose();
    });
  });

  group('Absenden verweigert', () {
    test('Name fehlt: Grund am Feld, Fokus dorthin, Serverfehler bleibt unberührt', () async {
      final s = await _setup();
      s.c.user.text = 'emil';
      s.c.password.text = 'sicher-genug';
      s.c.passwordRepeat.text = 'sicher-genug';
      s.c.submit(_de, 'de');
      expect(s.c.errorAt(AccountField.name), _de.regNameMissing);
      expect(s.c.errorLine(_de), _de.regNameMissing);
      expect(s.focused, <AccountField>[AccountField.name]);
      expect(s.c.busy, isFalse);
      s.c.dispose();
    });

    test('Reihenfolge der Gründe: ungültiger Name, zu kurzes Passwort, Wiederholung', () async {
      final s = await _setup();
      s.c.name.text = 'Emil';
      s.c.user.text = 'a';
      s.c.onUser('a');
      s.c.submit(_de, 'de');
      expect(s.c.errorAt(AccountField.user), _de.regUsernameInvalid);
      s.c.user.text = 'emil';
      s.c.onUser('emil');
      await _settled();
      s.c.password.text = 'kurz';
      s.c.passwordRepeat.text = 'kurz';
      s.c.submit(_de, 'de');
      expect(s.c.errorAt(AccountField.pass), _de.regPasswordTooShort);
      s.c.password.text = 'sicher-genug';
      s.c.passwordRepeat.text = 'etwas-anderes';
      s.c.submit(_de, 'de');
      expect(s.c.errorAt(AccountField.repeat), _de.regPasswordMismatch);
      expect(s.focused, <AccountField>[AccountField.user, AccountField.pass, AccountField.repeat]);
      s.c.dispose();
    });

    test('Name vergeben: Grund am Benutzernamen', () async {
      final s = await _setup();
      _fill(s, user: 'anna');
      await _settled();
      s.c.submit(_de, 'de');
      expect(s.c.errorAt(AccountField.user), _de.regUsernameTaken);
      s.c.dispose();
    });

    test('Eingabe löscht den Grund wieder', () async {
      final s = await _setup();
      s.c.submit(_de, 'de');
      expect(s.c.errorLine(_de), isNotNull);
      s.c.onUser('x');
      expect(s.c.errorLine(_de), isNull);
      s.c.dispose();
    });
  });

  group('Registrierung in der App', () {
    test('Erfolg: Konto angelegt, Passwörter geleert, kein Schritt, nicht beschäftigt', () async {
      final s = await _setup();
      _fill(s);
      await _settled();
      s.c.submit(_de, 'de');
      await _settled();
      expect(s.gateway.userId, '@emil:${s.server.host}');
      expect((s.c.password.text, s.c.passwordRepeat.text), ('', ''));
      expect((s.c.stage, s.c.busy, s.c.errorLine(_de)), (null, false, null));
      s.c.dispose();
    });

    test('Bedingungen: Schritt statt Konto, danach Zustimmung legt das Konto an', () async {
      final s = await _setup();
      s.server.registrationFlows = <List<String>>[
        <String>[RegistrationFlows.terms],
      ];
      _fill(s);
      await _settled();
      await s.c.register('de');
      expect(s.c.stage, isA<TermsStage>());
      expect(s.gateway.userId, isNull);
      expect(s.c.password.text, isNotEmpty, reason: 'Passwort bleibt für die Folgeschritte');
      await s.c.continueRegistration(const AcceptTerms());
      expect(s.gateway.userId, '@emil:${s.server.host}');
      expect((s.c.stage, s.c.password.text), (null, ''));
      s.c.dispose();
    });

    test('Fehler beim Absenden: Text in der Sprache der Oberfläche, nicht mehr beschäftigt', () async {
      final s = await _setup();
      _fill(s);
      await _settled();
      s.server.addAccount('emil', 'jemand-anderes'); // jemand war schneller
      await s.c.register('de');
      expect(s.c.errorLine(_de), _de.regUsernameTaken);
      expect(s.c.busy, isFalse);
      await _settled();
      expect(s.c.check, UsernameCheck.taken, reason: 'Der Server meldete „vergeben“: Prüfung wird neu angestoßen');
      s.c.dispose();
    });

    test('endgültiger Fehler in einem Folgeschritt: zurück zum Formular, Registrierung verworfen', () async {
      final s = await _setup();
      s.server.registrationFlows = <List<String>>[
        <String>[RegistrationFlows.terms],
      ];
      _fill(s);
      await _settled();
      await s.c.register('de');
      expect(s.c.stage, isA<TermsStage>());
      s.gateway.cancelRegistration(); // der Server hat die Sitzung vergessen: kein „vorübergehender“ Fehler
      await s.c.continueRegistration(const AcceptTerms());
      expect(s.c.stage, isNull);
      expect(s.c.errorLine(_de), isNotNull);
      s.c.dispose();
    });

    test('Eingabefehler im Folgeschritt: Schritt bleibt, Fehler wird gezeigt', () async {
      final s = await _setup();
      s.server.registrationFlows = <List<String>>[
        <String>[RegistrationFlows.email],
      ];
      _fill(s);
      await _settled();
      await s.c.register('de');
      expect(s.c.stage, isA<EmailStage>());
      await s.c.continueRegistration(const SubmitEmail('keine-adresse'));
      expect(s.c.stage, isA<EmailStage>(), reason: 'ungültige Eingabe ist vorübergehend: der Schritt bleibt');
      expect(s.c.errorLine(_de), isNotNull);
      s.c.dispose();
    });

    test('cancelStage: Schritt und Fehler weg', () async {
      final s = await _setup();
      s.server.registrationFlows = <List<String>>[
        <String>[RegistrationFlows.terms],
      ];
      _fill(s);
      await _settled();
      await s.c.register('de');
      expect(s.c.stage, isNotNull);
      s.c.cancelStage();
      expect((s.c.stage, s.c.errorLine(_de)), (null, null));
      s.c.dispose();
    });

    test('doppeltes Absenden während der Anlage wird ignoriert', () async {
      final s = await _setup();
      _fill(s);
      await _settled();
      s.server.registerGate = Completer<void>();
      s.c.submit(_de, 'de');
      s.c.submit(_de, 'de');
      expect(s.c.busy, isTrue);
      expect(s.server.registerCalls, 1);
      s.server.registerGate!.complete();
      await _settled();
      s.c.dispose();
    });
  });

  group('Anlage beim Anbieter (OAuth)', () {
    test('Erfolg: Browser-Anmeldung mit dem Server, danach Anzeigename gesetzt', () async {
      final s = await _setup();
      s.c.name.text = '  Emil  ';
      final seen = <bool>[];
      s.c.addListener(() => seen.add(s.c.waitingForBrowser));
      // Das Fake-Gateway setzt den Namen nur mit Sitzung: angemeldet wie nach dem Rücksprung.
      await s.gateway.login(server: ServerUrl.tryParse(s.server.host)!, username: 'anna', password: 'geheim123');
      await s.c.createInBrowser();
      expect(s.signedIn.single.host, s.server.host);
      expect(seen, contains(true));
      expect((s.c.waitingForBrowser, s.c.busy, s.c.errorLine(_de)), (false, false, null));
      s.c.dispose();
    });

    test('Fehler im Browser: Meldung, Wartezustand beendet', () async {
      final s = await _setup();
      s.signInError = const GatewayException(GatewayError.oauthCancelled);
      await s.c.createInBrowser();
      expect(s.c.errorLine(_de), isNotNull);
      expect((s.c.waitingForBrowser, s.c.busy), (false, false));
      s.c.dispose();
    });

    test('Anzeigename scheitert: kein Abbruch, kein Fehler', () async {
      final s = await _setup();
      s.c.name.text = 'Emil'; // ohne Sitzung wirft setDisplayName
      await s.c.createInBrowser();
      expect(s.c.errorLine(_de), isNull);
      s.c.dispose();
    });

    test('dispose während des Wartens bricht die Browser-Anmeldung ab', () async {
      final s = await _setup();
      s.signInGate = Completer<void>();
      final running = s.c.createInBrowser();
      await Future<void>.delayed(Duration.zero);
      expect(s.c.waitingForBrowser, isTrue);
      s.c.dispose();
      expect(s.browserCancels, 1);
      s.signInGate!.complete();
      await running;
    });
  });

  group('Element und Lebensdauer', () {
    test('Element fehlt: Hinweis; installiert: Hinweis weg', () async {
      final s = await _setup();
      s.elementInstalled = false;
      await s.c.openElement();
      expect(s.c.elementMissing, isTrue);
      s.elementInstalled = true;
      await s.c.openElement();
      expect(s.c.elementMissing, isFalse);
      s.c.dispose();
    });

    test('dispose verwirft die Registrierung am Gateway und ohne Warten keinen Browser-Abbruch', () async {
      final s = await _setup();
      s.server.registrationFlows = <List<String>>[
        <String>[RegistrationFlows.terms],
      ];
      _fill(s);
      await _settled();
      await s.c.register('de');
      expect(s.c.stage, isNotNull);
      s.c.dispose();
      expect(s.browserCancels, 0);
      expect(
        () => s.gateway.continueRegistration(const AcceptTerms()),
        throwsA(isA<GatewayException>()),
        reason: 'die Registrierung ist beendet, kein Schritt mehr offen',
      );
    });

    test('eine Aktion über dispose hinweg meldet nichts mehr (sonst würfe ChangeNotifier)', () async {
      final s = await _setup();
      _fill(s);
      await _settled();
      s.server.registerGate = Completer<void>();
      final running = s.c.register('de');
      s.c.dispose();
      s.server.registerGate!.complete();
      await running;
    });
  });
}
