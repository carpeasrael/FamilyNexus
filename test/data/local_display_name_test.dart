import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

/// #261, E-89: Das lokale Protokoll nennt den eigenen Anzeigenamen aus dem Matrix-Zwischenspeicher, ohne Netzabfrage.
const String _me = '@n1:hs.example';
const String _fam = '!familie:hs.example';

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

Map<String, Object?> _member(String user, String? name) => <String, Object?>{
      'type': 'm.room.member',
      'state_key': user,
      'event_id': '\$m_${user.substring(1, 3)}',
      'sender': user,
      'origin_server_ts': DateTime.utc(2026, 11, 4, 10).millisecondsSinceEpoch,
      'content': <String, Object?>{'membership': 'join', 'displayname': ?name},
    };

Map<String, Object?> _firstSync({String? name, bool family = true}) => <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _fam: <String, Object?>{
            'state': <String, Object?>{
              'events': <Object?>[_member(_me, name), _member('@ben:hs.example', 'Ben')],
            },
            'timeline': <String, Object?>{'events': <Object?>[], 'limited': false},
          },
        },
      },
      if (family)
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{
              'type': SdkMatrixGateway.familyAccountData,
              'content': <String, Object?>{'room_id': _fam},
            },
          ],
        },
    };

/// Antwortet auf Anmeldung und den ersten Sync; weitere Syncs hängen bis [release]. Zählt Anfragen an `/profile/`.
class _Hs {
  _Hs(this.firstSync);

  final Map<String, Object?> firstSync;
  final Completer<void> _hold = Completer<void>();
  int syncs = 0;
  int profileRequests = 0;

  void release() {
    if (!_hold.isCompleted) _hold.complete();
  }

  http.Client get client => MockClient.streaming((req, body) async {
        final path = req.url.path;
        if (path.contains('/profile/')) {
          profileRequests++;
          return _json(<String, Object?>{'displayname': 'Vom Server'});
        }
        if (path == '/_matrix/client/versions') return _json(<String, Object?>{'versions': <String>['v1.1', 'v1.11']});
        if (path == '/_matrix/client/v3/login') {
          if (req.method == 'POST') return _json(<String, Object?>{'user_id': _me, 'access_token': 'tok', 'device_id': 'DEV1'});
          return _json(<String, Object?>{
            'flows': <Object?>[<String, Object?>{'type': 'm.login.password'}],
          });
        }
        if (path.endsWith('/filter')) return _json(<String, Object?>{'filter_id': '1'});
        if (path == '/_matrix/client/v3/sync') {
          if (req.url.queryParameters['set_presence'] == 'offline') return _json(<String, Object?>{'next_batch': 'p'});
          final n = syncs++;
          if (n == 0) return _json(<String, Object?>{'next_batch': 's1', ...firstSync});
          await _hold.future;
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<SdkMatrixGateway> _loggedIn(_Hs hs, Directory dir) async {
  final g = SdkMatrixGateway(
    keyStore: MemoryKeyStore(),
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
  );
  addTearDown(() async {
    hs.release();
    await g.close();
  });
  await g.restore();
  await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (g.sdkClient?.getRoomById(_fam) == null) {
    if (DateTime.now().isAfter(end)) fail('Familienraum nicht synchronisiert');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return g;
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_localname');
    addTearDown(() => dir.delete(recursive: true));
  });

  test('ohne refresh: eigener Name aus dem m.room.member des Familienraums, keine Anfrage an /profile/', () async {
    final hs = _Hs(_firstSync(name: 'Test N1'));
    final g = await _loggedIn(hs, dir);
    hs.profileRequests = 0;
    final inv = await g.dataInventory(refresh: false);
    expect(inv.displayName, 'Test N1');
    expect(hs.profileRequests, 0, reason: 'lokales Protokoll fragt nicht beim Server nach');
  });

  test('ohne Familien-Kontodaten und ohne Namen: null statt Netzabfrage', () async {
    final hs = _Hs(_firstSync(name: null, family: false));
    final g = await _loggedIn(hs, dir);
    hs.profileRequests = 0;
    final inv = await g.dataInventory(refresh: false);
    expect(inv.displayName, isNull);
    expect(hs.profileRequests, 0);
  });
}
