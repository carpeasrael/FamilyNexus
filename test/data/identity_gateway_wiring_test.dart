import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/matrix/local_identity_pins.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/family.dart' show IdentityStatus;
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' show CrossSigningKey, DeviceKeysList, SyncUpdate;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';
import '../support/sync_requests.dart';

/// #440: Verdrahtung der Identitätsvermerke im Gateway (`_identityOf`, `_persistPins`, `acceptIdentityChange`) gegen
/// einen nachgestellten Homeserver. Die Hauptschlüssel der Mitglieder setzt der Test im SDK-Client; ohne `local:` im
/// Spiegel der Kontodaten ersetzte ein veralteter Kontodaten-Vermerk den lokalen (Mutationsprobe, siehe unten).
const String _me = '@n1:hs.example';
const String _ben = '@ben:hs.example';
const String _cara = '@cara:hs.example';
const String _fam = '!familie:hs.example';
const String _pinsType = SdkMatrixGateway.pinsAccountData;
const String _keyOld = 'KEYOLD0000000000000000000000000000000000000';
const String _keyNew = 'KEYNEW0000000000000000000000000000000000000';
const String _keyCara = 'KEYCARA000000000000000000000000000000000000';

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

List<Object?> _roomState({String benName = 'Ben'}) => <Object?>[
      _state('m.room.create', '', <String, Object?>{'room_version': '10', 'creator': _ben}, sender: _ben),
      _state('m.room.encryption', '', <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
      _member(_me, 'Ich'),
      _member(_ben, benName),
      _member(_cara, 'Cara'),
    ];

/// Erster Sync: Familienraum, Familien-Kontodaten und (optional) die Identitätsvermerke des Kontos.
Map<String, Object?> _firstSync(Map<String, String>? accountPins) => <String, Object?>{
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _fam: <String, Object?>{
            'state': <String, Object?>{'events': _roomState()},
            'timeline': <String, Object?>{'events': <Object?>[], 'limited': false},
          },
        },
      },
      'account_data': <String, Object?>{
        'events': <Object?>[
          <String, Object?>{'type': SdkMatrixGateway.familyAccountData, 'content': <String, Object?>{'room_id': _fam}},
          if (accountPins != null) <String, Object?>{'type': _pinsType, 'content': accountPins},
        ],
      },
    };

typedef _Put = ({String path, Map<String, Object?> body});

class _Hs {
  _Hs(this.firstSync);

  final Map<String, Object?> firstSync;
  final Completer<void> _hold = Completer<void>();
  int syncs = 0;
  final List<_Put> pinPuts = <_Put>[];

  /// Schreiben der Kontodaten scheitert (Schreibfehler von `setAccountData`).
  bool failPinPuts = false;

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
          if (isRejectionPoll(req.url)) return _json(<String, Object?>{'next_batch': 'p'});
          final n = syncs++;
          if (n == 0) return _json(<String, Object?>{'next_batch': 's1', ...firstSync});
          await _hold.future;
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'GET' && path.endsWith('/members')) {
          return _json(<String, Object?>{
            'chunk': <Object?>[_member(_me, 'Ich'), _member(_ben, 'Ben'), _member(_cara, 'Cara')],
          });
        }
        if (req.method == 'PUT' && path.contains('/account_data/$_pinsType')) {
          final raw = await utf8.decodeStream(body);
          pinPuts.add((path: path, body: (json.decode(raw) as Map).cast<String, Object?>()));
          if (failPinPuts) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'kaputt'}, 500);
          return _json(<String, Object?>{});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

String _localEntry(Map<String, String> pins) => json.encode(<String, Object?>{'user_id': _me, 'pins': pins});

