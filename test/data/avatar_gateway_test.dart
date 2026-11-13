import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/family.dart' show MemberStatus, Role;
import 'package:family_nexus/domain/member_avatars.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';

/// #422, E-101: Avatar als Raumzustand im Gateway (Lesen, Setzen, Änderungsmeldung) und die Freischaltung für
/// Mitglieder in bestehenden Familien (Lesen vom Server, Wächter, Wiederholung) gegen einen nachgestellten Homeserver.
const String _me = '@n1:hs.example';
const String _ben = '@ben:hs.example';
const String _eva = '@eva:hs.example';
const String _fam = '!familie:hs.example';
const String _type = AvatarPresets.type;

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

int _ts = DateTime.utc(2026, 11, 4, 10).millisecondsSinceEpoch;

Map<String, Object?> _state(String type, String key, Map<String, Object?> content, {String? sender}) => <String, Object?>{
      'type': type,
      'state_key': key,
      'event_id': '\$s${_ts++}',
      'sender': sender ?? _me,
      'origin_server_ts': _ts,
      'content': content,
    };

Map<String, Object?> _member(String user, String name) =>
    _state('m.room.member', user, <String, Object?>{'membership': 'join', 'displayname': name}, sender: user);

Map<String, Object?> _levels({int me = 0, bool permitted = false, int stateDefault = 50, int powerLevelsNeeded = 50}) => <String, Object?>{
      'users': <String, int>{_me: me, if (me < 100) _ben: 100},
      'users_default': 0,
      'state_default': stateDefault,
      'events_default': 0,
      'invite': 50,
      'kick': 50,
      'events': <String, int>{
        'm.room.power_levels': powerLevelsNeeded,
        'm.room.name': 50,
        if (permitted) _type: 0,
      },
      'future_field': <String, Object?>{'bleibt': true},
    };

Map<String, Object?> _avatar(String key, Object? content, {String? sender}) =>
    _state(_type, key, content is Map<String, Object?> ? content : <String, Object?>{'preset': content}, sender: sender ?? key);

