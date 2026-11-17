import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';
import '../support/sync_requests.dart';

/// #526, E-106: Lesebestätigung im Gateway mit echtem SDK-Client und HTTP-Mock (Muster `live_since_test.dart`):
/// `markChatRead` sendet `m.read` nur bei eingeschalteter Lesebestätigung, `m.read.private` immer;
/// `refreshReadStates()` bildet neu ab; ein Sync mit nur einem Lesemarker löst den Neuaufbau aus.
const String _me = '@n1:hs.example';
const String _ben = '@ben:hs.example';
const String _fam = '!familie:hs.example';

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

DateTime _t(int s) => DateTime.utc(2026, 11, 3, 10).add(Duration(seconds: s));

Map<String, Object?> _event(String id, int ts) => <String, Object?>{
      'type': 'm.room.encrypted',
      'event_id': id,
      'sender': _ben,
      'origin_server_ts': _t(ts).millisecondsSinceEpoch,
      'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x', 'session_id': 's', 'sender_key': 'k'},
    };

/// Antwortet auf Anmeldung und ersten Sync (Familienraum mit zwei ungelesenen Ereignissen), merkt `read_markers`.
class _Hs {
  final Completer<void> _hold = Completer<void>();
  int syncs = 0;
  final List<Map<String, Object?>> readMarkers = <Map<String, Object?>>[];

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
        if (path.endsWith('/read_markers') && req.method == 'POST') {
          readMarkers.add(json.decode(await body.bytesToString()) as Map<String, Object?>);
          return _json(<String, Object?>{});
        }
        if (path == '/_matrix/client/v3/sync') {
          if (isRejectionPoll(req.url)) return _json(<String, Object?>{'next_batch': 'p'});
          final n = syncs++;
          if (n == 0) {
            return _json(<String, Object?>{
              'next_batch': 's1',
              'rooms': <String, Object?>{
                'join': <String, Object?>{
                  _fam: <String, Object?>{
                    'timeline': <String, Object?>{
                      'events': <Object?>[_event(r'$chat1', 10), _event(r'$chat2', 20)],
                      'limited': false,
                    },
                    'unread_notifications': <String, Object?>{'notification_count': 2, 'highlight_count': 0},
                  },
                },
              },
              'account_data': <String, Object?>{
                'events': <Object?>[
                  <String, Object?>{
                    'type': SdkMatrixGateway.familyAccountData,
                    'content': <String, Object?>{'room_id': _fam},
                  },
                ],
              },
            });
          }
          await _hold.future;
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<void> _until(bool Function() cond, {String? what}) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Bedingung nicht erreicht: $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_receipts');
    addTearDown(() => dir.delete(recursive: true));
  });

  Future<(SdkMatrixGateway, _Hs)> open({bool Function()? share}) async {
    final hs = _Hs();
    final g = share == null
        ? SdkMatrixGateway(
            keyStore: MemoryKeyStore(),
            dbDirectory: dir.path,
            probe: ServerProbe(client: hs.client),
            databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
            httpClient: hs.client,
          )
        : SdkMatrixGateway(
            keyStore: MemoryKeyStore(),
            dbDirectory: dir.path,
            probe: ServerProbe(client: hs.client),
            databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
            httpClient: hs.client,
            shareReadReceipts: share,
          );
    addTearDown(() async {
      hs.release();
      await g.close();
    });
    await g.restore();
    await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    await _until(() => g.family != null && g.sdkClient?.getRoomById(_fam)?.notificationCount == 2, what: 'Familie und Serverzähler');
    return (g, hs);
  }

  test('Standard (ohne Parameter): markChatRead sendet m.read und m.read.private', () async {
    final (g, hs) = await open();
    await g.markChatRead();
    expect(hs.readMarkers, hasLength(1));
    expect(hs.readMarkers.single['m.read'], r'$chat2');
    expect(hs.readMarkers.single['m.read.private'], r'$chat2');
    expect(hs.readMarkers.single['m.fully_read'], r'$chat2');
  });

  test('Lesebestätigung an: m.read und m.read.private; aus: nur m.read.private', () async {
    var on = true;
    final (g, hs) = await open(share: () => on);
    await g.markChatRead();
    expect(hs.readMarkers.single.containsKey('m.read'), isTrue);
    expect(hs.readMarkers.single['m.read.private'], r'$chat2');

    on = false;
    // Zweiter Aufruf: der Server hat den Zähler nicht zurückgesetzt (Mock), `notificationCount` bleibt 2.
    await g.markChatRead();
    expect(hs.readMarkers, hasLength(2));
    expect(hs.readMarkers.last.containsKey('m.read'), isFalse, reason: 'Gegenseitigkeit: nur privat');
    expect(hs.readMarkers.last['m.read.private'], r'$chat2');
    expect(hs.readMarkers.last['m.fully_read'], r'$chat2');
  });

  test('refreshReadStates() löst einen Neuaufbau mit Benachrichtigung aus', () async {
    final (g, _) = await open();
    var n = 0;
    g.addListener(() => n++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final before = n;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(n, before, reason: 'ohne Anstoß ist es ruhig');
    g.refreshReadStates();
    await _until(() => n > before, what: 'Neuaufbau nach refreshReadStates');
  });

  test('ein Sync mit nur einem Lesemarker (ephemeral m.receipt) speichert ihn und löst den Neuaufbau aus', () async {
    final (g, _) = await open();
    var n = 0;
    g.addListener(() => n++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final before = n;
    await g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{
      'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}',
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _fam: <String, Object?>{
            'ephemeral': <String, Object?>{
              'events': <Object?>[
                <String, Object?>{
                  'type': 'm.receipt',
                  'content': <String, Object?>{
                    r'$chat2': <String, Object?>{
                      'm.read': <String, Object?>{
                        _ben: <String, Object?>{'ts': _t(30).millisecondsSinceEpoch},
                      },
                    },
                  },
                },
              ],
            },
          },
        },
      },
    }));
    await _until(() => n > before, what: 'Neuaufbau nach Receipt-Sync');
    final marker = g.sdkClient!.getRoomById(_fam)!.receiptState.global.otherUsers[_ben];
    expect(marker?.eventId, r'$chat2');
  });
}
