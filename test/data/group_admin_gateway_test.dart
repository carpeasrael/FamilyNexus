// Gruppen-Verwaltung im echten SdkMatrixGateway (#119, K4-3): Mitglieder, Einladen (Größe, Ziel, Erreichbarkeit), Entfernen
// (kick, Sperre des Sendens, Freigabe), Admin ernennen und abstufen, Identität und Pins von Gruppen-Fremden. Gegen einen
// nachgestellten Homeserver (Harness wie in `book_gateway_sync_test.dart`, hier für die Verwaltung erweitert). Läuft ohne
// vodozemac: ein erlaubtes Senden geht im Klartext an den Server und belegt nur das Tor, nicht die Verschlüsselung.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/local_identity_pins.dart' show LocalIdentityPins;
import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/chat.dart' show GroupMember, GroupMembership, ThreadKind;
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart' show IdentityStatus;
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show CrossSigningKey, DeviceKeys, DeviceKeysList, SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_outbound_session_port.dart';
import '../support/memory_stores.dart';

const String _me = '@n2:hs.example';
const String _cara = '@cara:hs.example';
const String _ben = '@ben:hs.example';
const String _fremd = '@fremd:hs.example';
const String _anna = '@anna:hs.example';
const String _caro = '@caro:hs.example';
const String _dora = '@dora:hs.example';
const String _familyRoom = '!familie:hs.example';
const String _gr = '!gr:hs.example';
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

/// Familienraum: ich Moderator (100), Cara Moderatorin (50), Ben Mitglied (0).
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
                  'users': <String, int>{_me: 100, _cara: 50},
                  'users_default': 0,
                  'state_default': 50,
                  'invite': 50,
                  'kick': 50,
                }),
                _memberEvent(_me, 'join'),
                _memberEvent(_cara, 'join'),
                _memberEvent(_ben, 'join'),
              ],
            },
          },
        },
      },
    };

/// Inhalt von `m.room.power_levels` einer Gruppe (mit weiteren Feldern, die beim Ändern unberührt bleiben müssen).
Map<String, Object?> _pl({Map<String, int>? users, int invite = 50, int kick = 50}) => <String, Object?>{
      'users': users ?? <String, int>{_me: 100},
      'users_default': 0,
      'events_default': 0,
      'state_default': 50,
      'invite': invite,
      'kick': kick,
      'ban': 50,
      'redact': 50,
      'events': <String, int>{'m.room.power_levels': 50, 'm.room.name': 50, 'm.room.join_rules': 100, 'm.room.history_visibility': 100, 'm.room.encryption': 100},
    };

class _Hs {
  final List<(String, String, String)> calls = <(String, String, String)>[];
  final Completer<void> release = Completer<void>();
  int _syncs = 0;

  /// Mitglieder und weitere Mitgliedschaften, die `GET …/members` liefert.
  List<String> members = <String>[];
  final Map<String, String> extra = <String, String>{};
  bool membersFail = false;

  /// Hält `GET …/members`, bis die Zukunft endet (laufender Abruf).
  Completer<void>? holdMembers;

  /// Hält `POST …/invite`, bis die Zukunft endet (parallele Verwaltungsoperation).
  Completer<void>? holdInvite;

  /// Hält `GET …/state/m.room.power_levels`.
  Completer<void>? holdPl;

  /// `POST …/kick`: `forbidden` ⇒ Matrix-Fehlerantwort 403, `timeout` ⇒ Zeitablauf (kein Matrix-Fehler).
  String? kickMode;

  final List<(String, String)> sends = <(String, String)>[];
  final Map<String, Map<String, Object?>> serverState = <String, Map<String, Object?>>{};

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
        if (path.endsWith('/kick')) {
          if (kickMode == 'forbidden') return _json(<String, Object?>{'errcode': 'M_FORBIDDEN', 'error': 'nein'}, 403);
          if (kickMode == 'timeout') throw TimeoutException('kick');
          return _json(<String, Object?>{});
        }
        if (path.endsWith('/invite')) {
          await holdInvite?.future;
          return _json(<String, Object?>{});
        }
        if (path.endsWith('/members')) {
          await holdMembers?.future;
          if (membersFail && !path.contains(_familyRoom)) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'Fehler'}, 500);
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
                  'room_id': _gr,
                },
              for (final m in members)
                <String, Object?>{
                  'type': 'm.room.member',
                  'state_key': m,
                  'sender': m,
                  'content': <String, Object?>{'membership': 'join'},
                  'event_id': '\$m${_n++}',
                  'origin_server_ts': 1700000000000 + _n,
                  'room_id': _gr,
                },
            ],
          });
        }
        final st = RegExp(r'/rooms/([^/]+)/state/([^/]+)/?$').firstMatch(path);
        if (st != null && req.method == 'GET') {
          if (st.group(2) == 'm.room.power_levels') await holdPl?.future;
          final content = serverState['${st.group(1)}|${st.group(2)}'];
          if (content != null) return _json(content);
          return _json(<String, Object?>{'errcode': 'M_NOT_FOUND', 'error': 'nicht vorhanden'}, 404);
        }
        if (path.endsWith('/messages')) {
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
                'room_id': _gr,
              },
            ],
          });
        }
        if (req.method == 'PUT' && path.contains('/send/')) {
          sends.add((path, text));
          return _json(<String, Object?>{'event_id': '\$sent${sends.length}'});
        }
        if (req.method == 'PUT' && path.contains('/state/')) return _json(<String, Object?>{'event_id': '\$st${calls.length}'});
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<(_Hs, SdkMatrixGateway)> _signedIn({MemoryKeyValueStore? accountStore}) async {
  final hs = _Hs();
  final dir = await Directory.systemTemp.createTemp('fn_groupadmin');
  final keys = MemoryKeyStore();
  addTearDown(() => dir.delete(recursive: true));
  final g = SdkMatrixGateway(
    keyStore: keys,
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
    joinOpTimeout: const Duration(milliseconds: 800),
    joinPollInterval: const Duration(hours: 1),
    requireEncryptionForBooks: false,
    encryptionAvailable: true,
    contactRow2Delay: const Duration(seconds: 60),
    accountStore: accountStore,
  );
  addTearDown(() async {
    if (!hs.release.isCompleted) hs.release.complete();
    await g.close();
  });
  await g.restore();
  await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n2', password: 'geheim123');
  await Future<void>.delayed(_settle);
  await _sync(g, _familySync());
  await Future<void>.delayed(_settle);
  return (hs, g);
}

Future<void> _sync(SdkMatrixGateway g, Map<String, Object?> update) =>
    g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}', ...update}));

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

/// Beigetretene Gruppe: Zähler und Zustand einzeln steuerbar (`null` lässt die Angabe weg).
Map<String, Object?> _groupJoined(
  String room, {
  bool megolm = true,
  int? joined,
  int? invited = 0,
  String? rule = 'invite',
  String? history = 'invited',
  List<String>? members,
  List<String> invitedMembers = const <String>[],
  Map<String, Object?>? pl,
  int memberEvents = -1,
}) {
  final all = members ?? <String>[_me, _fremd, _anna];
  final shown = memberEvents < 0 ? all : all.take(memberEvents).toList();
  final j = joined ?? all.length;
  if (invitedMembers.isNotEmpty) invited = invitedMembers.length;
  return <String, Object?>{
    'rooms': <String, Object?>{
      'join': <String, Object?>{
        room: <String, Object?>{
          'summary': <String, Object?>{'m.joined_member_count': j, 'm.invited_member_count': ?invited},
          'state': <String, Object?>{
            'events': <Object?>[
              _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
              if (megolm) _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
              _state('m.room.name', _me, <String, Object?>{'name': 'Skatrunde'}),
              if (rule != null) _state('m.room.join_rules', _me, <String, Object?>{'join_rule': rule}),
              if (history != null) _state('m.room.history_visibility', _me, <String, Object?>{'history_visibility': history}),
              _state('m.room.power_levels', _me, pl ?? _pl()),
              for (final m in shown) _memberEvent(m, 'join'),
              for (final m in invitedMembers) _memberEvent(m, 'invite', sender: _me),
            ],
          },
        },
      },
    },
  };
}

