import 'dart:convert';
import 'dart:io' show Platform;

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/account_deletion.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/password_change.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart' show MatrixException;

import 'e2e_support.dart';

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

Future<({SdkMatrixGateway g, String user, String password})> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return (g: a.gateway, user: a.user, password: a.password);
}

/// Direkte Anfrage an einen Server: Die Annahmen zu Synapse (#117) gelten seinen Antworten, nicht der App.
Future<(int, Map<String, Object?>)> _post(http.Client c, String base, String path, Map<String, Object?> body, {String? token}) async {
  final res = await c.post(
    Uri.parse('$base/_matrix/client/v3/$path'),
    headers: <String, String>{'content-type': 'application/json', 'authorization': ?(token == null ? null : 'Bearer $token')},
    body: json.encode(body),
  );
  return (res.statusCode, res.body.isEmpty ? <String, Object?>{} : json.decode(res.body) as Map<String, Object?>);
}

Future<String> _rawLogin(http.Client c, String user, String password) async {
  final (status, body) = await _post(c, '${E2e.server.uri}', 'login', <String, Object?>{
    'type': 'm.login.password',
    'identifier': <String, String>{'type': 'm.id.user', 'user': user},
    'password': password,
  });
  if (status != 200) throw StateError('Anmeldung fehlgeschlagen: $status $body');
  return body['access_token']! as String;
}

Future<int> _loginStatus(http.Client c, String user, String password) async {
  final (status, _) = await _post(c, '${E2e.server.uri}', 'login', <String, Object?>{
    'type': 'm.login.password',
    'identifier': <String, String>{'type': 'm.id.user', 'user': user},
    'password': password,
  });
  return status;
}

Future<int> _whoami(http.Client c, String token) async {
  final res = await c.get(Uri.parse('${E2e.server.uri}/_matrix/client/v3/account/whoami'), headers: <String, String>{'authorization': 'Bearer $token'});
  return res.statusCode;
}

Map<String, Object?> _passwordAuth(String session, String user, String password) => <String, Object?>{
      'type': 'm.login.password',
      'session': session,
      'password': password,
      'identifier': <String, String>{'type': 'm.id.user', 'user': user},
    };

GatewayError? _mapped(Map<String, Object?> body) => SdkMatrixGateway.passwordChangeError(MatrixException.fromJson(body))?.error;

bool _hasPasswordFlow(Map<String, Object?> body) => (body['flows']! as List<Object?>).any((f) {
      final stages = (f! as Map<String, Object?>)['stages']! as List<Object?>;
      return stages.length == 1 && stages.single == 'm.login.password';
    });

/// Neues Passwort, das die Richtlinie der Variante `only_for_reauth` erfüllt.
const String _policyPassword = 'neu-und-lang-2026-genug';

/// Führt das echte Gateway zu einem Varianten-Server: Die App spricht nur https, die Varianten nur http.
/// Hält fest, was die App gesendet hat.
class _VariantClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  /// Alle Anfragekörper, gleich an welchen Endpunkt.
  final List<String> sent = <String>[];
  final List<Map<String, Object?>> passwordPosts = <Map<String, Object?>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    sent.add(text);
    if (request.method == 'POST' && request.url.path.endsWith('/account/password')) {
      passwordPosts.add(json.decode(text) as Map<String, Object?>);
    }
    final forward = http.Request(request.method, request.url.replace(scheme: 'http', host: '127.0.0.1'))
      ..followRedirects = false
      ..headers.addAll(request.headers)
      ..bodyBytes = bytes;
    return _inner.send(forward);
  }

  @override
  void close() => _inner.close();
}

