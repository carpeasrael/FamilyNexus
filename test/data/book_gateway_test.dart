// Buchverwaltung des SdkMatrixGateway (Kassenbuch, #311, E-113) gegen einen nachgestellten Homeserver: gesperrt =
// keine Anfrage, Anlegen, Einladen, Annehmen, Sendeschutz und Abgleich. Läuft ohne vodozemac.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/book_room.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show SyncStatus, SyncStatusUpdate, SyncUpdate;
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
Map<String, Object?> _bookJoin(String room, {String creator = _me, Map<String, Object?>? pl, List<String> members = const <String>[], String family = _familyRoom, bool marker = true}) =>
    <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          room: <String, Object?>{
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

Map<String, Object?> _bookInvite(String room, {String creator = _cara, String inviter = _cara, String family = _familyRoom, bool withCreate = true}) =>
    <String, Object?>{
      'rooms': <String, Object?>{
        'invite': <String, Object?>{
          room: <String, Object?>{
            'invite_state': <String, Object?>{
              'events': <Object?>[
                if (withCreate)
                  <String, Object?>{
                    'type': 'm.room.create',
                    'state_key': '',
                    'sender': creator,
                    'content': <String, Object?>{'room_version': '10', ...BookRoomMarker.cashCreationContent(family)},
                  },
                <String, Object?>{
                  'type': 'm.room.member',
                  'state_key': _me,
                  'sender': inviter,
                  'content': <String, Object?>{'membership': 'invite'},
                },
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
          return _json(<String, Object?>{
            'chunk': <Object?>[
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

/// Einladung wie vom Server: Das SDK wartet in verschlüsselten Räumen, bis die Einladung im Sync erscheint.
Future<void> _inviteAndDeliver(SdkMatrixGateway g, String room, String user) async {
  final done = g.inviteToBook(room, user);
  await Future<void>.delayed(const Duration(milliseconds: 250));
  await _sync(g, <String, Object?>{
    'rooms': <String, Object?>{
      'join': <String, Object?>{
        room: <String, Object?>{
          'timeline': <String, Object?>{
            'events': <Object?>[_memberEvent(user, 'invite', sender: _me)],
          },
        },
      },
    },
  });
  await done;
}

Matcher _notAllowed() => throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed));

void main() {
  setUpAll(sqfliteFfiInit);

  test('Ausgangslage: die Familie ist bekannt, ich bin Moderator, Cara auch, Ben nicht', () async {
    final (_, g) = await _signedIn();
    final f = g.family;
    expect(f, isNotNull, reason: 'Familie aus Kontodaten und Raumzustand');
    expect(f!.member(_cara)?.role, Role.moderator);
    expect(f.member(_ben)?.role, Role.member);
    expect(f.myRole, Role.moderator);
  });

  group('gesperrt (Standard): keine Anfrage', () {
    test('Listen leer, Aktionen notAllowed, nichts an den Server', () async {
      final (hs, g) = await _signedIn(enabled: false);
      await _sync(g, _bookJoin(_book));
      await _sync(g, _bookInvite('!einl:hs.example'));
      expect(g.books, isEmpty);
      expect(g.bookInvitations, isEmpty);
      final before = hs.calls.length;
      await expectLater(g.createBook(), _notAllowed());
      await expectLater(g.inviteToBook(_book, _cara), _notAllowed());
      await expectLater(g.removeFromBook(_book, _cara), _notAllowed());
      await expectLater(g.leaveBook(_book), _notAllowed());
      await expectLater(g.acceptBookInvitation('!einl:hs.example'), _notAllowed());
      await expectLater(g.declineBookInvitation('!einl:hs.example'), _notAllowed());
      await expectLater(g.verifyBookRecipients(_book), _notAllowed());
      await expectLater(g.reconcileBook(_book), _notAllowed());
      expect(hs.calls.length, before);
    });

    test('der eingebaute Standard ist freigeschaltet; ohne Sitzung bleibt jede Buchaktion notAllowed', () async {
      expect(CashBookFlags.enabled, isTrue);
      final hs = _Hs();
      final dir = await Directory.systemTemp.createTemp('fn_bookgw0');
      addTearDown(() => dir.delete(recursive: true));
      final g = SdkMatrixGateway(
        keyStore: MemoryKeyStore(),
        dbDirectory: dir.path,
        probe: ServerProbe(client: hs.client),
        databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
        httpClient: hs.client,
      );
      addTearDown(() async {
        if (!hs.release.isCompleted) hs.release.complete();
        await g.close();
      });
      await g.restore();
      await expectLater(g.createBook(), _notAllowed());
    });
  });

  group('Listen', () {
    test('books: nur beigetretene Bücher dieser Familie mit Create-Kennzeichen', () async {
      final (_, g) = await _signedIn();
      await _sync(g, _bookJoin(_book));
      await _sync(g, _bookJoin('!fremdfam:hs.example', family: '!andere:hs.example'));
      await _sync(g, _bookJoin('!ohne:hs.example', marker: false));
      expect(g.books.map((b) => b.roomId), <String>[_book]);
      expect(g.books.single.creatorId, _me);
    });

    test('bookInvitations: nur Einladender == Ersteller und Moderator meiner Familie', () async {
      final (_, g) = await _signedIn();
      await _sync(g, _bookInvite('!gut:hs.example'));
      await _sync(g, _bookInvite('!mitglied:hs.example', creator: _ben, inviter: _ben));
      await _sync(g, _bookInvite('!fremder:hs.example', creator: _fremd, inviter: _fremd));
      await _sync(g, _bookInvite('!dritter:hs.example', creator: _cara, inviter: _ben));
      await _sync(g, _bookInvite('!ohnecreate:hs.example', withCreate: false));
      expect(g.bookInvitations.map((i) => i.roomId), <String>['!gut:hs.example']);
    });
  });

  group('anlegen', () {
    test('createRoom mit Kennzeichen, neutralem Namen, Invite-Regel, verschlüsselt und Power-Levels des Erstellers', () async {
      final (hs, g) = await _signedIn();
      final created = g.createBook();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _syncJoined(g, _bookJoin(_book));
      final id = await created;
      expect(id, _book);
      expect(hs.where('PUT', '/pushrules/'), isNotEmpty, reason: 'Raum stumm geschaltet');
      final c = hs.where('POST', '/createRoom').single;
      final body = json.decode(c.$3) as Map<String, Object?>;
      expect(body['name'], 'FamilyNexus');
      expect(body['room_version'], '10');
      final cc = body['creation_content']! as Map<String, Object?>;
      expect(cc[BookRoomMarker.bookKey], BookRoomMarker.cashKind);
      expect(cc[BookRoomMarker.familyKey], _familyRoom);
      final init = {for (final s in body['initial_state']! as List) (s as Map)['type']: s['content']};
      expect(init['m.room.join_rules'], <String, Object?>{'join_rule': 'invite'});
      expect((init['m.room.encryption']! as Map)['algorithm'], 'm.megolm.v1.aes-sha2');
      final pl = body['power_level_content_override']! as Map<String, Object?>;
      expect(pl['users'], <String, Object?>{_me: 100});
      expect(pl['invite'], 100);
      expect(pl['kick'], 100);
    });

    test('nur Moderatoren legen Bücher an (Mitglied: notAllowed)', () async {
      final (hs, g) = await _signedIn();
      // Ich werde herabgestuft: Power-Level 0 im Familienraum.
      await _sync(g, <String, Object?>{
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            _familyRoom: <String, Object?>{
              'state': <String, Object?>{
                'events': <Object?>[
                  _state('m.room.power_levels', _cara, <String, Object?>{'users': <String, int>{_cara: 100}, 'users_default': 0}),
                ],
              },
            },
          },
        },
      });
      await Future<void>.delayed(_settle);
      final before = hs.where('POST', '/createRoom').length;
      await expectLater(g.createBook(), _notAllowed());
      expect(hs.where('POST', '/createRoom').length, before);
    });

    test('höchstens zehn Bücher je Familie', () async {
      final (hs, g) = await _signedIn();
      for (var i = 0; i < 10; i++) {
        await _sync(g, _bookJoin('!b$i:hs.example'));
      }
      expect(g.books, hasLength(10));
      await expectLater(g.createBook(), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.invalidInput)));
      expect(hs.where('POST', '/createRoom'), isEmpty);
    });
  });

  group('einladen und entfernen', () {
    test('Moderator der Familie wird eingeladen; Mitglied, Fremder und ich selbst nicht (ohne Anfrage)', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book));
      hs.members = <String>[_me];
      await _inviteAndDeliver(g, _book, _cara);
      expect(hs.where('POST', '/invite'), hasLength(1));
      expect(hs.where('POST', '/invite').single.$3, contains(_cara));
      final before = hs.where('POST', '/invite').length;
      for (final bad in <String>[_ben, _fremd, _me, 'kein-id']) {
        await expectLater(g.inviteToBook(_book, bad), _notAllowed(), reason: bad);
      }
      expect(hs.where('POST', '/invite').length, before);
    });

    test('nur der Ersteller lädt ein und entfernt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin('!fremderbuch:hs.example', creator: _cara));
      await expectLater(g.inviteToBook('!fremderbuch:hs.example', _cara), _notAllowed());
      await expectLater(g.removeFromBook('!fremderbuch:hs.example', _ben), _notAllowed());
      expect(hs.where('POST', '/invite'), isEmpty);
      expect(hs.where('POST', '/kick'), isEmpty);
    });

    test('Mitgliedergrenze: bei zehn Mitgliedern keine weitere Einladung', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book));
      hs.members = <String>[_me, for (var i = 0; i < 9; i++) '@m$i:hs.example'];
      await expectLater(g.inviteToBook(_book, _cara), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.invalidInput)));
      expect(hs.where('POST', '/invite'), isEmpty);
    });

    test('entfernen: Ersteller kickt andere, nie sich selbst', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book));
      await g.removeFromBook(_book, _cara);
      expect(hs.where('POST', '/kick').single.$3, contains(_cara));
      await expectLater(g.removeFromBook(_book, _me), _notAllowed());
    });

    test('Raum ohne Buch-Kennzeichen wird nie als Buch behandelt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin('!kein:hs.example', marker: false));
      await expectLater(g.inviteToBook('!kein:hs.example', _cara), _notAllowed());
      await expectLater(g.leaveBook('!kein:hs.example'), _notAllowed());
      expect(hs.where('POST', '/invite'), isEmpty);
      expect(hs.where('POST', '/leave'), isEmpty);
    });
  });

  group('annehmen', () {
    test('gültige Einladung: Beitritt, Nachprüfung besteht, Raum bleibt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!gut:hs.example'));
      hs.serveBook('!gut:hs.example', _cara);
      hs.onJoin = (room) => Timer(const Duration(milliseconds: 100), () => unawaited(_syncJoined(g, _bookJoin(room, creator: _cara, members: <String>[_cara]))));
      await g.acceptBookInvitation('!gut:hs.example');
      expect(hs.where('POST', '/join'), hasLength(1));
      expect(hs.where('POST', '/leave'), isEmpty);
    });

    test('Einladender kein Moderator meiner Familie oder nicht Ersteller: notAllowed ohne Beitritt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!mitglied:hs.example', creator: _ben, inviter: _ben));
      await _sync(g, _bookInvite('!dritter:hs.example', creator: _cara, inviter: _ben));
      await expectLater(g.acceptBookInvitation('!mitglied:hs.example'), _notAllowed());
      await expectLater(g.acceptBookInvitation('!dritter:hs.example'), _notAllowed());
      expect(hs.where('POST', '/join'), isEmpty);
    });

    test('Nachprüfung: Raum mit abweichenden Power-Levels wird verlassen', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!schlecht:hs.example'));
      hs.serveBook('!schlecht:hs.example', _cara, pl: _bookPl(_cara, invite: 0));
      hs.onJoin = (room) => Timer(
            const Duration(milliseconds: 100),
            () => unawaited(_syncJoined(g, _bookJoin(room, creator: _cara, pl: _bookPl(_cara, invite: 0), members: <String>[_cara]))),
          );
      await expectLater(g.acceptBookInvitation('!schlecht:hs.example'), _notAllowed());
      expect(hs.where('POST', '/leave'), isNotEmpty);
    });

    test('ablehnen verlässt die Einladung', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!nein:hs.example'));
      await g.declineBookInvitation('!nein:hs.example');
      expect(hs.where('POST', '/leave'), hasLength(1));
    });
  });

  group('Sendeschutz', () {
    test('alle Mitglieder Moderatoren der Familie: erlaubt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara];
      await g.verifyBookRecipients(_book);
    });

    test('ein Mitglied, ein Fremder oder ein Herabgestufter im Raum: notAllowed (frisch gelesen, kein Zwischenspeicher)', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara];
      await g.verifyBookRecipients(_book);
      hs.members = <String>[_me, _cara, _ben];
      await expectLater(g.verifyBookRecipients(_book), _notAllowed());
      hs.members = <String>[_me, _fremd];
      await expectLater(g.verifyBookRecipients(_book), _notAllowed());
      hs.members = <String>[_me, _cara];
      hs.left = <String>{_ben, _fremd};
      await g.verifyBookRecipients(_book);
    });
  });

  group('Abgleich', () {
    test('erst der zweite Durchlauf entfernt; wer wieder berechtigt ist, beginnt von vorn; nur der Ersteller', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara, _ben]));
      hs.members = <String>[_me, _cara, _ben];
      // Die Mitgliederliste der Familie muss belastbar sein (erster Sync, Teilnehmer geladen).
      expect(g.initialSyncDone, isTrue);
      expect(await g.reconcileBook(_book), isEmpty, reason: 'erster Durchlauf merkt nur');
      expect(hs.where('POST', '/kick'), isEmpty);
      expect(await g.reconcileBook(_book), <String>[_ben]);
      expect(hs.where('POST', '/kick').single.$3, contains(_ben));
    });

    test('Buch eines anderen: kein Abgleich', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin('!fremderbuch:hs.example', creator: _cara, members: <String>[_cara, _ben]));
      hs.members = <String>[_me, _cara, _ben];
      expect(await g.reconcileBook('!fremderbuch:hs.example'), isEmpty);
      expect(await g.reconcileBook('!fremderbuch:hs.example'), isEmpty);
      expect(hs.where('POST', '/kick'), isEmpty);
    });
  });

  group('Lücken der Mutationsprobe (Teil 2b)', () {
    test('eingebauter Standard ist freigeschaltet: angemeldet, Familie bekannt, Buch und Einladung sind sichtbar', () async {
      final (_, g) = await _signedIn(enabled: null);
      expect(g.family, isNotNull);
      await _sync(g, _bookJoin(_book));
      await _sync(g, _bookInvite('!einl:hs.example'));
      expect(g.books.map((b) => b.roomId), <String>[_book]);
      expect(g.bookInvitations.map((b) => b.roomId), <String>['!einl:hs.example']);
    });

    test('ausdrücklich gesperrt (enabled: false): angemeldet, Familie bekannt, Buch und Einladung da, trotzdem nichts', () async {
      final (hs, g) = await _signedIn(enabled: false);
      expect(g.family, isNotNull);
      await _sync(g, _bookJoin(_book));
      await _sync(g, _bookInvite('!einl:hs.example'));
      expect(g.books, isEmpty);
      expect(g.bookInvitations, isEmpty);
      await expectLater(g.createBook(), _notAllowed());
      expect(hs.where('POST', '/createRoom'), isEmpty);
    });

    test('Einladender ist Moderator der Familie, aber nicht Ersteller: nicht annehmbar, kein Beitritt', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!dritter:hs.example', creator: _fremd, inviter: _cara));
      expect(g.bookInvitations, isEmpty);
      await expectLater(g.acceptBookInvitation('!dritter:hs.example'), _notAllowed());
      expect(hs.where('POST', '/join'), isEmpty);
    });

    test('Einladender ist nur eingeladener (nicht beigetretener) Moderator: nicht annehmbar', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!dora:hs.example', creator: _dora, inviter: _dora));
      expect(g.bookInvitations, isEmpty);
      await expectLater(g.acceptBookInvitation('!dora:hs.example'), _notAllowed());
      expect(hs.where('POST', '/join'), isEmpty);
    });

    test('falsche Mitgliedschaft: Annehmen und Ablehnen eines beigetretenen Buchs, Verlassen und Einladen einer Einladung', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book));
      await _sync(g, _bookInvite('!einl:hs.example'));
      final notFound = throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notFound));
      await expectLater(g.acceptBookInvitation(_book), notFound);
      await expectLater(g.declineBookInvitation(_book), notFound);
      await expectLater(g.leaveBook('!einl:hs.example'), notFound);
      await expectLater(g.inviteToBook('!einl:hs.example', _cara), notFound);
      expect(hs.where('POST', '/join'), isEmpty);
      expect(hs.where('POST', '/leave'), isEmpty);
    });

    test('ungültige Raum-ID: invalidInput ohne Anfrage', () async {
      final (hs, g) = await _signedIn();
      final before = hs.calls.length;
      final invalid = throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.invalidInput));
      await expectLater(g.leaveBook('kein-raum'), invalid);
      await expectLater(g.acceptBookInvitation('kein-raum'), invalid);
      expect(hs.calls.length, before);
    });

    test('Verschlüsselung nicht verfügbar: Anlegen scheitert vor jeder Anfrage', () async {
      final (hs, g) = await _signedIn(requireEncryption: true);
      await expectLater(g.createBook(), throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.encryptionUnavailable)));
      expect(hs.where('POST', '/createRoom'), isEmpty);
    });

    test('Push-Regel scheitert: Anlegen gelingt trotzdem (nur eine Warnung)', () async {
      final (hs, g) = await _signedIn();
      hs.pushRulesFail = true;
      final created = g.createBook();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _syncJoined(g, _bookJoin(_book));
      expect(await created, _book);
    });

    test('Annehmen stellt den Raum stumm (Push-Regel)', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!gut:hs.example'));
      hs.serveBook('!gut:hs.example', _cara);
      hs.onJoin = (room) => Timer(const Duration(milliseconds: 100), () => unawaited(_syncJoined(g, _bookJoin(room, creator: _cara, members: <String>[_cara]))));
      await g.acceptBookInvitation('!gut:hs.example');
      expect(hs.where('PUT', '/pushrules/'), isNotEmpty);
    });

    test('Serverzustand nicht abrufbar (404): die Nachprüfung besteht nicht, der Raum wird verlassen', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookInvite('!kaputt:hs.example'));
      hs.onJoin = (room) => Timer(const Duration(milliseconds: 100), () => unawaited(_syncJoined(g, _bookJoin(room, creator: _cara, members: <String>[_cara]))));
      await expectLater(g.acceptBookInvitation('!kaputt:hs.example'), _notAllowed());
      expect(hs.where('POST', '/leave'), isNotEmpty);
    });

    test('Abgleich: ohne bekannte Familie entfernt niemand, auch nicht nach zwei Durchläufen', () async {
      final (hs, g) = await _signedIn(familySynced: false);
      await _sync(g, _bookJoin(_book, members: <String>[_cara, _ben]));
      hs.members = <String>[_me, _cara, _ben];
      expect(g.family, isNull);
      expect(await g.reconcileBook(_book), isEmpty);
      expect(await g.reconcileBook(_book), isEmpty);
      expect(await g.reconcileBook(_book), isEmpty);
      expect(hs.where('POST', '/kick'), isEmpty);
    });

    test('Abgleich: Mitgliederliste der Familie nicht geladen (Teilliste) entfernt niemanden', () async {
      final (hs, g) = await _signedIn(familyMembersFail: true);
      await _sync(g, _bookJoin(_book, members: <String>[_cara, _ben]));
      hs.members = <String>[_me, _cara, _ben];
      expect(g.debugParticipantsLoaded, isFalse);
      expect(await g.reconcileBook(_book), isEmpty);
      expect(await g.reconcileBook(_book), isEmpty);
      expect(await g.reconcileBook(_book), isEmpty);
      expect(hs.where('POST', '/kick'), isEmpty);
    });
  });
}
