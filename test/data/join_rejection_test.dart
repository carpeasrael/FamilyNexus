// Ablehnungs-Erkennung des SdkMatrixGateway gegen nachgestellte Serverantworten (#116, #75, E-81).
// Läuft ohne vodozemac in der CI. Echtzeit mit kurzen Werten statt `fakeAsync`, weil die FFI-Datenbank
// dort nicht fortschreitet. `set_presence=offline` trennt die Abfragen von der Sync-Schleife des SDK.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show MatrixException, SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

const String _me = '@n2:hs.example';
const String _room = '!familie:hs.example';
const String _otherRoom = '!andere:hs.example';
const Duration _settle = Duration(milliseconds: 350);

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

/// Antwort, deren Kopfzeilen da sind, deren Körper aber nie endet.
http.StreamedResponse _hanging(int status, {void Function()? onCancel}) =>
    http.StreamedResponse(StreamController<List<int>>(onCancel: onCancel).stream, status);

Map<String, Object?> _kick({Object? prev = 'knock', String sender = '@mod:hs.example', String stateKey = _me, String room = _room}) =>
    <String, Object?>{
      'rooms': <String, Object?>{
        'leave': <String, Object?>{
          room: <String, Object?>{
            'timeline': <String, Object?>{
              'events': <Object?>[
                <String, Object?>{
                  'type': 'm.room.member',
                  'state_key': stateKey,
                  'sender': sender,
                  'event_id': r'$kick',
                  'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                  'content': <String, Object?>{'membership': 'leave'},
                  'unsigned': <String, Object?>{
                    if (prev != null) 'prev_content': <String, Object?>{'membership': prev},
                  },
                },
              ],
            },
          },
        },
      },
    };

Map<String, Object?> _section(String section) => <String, Object?>{
      'rooms': <String, Object?>{
        section: <String, Object?>{_room: <String, Object?>{}},
      },
    };

/// Nachgestellter Homeserver `https://hs.example`. [onPoll] beantwortet die Ablehnungs-Abfragen.
class _Hs {
  FutureOr<http.StreamedResponse> Function(http.BaseRequest req) onPoll = (_) => _json(_section('knock'));
  FutureOr<http.StreamedResponse> Function(http.BaseRequest req) onKnock = (_) => _json(<String, Object?>{'room_id': _room});
  Map<String, Object?> loginExtra = const <String, Object?>{};
  Future<http.StreamedResponse>? onRefresh;

  final List<http.BaseRequest> polls = <http.BaseRequest>[];
  final Completer<void> _release = Completer<void>();
  int _syncs = 0;

  /// Räume, nach denen gefragt wurde.
  List<Object?> get polledRooms => <Object?>[
        for (final p in polls) ...((json.decode(p.url.queryParameters['filter']!) as Map)['room'] as Map)['rooms'] as List,
      ];

  void releaseSync() {
    if (!_release.isCompleted) _release.complete();
  }