Map<String, Object?> _syncOf(List<Object?> states, {bool family = true}) => <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _fam: <String, Object?>{
            'state': <String, Object?>{'events': states},
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

List<Object?> _baseState({
  int me = 0,
  bool permitted = false,
  int stateDefault = 50,
  int powerLevelsNeeded = 50,
  List<Object?> avatars = const <Object?>[],
}) =>
    <Object?>[
      _state('m.room.create', '', <String, Object?>{'room_version': '10', 'creator': _ben}, sender: _ben),
      _state('m.room.encryption', '', <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
      _state('m.room.power_levels', '', _levels(me: me, permitted: permitted, stateDefault: stateDefault, powerLevelsNeeded: powerLevelsNeeded)),
      _member(_me, 'Ich'),
      _member(_ben, 'Ben'),
      _member(_eva, 'Eva'),
      ...avatars,
    ];

typedef _Put = ({String path, Map<String, Object?> body});

class _Hs {
  _Hs(this.firstSync, {Map<String, Object?>? serverLevels}) : serverLevels = serverLevels ?? <String, Object?>{};

  final Map<String, Object?> firstSync;

  /// Zustandsereignisse, die [_loggedIn] nach der Anmeldung in einem weiteren Sync einspielt.
  List<Object?> later = <Object?>[];

  /// Stand von `m.room.power_levels` auf dem Server (Antwort auf `GET`, Ziel von `PUT`).
  Map<String, Object?> serverLevels;
  final Completer<void> _hold = Completer<void>();
  int syncs = 0;
  final List<_Put> puts = <_Put>[];
  final List<String> levelReads = <String>[];

  /// Die ersten so vielen Schreibungen von `m.room.power_levels` lehnt der Server mit `M_FORBIDDEN` ab; danach
  /// verhält er sich wie [serverLevels] (und nimmt an).
  int forbidPowerLevelPuts = 0;

  /// Jede Schreibung von `m.room.power_levels` scheitert mit `M_UNKNOWN`.
  bool failPowerLevelPuts = false;

  /// Hängt die Antwort auf das Lesen der Power-Levels, bis der Completer erfüllt ist.
  Completer<void>? holdLevelRead;

  List<_Put> get levelPuts => puts.where((p) => p.path.contains('/state/m.room.power_levels/')).toList();
  List<_Put> get avatarPuts => puts.where((p) => p.path.contains('/state/$_type/')).toList();

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
          if (n == 0) return _json(<String, Object?>{'next_batch': 's1', ...firstSync});
          await _hold.future;
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'GET' && path.endsWith('/state/m.room.power_levels/')) {
          levelReads.add(path);
          await holdLevelRead?.future;
          return _json(json.decode(json.encode(serverLevels)) as Map<String, Object?>);
        }
        if (req.method == 'GET' && path.endsWith('/members')) {
          return _json(<String, Object?>{
            'chunk': <Object?>[_member(_me, 'Ich'), _member(_ben, 'Ben'), _member(_eva, 'Eva')],
          });
        }
        if (req.method == 'PUT' && path.contains('/state/')) {
          final raw = await utf8.decodeStream(body);
          final put = (path: path, body: (json.decode(raw) as Map).cast<String, Object?>());
          puts.add(put);
          if (path.contains('/state/m.room.power_levels/')) {
            if (failPowerLevelPuts) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'kaputt'}, 500);
            if (forbidPowerLevelPuts > 0) {
              forbidPowerLevelPuts--;
              return _json(<String, Object?>{'errcode': 'M_FORBIDDEN', 'error': 'veraltet'}, 403);
            }
            serverLevels = put.body;
          }
          return _json(<String, Object?>{'event_id': '\$put${puts.length}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

Future<SdkMatrixGateway> _loggedIn(_Hs hs, Directory dir, {bool ensure = false, DateTime Function()? now}) async {
  final g = SdkMatrixGateway(
    keyStore: MemoryKeyStore(),
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
    ensureAvatarPermission: ensure,
    now: now,
  );
  addTearDown(() async {
    hs.release();
    await g.close();
  });
  await g.restore();
  await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
  await _until(() => g.family != null && g.initialSyncDone, what: 'Familie aufgebaut');
  if (hs.later.isNotEmpty) {
    await _sync(g, hs.later);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
  return g;
}

Future<void> _until(bool Function() cond, {String? what}) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Bedingung nicht erreicht${what == null ? '' : ': $what'}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _sync(SdkMatrixGateway g, List<Object?> states) =>
    g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{
      'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}',
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _fam: <String, Object?>{
            'timeline': <String, Object?>{'events': <Object?>[], 'limited': false},
            'state': <String, Object?>{'events': states},
          },
        },
      },
    }));