/// Ein Weggang (oder Beitritt) in der Gruppe: Mitgliedsereignis und neue Zähler.
Map<String, Object?> _memberChange(String user, String membership, {required int joined, int? invited = 0, String room = _gr}) => <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          room: <String, Object?>{
            'summary': <String, Object?>{'m.joined_member_count': joined, 'm.invited_member_count': ?invited},
            'state': <String, Object?>{'events': <Object?>[_memberEvent(user, membership)]},
          },
        },
      },
    };

Map<String, Object?> _groupInvite(String room, String from) => <String, Object?>{
      'rooms': <String, Object?>{
        'invite': <String, Object?>{
          room: <String, Object?>{
            'invite_state': <String, Object?>{
              'events': <Object?>[
                <String, Object?>{'type': 'm.room.member', 'state_key': _me, 'sender': from, 'content': <String, Object?>{'membership': 'invite'}},
                <String, Object?>{'type': 'm.room.join_rules', 'state_key': '', 'sender': from, 'content': <String, Object?>{'join_rule': 'invite'}},
                <String, Object?>{'type': 'm.room.name', 'state_key': '', 'sender': from, 'content': <String, Object?>{'name': 'Einladung'}},
              ],
            },
          },
        },
      },
    };

const ContactPolicy _rec = ContactPolicy(
  enabled: true,
  contacts: <String, ContactState>{_fremd: ContactState.accepted, _anna: ContactState.accepted, _caro: ContactState.accepted},
  groups: <String>{_gr},
);
const ContactPolicy _nobody = ContactPolicy(enabled: true);

