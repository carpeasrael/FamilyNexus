import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show SessionClearReason;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';
import '../support/sync_requests.dart';

/// #556, E-110: Das Gateway merkt sich, dass der Server die Sitzung beendet hat (Token ungültig), und sagt es nicht,
/// wenn die Person sich selbst abmeldet. Echter SDK-Client; der Server ist ein Mock.
const String _me = '@n1:hs.example';

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

/// Antwortet auf Anmeldung und ersten Sync; weitere Syncs hängen bis [endSession]. Danach antwortet jeder Sync mit
/// `M_UNKNOWN_TOKEN` (ohne `soft_logout`), bis [recover] gerufen wird.
class _Hs {
  Completer<void> _hold = Completer<void>();
  bool _rejecting = false;
  int syncs = 0;

  void endSession() {
    _rejecting = true;
    if (!_hold.isCompleted) _hold.complete();
  }

  void recover() {
    _rejecting = false;
    _hold = Completer<void>();
  }

  void release() {
    if (!_hold.isCompleted) _hold.complete();
  }

  http.Client get client => MockClient.streaming((req, body) async {
        final path = req.url.path;
        if (path == '/_matrix/client/versions') return _json(<String, Object?>{'versions': <String>['v1.1', 'v1.11']});
        if (path == '/_matrix/client/v3/login') {
          if (req.method == 'POST') return _json(<String, Object?>{'user_id': _me, 'access_token': 'tok', 'device_id': 'DEV1'});
          return _json(<String, Object?>{
            'flows': <Object?>[<String, Object?>{'type': 'm.login.password'}],
          });
        }
        if (path == '/_matrix/client/v3/logout') return _json(<String, Object?>{});
        if (path.endsWith('/filter')) return _json(<String, Object?>{'filter_id': '1'});
        if (path == '/_matrix/client/v3/sync') {
          if (isRejectionPoll(req.url)) return _json(<String, Object?>{'next_batch': 'p'});
          final n = syncs++;
          if (n == 0) return _json(<String, Object?>{'next_batch': 's1'});
          await _hold.future;
          if (_rejecting) {
            return _json(<String, Object?>{'errcode': 'M_UNKNOWN_TOKEN', 'error': 'Unknown access token', 'soft_logout': false}, 401);
          }
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<void> _until(bool Function() ok, String what) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('Zeitüberschreitung: $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('Zuordnung der SDK-Gründe', () {
    test('nur Token ungültig und gescheiterte Erneuerung sind „Server hat beendet“; kein SDK-Wert fehlt', () {
      const expected = <SessionClearReason, bool>{
        SessionClearReason.unknownToken: true,
        SessionClearReason.softLogoutRefreshFailed: true,
        SessionClearReason.logout: false,
        SessionClearReason.exportDump: false,
        SessionClearReason.initFailed: false,
        SessionClearReason.unspecified: false,
      };
      expect(SessionClearReason.values.toSet(), expected.keys.toSet(), reason: 'neuer SDK-Wert: Zuordnung prüfen');
      for (final r in SessionClearReason.values) {
        expect(sessionEndedByServerFor(r), expected[r], reason: '$r');
      }
    });
  });

  group('echter SDK-Client', () {
    late Directory dir;
    late _Hs hs;
    late SdkMatrixGateway g;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fn556');
      hs = _Hs();
      g = SdkMatrixGateway(
        keyStore: MemoryKeyStore(),
        dbDirectory: dir.path,
        probe: ServerProbe(client: hs.client),
        databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
        httpClient: hs.client,
      );
      addTearDown(() async {
        hs.release();
        await g.close();
        await dir.delete(recursive: true);
      });
      await g.restore();
      await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
      await _until(() => hs.syncs >= 2, 'zweiter Sync (wartet)');
    });

    test('Server antwortet M_UNKNOWN_TOKEN: abgemeldet, Merkmal gesetzt, Zuhörer benachrichtigt', () async {
      expect(g.sessionEndedByServer, isFalse, reason: 'angemeldet');
      var notified = 0;
      g.addListener(() => notified++);

      hs.endSession();
      await _until(() => g.sessionEndedByServer, 'Sitzungsende durch den Server');

      expect(g.session.name, 'loggedOut');
      expect(notified, greaterThan(0), reason: 'Rebuild: „Anmelden“ erfährt das Merkmal');
    });

    test('eigenes Abmelden setzt das Merkmal nicht', () async {
      await g.logout();
      expect(g.session.name, 'loggedOut');
      expect(g.sessionEndedByServer, isFalse);
    });

    test('Merkmal wird beim nächsten Sitzungsende überschrieben: erst Server, dann lokal bereinigt: falsch', () async {
      hs.endSession();
      await _until(() => g.sessionEndedByServer, 'Sitzungsende durch den Server');

      await g.sdkClient!.clear(reason: SessionClearReason.unspecified);
      // Das SDK meldet den Grund über einen Stream: erst die Ereigniswarteschlange laufen lassen.
      await _until(() => !g.sessionEndedByServer, 'Handler für den zweiten Sitzungsgrund');
      expect(g.sessionEndedByServer, isFalse, reason: 'z. B. lokal bereinigte Sitzung nach Kontolöschung (E-90)');
    });

    test('nach erneuter Anmeldung gilt das Merkmal nicht', () async {
      hs.endSession();
      await _until(() => g.sessionEndedByServer, 'Sitzungsende durch den Server');

      hs.recover();
      await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');

      expect(g.session.name, 'ready');
      expect(g.sessionEndedByServer, isFalse);
    });
  });
}
