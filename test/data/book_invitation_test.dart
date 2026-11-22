// Buch-Einladungen (Kassenbuch, #311, E-113): Sie erscheinen nie als Familieneinladung und werden von der
// Familienlogik nie angenommen, auch wenn die Einladung kein `m.room.create` enthielt. Läuft gegen einen
// nachgestellten Homeserver (wie join_rejection_test), ohne vodozemac. Die Trennung gilt unabhängig von `CashBookFlags`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/book_room.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show BasicEvent, SyncStatus, SyncStatusUpdate, SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

const String _me = '@n2:hs.example';
const String _inviter = '@mod:hs.example';
const String _book = '!buch:hs.example';
const String _family = '!familie:hs.example';
const String _dm = '!dm:hs.example';
const Duration _settle = Duration(milliseconds: 350);

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

Map<String, Object?> _create(String room, Map<String, Object?> content) =>
    <String, Object?>{'type': 'm.room.create', 'state_key': '', 'sender': _inviter, 'content': <String, Object?>{'room_version': '10', ...content}};

Map<String, Object?> _member(String membership, {bool direct = false}) => <String, Object?>{
      'type': 'm.room.member',
      'state_key': _me,
      'sender': _inviter,
      'content': <String, Object?>{'membership': membership, if (direct) 'is_direct': true},
    };

/// Einladung wie vom Server: gestrippter Zustand mit oder ohne `m.room.create`.
Map<String, Object?> _invite(String room, {Map<String, Object?>? create, bool direct = false}) => <String, Object?>{
      'rooms': <String, Object?>{
        'invite': <String, Object?>{
          room: <String, Object?>{
            'invite_state': <String, Object?>{
              'events': <Object?>[if (create != null) _create(room, create), _member('invite', direct: direct)],
            },
          },
        },
      },
    };

/// Beigetretener Raum mit Verschlüsselung und (optional) Buch-Kennzeichen im Zustand. Zustandsereignisse im Sync
/// brauchen Kennung und Zeit (anders als gestrippte Einladungsereignisse).
Map<String, Object?> _joined(String room, {Map<String, Object?> create = const <String, Object?>{}}) {
  var n = 0;
  Map<String, Object?> full(Map<String, Object?> e) => <String, Object?>{...e, 'event_id': '\$s${n++}', 'origin_server_ts': 1700000000000 + n};
  return <String, Object?>{
    'rooms': <String, Object?>{
      'join': <String, Object?>{
        room: <String, Object?>{
          'state': <String, Object?>{
            'events': <Object?>[
              full(_create(room, create)),
              full(<String, Object?>{
                'type': 'm.room.encryption',
                'state_key': '',
                'sender': _inviter,
                'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'},
              }),
              full(_member('join')),
            ],
          },
        },
      },
    },
  };
}

class _Hs {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
  final List<(String, String)> bodies = <(String, String)>[];
  void Function(String room)? onJoin;
  Completer<void> release = Completer<void>();
  int _syncs = 0;

  Iterable<http.BaseRequest> where(String method, String part) => requests.where((r) => r.method == method && r.url.path.contains(part));

