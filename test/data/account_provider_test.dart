import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show MatrixSdkDatabase;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

/// #259, E-90: Die App zeigt die eingegebene Anbieter-Adresse, nicht den über `.well-known` aufgelösten Homeserver.
const String _me = '@n1:hs.example';
const String _key = SdkMatrixGateway.accountProviderKey;
final ServerUrl _provider = ServerUrl.tryParse('provider.example')!;

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

/// Nachgestellter Anbieter: `provider.example` leitet per `.well-known` auf `https://hs.example` um, dort läuft der
/// Homeserver. Der erste Sync antwortet sofort, weitere hängen bis [release]; mit [revoked] dann 401 M_UNKNOWN_TOKEN.
class _Hs {
  bool failAfterLogin = false;
  bool revoked = false;
  bool _loggedIn = false;
  final Completer<void> _hold = Completer<void>();
  int syncs = 0;
  final List<Uri> requests = <Uri>[];

  void release() {
    if (!_hold.isCompleted) _hold.complete();
  }

  http.Client get client => MockClient.streaming((req, body) async {
        final path = req.url.path;
        requests.add(req.url);
        if (path == '/.well-known/matrix/client') {
          return req.url.host == 'provider.example'
              ? _json(<String, Object?>{
                  'm.homeserver': <String, Object?>{'base_url': 'https://hs.example'},
                })
              : _json(<String, Object?>{'errcode': 'M_NOT_FOUND'}, 404);
        }
        if (req.url.host != 'hs.example') return _json(<String, Object?>{'errcode': 'M_NOT_FOUND'}, 404);
        if (path == '/_matrix/client/versions') return _json(<String, Object?>{'versions': <String>['v1.1', 'v1.11']});
        if (path == '/_matrix/client/v3/login') {
          if (req.method == 'POST') {
            _loggedIn = true;
            return _json(<String, Object?>{'user_id': _me, 'access_token': 'tok', 'device_id': 'DEV1'});
          }
          return _json(<String, Object?>{
            'flows': <Object?>[<String, Object?>{'type': 'm.login.password'}],
          });
        }
        if (failAfterLogin && _loggedIn) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'kaputt'}, 500);
        if (path.endsWith('/filter')) return _json(<String, Object?>{'filter_id': '1'});
        if (path == '/_matrix/client/v3/sync') {
          if (req.url.queryParameters['set_presence'] == 'offline') return _json(<String, Object?>{'next_batch': 'p'});
          final n = syncs++;
          if (n == 0) return _json(<String, Object?>{'next_batch': 's1'});
          await _hold.future;
          if (revoked) return _json(<String, Object?>{'errcode': 'M_UNKNOWN_TOKEN', 'error': 'ungültig'}, 401);
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

/// Ablage, deren Lesen scheitern kann (Lesefehler beim Start).
class _FlakyStore extends MemoryKeyValueStore {
  bool failReads = false;

  @override
  Future<Map<String, String>> readAll() {
    if (failReads) throw StateError('Lesefehler (Test)');
    return super.readAll();
  }
}

Future<SdkMatrixGateway> _gateway(
  _Hs hs,
  Directory dir,
  MemoryKeyStore keys, {
  MemoryKeyValueStore? kv,
  Future<Database> Function(String path, String key)? opener,
}) async {
  final g = SdkMatrixGateway(
    keyStore: keys,
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: opener ?? (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
    accountStore: kv,
  );
  addTearDown(() async {
    hs.release();
    await g.close();
  });
  return g;
}

/// Matrix-Datenbank mit einer gespeicherten Sitzung (wie nach einer Anmeldung mit einer älteren Version).
Future<void> _seedSession(Directory dir, MemoryKeyStore keys, {String homeserver = 'https://hs.example'}) async {
  await keys.getOrCreateKey(SdkMatrixGateway.matrixDbKeyName);
  final db = await databaseFactoryFfi.openDatabase(_dbPath(dir));
  final matrix = await MatrixSdkDatabase.init('familynexus', database: db);
  await matrix.storeClient(homeserverUrl: homeserver, token: 'tok', userId: _me, deviceId: 'DEV1');
  await db.close();
}

String _dbPath(Directory dir) => '${dir.path}/${SdkMatrixGateway.matrixDbFileName}';

String _entry({String user = _me, String entered = 'https://provider.example', String base = 'https://hs.example'}) =>
    json.encode(<String, String>{'user_id': user, 'entered': entered, 'base': base});

Future<void> _until(bool Function() cond, {String? what}) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Bedingung nicht erreicht: $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late MemoryKeyStore keys;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_provider');
    keys = MemoryKeyStore();
    addTearDown(() => dir.delete(recursive: true));
  });