void main() {
  setUpAll(sqfliteFfiInit);

  Future<(_Hs, SdkMatrixGateway)> signedIn([ContactPolicy p = _rec, MemoryKeyValueStore? accountStore]) async {
    final (hs, g) = await _signedIn(accountStore: accountStore);
    g.setContactPolicy(p);
    g.debugDevicesOf = (id) => <bool>[true];
    return (hs, g);
  }

  Future<void> settle(SdkMatrixGateway g, Map<String, Object?> update) async {
    await _sync(g, update);
    await Future<void>.delayed(_settle);
  }

  /// Ein Sync ohne Mitgliederänderung: löst den Abgleich der Gruppen aus.
  Future<void> nudge(SdkMatrixGateway g, [Map<String, Object?>? update]) => settle(
        g,
        update ?? <String, Object?>{'account_data': <String, Object?>{'events': <Object?>[<String, Object?>{'type': 'x.kick', 'content': <String, Object?>{'n': _n++}}]}},
      );

  /// Gruppe eingestuft, Außensitzung als Fake, Mitgliederliste des Servers passend.
  Future<(_Hs, SdkMatrixGateway, FakeOutboundSessionPort)> ready({
    Map<String, Object?>? update,
    ContactPolicy policy = _rec,
    List<String>? serverMembers,
    bool open = false,
    bool session = false,
  }) async {
    final (hs, g) = await signedIn(policy);
    final port = FakeOutboundSessionPort();
    g.debugOutboundPort = port;
    hs.members = serverMembers ?? <String>[_me, _fremd, _anna];
    await settle(g, update ?? _groupJoined(_gr));
    expect(g.debugGroups.keys, contains(_gr), reason: 'Gruppe eingestuft');
    if (session) port.createSession(_gr, <String>{_me, _fremd, _anna});
    if (open) {
      await g.openThread(_gr);
      await Future<void>.delayed(_settle);
    }
    return (hs, g, port);
  }

  int membersCalls(_Hs hs) => hs.where('GET', '$_gr/members').length;
  int invites(_Hs hs) => hs.where('POST', '$_gr/invite').length;
  int kicks(_Hs hs) => hs.where('POST', '$_gr/kick').length;
  int plWrites(_Hs hs) => hs.where('PUT', '$_gr/state/m.room.power_levels').length;
  int groupSends(_Hs hs) => hs.sends.where((s) => s.$1.contains(_gr)).length;

  /// Setzt den Cross-Signing-Hauptschlüssel [uid] im SDK-Client (ohne `/keys/query`).
  void master(SdkMatrixGateway g, String uid, String pub) {
    final c = g.sdkClient!;
    final list = c.userDeviceKeys[uid] ?? (c.userDeviceKeys[uid] = DeviceKeysList(uid, c));
    list.crossSigningKeys
      ..clear()
      ..[pub] = CrossSigningKey.fromJson(<String, Object?>{
        'user_id': uid,
        'usage': <String>['master'],
        'keys': <String, String>{'ed25519:$pub': pub},
      }, c);
  }

  /// Ein von der App gesperrtes Gerät mit (im Harness als gültig geltender) Selbstsignatur.
  void blockedDevice(SdkMatrixGateway g, String uid) {
    final c = g.sdkClient!;
    final list = c.userDeviceKeys[uid] ?? (c.userDeviceKeys[uid] = DeviceKeysList(uid, c));
    final d = DeviceKeys.fromJson(<String, Object?>{
      'user_id': uid,
      'device_id': 'D1',
      'algorithms': <String>['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
      'keys': <String, String>{'ed25519:D1': 'ED25519KEY', 'curve25519:D1': 'CURVEKEY'},
      'signatures': <String, Object?>{
        uid: <String, String>{'ed25519:D1': 'SIGNATURE'},
      },
    }, c);
    d.blocked = true;
    list.deviceKeys['D1'] = d;
  }

  const k1 = 'KEYONE00000000000000000000000000000000000000';
  const k2 = 'KEYTWO00000000000000000000000000000000000000';

  group('Vorbedingungen aller Verwaltungsmethoden (K4-3)', () {
    final ops = <String, Future<Object?> Function(SdkMatrixGateway g, String room)>{
      'groupMembers': (g, r) => g.groupMembers(r),
      'inviteToGroup': (g, r) => g.inviteToGroup(r, _caro),
      'removeFromGroup': (g, r) => g.removeFromGroup(r, _anna),
      'setGroupAdmin': (g, r) => g.setGroupAdmin(r, _anna, admin: true),
    };

    for (final e in ops.entries) {
      test('${e.key}: abgemeldet, Bereich aus, Liste unvollständig, keine Gruppe, nicht beigetreten, Datensatz fehlt ⇒ notAllowed; ungültige Raum-ID ⇒ invalidInput', () async {
        final (hs, g, _) = await ready();
        await expectLater(e.value(g, 'kein-raum'), _error(GatewayError.invalidInput));
        await expectLater(e.value(g, '!nein:hs.example'), _error(GatewayError.notAllowed), reason: 'unbekannter Raum');
        await expectLater(e.value(g, _familyRoom), _error(GatewayError.notAllowed), reason: 'der Familienraum ist keine Gruppe');
        await settle(g, _groupInvite('!ein:hs.example', _fremd));
        await expectLater(e.value(g, '!ein:hs.example'), _error(GatewayError.notAllowed), reason: 'nur eingeladen, nicht beigetreten');
        g.setContactPolicy(_nobody);
        await Future<void>.delayed(_settle);
        await expectLater(e.value(g, _gr), _error(GatewayError.notAllowed), reason: 'Datensatz fehlt');
        g.setContactPolicy(ContactPolicy.off);
        await Future<void>.delayed(_settle);
        await expectLater(e.value(g, _gr), _error(GatewayError.notAllowed), reason: 'Bereich aus');
        expect(invites(hs) + kicks(hs) + plWrites(hs), 0, reason: 'nichts ging an den Server');

        final (_, g2, _) = await ready();
        g2.debugLeaveFamilyScope();
        await expectLater(e.value(g2, _gr), _error(GatewayError.notAllowed), reason: 'Mitgliederliste der Familie unvollständig');

        final (_, g3, _) = await ready();
        await g3.logout();
        await expectLater(e.value(g3, _gr), _error(GatewayError.notAllowed), reason: 'abgemeldet');
      });
    }

    test('Raum ist beigetretene Gruppe mit Datensatz, aber der Abgleich lief noch nicht: einmal abgleichen, dann geht die Operation (Einladung unmittelbar nach createGroup)', () async {
      final (hs, g) = await signedIn(_nobody);
      g.debugOutboundPort = FakeOutboundSessionPort();
      hs.members = <String>[_me, _fremd, _anna];
      await settle(g, _groupJoined(_gr));
      expect(g.debugGroups, isEmpty, reason: 'ohne Datensatz keine Gruppe');
      g.setContactPolicy(_rec); // Datensatz da, der Abgleich ist noch nicht gelaufen
      expect(g.debugGroups, isEmpty);
      await g.inviteToGroup(_gr, _caro);
      expect(invites(hs), 1);
      expect(g.debugGroups.keys, contains(_gr));
    });
  });

  group('groupMembers', () {
    test('Einträge mit Stufe, Mitgliedschaft, Familie, ich; Reihenfolge ich, Admins, Name; Fremdtext bereinigt', () async {
      final (_, g, _) = await ready(
        update: _groupJoined(
          _gr,
          members: <String>[_me, _fremd, _anna, _cara],
          invitedMembers: <String>[_caro],
          pl: _pl(users: <String, int>{_me: 100, _anna: 50}),
        ),
        serverMembers: <String>[_me, _fremd, _anna, _cara],
      );
      final list = await g.groupMembers(_gr);
      final byId = <String, GroupMember>{for (final m in list) m.userId: m};
      expect(byId.keys.toSet(), <String>{_me, _fremd, _anna, _cara, _caro});
      expect(list.first.userId, _me);
      expect(byId[_me]!.isMe, isTrue);
      expect(byId[_me]!.power, 100);
      expect(byId[_anna]!.power, 50);
      expect(byId[_fremd]!.power, 0);
      expect(byId[_cara]!.isFamily, isTrue);
      expect(byId[_fremd]!.isFamily, isFalse);
      expect(byId[_caro]!.membership, GroupMembership.invite);
      expect(byId[_fremd]!.membership, GroupMembership.join);
      expect(list.indexWhere((m) => m.userId == _anna), lessThan(list.indexWhere((m) => m.userId == _fremd)), reason: 'Admin vor Mitglied');
    });

    test('identity kommt aus dem Zustandsträger je Sync (ohne Auswertung durch groupMembers); Wechsel zeigt changed', () async {
      final (_, g, _) = await ready();
      master(g, _anna, k1);
      await nudge(g);
      var byId = <String, GroupMember>{for (final m in await g.groupMembers(_gr)) m.userId: m};
      expect(byId[_anna]!.identity, IdentityStatus.pinned);
      expect(byId[_fremd]!.identity, IdentityStatus.unknown, reason: 'ohne Schlüssel');
      master(g, _anna, k2);
      await nudge(g);
      byId = <String, GroupMember>{for (final m in await g.groupMembers(_gr)) m.userId: m};
      expect(byId[_anna]!.identity, IdentityStatus.changed);
    });

    test('G > 50: nur die lokal bekannten Einträge, ohne Serverabruf (Aufrufzähler), nie als Beleg für „leer“', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, joined: 60));
      final before = membersCalls(hs);
      await g.groupMembers(_gr); // lädt den Zustand aus der Datenbank nach; ein teilweise geladener Raum kennt kaum Mitglieder
      await nudge(g, _memberChange(_anna, 'join', joined: 60));
      final list = await g.groupMembers(_gr);
      expect(membersCalls(hs), before, reason: 'bei G > 50 kein Abruf der Mitgliederliste');
      expect(list.map((m) => m.userId), contains(_anna), reason: 'die lokal bekannten Mitglieder');
      expect(list.map((m) => m.userId), isNot(contains(_dora)), reason: 'möglicherweise unvollständig, aber nichts erfunden');
    });
  });

  group('inviteToGroup', () {
    // 49 beigetretene Mitglieder: ich und 48 weitere.
    List<String> many(int n) => <String>[_me, for (var i = 0; i < n - 1; i++) '@m$i:hs.example'];

    test('Kontrollfall: bestätigter Kontakt wird eingeladen (Liste frisch geholt, Erreichbarkeit frisch, ein invite), Liste nachgeführt, kein Pin, kein Datensatz', () async {
      // Einladungszahl unbekannt: die lokale Liste ist nie vollständig, die frische Liste kommt vom Server.
      final (hs, g, _) = await ready(update: _groupJoined(_gr, invited: null));
      final before = membersCalls(hs);
      await g.inviteToGroup(_gr, _caro);
      expect(invites(hs), 1);
      expect(membersCalls(hs), before + 1, reason: 'eine frische Liste');
      expect(hs.where('POST', '$_gr/invite').single.$3, contains(_caro));
      expect(g.debugGroupMembers[_gr]![_caro], GroupMembership.invite);
      expect(g.debugContactSessionPinIds, isEmpty, reason: 'der Pin entsteht erst beim Beitritt');
      expect(hs.where('PUT', 'account_data'), isEmpty, reason: 'kein Datensatz, keine Kontodaten');
      expect(g.debugAdminOps, isEmpty);
    });

    test('Familienmitglied wird eingeladen (auch ohne Kontakt-Datensatz)', () async {
      final (hs, g, _) = await ready();
      await g.inviteToGroup(_gr, _ben);
      expect(invites(hs), 1);
    });

    test('Größe: G = 49 ok; G = 50 (40 + 10 eingeladen) und G > 50 ⇒ groupFull ohne Abruf (Aufrufzähler); unbekannte Größe ⇒ serverUnreachable ohne Abruf', () async {
      final (hs1, g1, _) = await ready(update: _groupJoined(_gr, members: many(49)), serverMembers: many(49));
      await g1.inviteToGroup(_gr, _caro);
      expect(invites(hs1), 1, reason: 'G = 49: eine Person mehr sind 50');

      final (hs2, g2, _) = await ready(update: _groupJoined(_gr, joined: 40, invited: 10, memberEvents: 1), serverMembers: many(40));
      final c2 = membersCalls(hs2);
      await expectLater(g2.inviteToGroup(_gr, _caro), _error(GatewayError.groupFull));
      expect(membersCalls(hs2), c2, reason: 'G ≥ 50: kein Abruf');
      expect(invites(hs2), 0);

      final (hs3, g3, _) = await ready(update: _groupJoined(_gr, joined: 60, memberEvents: 1));
      final c3 = membersCalls(hs3);
      await expectLater(g3.inviteToGroup(_gr, _caro), _error(GatewayError.groupFull));
      expect(membersCalls(hs3), c3, reason: 'G > 50: kein Abruf');

      final unknown = _groupJoined(_gr);
      ((((unknown['rooms']! as Map)['join']! as Map)[_gr]! as Map)['summary']! as Map).remove('m.joined_member_count');
      final (hs4, g4, _) = await ready(update: unknown);
      final c4 = membersCalls(hs4);
      await expectLater(g4.inviteToGroup(_gr, _caro), _error(GatewayError.serverUnreachable));
      expect(membersCalls(hs4), c4, reason: 'unbekannte Größe: kein Abruf');
      expect(invites(hs4), 0);
    });

    test('die frische Liste ergibt G + 1 > 50 (40 beigetreten, Einladungszahl unbekannt, 30 Eingeladene auf dem Server) ⇒ groupFull', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, joined: 40, invited: null, memberEvents: 1), serverMembers: many(40));
      for (var i = 0; i < 30; i++) {
        hs.extra['@i$i:hs.example'] = 'invite';
      }
      await expectLater(g.inviteToGroup(_gr, _caro), _error(GatewayError.groupFull));
      expect(invites(hs), 0);
    });

    test('gescheiterter Abruf der Liste ⇒ serverUnreachable, kein invite', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, invited: null));
      hs.membersFail = true;
      await expectLater(g.inviteToGroup(_gr, _caro), _error(GatewayError.serverUnreachable));
      expect(invites(hs), 0);
    });

    test('läuft schon ein Abruf (Hintergrundabruf nach createGroup), wartet die Einladung auf diesen: ein Abruf, kein serverUnreachable', () async {
      final (hs, g) = await signedIn();
      g.debugOutboundPort = FakeOutboundSessionPort();
      hs.members = <String>[_me, _fremd, _anna];
      hs.holdMembers = Completer<void>();
      // Einladungszahl unbekannt: die lokale Liste ist nie vollständig, der Abgleich startet den Abruf und er hängt.
      await settle(g, _groupJoined(_gr, invited: null, memberEvents: 1));
      expect(membersCalls(hs), 1, reason: 'der Hintergrundabruf läuft');
      final done = g.inviteToGroup(_gr, _caro);
      await Future<void>.delayed(_settle);
      expect(invites(hs), 0, reason: 'wartet auf die frische Liste');
      hs.holdMembers!.complete();
      await done;
      expect(membersCalls(hs), 1, reason: 'derselbe Abruf, kein zweiter');
      expect(invites(hs), 1);
    });

    test('Gesundheit zuerst: unverschlüsselt, Regel, Verlauf ⇒ kein invite (auch bei sonst erlaubtem Ziel)', () async {
      final cases = <String, (Map<String, Object?>, GatewayError)>{
        'unverschlüsselt': (_groupJoined(_gr, megolm: false), GatewayError.encryptionUnavailable),
        'Regel public': (_groupJoined(_gr, rule: 'public'), GatewayError.notAllowed),
        'Verlauf shared': (_groupJoined(_gr, history: 'shared'), GatewayError.notAllowed),
        'Regel fehlt': (_groupJoined(_gr, rule: null), GatewayError.notAllowed),
      };
      for (final e in cases.entries) {
        final (hs, g, _) = await ready(update: e.value.$1);
        await expectLater(g.inviteToGroup(_gr, _caro), _error(e.value.$2), reason: e.key);
        expect(invites(hs), 0, reason: e.key);
      }
    });

    test('Recht fehlt (Stufe unter der Schwelle invite) ⇒ notAllowed', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: _pl(users: <String, int>{_anna: 100})));
      await expectLater(g.inviteToGroup(_gr, _caro), _error(GatewayError.notAllowed));
      expect(invites(hs), 0);
    });

    test('Ziel: Nicht-Kontakt, blockiert, ich selbst ⇒ notAllowed; ungültige Kennung ⇒ invalidInput; schon dabei oder eingeladen ⇒ alreadyExists', () async {
      final (hs, g, _) = await ready();
      await expectLater(g.inviteToGroup(_gr, _dora), _error(GatewayError.notAllowed), reason: 'kein bestätigter Kontakt');
      await expectLater(g.inviteToGroup(_gr, _me), _error(GatewayError.notAllowed), reason: 'ich selbst');
      await expectLater(g.inviteToGroup(_gr, 'keine-kennung'), _error(GatewayError.invalidInput));
      await expectLater(g.inviteToGroup(_gr, _anna), _error(GatewayError.alreadyExists), reason: 'schon Mitglied');
      expect(invites(hs), 0);

      final (hs2, g2, _) = await ready(policy: const ContactPolicy(enabled: true, contacts: <String, ContactState>{_caro: ContactState.accepted}, blocked: <String>{_caro}, groups: <String>{_gr}));
      await expectLater(g2.inviteToGroup(_gr, _caro), _error(GatewayError.notAllowed), reason: 'blockiert');
      expect(invites(hs2), 0);

      final (hs3, g3, _) = await ready(policy: const ContactPolicy(enabled: true, contacts: <String, ContactState>{_caro: ContactState.outgoing}, groups: <String>{_gr}));
      await expectLater(g3.inviteToGroup(_gr, _caro), _error(GatewayError.notAllowed), reason: 'nur ausgehend, nicht bestätigt');
      expect(invites(hs3), 0);

      final (hs4, g4, _) = await ready(update: _groupJoined(_gr, members: <String>[_me, _fremd], invitedMembers: <String>[_caro]), serverMembers: <String>[_me, _fremd]);
      hs4.extra[_caro] = 'invite';
      await expectLater(g4.inviteToGroup(_gr, _caro), _error(GatewayError.alreadyExists), reason: 'schon eingeladen');
      expect(invites(hs4), 0);
    });

    test('Erreichbarkeit frisch: nicht erreichbar ⇒ peerNotReachable; unbekannt ⇒ serverUnreachable; geänderter Schlüssel und gesperrte Geräte ⇒ notAllowed', () async {
      final (hs, g, _) = await ready();
      g.debugDevicesOf = (id) => id == _caro ? <bool>[false] : <bool>[true];
      await expectLater(g.inviteToGroup(_gr, _caro), _error(GatewayError.peerNotReachable));
      g.debugDevicesOf = (id) => id == _caro ? null : <bool>[true];
      await expectLater(g.inviteToGroup(_gr, _caro), _error(GatewayError.serverUnreachable));
      g.debugDevicesOf = (id) => <bool>[true];
      blockedDevice(g, _caro);
      await expectLater(g.inviteToGroup(_gr, _caro), _error(GatewayError.notAllowed), reason: 'gesperrte Geräte');
      expect(invites(hs), 0);

      final (hs2, g2, _) = await ready();
      master(g2, _caro, k1);
      await g2.inviteToGroup(_gr, _caro); // Erstkontakt: bekannter Schlüssel, kein Wechsel
      expect(invites(hs2), 1);
      final (hs3, g3, _) = await ready();
      g3.debugSeedSessionPins(<String>[_caro]); // ein früher gemerkter Schlüssel, der jetzt nicht mehr passt
      master(g3, _caro, k1);
      await expectLater(g3.inviteToGroup(_gr, _caro), _error(GatewayError.notAllowed), reason: 'Schlüssel geändert');
      expect(invites(hs3), 0);
    });

    test('Verwaltungsoperationen: je Raum eine zugleich (groupBusy), das Senden bleibt nicht gesperrt, _reconcileGroup läuft weiter, im finally freigegeben', () async {
      final (hs, g, port) = await ready(open: true, session: true);
      hs.holdInvite = Completer<void>();
      final first = g.inviteToGroup(_gr, _caro);
      await Future<void>.delayed(_settle);
      expect(g.debugAdminOps, <String>{_gr});
      expect(g.debugGroupOps, isEmpty, reason: 'adminOps ist nicht groupOps');
      await expectLater(g.inviteToGroup(_gr, _ben), _error(GatewayError.groupBusy));
      await expectLater(g.removeFromGroup(_gr, _anna), _error(GatewayError.groupBusy));
      await expectLater(g.setGroupAdmin(_gr, _anna, admin: true), _error(GatewayError.groupBusy));
      await g.sendMessage('Hallo', threadId: _gr);
      expect(groupSends(hs), 1, reason: 'das Senden ist während der Verwaltung nicht gesperrt');
      await nudge(g, _memberChange(_anna, 'leave', joined: 2));
      expect(port.wipes, 1, reason: '_reconcileGroup läuft während der Verwaltungsoperation weiter');
      hs.holdInvite!.complete();
      await first;
      expect(g.debugAdminOps, isEmpty);
      // Auch nach einem Fehler freigegeben.
      final (hs2, g2, _) = await ready(update: _groupJoined(_gr, invited: null));
      hs2.membersFail = true;
      await expectLater(g2.inviteToGroup(_gr, _caro), throwsA(isA<GatewayException>()));
      expect(g2.debugAdminOps, isEmpty);
    });

    test('Epoche wechselt im await (Abmelden während des Abrufs) ⇒ notAllowed, nichts eingeladen', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, invited: null));
      hs.holdMembers = Completer<void>();
      final done = g.inviteToGroup(_gr, _caro);
      await Future<void>.delayed(_settle);
      await g.logout();
      hs.holdMembers!.complete();
      await expectLater(done, _error(GatewayError.notAllowed));
      expect(invites(hs), 0);
    });
  });

  group('removeFromGroup', () {
    test('Kontrollfall: ruft kick; vor dem Sync des Weggangs Senden groupBusy (auch nach Sync, Abruf und openThread), nach dem Weggang genau ein Wisch und Senden frei', () async {
      final (hs, g, port) = await ready(open: true, session: true);
      await g.sendMessage('Davor', threadId: _gr);
      expect(groupSends(hs), 1);
      await g.removeFromGroup(_gr, _anna);
      expect(kicks(hs), 1);
      expect(hs.where('POST', '$_gr/kick').single.$3, contains(_anna));
      expect(g.debugRemoving, <String, Set<String>>{_gr: <String>{_anna}});
      await expectLater(g.sendMessage('Danach', threadId: _gr), _error(GatewayError.groupBusy));
      await Future<void>.delayed(_settle);
      expect(g.threads.firstWhere((t) => t.kind == ThreadKind.group).sendLock.name, 'wechsel');
      await nudge(g);
      await g.openThread(_gr);
      await expectLater(g.sendMessage('Danach', threadId: _gr), _error(GatewayError.groupBusy), reason: 'der Weggang ist noch nicht im Zustand');
      expect(port.wipes, 0);
      await nudge(g, _memberChange(_anna, 'leave', joined: 2));
      expect(port.wipes, 1);
      expect(g.debugRemoving, isEmpty);
      await g.sendMessage('Danach', threadId: _gr);
      expect(groupSends(hs), 2);
    });

    test('kick mit definitivem Fehler (M_FORBIDDEN): die Sperre fällt sofort, Senden gelingt wieder; kick mit Zeitablauf lässt sie stehen', () async {
      final (hs, g, _) = await ready(open: true, session: true);
      hs.kickMode = 'forbidden';
      await expectLater(g.removeFromGroup(_gr, _anna), _error(GatewayError.notAllowed));
      expect(g.debugRemoving, isEmpty);
      await g.sendMessage('Hallo', threadId: _gr);
      expect(groupSends(hs), 1);
      hs.kickMode = 'timeout';
      await expectLater(g.removeFromGroup(_gr, _anna), _error(GatewayError.serverUnreachable));
      expect(g.debugRemoving, <String, Set<String>>{_gr: <String>{_anna}}, reason: 'der kick kann noch ankommen: fail-closed');
      await expectLater(g.sendMessage('Hallo', threadId: _gr), _error(GatewayError.groupBusy));
      expect(g.debugAdminOps, isEmpty);
    });

    test('Zustand „Wisch fällig“ (pendingWipe) und „Wechsel läuft“ (groupOps) halten die Sperre, auch wenn das Ziel lokal schon weg ist', () async {
      final (hs, g, port) = await ready(open: true, session: true);
      await g.removeFromGroup(_gr, _anna);
      port.wipeIneffective = true;
      await nudge(g, _memberChange(_anna, 'leave', joined: 2));
      expect(g.debugPendingWipe, <String>{_gr});
      expect(g.debugRemoving, <String, Set<String>>{_gr: <String>{_anna}}, reason: 'ein fälliger Wisch hält die Sperre über pendingWipe');
      port.wipeIneffective = false;
      await nudge(g);
      expect(g.debugPendingWipe, isEmpty);
      expect(g.debugRemoving, isEmpty, reason: 'nach belegtem Wisch fällt die Sperre');
      await g.sendMessage('Danach', threadId: _gr);
      expect(groupSends(hs), 1);

      final (_, g2, port2) = await ready(open: true, session: true);
      await g2.removeFromGroup(_gr, _anna);
      port2.holdWipe = Completer<void>();
      await _sync(g2, _memberChange(_anna, 'leave', joined: 2));
      await Future<void>.delayed(_settle);
      expect(g2.debugGroupOps, <String>{_gr});
      expect(g2.debugRemoving, isNotEmpty, reason: 'der Wechsel läuft noch: nicht freigeben');
      port2.holdWipe!.complete();
      await Future<void>.delayed(_settle);
      expect(g2.debugRemoving, isEmpty);
    });

    test('Freigabe in jedem Rückkehrpfad: G > 50 (keine Liste, lastMembers == null) fällt mit dem lokalen Weggang; lastMembers == null gibt von sich aus nie frei', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, joined: 60), session: true, open: true);
      final before = membersCalls(hs);
      await expectLater(g.removeFromGroup(_gr, _anna), _error(GatewayError.notFound), reason: 'ohne lokalen Eintrag (Lazy Loading) kein Entfernen');
      await nudge(g, _memberChange(_anna, 'join', joined: 60)); // jetzt ist anna lokal bekannt
      await g.removeFromGroup(_gr, _anna);
      await nudge(g);
      await nudge(g);
      expect(g.debugRemoving, <String, Set<String>>{_gr: <String>{_anna}}, reason: 'lastMembers == null gilt nie als „weg“');
      expect(membersCalls(hs), before, reason: 'bei G > 50 keine Abfrage');
      await nudge(g, _memberChange(_anna, 'leave', joined: 59));
      expect(g.debugRemoving, isEmpty, reason: 'fällt mit dem lokalen Weggang');
    });

    test('„Server sagt weg, lokal noch nicht“: genau eine umgehende frische Abfrage, die Liste löst über lastMembers auf (kein Dauerlauf)', () async {
      // Einladungszahl unbekannt: die lokale Liste ist nie vollständig, die Liste des Servers bleibt maßgeblich.
      final (hs, g, port) = await ready(update: _groupJoined(_gr, invited: null, memberEvents: 1), open: true, session: true);
      g.debugAgeGroupMembers(_gr, Duration.zero);
      await g.removeFromGroup(_gr, _anna);
      expect(g.debugRemoving, isNotEmpty);
      final before = membersCalls(hs);
      hs.members = <String>[_me, _fremd]; // der Server hat anna schon entfernt, der lokale Zustand noch nicht
      for (var i = 0; i < 4; i++) {
        await nudge(g);
      }
      expect(membersCalls(hs), before + 1, reason: 'je Eintrag höchstens eine umgehende Abfrage, auch bei laufender Refresh-Schleife');
      expect(port.wipes, 1, reason: 'die frische Liste lässt den Abgleich den Weggang erkennen und wischen');
      expect(g.debugRemoving, isEmpty, reason: 'anna steht nicht mehr in lastMembers');
      await g.sendMessage('Danach', threadId: _gr);
      expect(groupSends(hs), 1);
    });

    test('kick kam nie an: eine frische Abfrage, danach (Obergrenze 10 Minuten) fällt die Sperre; nie eine zweite Abfrage', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, invited: null), open: true, session: true);
      await g.removeFromGroup(_gr, _anna);
      final before = membersCalls(hs);
      for (var i = 0; i < 4; i++) {
        await nudge(g);
      }
      expect(membersCalls(hs), before + 1, reason: 'genau eine umgehende Abfrage');
      expect(g.debugRemoving, isNotEmpty, reason: 'das Ziel ist weiter Mitglied, die Obergrenze ist noch nicht erreicht');
      g.debugAgeRemoving(_gr, const Duration(minutes: 11));
      await nudge(g);
      expect(g.debugRemoving, isEmpty, reason: 'älter als 10 Minuten und weiter Mitglied: verworfen');
      expect(membersCalls(hs), before + 1, reason: 'nie eine zweite Abfrage je Eintrag');
      await g.sendMessage('Wieder frei', threadId: _gr);
      expect(groupSends(hs), 1);
    });

    test('Ziel ohne lokalen Mitgliedseintrag ⇒ notFound; Selbstentfernen, gleiche und höhere Stufe, fehlendes Recht ⇒ notAllowed; nichts geht an den Server', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: _pl(users: <String, int>{_me: 50, _anna: 50, _fremd: 100})));
      await expectLater(g.removeFromGroup(_gr, '@wer:hs.example'), _error(GatewayError.notFound));
      await expectLater(g.removeFromGroup(_gr, _me), _error(GatewayError.notAllowed), reason: 'ich selbst');
      await expectLater(g.removeFromGroup(_gr, _anna), _error(GatewayError.notAllowed), reason: '50 gegen 50');
      await expectLater(g.removeFromGroup(_gr, _fremd), _error(GatewayError.notAllowed), reason: 'höhere Stufe');
      await expectLater(g.removeFromGroup(_gr, 'keine-kennung'), _error(GatewayError.invalidInput));
      expect(kicks(hs), 0);
      final (hs2, g2, _) = await ready(update: _groupJoined(_gr, pl: _pl(users: <String, int>{_anna: 100})));
      await expectLater(g2.removeFromGroup(_gr, _fremd), _error(GatewayError.notAllowed), reason: 'Stufe 0 unter der Schwelle kick');
      expect(kicks(hs2), 0);
    });

    test('ein nur Eingeladener lässt sich entfernen; ein Admin (Stufe 50) entfernt ein Mitglied, wenn er die Schwelle erreicht', () async {
      final (hs, g, _) = await ready(
        update: _groupJoined(_gr, members: <String>[_me, _fremd], invitedMembers: <String>[_caro], pl: _pl(users: <String, int>{_me: 50, _anna: 100})),
        serverMembers: <String>[_me, _fremd],
      );
      hs.extra[_caro] = 'invite';
      await g.removeFromGroup(_gr, _caro);
      expect(kicks(hs), 1);
      await g.removeFromGroup(_gr, _fremd);
      expect(kicks(hs), 2);
    });

    test('Lebenszyklus: removing überlebt forget/clearRooms (zurückkehrender Raum bleibt gesperrt), clearAll löscht, ein verlassener Raum (left) auch', () async {
      final (hs, g, _) = await ready(open: true, session: true);
      await g.removeFromGroup(_gr, _anna);
      g.setContactPolicy(_nobody);
      await Future<void>.delayed(_settle);
      expect(g.debugGroups, isEmpty);
      expect(g.debugRemoving, <String, Set<String>>{_gr: <String>{_anna}}, reason: 'überlebt forget');
      g.setContactPolicy(_rec);
      await nudge(g);
      expect(g.debugGroups.keys, contains(_gr));
      await g.openThread(_gr);
      await expectLater(g.sendMessage('Hallo', threadId: _gr), _error(GatewayError.groupBusy), reason: 'der zurückkehrende Raum bleibt gesperrt');
      expect(groupSends(hs), 0);
      await g.logout();
      expect(g.debugRemoving, isEmpty, reason: 'clearAll');

      final (_, g2, _) = await ready(open: true, session: true);
      await g2.removeFromGroup(_gr, _anna);
      await nudge(g2, <String, Object?>{
        'rooms': <String, Object?>{
          'leave': <String, Object?>{
            _gr: <String, Object?>{
              'state': <String, Object?>{
                'events': <Object?>[_state('m.room.member', _fremd, <String, Object?>{'membership': 'leave'}, key: _me)],
              },
            },
          },
        },
      });
      expect(g2.leftGroupRooms, <String>{_gr});
      expect(g2.debugRemoving, isEmpty, reason: 'ein Raum in left hat nichts mehr zu sperren');
    });

    test('Epoche wechselt im kick (Abmelden während des Servers): der Fehlerpfad rührt den Zustand des neuen Kontos nicht an', () async {
      final (hs, g, _) = await ready();
      hs.kickMode = 'forbidden';
      final r = g.removeFromGroup(_gr, _anna);
      await expectLater(r, _error(GatewayError.notAllowed));
      expect(g.debugAdminOps, isEmpty);
    });
  });

  group('setGroupAdmin', () {
    Map<String, Object?> written(_Hs hs) => json.decode(hs.where('PUT', '$_gr/state/m.room.power_levels').single.$3) as Map<String, Object?>;

    void serve(_Hs hs, Map<String, Object?> pl) => hs.serverState['$_gr|m.room.power_levels'] = pl;

    test('Ernennen: Stufe 50 (nie 100), nur users[anna] ändert sich, alle anderen Felder bleiben gleich', () async {
      final pl = _pl(users: <String, int>{_me: 100, _caro: 50});
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: pl));
      serve(hs, pl);
      await g.setGroupAdmin(_gr, _anna, admin: true);
      final w = written(hs);
      expect((w['users']! as Map)[_anna], 50);
      expect((w['users']! as Map)[_me], 100);
      expect((w['users']! as Map)[_caro], 50);
      final rest = Map<String, Object?>.of(w)..remove('users');
      final orig = Map<String, Object?>.of(pl)..remove('users');
      expect(json.encode(rest), json.encode(orig), reason: 'alle übrigen Felder bleiben unverändert');
      expect(g.debugAdminOps, isEmpty);
    });

    test('Abstufen: Stufe 0 entfernt den Eintrag (users_default gilt), übrige Felder gleich', () async {
      final pl = _pl(users: <String, int>{_me: 100, _anna: 50});
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: pl));
      serve(hs, pl);
      await g.setGroupAdmin(_gr, _anna, admin: false);
      final w = written(hs);
      expect((w['users']! as Map).containsKey(_anna), isFalse);
      expect((w['users']! as Map)[_me], 100);
      expect(w['users_default'], 0);
      final rest = Map<String, Object?>.of(w)..remove('users');
      final orig = Map<String, Object?>.of(pl)..remove('users');
      expect(json.encode(rest), json.encode(orig));
    });

    test('Antwort des Servers fehlt oder ist nicht abrufbar ⇒ Fehler ohne Schreiben', () async {
      final (hs, g, _) = await ready();
      await expectLater(g.setGroupAdmin(_gr, _anna, admin: true), _error(GatewayError.serverUnreachable));
      expect(plWrites(hs), 0);
    });

    test('Rechte laufen gegen die FRISCH gelesenen Stufen: lokal Admin, laut Server nicht ⇒ notAllowed', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: _pl(users: <String, int>{_me: 100})));
      serve(hs, _pl(users: <String, int>{_me: 0, _caro: 100}));
      await expectLater(g.setGroupAdmin(_gr, _anna, admin: true), _error(GatewayError.notAllowed));
      expect(plWrites(hs), 0);
    });

    test('50 gegen 50, Selbsternennung, schon Admin ernennen, Nicht-Admin entziehen, nur Eingeladener ⇒ gesperrt; ein Eingeladener ⇒ notFound', () async {
      final pl = _pl(users: <String, int>{_me: 50, _anna: 50, _caro: 100});
      final (hs, g, _) = await ready(update: _groupJoined(_gr, members: <String>[_me, _fremd, _anna], invitedMembers: <String>[_dora], pl: pl));
      serve(hs, pl);
      await expectLater(g.setGroupAdmin(_gr, _anna, admin: false), _error(GatewayError.notAllowed), reason: '50 gegen 50');
      await expectLater(g.setGroupAdmin(_gr, _me, admin: true), _error(GatewayError.notAllowed), reason: 'Selbsternennung nie');
      await expectLater(g.setGroupAdmin(_gr, _anna, admin: true), _error(GatewayError.notAllowed), reason: 'schon Admin');
      await expectLater(g.setGroupAdmin(_gr, _fremd, admin: false), _error(GatewayError.notAllowed), reason: 'kein Admin');
      await expectLater(g.setGroupAdmin(_gr, _dora, admin: true), _error(GatewayError.notFound), reason: 'nur eingeladen');
      await expectLater(g.setGroupAdmin(_gr, 'keine-kennung', admin: true), _error(GatewayError.invalidInput));
      expect(plWrites(hs), 0);
    });

    test('Selbstabstufung: der einzige Admin ⇒ notAllowed (isLastAdmin), mit einem zweiten beigetretenen Admin erlaubt; bei G > 50 oder unbekannter Liste ⇒ notAllowed', () async {
      final solo = _pl(users: <String, int>{_me: 100});
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: solo));
      serve(hs, solo);
      await expectLater(g.setGroupAdmin(_gr, _me, admin: false), _error(GatewayError.notAllowed), reason: 'der einzige Admin');
      expect(plWrites(hs), 0);

      final duo = _pl(users: <String, int>{_me: 100, _anna: 50});
      final (hs2, g2, _) = await ready(update: _groupJoined(_gr, pl: duo));
      serve(hs2, duo);
      await g2.setGroupAdmin(_gr, _me, admin: false);
      expect(((written(hs2)['users']!) as Map).containsKey(_me), isFalse);

      // Ein zweiter Admin, der nur eingeladen ist, zählt nicht (nur beigetretene).
      final inv = _pl(users: <String, int>{_me: 100, _dora: 50});
      final (hs3, g3, _) = await ready(update: _groupJoined(_gr, members: <String>[_me, _fremd], invitedMembers: <String>[_dora], pl: inv), serverMembers: <String>[_me, _fremd]);
      serve(hs3, inv);
      await expectLater(g3.setGroupAdmin(_gr, _me, admin: false), _error(GatewayError.notAllowed));

      final big = _pl(users: <String, int>{_me: 100, _anna: 50});
      final (hs4, g4, _) = await ready(update: _groupJoined(_gr, joined: 60, pl: big));
      serve(hs4, big);
      await expectLater(g4.setGroupAdmin(_gr, _me, admin: false), _error(GatewayError.notAllowed), reason: 'G > 50: Liste unbekannt, fail-closed');
      expect(plWrites(hs4), 0);
    });

    test('die Sperre der Selbstabstufung liegt im Gateway, nicht in canSetAdmin: ein anderes Mitglied abstufen geht auch für den einzigen Admin (er bleibt Admin)', () async {
      final pl = _pl(users: <String, int>{_me: 100, _anna: 50});
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: pl));
      serve(hs, pl);
      await g.setGroupAdmin(_gr, _anna, admin: false);
      expect(plWrites(hs), 1);
    });

    test('parallele Operation ⇒ groupBusy (der Zustand wird während des Lesens gehalten)', () async {
      final pl = _pl(users: <String, int>{_me: 100});
      final (hs, g, _) = await ready(update: _groupJoined(_gr, pl: pl));
      serve(hs, pl);
      hs.holdPl = Completer<void>();
      final first = g.setGroupAdmin(_gr, _anna, admin: true);
      await Future<void>.delayed(_settle);
      await expectLater(g.setGroupAdmin(_gr, _fremd, admin: true), _error(GatewayError.groupBusy));
      hs.holdPl!.complete();
      await first;
      expect(g.debugAdminOps, isEmpty);
    });
  });

  group('Identität und Pins von Gruppen-Fremden (K4-3, §8.5)', () {
    test('Erstpin ohne groupMembers: der Abgleich je Sync pinnt Fremde der Gruppe (Sitzungs-Pin), nicht Familienmitglieder, nie Kontodaten', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, members: <String>[_me, _fremd, _anna, _cara]), serverMembers: <String>[_me, _fremd, _anna, _cara]);
      master(g, _anna, k1);
      master(g, _cara, k1);
      await nudge(g);
      expect(g.debugContactSessionPinIds, <String>{_anna}, reason: 'Familienmitglieder nie mit mirror:false gepinnt');
      expect(g.debugGroupIdentity[_anna], IdentityStatus.pinned);
      expect(hs.where('PUT', 'account_data').where((c) => c.$3.contains(_anna)), isEmpty, reason: 'ein Kontakt-Pin steht nie in den Kontodaten');
    });

    test('Wechsel eines Fremden sperrt Geräte und zählt im Thread als ausgelassen, ohne groupMembers aufzurufen', () async {
      final (_, g, _) = await ready();
      master(g, _anna, k1);
      await nudge(g);
      master(g, _anna, k2);
      await nudge(g);
      expect(g.debugIdentityChanged, contains(_anna));
      final t = g.threads.firstWhere((t) => t.kind == ThreadKind.group);
      expect(t.identityChangedCount, 1);
      expect(t.unreachableCount, 1);
      expect(g.debugGroupIdentity[_anna], IdentityStatus.changed);
    });

    test('Tor: der Wechsel wird im Tor SYNCHRON ausgewertet (ohne Sync und ohne groupMembers): das Mitglied zählt als ausgelassen', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, members: <String>[_me, _anna]), serverMembers: <String>[_me, _anna], open: true, session: true);
      master(g, _anna, k1);
      await nudge(g);
      expect(g.debugContactSessionPinIds, contains(_anna));
      master(g, _anna, k2); // Wechsel ohne weiteren Sync
      expect(g.debugIdentityChanged, isNot(contains(_anna)));
      await expectLater(g.sendMessage('Hallo', threadId: _gr), _error(GatewayError.peerNotReachable));
      expect(g.debugIdentityChanged, contains(_anna), reason: 'das Tor hat ausgewertet');
      expect(groupSends(hs), 0);
    });

    test('je eindeutiger Kennung nur eine Auswertung je Lauf (zwei Gruppen mit denselben Fremden)', () async {
      const gr2 = '!gr2:hs.example';
      final (hs, g) = await signedIn(const ContactPolicy(enabled: true, groups: <String>{_gr, gr2}));
      g.debugOutboundPort = FakeOutboundSessionPort();
      hs.members = <String>[_me, _fremd, _anna];
      await settle(g, <String, Object?>{
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            ...(_groupJoined(_gr)['rooms']! as Map)['join']! as Map<String, Object?>,
            ...(_groupJoined(gr2)['rooms']! as Map)['join']! as Map<String, Object?>,
          },
        },
      });
      expect(g.debugGroups.keys.toSet(), <String>{_gr, gr2});
      final before = g.debugGroupIdentityEvals;
      await nudge(g);
      expect(g.debugGroupIdentityEvals - before, 2, reason: 'fremd und anna je einmal, nicht je Gruppe');
    });

    test('Obergrenze 500: der reale Bestand zählt (Familienmitglieder nicht); darüber kein neuer Pin; bestehende Pins bleiben wirksam; je Lauf fortgezählt', () async {
      final (_, g, _) = await ready();
      g.debugSeedSessionPins(<String>[for (var i = 0; i < 499; i++) '@p$i:hs.example', _cara, _ben]);
      master(g, _anna, k1);
      master(g, _fremd, k1);
      await nudge(g);
      // Bestand 499 (ohne Familie): genau ein Platz, im selben Lauf fortgezählt; wer zuerst kommt, bekommt ihn.
      final pinned = <String>{_anna, _fremd}.intersection(g.debugContactSessionPinIds);
      expect(pinned, hasLength(1), reason: 'ein Platz, danach voll');
      final other = _anna == pinned.single ? _fremd : _anna;
      expect(g.debugGroupIdentity[other], IdentityStatus.unknown);
      expect(g.debugContactSessionPinIds.length, 499 + 2 + 1, reason: '499 Fremde + 2 Familienmitglieder (zählen nicht) + 1 neuer Pin');
      master(g, pinned.single, k2);
      await nudge(g);
      expect(g.debugIdentityChanged, contains(pinned.single), reason: 'bestehende Pins werden bei vollem Bestand weiter ausgewertet');
    });

    test('Obergrenze 500 nach einem Neustart: der Bestand kommt aus der lokalen Ablage (kein neuer Pin, auch nicht lokal), bestehende Pins bleiben wirksam, nichts wird gelöscht', () async {
      final kv = MemoryKeyValueStore();
      final seeded = <String, String>{for (var i = 0; i < 498; i++) '@p$i:hs.example': 'LOCAL$i', _cara: k1, _fremd: k1};
      kv.data[LocalIdentityPins.storeKey] = json.encode(<String, Object?>{'user_id': _me, 'pins': seeded});
      final (hs, g) = await signedIn(_rec, kv);
      g.debugOutboundPort = FakeOutboundSessionPort();
      hs.members = <String>[_me, _fremd, _anna];
      await settle(g, _groupJoined(_gr));
      master(g, _anna, k1);
      master(g, _fremd, k1);
      await nudge(g);
      // Bestand: 498 Fremde + fremd (Familie _cara zählt nicht) = 499: ein Platz für anna.
      expect(g.localIdentityPins.keys, contains(_anna), reason: 'ein Platz war frei');
      expect(g.localIdentityPins.length, 498 + 2 + 1);
      master(g, _anna, k2);
      await nudge(g);
      expect(g.debugIdentityChanged, contains(_anna), reason: 'bestehender Pin wirksam');
      expect(g.localIdentityPins.length, 498 + 2 + 1, reason: 'nichts gelöscht');
    });

    test('Obergrenze 500 mit vollem lokalem Bestand: kein neuer Pin, weder Sitzung noch lokal', () async {
      final kv = MemoryKeyValueStore();
      final seeded = <String, String>{for (var i = 0; i < 500; i++) '@p$i:hs.example': 'LOCAL$i'};
      kv.data[LocalIdentityPins.storeKey] = json.encode(<String, Object?>{'user_id': _me, 'pins': seeded});
      final (hs, g) = await signedIn(_rec, kv);
      g.debugOutboundPort = FakeOutboundSessionPort();
      hs.members = <String>[_me, _fremd, _anna];
      await settle(g, _groupJoined(_gr));
      master(g, _anna, k1);
      await nudge(g);
      expect(g.localIdentityPins.keys, isNot(contains(_anna)));
      expect(g.debugContactSessionPinIds, isNot(contains(_anna)));
      expect(g.debugGroupIdentity[_anna], IdentityStatus.unknown);
      expect(g.localIdentityPins.length, 500);
    });

    test('kein Löschen beim Entfernen: nach Weggang und Wiederbeitritt mit neuem Schlüssel ⇒ changed (kein TOFU-Reset)', () async {
      final (_, g, _) = await ready(session: true);
      master(g, _anna, k1);
      await nudge(g);
      expect(g.debugContactSessionPinIds, contains(_anna));
      await nudge(g, _memberChange(_anna, 'leave', joined: 2));
      expect(g.debugContactSessionPinIds, contains(_anna), reason: 'Pins bleiben, auch nach dem Weggang');
      await nudge(g, _memberChange(_anna, 'join', joined: 3));
      master(g, _anna, k2);
      await nudge(g);
      expect(g.debugIdentityChanged, contains(_anna));
    });

    test('Akzeptieren für ein Gruppenmitglied wirkt (Sitzung und lokal, nie Kontodaten); Kontrollen: Fremder ohne Gruppe, blockiert, nicht eingestufte Gruppe ⇒ notFound', () async {
      final (hs, g, _) = await ready(update: _groupJoined(_gr, members: <String>[_me, _fremd, _anna]));
      master(g, _anna, k1);
      master(g, _dora, k1);
      await nudge(g);
      master(g, _anna, k2);
      await nudge(g);
      expect(g.debugIdentityChanged, contains(_anna));
      await g.acceptIdentityChange(_anna);
      expect(g.debugIdentityChanged, isNot(contains(_anna)));
      expect(hs.where('PUT', 'account_data'), isEmpty, reason: 'nie familyAccountData');
      master(g, _anna, k2);
      await nudge(g);
      expect(g.debugIdentityChanged, isNot(contains(_anna)), reason: 'der akzeptierte Schlüssel gilt');

      // Fremder ohne Kontakt-Datensatz und in keiner eingestuften Gruppe.
      master(g, _dora, k2);
      await expectLater(g.acceptIdentityChange(_dora), _error(GatewayError.notFound));
      // Blockiertes Gruppenmitglied.
      final (_, g2, _) = await ready(policy: const ContactPolicy(enabled: true, groups: <String>{_gr}, blocked: <String>{_anna}));
      master(g2, _anna, k1);
      await nudge(g2);
      master(g2, _anna, k2);
      await nudge(g2);
      await expectLater(g2.acceptIdentityChange(_anna), _error(GatewayError.notFound));
      // Mitglied einer nicht eingestuften Gruppe (kein Datensatz).
      final (hs3, g3) = await signedIn(_nobody);
      hs3.members = <String>[_me, _fremd, _anna];
      await settle(g3, _groupJoined(_gr));
      master(g3, _anna, k1);
      await nudge(g3);
      master(g3, _anna, k2);
      await nudge(g3);
      await expectLater(g3.acceptIdentityChange(_anna), _error(GatewayError.notFound));
    });

    test('groupMemberAcceptable (reine Regel): nur mit Bereich an, vollständiger Liste, nicht blockiert, in eingestufter Gruppe', () {
      bool f({bool e = true, bool c = true, bool b = false, bool g = true}) => groupMemberAcceptable(enabled: e, membersComplete: c, blocked: b, inClassifiedGroup: g);
      expect(f(), isTrue);
      expect(f(e: false), isFalse);
      expect(f(c: false), isFalse);
      expect(f(b: true), isFalse);
      expect(f(g: false), isFalse);
    });
  });
}
