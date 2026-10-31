// Echte Kontoanlage-Logik des SdkMatrixGateway (UIA-Schleife, OAuth-Rücksprung) gegen nachgestellte
// Serverantworten (Review R7). Erfolgreiche Anmeldungen (mit Krypto-Initialisierung) prüfen die
// E2E-Tests; hier geht es um Abläufe, Weitergabe von Sitzung/Schritten, Prüfungen und Fehlerzuordnung.
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/background_image_work.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/password_change.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show MatrixException;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../support/memory_stores.dart';

typedef _Handler = (int, Object) Function(http.Request req, Map<String, Object?> body);

/// Nachgestellter Homeserver `https://hs.example`; [register] und [token] liefern die Antworten.
class _Server {
  _Server({this.version = 'v1.11', this.meta});

  final String version;
  final Map<String, Object?>? meta;
  _Handler? register;
  _Handler? token;
  _Handler? login;

  /// Antwort auf `POST /account/password`; [passwordBodies] sammelt die Anfragen.
  _Handler? password;
  final List<Map<String, Object?>> passwordBodies = <Map<String, Object?>>[];

  /// Antwort auf alle übrigen Anfragen nach der Anmeldung (z. B. Fehler bei Folgeschritten).
  _Handler? afterLogin;
  bool loggedIn = false;
  final List<Map<String, Object?>> registerBodies = <Map<String, Object?>>[];
  final List<Map<String, String>> tokenBodies = <Map<String, String>>[];
  int oidcRegistrations = 0;

