// Buch-Sync des SdkMatrixGateway (Kassenbuch, #311, E-113, Teil 2c) gegen einen nachgestellten Homeserver: Mitglieder
// frisch vom Server, Sendeschutz beim Senden, Signale je Buch, Abbau. Läuft ohne vodozemac (Naht `requireEncryptionForBooks`).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/book_room.dart';
import 'package:family_nexus/domain/book_signal.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show Event, SyncStatus, SyncStatusUpdate, SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

const String _me = '@n2:hs.example';
const String _cara = '@cara:hs.example';
const String _ben = '@ben:hs.example';
const String _fremd = '@fremd:hs.example';
const String _dora = '@dora:hs.example';
const String _familyRoom = '!familie:hs.example';
const String _book = '!buch:hs.example';
const Duration _settle = Duration(milliseconds: 350);

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

int _n = 0;
Map<String, Object?> _state(String type, String sender, Map<String, Object?> content, {String key = ''}) => <String, Object?>{
      'type': type,
      'state_key': key,
      'sender': sender,
      'content': content,
      'event_id': '\$e${_n++}',
      'origin_server_ts': 1700000000000 + _n,
    };

Map<String, Object?> _memberEvent(String id, String membership, {String? sender}) =>
    _state('m.room.member', sender ?? id, <String, Object?>{'membership': membership, 'displayname': id}, key: id);

/// Familienraum: ich Moderator (100), Cara Moderatorin (50), Ben Mitglied (0), dazu der Vermerk in den Kontodaten.
Map<String, Object?> _familySync() => <String, Object?>{
      'account_data': <String, Object?>{
        'events': <Object?>[
          <String, Object?>{'type': 'de.inneso.familynexus.family', 'content': <String, Object?>{'room_id': _familyRoom}},
        ],
      },
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _familyRoom: <String, Object?>{
            'state': <String, Object?>{
              'events': <Object?>[
                _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
                _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
                _state('m.room.name', _me, <String, Object?>{'name': 'Familie'}),
                _state('m.room.power_levels', _me, <String, Object?>{
                  'users': <String, int>{_me: 100, _cara: 50, _dora: 50},
                  'users_default': 0,
                  'state_default': 50,
                  'invite': 50,
                  'kick': 50,
                }),
                _memberEvent(_me, 'join'),
                _memberEvent(_cara, 'join'),
                _memberEvent(_ben, 'join'),
                _memberEvent(_dora, 'invite', sender: _me),
              ],
            },
          },
        },
      },
    };

Map<String, Object?> _bookPl(String creator, {int invite = 100}) => <String, Object?>{
      'users': <String, int>{creator: 100},
      'users_default': 0,
      'events_default': 0,
      'state_default': 100,
      'invite': invite,
      'kick': 100,
      'ban': 100,
      'redact': 100,
    };

/// Beigetretenes Buch mit Zustand wie `BookRoomSpec` ihn erzeugt (anpassbar für Abweichungen).
Map<String, Object?> _bookJoin(String room, {String creator = _me, Map<String, Object?>? pl, List<String> members = const <String>[], String family = _familyRoom, bool marker = true, bool summary = false}) =>
    <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          room: <String, Object?>{
            if (summary) 'summary': <String, Object?>{'m.joined_member_count': 1 + members.length, 'm.invited_member_count': 0},
            'state': <String, Object?>{
              'events': <Object?>[
                _state('m.room.create', creator, <String, Object?>{
                  'room_version': '10',
                  if (marker) ...BookRoomMarker.cashCreationContent(family),
                }),
                _state('m.room.encryption', creator, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
                _state('m.room.history_visibility', creator, <String, Object?>{'history_visibility': 'shared'}),
                _state('m.room.join_rules', creator, <String, Object?>{'join_rule': 'invite'}),
                _state('m.room.power_levels', creator, pl ?? _bookPl(creator)),
                _memberEvent(_me, 'join'),
                for (final m in members) _memberEvent(m, 'join'),
              ],
            },
          },
        },
      },
    };

class _Hs {
  final List<(String, String, String)> calls = <(String, String, String)>[]; // Methode, Pfad, Körper
  Completer<void> release = Completer<void>();
  int _syncs = 0;
  void Function(String room)? onJoin;
  List<String> members = <String>[];
  Set<String> left = <String>{};

  /// Weitere Mitgliedschaften auf dem Server (`invite`, `ban`, ...), Schlüssel Nutzer-ID.
  final Map<String, String> extra = <String, String>{};

  /// Die Mitgliederliste des Buchs ist leer (unbrauchbare Antwort).
  bool emptyMembers = false;