  http.Client get client => MockClient.streaming((req, body) async {
        final path = req.url.path;
        if (path == '/_matrix/client/versions') return _json(<String, Object?>{'versions': <String>['v1.1', 'v1.11']});
        if (path == '/_matrix/client/v3/login') {
          if (req.method == 'POST') {
            return _json(<String, Object?>{'user_id': _me, 'access_token': 'tok', 'device_id': 'DEV1', ...loginExtra});
          }
          return _json(<String, Object?>{
            'flows': <Object?>[<String, Object?>{'type': 'm.login.password'}],
          });
        }
        if (path == '/_matrix/client/v3/refresh' && onRefresh != null) return onRefresh!;
        if (path.endsWith('/filter')) return _json(<String, Object?>{'filter_id': '1'});
        if (path == '/_matrix/client/v3/sync') {
          if (req.url.queryParameters['set_presence'] == 'offline') {
            polls.add(req);
            return await onPoll(req);
          }
          // Die Sync-Schleife des SDK steht nach der ersten Antwort, bis der Test endet.
          if (_syncs++ > 0) await _release.future;
          return _json(<String, Object?>{'next_batch': 's$_syncs'});
        }
        if (path.contains('/knock/')) return await onKnock(req);
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<(_Hs, SdkMatrixGateway)> _signedIn({
  _Hs? server,
  Duration opTimeout = const Duration(milliseconds: 150),
  Duration interval = const Duration(hours: 1),
  bool autoClose = true,
}) async {
  final hs = server ?? _Hs();
  final dir = await Directory.systemTemp.createTemp('fn_rej');
  addTearDown(() => dir.delete(recursive: true));
  final g = SdkMatrixGateway(
    keyStore: MemoryKeyStore(),
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
    joinOpTimeout: opTimeout,
    joinPollInterval: interval,
  );
  if (autoClose) {
    addTearDown(() async {
      hs.releaseSync();
      await g.close();
    });
  }
  await g.restore();
  await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n2', password: 'geheim123');
  await Future<void>.delayed(_settle);
  return (hs, g);
}

Future<void> _until(bool Function() cond) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Bedingung nicht erreicht');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _sync(SdkMatrixGateway g, Map<String, Object?> update) =>
    g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}', ...update}));

Future<void> _syncLeave(SdkMatrixGateway g, [String room = _room]) => _sync(g, <String, Object?>{
      'rooms': <String, Object?>{
        'leave': <String, Object?>{room: <String, Object?>{}},
      },
    });

/// Vermerk der Anfrage, wie ihn der Sync aus den Kontodaten liefert.
Future<void> _syncNote(SdkMatrixGateway g, String room, int ts) => _sync(g, <String, Object?>{
      'account_data': <String, Object?>{
        'events': <Object?>[
          <String, Object?>{
            'type': SdkMatrixGateway.joinRequestAccountData,
            'content': <String, Object?>{'room_id': room, 'ts': ts},
          },
        ],
      },
    });

/// Offene Anfrage mit Zeitgeber: Ohne ihn erzeugte `_refreshOnce` nach dem Sync zusätzlich den Sofort-Poll.
Future<(_Hs, SdkMatrixGateway)> _armed() async {
  final (hs, g) = await _signedIn();
  await g.requestToJoinByCode(_room);
  await Future<void>.delayed(_settle);
  expect(g.rejectionTimerActive, isTrue);
  expect(hs.polls, isEmpty);
  return (hs, g);
}

/// Hält die nächste Abfrage an, bis der Test den Completer erfüllt.
Completer<http.StreamedResponse> _holdPoll(_Hs hs) {
  final held = Completer<http.StreamedResponse>();
  hs.onPoll = (_) => held.future;
  return held;
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('Zeitschranken (#116)', () {
    test('hängender Antwortkörper: Die Abfrage endet, die nächste läuft', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => _hanging(200);
      await g.pollRejectionForTest().timeout(const Duration(seconds: 3));
      expect(g.joinRequestDiagnostic, contains('Zustand: timeout(body)'));
      expect(g.joinRequestDiagnostic, contains('body=1'));

      hs.onPoll = (_) => _json(_section('knock'));
      await g.pollRejectionForTest().timeout(const Duration(seconds: 3));
      expect(hs.polls, hasLength(2));
      expect(g.joinRequestDiagnostic, contains('Zustand: knock'));
    });

    test('keine Kopfzeilen: Zustand timeout(headers)', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => Completer<http.StreamedResponse>().future;
      await g.pollRejectionForTest().timeout(const Duration(seconds: 3));
      expect(g.joinRequestDiagnostic, contains('Zustand: timeout(headers)'));
      expect(g.joinRequestDiagnostic, contains('headers=1'));
    });

    test('hängendes /refresh: Zustand timeout(auth) statt Stillstand', () async {
      final hs = _Hs()
        ..loginExtra = <String, Object?>{'expires_in_ms': 1000, 'refresh_token': 'ref'}
        ..onRefresh = Completer<http.StreamedResponse>().future;
      final (_, g) = await _signedIn(server: hs);
      // Der Vermerk kommt aus dem Sync; `_knock` scheiterte hier selbst an der Zeitschranke.
      await _syncNote(g, _room, DateTime.now().millisecondsSinceEpoch);
      await _until(() => g.joinRequestDiagnostic.contains('Zustand: timeout(auth)'));
      expect(hs.polls, isEmpty);
    });

    test('Knock: hängender Körper bei Status 200 gilt als Erfolg und wird verworfen', () async {
      final (hs, g) = await _signedIn();
      var cancelled = false;
      hs.onKnock = (_) => _hanging(200, onCancel: () => cancelled = true);
      await g.requestToJoinByCode(_room).timeout(const Duration(seconds: 3));
      expect(g.joinRequestPending, isTrue);
      await _until(() => cancelled);
    });

    test('Knock: hängender Körper bei einem Fehlerstatus endet als Fehler', () async {
      final (hs, g) = await _signedIn();
      hs.onKnock = (_) => _hanging(403);
      await expectLater(g.requestToJoinByCode(_room).timeout(const Duration(seconds: 3)), throwsA(isNot(isA<TimeoutException>())));
      expect(g.joinRequestPending, isFalse);
    });
  });