/// Der erste Sync trägt nur, was das SDK sofort im Speicher hält (Raum, Verschlüsselung, Mitglieder); alles Übrige
/// (Power-Levels, Avatare) kommt danach in einem weiteren Sync, den [_loggedIn] einspielt (der Raum ist anfangs
/// `partial`, benutzerdefinierte Zustandstypen übernimmt das SDK erst später).
Future<_Hs> _hsWith(List<Object?> states, {Map<String, Object?>? serverLevels}) async {
  bool early(Object? e) => const <String>['m.room.create', 'm.room.encryption', 'm.room.member'].contains((e! as Map)['type']);
  return _Hs(_syncOf(states.where(early).toList()), serverLevels: serverLevels ?? _levels(me: 50))
    ..later = states.where((e) => !early(e)).toList();
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_avatar');
    addTearDown(() => dir.delete(recursive: true));
  });

  group('Lesen (avatarOf)', () {
    test('gültiger Eintrag, Wechsel ersetzt, ungültige Kennung, fremder Absender, kein preset und {} ergeben null', () async {
      final hs = await _hsWith(_baseState(avatars: <Object?>[
        _avatar(_ben, 'p03'),
        _avatar(_eva, 'zzz'),
        _avatar(_me, <String, Object?>{}),
      ]));
      final g = await _loggedIn(hs, dir);
      expect(g.avatarOf(_ben), 'p03');
      expect(g.avatarOf(_eva), isNull, reason: 'unbekannte Kennung');
      expect(g.avatarOf(_me), isNull, reason: '{} = kein Avatar');
      // Schlüssel ≠ Absender: Ben schreibt in Evas Schlüssel
      await _sync(g, <Object?>[_avatar(_eva, 'p05', sender: _ben)]);
      expect(g.avatarOf(_eva), isNull, reason: 'Absender gleich Schlüssel verlangt');
      // fehlendes preset
      await _sync(g, <Object?>[_avatar(_eva, <String, Object?>{'anderes': 'p05'})]);
      expect(g.avatarOf(_eva), isNull);
      // Wechsel ersetzt die frühere Wahl
      await _sync(g, <Object?>[_avatar(_ben, 'p07')]);
      expect(g.avatarOf(_ben), 'p07');
      // ungültige Matrix-ID
      expect(g.avatarOf('ben'), isNull);
    });

    test('Schlüssel ohne gültige Matrix-ID, Absender gleich Schlüssel: null', () async {
      final hs = await _hsWith(_baseState(avatars: <Object?>[_avatar('ben', 'p03'), _avatar(_ben, 'p04')]));
      final g = await _loggedIn(hs, dir);
      expect(g.avatarOf(_ben), 'p04');
      expect(g.avatarOf('ben'), isNull, reason: 'Eintrag liegt vor, aber die Kennung ist keine Matrix-ID');
    });

    test('500 Müllschlüssel (auch mit fremder Matrix-ID) verdrängen keinen echten Eintrag', () async {
      final junk = <Object?>[
        for (var i = 0; i < 500; i++) _avatar('@junk$i:hs.example', 'p01', sender: _eva),
        for (var i = 0; i < 100; i++) _avatar('kein-at-$i', 'p02', sender: _eva),
      ];
      final hs = await _hsWith(_baseState(avatars: <Object?>[_avatar(_ben, 'p09'), ...junk]));
      final g = await _loggedIn(hs, dir);
      expect(g.avatarOf(_ben), 'p09');
      for (final id in <String>['@junk0:hs.example', '@junk499:hs.example']) {
        expect(g.avatarOf(id), isNull, reason: 'Absender ≠ Schlüssel');
      }
    });

    test('ohne Familie: null und Verfügbarkeit unbekannt', () async {
      final hs = _Hs(<String, Object?>{'rooms': <String, Object?>{}});
      final g = SdkMatrixGateway(
        keyStore: MemoryKeyStore(),
        dbDirectory: dir.path,
        probe: ServerProbe(client: hs.client),
        databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
        httpClient: hs.client,
        ensureAvatarPermission: false,
      );
      addTearDown(() async {
        hs.release();
        await g.close();
      });
      expect(g.avatarOf(_ben), isNull);
      expect(g.avatarAvailability, AvatarAvailability.unknown);
      await g.restore();
      await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
      await _until(() => g.initialSyncDone);
      expect(g.family, isNull);
      expect(g.avatarOf(_ben), isNull);
      expect(g.avatarAvailability, AvatarAvailability.unknown, reason: 'kein Hinweis ohne Familie');
    });
  });

  group('Änderungsmeldung (avatarRevision)', () {
    test('zählt nur bei geändertem Stand hoch, nicht bei einem Sync ohne Avatar-Änderung', () async {
      final hs = await _hsWith(_baseState(avatars: <Object?>[_avatar(_ben, 'p03')]));
      final g = await _loggedIn(hs, dir);
      final start = g.avatarRevision.value;
      // Sync mit anderem Zustand (Raumname), kein Avatar-, Namens- oder Statuswechsel
      await _sync(g, <Object?>[_state('m.room.name', '', <String, Object?>{'name': 'Neu'})]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(g.avatarRevision.value, start);
      // Avatar-Wechsel
      await _sync(g, <Object?>[_avatar(_ben, 'p04')]);
      await _until(() => g.avatarRevision.value > start, what: 'Zähler nach Avatar-Wechsel');
      expect(g.avatarOf(_ben), 'p04');
      final afterAvatar = g.avatarRevision.value;
      // Anzeigename ändert sich ebenfalls (Rückfall-Buchstabe)
      await _sync(g, <Object?>[_member(_ben, 'Bernd')]);
      await _until(() => g.avatarRevision.value > afterAvatar, what: 'Zähler nach Namenswechsel');
    });
  });

  group('Setzen (setMemberAvatar) und Verfügbarkeit', () {
    test('mit Freigabe: eigener Schlüssel, null setzt {}, ungültige Kennung abgelehnt', () async {
      final hs = await _hsWith(_baseState(permitted: true));
      final g = await _loggedIn(hs, dir);
      expect(g.avatarAvailability, AvatarAvailability.settable);
      await g.setMemberAvatar('p02');
      expect(hs.avatarPuts, hasLength(1));
      expect(Uri.decodeComponent(hs.avatarPuts.single.path), endsWith('/state/$_type/$_me'));
      expect(hs.avatarPuts.single.body, <String, Object?>{'preset': 'p02'});
      await g.setMemberAvatar(null);
      expect(hs.avatarPuts.last.body, isEmpty);
      await expectLater(
        g.setMemberAvatar('p99'),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      expect(hs.avatarPuts, hasLength(2), reason: 'ungültige Kennung wird nicht gesendet');
    });

    test('ohne Freigabe: needsModerator und notAllowed, nichts wird gesendet', () async {
      final hs = await _hsWith(_baseState());
      final g = await _loggedIn(hs, dir);
      expect(g.avatarAvailability, AvatarAvailability.needsModerator);
      await expectLater(
        g.setMemberAvatar('p02'),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      expect(hs.avatarPuts, isEmpty);
    });

    test('Person nicht mehr beigetreten: notAllowed und nichts wird gesendet', () async {
      final hs = await _hsWith(_baseState(permitted: true));
      final g = await _loggedIn(hs, dir);
      expect(g.avatarAvailability, AvatarAvailability.settable);
      await _sync(g, <Object?>[
        _state('m.room.member', _me, <String, Object?>{'membership': 'leave'}, sender: _ben),
      ]);
      await _until(() => g.family?.member(_me)?.status != MemberStatus.joined, what: 'nicht mehr beigetreten');
      expect(g.avatarAvailability, AvatarAvailability.settable, reason: 'die Freigabe allein genügt nicht');
      await expectLater(
        g.setMemberAvatar('p02'),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      expect(hs.avatarPuts, isEmpty);
    });

    test('Moderator (50) kann immer setzen, auch ohne Freigabe', () async {
      final hs = await _hsWith(_baseState(me: 50));
      final g = await _loggedIn(hs, dir);
      expect(g.avatarAvailability, AvatarAvailability.settable);
    });
  });

  group('Freischaltung für Mitglieder (bestehende Familien)', () {
    test('liest vom Server, ergänzt nur events[Typ] = 0 und lässt alle übrigen Felder unverändert', () async {
      // Lokaler Stand (Sync) und Serverstand unterscheiden sich: gesendet wird auf Basis des Servers.
      final server = _levels(me: 50)..['future_field'] = <String, Object?>{'nur_server': 1};
      final hs = await _hsWith(_baseState(me: 50), serverLevels: server);
      final g = await _loggedIn(hs, dir);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, hasLength(1));
      expect(hs.levelPuts, hasLength(1));
      final sent = hs.levelPuts.single.body;
      expect((sent['events']! as Map)[_type], 0);
      expect((sent['events']! as Map)['m.room.name'], 50);
      expect(sent['future_field'], <String, Object?>{'nur_server': 1}, reason: 'Serverstand, nicht Zwischenspeicher');
      expect(sent['users'], server['users']);
      expect(sent['state_default'], 50);
      expect(hs.avatarPuts, isEmpty);
    });

    test('Nicht-Moderator tut nichts: weder Lesen noch Schreiben', () async {
      final hs = await _hsWith(_baseState());
      final g = await _loggedIn(hs, dir);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, isEmpty);
      expect(hs.levelPuts, isEmpty);
    });

    test('Rolle Mitglied, aber Power-Levels änderbar: nichts (nur die Moderator-Bedingung verhindert den Lauf)', () async {
      final hs = await _hsWith(_baseState(powerLevelsNeeded: 0));
      final g = await _loggedIn(hs, dir);
      expect(g.family!.myRole, Role.member);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, isEmpty);
      expect(hs.levelPuts, isEmpty);
    });

    test('Moderator ohne Recht, Power-Levels zu ändern: weder Lesen noch Schreiben', () async {
      final hs = await _hsWith(_baseState(me: 50, powerLevelsNeeded: 100));
      final g = await _loggedIn(hs, dir);
      expect(g.family!.myRole, Role.moderator);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, isEmpty);
      expect(hs.levelPuts, isEmpty);
    });

    test('Ersteller ohne gespeicherte Power-Levels (Rolle Moderator, Änderung erlaubt): nichts', () async {
      final states = _baseState()..removeWhere((e) => (e! as Map)['type'] == 'm.room.power_levels');
      states[0] = _state('m.room.create', '', <String, Object?>{'room_version': '10', 'creator': _me}, sender: _me);
      final hs = await _hsWith(states);
      final g = await _loggedIn(hs, dir);
      expect(g.family!.myRole, Role.moderator, reason: 'Voraussetzung: nur die fehlenden Power-Levels verhindern den Lauf');
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, isEmpty);
      expect(hs.levelPuts, isEmpty);
    });

    test('ohne gespeicherte Power-Levels: nichts (canChangeStateEvent wäre für jeden wahr)', () async {
      final states = _baseState(me: 50)..removeWhere((e) => (e! as Map)['type'] == 'm.room.power_levels');
      final hs = await _hsWith(states);
      final g = await _loggedIn(hs, dir);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, isEmpty);
      expect(hs.levelPuts, isEmpty);
    });

    test('Freigabe lokal schon da: nichts; Server schon freigegeben: nur Lesen, nichts senden (idempotent)', () async {
      final hs = await _hsWith(_baseState(me: 50, permitted: true));
      final g = await _loggedIn(hs, dir);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, isEmpty);

      final hs2 = await _hsWith(_baseState(me: 50), serverLevels: _levels(me: 50, permitted: true));
      final dir2 = await Directory.systemTemp.createTemp('fn_avatar2');
      addTearDown(() => dir2.delete(recursive: true));
      final g2 = await _loggedIn(hs2, dir2);
      await g2.debugRunAvatarPermission();
      expect(hs2.levelReads, hasLength(1));
      expect(hs2.levelPuts, isEmpty, reason: 'Zwischenspeicher älter als der Server: nichts senden');
    });

    test('M_FORBIDDEN: einmal neu lesen und wiederholen; danach Erfolg', () async {
      final hs = await _hsWith(_baseState(me: 50))..forbidPowerLevelPuts = 1;
      final g = await _loggedIn(hs, dir);
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, hasLength(2));
      expect(hs.levelPuts, hasLength(2));
      expect((hs.serverLevels['events']! as Map)[_type], 0);
    });

    test('M_FORBIDDEN zweimal: keine dritte Schreibung, Pause von 5 Minuten, App läuft weiter', () async {
      var now = DateTime.utc(2026, 11, 4, 12);
      final hs = await _hsWith(_baseState(me: 50))..forbidPowerLevelPuts = 99;
      final g = await _loggedIn(hs, dir, now: () => now);
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(2));
      now = now.add(const Duration(minutes: 4, seconds: 59));
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(2), reason: 'innerhalb der Pause');
      now = now.add(const Duration(seconds: 2));
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(4), reason: 'nach der Pause wird erneut versucht');
    });

    test('anderer Fehler bricht nicht ab: Pause von 5 Minuten, danach neuer Versuch', () async {
      var now = DateTime.utc(2026, 11, 4, 12);
      final hs = await _hsWith(_baseState(me: 50))..failPowerLevelPuts = true;
      final g = await _loggedIn(hs, dir, now: () => now);
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(1), reason: 'bei anderen Fehlern keine Wiederholung');
      now = now.add(const Duration(minutes: 5, seconds: 1));
      hs.failPowerLevelPuts = false;
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(2));
      expect((hs.serverLevels['events']! as Map)[_type], 0);
    });

    test('Pause von 2 Minuten nach Erfolg; nie dauerhaft erledigt: verlorene Freigabe wird ergänzt', () async {
      var now = DateTime.utc(2026, 11, 4, 12);
      final hs = await _hsWith(_baseState(me: 50));
      final g = await _loggedIn(hs, dir, now: () => now);
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(1));
      // Sync-Echo fehlt noch (lokaler Stand ohne Freigabe), innerhalb der Pause: nichts
      now = now.add(const Duration(minutes: 1, seconds: 59));
      await g.debugRunAvatarPermission();
      expect(hs.levelReads, hasLength(1));
      // Ein anderer Moderator schreibt auf veraltetem Stand: die Freigabe geht verloren (Server ohne Eintrag)
      hs.serverLevels = _levels(me: 50);
      now = now.add(const Duration(seconds: 2));
      await g.debugRunAvatarPermission();
      expect(hs.levelPuts, hasLength(2), reason: 'außerhalb der Pause wird die verlorene Freigabe ergänzt');
      expect((hs.serverLevels['events']! as Map)[_type], 0);
    });

    test('höchstens ein Lauf gleichzeitig', () async {
      final hs = await _hsWith(_baseState(me: 50));
      final g = await _loggedIn(hs, dir);
      hs.holdLevelRead = Completer<void>();
      final first = g.debugRunAvatarPermission();
      final second = g.debugRunAvatarPermission();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(hs.levelReads, hasLength(1));
      hs.holdLevelRead!.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(hs.levelPuts, hasLength(1));
    });

    test('Dispose während des Lesens: nach dem await wird nichts mehr gesendet', () async {
      final hs = await _hsWith(_baseState(me: 50));
      final g = await _loggedIn(hs, dir);
      hs.holdLevelRead = Completer<void>();
      final run = g.debugRunAvatarPermission();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await g.close();
      hs.holdLevelRead!.complete();
      await run;
      expect(hs.levelPuts, isEmpty);
    });

    test('automatisch bei jedem Aufbau der Familie (ensureAvatarPermission: true), entkoppelt', () async {
      final hs = await _hsWith(_baseState(me: 50));
      await _loggedIn(hs, dir, ensure: true);
      await _until(() => hs.levelPuts.isNotEmpty, what: 'automatische Freischaltung');
      expect((hs.levelPuts.single.body['events']! as Map)[_type], 0);
    });

    test('ensureAvatarPermission: false: kein automatischer Lauf', () async {
      final hs = await _hsWith(_baseState(me: 50));
      await _loggedIn(hs, dir);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(hs.levelReads, isEmpty);
      expect(hs.levelPuts, isEmpty);
    });
  });
}