  /// Antwort auf `/messages`: `create` (das Raum-Ereignis, Ende des Verlaufs), `endless` (immer eine weitere Seite).
  String messagesMode = 'create';
  int messagesCalls = 0;

  /// Gesendete Ereignisse (Pfad, Körper); nach [sendOkCount] Sendungen scheitern weitere.
  final List<(String, String)> sends = <(String, String)>[];
  int? sendOkCount;
  String createdRoom = _book;

  /// Der Server antwortet auf die Mitgliederliste der Familie mit einem Fehler (Teilliste, `_participantsLoaded` bleibt aus).
  bool familyMembersFail = false;

  /// Der Server lehnt Push-Regeln ab.
  bool pushRulesFail = false;

  /// Zustandsereignisse, die der Server auf `GET /rooms/{id}/state/{type}/` liefert (Schlüssel `Raum|Typ`).
  final Map<String, Map<String, Object?>> serverState = <String, Map<String, Object?>>{};

  /// Zustand eines korrekt angelegten Buchs (wie `BookRoomSpec` ihn erzeugt), Power-Levels anpassbar.
  void serveBook(String room, String creator, {Map<String, Object?>? pl}) {
    serverState['$room|m.room.encryption'] = <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'};
    serverState['$room|m.room.history_visibility'] = <String, Object?>{'history_visibility': 'shared'};
    serverState['$room|m.room.join_rules'] = <String, Object?>{'join_rule': 'invite'};
    serverState['$room|m.room.power_levels'] = pl ?? _bookPl(creator);
  }

  Iterable<(String, String, String)> where(String method, String part) => calls.where((c) => c.$1 == method && c.$2.contains(part));

  http.Client get client => MockClient.streaming((req, body) async {
        final text = utf8.decode(await body.expand((e) => e).toList());
        final path = Uri.decodeFull(req.url.path);
        calls.add((req.method, path, text));
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
        if (path == '/_matrix/client/v3/createRoom') return _json(<String, Object?>{'room_id': createdRoom});
        final join = RegExp(r'/rooms/([^/]+)/join$').firstMatch(path);
        if (join != null) {
          onJoin?.call(join.group(1)!);
          return _json(<String, Object?>{'room_id': join.group(1)});
        }
        if (path.endsWith('/members')) {
          if (familyMembersFail && path.contains(_familyRoom)) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'Fehler'}, 500);
          if (emptyMembers && !path.contains(_familyRoom)) return _json(<String, Object?>{'chunk': <Object?>[]});
          return _json(<String, Object?>{
            'chunk': <Object?>[
              for (final e in extra.entries)
                <String, Object?>{
                  'type': 'm.room.member',
                  'state_key': e.key,
                  'sender': e.key,
                  'content': <String, Object?>{'membership': e.value},
                  'event_id': '\$x${_n++}',
                  'origin_server_ts': 1700000000000 + _n,
                  'room_id': _book,
                },
              for (final m in <String>[...members, ...left])
                <String, Object?>{
                  'type': 'm.room.member',
                  'state_key': m,
                  'sender': m,
                  'content': <String, Object?>{'membership': left.contains(m) ? 'leave' : 'join'},
                  'event_id': '\$m${_n++}',
                  'origin_server_ts': 1700000000000 + _n,
                  'room_id': _book,
                },
            ],
          });
        }
        final st = RegExp(r'/rooms/([^/]+)/state/([^/]+)/?$').firstMatch(path);
        if (st != null && req.method == 'GET') {
          final content = serverState['${st.group(1)}|${st.group(2)}'];
          if (content != null) return _json(content);
          return _json(<String, Object?>{'errcode': 'M_NOT_FOUND', 'error': 'nicht vorhanden'}, 404);
        }
        if (path.endsWith('/messages')) {
          messagesCalls++;
          final room = RegExp(r'/rooms/([^/]+)/messages').firstMatch(path)!.group(1)!;
          if (messagesMode == 'endless') {
            return _json(<String, Object?>{
              'start': 's$messagesCalls',
              'end': 'p$messagesCalls',
              'chunk': <Object?>[
                <String, Object?>{
                  'type': 'm.room.message',
                  'event_id': '\$old$messagesCalls',
                  'sender': _me,
                  'origin_server_ts': 1600000000000 - messagesCalls,
                  'room_id': room,
                  'content': <String, Object?>{'msgtype': 'm.text', 'body': 'alt'},
                },
              ],
            });
          }
          return _json(<String, Object?>{
            'start': 'a',
            'chunk': <Object?>[
              <String, Object?>{
                'type': 'm.room.create',
                'state_key': '',
                'sender': _me,
                'content': <String, Object?>{'room_version': '10'},
                'event_id': '\$create',
                'origin_server_ts': 1,
                'room_id': room,
              },
            ],
          });
        }
        if (req.method == 'PUT' && path.contains('/send/')) {
          sends.add((path, text));
          if (sendOkCount != null && sends.length > sendOkCount!) return _json(<String, Object?>{'errcode': 'M_FORBIDDEN', 'error': 'nein'}, 403);
          return _json(<String, Object?>{'event_id': '\$sent${sends.length}'});
        }
        if (pushRulesFail && path.contains('/pushrules/')) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'Fehler'}, 500);
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

