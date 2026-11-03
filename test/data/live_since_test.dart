import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show Client, Event, EventStatus, EventStatusExtension, MatrixSdkDatabase, Room, SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

/// #254, E-88: Grundlinie für Meldungen (`liveSince`) mit echtem SDK-Client.
const String _me = '@n1:hs.example';
const String _famA = '!familieA:hs.example';
const String _famB = '!familieB:hs.example';
const String _dm = '!einzel:hs.example';

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

DateTime _t(int s) => DateTime.utc(2026, 11, 3, 10).add(Duration(seconds: s));

Map<String, Object?> _event(String id, String type, int ts, {String sender = '@ben:hs.example'}) => <String, Object?>{
      'type': type,
      'event_id': id,
      'sender': sender,
      'origin_server_ts': _t(ts).millisecondsSinceEpoch,
      'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x', 'session_id': 's', 'sender_key': 'k'},
    };

Map<String, Object?> _rooms(Map<String, List<Map<String, Object?>>> timelines, {String? family}) => <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          for (final e in timelines.entries)
            e.key: <String, Object?>{
              'timeline': <String, Object?>{'events': e.value, 'limited': false},
            },
        },
      },
      if (family != null)
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{
              'type': SdkMatrixGateway.familyAccountData,
              'content': <String, Object?>{'room_id': family},
            },
          ],
        },
    };

/// Antwortet auf Anmeldung und die erste Sync-Anfrage; weitere Syncs hängen, bis [release].
class _Hs {
  _Hs(this.firstSync);