void main() {
  group('Passwort ändern (#117) gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    late http.Client c;
    setUp(() => c = E2e.lenientClient());
    tearDown(() => c.close());

    test('richtiges Passwort: neues gilt, altes nicht mehr, aktuelle Sitzung bleibt', () async {
      final a = await E2e.loggedIn('pwok');
      await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync');
      expect(await a.gateway.passwordChange(), isA<PasswordChangeInApp>());
      await a.gateway.changePassword(oldPassword: a.password, newPassword: 'neu-${a.password}', logoutOtherDevices: false);

      expect(await _loginStatus(c, a.user, 'neu-${a.password}'), 200);
      expect(await _loginStatus(c, a.user, a.password), 403);
      expect(a.gateway.session, SessionState.ready);
      expect(await a.gateway.checkAccountDeleted(), isFalse, reason: 'Sitzung gilt beim Server weiter');
    });

    test('falsches aktuelles Passwort: invalidCredentials, nichts geändert', () async {
      final a = await E2e.loggedIn('pwbad');
      await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync');
      await expectLater(
        a.gateway.changePassword(oldPassword: 'falsch-falsch', newPassword: 'neu-und-lang', logoutOtherDevices: false),
        _error(GatewayError.invalidCredentials),
      );
      expect(await _loginStatus(c, a.user, a.password), 200);
      expect(await _loginStatus(c, a.user, 'neu-und-lang'), 403);
    });

    test('logoutOtherDevices: false lässt die zweite Sitzung bestehen, true beendet sie, die aktuelle bleibt', () async {
      final a = await E2e.loggedIn('pwdev');
      await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync');
      final other = await _rawLogin(c, a.user, a.password);

      await a.gateway.changePassword(oldPassword: a.password, newPassword: 'zwei-${a.password}', logoutOtherDevices: false);
      expect(await _whoami(c, other), 200);

      await a.gateway.changePassword(oldPassword: 'zwei-${a.password}', newPassword: 'drei-${a.password}', logoutOtherDevices: true);
      expect(await _whoami(c, other), 401);
      expect(a.gateway.session, SessionState.ready);
      expect(await a.gateway.checkAccountDeleted(), isFalse);
    });

    test('Annahme: Ohne `logout_devices` meldet Synapse andere Geräte ab', () async {
      final acc = await E2e.registerUser('pwdef');
      final token = await _rawLogin(c, acc.user, acc.password);
      final other = await _rawLogin(c, acc.user, acc.password);
      final base = '${E2e.server.uri}';
      final (_, challenge) = await _post(c, base, 'account/password', <String, Object?>{'new_password': 'neu-und-lang'}, token: token);
      final (status, _) = await _post(c, base, 'account/password', <String, Object?>{
        'new_password': 'neu-und-lang',
        'auth': _passwordAuth(challenge['session']! as String, acc.user, acc.password),
      }, token: token);
      expect(status, 200);
      expect(await _whoami(c, other), 401);
      expect(await _whoami(c, token), 200);
    });

    test('Annahme: Der erste Aufruf ohne `auth` fragt mit Passwort-Flow und Session nach', () async {
      final acc = await E2e.registerUser('pwuia');
      final token = await _rawLogin(c, acc.user, acc.password);
      final (status, body) = await _post(c, '${E2e.server.uri}', 'account/password', <String, Object?>{'new_password': 'neu-und-lang', 'logout_devices': false}, token: token);
      expect(status, 401);
      expect(body['session'], isA<String>());
      expect(_hasPasswordFlow(body), isTrue, reason: '$body');
      expect(await _loginStatus(c, acc.user, acc.password), 200, reason: 'noch nichts geändert');
    });

    test('Annahme: Falsches Passwort antwortet mit Flows, Session und `M_FORBIDDEN`', () async {
      final acc = await E2e.registerUser('pwwrong');
      final token = await _rawLogin(c, acc.user, acc.password);
      final base = '${E2e.server.uri}';
      final (_, challenge) = await _post(c, base, 'account/password', <String, Object?>{'new_password': 'neu-und-lang'}, token: token);
      final (status, body) = await _post(c, base, 'account/password', <String, Object?>{
        'new_password': 'neu-und-lang',
        'auth': _passwordAuth(challenge['session']! as String, acc.user, 'falsch-falsch'),
      }, token: token);
      expect(status, 401);
      expect(body['errcode'], 'M_FORBIDDEN');
      expect(body['session'], isA<String>());
      expect(_hasPasswordFlow(body), isTrue, reason: '$body');
      expect(_mapped(body), GatewayError.invalidCredentials);
    });

    test('Annahme: 512 Zeichen nimmt Synapse an (mit Anmeldung), 513 lehnt es ab', () async {
      final a = await E2e.loggedIn('pwlen');
      await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync');
      final longest = 'a' * PasswordChange.maxLength;
      await a.gateway.changePassword(oldPassword: a.password, newPassword: longest, logoutOtherDevices: false);
      expect(await _loginStatus(c, a.user, longest), 200);

      final token = await _rawLogin(c, a.user, longest);
      final base = '${E2e.server.uri}';
      final tooLong = 'b' * (PasswordChange.maxLength + 1);
      final (firstStatus, challenge) = await _post(c, base, 'account/password', <String, Object?>{'new_password': tooLong}, token: token);
      var status = firstStatus;
      if (status == 401 && challenge['session'] is String) {
        (status, _) = await _post(c, base, 'account/password', <String, Object?>{
          'new_password': tooLong,
          'auth': _passwordAuth(challenge['session']! as String, a.user, longest),
        }, token: token);
      }
      expect(status, greaterThanOrEqualTo(400), reason: '513 Zeichen');
      expect(await _loginStatus(c, a.user, tooLong), 403);
      expect(await _loginStatus(c, a.user, longest), 200);
    });
  });

  // Braucht tool/synapse/password_variants.sh (tool/e2e.sh startet es); das Standard-Synapse hat diese
  // Einstellungen nicht.
  group(
    'Passwort ändern (#117): Annahmen zu abweichenden Synapse-Einstellungen',
    skip: E2e.enabled && Platform.environment['FN_E2E_PASSWORD_VARIANTS'] == '1' ? false : 'Setze FN_E2E_PASSWORD_VARIANTS=1, siehe tool/synapse/password_variants.sh',
    () {
      late http.Client c;
      var n = 0;
      setUp(() => c = http.Client());
      tearDown(() => c.close());

      /// Offene Registrierung liefert das Zugangstoken: Anmelden geht hier nicht immer.
      Future<({String user, String password, String token, String userId, String deviceId})> register(String base) async {
        final user = 'pwvar-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${n++}';
        final password = 'pw-$user-12345';
        final (status, body) = await _post(c, base, 'register', <String, Object?>{
          'username': user,
          'password': password,
          'auth': <String, String>{'type': 'm.login.dummy'},
        });
        if (status != 200) throw StateError('Registrierung fehlgeschlagen: $status $body');
        return (
          user: user,
          password: password,
          token: body['access_token']! as String,
          userId: body['user_id']! as String,
          deviceId: body['device_id']! as String,
        );
      }

      /// Echtes Gateway mit laufender Sitzung. Das Token kommt aus [register], weil die App sich hier nicht
      /// anmelden kann. Das entspricht einer Sitzung von vor der Umstellung des Servers.
      Future<(SdkMatrixGateway, _VariantClient)> session(String base, ({String user, String password, String token, String userId, String deviceId}) acc) async {
        await E2e.init();
        final net = _VariantClient();
        final g = await E2e.newGateway(httpClient: net);
        addTearDown(net.close);
        addTearDown(g.close);
        await g.restore();
        await g.sdkClient!.init(
          newToken: acc.token,
          newHomeserver: Uri.parse('https://localhost:${Uri.parse(base).port}'),
          newUserID: acc.userId,
          newDeviceID: acc.deviceId,
          newDeviceName: 'E2E',
          waitForFirstSync: false,
        );
        return (g, net);
      }

      test('Ohne Passwort-Anmeldung (`localdb_enabled: false`): leere Flows, ein POST, Passwort bleibt beim Gerät', () async {
        const base = 'http://127.0.0.1:18449';
        final acc = await register(base);
        final (status, body) = await _post(c, base, 'account/password', <String, Object?>{'new_password': 'neu-und-lang', 'logout_devices': false}, token: acc.token);
        expect(status, 401, reason: '$body');
        expect(body['flows'], <Object?>[], reason: '$body');
        expect(body.containsKey('errcode'), isFalse, reason: '$body');
        expect(_mapped(body), GatewayError.passwordChangeUnavailable);

        final (g, net) = await session(base, acc);
        await expectLater(
          g.changePassword(oldPassword: acc.password, newPassword: 'neu-und-lang', logoutOtherDevices: false),
          _error(GatewayError.passwordChangeUnavailable),
        );
        expect(net.passwordPosts, hasLength(1), reason: 'keine Wiederholung');
        expect(net.passwordPosts.single.containsKey('auth'), isFalse);
        expect(net.passwordPosts.single['logout_devices'], isFalse);
        expect(net.sent.where((b) => b.contains(acc.password)), isEmpty, reason: 'altes Passwort geht an keinen Endpunkt');
      });

      test('Ohne Passwort-Anmeldung (`enabled: false`): keine Passwort-Stufe in den Flows', () async {
        const base = 'http://127.0.0.1:18450';
        final acc = await register(base);
        final (status, body) = await _post(c, base, 'account/password', <String, Object?>{'new_password': 'neu-und-lang', 'logout_devices': false}, token: acc.token);
        expect(status, 401, reason: '$body');
        expect(_hasPasswordFlow(body), isFalse, reason: '$body');
        expect(_mapped(body), GatewayError.passwordChangeUnavailable);
      });

      test('Annahme zu `only_for_reauth`: Passwort-Stufe vorhanden, richtiges Passwort ergibt 403 ohne Flows', () async {
        const base = 'http://127.0.0.1:18451';
        final wrong = await register(base);
        final change = <String, Object?>{'new_password': _policyPassword, 'logout_devices': false};
        final (firstStatus, challenge) = await _post(c, base, 'account/password', change, token: wrong.token);
        expect(firstStatus, 401, reason: '$challenge');
        expect(challenge['session'], isA<String>());
        expect(_hasPasswordFlow(challenge), isTrue, reason: '$challenge');

        final (wrongStatus, wrongBody) = await _post(c, base, 'account/password', <String, Object?>{
          ...change,
          'auth': _passwordAuth(challenge['session']! as String, wrong.user, 'falsch-falsch'),
        }, token: wrong.token);
        expect(wrongStatus, 401, reason: '$wrongBody');
        expect(wrongBody['errcode'], 'M_FORBIDDEN');
        expect(wrongBody['completed'], <Object?>[]);
        expect(_hasPasswordFlow(wrongBody), isTrue, reason: '$wrongBody');
        expect(_mapped(wrongBody), GatewayError.invalidCredentials);

        final right = await register(base);
        final (_, second) = await _post(c, base, 'account/password', change, token: right.token);
        final (status, body) = await _post(c, base, 'account/password', <String, Object?>{
          ...change,
          'auth': _passwordAuth(second['session']! as String, right.user, right.password),
        }, token: right.token);
        expect(status, 403, reason: '$body');
        expect(body['errcode'], 'M_FORBIDDEN');
        expect(body.containsKey('flows'), isFalse, reason: '$body');
        expect(_mapped(body), GatewayError.passwordChangeUnavailable);

        final (weakStatus, weakBody) = await _post(c, base, 'account/password', <String, Object?>{'new_password': 'kurz1', 'logout_devices': false}, token: right.token);
        expect(weakStatus, 400, reason: '$weakBody');
        expect(weakBody['errcode'], 'M_PASSWORD_TOO_SHORT');
        expect(_mapped(weakBody), GatewayError.weakPassword);

        final (loginStatus, loginBody) = await _post(c, base, 'login', <String, Object?>{
          'type': 'm.login.password',
          'identifier': <String, String>{'type': 'm.id.user', 'user': right.user},
          'password': right.password,
        });
        expect(loginStatus, 400, reason: '$loginBody');
        expect(loginBody['errcode'], 'M_UNKNOWN');
      });

      test('`only_for_reauth` mit echtem Gateway: falsches, richtiges Passwort und Richtlinie', () async {
        const base = 'http://127.0.0.1:18451';
        final acc = await register(base);
        final (g, net) = await session(base, acc);

        await expectLater(
          g.changePassword(oldPassword: 'falsch-falsch', newPassword: _policyPassword, logoutOtherDevices: false),
          _error(GatewayError.invalidCredentials),
        );
        expect(net.passwordPosts, hasLength(2));
        expect(net.passwordPosts.first.containsKey('auth'), isFalse, reason: 'Passwort erst, wenn der Server es verlangt');
        expect((net.passwordPosts.last['auth']! as Map<String, Object?>)['password'], 'falsch-falsch');

        net.passwordPosts.clear();
        await expectLater(
          g.changePassword(oldPassword: acc.password, newPassword: _policyPassword, logoutOtherDevices: false),
          _error(GatewayError.passwordChangeUnavailable),
        );
        expect(net.passwordPosts, hasLength(2));
        expect(net.passwordPosts.first.containsKey('auth'), isFalse);
        expect((net.passwordPosts.last['auth']! as Map<String, Object?>)['password'], acc.password);

        net.passwordPosts.clear();
        net.sent.clear();
        await expectLater(
          g.changePassword(oldPassword: acc.password, newPassword: 'kurz-1234', logoutOtherDevices: false),
          _error(GatewayError.weakPassword),
        );
        expect(net.passwordPosts, hasLength(1), reason: 'Richtlinie greift vor der Nachfrage');
        expect(net.sent.where((b) => b.contains(acc.password)), isEmpty);
      });
    },
  );

  group('Kontolöschung (#12) gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Passwort-Konto: falsches Passwort scheitert, danach gelöscht, Familie verlassen, Anmeldung unmöglich', () async {
      final mod = await _login('delmod');
      await mod.g.createFamily('Familie Löschung');
      await E2e.until(() => mod.g.family != null);
      final b = await _login('delmem');
      final bid = b.g.userId!;

      final link = InviteLink.tryParse(await mod.g.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      await b.g.requestToJoin(link);
      await E2e.until(() => mod.g.family?.member(bid)?.status == MemberStatus.requested, what: 'Anfrage');
      await mod.g.approveRequest(bid);
      await E2e.until(() => b.g.invitations.isNotEmpty, what: 'Einladung');
      await b.g.acceptInvitation(b.g.invitations.single.roomId);
      await E2e.until(() => mod.g.family?.member(bid)?.status == MemberStatus.joined, what: 'beigetreten');

      // Zweites Gerät desselben Kontos: sieht die Löschung bei der nächsten Prüfung.
      final second = await E2e.loginAs(b.user, b.password);
      expect(await second.checkAccountDeleted(), isFalse);

      expect(await b.g.accountDeletion(), isA<AccountDeletionInApp>());
      await expectLater(b.g.deleteAccount(password: 'falsch-falsch'), _error(GatewayError.invalidCredentials));
      expect(b.g.session, SessionState.ready, reason: 'nichts gelöscht');

      await b.g.deleteAccount(password: b.password);
      expect(b.g.session, SessionState.loggedOut);
      await E2e.until(() => mod.g.family?.member(bid)?.status != MemberStatus.joined, what: 'Konto hat die Familie verlassen');

      expect(await second.checkAccountDeleted(), isTrue);
      expect(second.session, SessionState.loggedOut);
      await expectLater(E2e.loginAs(b.user, b.password), throwsA(isA<GatewayException>()));
    });
  });
}