/// [enabled] `null`: der eingebaute Standard (gesperrt) ohne Parameter. [familySynced] `false`: keine Familie bekannt.
Future<(_Hs, SdkMatrixGateway)> _signedIn({
  bool? enabled = true,
  bool familySynced = true,
  bool familyMembersFail = false,
  bool requireEncryption = false,
}) async {
  final hs = _Hs()..familyMembersFail = familyMembersFail;
  final dir = await Directory.systemTemp.createTemp('fn_bookgw');
  addTearDown(() => dir.delete(recursive: true));
  SdkMatrixGateway make({bool? flag}) => flag == null
      ? SdkMatrixGateway(
          keyStore: MemoryKeyStore(),
          dbDirectory: dir.path,
          probe: ServerProbe(client: hs.client),
          databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
          httpClient: hs.client,
          joinOpTimeout: const Duration(milliseconds: 800),
          joinPollInterval: const Duration(hours: 1),
          requireEncryptionForBooks: requireEncryption,
        )
      : SdkMatrixGateway(
          keyStore: MemoryKeyStore(),
          dbDirectory: dir.path,
          probe: ServerProbe(client: hs.client),
          databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
          httpClient: hs.client,
          joinOpTimeout: const Duration(milliseconds: 800),
          joinPollInterval: const Duration(hours: 1),
          cashBooksEnabled: flag,
          requireEncryptionForBooks: requireEncryption,
        );
  final g = make(flag: enabled);
  addTearDown(() async {
    if (!hs.release.isCompleted) hs.release.complete();
    await g.close();
  });
  await g.restore();
  await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n2', password: 'geheim123');
  await Future<void>.delayed(_settle);
  if (familySynced) {
    await _sync(g, _familySync());
    await Future<void>.delayed(_settle);
  }
  return (hs, g);
}

Future<void> _sync(SdkMatrixGateway g, Map<String, Object?> update) =>
    g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}', ...update}));

Future<void> _syncJoined(SdkMatrixGateway g, Map<String, Object?> update) async {
  await _sync(g, update);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  g.sdkClient!.onSyncStatus.add(const SyncStatusUpdate(SyncStatus.finished));
}

Matcher _notAllowed() => throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed));

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