  test('Anmelden über .well-known: Anzeige der Eingabe, technisch die Basis; nach close und restore unverändert', () async {
    final kv = MemoryKeyValueStore();
    final hs1 = _Hs();
    final g1 = await _gateway(hs1, dir, keys, kv: kv);
    await g1.restore();
    await g1.login(server: _provider, username: 'n1', password: 'geheim123');
    expect(g1.session, SessionState.ready);
    expect(g1.server?.host, 'provider.example', reason: 'bisher hs.example (aufgelöste Basis)');
    expect(g1.sdkClient!.homeserver!.host, 'hs.example', reason: 'Sync und Anfragen laufen weiter über die Basis');
    final stored = json.decode(kv.data[_key]!) as Map<String, Object?>;
    expect(stored, <String, Object?>{'user_id': _me, 'entered': 'https://provider.example', 'base': 'https://hs.example'});

    final inventory = await g1.dataInventory(refresh: false);
    expect(inventory.server, 'https://provider.example');
    expect(ServerUrl.tryParse(inventory.homeserver!), ServerUrl.tryParse('https://hs.example'));

    hs1.release();
    await g1.close();
    expect(kv.data.containsKey(_key), isTrue, reason: 'Schließen ist kein Sitzungsende');

    final g2 = await _gateway(_Hs(), dir, keys, kv: kv);
    await g2.restore();
    expect(g2.session, SessionState.ready);
    expect(g2.server?.host, 'provider.example');
  });

  test('#28: Anmeldung gelingt, ein Folgeschritt scheitert: trotzdem die eingegebene Adresse', () async {
    final hs = _Hs()..failAfterLogin = true;
    final kv = MemoryKeyValueStore();
    final g = await _gateway(hs, dir, keys, kv: kv);
    await g.restore();
    await g.login(server: _provider, username: 'n1', password: 'geheim123');
    expect(g.session, SessionState.ready);
    expect(g.server?.host, 'provider.example');
    expect(kv.data.containsKey(_key), isTrue);
  });

  test('erzwungenes Sitzungsende (ungültiges Token) löscht den Eintrag', () async {
    final hs = _Hs();
    final kv = MemoryKeyValueStore();
    final g = await _gateway(hs, dir, keys, kv: kv);
    await g.restore();
    await g.login(server: _provider, username: 'n1', password: 'geheim123');
    expect(kv.data.containsKey(_key), isTrue, reason: 'Vorbedingung');
    expect(g.server?.host, 'provider.example', reason: 'Vorbedingung');
    hs.revoked = true;
    hs.release();
    await _until(() => !kv.data.containsKey(_key), what: 'Eintrag gelöscht');
    expect(g.session, SessionState.loggedOut);
    expect(g.server, isNull);
  });

  test('Abmelden löscht den Eintrag', () async {
    final kv = MemoryKeyValueStore();
    final g = await _gateway(_Hs(), dir, keys, kv: kv);
    await g.restore();
    await g.login(server: _provider, username: 'n1', password: 'geheim123');
    expect(kv.data.containsKey(_key), isTrue, reason: 'Vorbedingung');
    await g.logout();
    expect(kv.data.containsKey(_key), isFalse);
    expect(g.server, isNull);
  });