  /// Inhalt der ersten echten Sync-Antwort (ohne `next_batch`).
  Map<String, Object?> firstSync;
  Completer<void> firstGate = Completer<void>()..complete();
  final Completer<void> _hold = Completer<void>();
  int syncs = 0;

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
        if (path.endsWith('/filter')) return _json(<String, Object?>{'filter_id': '1'});
        if (path == '/_matrix/client/v3/sync') {
          if (req.url.queryParameters['set_presence'] == 'offline') return _json(<String, Object?>{'next_batch': 'p'});
          final n = syncs++;
          if (n == 0) {
            await firstGate.future;
            return _json(<String, Object?>{'next_batch': 's1', ...firstSync});
          }
          await _hold.future;
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<SdkMatrixGateway> _gateway(_Hs hs, Directory dir, MemoryKeyStore keys) async {
  final g = SdkMatrixGateway(
    keyStore: keys,
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
  );
  addTearDown(() async {
    hs.release();
    await g.close();
  });
  return g;
}

Future<void> _until(bool Function() cond, {String? what}) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Bedingung nicht erreicht: $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _sync(SdkMatrixGateway g, Map<String, Object?> update, {bool real = true}) => g.sdkClient!.handleSync(
    SyncUpdate.fromJson(<String, Object?>{'next_batch': real ? 'x${DateTime.now().microsecondsSinceEpoch}' : '', ...update}));

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_live');
    addTearDown(() => dir.delete(recursive: true));
  });

  test('künstlicher Sync zählt nicht; erster echter Sync: Maximum aller Ereignisse jeden Typs aller Räume', () async {
    // Einkauf nach der letzten Chat-Nachricht und eine Direktnachricht, bevor die Familie bekannt ist.
    final hs = _Hs(_rooms(<String, List<Map<String, Object?>>>{
      _famA: <Map<String, Object?>>[
        _event(r'$chat', 'm.room.encrypted', 10),
        _event(r'$shop', 'de.inneso.familynexus.shopping', 40),
      ],
      _dm: <Map<String, Object?>>[_event(r'$dm', 'm.room.encrypted', 30)],
    }, family: _famA));
    hs.firstGate = Completer<void>();
    final g = await _gateway(hs, dir, MemoryKeyStore());
    await g.restore();
    final login = g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    await _until(() => g.sdkClient?.isLogged() ?? false, what: 'angemeldet');
    // Künstlicher Sync des SDK (z. B. Verlauf) vor dem ersten echten: zählt nicht.
    await _sync(g, _rooms(<String, List<Map<String, Object?>>>{
      _famA: <Map<String, Object?>>[_event(r'$alt', 'm.room.encrypted', 90)],
    }), real: false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(g.liveSince, isNull);
    hs.firstGate.complete();
    await login;
    await _until(() => g.liveSince != null, what: 'liveSince gesetzt');
    expect(g.liveSince, _t(40), reason: 'Einkaufsereignis ist das jüngste; lastEvent wäre die Chat-Nachricht (10)');
  });

  test('Familienwechsel nach dem ersten Sync hebt die Grundlinie über den Verlauf der neuen Familie', () async {
    final hs = _Hs(_rooms(<String, List<Map<String, Object?>>>{
      _famA: <Map<String, Object?>>[_event(r'$a1', 'm.room.encrypted', 10)],
    }, family: _famA));
    final g = await _gateway(hs, dir, MemoryKeyStore());
    await g.restore();
    await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    await _until(() => g.liveSince != null, what: 'liveSince gesetzt');
    expect(g.liveSince, _t(10));
    await _sync(g, _rooms(<String, List<Map<String, Object?>>>{
      _famB: <Map<String, Object?>>[_event(r'$b1', 'm.room.encrypted', 50), _event(r'$b2', 'de.inneso.familynexus.shopping', 60)],
    }, family: _famB));
    await _until(() => g.liveSince == _t(60), what: 'Grundlinie gehoben');
    // Auch beim Familienwechsel gilt die Obergrenze: Zeitstempel weit in der Zukunft.
    final future = DateTime.now().toUtc().add(const Duration(hours: 3));
    await _sync(g, _rooms(<String, List<Map<String, Object?>>>{
      _famA: <Map<String, Object?>>[
        <String, Object?>{..._event(r'$a9', 'm.room.encrypted', 0), 'origin_server_ts': future.millisecondsSinceEpoch},
      ],
    }, family: _famA));
    await _until(() => g.family?.roomId == _famA, what: 'zurück zu A');
    await _until(() => g.liveSince != _t(60), what: 'Grundlinie erneut gehoben');
    expect(g.liveSince!.isAfter(DateTime.now().toUtc().add(SdkMatrixGateway.liveSkew)), isFalse);
  });

  test('Abmelden setzt zurück; Wiederherstellen: Start zählt nicht als Familienwechsel, leere Antwort nimmt den Startwert',
      () async {
    final keys = MemoryKeyStore();
    final hs1 = _Hs(_rooms(<String, List<Map<String, Object?>>>{
      _famA: <Map<String, Object?>>[_event(r'$a1', 'm.room.encrypted', 10), _event(r'$a2', 'm.room.encrypted', 20)],
    }, family: _famA));
    final g1 = await _gateway(hs1, dir, keys);
    await g1.restore();
    await g1.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    await _until(() => g1.liveSince != null, what: 'liveSince gesetzt');
    hs1.release();
    await g1.close();

    // Neuer Prozess: Sitzung aus der Datenbank, die erste echte Antwort hält, bis der Test sie freigibt.
    final hs2 = _Hs(const <String, Object?>{})..firstGate = Completer<void>();
    final g2 = await _gateway(hs2, dir, keys);
    await g2.restore();
    expect(g2.family?.roomId, _famA, reason: 'Familie aus der Datenbank: „keine → A“ ist gelaufen');
    expect(g2.liveSince, isNull, reason: 'vor dem ersten echten Sync keine Grundlinie, auch nicht durch den Familienwechsel');
    hs2.firstGate.complete();
    await _until(() => g2.liveSince != null, what: 'liveSince nach leerer Antwort');
    expect(g2.liveSince, _t(20), reason: 'Startwert aus der Datenbank');

    await g2.logout();
    expect(g2.liveSince, isNull);
  });

  test('Obergrenze: Zeitstempel weit in der Zukunft unterdrückt Meldungen höchstens 5 Minuten', () async {
    final future = DateTime.now().toUtc().add(const Duration(hours: 2));
    final hs = _Hs(<String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _famA: <String, Object?>{
            'timeline': <String, Object?>{
              'events': <Object?>[
                <String, Object?>{
                  ..._event(r'$zukunft', 'm.room.encrypted', 0),
                  'origin_server_ts': future.millisecondsSinceEpoch,
                },
              ],
            },
          },
        },
      },
    });
    final g = await _gateway(hs, dir, MemoryKeyStore());
    await g.restore();
    final before = DateTime.now().toUtc();
    await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    await _until(() => g.liveSince != null, what: 'liveSince gesetzt');
    expect(SdkMatrixGateway.liveSkew, const Duration(minutes: 5), reason: 'Zusage in E-88');
    final limit = DateTime.now().toUtc().add(SdkMatrixGateway.liveSkew);
    expect(g.liveSince!.isAfter(limit), isFalse);
    expect(g.liveSince!.isAfter(before.add(SdkMatrixGateway.liveSkew).subtract(const Duration(seconds: 5))), isTrue);
  });

  test('Startwert zählt nur vom Server bestätigte Ereignisse (SENDING trägt Gerätezeit)', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final client = Client('seed', database: await MatrixSdkDatabase.init('seed', database: db));
    addTearDown(db.close);
    final room = Room(id: _famA, client: client);
    Event e(String id, int ts, EventStatus status) => Event.fromJson(<String, Object?>{
          ..._event(id, 'm.room.encrypted', ts),
          'status': status.intValue,
        }, room);
    expect(SdkMatrixGateway.latestSynced(<Event>[e(r'$s', 900, EventStatus.sending), e(r'$a', 20, EventStatus.synced)]), _t(20));
    expect(SdkMatrixGateway.latestSynced(<Event>[e(r'$f', 900, EventStatus.error), e(r'$x', 900, EventStatus.sent)]), isNull);
    expect(SdkMatrixGateway.latestSynced(const <Event>[]), isNull);
  });
}