  http.Client get client => MockClient.streaming((req, body) async {
        final text = utf8.decode(await body.expand((e) => e).toList());
        requests.add(req);
        bodies.add((req.url.path, text));
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
          if (_syncs++ > 0) await release.future;
          return _json(<String, Object?>{'next_batch': 's$_syncs'});
        }
        final joinMatch = RegExp(r'/rooms/([^/]+)/join$').firstMatch(path);
        if (joinMatch != null) {
          final room = Uri.decodeComponent(joinMatch.group(1)!);
          onJoin?.call(room);
          return _json(<String, Object?>{'room_id': room});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<(_Hs, SdkMatrixGateway)> _signedIn() async {
  final hs = _Hs();
  final dir = await Directory.systemTemp.createTemp('fn_book');
  addTearDown(() => dir.delete(recursive: true));
  final g = SdkMatrixGateway(
    keyStore: MemoryKeyStore(),
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
    joinOpTimeout: const Duration(milliseconds: 500),
    joinPollInterval: const Duration(hours: 1),
  );
  addTearDown(() async {
    if (!hs.release.isCompleted) hs.release.complete();
    await g.close();
  });
  await g.restore();
  await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n2', password: 'geheim123');
  await Future<void>.delayed(_settle);
  return (hs, g);
}

Future<void> _sync(SdkMatrixGateway g, Map<String, Object?> update) =>
    g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}', ...update}));

/// Beitritt aus Sicht des SDK: Sync mit dem Raum und danach „Sync beendet“ (`waitForRoomInSync` wartet auf beides).
Future<void> _syncJoined(SdkMatrixGateway g, Map<String, Object?> update) async {
  await _sync(g, update);
  // `waitForRoomInSync` hört erst nach dem Sync-Ereignis auf den Status: ein sofort gesendeter ginge verloren.
  await Future<void>.delayed(const Duration(milliseconds: 80));
  g.sdkClient!.onSyncStatus.add(const SyncStatusUpdate(SyncStatus.finished));
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('Einladungsliste', () {
    test('Familieneinladung erscheint, Buch-Einladung (jeder Wert des Kennzeichens), Einzelchat nicht', () async {
      final (_, g) = await _signedIn();
      await _sync(g, _invite(_family, create: <String, Object?>{}));
      expect(g.invitations.map((i) => i.roomId), <String>[_family], reason: 'Kontrollfall: normale Familieneinladung');
      await _sync(g, _invite(_book, create: BookRoomMarker.cashCreationContent(_family)));
      await _sync(g, _invite('!x:hs.example', create: <String, Object?>{BookRoomMarker.bookKey: 'anderes'}));
      await _sync(g, _invite('!y:hs.example', create: <String, Object?>{BookRoomMarker.bookKey: null}));
      await _sync(g, _invite(_dm, direct: true));
      expect(g.invitations.map((i) => i.roomId), <String>[_family]);
    });

    test('Einladung ohne gestrippte Create sieht wie eine Familieneinladung aus (Verfügbarkeitsgrenze, E-113)', () async {
      final (_, g) = await _signedIn();
      await _sync(g, _invite(_book));
      expect(g.invitations.map((i) => i.roomId), <String>[_book]);
    });
  });

  group('acceptInvitation', () {
    test('Raum mit Buch-Kennzeichen: notAllowed, nichts geschrieben, kein Beitritt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _invite(_book, create: BookRoomMarker.cashCreationContent(_family)));
      final before = hs.requests.length;
      await expectLater(
        g.acceptInvitation(_book),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      expect(hs.requests.length, before, reason: 'weder Familienvermerk noch Beitritt');
      expect(hs.where('POST', '/join'), isEmpty);
    });

    test('Buch-Einladung bei bestehender Familie: ebenfalls notAllowed (die Buch-Prüfung kommt vor alreadyExists), nichts geschrieben', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _joined(_family));
      g.sdkClient!.accountData['de.inneso.familynexus.family'] = BasicEvent(type: 'de.inneso.familynexus.family', content: <String, Object?>{'room_id': _family});
      await _sync(g, _invite(_book, create: BookRoomMarker.cashCreationContent(_family)));
      final before = hs.requests.length;
      await expectLater(
        g.acceptInvitation(_book),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      expect(hs.requests.length, before);
    });

    test('Fail-safe: Einladung ohne Create, nach dem Beitritt zeigt sich das Buch: Raum verlassen, Vermerk zurückgesetzt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _invite(_book));
      hs.onJoin = (room) => Timer(const Duration(milliseconds: 100), () => unawaited(_syncJoined(g, _joined(room, create: BookRoomMarker.cashCreationContent(_family)))));
      await expectLater(
        g.acceptInvitation(_book),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      expect(hs.where('POST', '/leave'), isNotEmpty, reason: 'Raum verlassen');
      final pointer = hs.bodies.where((b) => b.$1.contains('de.inneso.familynexus.family')).toList();
      expect(pointer, hasLength(2), reason: 'erst gesetzt, dann zurückgesetzt');
      expect((json.decode(pointer.first.$2) as Map)['room_id'], _book);
      expect(json.decode(pointer.last.$2), isEmpty, reason: 'Familienvermerk wie vorher (leer)');
    });

    test('Kontrollfall: dieselbe Abfolge mit einem Familienraum ohne Buch-Kennzeichen nimmt die Einladung an', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _invite(_family, create: <String, Object?>{}));
      hs.onJoin = (room) => Timer(const Duration(milliseconds: 100), () => unawaited(_syncJoined(g, _joined(room))));
      try {
        await g.acceptInvitation(_family);
      } on GatewayException catch (e) {
        expect(e.error, isNot(GatewayError.notAllowed), reason: 'kein Buch');
      }
      expect(hs.where('POST', '/leave'), isEmpty, reason: 'nicht verlassen');
      final pointer = hs.bodies.where((b) => b.$1.contains('de.inneso.familynexus.family')).toList();
      expect((json.decode(pointer.first.$2) as Map)['room_id'], _family);
    });
  });
}