  group('Sync als Auslöser (#116)', () {
    test('leave im Sync löst eine Abfrage aus und die Ablehnung wird erkannt', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => _json(_kick());
      await _syncLeave(g);
      await _until(() => g.joinRequestRejected);
      expect(hs.polls, hasLength(1));
      expect(g.joinRequestDiagnostic, contains('Zustand: leaveRejected'));
      expect(g.joinRequestDiagnostic, contains('Auslöser: sync'));
      expect(g.joinRequestDiagnostic, isNot(contains('Erkannt: -')));
      expect(g.joinRequestDiagnostic, contains('Timer aktiv: nein'));
    });

    test('altes leave bei offener neuer Anfrage: Abfrage läuft, kein Alarm', () async {
      final (hs, g) = await _armed();
      await _syncLeave(g);
      await _until(() => g.joinRequestDiagnostic.contains('Zustand: knock'));
      expect(hs.polls, hasLength(1));
      expect(g.joinRequestRejected, isFalse);
      expect(g.joinRequestPending, isTrue);
    });

    test('keine offene Anfrage: keine Abfrage', () async {
      final (hs, g) = await _signedIn();
      await _syncLeave(g);
      await Future<void>.delayed(_settle);
      expect(hs.polls, isEmpty);
      expect(g.rejectionTimerActive, isFalse);
    });

    test('anderer Raum: keine Abfrage', () async {
      final (hs, g) = await _armed();
      await _syncLeave(g, _otherRoom);
      await Future<void>.delayed(_settle);
      expect(hs.polls, isEmpty);
    });

    test('Auslöser während laufender Abfrage: genau eine Wiederholung', () async {
      final (hs, g) = await _armed();
      final held = _holdPoll(hs);
      await _syncLeave(g);
      await _until(() => hs.polls.length == 1);
      await _syncLeave(g);
      await _syncLeave(g);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(hs.polls, hasLength(1));

      hs.onPoll = (_) => _json(_kick());
      held.complete(_json(_section('knock')));
      await _until(() => g.joinRequestRejected);
      await Future<void>.delayed(_settle);
      expect(hs.polls, hasLength(2));
    });

    test('wiederholtes Update ist unschädlich', () async {
      final (hs, g) = await _armed();
      await _syncLeave(g);
      await _until(() => hs.polls.length == 1 && g.joinRequestDiagnostic.contains('Zustand: knock'));
      await _syncLeave(g);
      await _until(() => hs.polls.length == 2);
      await Future<void>.delayed(_settle);
      expect(g.joinRequestRejected, isFalse);
      expect(g.joinRequestPending, isTrue);
    });

    test('nach erkannter Ablehnung keine weitere Abfrage', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => _json(_kick());
      await _syncLeave(g);
      await _until(() => g.joinRequestRejected);
      await _syncLeave(g);
      await Future<void>.delayed(_settle);
      expect(hs.polls, hasLength(1));
    });
  });

  group('Veraltete Antworten (#116)', () {
    test('Rückzug und neue Anfrage überholen die laufende Abfrage: kein Alarm', () async {
      final (hs, g) = await _armed();
      final held = _holdPoll(hs);
      final poll = g.pollRejectionForTest();
      await _until(() => hs.polls.length == 1);
      await g.cancelJoinRequest();
      await g.requestToJoinByCode(_room);
      held.complete(_json(_kick()));
      await poll;
      expect(g.joinRequestRejected, isFalse);
      expect(g.joinRequestPending, isTrue);
      expect(g.joinRequestDiagnostic, isNot(contains('leaveRejected')));
    });

    test('stehender Sync: alter Vermerk, neue Anfrage in anderem Raum: kein Alarm', () async {
      final (hs, g) = await _signedIn();
      await _syncNote(g, _otherRoom, DateTime.now().millisecondsSinceEpoch - 60000);
      await _until(() => hs.polls.length == 1);
      await Future<void>.delayed(_settle);
      await g.requestToJoinByCode(_room);
      hs.onPoll = (_) => _json(_kick(room: _otherRoom));

      await g.pollRejectionForTest();
      await _syncLeave(g, _otherRoom);
      await Future<void>.delayed(_settle);
      expect(hs.polls, hasLength(1));
      expect(g.joinRequestRejected, isFalse);
      expect(g.joinRequestDiagnostic, contains('Zustand: staleNote'));
    });

    test('zwei Geräte: Ein neuerer Vermerk gewinnt gegen die lokale Anfrage', () async {
      final (hs, g) = await _armed();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await _syncNote(g, _otherRoom, DateTime.now().millisecondsSinceEpoch);
      await g.pollRejectionForTest();
      expect(hs.polledRooms, <Object?>[_otherRoom]);
      expect(g.joinRequestDiagnostic, isNot(contains('staleNote')));
    });
  });

  group('Zeitgeber (#116)', () {
    test('dispose stoppt die Abfragen', () async {
      final (hs, g) = await _signedIn(interval: const Duration(milliseconds: 40), autoClose: false);
      await g.requestToJoinByCode(_room);
      await _until(() => hs.polls.isNotEmpty);
      hs.releaseSync();
      g.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final after = hs.polls.length;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(hs.polls, hasLength(after));
    });

    test('close stoppt den Zeitgeber', () async {
      final (hs, g) = await _armed();
      hs.releaseSync();
      await g.close();
      expect(g.rejectionTimerActive, isFalse);
    });
  });

  group('Sofort-Abfrage (#116)', () {
    test('Vermerk ohne Zeitgeber: genau eine Abfrage ohne Warten', () async {
      final (hs, g) = await _signedIn();
      await _syncNote(g, _room, DateTime.now().millisecondsSinceEpoch);
      await _until(() => hs.polls.isNotEmpty);
      await Future<void>.delayed(_settle);
      expect(hs.polls, hasLength(1));
      expect(g.rejectionTimerActive, isTrue);
      expect(g.joinRequestDiagnostic, contains('Auslöser: start'));
    });

    test('nach dem Knock keine Sofort-Abfrage', () async {
      final (hs, g) = await _armed();
      await _sync(g, const <String, Object?>{});
      await Future<void>.delayed(_settle);
      expect(hs.polls, isEmpty);
    });

    test('nach erkannter Ablehnung kein neuer Zeitgeber', () async {
      final (hs, g) = await _signedIn();
      hs.onPoll = (_) => _json(_kick());
      await _syncNote(g, _room, DateTime.now().millisecondsSinceEpoch);
      await _until(() => g.joinRequestRejected);
      expect(g.rejectionTimerActive, isFalse);
      await _sync(g, const <String, Object?>{});
      await Future<void>.delayed(_settle);
      expect(g.rejectionTimerActive, isFalse);
      expect(hs.polls, hasLength(1));
    });
  });

  group('Diagnose (#116)', () {
    final leaks = RegExp(r'[!@]|hs\.example|tok');

    test('Ausnahme mit Raum-ID im Text: Die Ausgabe enthält weder Text noch ID', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => throw http.ClientException('kaputt $_room $_me');
      await g.pollRejectionForTest();
      expect(g.joinRequestDiagnostic, contains('Zustand: failed(client)'));
      expect(leaks.hasMatch(g.joinRequestDiagnostic), isFalse);
    });

    test('Zeitüberschreitung mit Raum-ID im Text: nur die Phase', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => throw TimeoutException('kaputt $_room');
      await g.pollRejectionForTest();
      expect(g.joinRequestDiagnostic, contains('Zustand: timeout(headers)'));
      expect(leaks.hasMatch(g.joinRequestDiagnostic), isFalse);
    });

    test('MXID in prev_content.membership wird zu other', () async {
      final (hs, g) = await _armed();
      hs.onPoll = (_) => _json(_kick(prev: '@boese:hs.example', sender: _me));
      await g.pollRejectionForTest();
      final d = g.joinRequestDiagnostic;
      expect(d, contains('Zustand: leaveOther'));
      expect(d, contains('membership: leave'));
      expect(d, contains('vorher: other'));
      expect(d, contains('eigen: ja'));
      expect(d, contains('Versatz: '));
      expect(leaks.hasMatch(d), isFalse);
    });

    test('Mitgliedschaft nur aus der festen Liste', () {
      for (final m in <String>['join', 'knock', 'invite', 'leave', 'ban']) {
        expect(SdkMatrixGateway.membershipLabel(m), m);
      }
      expect(SdkMatrixGateway.membershipLabel(null), '-');
      expect(SdkMatrixGateway.membershipLabel('!raum:hs.example'), 'other');
      expect(SdkMatrixGateway.membershipLabel(7), 'other');
    });

    test('Fehlerklassen in fester Reihenfolge', () {
      expect(SdkMatrixGateway.failureClass(const _ClientSocketError()), 'socket');
      expect(SdkMatrixGateway.failureClass(const SocketException('x')), 'socket');
      expect(SdkMatrixGateway.failureClass(const HandshakeException('x')), 'tls');
      expect(SdkMatrixGateway.failureClass(const TlsException('x')), 'tls');
      expect(SdkMatrixGateway.failureClass(const FormatException('x')), 'format');
      expect(SdkMatrixGateway.failureClass(MatrixException(http.Response('{}', 500))), 'matrix');
      expect(SdkMatrixGateway.failureClass(http.ClientException('x')), 'client');
      expect(SdkMatrixGateway.failureClass(StateError('x')), 'other');
    });

    test('Zustände der Antworten', () async {
      final (hs, g) = await _armed();
      Future<void> expectState(http.StreamedResponse Function() response, String state) async {
        hs.onPoll = (_) => response();
        await g.pollRejectionForTest();
        expect(g.joinRequestDiagnostic, contains('Zustand: $state'));
      }

      await expectState(() => _json(_section('invite')), 'invite');
      await expectState(() => _json(_section('join')), 'join');
      await expectState(() => _json(<String, Object?>{'rooms': <String, Object?>{}}), 'noRoom');
      await expectState(() => _json(<String, Object?>{'errcode': 'M_UNKNOWN'}, 503), 'http(503)');
      await expectState(() => _json(_kick(stateKey: '@wer:hs.example')), 'leaveNoOwnEvent');
      await expectState(() => http.StreamedResponse(Stream<List<int>>.value(utf8.encode('kein json')), 200), 'failed(format)');
      expect(g.joinRequestDiagnostic, contains('Abfragen: 6'));
      expect(g.joinRequestRejected, isFalse);
    });

    test('kein https: notHttps', () async {
      final (hs, g) = await _armed();
      g.sdkClient!.homeserver = Uri.parse('http://hs.example');
      await g.pollRejectionForTest();
      expect(hs.polls, isEmpty);
      expect(g.joinRequestDiagnostic, contains('Zustand: notHttps'));
      g.sdkClient!.homeserver = Uri.parse('https://hs.example');
    });
  });
}

/// Wie `_ClientSocketException` des http-Pakets: beides zugleich.
class _ClientSocketError implements http.ClientException, SocketException {
  const _ClientSocketError();

  @override
  String get message => 'x';

  @override
  Uri? get uri => null;

  @override
  InternetAddress? get address => null;

  @override
  OSError? get osError => null;

  @override
  int? get port => null;
}