Map<String, Object?> _entryContent({String id = '11111111-1111-4111-8111-111111111111', String author = _me, int version = 1, int cents = 100}) => <String, Object?>{
      'v': 1,
      'id': id,
      'author': author,
      'version': version,
      'deleted': false,
      'date': '2026-11-20',
      'store': 'Edeka',
      'amount_cents': cents,
      'note': '',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

Map<String, Object?> _metaContent({int version = 1, String title = 'Haushalt'}) =>
    <String, Object?>{'v': 1, 'title': title, 'currency': 'EUR', 'version': version};

int _eid = 0;

/// Ereignis, das (wie nach der Entschlüsselung) als `m.room.encrypted` angekommen ist.
Event _arrived(SdkMatrixGateway g, String room, String type, String sender, Map<String, Object?> content) {
  final id = '\$ev${_eid++}';
  return Event.fromJson(<String, Object?>{
    'type': type,
    'event_id': id,
    'sender': sender,
    'origin_server_ts': 1700000000000 + _eid,
    'content': content,
    'original_source': <String, Object?>{
      'type': 'm.room.encrypted',
      'event_id': id,
      'sender': sender,
      'origin_server_ts': 1700000000000 + _eid,
      'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
    },
  }, g.sdkClient!.getRoomById(room)!);
}

Event _plain(SdkMatrixGateway g, String room, String type, String sender, Map<String, Object?> content) => Event.fromJson(<String, Object?>{
      'type': type,
      'event_id': '\$pl${_eid++}',
      'sender': sender,
      'origin_server_ts': 1700000000000 + _eid,
      'content': content,
    }, g.sdkClient!.getRoomById(room)!);

void main() {
  setUpAll(sqfliteFfiInit);

  group('gesperrt (Standard): keine Anfrage, kein Signal, keine Warnung', () {
    test('Aufrufe notAllowed/leer, nichts an den Server, Einlesen wirkungslos', () async {
      final (hs, g) = await _signedIn(enabled: false);
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      final before = hs.calls.length;
      await expectLater(g.bookKnownMembers(_book), _notAllowed());
      await expectLater(g.publishBookEvents(_book, <BookOutgoing>[BookOutgoing(CashBookCodec.entryType, _entryContent())]), _notAllowed());
      expect(g.bookRoomGone(_book), isFalse);
      expect(g.bookHistoryComplete(_book), isFalse);
      expect(g.bookUndecryptableCount(_book), 0);
      g.debugIngestBookEvents(_book, _me, <Event>[_arrived(g, _book, CashBookCodec.metaType, _me, _metaContent())]);
      expect(g.debugBookHistory(_book), isEmpty, reason: 'gesperrt: nichts wird eingelesen');
      expect(g.bookRoomGone('!nie:hs.example'), isFalse);
      expect(hs.calls.length, before);
      expect(g.debugBookTimelineIds, isEmpty);
    });

    test('gesperrt: ein Klartext-Buchereignis im Familienraum löst keine Warnung aus, freigeschaltet schon', () async {
      AppLog.capture = true;
      addTearDown(() => AppLog.capture = false);
      Future<int> warnings(bool enabled) async {
        AppLog.captured.clear();
        final (_, g) = await _signedIn(enabled: enabled);
        await _syncJoined(g, <String, Object?>{
          'rooms': <String, Object?>{
            'join': <String, Object?>{
              _familyRoom: <String, Object?>{
                'timeline': <String, Object?>{
                  'events': <Object?>[
                    <String, Object?>{
                      'type': CashBookCodec.entryType,
                      'event_id': '\$plain${_eid++}',
                      'sender': _cara,
                      'origin_server_ts': 1700000000000,
                      'content': _entryContent(author: _cara),
                    },
                  ],
                },
              },
            },
          },
        });
        await Future<void>.delayed(_settle);
        return AppLog.captured.where((l) => l.contains('Klartext')).length;
      }

      expect(await warnings(false), 0);
      expect(await warnings(true), 1);
    });
  });

  group('bookKnownMembers: frisch vom Server', () {
    test('join, leave, invite und ban zählen; wer nie im Raum war, nicht', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara];
      hs.left = <String>{_ben};
      hs.extra[_dora] = 'invite';
      hs.extra[_fremd] = 'ban';
      expect(await g.bookKnownMembers(_book), <String>{_me, _cara, _ben, _dora, _fremd});
      hs.extra.clear();
      expect(await g.bookKnownMembers(_book), <String>{_me, _cara, _ben}, reason: 'jeder Aufruf fragt den Server (kein Zwischenspeicher)');
      expect(hs.where('GET', '/members').where((c) => c.$2.contains(_book)).length, greaterThanOrEqualTo(2));
    });

    test('leere oder unbrauchbare Antwort (ich fehle): gescheitert, nie „keine Mitglieder“', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.emptyMembers = true;
      await expectLater(g.bookKnownMembers(_book), _error(GatewayError.serverUnreachable));
    });

    test('Buch einer anderen Familie, unbekannter Raum, ungültige ID, Einladung statt Beitritt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin('!anderes:hs.example', family: '!andere:hs.example'));
      hs.members = <String>[_me];
      await expectLater(g.bookKnownMembers('!anderes:hs.example'), _notAllowed());
      await expectLater(g.bookKnownMembers('!gibtsnicht:hs.example'), _error(GatewayError.notFound));
      await expectLater(g.bookKnownMembers('kein-raum'), _error(GatewayError.invalidInput));
    });
  });

  group('Sendeschutz, Einladen und Abgleich lesen die Rückgabe des Servers (nicht den lokalen Stand)', () {
    test('Fremder steht nur auf dem Server, lokal unbekannt: verifyBookRecipients verweigert', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara, _fremd];
      await expectLater(g.verifyBookRecipients(_book), _notAllowed());
    });

    test('Abgleich entfernt den nur auf dem Server bekannten Fremden erst im zweiten Durchlauf', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara, _fremd];
      expect(await g.reconcileBook(_book), isEmpty);
      expect(await g.reconcileBook(_book), <String>[_fremd]);
    });

    test('leere Antwort: Sendeschutz wirft, Abgleich entfernt niemanden und setzt zurück, Einladen lädt nicht ein', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara, _fremd];
      expect(await g.reconcileBook(_book), isEmpty); // merkt _fremd
      hs.emptyMembers = true;
      await expectLater(g.verifyBookRecipients(_book), _error(GatewayError.serverUnreachable));
      await expectLater(g.reconcileBook(_book), _error(GatewayError.serverUnreachable));
      await expectLater(g.inviteToBook(_book, _cara), _error(GatewayError.serverUnreachable));
      hs.emptyMembers = false;
      expect(await g.reconcileBook(_book), isEmpty, reason: 'der Abbruch hat das Gemerkte verworfen: wieder erster Durchlauf');
      expect(hs.where('POST', '/kick'), isEmpty);
      expect(hs.where('POST', '/invite'), isEmpty);
    });

    test('eigenes Konto nur eingeladen statt beigetreten: Antwort unbrauchbar (fail-closed)', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_cara];
      hs.extra[_me] = 'invite';
      await expectLater(g.verifyBookRecipients(_book), _error(GatewayError.serverUnreachable));
    });

    test('auch bei vollständiger lokaler Mitgliederliste fragt jeder Aufruf den Server (enforceFetchFromServer)', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara], summary: true));
      hs.members = <String>[_me, _cara];
      await g.verifyBookRecipients(_book);
      hs.members = <String>[_me, _cara, _fremd];
      await expectLater(g.verifyBookRecipients(_book), _notAllowed());
      expect(hs.where('GET', '/members').where((c) => c.$2.contains(_book)), isNotEmpty);
    });

    test('Mitgliedergrenze zählt die Mitglieder vom Server', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book));
      hs.members = <String>[_me, for (var i = 0; i < CashBookLimits.maxMembersPerBook - 1; i++) '@u$i:hs.example'];
      await expectLater(g.inviteToBook(_book, _cara), _error(GatewayError.invalidInput));
    });
  });

  group('publishBookEvents', () {
    BookOutgoing entry({String author = _me, int cents = 100, String id = '11111111-1111-4111-8111-111111111111'}) =>
        BookOutgoing(CashBookCodec.entryType, _entryContent(author: author, cents: cents, id: id));

    Future<(_Hs, SdkMatrixGateway)> ready({String creator = _me}) async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, creator: creator, members: <String>[_cara]));
      hs.members = <String>[_me, _cara];
      return (hs, g);
    }

    test('eigener Eintrag und eigenes Meta (Ersteller): gesendet, Ergebnis je Ereignis', () async {
      final (hs, g) = await ready();
      final r = await g.publishBookEvents(_book, <BookOutgoing>[BookOutgoing(CashBookCodec.metaType, _metaContent()), entry()]);
      expect(r, <BookSendResult>[BookSendResult.sent, BookSendResult.sent]);
      expect(hs.sends, hasLength(2));
      expect(hs.sends.first.$1, contains(CashBookCodec.metaType));
      expect(hs.sends.last.$1, contains(CashBookCodec.entryType));
    });

    test('Sendeschutz: Fremder im Raum → alle blocked, nichts gesendet', () async {
      final (hs, g) = await ready();
      hs.members = <String>[_me, _cara, _fremd];
      final r = await g.publishBookEvents(_book, <BookOutgoing>[entry(), entry(id: '22222222-2222-4222-8222-222222222222')]);
      expect(r, <BookSendResult>[BookSendResult.blocked, BookSendResult.blocked]);
      expect(hs.sends, isEmpty);
    });

    test('Mitglieder nicht belastbar (leere Antwort): alle failed (nicht blocked), nichts gesendet', () async {
      final (hs, g) = await ready();
      hs.emptyMembers = true;
      expect(await g.publishBookEvents(_book, <BookOutgoing>[entry()]), <BookSendResult>[BookSendResult.failed]);
      expect(hs.sends, isEmpty);
    });

    test('fremder Autor, Meta eines Nicht-Erstellers, fremder Typ, zu groß: invalid, die übrigen werden gesendet', () async {
      final (hs, g) = await ready(creator: _cara);
      final big = <String, Object?>{..._entryContent(), 'note': 'x' * 20000};
      final r = await g.publishBookEvents(_book, <BookOutgoing>[
        entry(author: _cara),
        BookOutgoing(CashBookCodec.metaType, _metaContent()),
        const BookOutgoing('m.room.message', <String, Object?>{'body': 'x'}),
        BookOutgoing(CashBookCodec.entryType, big),
        entry(),
      ]);
      expect(r, <BookSendResult>[
        BookSendResult.invalid,
        BookSendResult.invalid,
        BookSendResult.invalid,
        BookSendResult.invalid,
        BookSendResult.sent,
      ]);
      expect(hs.sends, hasLength(1));
    });

    test('scheitert eine Sendung, bleiben alle späteren ungesendet (failed)', () async {
      final (hs, g) = await ready();
      hs.sendOkCount = 1;
      final r = await g.publishBookEvents(_book, <BookOutgoing>[entry(), entry(id: '22222222-2222-4222-8222-222222222222'), entry(id: '33333333-3333-4333-8333-333333333333')]);
      expect(r, <BookSendResult>[BookSendResult.sent, BookSendResult.failed, BookSendResult.failed]);
      expect(hs.sends.length, 2, reason: 'nach dem ersten Fehler wird nichts mehr versucht');
    });

    test('genau 50 Ereignisse sind erlaubt; nicht kodierbarer Inhalt ist invalid', () async {
      final (hs, g) = await ready();
      final r = await g.publishBookEvents(_book, <BookOutgoing>[for (var i = 0; i < 50; i++) entry()]);
      expect(r, everyElement(BookSendResult.sent));
      expect(hs.sends, hasLength(50));
      final bad = await g.publishBookEvents(_book, <BookOutgoing>[
        BookOutgoing(CashBookCodec.entryType, <String, Object?>{'author': _me, 'x': DateTime.now()}),
      ]);
      expect(bad, <BookSendResult>[BookSendResult.invalid]);
    });

    test('höchstens 50 Ereignisse; leere Liste; Buch einer anderen Familie', () async {
      final (hs, g) = await ready();
      await expectLater(
        g.publishBookEvents(_book, <BookOutgoing>[for (var i = 0; i < 51; i++) entry()]),
        _error(GatewayError.invalidInput),
      );
      expect(await g.publishBookEvents(_book, const <BookOutgoing>[]), isEmpty);
      await _sync(g, _bookJoin('!anderes:hs.example', family: '!andere:hs.example'));
      await expectLater(g.publishBookEvents('!anderes:hs.example', <BookOutgoing>[entry()]), _notAllowed());
      expect(hs.sends, isEmpty);
    });

    test('Verschlüsselung ist Pflicht (Standard der Naht): ohne verfügbare Verschlüsselung wird nichts gesendet', () async {
      final (hs, g) = await _signedIn(requireEncryption: true);
      await _sync(g, _bookJoin(_book));
      hs.members = <String>[_me];
      await expectLater(g.publishBookEvents(_book, <BookOutgoing>[entry()]), _error(GatewayError.encryptionUnavailable));
      expect(hs.sends, isEmpty);
    });
  });

  group('Signale und Historie je Buch', () {
    Future<(_Hs, SdkMatrixGateway)> ready() async {
      final (hs, g) = await _signedIn();
      await _syncJoined(g, _bookJoin(_book, members: <String>[_cara]));
      return (hs, g);
    }

    test('Signale tragen Raum und Ersteller; Meta zuerst, nur vom Ersteller, höchste Version gewinnt', () async {
      final (_, g) = await ready();
      final live = <BookSignal>[];
      g.bookSignals.listen(live.add);
      await Future<void>.delayed(Duration.zero);
      g.debugIngestBookEvents(_book, _me, <Event>[
        _arrived(g, _book, CashBookCodec.metaType, _me, _metaContent(version: 2, title: 'Neu')),
        _arrived(g, _book, CashBookCodec.metaType, _cara, _metaContent(version: 9, title: 'Gefälscht')),
        _arrived(g, _book, CashBookCodec.metaType, _me, _metaContent(version: 1, title: 'Alt')),
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara)),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(live.map((s) => (s.kind, s.roomId, s.creatorId)), <Object>[
        (BookSignalKind.meta, _book, _me),
        (BookSignalKind.entry, _book, _me),
      ]);
      final history = g.debugBookHistory(_book);
      expect(history.first.content['title'], 'Neu', reason: 'Meta mit der höchsten Version, nie das gefälschte');
      expect(history, hasLength(2));
    });

    test('Verlauf je (Absender, id) auf die höchste Version verdichtet; kein Verdrängen durch Menge', () async {
      final (_, g) = await ready();
      g.debugIngestBookEvents(_book, _me, <Event>[
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara, version: 3, cents: 3)),
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara, version: 2, cents: 2)),
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara, version: 3, cents: 3)),
        for (var i = 0; i < 6000; i++)
          _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara, id: '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}')),
      ]);
      final h = g.debugBookHistory(_book);
      expect(h, hasLength(6001), reason: 'mehr als 5000 Signale gehen nicht verloren');
      expect(h.firstWhere((s) => s.content['id'] == '11111111-1111-4111-8111-111111111111').content['version'], 3);
    });

    test('zwei Absender mit gleicher id bleiben getrennt (Schlüssel Absender + id, nie Raum + id)', () async {
      final (_, g) = await ready();
      g.debugIngestBookEvents(_book, _me, <Event>[
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara)),
        _arrived(g, _book, CashBookCodec.entryType, _me, _entryContent(author: _me)),
      ]);
      expect(g.debugBookHistory(_book), hasLength(2));
    });

    test('über 30000 Einträge: der älteste fällt weg und der Verlauf gilt nie als vollständig', () async {
      final (_, g) = await ready();
      g.debugMarkBookComplete(_book);
      expect(g.bookHistoryComplete(_book), isTrue);
      g.debugIngestBookEvents(_book, _me, <Event>[
        for (var i = 0; i <= 30000; i++)
          _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara, id: '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}')),
      ]);
      expect(g.debugBookHistory(_book), hasLength(30000));
      expect(g.bookHistoryComplete(_book), isFalse);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Beitritt eines anderen Mitglieds: Livesignal memberJoined (nie in der Historie)', () async {
      final (hs, g) = await _signedIn();
      hs.members = <String>[_me, _cara];
      await _syncJoined(g, _bookJoin(_book, members: <String>[_cara]));
      await Future<void>.delayed(_settle);
      await Future<void>.delayed(_settle);
      final live = <BookSignal>[];
      g.bookSignals.listen(live.add);
      await Future<void>.delayed(Duration.zero);
      await _syncJoined(g, <String, Object?>{
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            _book: <String, Object?>{
              'timeline': <String, Object?>{
                'events': <Object?>[_memberEvent(_ben, 'join')],
              },
            },
          },
        },
      });
      await Future<void>.delayed(_settle);
      expect(live.map((s) => (s.kind, s.sender)), <Object>[(BookSignalKind.memberJoined, _ben)]);
      expect(g.debugBookHistory(_book), isEmpty);
    });

    test('ein neuer Zuhörer erhält zuerst das Meta, dann die Einträge; Beitritte werden nie wiedereingespielt', () async {
      final (_, g) = await ready();
      g.debugIngestBookEvents(_book, _me, <Event>[
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara)),
        _arrived(g, _book, CashBookCodec.metaType, _me, _metaContent()),
      ]);
      final late = <BookSignal>[];
      g.bookSignals.listen(late.add);
      await Future<void>.delayed(Duration.zero);
      expect(late.map((s) => s.kind), <BookSignalKind>[BookSignalKind.meta, BookSignalKind.entry]);
    });

    test('Klartext und noch nicht entschlüsselte Ereignisse: kein Signal; Zähler der unentschlüsselten', () async {
      final (_, g) = await ready();
      AppLog.capture = true;
      addTearDown(() => AppLog.capture = false);
      AppLog.captured.clear();
      g.debugIngestBookEvents(_book, _me, <Event>[
        _plain(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara)),
        Event.fromJson(<String, Object?>{
          'type': 'm.room.encrypted',
          'event_id': '\$enc${_eid++}',
          'sender': _cara,
          'origin_server_ts': 1700000000000,
          'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
        }, g.sdkClient!.getRoomById(_book)!),
      ]);
      expect(g.debugBookHistory(_book), isEmpty);
      expect(g.bookUndecryptableCount(_book), 1);
      expect(AppLog.captured.where((l) => l.contains('Klartext')), hasLength(1));
    });

    test('dasselbe Ereignis wird nur einmal gemeldet', () async {
      final (_, g) = await ready();
      final e = _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara));
      final live = <BookSignal>[];
      g.bookSignals.listen(live.add);
      await Future<void>.delayed(Duration.zero);
      g.debugIngestBookEvents(_book, _me, <Event>[e, e]);
      await Future<void>.delayed(Duration.zero);
      expect(live, hasLength(1));
    });
  });

  group('Zeitleisten, Vollständigkeit und Abbau', () {
    test('beigetretenes Buch bekommt eine Zeitleiste; ohne weitere Ereignisse gilt der Verlauf als vollständig', () async {
      final (_, g) = await _signedIn();
      await _syncJoined(g, _bookJoin(_book, members: <String>[_cara]));
      await Future<void>.delayed(_settle);
      await Future<void>.delayed(_settle);
      expect(g.debugBookTimelineIds, <String>{_book});
      expect(g.bookHistoryComplete(_book), isTrue);
    });

    test('Backfill lädt ältere Seiten bis zum Raum-Ereignis, erst dann vollständig', () async {
      final (hs, g) = await _signedIn();
      final update = _bookJoin(_book, members: <String>[_cara]);
      final room = ((update['rooms']! as Map)['join']! as Map)[_book]! as Map<String, Object?>;
      room['timeline'] = <String, Object?>{'events': <Object?>[], 'limited': true, 'prev_batch': 'p0'};
      await _syncJoined(g, update);
      await Future<void>.delayed(_settle);
      await Future<void>.delayed(_settle);
      expect(hs.messagesCalls, greaterThanOrEqualTo(1), reason: 'der Verlauf wurde nachgeladen');
      expect(g.bookHistoryComplete(_book), isTrue);
    });

    test('Backfill-Obergrenze: nach 200 Seiten bleibt der Verlauf unvollständig und wird nicht erneut versucht', () async {
      final (hs, g) = await _signedIn();
      hs.messagesMode = 'endless';
      final update = _bookJoin(_book, members: <String>[_cara]);
      final room = ((update['rooms']! as Map)['join']! as Map)[_book]! as Map<String, Object?>;
      room['timeline'] = <String, Object?>{'events': <Object?>[], 'limited': true, 'prev_batch': 'p0'};
      await _syncJoined(g, update);
      for (var i = 0; i < 40 && hs.messagesCalls < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(_settle);
      expect(hs.messagesCalls, inInclusiveRange(200, 201), reason: 'höchstens 200 Seiten (plus ein Ladevorgang des SDK)');
      expect(g.bookHistoryComplete(_book), isFalse);
      final calls = hs.messagesCalls;
      await _syncJoined(g, <String, Object?>{'rooms': <String, Object?>{}});
      await Future<void>.delayed(_settle);
      expect(hs.messagesCalls, calls, reason: 'nicht erneut versucht');
    });

    test('Buch verlassen: Zeitleiste, Historie und Vollständigkeit werden abgebaut; bookRoomGone', () async {
      final (_, g) = await _signedIn();
      await _syncJoined(g, _bookJoin(_book, members: <String>[_cara]));
      await Future<void>.delayed(_settle);
      g.debugIngestBookEvents(_book, _me, <Event>[
        _arrived(g, _book, CashBookCodec.metaType, _me, _metaContent()),
        _arrived(g, _book, CashBookCodec.entryType, _cara, _entryContent(author: _cara)),
      ]);
      expect(g.debugBookHistory(_book), hasLength(2));
      expect(g.bookRoomGone(_book), isFalse);
      await _syncJoined(g, <String, Object?>{
        'rooms': <String, Object?>{
          'leave': <String, Object?>{
            _book: <String, Object?>{
              'state': <String, Object?>{'events': <Object?>[]},
              'timeline': <String, Object?>{
                'events': <Object?>[_memberEvent(_me, 'leave')],
              },
            },
          },
        },
      });
      await Future<void>.delayed(_settle);
      expect(g.bookRoomGone(_book), isTrue);
      expect(g.debugBookTimelineIds, isEmpty);
      expect(g.debugBookHistory(_book), isEmpty);
      expect(g.bookHistoryComplete(_book), isFalse);
    });

    test('unbekannter Raum nach dem ersten Sync gilt als weg; ohne Familie oder gesperrt nie', () async {
      final (_, g) = await _signedIn();
      expect(g.bookRoomGone('!nie:hs.example'), isTrue);
      final (_, g2) = await _signedIn(familySynced: false);
      expect(g2.bookRoomGone('!nie:hs.example'), isFalse);
    });

    test('Zurücksetzen (Abmelden, Familienwechsel) räumt alles', () async {
      final (_, g) = await _signedIn();
      await _syncJoined(g, _bookJoin(_book, members: <String>[_cara]));
      await Future<void>.delayed(_settle);
      g.debugIngestBookEvents(_book, _me, <Event>[_arrived(g, _book, CashBookCodec.metaType, _me, _metaContent())]);
      g.debugMarkBookComplete(_book);
      g.debugResetBooks();
      expect(g.debugBookTimelineIds, isEmpty);
      expect(g.debugBookHistory(_book), isEmpty);
      expect(g.bookHistoryComplete(_book), isFalse);
    });

    test('Buch einer anderen Familie bekommt keine Zeitleiste', () async {
      final (_, g) = await _signedIn();
      await _syncJoined(g, _bookJoin('!anderes:hs.example', family: '!andere:hs.example'));
      await Future<void>.delayed(_settle);
      expect(g.debugBookTimelineIds, isEmpty);
    });
  });
}