  http.Client get client => MockClient((req) async {
        final path = req.url.path;
        Map<String, Object?> jsonBody() =>
            req.body.isEmpty ? <String, Object?>{} : json.decode(req.body) as Map<String, Object?>;
        (int, Object) r;
        if (path == '/_matrix/client/versions') {
          r = (200, <String, Object?>{'versions': <String>['v1.1', version]});
        } else if (path == '/_matrix/client/v3/login' && req.method == 'POST' && login != null) {
          r = login!(req, jsonBody());
          loggedIn = r.$1 == 200;
        } else if (path == '/_matrix/client/v3/account/password' && password != null) {
          final b = jsonBody();
          passwordBodies.add(b);
          r = password!(req, b);
        } else if (afterLogin != null && loggedIn && !path.startsWith('/_matrix/client/v3/login')) {
          r = afterLogin!(req, const <String, Object?>{});
        } else if (path == '/_matrix/client/v3/login') {
          r = (200, <String, Object?>{'flows': <Object?>[<String, Object?>{'type': 'm.login.password'}]});
        } else if (path == '/_matrix/client/v1/auth_metadata' && meta != null) {
          r = (200, meta!);
        } else if (path == '/_matrix/client/v3/register' && req.method == 'POST' && register != null) {
          final b = jsonBody();
          registerBodies.add(b);
          r = register!(req, b);
        } else if (path == '/oauth2/registration') {
          oidcRegistrations++;
          r = (201, <String, Object?>{'client_id': 'cid', 'client_uri': 'https://carpeasrael.github.io/FamilyNexus/'});
        } else if (path == '/oauth2/token' && token != null) {
          tokenBodies.add(Uri.splitQueryString(req.body));
          r = token!(req, const <String, Object?>{});
        } else {
          r = (404, <String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'});
        }
        return http.Response(r.$2 is String ? r.$2 as String : json.encode(r.$2), r.$1, headers: <String, String>{'content-type': 'application/json'});
      });
}

final ServerUrl _hs = ServerUrl.tryParse('hs.example')!;

Map<String, Object?> _uia(List<List<String>> flows, {List<String> completed = const <String>[], Map<String, Object?>? params, String? errcode}) =>
    <String, Object?>{
      'session': 'S1',
      'flows': <Object?>[for (final f in flows) <String, Object?>{'stages': f}],
      'completed': completed,
      'params': params ?? <String, Object?>{},
      'errcode': ?errcode,
    };

Future<SdkMatrixGateway> _gateway(_Server server) async {
  final dir = await Directory.systemTemp.createTemp('fn_reg');
  addTearDown(() => dir.delete(recursive: true));
  final g = SdkMatrixGateway(
    keyStore: MemoryKeyStore(),
    dbDirectory: dir.path,
    probe: ServerProbe(client: server.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    httpClient: server.client,
  );
  addTearDown(g.close);
  return g;
}

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

const Map<String, Object?> _meta = <String, Object?>{
  'issuer': 'https://hs.example/',
  'authorization_endpoint': 'https://hs.example/authorize',
  'token_endpoint': 'https://hs.example/oauth2/token',
  'registration_endpoint': 'https://hs.example/oauth2/registration',
  'revocation_endpoint': 'https://hs.example/oauth2/revoke',
  'response_types_supported': <String>['code'],
  'response_modes_supported': <String>['query', 'fragment'],
  'grant_types_supported': <String>['authorization_code', 'refresh_token'],
  'code_challenge_methods_supported': <String>['S256'],
  'prompt_values_supported': <String>['create'],
};

/// PKCE nutzt im SDK vodozemac; die Bibliothek baut `tool/e2e.sh` (ohne sie wird die OAuth-Gruppe übersprungen).
final String _vodLib = Platform.environment['FN_VOD_LIB'] ?? '/tmp/vod-target/release/';
final bool _vodAvailable = Directory(_vodLib).existsSync() &&
    Directory(_vodLib).listSync().any((f) => f.path.contains('vodozemac_bindings_dart'));

void main() {
  setUpAll(sqfliteFfiInit);

  test('#129: der Client verkleinert Bilder im Hintergrund', () async {
    final g = await _gateway(_Server());
    await g.restore().catchError((Object _) {});
    expect(g.sdkClient!.customImageResizer, same(resizeImageInBackground));
  });

  group('#28: Anmeldung gelingt, ein Folgeschritt scheitert', () {
    test('kein „Unbekannter Fehler.“: die Sitzung steht', () async {
      final s = _Server();
      s.login = (req, b) => (200, <String, Object?>{'user_id': '@n2:hs.example', 'access_token': 'tok', 'device_id': 'DEV1'});
      s.afterLogin = (req, b) => (500, <String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'kaputt'});
      final g = await _gateway(s);
      await g.login(server: _hs, username: 'n2', password: 'geheim123');
      expect(g.session, SessionState.ready);
      expect(g.userId, '@n2:hs.example');
    });

    test('falsches Passwort bleibt ein Fehler', () async {
      final s = _Server();
      s.login = (req, b) => (403, <String, Object?>{'errcode': 'M_FORBIDDEN', 'error': 'Invalid password'});
      final g = await _gateway(s);
      await expectLater(g.login(server: _hs, username: 'n2', password: 'falsch123'), _error(GatewayError.invalidCredentials));
      expect(g.session, SessionState.loggedOut);
    });
  });

  group('Passwort ändern (SdkMatrixGateway, #117)', () {
    Future<(_Server, SdkMatrixGateway)> signedIn() async {
      final s = _Server();
      s.login = (req, b) => (200, <String, Object?>{'user_id': '@n2:hs.example', 'access_token': 'tok', 'device_id': 'DEV1'});
      s.afterLogin = (req, b) => (200, <String, Object?>{});
      final g = await _gateway(s);
      await g.login(server: _hs, username: 'n2', password: 'geheim123');
      return (s, g);
    }

    Future<void> change(SdkMatrixGateway g, {bool logoutOthers = false}) =>
        g.changePassword(oldPassword: 'geheim123', newPassword: 'neu-und-lang', logoutOtherDevices: logoutOthers);

    final passwordFlow = <List<String>>[<String>['m.login.password']];

    test('TP-PW-20 erster Aufruf ohne altes Passwort, Wiederholung mit Sitzung; logout_devices jedes Mal', () async {
      final (s, g) = await signedIn();
      s.password = (req, b) => b['auth'] == null ? (401, _uia(passwordFlow)) : (200, <String, Object?>{});
      await change(g, logoutOthers: true);
      expect(s.passwordBodies, hasLength(2));
      expect(s.passwordBodies[0].containsKey('auth'), isFalse, reason: 'altes Passwort geht nur an die Passwort-Stufe');
      expect(json.encode(s.passwordBodies[0]).contains('geheim123'), isFalse);
      expect(s.passwordBodies[0]['logout_devices'], true);
      expect(s.passwordBodies[1]['logout_devices'], true);
      expect(s.passwordBodies[1]['new_password'], 'neu-und-lang');
      final auth = s.passwordBodies[1]['auth']! as Map<String, Object?>;
      expect(auth['type'], 'm.login.password');
      expect(auth['session'], 'S1');
      expect(auth['password'], 'geheim123');
      expect(auth['identifier'], <String, Object?>{'type': 'm.id.user', 'user': '@n2:hs.example'});
    });

    test('TP-PW-20b `logout_devices: false` wird ausdrücklich gesendet', () async {
      final (s, g) = await signedIn();
      s.password = (req, b) => b['auth'] == null ? (401, _uia(passwordFlow)) : (200, <String, Object?>{});
      await change(g);
      expect(s.passwordBodies.map((b) => b['logout_devices']), <Object?>[false, false]);
    });

    test('TP-PW-20c mehrere Flows: der reine Passwort-Flow reicht', () async {
      final (s, g) = await signedIn();
      s.password = (req, b) => b['auth'] == null
          ? (401, _uia(<List<String>>[<String>['m.login.sso'], <String>['m.login.password']]))
          : (200, <String, Object?>{});
      await change(g);
      expect(s.passwordBodies, hasLength(2));
    });

    test('TP-PW-21 Prüfungen vor jeder Anfrage', () async {
      final (s, g) = await signedIn();
      await expectLater(g.changePassword(oldPassword: 'geheim123', newPassword: 'kurz', logoutOtherDevices: false), _error(GatewayError.weakPassword));
      await expectLater(g.changePassword(oldPassword: '', newPassword: 'neu-und-lang', logoutOtherDevices: false), _error(GatewayError.invalidInput));
      await expectLater(g.changePassword(oldPassword: 'a' * 1025, newPassword: 'neu-und-lang', logoutOtherDevices: false), _error(GatewayError.invalidInput));
      await expectLater(g.changePassword(oldPassword: 'geheim123', newPassword: 'a' * 513, logoutOtherDevices: false), _error(GatewayError.invalidInput));
      expect(s.passwordBodies, isEmpty);
      s.password = (req, b) => (200, <String, Object?>{});
      await g.changePassword(oldPassword: 'geheim123', newPassword: 'a' * 512, logoutOtherDevices: false);
      expect(s.passwordBodies, hasLength(1));
    });

    test('TP-PW-21b nicht angemeldet: keine Anfrage', () async {
      final s = _Server();
      final g = await _gateway(s);
      await expectLater(change(g), _error(GatewayError.notAllowed));
      await expectLater(g.passwordChange(), _error(GatewayError.notAllowed));
    });

    test('TP-PW-22 klassische Anmeldung: Änderung in der App', () async {
      final (_, g) = await signedIn();
      expect(await g.passwordChange(), isA<PasswordChangeInApp>());
    });

    // Antworten des ersten Aufrufs: (Name, Status, Körper, erwarteter Fehler).
    final first = <(String, int, Object, GatewayError)>[
      ('flows: []', 401, _uia(<List<String>>[]), GatewayError.passwordChangeUnavailable),
      ('nur SSO', 401, _uia(<List<String>>[<String>['m.login.sso']]), GatewayError.passwordChangeUnavailable),
      ('Passwort + E-Mail', 401, _uia(<List<String>>[<String>['m.login.password', 'm.login.email.identity']]), GatewayError.passwordChangeUnavailable),
      (
        'Passwort-Flow ohne Session',
        401,
        <String, Object?>{'flows': <Object?>[<String, Object?>{'stages': <String>['m.login.password']}]},
        GatewayError.passwordChangeUnavailable,
      ),
      ('M_FORBIDDEN ohne Flows (abgeschaltet)', 403, <String, Object?>{'errcode': 'M_FORBIDDEN'}, GatewayError.passwordChangeUnavailable),
      ('M_USER_LOCKED', 401, <String, Object?>{'errcode': 'M_USER_LOCKED'}, GatewayError.notAllowed),
      ('M_USER_SUSPENDED', 403, <String, Object?>{'errcode': 'M_USER_SUSPENDED'}, GatewayError.notAllowed),
      ('M_USER_DEACTIVATED', 403, <String, Object?>{'errcode': 'M_USER_DEACTIVATED'}, GatewayError.notAllowed),
      ('M_UNRECOGNIZED', 404, <String, Object?>{'errcode': 'M_UNRECOGNIZED'}, GatewayError.passwordChangeUnavailable),
      ('M_LIMIT_EXCEEDED', 429, <String, Object?>{'errcode': 'M_LIMIT_EXCEEDED'}, GatewayError.rateLimited),
      ('M_WEAK_PASSWORD', 400, <String, Object?>{'errcode': 'M_WEAK_PASSWORD'}, GatewayError.weakPassword),
      ('M_PASSWORD_NO_DIGIT', 400, <String, Object?>{'errcode': 'M_PASSWORD_NO_DIGIT'}, GatewayError.weakPassword),
      ('Körper ohne errcode', 500, <String, Object?>{'error': 'kaputt'}, GatewayError.unknown),
      ('kein JSON', 502, '<html>Bad Gateway</html>', GatewayError.unknown),
    ];
    for (final (name, status, body, expected) in first) {
      test('TP-PW-23 erster Aufruf: $name → ${expected.name}', () async {
        final (s, g) = await signedIn();
        s.password = (req, b) => (status, body);
        await expectLater(change(g), _error(expected));
        expect(s.passwordBodies, hasLength(1), reason: 'keine Wiederholung, altes Passwort bleibt beim Gerät');
      });
    }

    // Antworten auf die Wiederholung mit Passwort.
    final second = <(String, int, Object, GatewayError)>[
      ('falsches Passwort (M_FORBIDDEN mit Flows)', 401, _uia(<List<String>>[<String>['m.login.password']], errcode: 'M_FORBIDDEN'), GatewayError.invalidCredentials),
      ('M_UNAUTHORIZED mit Flows', 401, _uia(<List<String>>[<String>['m.login.password']], errcode: 'M_UNAUTHORIZED'), GatewayError.invalidCredentials),
      ('Flows ohne errcode', 401, _uia(<List<String>>[<String>['m.login.password']]), GatewayError.unknown),
      ('abgeschaltet nach richtigem Passwort', 403, <String, Object?>{'errcode': 'M_FORBIDDEN'}, GatewayError.passwordChangeUnavailable),
      ('M_LIMIT_EXCEEDED', 429, <String, Object?>{'errcode': 'M_LIMIT_EXCEEDED'}, GatewayError.rateLimited),
    ];
    for (final (name, status, body, expected) in second) {
      test('TP-PW-24 Wiederholung: $name → ${expected.name}', () async {
        final (s, g) = await signedIn();
        s.password = (req, b) => b['auth'] == null ? (401, _uia(passwordFlow)) : (status, body);
        await expectLater(change(g), _error(expected));
        expect(s.passwordBodies, hasLength(2));
      });
    }

    test('TP-PW-25 Zuordnung: Nur das rohe errcode zählt, `M_PASSWORD*` nur als Zeichenkette', () {
      GatewayError? of(Map<String, Object?> raw) => SdkMatrixGateway.passwordChangeError(MatrixException.fromJson(raw))?.error;
      final flow = <Object?>[<String, Object?>{'stages': <String>['m.login.password']}];
      expect(of(<String, Object?>{'flows': flow, 'session': 'S1'}), GatewayError.unknown, reason: 'Getter meldete hier M_FORBIDDEN');
      expect(of(<String, Object?>{'flows': flow, 'session': 'S1', 'errcode': 42}), GatewayError.unknown);
      expect(of(<String, Object?>{'errcode': 42}), isNull, reason: 'kein String: weiter an _map');
      expect(of(<String, Object?>{'errcode': <String>['M_PASSWORD_TOO_SHORT']}), isNull);
      expect(of(<String, Object?>{'errcode': 'M_PASSWORD_TOO_SHORT'}), GatewayError.weakPassword);
      expect(of(<String, Object?>{'errcode': 'M_LIMIT_EXCEEDED'}), isNull);
      expect(of(<String, Object?>{'errcode': 'M_FORBIDDEN', 'flows': <Object?>[], 'session': 'S1'}), GatewayError.passwordChangeUnavailable, reason: 'Schritt 1 vor Schritt 2');
      expect(of(<String, Object?>{'errcode': 'M_USER_LOCKED', 'flows': flow, 'session': 'S1'}), GatewayError.notAllowed, reason: 'gesperrt ist kein falsches Passwort');
    });

    test('TP-PW-26 Kontoseite: ohne Löschaktion, nur https', () {
      const meta = <String, Object?>{
        'account_management_uri': 'https://hs.example/account?x=1',
        'account_management_actions_supported': <String>['org.matrix.account_deactivate'],
      };
      expect(SdkMatrixGateway.accountManagementPage(meta), Uri.parse('https://hs.example/account?x=1'));
      expect(SdkMatrixGateway.accountDeletionPage(meta)!.queryParameters['action'], 'org.matrix.account_deactivate');
      expect(SdkMatrixGateway.accountManagementPage(const <String, Object?>{'account_management_uri': 'http://hs.example/account'}), isNull);
      expect(SdkMatrixGateway.accountManagementPage(const <String, Object?>{'account_management_uri': 'https://u:p@hs.example/'}), isNull);
      expect(SdkMatrixGateway.accountManagementPage(const <String, Object?>{}), isNull);
    });
  });

  group('UIA-Registrierung (SdkMatrixGateway)', () {
    test('Bedingungen → Captcha: Sitzung und erledigte Schritte werden weitergegeben, Captcha-Seite des Servers', () async {
      final s = _Server();
      s.register = (req, b) {
        final auth = b['auth'] as Map<String, Object?>?;
        if (auth == null) {
          return (401, _uia(<List<String>>[<String>['m.login.terms', 'm.login.recaptcha']], params: <String, Object?>{
            'm.login.terms': <String, Object?>{
              'policies': <String, Object?>{
                'privacy': <String, Object?>{'version': '1', 'de': <String, Object?>{'name': 'Datenschutz', 'url': 'https://hs.example/p'}},
              },
            },
          }));
        }
        return (401, _uia(<List<String>>[<String>['m.login.terms', 'm.login.recaptcha']], completed: <String>['m.login.terms']));
      };
      final g = await _gateway(s);
      final first = await g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'Emil');
      expect(first, isA<TermsStage>());
      expect((first! as TermsStage).policies.single.name, 'Datenschutz');
      expect(s.registerBodies.first['username'], 'emil');
      expect(s.registerBodies.first['password'], 'sicher-genug');
      expect(s.registerBodies.first['initial_device_display_name'], startsWith('FamilyNexus'));

      final second = await g.continueRegistration(const AcceptTerms());
      expect(s.registerBodies[1]['auth'], <String, Object?>{'type': 'm.login.terms', 'session': 'S1'});
      expect(s.registerBodies[1]['password'], 'sicher-genug', reason: 'jede Anfrage trägt die vollständigen Angaben');
      expect(second, isA<CaptchaStage>());
      final page = (second! as CaptchaStage).page;
      expect(page.toString(), 'https://hs.example/_matrix/client/v3/auth/m.login.recaptcha/fallback/web?session=S1');
      expect((second as CaptchaStage).notDoneYet, isFalse);

      final third = await g.continueRegistration(const CaptchaDone());
      expect(s.registerBodies[2]['auth'], <String, Object?>{'session': 'S1'}, reason: 'nach dem Fallback nur die Sitzung');
      expect((third! as CaptchaStage).notDoneYet, isTrue, reason: 'Server sieht das Captcha noch nicht');
    });

    test('falscher Zugangscode → „passt nicht“; Code wird im Feld token gesendet', () async {
      final s = _Server();
      s.register = (req, b) => (401, _uia(<List<String>>[<String>['m.login.registration_token']], errcode: b['auth'] == null ? null : 'M_UNAUTHORIZED'));
      final g = await _gateway(s);
      expect(await g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'E'), isA<TokenStage>());
      final r = await g.continueRegistration(const SubmitToken('  FALSCH '));
      expect((s.registerBodies.last['auth']! as Map<String, Object?>)['token'], 'FALSCH');
      expect((r! as TokenStage).wrong, isTrue);
    });

    test('Platzhalterschritt (dummy) wird selbst erledigt; Endlosschleife des Servers wird abgebrochen', () async {
      final s = _Server();
      s.register = (req, b) => (401, _uia(<List<String>>[<String>['m.login.dummy']]));
      final g = await _gateway(s);
      await expectLater(g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'E'), _error(GatewayError.unknown));
      expect(s.registerBodies, hasLength(2), reason: 'genau ein automatischer Versuch');
      expect((s.registerBodies.last['auth']! as Map<String, Object?>)['type'], 'm.login.dummy');
    });