  test('Matrix-Datenbank vorübergehend nicht lesbar (sessionLost: false): Eintrag bleibt', () async {
    final kv = MemoryKeyValueStore();
    final hs1 = _Hs();
    final g1 = await _gateway(hs1, dir, keys, kv: kv);
    await g1.restore();
    await g1.login(server: _provider, username: 'n1', password: 'geheim123');
    hs1.release();
    await g1.close();

    var failOpen = true;
    final g2 = await _gateway(_Hs(), dir, keys, kv: kv, opener: (path, key) async {
      if (failOpen) throw StateError('gesperrt');
      return databaseFactoryFfi.openDatabase(path);
    });
    await expectLater(
      g2.restore(),
      throwsA(isA<SessionRestoreException>().having((e) => e.sessionLost, 'sessionLost', false)),
    );
    expect(kv.data.containsKey(_key), isTrue);
    failOpen = false;
    await g2.restore();
    expect(g2.server?.host, 'provider.example');
  });

  test('Altsitzung ohne Eintrag zeigt den aufgelösten Server (mit und ohne Ablage)', () async {
    await _seedSession(dir, keys);
    final g1 = await _gateway(_Hs(), dir, keys, kv: MemoryKeyValueStore());
    await g1.restore();
    expect(g1.session, SessionState.ready);
    expect(g1.server?.host, 'hs.example');
    await g1.close();

    final g2 = await _gateway(_Hs(), dir, keys);
    await g2.restore();
    expect(g2.server?.host, 'hs.example');
  });

  for (final (name, entry, expected) in <(String, String, String)>[
    ('fremdes Konto', _entry(user: '@jemand:hs.example'), 'hs.example'),
    ('andere Basis', _entry(base: 'https://anders.example'), 'hs.example'),
    ('unlesbarer Eintrag', '{kaputt', 'hs.example'),
    ('Basis mit Schrägstrich am Ende gilt als gleich', _entry(base: 'https://hs.example/'), 'provider.example'),
  ]) {
    test('gespeicherter Eintrag: $name → $expected', () async {
      await _seedSession(dir, keys);
      final kv = MemoryKeyValueStore()..data[_key] = entry;
      final g = await _gateway(_Hs(), dir, keys, kv: kv);
      await g.restore();
      expect(g.session, SessionState.ready);
      expect(g.server?.host, expected);
    });
  }

  test('Sitzung mit Schrägstrich am Ende der gespeicherten Basis passt zum Eintrag', () async {
    await _seedSession(dir, keys, homeserver: 'https://hs.example/');
    final kv = MemoryKeyValueStore()..data[_key] = _entry();
    final g = await _gateway(_Hs(), dir, keys, kv: kv);
    await g.restore();
    expect(g.server?.host, 'provider.example');
  });

  test('ohne gespeicherte Sitzung wird ein übrig gebliebener Eintrag gelöscht', () async {
    final kv = MemoryKeyValueStore()..data[_key] = _entry();
    final g = await _gateway(_Hs(), dir, keys, kv: kv);
    await g.restore();
    expect(g.session, SessionState.loggedOut);
    expect(kv.data.containsKey(_key), isFalse);
  });

  test('Lesefehler beim Start: nur geloggt; das spätere Sitzungsende löscht den Eintrag trotzdem', () async {
    await _seedSession(dir, keys);
    final kv = _FlakyStore()
      ..data[_key] = _entry()
      ..failReads = true;
    final g = await _gateway(_Hs(), dir, keys, kv: kv);
    await g.restore();
    expect(g.session, SessionState.ready, reason: 'Start läuft weiter');
    expect(g.server?.host, 'hs.example', reason: 'ohne lesbaren Eintrag der aufgelöste Server');
    kv.failReads = false;
    await g.logout();
    expect(kv.data.containsKey(_key), isFalse);
  });

  test('Schreibfehler der Ablage verhindert die Anmeldung nicht', () async {
    final kv = MemoryKeyValueStore()..failWrites = true;
    final g = await _gateway(_Hs(), dir, keys, kv: kv);
    await g.restore();
    await g.login(server: _provider, username: 'n1', password: 'geheim123');
    expect(g.session, SessionState.ready);
    expect(g.server?.host, 'provider.example', reason: 'für die laufende Sitzung im Speicher');
  });
}