Future<void> _until(bool Function() cond, {String? what}) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Bedingung nicht erreicht${what == null ? '' : ': $what'}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Setup {
  _Setup(this.hs, this.g, this.kv);
  final _Hs hs;
  final SdkMatrixGateway g;
  final MemoryKeyValueStore kv;

  IdentityStatus? status(String uid) => g.family?.members.where((m) => m.userId == uid).firstOrNull?.identity;

  /// Setzt den Cross-Signing-Hauptschlüssel eines Mitglieds im SDK-Client (ohne `/keys/query`).
  void master(String uid, String pub) {
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

  /// Löst einen Abgleich der Familie aus (neuer Anzeigename eines Mitglieds) und wartet darauf.
  Future<void> refresh(String benName) async {
    await g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{
      'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}',
      'rooms': <String, Object?>{
        'join': <String, Object?>{
          _fam: <String, Object?>{
            'timeline': <String, Object?>{'events': <Object?>[], 'limited': false},
            'state': <String, Object?>{'events': <Object?>[_member(_ben, benName)]},
          },
        },
      },
    }));
    await _until(() => g.family!.members.any((m) => m.userId == _ben && m.displayName == benName), what: 'Abgleich $benName');
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_identity');
    addTearDown(() => dir.delete(recursive: true));
    AppLog.captured.clear();
    AppLog.capture = true;
    addTearDown(() => AppLog.capture = false);
  });

  /// [localPins]: lokale Kopie dieses Geräts; [accountPins]: Kontodaten des Servers (`null` = nicht vorhanden).
  Future<_Setup> start({Map<String, String>? localPins, Map<String, String>? accountPins}) async {
    final kv = MemoryKeyValueStore();
    if (localPins != null) kv.data[LocalIdentityPins.storeKey] = _localEntry(localPins);
    final hs = _Hs(_firstSync(accountPins));
    final g = SdkMatrixGateway(
      keyStore: MemoryKeyStore(),
      dbDirectory: dir.path,
      probe: ServerProbe(client: hs.client),
      databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
      httpClient: hs.client,
      accountStore: kv,
      ensureAvatarPermission: false,
    );
    addTearDown(() async {
      hs.release();
      await g.close();
    });
    await g.restore();
    await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    await _until(() => g.family != null && g.initialSyncDone, what: 'Familie aufgebaut');
    return _Setup(hs, g, kv);
  }

  group('_identityOf', () {
    test('ohne Hauptschlüssel: unbekannt; mit Schlüssel beim ersten Kontakt: vermerkt', () async {
      final s = await start();
      expect(s.status(_ben), IdentityStatus.unknown);
      s.master(_ben, _keyOld);
      await s.refresh('Ben 1');
      expect(s.status(_ben), IdentityStatus.pinned);
    });

    test('lokaler Vermerk gilt vor den Kontodaten: anderer Schlüssel = geändert, auch wenn die Kontodaten ihn nennen', () async {
      final s = await start(localPins: <String, String>{_ben: _keyOld}, accountPins: <String, String>{_ben: _keyNew});
      s.master(_ben, _keyNew);
      await s.refresh('Ben 1');
      expect(s.status(_ben), IdentityStatus.changed, reason: 'der Server darf den lokalen Vermerk nicht überstimmen');
      expect(AppLog.captured.where((l) => l.contains('weicht vom lokalen Stand ab')), hasLength(1));
      await s.refresh('Ben 2');
      expect(AppLog.captured.where((l) => l.contains('weicht vom lokalen Stand ab')), hasLength(1), reason: 'einmal je Mitglied');
    });

    test('Server löscht den Kontodaten-Vermerk: der lokale hält, unveränderter Schlüssel bleibt vermerkt', () async {
      final s = await start(localPins: <String, String>{_ben: _keyOld}, accountPins: const <String, String>{});
      s.master(_ben, _keyOld);
      await s.refresh('Ben 1');
      expect(s.status(_ben), IdentityStatus.pinned);
      s.master(_ben, _keyNew);
      await s.refresh('Ben 2');
      expect(s.status(_ben), IdentityStatus.changed, reason: 'ohne Kontodaten-Vermerk fiele der Wechsel nicht auf');
    });
  });

  group('_persistPins (erster Kontakt schreibt die Kontodaten)', () {
    test('der Spiegel enthält den neuen Vermerk und die lokalen Vermerke (local:)', () async {
      // Cara ist nur lokal vermerkt (Kontodaten kennen sie nicht); Ben wird neu gesehen.
      final s = await start(localPins: <String, String>{_cara: _keyCara}, accountPins: const <String, String>{});
      s.master(_ben, _keyOld);
      await s.refresh('Ben 1');
      await _until(() => s.hs.pinPuts.isNotEmpty, what: 'Kontodaten geschrieben');
      expect(s.hs.pinPuts.last.body, <String, Object?>{_ben: _keyOld, _cara: _keyCara},
          reason: 'ohne local: ginge der lokale Vermerk der Kontodaten-Kopie verloren');
    });

    test('K3b-2b: der Spiegel enthält nur Pins aktueller Mitglieder; Kontakt-Pins bleiben lokal, Einträge ehemaliger Mitglieder bleiben über die Kontodaten', () async {
      const fremd = '@fremd:hs.example';
      const ehemalig = '@ehemalig:hs.example';
      final s = await start(
        localPins: <String, String>{fremd: _keyOld, ehemalig: _keyCara, _cara: _keyCara},
        accountPins: <String, String>{ehemalig: _keyCara},
      );
      s.master(_ben, _keyOld);
      await s.refresh('Ben 1');
      await _until(() => s.hs.pinPuts.isNotEmpty, what: 'Kontodaten geschrieben');
      expect(s.hs.pinPuts.last.body, <String, Object?>{_ben: _keyOld, _cara: _keyCara, ehemalig: _keyCara},
          reason: 'Kontakt-Pin (fremd) nie in den Kontodaten; ehemaliges Mitglied bleibt über die Kontodaten');
      expect(s.g.localIdentityPins[fremd], _keyOld, reason: 'lokal bleibt er');
    });

    test('Schreibfehler: protokolliert, ohne Ausnahme; der Vermerk geht beim nächsten Schreiben mit hinaus', () async {
      final s = await start(accountPins: const <String, String>{});
      s.hs.failPinPuts = true;
      s.master(_ben, _keyOld);
      await s.refresh('Ben 1');
      await _until(() => s.hs.pinPuts.isNotEmpty, what: 'Schreibversuch');
      await _until(() => AppLog.captured.any((l) => l.contains('Identitätsvermerke nicht gespeichert')), what: 'Protokoll');
      expect(s.status(_ben), IdentityStatus.pinned);
      // Der nächste erste Kontakt (Cara) schreibt erneut; Bens vorgemerkter Vermerk ist dabei.
      s.hs.failPinPuts = false;
      s.master(_cara, _keyCara);
      await s.refresh('Ben 2');
      await _until(() => s.hs.pinPuts.length >= 2, what: 'zweiter Versuch');
      expect(s.hs.pinPuts.last.body, <String, Object?>{_ben: _keyOld, _cara: _keyCara});
    });
  });

  group('acceptIdentityChange', () {
    Future<_Setup> changed() async {
      final s = await start(localPins: <String, String>{_ben: _keyOld, _cara: _keyCara}, accountPins: <String, String>{_ben: _keyOld});
      s.master(_ben, _keyNew);
      await s.refresh('Ben 1');
      expect(s.status(_ben), IdentityStatus.changed);
      return s;
    }

    test('schreibt neuen Schlüssel samt lokalen Vermerken (local:), übernimmt ihn lokal und hebt „geändert“ auf', () async {
      final s = await changed();
      await s.g.acceptIdentityChange(_ben);
      expect(s.hs.pinPuts, hasLength(1));
      expect(s.hs.pinPuts.single.body, <String, Object?>{_ben: _keyNew, _cara: _keyCara},
          reason: 'ohne local: fehlte Cara in den Kontodaten, obwohl sie nur lokal vermerkt ist');
      expect(s.g.localIdentityPins[_ben], _keyNew);
      await _until(() => s.kv.data[LocalIdentityPins.storeKey]!.contains(_keyNew), what: 'lokal gespeichert');
      await s.refresh('Ben 2');
      expect(s.status(_ben), IdentityStatus.pinned);
    });

    test('Schreibfehler der Kontodaten: Ausnahme, lokaler Vermerk und „geändert“ bleiben', () async {
      final s = await changed();
      s.hs.failPinPuts = true;
      await expectLater(s.g.acceptIdentityChange(_ben), throwsA(isA<GatewayException>()));
      expect(s.hs.pinPuts, hasLength(1));
      expect(s.g.localIdentityPins[_ben], _keyOld, reason: 'accept erst nach erfolgreichem Schreiben');
      expect(s.kv.data[LocalIdentityPins.storeKey]!.contains(_keyNew), isFalse);
      await s.refresh('Ben 2');
      expect(s.status(_ben), IdentityStatus.changed);
    });

    test('ohne erkannte Änderung: nicht gefunden, nichts geschrieben', () async {
      final s = await start(localPins: <String, String>{_ben: _keyOld}, accountPins: <String, String>{_ben: _keyOld});
      s.master(_ben, _keyOld);
      await s.refresh('Ben 1');
      await expectLater(
        s.g.acceptIdentityChange(_ben),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notFound)),
      );
      expect(s.hs.pinPuts, isEmpty);
    });
  });
}