    test('nur nicht unterstützte Abläufe → registrationDisabled', () async {
      final s = _Server();
      s.register = (req, b) => (401, _uia(<List<String>>[<String>['m.login.msisdn']]));
      final g = await _gateway(s);
      await expectLater(g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'E'), _error(GatewayError.registrationDisabled));
    });

    test('Fehlerzuordnung: vergeben, ungültig, schwaches Passwort, abgeschaltet', () async {
      for (final (status, code, expected) in <(int, String, GatewayError)>[
        (400, 'M_USER_IN_USE', GatewayError.usernameTaken),
        (400, 'M_INVALID_USERNAME', GatewayError.usernameInvalid),
        (400, 'M_EXCLUSIVE', GatewayError.usernameInvalid),
        (400, 'M_WEAK_PASSWORD', GatewayError.weakPassword),
        (400, 'M_PASSWORD_TOO_SHORT', GatewayError.weakPassword),
        (403, 'M_FORBIDDEN', GatewayError.registrationDisabled),
        (429, 'M_LIMIT_EXCEEDED', GatewayError.rateLimited),
      ]) {
        final s = _Server();
        s.register = (req, b) => (status, <String, Object?>{'errcode': code, 'error': 'x'});
        final g = await _gateway(s);
        await expectLater(g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'E'), _error(expected), reason: code);
        await expectLater(g.continueRegistration(const AcceptTerms()), _error(GatewayError.notFound), reason: 'Registrierung verworfen ($code)');
      }
    });

    test('Abbrechen verwirft die Registrierung samt Passwort; Anmelden ebenso (R4)', () async {
      final s = _Server();
      s.register = (req, b) => (401, _uia(<List<String>>[<String>['m.login.terms']]));
      final g = await _gateway(s);
      await g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'E');
      g.cancelRegistration();
      await expectLater(g.continueRegistration(const AcceptTerms()), _error(GatewayError.notFound));

      await g.register(server: _hs, username: 'emil', password: 'sicher-genug', displayName: 'E');
      await expectLater(g.login(server: _hs, username: 'emil', password: 'falsch'), throwsA(isA<GatewayException>()));
      await expectLater(g.continueRegistration(const AcceptTerms()), _error(GatewayError.notFound), reason: 'Anmelden beendet die Registrierung');
    });

    test('lokale Prüfungen vor jeder Anfrage', () async {
      final s = _Server();
      s.register = (req, b) => (401, _uia(<List<String>>[<String>['m.login.dummy']]));
      final g = await _gateway(s);
      await expectLater(g.register(server: _hs, username: 'Emil', password: 'sicher-genug', displayName: 'E'), _error(GatewayError.usernameInvalid));
      await expectLater(g.register(server: _hs, username: 'emil', password: 'kurz', displayName: 'E'), _error(GatewayError.weakPassword));
      expect(s.registerBodies, isEmpty);
    });
  });

  group('OAuth (SdkMatrixGateway)', skip: _vodAvailable ? false : 'vodozemac fehlt (tool/e2e.sh baut sie, FN_VOD_LIB)', () {
    setUpAll(() async {
      if (_vodAvailable) await vod.init(libraryPath: _vodLib);
    });
    final redirect = Uri.parse('io.github.carpeasrael.familynexus:/oauth');

    test('Start: dynamische Client-Anmeldung, PKCE S256, state, prompt=create', () async {
      final s = _Server(version: 'v1.15', meta: _meta);
      final g = await _gateway(s);
      final uri = await g.startOAuth(server: _hs, redirectUri: redirect, create: true);
      expect(uri.scheme, 'https');
      expect(uri.path, '/authorize');
      expect(uri.queryParameters['prompt'], 'create');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(uri.queryParameters['redirect_uri'], redirect.toString());
      expect(uri.queryParameters['client_id'], 'cid');
      expect(uri.queryParameters['state']!.length, greaterThan(20));
      expect(s.oidcRegistrations, 1);
      final login = await g.startOAuth(server: _hs, redirectUri: redirect, create: false);
      expect(login.queryParameters.containsKey('prompt'), isFalse);
    });

    test('R12 unsicherer Token-Endpunkt: Abbruch, bevor sich die App beim Anbieter anmeldet', () async {
      final s = _Server(version: 'v1.15', meta: <String, Object?>{..._meta, 'token_endpoint': 'http://hs.example/oauth2/token'});
      final g = await _gateway(s);
      await expectLater(g.startOAuth(server: _hs, redirectUri: redirect, create: true), _error(GatewayError.serverUnsupported));
      expect(s.oidcRegistrations, 0);
    });

    test('nur eigene Rücksprungadressen; fremder state wird verworfen, Anmeldung bleibt offen (R8)', () async {
      final s = _Server(version: 'v1.15', meta: _meta);
      s.token = (req, b) => (400, <String, Object?>{'error': 'invalid_grant'});
      final g = await _gateway(s);
      await expectLater(g.startOAuth(server: _hs, redirectUri: Uri.parse('https://evil.example/cb'), create: true), _error(GatewayError.invalidInput));
      final uri = await g.startOAuth(server: _hs, redirectUri: redirect, create: true);
      final state = uri.queryParameters['state']!;

      await expectLater(g.completeOAuth(Uri.parse('$redirect?code=c&state=fremd')), _error(GatewayError.oauthStateMismatch));
      await expectLater(g.completeOAuth(Uri.parse('evil:/oauth?code=c&state=$state')), _error(GatewayError.oauthStateMismatch));
      expect(s.tokenBodies, isEmpty, reason: 'fremde Rücksprünge erreichen den Anbieter nie');

      // Der echte Rücksprung kommt danach noch an: Code und Verifier gehen an den Token-Endpunkt.
      await expectLater(g.completeOAuth(Uri.parse('$redirect?code=echt&state=$state')), _error(GatewayError.oauthCancelled));
      final body = s.tokenBodies.single;
      expect(body['code'], 'echt');
      expect(body['grant_type'], 'authorization_code');
      expect(body['redirect_uri'], redirect.toString());
      expect(body['code_verifier']!.length, greaterThanOrEqualTo(43));
      expect(body['client_id'], 'cid');
      await expectLater(g.completeOAuth(Uri.parse('$redirect?code=echt&state=$state')), _error(GatewayError.oauthCancelled), reason: 'einmalig');
    });

    test('Ablehnung beim Anbieter (error=access_denied) beendet die Anmeldung', () async {
      final s = _Server(version: 'v1.15', meta: _meta);
      final g = await _gateway(s);
      final state = (await g.startOAuth(server: _hs, redirectUri: redirect, create: false)).queryParameters['state']!;
      await expectLater(g.completeOAuth(Uri.parse('$redirect?error=access_denied&state=$state')), _error(GatewayError.oauthCancelled));
      await expectLater(g.completeOAuth(Uri.parse('$redirect?code=x&state=$state')), _error(GatewayError.oauthCancelled));
    });

    test('Desktop-Rücksprung über 127.0.0.1 wird angenommen, Fragment und Query werden gelesen', () async {
      final s = _Server(version: 'v1.15', meta: _meta);
      s.token = (req, b) => (400, <String, Object?>{'error': 'invalid_grant'});
      final g = await _gateway(s);
      final loop = Uri.parse('http://127.0.0.1:41234/oauth');
      final state = (await g.startOAuth(server: _hs, redirectUri: loop, create: false)).queryParameters['state']!;
      await expectLater(g.completeOAuth(Uri.parse('http://127.0.0.1:41234/oauth#code=f&state=$state')), _error(GatewayError.oauthCancelled));
      expect(s.tokenBodies.single['code'], 'f');
    });
  });
}
