// Buch-Sync des SdkMatrixGateway (Kassenbuch, #311, E-113, Teil 2c) gegen einen nachgestellten Homeserver: Mitglieder
// frisch vom Server, Sendeschutz beim Senden, Signale je Buch, Abbau. Läuft ohne vodozemac (Naht `requireEncryptionForBooks`).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/book_room.dart';
import 'package:family_nexus/domain/book_signal.dart';
import 'package:family_nexus/domain/calendar_signal.dart' show CalendarSignal, ContactSignal, PrivateEventSignal;
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/chat.dart' show ChatThread, GroupSendLock, ThreadKind;
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/conversation_policy.dart' show PeerMembership;
import 'package:family_nexus/domain/data_inventory.dart' show InventoryRoomKind;
import 'package:family_nexus/domain/family.dart' show IdentityStatus;
import 'package:family_nexus/domain/moderation.dart' show ReportCategory, ReportRequest;
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/encryption.dart' show Encryption, KeyVerification, KeyVerificationState;
import 'package:matrix/matrix.dart' show CrossSigningKey, DeviceKeys, DeviceKeysList, Event, SyncStatus, SyncStatusUpdate, SyncUpdate;
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

  /// Hält die erste Antwort auf `/sync`, bis die Zukunft endet (Zustand „vor der ersten Serverantwort“, K3c-1).
  Completer<void>? holdFirst;
  int _syncs = 0;
  void Function(String room)? onJoin;

  /// Antworten auf `GET /profile/{id}` (Status, Körper); ohne Eintrag `M_NOT_FOUND`.
  final Map<String, (int, Map<String, Object?>)> profiles = <String, (int, Map<String, Object?>)>{};

  /// `POST …/leave` schlägt mit 403 fehl (nicht 500/M_UNKNOWN: das SDK löscht den Raum dann lokal) (Wiederholbarkeit von `leaveConversation`).
  bool failLeave = false;

  /// Hält `createRoom`, bis die Zukunft endet (Wettlauf beim Anlegen).
  Completer<void>? holdCreate;

  /// Hält `POST …/join`, bis die Zukunft endet (gleichzeitige Beitritte, K4-2a).
  Completer<void>? holdJoin;

  /// Nach `createRoom`: liefert den Sync mit dem angelegten Raum (sonst wartet das SDK darauf).
  void Function(String room)? onCreate;

  /// Hält die Antworten auf `GET /profile/{id}`, bis die Zukunft endet (gleichzeitige Abfragen).
  Completer<void>? holdProfile;
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
          if (_syncs == 0) await holdFirst?.future;
          if (_syncs++ > 0) await release.future;
          return _json(<String, Object?>{'next_batch': 's$_syncs'});
        }
        if (failLeave && path.endsWith('/leave')) return _json(<String, Object?>{'errcode': 'M_FORBIDDEN', 'error': 'x'}, 403);
        if (path == '/_matrix/client/v3/createRoom') {
          await holdCreate?.future;
          onCreate?.call(createdRoom);
          return _json(<String, Object?>{'room_id': createdRoom});
        }
        if (path.startsWith('/_matrix/client/v3/profile/')) {
          await holdProfile?.future;
          final user = path.substring('/_matrix/client/v3/profile/'.length);
          final p = profiles[user];
          if (p == null) return _json(<String, Object?>{'errcode': 'M_NOT_FOUND', 'error': 'Profil nicht gefunden'}, 404);
          return _json(p.$2, p.$1);
        }
        final join = RegExp(r'/rooms/([^/]+)/join$').firstMatch(path);
        if (join != null) {
          await holdJoin?.future;
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
  bool? encryption,
  bool defaultEncryption = false,
  Duration row2Delay = const Duration(seconds: 60),
  bool holdFirstSync = false,
}) async {
  final hs = _Hs()..familyMembersFail = familyMembersFail;
  if (holdFirstSync) hs.holdFirst = Completer<void>();
  final dir = await Directory.systemTemp.createTemp('fn_bookgw');
  _lastDir = dir;
  final keys = _lastKeys = MemoryKeyStore();
  addTearDown(() => dir.delete(recursive: true));
  SdkMatrixGateway make({bool? flag}) => defaultEncryption
      ? SdkMatrixGateway(
          // Ohne `encryptionAvailable`: der Standard der Produktion (`client.encryptionEnabled`).
          keyStore: keys,
          dbDirectory: dir.path,
          probe: ServerProbe(client: hs.client),
          databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
          httpClient: hs.client,
          joinOpTimeout: const Duration(milliseconds: 800),
          joinPollInterval: const Duration(hours: 1),
          cashBooksEnabled: true,
          requireEncryptionForBooks: requireEncryption,
          contactRow2Delay: row2Delay,
        )
      : flag == null
      ? SdkMatrixGateway(
          keyStore: keys,
          dbDirectory: dir.path,
          probe: ServerProbe(client: hs.client),
          databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
          httpClient: hs.client,
          joinOpTimeout: const Duration(milliseconds: 800),
          joinPollInterval: const Duration(hours: 1),
          requireEncryptionForBooks: requireEncryption,
          encryptionAvailable: encryption,
          contactRow2Delay: row2Delay,
        )
      : SdkMatrixGateway(
          keyStore: keys,
          dbDirectory: dir.path,
          probe: ServerProbe(client: hs.client),
          databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
          httpClient: hs.client,
          joinOpTimeout: const Duration(milliseconds: 800),
          joinPollInterval: const Duration(hours: 1),
          cashBooksEnabled: flag,
          requireEncryptionForBooks: requireEncryption,
          encryptionAvailable: encryption,
          contactRow2Delay: row2Delay,
        );
  final g = make(flag: enabled);
  addTearDown(() async {
    if (!hs.release.isCompleted) hs.release.complete();
    if (hs.holdFirst != null && !hs.holdFirst!.isCompleted) hs.holdFirst!.complete();
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

/// Verzeichnis der Datenbank des zuletzt angelegten Gateways (für den Neustart auf demselben Stand).
Directory? _lastDir;
MemoryKeyStore? _lastKeys;

/// Neustart auf demselben Datenbankstand (kein Login): die Sitzung wird wiederhergestellt, `_syncedOnce` gilt durch den
/// gespeicherten Stand, bevor der Server geantwortet hat. [hs] ist der Server des Neustarts (frisch: erste Antwort sofort,
/// mit `holdFirst`: erst auf Freigabe).
Future<SdkMatrixGateway> _restarted(_Hs hs, Directory dir, {Duration row2Delay = const Duration(seconds: 60)}) async {
  final g = SdkMatrixGateway(
    keyStore: _lastKeys!,
    dbDirectory: dir.path,
    probe: ServerProbe(client: hs.client),
    databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
    httpClient: hs.client,
    joinOpTimeout: const Duration(milliseconds: 800),
    joinPollInterval: const Duration(hours: 1),
    requireEncryptionForBooks: false,
    encryptionAvailable: true,
    contactRow2Delay: row2Delay,
  );
  addTearDown(() async {
    if (!hs.release.isCompleted) hs.release.complete();
    if (hs.holdFirst != null && !hs.holdFirst!.isCompleted) hs.holdFirst!.complete();
    await g.close();
  });
  await g.restore();
  return g;
}

Future<void> _sync(SdkMatrixGateway g, Map<String, Object?> update) =>
    g.sdkClient!.handleSync(SyncUpdate.fromJson(<String, Object?>{'next_batch': 'x${DateTime.now().microsecondsSinceEpoch}', ...update}));

Future<void> _syncJoined(SdkMatrixGateway g, Map<String, Object?> update) async {
  await _sync(g, update);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  g.sdkClient!.onSyncStatus.add(const SyncStatusUpdate(SyncStatus.finished));
}

Future<ChatThread?> contactThreadFor(SdkMatrixGateway g, String room, Map<String, Object?> update) async {
  await _sync(g, update);
  await Future<void>.delayed(_settle);
  return g.threads.where((t) => t.id == room && t.kind == ThreadKind.contact).firstOrNull;
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

  // ---- #119, K2a: Einzelchat-Einstufung im echten Gateway (Verhaltensgleichheit der Überführung in `ConversationPolicy`) ----

  /// Beigetretener Raum mit Gegenüber [peer] (m.direct), Megolm, Zählern und Mitgliedern.
  Map<String, Object?> dmJoined(
    String room,
    String peer, {
    bool direct = true,
    bool megolm = true,
    int joined = 2,
    int invited = 0,
    int? summaryJoined,
    List<String>? members,
    String peerState = 'join',
  }) =>
      <String, Object?>{
        if (direct)
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{peer: <String>[room]}},
            ],
          },
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            room: <String, Object?>{
              'summary': <String, Object?>{'m.joined_member_count': summaryJoined ?? joined, 'm.invited_member_count': invited},
              'state': <String, Object?>{
                'events': <Object?>[
                  _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
                  if (megolm) _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
                  for (final m in members ?? <String>[_me, peer]) _memberEvent(m, m == peer ? peerState : 'join'),
                ],
              },
            },
          },
        },
      };

  /// Einladung in einen Raum; [direct] setzt `is_direct` im eigenen Mitgliedsereignis, [from] ist der Einladende.
  Map<String, Object?> dmInvite(String room, String from, {bool direct = true}) => <String, Object?>{
        'rooms': <String, Object?>{
          'invite': <String, Object?>{
            room: <String, Object?>{
              'invite_state': <String, Object?>{
                'events': <Object?>[
                  <String, Object?>{
                    'type': 'm.room.member',
                    'state_key': _me,
                    'sender': from,
                    'content': <String, Object?>{'membership': 'invite', if (direct) 'is_direct': true},
                  },
                ],
              },
            },
          },
        },
      };

  group('Kontakt-Einzelchats (#119, K3a-2a)', () {
    const ct = '!ct:hs.example';
    const policy = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted});

    Future<ChatThread?> contactThread(SdkMatrixGateway g, Map<String, Object?> update) async {
      await _sync(g, update);
      await Future<void>.delayed(_settle);
      return g.threads.where((t) => t.id == ct && t.kind == ThreadKind.contact).firstOrNull;
    }

    Future<SdkMatrixGateway> signedIn([ContactPolicy p = policy]) async {
      final (_, g) = await _signedIn(encryption: true);
      g.setContactPolicy(p);
      return g;
    }

    test('Kontrollfall: Kontakt mit Datensatz, beigetreten, Megolm, zwei Personen ⇒ Kontakt-Thread mit Titel „Name · server“', () async {
      final g = await signedIn();
      final t = await contactThread(g, dmJoined(ct, _fremd));
      expect(t, isNotNull);
      expect(t!.peerId, _fremd);
      expect(t.pending, isFalse);
      expect(t.isOutside, isTrue);
      expect(t.title, '$_fremd · hs.example');
    });

    test('Gegenproben je einzeln: kein Thread', () async {
      final cases = <String, (ContactPolicy, Map<String, Object?>)>{
        'ohne Datensatz': (const ContactPolicy(enabled: true), dmJoined(ct, _fremd)),
        'Bereich aus': (ContactPolicy.off, dmJoined(ct, _fremd)),
        'blockiert (Datensatz)': (const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}), dmJoined(ct, _fremd)),
        'lokal blockiert': (const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.accepted}, blocked: {_fremd}), dmJoined(ct, _fremd)),
        'ohne Megolm': (policy, dmJoined(ct, _fremd, megolm: false)),
        'drei Personen': (policy, dmJoined(ct, _fremd, joined: 3, members: <String>[_me, _fremd, _cara])),
        'Gegenüber hat den Raum verlassen': (policy, dmJoined(ct, _fremd, peerState: 'leave', joined: 1)),
        'Gegenüber abgelehnt/verbannt': (policy, dmJoined(ct, _fremd, peerState: 'ban', joined: 1)),
      };
      for (final e in cases.entries) {
        final g = await signedIn(e.value.$1);
        expect(await contactThread(g, e.value.$2), isNull, reason: e.key);
      }
    });

    test('Familienmitglied mit Kontaktdatensatz bleibt ein Einzelchat mit Mitglied, nie ein Kontakt-Thread', () async {
      final g = await signedIn(const ContactPolicy(enabled: true, contacts: {_ben: ContactState.accepted}));
      await _sync(g, dmJoined(ct, _ben));
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.id == ct).map((t) => t.kind), <ThreadKind>[ThreadKind.direct]);
    });

    test('Mitgliedszustand des Gegenübers fehlt: kein Thread, bis die Test-Naht ihn liefert; ein Fehler bleibt unbekannt', () async {
      final g = await signedIn();
      var calls = 0;
      g.debugPeerMembershipLoader = (room, peer) async {
        calls++;
        throw StateError('Netz');
      };
      expect(await contactThread(g, dmJoined(ct, _fremd, members: <String>[_me])), isNull, reason: 'unbekannt ⇒ ignoriert');
      expect(calls, 1);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty);
      // Später liefert die Anforderung `join`: der nächste Abgleich zeigt den Thread (Wartezeit je Raum umgehen).
      g.debugPeerMembershipLoader = (room, peer) async => PeerMembership.join;
      final g2 = await signedIn();
      g2.debugPeerMembershipLoader = (room, peer) async => PeerMembership.join;
      await _sync(g2, dmJoined(ct, _fremd, members: <String>[_me]));
      await Future<void>.delayed(_settle);
      await _sync(g2, <String, Object?>{});
      await Future<void>.delayed(_settle);
      expect(g2.threads.where((t) => t.id == ct && t.kind == ThreadKind.contact), hasLength(1));
    });

    test('Gegenüber nur eingeladen und outgoing: Thread wartet (pending); Senden verweigert', () async {
      final g = await signedIn(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      final t = await contactThread(g, dmJoined(ct, _fremd, peerState: 'invite', joined: 1, invited: 1));
      expect(t, isNotNull);
      expect(t!.pending, isTrue);
      await g.openThread(ct);
      await expectLater(g.sendMessage('Hallo', threadId: ct), _notAllowed());
    });

    test('Senden vor openThread und Reaktionen im Kontaktraum sind verweigert; nach openThread liest messagesIn', () async {
      final g = await signedIn();
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      await expectLater(g.sendMessage('Hallo', threadId: ct), _notAllowed());
      await expectLater(g.sendReaction('\$e', '👍', threadId: ct), _notAllowed());
      expect(g.messagesIn(ct), isEmpty);
      await g.openThread(ct);
      await g.openThread(ct); // idempotent
      expect(g.messagesIn(ct), isEmpty);
    });

    test('K3b-2a: isThreadOpen (erst nach openThread) und peerName (bereinigter Anzeigename)', () async {
      final g = await signedIn();
      final t = await contactThread(g, dmJoined(ct, _fremd));
      expect(t!.peerName, _fremd, reason: 'Anzeigename des Gegenübers, bereinigt, ohne Server');
      expect(g.isThreadOpen(ct), isFalse);
      await g.openThread(ct);
      expect(g.isThreadOpen(ct), isTrue);
      expect(g.isThreadOpen(ChatThread.familyId), isTrue);
    });

    test('K3b-2a: wartender Kontakt-Raum bekommt nie eine Zeitleiste (isThreadOpen bleibt false)', () async {
      final g = await signedIn(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      final t = await contactThread(g, dmJoined(ct, _fremd, peerState: 'invite', joined: 1, invited: 1));
      expect(t?.pending, isTrue);
      await g.openThread(ct);
      expect(g.isThreadOpen(ct), isFalse);
    });

    test('Richtlinie aus oder Blockieren mitten in der Sitzung: der Thread verschwindet ohne weiteren Sync', () async {
      final g = await signedIn();
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}));
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty);
      g.setContactPolicy(policy);
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), hasLength(1));
      g.setContactPolicy(ContactPolicy.off);
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty);
    });

    test('Familienwechsel: ohne geladene Mitgliederliste keine Kontakt-Threads, danach wieder; die Richtlinie bleibt', () async {
      final g = await signedIn();
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      g.debugLeaveFamilyScope();
      expect(g.debugContactPolicy, policy);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty, reason: '_resetFamilyChats und _resetContacts(full: false) räumen die Kontakt-Räume (failed und creating bleiben, Test 6 b)');
      expect(g.contactRequests, isEmpty);
    });

    test('Anfrage: Einladung is_direct von Fremden ohne Datensatz; kein Rauminhalt, keine Zeitleiste; Ablehnen verlässt sie', () async {
      final g = await signedIn(const ContactPolicy(enabled: true));
      await _sync(g, dmInvite('!rq:hs.example', _fremd));
      await Future<void>.delayed(_settle);
      expect(g.contactRequests.map((r) => r.roomId), <String>['!rq:hs.example']);
      expect(g.contactRequests.single.fromUserId, _fremd);
      expect(g.contactRequests.single.fromName, 'fremd · hs.example', reason: 'ohne Anzeigename der lokale Teil, Server aus der ID');
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty);
      await g.declineContactRequest('!rq:hs.example');
      await expectLater(g.declineContactRequest('!rq:hs.example'), _notAllowed(), reason: 'nur für die Einstufung contactRequest');
    });

    test('keine Anfragen bei Bereich aus; Ablehnen ohne Bereich verweigert', () async {
      final g = await signedIn(ContactPolicy.off);
      await _sync(g, dmInvite('!rq:hs.example', _fremd));
      await Future<void>.delayed(_settle);
      expect(g.contactRequests, isEmpty);
      await expectLater(g.declineContactRequest('!rq:hs.example'), _notAllowed());
    });

    test('Einladung eines Kontakts mit Datensatz wird angenommen (/join), eines Fremden nie', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      await _sync(g, dmInvite('!fr:hs.example', _dora));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isEmpty, reason: 'Fremder ohne Datensatz: nie ohne Tipp');
      await _sync(g, dmInvite('!ok:hs.example', _fremd));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isNotEmpty);
    });

    Map<String, Object?> invites(Map<String, String> fromByRoom) => <String, Object?>{
          'rooms': <String, Object?>{
            'invite': <String, Object?>{
              for (final e in fromByRoom.entries)
                e.key: <String, Object?>{
                  'invite_state': <String, Object?>{
                    'events': <Object?>[
                      <String, Object?>{
                        'type': 'm.room.member',
                        'state_key': _me,
                        'sender': e.value,
                        'content': <String, Object?>{'membership': 'invite', 'is_direct': true},
                      },
                    ],
                  },
                },
            },
          },
        };

    test('Identitätsvertauschung: Gegenüber verlässt, ein Dritter tritt bei (m.direct zeigt weiter auf das Gegenüber) ⇒ kein Thread', () async {
      final g = await signedIn();
      final update = dmJoined(ct, _fremd, members: <String>[_me, _dora], joined: 2);
      // m.direct zeigt auf _fremd, im Raum sind aber ich und _dora; _fremd ist als „leave“ eingetragen.
      (((update['rooms']! as Map)['join']! as Map)[ct]! as Map)['state'] = <String, Object?>{
        'events': <Object?>[
          _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
          _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
          _memberEvent(_me, 'join'),
          _memberEvent(_dora, 'join'),
          _memberEvent(_fremd, 'leave'),
        ],
      };
      expect(await contactThread(g, update), isNull);
    });

    test('gegenseitiges Hinzufügen: der eigene wartende Raum hindert die Annahme nicht (beide Reihenfolgen der Raum-IDs)', () async {
      for (final ids in <(String, String)>[('!a:hs.example', '!z:hs.example'), ('!z:hs.example', '!a:hs.example')]) {
        final (hs, g) = await _signedIn(encryption: true);
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
        final own = dmJoined(ids.$1, _fremd, peerState: 'invite', joined: 1, invited: 1);
        await _sync(g, own);
        await _sync(g, invites(<String, String>{ids.$2: _fremd}));
        await Future<void>.delayed(_settle);
        expect(hs.where('POST', '${ids.$2}/join'), isNotEmpty, reason: 'Einladung der Gegenseite wird angenommen: $ids');
        expect(hs.where('POST', '${ids.$1}/join'), isEmpty);
        expect(hs.where('POST', '/leave'), isEmpty, reason: 'nie destruktiv: der eigene Raum wird nicht verlassen');
      }
    });

    test('ein beigetretener Raum des Einladenden blockiert eine weitere Einladung (nur ein Raum je Gegenüber)', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      await _sync(g, invites(<String, String>{'!zweit:hs.example': _fremd}));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '!zweit:hs.example/join'), isEmpty);
    });

    test('je Einladendem die Einladung mit der kleinsten Raum-ID, auch wenn die größere zuerst im Update steht', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      await _sync(g, invites(<String, String>{'!zzz:hs.example': _fremd, '!bbb:hs.example': _fremd}));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '!bbb:hs.example/join'), isNotEmpty);
      expect(hs.where('POST', '!zzz:hs.example/join'), isEmpty);
    });

    test('600 Fremdeinladungen verdrängen die Annahme eines Kontakts nicht; Anfragen: höchstens 5 je Server', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      await _sync(g, invites(<String, String>{
        for (var i = 0; i < 600; i++) '!s${i.toString().padLeft(4, '0')}:hs.example': '@s${i.toString().padLeft(4, '0')}:hs.example',
        '!kontakt:hs.example': _fremd,
      }));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(hs.where('POST', '!kontakt:hs.example/join'), isNotEmpty);
      expect(hs.where('POST', '/join').where((c) => !c.$2.contains('!kontakt')), isEmpty, reason: 'Fremde nie ohne Tipp');
      expect(g.contactRequests.length, 5, reason: 'je Server höchstens 5');
      expect(g.contactRequestsHidden, greaterThan(0));
    });

    test('Anfragen: insgesamt höchstens 50 bei vielen Servern; Ablehnen gibt den Platz frei (die nächste rückt nach)', () async {
      final g = await signedIn(const ContactPolicy(enabled: true));
      await _sync(g, invites(<String, String>{
        for (var i = 0; i < 60; i++) '!r${i.toString().padLeft(3, '0')}:s$i.example': '@x$i:s$i.example',
      }));
      await Future<void>.delayed(_settle);
      expect(g.contactRequests.length, 50);
      expect(g.contactRequestsHidden, 10);
      final first = g.contactRequests.first.roomId;
      await g.declineContactRequest(first);
      await Future<void>.delayed(_settle);
      expect(g.contactRequests.map((r) => r.roomId), isNot(contains(first)));
      expect(g.contactRequests.length, 50, reason: 'die nächste Anfrage rückt nach');
    });

    test('Anfragen: je Absender eine (kleinste Raum-ID); die Reihenfolge der Erstsichtung bleibt, neue verdrängen nie ältere', () async {
      final g = await signedIn(const ContactPolicy(enabled: true));
      const anna = '@anna2:hs.example';
      const bert = '@bert2:hs.example';
      await _sync(g, invites(<String, String>{'!zz:hs.example': anna, '!aa:hs.example': anna}));
      await Future<void>.delayed(_settle);
      expect(g.contactRequests.map((r) => r.roomId), <String>['!aa:hs.example']);
      await _sync(g, invites(<String, String>{'!b1:hs.example': bert}));
      await Future<void>.delayed(_settle);
      expect(g.contactRequests.map((r) => r.fromUserId), <String>[anna, bert], reason: 'Erstsichtung: Anna zuerst');
    });

    test('Anfrage mit feindlichem Anzeigenamen: bereinigt, Server aus der ID', () async {
      final g = await signedIn(const ContactPolicy(enabled: true));
      final update = invites(<String, String>{'!h:hs.example': '@evil:evil.example'});
      ((((update['rooms']! as Map)['invite']! as Map)['!h:hs.example']! as Map)['invite_state']! as Map<String, Object?>)['events'] = <Object?>[
        <String, Object?>{
          'type': 'm.room.member',
          'state_key': _me,
          'sender': '@evil:evil.example',
          'content': <String, Object?>{'membership': 'invite', 'is_direct': true},
        },
        <String, Object?>{
          'type': 'm.room.member',
          'state_key': '@evil:evil.example',
          'sender': '@evil:evil.example',
          'content': <String, Object?>{'membership': 'join', 'displayname': 'Mama \u202E· familie.de'},
        },
      ];
      await _sync(g, update);
      await Future<void>.delayed(_settle);
      expect(g.contactRequests.single.fromName, 'Mama familie.de · evil.example');
    });

    /// Zwei Räume mit demselben Gegenüber in einem Update (m.direct nennt beide).
    Map<String, Object?> twoRooms(String r1, String r2, {String peerState1 = 'join', int joined1 = 2, int invited1 = 0}) {
      final a = dmJoined(r1, _fremd, peerState: peerState1, joined: joined1, invited: invited1);
      final b = dmJoined(r2, _fremd);
      (((a['account_data']! as Map)['events']! as List).first as Map)['content'] = <String, Object?>{_fremd: <String>[r1, r2]};
      ((a['rooms']! as Map)['join']! as Map).addAll(((b['rooms']! as Map)['join']! as Map).cast<String, Object?>());
      return a;
    }

    test('Auswahl je Gegenüber: ein beigetretenes Gegenüber geht einem wartenden vor, auch mit größerer Raum-ID', () async {
      // Der wartende Raum (peerState invite) ist jeweils der erste Raum im Update; beide Zuordnungen der Raum-IDs.
      for (final (waiting, joined) in <(String, String)>[('!a:hs.example', '!z:hs.example'), ('!z:hs.example', '!a:hs.example')]) {
        final g = await signedIn(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
        await _sync(g, twoRooms(waiting, joined, peerState1: 'invite', joined1: 1, invited1: 1));
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.contact).map((t) => t.id), <String>[joined], reason: 'wartend $waiting, beigetreten $joined');
      }
      // Umgekehrte Reihenfolge im Update: der beigetretene Raum steht zuerst.
      for (final (waiting, joined) in <(String, String)>[('!a:hs.example', '!z:hs.example'), ('!z:hs.example', '!a:hs.example')]) {
        final g = await signedIn(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
        final u = twoRooms(joined, waiting);
        // Im zweiten Raum (waiting) ist das Gegenüber nur eingeladen.
        final w = dmJoined(waiting, _fremd, peerState: 'invite', joined: 1, invited: 1);
        (((u['rooms']! as Map)['join']! as Map))[waiting] = ((w['rooms']! as Map)['join']! as Map)[waiting];
        await _sync(g, u);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.contact).map((t) => t.id), <String>[joined], reason: 'beigetreten zuerst: $joined, wartend $waiting');
      }
    });

    test('Auswahl je Gegenüber: unter mehreren beigetretenen Räumen die kleinste Raum-ID', () async {
      final g = await signedIn();
      await _sync(g, twoRooms('!z:hs.example', '!a:hs.example'));
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact).map((t) => t.id), <String>['!a:hs.example']);
    });

    test('Auto-Annahme prüft vor dem /join: Blockierte und Eingeladene der Familie werden nie angenommen', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(const ContactPolicy(
        enabled: true,
        contacts: {_fremd: ContactState.accepted, _dora: ContactState.accepted},
        blocked: {_fremd},
      ));
      await _sync(g, invites(<String, String>{'!bl:hs.example': _fremd, '!fam:hs.example': _dora}));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isEmpty, reason: 'blockiert und Familienmitglied (eingeladen): nie ein /join');
    });

    test('der eigene wartende Raum blockiert die Annahme nicht: erst der Thread (pending), dann die Einladung der Gegenseite', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      expect(await contactThread(g, dmJoined('!own:hs.example', _fremd, peerState: 'invite', joined: 1, invited: 1)), isNull);
      await _sync(g, dmJoined('!own:hs.example', _fremd, peerState: 'invite', joined: 1, invited: 1));
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact && t.pending), hasLength(1), reason: 'Voraussetzung: der wartende Thread steht');
      await _sync(g, invites(<String, String>{'!gegen:hs.example': _fremd}));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '!gegen:hs.example/join'), isNotEmpty);
    });

    test('Anfragen: je Absender die kleinste Raum-ID, unabhängig von der Reihenfolge im Update', () async {
      for (final order in <List<String>>[<String>['!aa:hs.example', '!zz:hs.example'], <String>['!zz:hs.example', '!aa:hs.example']]) {
        final g = await signedIn(const ContactPolicy(enabled: true));
        await _sync(g, invites(<String, String>{for (final r in order) r: '@anna3:hs.example'}));
        await Future<void>.delayed(_settle);
        expect(g.contactRequests.map((r) => r.roomId), <String>['!aa:hs.example'], reason: '$order');
      }
    });

    test('Anfragen: ausgewertet werden höchstens 500 Einladungen (600 Server ⇒ 50 angezeigt, 450 weitere)', () async {
      final g = await signedIn(const ContactPolicy(enabled: true));
      await _sync(g, invites(<String, String>{
        for (var i = 0; i < 600; i++) '!q${i.toString().padLeft(4, '0')}:hs.example': '@u$i:srv$i.example',
      }));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(g.contactRequests.length, 50);
      expect(g.contactRequestsHidden, 450);
    });

    test('familyUnreadCount absolut: Kontakte zählen nie hinein, unreadCount zählt sie', () async {
      final g = await signedIn();
      final update = dmJoined(ct, _fremd);
      ((update['rooms']! as Map)['join']! as Map)[ct] = <String, Object?>{
        ...((update['rooms']! as Map)['join']! as Map)[ct]! as Map<String, Object?>,
        'unread_notifications': <String, Object?>{'notification_count': 3},
      };
      expect(await contactThread(g, update), isNotNull);
      expect(g.familyUnreadCount, 0);
      expect(g.unreadCount, 3);
    });

    test('leaveConversation verlässt nie einen beigetretenen Raum, der kein Kontakt-Thread ist', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      await _sync(g, dmJoined('!plain:hs.example', _dora, direct: false));
      await Future<void>.delayed(_settle);
      await expectLater(g.leaveConversation('!plain:hs.example'), _notAllowed());
      expect(hs.where('POST', '!plain:hs.example/leave'), isEmpty);
    });

    test('Blockieren nach openThread, vor dem nächsten Abgleich: Senden sofort verweigert (frische Prüfung)', () async {
      final g = await signedIn();
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      await g.openThread(ct);
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}));
      await expectLater(g.sendMessage('Hallo', threadId: ct), _notAllowed());
    });

    test('openThread: Blockieren oder Familienwechsel während des Öffnens ⇒ keine Zeitleiste', () async {
      final g = await signedIn();
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      final open = g.openThread(ct);
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}));
      await open;
      expect(g.debugContactTimelines, isEmpty);
      g.setContactPolicy(policy);
      await Future<void>.delayed(_settle);
      final open2 = g.openThread(ct);
      g.debugLeaveFamilyScope();
      await open2;
      expect(g.debugContactTimelines, isEmpty);
      await g.openThread(ct);
      await g.openThread(ct);
      expect(g.debugContactTimelines.length, lessThanOrEqualTo(1));
    });

    test('Mitgliedszustand des Gegenübers wird je Raum höchstens einmal je Minute angefordert', () async {
      final g = await signedIn();
      var calls = 0;
      g.debugPeerMembershipLoader = (room, peer) async {
        calls++;
        return null;
      };
      await _sync(g, dmJoined(ct, _fremd, members: <String>[_me]));
      await Future<void>.delayed(_settle);
      await _sync(g, <String, Object?>{});
      await Future<void>.delayed(_settle);
      await _sync(g, <String, Object?>{});
      await Future<void>.delayed(_settle);
      expect(calls, 1);
    });

    test('Senden in Mitglieder-Einzelchats läuft über den Mitglieder-Pfad (Vorrang vor dem Kontakt-Pfad)', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      await _sync(g, dmJoined('!mdm:hs.example', _ben));
      await Future<void>.delayed(_settle);
      // Im Harness ohne vodozemac meldet der **Mitglieder-Pfad** `encryptionUnavailable`; der Kontakt-Pfad würde `notAllowed`
      // melden. Das belegt, dass der Mitglieder-Pfad zuerst gilt.
      await expectLater(g.sendMessage('Hallo Ben', threadId: '!mdm:hs.example'), _error(GatewayError.encryptionUnavailable));
      expect(hs.sends, isEmpty);
    });

    group('Nachprüfung nach dem Beitritt (Auto-Annahme)', () {
      const room = '!neu:hs.example';

      /// Der Server beantwortet `/join` und liefert den beigetretenen Raum im nächsten Sync.
      Future<(_Hs, SdkMatrixGateway)> joined(Map<String, Object?> after, {void Function(SdkMatrixGateway g)? during}) async {
        final (hs, g) = await _signedIn(encryption: true);
        g.setContactPolicy(policy);
        hs.onJoin = (r) {
          during?.call(g);
          // Das Echo kommt erst nach der Antwort auf `/join` (sonst verpasst `join(waitForSync: true)` es).
          Future<void>.delayed(const Duration(milliseconds: 150), () => _syncJoined(g, after)).ignore();
        };
        await _sync(g, dmInvite(room, _fremd));
        await Future<void>.delayed(const Duration(seconds: 1));
        return (hs, g);
      }

      test('in Ordnung: Raum bleibt, Thread erscheint, nicht verlassen', () async {
        final (hs, g) = await joined(dmJoined(room, _fremd));
        expect(hs.where('POST', '$room/leave'), isEmpty);
        expect(g.threads.where((t) => t.id == room && t.kind == ThreadKind.contact), hasLength(1));
      });

      test('sicherer Verstoß (kein Megolm): sofort verlassen', () async {
        final (hs, _) = await joined(dmJoined(room, _fremd, megolm: false));
        expect(hs.where('POST', '$room/leave'), isNotEmpty);
      });

      test('sicherer Verstoß (drei Personen): sofort verlassen', () async {
        final (hs, _) = await joined(dmJoined(room, _fremd, joined: 3, members: <String>[_me, _fremd, _cara]));
        expect(hs.where('POST', '$room/leave'), isNotEmpty);
      });

      test('unbekannt (Mitgliedszustand des Gegenübers fehlt): nie verlassen; später geladen ⇒ Thread', () async {
        final (hs, g) = await _signedIn(encryption: true);
        g.setContactPolicy(policy);
        g.debugPeerMembershipLoader = (r, p) async => PeerMembership.join;
        hs.onJoin = (r) => Future<void>.delayed(const Duration(milliseconds: 150), () => _syncJoined(g, dmJoined(room, _fremd, members: <String>[_me]))).ignore();
        await _sync(g, dmInvite(room, _fremd));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(hs.where('POST', '$room/leave'), isEmpty, reason: 'unbekannt ist kein Verstoß');
        await _sync(g, <String, Object?>{});
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.id == room && t.kind == ThreadKind.contact), hasLength(1));
      });

      test('unbekannt (Zähler fehlen): nie verlassen', () async {
        final update = dmJoined(room, _fremd);
        (((update['rooms']! as Map)['join']! as Map)[room]! as Map).remove('summary');
        final (hs, _) = await joined(update);
        expect(hs.where('POST', '$room/leave'), isEmpty, reason: 'ohne Zähler ist die Größe unbekannt, kein Verstoß');
      });

      test('Familienwechsel während des Beitritts (K3c-1): kein Abbruch per Epoche; die Nachprüfung entscheidet, unvollständige Liste ⇒ unbekannt, nie verlassen', () async {
        // Vorher (Familien-Epoche): der Raum wurde verlassen. Jetzt: `_verifyJoined` meldet „unbekannt“, solange die Liste der neuen
        // Familie unvollständig ist (fail-closed, kein Verlassen); mit vollständiger Liste und Nichtmitglied erscheint der Thread.
        final (hs, g) = await joined(dmJoined(room, _fremd), during: (g) => g.debugLeaveFamilyScope());
        expect(hs.where('POST', '$room/leave'), isEmpty, reason: 'unbekannt ist kein Verstoß');
        await _sync(g, <String, Object?>{'account_data': <String, Object?>{'events': <Object?>[<String, Object?>{'type': 'x.k', 'content': <String, Object?>{}}]}});
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.id == room && t.kind == ThreadKind.contact), hasLength(1), reason: 'Liste nachgeladen, Person Nichtmitglied');
      });

      test('Blockieren während des Beitritts: der Raum wird verlassen', () async {
        final (hs, _) = await joined(
          dmJoined(room, _fremd),
          during: (g) => g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd})),
        );
        expect(hs.where('POST', '$room/leave'), isNotEmpty);
      });
    });

    test('leaveConversation: scheitert leave(), bleibt alles unverändert (Thread, m.direct); der zweite Versuch gelingt und bereinigt danach m.direct', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      hs.failLeave = true;
      await expectLater(g.leaveConversation(ct), throwsA(isA<GatewayException>()));
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), hasLength(1), reason: 'unverändert, nicht verschwunden');
      final directBefore = hs.where('PUT', 'account_data/m.direct').length;
      hs.failLeave = false;
      await g.leaveConversation(ct);
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '$ct/leave'), isNotEmpty);
      expect(hs.where('PUT', 'account_data/m.direct').length, greaterThan(directBefore), reason: 'm.direct erst nach dem Verlassen bereinigt');
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty);
    });

    test('leaveConversation verlässt den Raum und räumt den Thread auf', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(policy);
      expect(await contactThread(g, dmJoined(ct, _fremd)), isNotNull);
      await g.openThread(ct);
      await g.leaveConversation(ct);
      expect(hs.where('POST', '$ct/leave'), isNotEmpty);
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.contact), isEmpty);
      expect(g.messagesIn(ct), isEmpty);
    });

    test('leaveConversation nur für Kontakt-Threads: nicht für Familienchat und Einzelchat mit Mitglied', () async {
      final g = await signedIn();
      await _sync(g, dmJoined('!mdm:hs.example', _ben));
      await Future<void>.delayed(_settle);
      await expectLater(g.leaveConversation(ChatThread.familyId), _notAllowed());
      await expectLater(g.leaveConversation('!mdm:hs.example'), _notAllowed());
      await expectLater(g.leaveConversation('!unbekannt:hs.example'), _notAllowed());
    });

    test('Mitglieder-Einzelchats bleiben bei Richtlinie off unverändert (Verhaltensgleichheit)', () async {
      final (_, a) = await _signedIn(encryption: true);
      final (_, b) = await _signedIn(encryption: true);
      b.setContactPolicy(ContactPolicy.off);
      for (final g in <SdkMatrixGateway>[a, b]) {
        await _sync(g, dmJoined('!mdm:hs.example', _ben));
        await Future<void>.delayed(_settle);
      }
      expect(<(String, ThreadKind, String)>[for (final t in b.threads) (t.id, t.kind, t.title)],
          <(String, ThreadKind, String)>[for (final t in a.threads) (t.id, t.kind, t.title)]);
    });

    test('Ungelesenes: Kontakt-Räume zählen in unreadCount, nie in familyUnreadCount', () async {
      final g = await signedIn();
      final update = dmJoined(ct, _fremd);
      ((update['rooms']! as Map)['join']! as Map)[ct] = <String, Object?>{
        ...((update['rooms']! as Map)['join']! as Map)[ct]! as Map<String, Object?>,
        'unread_notifications': <String, Object?>{'notification_count': 3},
      };
      expect(await contactThread(g, update), isNotNull);
      expect(g.unreadIn(ct), 3);
      expect(g.unreadCount, g.familyUnreadCount + 3);
    });
  });

  group('Kontakt hinzufügen (#119, K3a-2b)', () {
    const policyOut = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.outgoing});

    Future<(_Hs, SdkMatrixGateway)> ready([ContactPolicy p = policyOut, bool encryption = true]) async {
      final (hs, g) = await _signedIn(encryption: encryption);
      g.setContactPolicy(p);
      g.debugDevicesOf = (id) => <bool>[true];
      return (hs, g);
    }

    int profileCalls(_Hs hs) => hs.where('GET', '/profile/').length;

    /// Nach dem Anlegen liefert der Server den Raum im Sync (Gegenüber nur eingeladen).
    void armCreate(_Hs hs, SdkMatrixGateway g) => hs.onCreate = (room) => Future<void>.delayed(
          const Duration(milliseconds: 150),
          () => _syncJoined(g, dmJoined(room, _fremd, peerState: 'invite', joined: 1, invited: 1)),
        ).ignore();

    int keyQueriesFor(_Hs hs, String id) => hs.where('POST', '/keys/query').where((c) => c.$3.contains(id)).length;

    group('probeContact', () {
      test('Familienmitglied (jeder Status): ohne Netzabfrage beantwortet', () async {
        final (hs, g) = await ready();
        for (final id in <String>[_ben, _cara, _dora]) {
          final p = await g.probeContact(id);
          expect(p.isFamilyMember, isTrue, reason: id);
        }
        expect(profileCalls(hs), 0);
        for (final id in <String>[_ben, _cara, _dora]) {
          expect(keyQueriesFor(hs, id), 0, reason: id);
        }
      });

      test('Vorbedingungen: ungültige ID, eigenes Konto, Bereich aus, blockiert, Liste nicht geladen', () async {
        final (_, g) = await ready();
        await expectLater(g.probeContact('kein-konto'), _error(GatewayError.invalidInput));
        await expectLater(g.probeContact(_me), _notAllowed());
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}));
        await expectLater(g.probeContact(_fremd), _notAllowed());
        g.setContactPolicy(ContactPolicy.off);
        await expectLater(g.probeContact(_fremd), _notAllowed());
        final (hs2, g2) = await _signedIn(encryption: true, familyMembersFail: true);
        g2.setContactPolicy(policyOut);
        await expectLater(g2.probeContact(_fremd), _notAllowed());
        expect(profileCalls(hs2), 0, reason: 'bei unvollständiger Mitgliederliste keine Netzabfrage');
      });

      test('Profil: vorhanden ⇒ Name bereinigt; nicht gefunden ⇒ no; verboten/Serverfehler ⇒ unknown (blockiert nichts)', () async {
        final (hs, g) = await ready();
        hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'Mama \u202E· familie.de'});
        var p = await g.probeContact(_fremd);
        expect((p.existence, p.displayName), (ContactExistence.yes, 'Mama familie.de'));
        for (final c in <(String, int, ContactExistence)>[('@nf:hs.example', 404, ContactExistence.no), ('@fb:hs.example', 403, ContactExistence.unknown), ('@se:hs.example', 500, ContactExistence.unknown)]) {
          hs.profiles[c.$1] = (c.$2, <String, Object?>{'errcode': c.$2 == 404 ? 'M_NOT_FOUND' : (c.$2 == 403 ? 'M_FORBIDDEN' : 'M_UNKNOWN'), 'error': 'x'});
          p = await g.probeContact(c.$1);
          expect(p.existence, c.$3, reason: c.$1);
        }
      });

      test('Erreichbarkeit: Gerät mit Schlüsseln ⇒ erreichbar; keine verschlüsselbaren Geräte ⇒ nicht erreichbar; Schlüssel unbekannt ⇒ unknown', () async {
        final (hs, g) = await ready();
        hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'F'});
        g.debugDevicesOf = (id) => <bool>[false, true];
        expect((await g.probeContact(_fremd)).reachability, ContactReachability.reachable);
        g.debugDevicesOf = (id) => <bool>[false, false];
        hs.profiles['@b:hs.example'] = (200, <String, Object?>{'displayname': 'B'});
        expect((await g.probeContact('@b:hs.example')).reachability, ContactReachability.notReachable, reason: 'Gerät ohne gültige Signaturkette');
        g.debugDevicesOf = (id) => <bool>[];
        hs.profiles['@c:hs.example'] = (200, <String, Object?>{'displayname': 'C'});
        expect((await g.probeContact('@c:hs.example')).reachability, ContactReachability.notReachable, reason: 'Schlüssel da, kein Gerät');
        g.debugDevicesOf = (id) => null;
        hs.profiles['@d:hs.example'] = (200, <String, Object?>{'displayname': 'D'});
        expect((await g.probeContact('@d:hs.example')).reachability, ContactReachability.unknown, reason: 'Abfragefehler ist nie „nicht erreichbar“');
      });

      test('Zwischenspeicher: gleiche Kennung innerhalb einer Minute ohne neue Abfrage; Unbekanntes wird nicht gemerkt', () async {
        final (hs, g) = await ready();
        hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'F'});
        await g.probeContact(_fremd);
        await g.probeContact(_fremd);
        expect(profileCalls(hs), 1);
        hs.profiles['@u:hs.example'] = (403, <String, Object?>{'errcode': 'M_FORBIDDEN', 'error': 'x'});
        await g.probeContact('@u:hs.example');
        await g.probeContact('@u:hs.example');
        expect(hs.where('GET', '/profile/@u').length, 2, reason: 'unknown wird nicht zwischengespeichert');
      });

      test('Grenzen: höchstens 20 Abfragen je Stunde (rateLimited), Familienmitglieder und Zwischenspeicher zählen nicht', () async {
        final (hs, g) = await ready();
        for (var i = 0; i < 20; i++) {
          final id = '@p$i:hs.example';
          hs.profiles[id] = (200, <String, Object?>{'displayname': 'P$i'});
          await g.probeContact(id);
          await g.probeContact(_ben);
          await g.probeContact(id);
        }
        await expectLater(g.probeContact('@p99:hs.example'), _error(GatewayError.rateLimited));
        expect((await g.probeContact('@p3:hs.example')).displayName, 'P3', reason: 'aus dem Zwischenspeicher');
      });

      test('Log: nie Kennung, Name oder Raum-ID im Fehlerfall', () async {
        AppLog.captured.clear();
        AppLog.capture = true;
        addTearDown(() => AppLog.capture = false);
        final (hs, g) = await ready();
        hs.profiles[_fremd] = (500, <String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'User $_fremd kaputt'});
        await g.probeContact(_fremd);
        final text = AppLog.captured.join('\n');
        expect(text, isNot(contains('fremd')));
        expect(text, isNot(contains('kaputt')));
      });
    });

    test('Schlüssel unbekannt: der Thread bleibt erreichbar (nie eine falsche Warnung) und Senden wird nicht als „nicht erreichbar“ verweigert', () async {
      final (_, g) = await ready(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.accepted}));
      expect(await contactThreadFor(g, '!ct:hs.example', dmJoined('!ct:hs.example', _fremd)), isNotNull);
      await g.openThread('!ct:hs.example');
      g.debugDevicesOf = (id) => null;
      await _sync(g, <String, Object?>{});
      await Future<void>.delayed(_settle);
      expect(g.threads.firstWhere((t) => t.kind == ThreadKind.contact).reachable, isTrue);
      try {
        await g.sendMessage('Hallo', threadId: '!ct:hs.example').timeout(const Duration(seconds: 3));
      } catch (e) {
        expect(e, isNot(isA<GatewayException>().having((x) => x.error, 'error', GatewayError.peerNotReachable)));
      }
    });

    test('gleichzeitige Abfragen: dieselbe Kennung teilt eine Anfrage; höchstens 4 verschiedene gleichzeitig (rateLimited)', () async {
      final (hs, g) = await ready();
      hs.holdProfile = Completer<void>();
      hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'F'});
      final a = g.probeContact(_fremd);
      final b = g.probeContact(_fremd);
      final others = <Future<ContactProbe>>[
        for (var i = 0; i < 3; i++) g.probeContact('@x$i:hs.example'),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await expectLater(g.probeContact('@x9:hs.example'), _error(GatewayError.rateLimited));
      hs.holdProfile!.complete();
      await Future.wait<ContactProbe>(<Future<ContactProbe>>[a, b, ...others]);
      expect(hs.where('GET', '/profile/@fremd').length, 1, reason: 'dieselbe Kennung teilt eine Anfrage');
    });

    group('startContactChat', () {
      test('Vorbedingungen je einzeln: ohne Datensatz, accepted, blockiert, Familienmitglied, eigenes Konto', () async {
        final (hs, g) = await ready(const ContactPolicy(enabled: true));
        var keyChecks = 0;
        g.debugDevicesOf = (id) {
          keyChecks++;
          return <bool>[true];
        };
        await expectLater(g.startContactChat(_fremd), _notAllowed(), reason: 'ohne Datensatz');
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.accepted}));
        await expectLater(g.startContactChat(_fremd), _notAllowed(), reason: 'accepted');
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}, blocked: {_fremd}));
        await expectLater(g.startContactChat(_fremd), _notAllowed(), reason: 'blockiert');
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_ben: ContactState.outgoing, _dora: ContactState.outgoing}));
        await expectLater(g.startContactChat(_ben), _notAllowed(), reason: 'Familienmitglied');
        await expectLater(g.startContactChat(_dora), _notAllowed(), reason: 'eingeladenes Familienmitglied');
        await expectLater(g.startContactChat(_me), _notAllowed());
        expect(hs.where('POST', '/createRoom'), isEmpty);
        expect(keyChecks, 0, reason: 'Vorbedingungen scheitern vor jeder Schlüsselabfrage');
      });

      test('Schreibweise des Servernamens: eigene Kennung und Familienmitglied bleiben erkannt', () async {
        final (hs, g) = await ready(const ContactPolicy(enabled: true, contacts: {'@n2:hs.example': ContactState.outgoing, _ben: ContactState.outgoing}));
        await expectLater(g.startContactChat('@n2:HS.Example'), _notAllowed(), reason: 'eigenes Konto');
        await expectLater(g.startContactChat('@ben:HS.EXAMPLE'), _notAllowed(), reason: 'Familienmitglied');
        await expectLater(g.probeContact('@n2:HS.Example'), _notAllowed());
        expect((await g.probeContact('@ben:HS.EXAMPLE')).isFamilyMember, isTrue);
        expect(profileCalls(hs), 0);
        await expectLater(g.startContactChat('@Gross:hs.example'), _error(GatewayError.invalidInput), reason: 'Großbuchstaben im lokalen Teil');
      });

      test('Liste nicht geladen: nie ein Raum', () async {
        final (hs, g) = await _signedIn(encryption: true, familyMembersFail: true);
        g.setContactPolicy(policyOut);
        await expectLater(g.startContactChat(_fremd), _notAllowed());
        expect(hs.where('POST', '/createRoom'), isEmpty);
      });

      test('ohne Verschlüsselung: encryptionUnavailable, kein Raum', () async {
        final (hs, g) = await ready(policyOut, false);
        await expectLater(g.startContactChat(_fremd), _error(GatewayError.encryptionUnavailable));
        expect(hs.where('POST', '/createRoom'), isEmpty);
      });

      test('nicht erreichbar ⇒ peerNotReachable, Abfragefehler ⇒ serverUnreachable; beide ohne Raum; danach ist ein neuer Versuch möglich', () async {
        final (hs, g) = await ready();
        g.debugDevicesOf = (id) => <bool>[false];
        await expectLater(g.startContactChat(_fremd), _error(GatewayError.peerNotReachable));
        g.debugDevicesOf = (id) => null;
        await expectLater(g.startContactChat(_fremd), _error(GatewayError.serverUnreachable));
        expect(hs.where('POST', '/createRoom'), isEmpty);
        g.debugDevicesOf = (id) => <bool>[true];
        hs.createdRoom = '!neu:hs.example';
        armCreate(hs, g);
        expect(await g.startContactChat(_fremd), isNotEmpty);
        expect(hs.where('POST', '/createRoom'), hasLength(1));
      });

      test('Anlegen: verschlüsselt, is_direct, Verlauf „shared“; gibt die Raum-ID zurück', () async {
        final (hs, g) = await ready();
        hs.createdRoom = '!neu:hs.example';
        armCreate(hs, g);
        final id = await g.startContactChat(_fremd);
        expect(id, '!neu:hs.example');
        final body = hs.where('POST', '/createRoom').single.$3;
        expect(body, contains('"is_direct":true'));
        expect(body, contains('m.megolm.v1.aes-sha2'));
        expect(body, contains('"history_visibility":"shared"'));
        expect(body, contains('"preset":"private_chat"'));
      });

      test('ein vorhandener Kontakt-Raum wird wiederverwendet, ohne neue Abfrage und ohne neuen Raum', () async {
        final (hs, g) = await ready();
        g.debugDevicesOf = (id) => <bool>[false]; // wäre „nicht erreichbar“: darf einen bestehenden Raum nicht blockieren
        await _sync(g, dmJoined('!alt:hs.example', _fremd));
        await Future<void>.delayed(_settle);
        expect(await g.startContactChat(_fremd), '!alt:hs.example');
        expect(hs.where('POST', '/createRoom'), isEmpty);
      });

      test('zweiter gleichzeitiger Aufruf für dieselbe Person: alreadyExists', () async {
        final (hs, g) = await ready();
        hs.holdCreate = Completer<void>();
        hs.createdRoom = '!neu:hs.example';
        armCreate(hs, g);
        final first = g.startContactChat(_fremd);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await expectLater(g.startContactChat(_fremd), _error(GatewayError.alreadyExists));
        hs.holdCreate!.complete();
        expect(await first, isNotEmpty);
      });

      test('Blockieren oder Familienwechsel während des Anlegens: der Raum wird verlassen, nicht verwaist', () async {
        for (final blockInsteadOfLeave in <bool>[true, false]) {
          final (hs, g) = await ready();
          hs.holdCreate = Completer<void>();
          hs.createdRoom = '!neu:hs.example';
          armCreate(hs, g);
          final f = g.startContactChat(_fremd);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (blockInsteadOfLeave) {
            g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}));
          } else {
            // Familienwechsel mit unvollständiger Liste der neuen Familie (K3c-1: die Nachprüfung entscheidet, nicht die Epoche);
            // lädt die Liste dagegen nach und die Person ist Nichtmitglied, bleibt der Raum (Test 6, a3 unten).
            hs.familyMembersFail = true;
            g.debugLeaveFamilyScope();
          }
          final done = expectLater(f, _notAllowed());
          hs.holdCreate!.complete();
          await done;
          expect(hs.where('POST', '!neu:hs.example/leave'), isNotEmpty, reason: blockInsteadOfLeave ? 'blockiert' : 'Familienwechsel');
        }
      });
    });

    test('Senden an nicht erreichbare Kontakte: peerNotReachable; Anzeige reachable=false (ohne Netz)', () async {
      final (hs, g) = await ready(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.accepted}));
      expect(await contactThreadFor(g, '!ct:hs.example', dmJoined('!ct:hs.example', _fremd)), isNotNull);
      expect(g.threads.firstWhere((t) => t.kind == ThreadKind.contact).reachable, isTrue);
      await g.openThread('!ct:hs.example');
      g.debugDevicesOf = (id) => <bool>[false];
      await _sync(g, <String, Object?>{});
      await Future<void>.delayed(_settle);
      expect(g.threads.firstWhere((t) => t.kind == ThreadKind.contact).reachable, isFalse);
      await expectLater(g.sendMessage('Hallo', threadId: '!ct:hs.example'), _error(GatewayError.peerNotReachable));
      expect(keyQueriesFor(hs, _fremd), 0, reason: 'Lesen von threads fragt nie das Netz');
    });
  });

  group('Kontakt-Identität: Pinning, Wechsel, Sendesperre, Verifizierung (#119, K3b-2b, B8)', () {
    const ct = '!ct:hs.example';
    const k1 = 'KEYONE00000000000000000000000000000000000000';
    const k2 = 'KEYTWO00000000000000000000000000000000000000';
    const policy = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted});
    const pinsType = SdkMatrixGateway.pinsAccountData;

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

    // Ohne Kontenablage (Standard dieses Harness): die lokale Ablage ist inaktiv, nur der Sitzungs-Pin schützt.
    Future<(_Hs, SdkMatrixGateway)> ready([ContactPolicy p = policy]) async {
      final (hs, g) = await _signedIn(encryption: true);
      g.setContactPolicy(p);
      g.debugDevicesOf = (id) => <bool>[true];
      return (hs, g);
    }

    // Ein Namenswechsel des Gegenübers im Kontakt-Raum löst den Abgleich aus (ein leerer Sync tut es nicht).
    var kicks = 0;
    Future<void> kick(SdkMatrixGateway g, [Map<String, Object?>? update, String peerState = 'join']) async {
      await _sync(g, update ?? <String, Object?>{
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            ct: <String, Object?>{
              'timeline': <String, Object?>{'events': <Object?>[], 'limited': false},
              'state': <String, Object?>{
                'events': <Object?>[
                  _state('m.room.member', _fremd, <String, Object?>{'membership': peerState, 'displayname': 'Fremd ${kicks++}'}, key: _fremd),
                ],
              },
            },
          },
        },
      });
      await Future<void>.delayed(_settle);
    }

    ChatThread? thread(SdkMatrixGateway g) => g.threads.where((t) => t.kind == ThreadKind.contact).firstOrNull;

    Iterable<(String, String, String)> pinWrites(_Hs hs) => hs.where('PUT', '/account_data/$pinsType');

    test('ohne Schlüssel: unbekannt; erster Schlüssel: nur vermerkt (Sitzungs-Pin), nie in die Kontodaten geschrieben', () async {
      final (hs, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      expect(thread(g)!.identity, IdentityStatus.unknown);
      master(g, _fremd, k1);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.pinned);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.pinned);
      expect(g.debugIdentityChanged, isEmpty);
      expect(pinWrites(hs), isEmpty, reason: 'Kontakt-Pins stehen nie in den Kontodaten (datensparsam)');
    });

    test('anderer Hauptschlüssel bei inaktiver lokaler Ablage: geändert in dieser Sitzung (kein Fail-open), Spiegel bleibt leer', () async {
      final (hs, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      master(g, _fremd, k1);
      await kick(g);
      master(g, _fremd, k2);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.changed);
      expect(g.debugIdentityChanged, contains(_fremd));
      expect(thread(g)!.reachable, isTrue, reason: 'Schlüssel geändert, nicht „nicht erreichbar“');
      expect(pinWrites(hs), isEmpty);
    });

    test('geändert hat Vorrang vor „nicht erreichbar“ (Geräte gesperrt), auch nach Ablauf des Erreichbarkeits-Zwischenspeichers', () async {
      final (_, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      await g.openThread(ct);
      master(g, _fremd, k1);
      await kick(g);
      master(g, _fremd, k2);
      g.debugDevicesOf = (id) => <bool>[false]; // gesperrte Geräte: encryptToDevice false
      await kick(g);
      final t = thread(g)!;
      expect(t.identity, IdentityStatus.changed);
      expect(t.reachable, isTrue);
      await expectLater(g.sendMessage('Hallo', threadId: ct), _notAllowed());
      await expectLater(g.sendAttachment(fileName: 'a.pdf', bytes: Uint8List.fromList('%PDF-1.4\n1 0 obj\n'.codeUnits), threadId: ct), _notAllowed());
    });

    test('Senden prüft den Schlüssel synchron neu: ein Wechsel zwischen zwei Abgleichen sperrt sofort', () async {
      final (_, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      await g.openThread(ct);
      master(g, _fremd, k1);
      await kick(g);
      expect(g.debugIdentityChanged, isEmpty);
      master(g, _fremd, k2); // ohne weiteren Abgleich
      await expectLater(g.sendMessage('Hallo', threadId: ct), _notAllowed());
      expect(g.debugIdentityChanged, contains(_fremd));
    });

    test('wartender Raum (outgoing, Gegenüber nur eingeladen) wird nicht gepinnt; nach dem Beitritt gilt der Schlüssel dann als erster', () async {
      final (_, g) = await ready(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd, peerState: 'invite', joined: 1, invited: 1)), isNotNull);
      master(g, _fremd, k1);
      await kick(g, null, 'invite');
      expect(thread(g)!.pending, isTrue);
      expect(thread(g)!.identity, IdentityStatus.unknown);
      master(g, _fremd, k2);
      await kick(g, null, 'invite');
      expect(g.debugIdentityChanged, isEmpty, reason: 'nichts gepinnt, also kein Wechsel');
      await kick(g);
      expect(thread(g)!.pending, isFalse);
      expect(thread(g)!.identity, IdentityStatus.pinned);
    });

    test('Akzeptieren: Kontakt accepted ⇒ nicht mehr geändert, kein Schreiben der Kontodaten; Senden wieder erlaubt', () async {
      final (hs, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      await g.openThread(ct);
      master(g, _fremd, k1);
      await kick(g);
      master(g, _fremd, k2);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.changed);
      await g.acceptIdentityChange(_fremd);
      await Future<void>.delayed(_settle);
      expect(g.debugIdentityChanged, isEmpty);
      expect(thread(g)!.identity, IdentityStatus.pinned);
      expect(pinWrites(hs), isEmpty, reason: 'keine Kontodaten-Schreibung für Kontakte');
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.pinned, reason: 'der akzeptierte Schlüssel gilt weiter');
      try {
        await g.sendMessage('Hallo', threadId: ct).timeout(const Duration(seconds: 3));
      } catch (e) {
        expect(e, isNot(isA<GatewayException>().having((x) => x.error, 'error', GatewayError.notAllowed)));
      }
      // Ein weiterer Wechsel wird wieder erkannt.
      master(g, _fremd, k1);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.changed);
    });

    test('Akzeptieren wirkt in der Sitzung auch gegen einen abweichenden Kontodaten-Pin und bei inaktiver Ablage (Vorrang-Slot)', () async {
      final (_, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      await kick(g, <String, Object?>{
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{'type': pinsType, 'content': <String, Object?>{_fremd: k1}},
          ],
        },
      });
      master(g, _fremd, k2);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.changed, reason: 'Kontodaten-Pin k1 ≠ k2');
      await g.acceptIdentityChange(_fremd);
      await Future<void>.delayed(_settle);
      await kick(g);
      expect(thread(g)!.identity, IdentityStatus.pinned);
      expect(g.debugIdentityChanged, isEmpty);
    });

    test('Akzeptieren verweigert: Fremde, Blockierte, outgoing ohne beigetretenes Gegenüber, ohne erkannte Änderung', () async {
      final (_, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      master(g, _fremd, k1);
      await kick(g);
      master(g, _dora, k1);
      await expectLater(g.acceptIdentityChange('@unbekannt:hs.example'), _error(GatewayError.notFound));
      await expectLater(g.acceptIdentityChange(_fremd), _error(GatewayError.notFound), reason: 'keine Änderung erkannt');
      master(g, _fremd, k2);
      await kick(g);
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.accepted}, blocked: {_fremd}));
      await expectLater(g.acceptIdentityChange(_fremd), _error(GatewayError.notFound), reason: 'blockiert');
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.blocked}, blocked: {_fremd}));
      await expectLater(g.acceptIdentityChange(_fremd), _error(GatewayError.notFound));
      g.setContactPolicy(const ContactPolicy(enabled: true));
      await expectLater(g.acceptIdentityChange(_fremd), _error(GatewayError.notFound), reason: 'ohne Datensatz');
    });

    test('Akzeptieren: outgoing mit wartendem Gegenüber verweigert', () async {
      final (_, g) = await ready(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd, peerState: 'invite', joined: 1, invited: 1)), isNotNull);
      master(g, _fremd, k1);
      g.debugIdentityChanged.add(_fremd);
      await expectLater(g.acceptIdentityChange(_fremd), _error(GatewayError.notFound));
    });

    test('startVerification: Fremde mit und ohne deviceId ⇒ notAllowed (vor encryptionUnavailable); eigenes Konto und Mitglieder nicht', () async {
      final (_, g) = await ready();
      await expectLater(g.startVerification(userId: '@fremd2:hs.example'), _error(GatewayError.notAllowed));
      await expectLater(g.startVerification(userId: '@fremd2:hs.example', deviceId: 'D1'), _error(GatewayError.notAllowed));
      await expectLater(g.startVerification(userId: _me, deviceId: 'D1'), _error(GatewayError.encryptionUnavailable), reason: 'eigenes Konto bleibt erlaubt');
      await expectLater(g.startVerification(userId: _ben), _error(GatewayError.encryptionUnavailable), reason: 'Mitglied bleibt erlaubt');
      // Kontakt ohne Thread (noch nicht synchronisiert): ebenfalls verweigert.
      await expectLater(g.startVerification(userId: _fremd), _error(GatewayError.notAllowed));
    });

    test('eingehende Anfragen: nur im gewählten Kontakt-Raum oder To-Device, nie von Fremden, Blockierten oder ohne Thread', () async {
      final (_, g) = await ready();
      expect(g.debugIncomingAllowed(_fremd, null), isFalse, reason: 'noch kein Thread (Neustart, Lazy Loading)');
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      expect(g.debugIncomingAllowed(_fremd, null), isTrue);
      expect(g.debugIncomingAllowed(_fremd, ct), isTrue);
      expect(g.debugIncomingAllowed(_fremd, '!gruppe:hs.example'), isFalse, reason: 'falscher Raum');
      expect(g.debugIncomingAllowed('@fremd2:hs.example', ct), isFalse);
      expect(g.debugIncomingAllowed('@fremd2:hs.example', null), isFalse);
      expect(g.debugIncomingAllowed(_me, '!x:hs.example'), isTrue);
      expect(g.debugIncomingAllowed(_ben, '!x:hs.example'), isTrue, reason: 'Mitglied wie bisher');
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.accepted}, blocked: {_fremd}));
      expect(g.debugIncomingAllowed(_fremd, ct), isFalse, reason: 'blockiert');
      g.setContactPolicy(ContactPolicy.off);
      expect(g.debugIncomingAllowed(_fremd, ct), isFalse, reason: 'Bereich aus');
    });

    test('eingehende Anfrage bei laufender Verifizierung abgewiesen (S4: nur eine zur Zeit), danach wieder erlaubt', () async {
      final (_, g) = await ready();
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd)), isNotNull);
      expect(g.debugIncomingAllowed(_fremd, ct), isTrue);
      final v = KeyVerification(encryption: _NoEncryption(), userId: _fremd);
      g.debugVerification = v;
      expect(g.debugIncomingAllowed(_fremd, ct), isFalse, reason: 'läuft (waitingAccept)');
      expect(g.debugIncomingAllowed(_me, null), isFalse, reason: 'gilt für jeden Absender');
      v.state = KeyVerificationState.error;
      expect(g.debugIncomingAllowed(_fremd, ct), isTrue, reason: 'Fehler beendet die Sperre');
      v.state = KeyVerificationState.askSas;
      expect(g.debugIncomingAllowed(_fremd, ct), isFalse);
      v.state = KeyVerificationState.done;
      expect(g.debugIncomingAllowed(_fremd, ct), isTrue, reason: 'fertig');
      g.debugVerification = null;
    });

    test('eingehende Anfrage bei wartendem Raum (outgoing) abgelehnt, nach dem Beitritt erlaubt', () async {
      final (_, g) = await ready(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      expect(await contactThreadFor(g, ct, dmJoined(ct, _fremd, peerState: 'invite', joined: 1, invited: 1)), isNotNull);
      expect(g.debugIncomingAllowed(_fremd, null), isFalse);
      expect(g.debugContactRoomOf(_fremd), isNull);
      await kick(g, dmJoined(ct, _fremd));
      expect(g.debugIncomingAllowed(_fremd, ct), isTrue);
    });

    test('_contactRoomOf: bei zwei Räumen desselben Gegenübers beigetretener vor wartendem, dann kleinste Raum-ID', () async {
      const a = '!aa:hs.example';
      const z = '!zz:hs.example';
      Map<String, Object?> both(String peerStateA, String peerStateZ) {
        final ra = (((dmJoined(a, _fremd, peerState: peerStateA, joined: peerStateA == 'join' ? 2 : 1, invited: peerStateA == 'join' ? 0 : 1)['rooms']! as Map)['join']! as Map)[a]) as Map<String, Object?>;
        final rz = (((dmJoined(z, _fremd, peerState: peerStateZ, joined: peerStateZ == 'join' ? 2 : 1, invited: peerStateZ == 'join' ? 0 : 1)['rooms']! as Map)['join']! as Map)[z]) as Map<String, Object?>;
        return <String, Object?>{
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_fremd: <String>[a, z]}},
            ],
          },
          'rooms': <String, Object?>{'join': <String, Object?>{a: ra, z: rz}},
        };
      }

      final (_, g1) = await ready();
      await kick(g1, both('join', 'join'));
      expect(g1.debugContactRoomOf(_fremd), a);
      final (_, g2) = await ready(const ContactPolicy(enabled: true, contacts: {_fremd: ContactState.outgoing}));
      await kick(g2, both('invite', 'join'));
      expect(g2.debugContactRoomOf(_fremd), z, reason: 'der wartende Raum mit der kleineren ID zählt nicht');
    });
  });

  group('Kontakte ohne Familie (#119, K3c-1)', () {
    const ct = '!ct:hs.example';
    const priv = '!privat:hs.example';
    const k1 = 'KEYONE00000000000000000000000000000000000000';
    const k2 = 'KEYTWO00000000000000000000000000000000000000';
    const policy = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted});
    const policyOut = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.outgoing});
    const short = Duration(milliseconds: 700);

    /// Konto ohne Familie, Bereich an, Schlüssel der Person erreichbar (Test-Naht).
    Future<(_Hs, SdkMatrixGateway)> noFamily([ContactPolicy p = policy, Duration row2Delay = const Duration(seconds: 60)]) async {
      final (hs, g) = await _signedIn(encryption: true, familySynced: false, row2Delay: row2Delay);
      g.setContactPolicy(p);
      g.debugDevicesOf = (id) => <bool>[true];
      return (hs, g);
    }

    List<ChatThread> contacts(SdkMatrixGateway g) => g.threads.where((t) => t.kind == ThreadKind.contact).toList();

    Future<void> settle(SdkMatrixGateway g, Map<String, Object?> update) async {
      await _sync(g, update);
      await Future<void>.delayed(_settle);
    }

    // Ein Sync mit Kontodaten löst den Abgleich aus (ein leerer Sync tut es nicht).
    Map<String, Object?> kickUpdate() => <String, Object?>{
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'x.kick', 'content': <String, Object?>{'n': _n++}},
            ],
          },
        };
    Future<void> kick(SdkMatrixGateway g) => settle(g, kickUpdate());

    Map<String, Object?> pointer(String room) => <String, Object?>{
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'de.inneso.familynexus.family', 'content': <String, Object?>{'room_id': room}},
            ],
          },
        };

    /// Wie `_familySync()`, aber mit [extra] als weiterem beigetretenen Mitglied.
    Map<String, Object?> familyWith(String? extra) {
      final u = _familySync();
      final events = ((((u['rooms']! as Map)['join']! as Map)[_familyRoom]! as Map)['state']! as Map)['events']! as List<Object?>;
      if (extra != null) events.add(_memberEvent(extra, 'join'));
      return u;
    }

    Map<String, Object?> withUnread(Map<String, Object?> update, String room, int n) {
      (((update['rooms']! as Map)['join']! as Map)[room]! as Map<String, Object?>)['unread_notifications'] = <String, Object?>{'notification_count': n, 'highlight_count': 0};
      return update;
    }

    Map<String, Object?> privateRoom() => <String, Object?>{
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'de.inneso.familynexus.private_room', 'content': <String, Object?>{'room_id': priv}},
            ],
          },
          'rooms': <String, Object?>{
            'join': <String, Object?>{
              priv: <String, Object?>{
                'summary': <String, Object?>{'m.joined_member_count': 1, 'm.invited_member_count': 0},
                'state': <String, Object?>{
                  'events': <Object?>[
                    _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
                    _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
                    _memberEvent(_me, 'join'),
                  ],
                },
              },
            },
          },
        };

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

    /// Ein von der App gesperrtes Gerät mit (im Harness ohne vodozemac als gültig geltender) Selbstsignatur.
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

    Future<void> noSend(Future<Object?> f) => expectLater(f.timeout(const Duration(seconds: 3)), _notAllowed());

    /// Nach dem Anlegen liefert der Server den Raum im Sync (Gegenüber nur eingeladen).
    void armCreate(_Hs hs, SdkMatrixGateway g, {String room = '!neu:hs.example'}) {
      hs.createdRoom = room;
      hs.onCreate = (r) => Future<void>.delayed(
            const Duration(milliseconds: 150),
            () => _syncJoined(g, dmJoined(r, _fremd, peerState: 'invite', joined: 1, invited: 1)),
          ).ignore();
    }

    test('1: Kontaktzustand ohne Familie bleibt über mehrere Abgleiche; probeContact liefert ein Ergebnis (Funktionstest des neuen Pfads)', () async {
      final (hs, g) = await noFamily();
      expect(g.family, isNull);
      await settle(g, dmJoined(ct, _fremd));
      expect(contacts(g), hasLength(1), reason: 'Thread ohne Familie');
      for (var i = 0; i < 3; i++) {
        await kick(g);
        expect(contacts(g), hasLength(1), reason: 'Abgleich $i');
      }
      expect(g.family, isNull);
      hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'Fremd'});
      final p = await g.probeContact(_fremd);
      expect((p.existence, p.isFamilyMember), (ContactExistence.yes, false));
    });

    group('familyResolved im Gateway (Wahrheitstabelle)', () {
      test('Zeile 2 (Zeiger auf unbekannten Raum): keine Kontakt-Threads, keine Anfragen, probe/start notAllowed', () async {
        final (_, g) = await noFamily(policyOut);
        await settle(g, dmJoined(ct, _fremd, peerState: 'invite', joined: 1, invited: 1));
        await settle(g, dmInvite('!rq:hs.example', '@fremd2:hs.example'));
        expect(contacts(g), hasLength(1));
        expect(g.contactRequests, hasLength(1));
        await settle(g, pointer('!gone:hs.example'));
        expect(g.debugContactFamilyResolved, isFalse);
        expect(contacts(g), isEmpty);
        expect(g.contactRequests, isEmpty);
        await expectLater(g.probeContact(_fremd), _notAllowed());
        await expectLater(g.startContactChat(_fremd), _notAllowed());
      });

      test('Zeile 5 (Familienraum beigetreten, Familie noch nicht gebaut): nicht aufgelöst; danach wieder Kontakte', () async {
        final (_, g) = await noFamily();
        await settle(g, dmJoined(ct, _fremd));
        expect(contacts(g), hasLength(1));
        final inHook = Completer<void>();
        final gate = Completer<void>();
        g.debugBeforeFamilyTimeline = () async {
          if (!inHook.isCompleted) inHook.complete();
          await gate.future;
        };
        await _sync(g, familyWith(null));
        await inHook.future;
        expect(g.family, isNull, reason: 'Zwischenzustand');
        expect(g.debugContactFamilyResolved, isFalse);
        expect(g.debugContactMembersComplete, isFalse);
        await expectLater(g.probeContact(_fremd), _notAllowed());
        g.debugBeforeFamilyTimeline = null;
        gate.complete();
        await Future<void>.delayed(_settle * 2);
        expect(g.family, isNotNull);
        expect(g.debugContactMembersComplete, isTrue);
        expect(contacts(g), hasLength(1), reason: 'Fremder bleibt Kontakt, Liste der Familie geladen');
      });

      test('Zeile 1 vor der ersten Serverantwort nicht aufgelöst (auch mit _syncedOnce), danach aufgelöst: Abgleich auch bei leerer Antwort', () async {
        final (_, g1) = await _signedIn(encryption: true, familySynced: false);
        final dir = _lastDir!;
        await settle(g1, dmJoined(ct, _fremd));
        await g1.close();
        final hs2 = _Hs()..holdFirst = Completer<void>();
        final g = await _restarted(hs2, dir);
        expect(g.initialSyncDone, isTrue, reason: 'gespeicherter Stand: _syncedOnce vor der Serverantwort');
        g.setContactPolicy(policy);
        g.debugDevicesOf = (id) => <bool>[true];
        await Future<void>.delayed(_settle);
        expect(g.debugContactFamilyResolved, isFalse);
        expect(contacts(g), isEmpty, reason: 'unaufgelöst ⇒ keine Kontakt-Threads');
        await expectLater(g.probeContact(_fremd), _notAllowed());
        hs2.holdFirst!.complete();
        await Future<void>.delayed(_settle * 3);
        expect(g.debugContactFamilyResolved, isTrue);
        expect(contacts(g), hasLength(1), reason: 'Übergang fresh false→true löst den Abgleich aus (auch bei leerer Antwort)');
      });

      test('Kontowechsel: nach Abmelden und neuer Anmeldung gilt „keine Familie“ erst nach der ersten Antwort des neuen Kontos', () async {
        final (hs, g) = await noFamily();
        expect(g.debugContactFamilyResolved, isTrue);
        await g.logout();
        expect(g.debugContactFamilyResolved, isFalse);
        await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n2', password: 'geheim123');
        g.setContactPolicy(policy);
        await Future<void>.delayed(_settle);
        // `release` hält jede weitere Antwort: das neue Konto hat noch nicht geantwortet.
        expect(hs.release.isCompleted, isFalse);
        expect(g.debugContactFamilyResolved, isFalse);
        expect(g.debugContactMembersComplete, isFalse);
      });
    });

    group('Rückfall für Zeile 2 (60 s UND 3 zählende Syncs, hier mit kurzer Zeit)', () {
      test('3 Syncs, aber vor Ablauf der Zeit ⇒ nicht aufgelöst; nach Ablauf aufgelöst', () async {
        final (_, g) = await noFamily(policy, short);
        await _sync(g, pointer('!gone:hs.example')); // Eintritt (zählt nicht)
        for (var i = 0; i < 3; i++) {
          await _sync(g, kickUpdate());
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(g.debugContactFamilyResolved, isFalse, reason: 'Zähler ≥ 3, aber Zeit nicht erreicht');
        await Future<void>.delayed(short + _settle);
        expect(g.debugContactFamilyResolved, isTrue);
      });

      test('nur leere Long-Polls: nie aufgelöst (zählen nicht), auch nach Ablauf der Zeit', () async {
        final (_, g) = await noFamily(policy, short);
        await _sync(g, pointer('!gone:hs.example'));
        for (var i = 0; i < 6; i++) {
          await _sync(g, <String, Object?>{});
        }
        await Future<void>.delayed(short + _settle);
        expect(g.debugContactFamilyResolved, isFalse);
      });

      test('3 zählende Syncs mit leeren Long-Polls dazwischen: nach Ablauf aufgelöst (leere brechen die Zählung nicht ab)', () async {
        final (_, g) = await noFamily(policy, short);
        await _sync(g, pointer('!gone:hs.example'));
        for (var i = 0; i < 3; i++) {
          await _sync(g, kickUpdate());
          await _sync(g, <String, Object?>{});
        }
        await Future<void>.delayed(short + _settle);
        expect(g.debugContactFamilyResolved, isTrue);
      });

      test('Zeigeränderung setzt zurück: keine kumulative Zählung über den Wechsel', () async {
        final (_, g) = await noFamily(policy, short);
        await _sync(g, pointer('!gone:hs.example'));
        await _sync(g, kickUpdate());
        await _sync(g, kickUpdate());
        await _sync(g, pointer('!other:hs.example')); // anderer Zeiger: Eintritt, Zähler 0
        await _sync(g, kickUpdate());
        await Future<void>.delayed(short + _settle);
        expect(g.debugContactFamilyResolved, isFalse, reason: '1 Sync seit dem Wechsel');
        await _sync(g, kickUpdate());
        await _sync(g, kickUpdate());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(g.debugContactFamilyResolved, isTrue, reason: '3 Syncs seit dem Wechsel und Zeit abgelaufen');
      });
    });

    group('Neuauswertung: Auslöser, Timer, Gate', () {
      test('(ii) Zeile 2 ohne weiteren Sync: der Timer startet erst ab fresh = true und löst nach der Zeit einen Abgleich aus', () async {
        final (_, g1) = await _signedIn(encryption: true, familySynced: false);
        final dir = _lastDir!;
        await settle(g1, pointer('!gone:hs.example'));
        await g1.close();
        final hs2 = _Hs()..holdFirst = Completer<void>();
        final g = await _restarted(hs2, dir, row2Delay: short);
        g.setContactPolicy(policy);
        await Future<void>.delayed(_settle);
        expect(g.debugContactRow2TimerPending, isFalse, reason: 'vor der ersten Antwort kein Timer');
        hs2.holdFirst!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(g.debugContactRow2TimerPending, isTrue);
        var refreshes = 0;
        g.debugBeforeRefresh = () async => refreshes++;
        await Future<void>.delayed(short + _settle);
        expect(refreshes, greaterThanOrEqualTo(1), reason: 'der Timer löst einen Abgleich aus');
        expect(g.debugContactRow2TimerPending, isFalse);
      });

      test('(iii) Abmelden, Ausschalten, Familie gefunden und dispose brechen den Timer ab', () async {
        Future<SdkMatrixGateway> armed() async {
          final (_, g) = await noFamily(policy, const Duration(seconds: 30));
          await _sync(g, pointer('!gone:hs.example'));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(g.debugContactRow2TimerPending, isTrue);
          return g;
        }

        final off = await armed();
        off.setContactPolicy(ContactPolicy.off);
        expect(off.debugContactRow2TimerPending, isFalse, reason: 'Ausschalten');
        final out = await armed();
        await out.logout();
        expect(out.debugContactRow2TimerPending, isFalse, reason: 'Abmelden');
        final scope = await armed();
        await settle(scope, familyWith(null));
        expect(scope.debugContactRow2TimerPending, isFalse, reason: 'Zeiger zeigt auf beigetretene Familie (Raumzustand geändert)');
        final disposed = await armed();
        disposed.dispose();
        expect(disposed.debugContactRow2TimerPending, isFalse, reason: 'dispose');
      });

      test('(iv) Gate: ohne eingeschalteten Bereich kein zusätzlicher Abgleich nach der ersten leeren Antwort und kein Timer; mit Bereich einer', () async {
        Future<(int, bool)> run({required bool enabled, required bool row2}) async {
          final (_, g1) = await _signedIn(encryption: true, familySynced: false);
          final dir = _lastDir!;
          await settle(g1, row2 ? pointer('!gone:hs.example') : dmJoined(ct, _fremd));
          await g1.close();
          final hs2 = _Hs()..holdFirst = Completer<void>();
          final g = await _restarted(hs2, dir, row2Delay: short);
          if (enabled) {
            g.setContactPolicy(policy);
          }
          await Future<void>.delayed(_settle * 2);
          var refreshes = 0;
          g.debugBeforeRefresh = () async => refreshes++;
          hs2.holdFirst!.complete();
          await Future<void>.delayed(_settle * 2);
          return (refreshes, g.debugContactRow2TimerPending);
        }

        final (offRefresh, offTimer) = await run(enabled: false, row2: true);
        expect(offRefresh, 0, reason: 'Bereich aus: kein Abgleich nach der leeren Antwort (I1, #150)');
        expect(offTimer, isFalse, reason: 'Bereich aus: kein Timer');
        final (onRefresh, onTimer) = await run(enabled: true, row2: true);
        expect(onRefresh, greaterThanOrEqualTo(1), reason: 'Gegenprobe: mit Bereich löst der Übergang den Abgleich aus');
        expect(onTimer, isTrue);
      });

      test('(iv-b) Gate: Bereich aus + nicht-leere Antwort mit Zeiger auf unbekannten Raum (Zeile 2) startet keinen Timer; Einschalten danach schon', () async {
        final (_, g) = await _signedIn(encryption: true, familySynced: false);
        await settle(g, pointer('!gone:hs.example'));
        await Future<void>.delayed(_settle * 2);
        expect(g.debugContactRow2TimerPending, isFalse, reason: 'Bereich aus: Zeile 2 wird nicht beobachtet (#150)');
        g.setContactPolicy(policy);
        await Future<void>.delayed(_settle * 2);
        expect(g.debugContactRow2TimerPending, isTrue, reason: 'Gegenprobe: mit Bereich beobachtet');
      });

      test('(v) Einschalten nach der ersten Antwort: setContactPolicy löst den Abgleich aus, Kontakte erscheinen', () async {
        final (_, g) = await _signedIn(encryption: true, familySynced: false);
        await settle(g, dmJoined(ct, _fremd));
        expect(contacts(g), isEmpty);
        g.setContactPolicy(policy);
        await Future<void>.delayed(_settle);
        expect(contacts(g), hasLength(1));
      });
    });

    test('3: Anfragen ohne Familie: Fremder ⇒ Anfrage; Kontakt mit Datensatz wird angenommen; Gruppeneinladung nie', () async {
      final (hs, g) = await noFamily();
      await settle(g, dmInvite('!rq:hs.example', '@fremd2:hs.example'));
      expect(g.contactRequests.map((r) => r.roomId), <String>['!rq:hs.example']);
      expect(hs.where('POST', '/join'), isEmpty, reason: 'Fremde nie angenommen');
      final group = dmInvite('!gr:hs.example', '@fremd3:hs.example', direct: false);
      (((group['rooms']! as Map)['invite']! as Map)['!gr:hs.example']! as Map<String, Object?>)['invite_state'] = <String, Object?>{
        'events': <Object?>[
          <String, Object?>{
            'type': 'm.room.member',
            'state_key': _me,
            'sender': '@fremd3:hs.example',
            'content': <String, Object?>{'membership': 'invite'},
          },
          <String, Object?>{'type': 'm.room.join_rules', 'state_key': '', 'sender': '@fremd3:hs.example', 'content': <String, Object?>{'join_rule': 'invite'}},
        ],
      };
      await settle(g, group);
      // K4-2a (bewusste Umkehr, Vorschlag §3.2): Eine Gruppeneinladung mit `join_rule: invite` ist jetzt eine **Gruppenanfrage**
      // (nie automatisch angenommen, nie eine Familieneinladung); vorher wurde sie ignoriert.
      expect(g.contactRequests.map((r) => r.roomId), <String>['!rq:hs.example', '!gr:hs.example']);
      expect(g.contactRequests.where((r) => r.roomId == '!gr:hs.example').single.isGroup, isTrue);
      expect(g.contactRequests.where((r) => r.roomId == '!rq:hs.example').single.isGroup, isFalse);
      expect(g.invitations, isEmpty, reason: 'Gruppe ohne knock ist nie eine Familieneinladung');
      expect(hs.where('POST', '!gr:hs.example/join'), isEmpty);
      hs.onJoin = (_) {};
      await settle(g, dmInvite('!von-kontakt:hs.example', _fremd));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '!von-kontakt:hs.example/join'), isNotEmpty, reason: 'eigener Kontakt wird angenommen');
    });

    test('4: privater Raum ohne Familie: ContactSignal erreicht die Zuhörer; fremder Absender, Familienraum-Logik und Kontakt-Räume nie', () async {
      final (_, g) = await noFamily();
      await settle(g, <String, Object?>{
        ...privateRoom(),
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            ...(((privateRoom()['rooms']! as Map)['join']!) as Map<String, Object?>),
            ...(((dmJoined(ct, _fremd)['rooms']! as Map)['join']!) as Map<String, Object?>),
          },
        },
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{'type': 'de.inneso.familynexus.private_room', 'content': <String, Object?>{'room_id': priv}},
            <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_fremd: <String>[ct]}},
          ],
        },
      });
      final timeline = g.debugPrivateTimeline;
      expect(timeline, isNotNull, reason: 'privater Raum wird ohne Familie abonniert');
      await g.openThread(ct);
      final inContact = g.debugContactTimeline(ct)!;
      final seen = <ContactSignal>[];
      final sub = g.calendarSignals.listen((s) {
        if (s is ContactSignal) seen.add(s);
      });
      addTearDown(sub.cancel);
      timeline!.events.insert(0, _arrived(g, priv, 'de.inneso.familynexus.contact', _me, <String, Object?>{'marker': 'privat-eigen'}));
      timeline.events.insert(0, _arrived(g, priv, 'de.inneso.familynexus.contact', _cara, <String, Object?>{'marker': 'privat-fremd'}));
      inContact.events.insert(0, _arrived(g, ct, 'de.inneso.familynexus.contact', _me, <String, Object?>{'marker': 'kontakt-raum'}));
      await kick(g);
      expect(seen.map((s) => s.content['marker']), <Object?>['privat-eigen']);
    });

    group('5: Schlüsselwechsel ohne Familie (me aus dem Client)', () {
      test('geändert ⇒ Banner, Senden (Text, Anhang) notAllowed, Akzeptieren wirkt, ein erneuter Wechsel sperrt synchron', () async {
        final (hs, g) = await noFamily();
        await settle(g, dmJoined(ct, _fremd));
        await g.openThread(ct);
        master(g, _fremd, k1);
        await kick(g);
        ChatThread thread() => contacts(g).single;
        expect(thread().identity, IdentityStatus.pinned);
        master(g, _fremd, k2);
        await kick(g);
        expect(thread().identity, IdentityStatus.changed);
        await noSend(g.sendMessage('Hallo', threadId: ct));
        await noSend(g.sendAttachment(fileName: 'a.pdf', bytes: Uint8List.fromList('%PDF-1.4\n1 0 obj\n'.codeUnits), threadId: ct));
        await g.acceptIdentityChange(_fremd);
        await Future<void>.delayed(_settle);
        expect(thread().identity, IdentityStatus.pinned);
        expect(hs.where('PUT', '/account_data/${SdkMatrixGateway.pinsAccountData}'), isEmpty);
        // Zwischen zwei Abgleichen: nur die frische Auswertung im Sendeweg (mit `me` vom Client) sperrt.
        master(g, _fremd, k1);
        await noSend(g.sendMessage('Hallo', threadId: ct));
        expect(g.debugIdentityChanged, contains(_fremd));
      });
    });

    group('6: Kontakt-Epoche getrennt von der Familien-Epoche (Nachprüfung entscheidet)', () {
      test('(a1) keine → keine: Abgleich während der Anlage, der Raum bleibt, Rückgabe ok', () async {
        final (hs, g) = await noFamily(policyOut);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final f = g.startContactChat(_fremd);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await kick(g); // Abgleich ohne Wechsel (in `_resetFamilyChats` steigt `_dmEpoch`, die Kontakt-Epoche nicht)
        hs.holdCreate!.complete();
        expect(await f, '!neu:hs.example');
        expect(hs.where('POST', '!neu:hs.example/leave'), isEmpty);
      });

      test('(a2) keine → A mit unvollständiger Liste: der Raum wird verlassen, notAllowed', () async {
        final (hs, g) = await noFamily(policyOut);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final f = g.startContactChat(_fremd);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        hs.familyMembersFail = true;
        await settle(g, familyWith(null));
        final done = expectLater(f, _notAllowed());
        hs.holdCreate!.complete();
        await done;
        expect(hs.where('POST', '!neu:hs.example/leave'), isNotEmpty);
      });

      test('(a3) keine → A, Liste nachgeladen, Person Nichtmitglied: der Raum bleibt', () async {
        final (hs, g) = await noFamily(policyOut);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final f = g.startContactChat(_fremd);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await settle(g, familyWith(null));
        expect(g.debugContactMembersComplete, isTrue);
        hs.holdCreate!.complete();
        expect(await f, '!neu:hs.example');
        expect(hs.where('POST', '!neu:hs.example/leave'), isEmpty);
      });

      test('(a4) keine → A, die Person ist Mitglied der neuen Familie: der Raum wird verlassen', () async {
        final (hs, g) = await noFamily(policyOut);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final f = g.startContactChat(_fremd);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await settle(g, familyWith(_fremd));
        final done = expectLater(f, _notAllowed());
        hs.holdCreate!.complete();
        await done;
        expect(hs.where('POST', '!neu:hs.example/leave'), isNotEmpty);
      });

      test('(b) creating überlebt den Familienwechsel (kein doppeltes Anlegen), failed bleibt verlassen und unsichtbar', () async {
        final (hs, g) = await noFamily(policyOut);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final f = g.startContactChat(_fremd);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await settle(g, familyWith(null));
        await expectLater(g.startContactChat(_fremd), _error(GatewayError.alreadyExists));
        hs.holdCreate!.complete();
        await f;
        expect(hs.where('POST', '/createRoom'), hasLength(1));
        // `failed`: bewusst verlassener Raum erscheint nach einem Familienwechsel nicht wieder.
        final (_, g2) = await noFamily();
        await settle(g2, dmJoined(ct, _fremd));
        expect(contacts(g2), hasLength(1));
        await g2.leaveConversation(ct);
        await settle(g2, dmJoined(ct, _fremd));
        expect(contacts(g2), isEmpty);
        await settle(g2, familyWith(null));
        await settle(g2, dmJoined(ct, _fremd));
        expect(contacts(g2), isEmpty, reason: 'failed überlebt den Familienwechsel');
      });

      test('(c0) Scope-Wechsel während einer Probe: Person wird Mitglied ⇒ notAllowed, kein Eintrag im Zwischenspeicher; Nichtmitglied ⇒ Ergebnis', () async {
        for (final member in <bool>[true, false]) {
          final (hs, g) = await noFamily(policyOut);
          hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'Fremd'});
          hs.holdProfile = Completer<void>();
          final f = g.probeContact(_fremd);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await settle(g, familyWith(member ? _fremd : null));
          hs.holdProfile!.complete();
          if (member) {
            await expectLater(f, _notAllowed());
            expect(g.debugProbeCacheLength, 0, reason: 'nichts zwischengespeichert');
          } else {
            expect((await f).existence, ContactExistence.yes);
            expect(g.debugProbeCacheLength, 1);
          }
        }
      });

      test('(c) probeCache wird beim Familienwechsel verworfen (zweite Probe fragt neu), peerCache bleibt (Anforderung nicht wiederholt)', () async {
        final (hs, g) = await noFamily();
        hs.profiles[_fremd] = (200, <String, Object?>{'displayname': 'Fremd'});
        await g.probeContact(_fremd);
        await g.probeContact(_fremd);
        expect(hs.where('GET', '/profile/@fremd').length, 1, reason: 'aus dem Zwischenspeicher');
        var loads = 0;
        g.debugPeerMembershipLoader = (room, peer) async {
          loads++;
          return PeerMembership.join;
        };
        await settle(g, dmJoined(ct, _fremd, members: <String>[_me]));
        await kick(g);
        expect(loads, 1);
        expect(contacts(g), hasLength(1));
        await settle(g, familyWith(null));
        await kick(g);
        expect(contacts(g), hasLength(1), reason: 'peerCache überlebt');
        expect(loads, 1, reason: 'Mitgliedszustand wird nicht erneut angefordert');
        await g.probeContact(_fremd);
        expect(hs.where('GET', '/profile/@fremd').length, 2, reason: 'probeCache verworfen');
      });

      test('(d) Abmelden verwirft alles: Epoche steigt, failed und Pins sind weg; ein Familienwechsel hebt die Epoche nicht', () async {
        final (_, g) = await noFamily();
        await settle(g, dmJoined(ct, _fremd));
        final epoch = g.debugContactEpoch;
        g.debugLeaveFamilyScope();
        expect(g.debugContactEpoch, epoch, reason: 'Familienwechsel: keine neue Kontakt-Epoche');
        await g.openThread(ct);
        master(g, _fremd, k1);
        await kick(g);
        master(g, _fremd, k2);
        await kick(g);
        expect(contacts(g).single.identity, IdentityStatus.changed);
        await g.leaveConversation(ct);
        await g.logout();
        expect(g.debugContactEpoch, greaterThan(epoch));
        await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n2', password: 'geheim123');
        g.setContactPolicy(policy);
        await settle(g, dmJoined(ct, _fremd));
        expect(contacts(g), hasLength(1), reason: 'failed wurde verworfen');
        master(g, _fremd, k2);
        await kick(g);
        expect(contacts(g).single.identity, IdentityStatus.pinned, reason: 'Sitzungs-Pin und Änderungsvermerk wurden verworfen (k2 gilt als erster Schlüssel)');
      });
    });

    group('7: Pin-Sackgasse (Gateway), je Variante', () {
      Future<(_Hs, SdkMatrixGateway)> ready([ContactPolicy p = policy]) async {
        final (hs, g) = await _signedIn(encryption: true);
        g.setContactPolicy(p);
        g.debugDevicesOf = (id) => <bool>[true];
        return (hs, g);
      }

      test('A: Entfernen und Wiederhinzufügen eines Kontakts mit geändertem Schlüssel legt den Raum an; Senden gesperrt; nach Beitritt Akzeptieren', () async {
        final (hs, g) = await ready();
        await settle(g, dmJoined(ct, _fremd));
        await g.openThread(ct);
        master(g, _fremd, k1);
        await kick(g);
        master(g, _fremd, k2);
        await kick(g);
        expect(contacts(g).single.identity, IdentityStatus.changed);
        await g.leaveConversation(ct);
        g.setContactPolicy(policyOut); // neuer Datensatz outgoing
        armCreate(hs, g);
        final id = await g.startContactChat(_fremd);
        expect(id, '!neu:hs.example');
        expect(hs.where('POST', '/createRoom'), isNotEmpty, reason: 'vor K3c-1: notAllowed vor dem Anlegen');
        await Future<void>.delayed(_settle);
        final t = contacts(g).singleWhere((t) => t.id == '!neu:hs.example');
        expect((t.pending, t.identity), (true, IdentityStatus.changed));
        await g.openThread(t.id);
        await noSend(g.sendMessage('Hallo', threadId: t.id));
        // Das Gegenüber tritt bei: Banner bleibt `changed`, Akzeptieren möglich.
        await kick(g);
        await settle(g, dmJoined('!neu:hs.example', _fremd));
        expect(contacts(g).singleWhere((t) => t.id == '!neu:hs.example').pending, isFalse);
        expect(contacts(g).singleWhere((t) => t.id == '!neu:hs.example').identity, IdentityStatus.changed);
        await g.acceptIdentityChange(_fremd);
        await Future<void>.delayed(_settle);
        expect(contacts(g).singleWhere((t) => t.id == '!neu:hs.example').identity, IdentityStatus.pinned);
      });

      test('B: Einladung der Gegenseite bei identityChanged wird angenommen; Senden gesperrt; Fremder ohne Datensatz weiter nur Anfrage', () async {
        final (hs, g) = await ready();
        g.debugIdentityChanged.add(_fremd);
        hs.onJoin = (r) => Future<void>.delayed(const Duration(milliseconds: 150), () => _syncJoined(g, dmJoined(r, _fremd))).ignore();
        await _sync(g, dmInvite('!neu:hs.example', _fremd));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(hs.where('POST', '!neu:hs.example/join'), isNotEmpty, reason: 'vor K3c-1 liegt die Einladung unbeantwortet');
        final t = contacts(g).singleWhere((t) => t.id == '!neu:hs.example');
        expect(t.identity, IdentityStatus.changed);
        await g.openThread(t.id);
        await noSend(g.sendMessage('Hallo', threadId: t.id));
        g.debugIdentityChanged.add('@fremd2:hs.example');
        await settle(g, dmInvite('!rq:hs.example', '@fremd2:hs.example'));
        expect(hs.where('POST', '!rq:hs.example/join'), isEmpty);
        expect(g.contactRequests.map((r) => r.roomId), <String>['!rq:hs.example']);
      });

      test('C (Neustartzustand): geänderte Geräte von der App gesperrt, kein Pin ⇒ identityChanged, Raum wird angelegt; kein TOFU beim Prüfen; echtes notReachable bleibt', () async {
        final (hs, g) = await ready(policyOut);
        g.debugDevicesOf = (id) => <bool>[false]; // gesperrte Geräte: encryptToDevice false
        blockedDevice(g, _fremd);
        master(g, _fremd, k1);
        expect(g.debugIdentityChanged, isEmpty, reason: 'Neustart: Sitzungsvermerk leer');
        armCreate(hs, g);
        final id = await g.startContactChat(_fremd);
        expect(id, '!neu:hs.example', reason: 'heute peerNotReachable');
        await Future<void>.delayed(_settle);
        final t = contacts(g).singleWhere((t) => t.id == id);
        expect(t.identity, IdentityStatus.changed, reason: 'gesperrte Geräte zeigen das Banner');
        await g.openThread(id);
        await noSend(g.sendMessage('Hallo', threadId: id));

        // Kein TOFU: eine Person ohne Sperre und ohne Pin bekommt beim bloßen Prüfen keinen Pin.
        final (hs2, g2) = await ready(policyOut);
        master(g2, _fremd, k1);
        armCreate(hs2, g2, room: '!neu2:hs.example');
        await g2.startContactChat(_fremd);
        master(g2, _fremd, k2);
        await settle(g2, dmJoined('!neu2:hs.example', _fremd));
        expect(contacts(g2).single.identity, IdentityStatus.pinned, reason: 'k2 ist der erste gesehene Schlüssel, k1 wurde nie gepinnt');

        // Nur gesperrte Geräte, kein Hauptschlüssel bekannt (Identität nicht berechenbar): die Sperre allein zählt.
        final (hs4, g4) = await ready(policyOut);
        g4.debugDevicesOf = (id) => <bool>[false];
        blockedDevice(g4, _fremd);
        expect(g4.debugIdentityChanged, isEmpty);
        armCreate(hs4, g4, room: '!neu4:hs.example');
        final id4 = await g4.startContactChat(_fremd);
        expect(id4, '!neu4:hs.example');
        await Future<void>.delayed(_settle);
        expect(contacts(g4).single.identity, IdentityStatus.changed, reason: 'Banner allein wegen gesperrter Geräte');
        // Nach dem Beitritt des Gegenübers (Raum mit Zeitleiste) sperrt allein die Gerätesperre das Senden.
        await settle(g4, dmJoined(id4, _fremd));
        await g4.openThread(id4);
        expect(g4.isThreadOpen(id4), isTrue);
        await noSend(g4.sendMessage('Hallo', threadId: id4));

        // Echtes notReachable (ohne Sperre) bleibt peerNotReachable.
        final (_, g3) = await ready(policyOut);
        g3.debugDevicesOf = (id) => <bool>[false];
        await expectLater(g3.startContactChat(_fremd), _error(GatewayError.peerNotReachable));
      });

      test('Zusatz: Bereich aus/an: Thread kehrt zurück, Akzeptieren möglich; aus: Wiederhinzufügen notAllowed; Familienmitglied nie Kontakt', () async {
        final (_, g) = await ready();
        await settle(g, dmJoined(ct, _fremd));
        master(g, _fremd, k1);
        await kick(g);
        master(g, _fremd, k2);
        await kick(g);
        expect(contacts(g).single.identity, IdentityStatus.changed);
        g.setContactPolicy(ContactPolicy.off);
        await Future<void>.delayed(_settle);
        expect(contacts(g), isEmpty);
        await expectLater(g.startContactChat(_fremd), _notAllowed());
        g.setContactPolicy(policy);
        await Future<void>.delayed(_settle);
        expect(contacts(g).single.identity, IdentityStatus.changed);
        await g.acceptIdentityChange(_fremd);
        await Future<void>.delayed(_settle);
        expect(contacts(g).single.identity, IdentityStatus.pinned);
        // Familienmitglied: nie Kontakt, auch nicht mit geändertem Schlüssel.
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: {_ben: ContactState.outgoing}));
        g.debugIdentityChanged.add(_ben);
        await expectLater(g.startContactChat(_ben), _notAllowed());
      });
    });

    group('8: Bereich aus (Gate und Abschalten ohne Familie)', () {
      for (final open in <bool>[false, true]) {
        test('Abschalten (Zeitleiste ${open ? 'offen' : 'nicht geöffnet'}): Threads, Anfragen, ${open ? 'Zeitleiste' : 'unreadCount'} und das Abo des privaten Raums sind sofort weg', () async {
          final (_, g) = await noFamily();
          final update = <String, Object?>{
            ...privateRoom(),
            'rooms': <String, Object?>{
              'join': <String, Object?>{
                ...(((privateRoom()['rooms']! as Map)['join']!) as Map<String, Object?>),
                ...(((withUnread(dmJoined(ct, _fremd), ct, 2)['rooms']! as Map)['join']!) as Map<String, Object?>),
              },
            },
            'account_data': <String, Object?>{
              'events': <Object?>[
                <String, Object?>{'type': 'de.inneso.familynexus.private_room', 'content': <String, Object?>{'room_id': priv}},
                <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_fremd: <String>[ct]}},
              ],
            },
          };
          await settle(g, update);
          await settle(g, dmInvite('!rq:hs.example', '@fremd2:hs.example'));
          if (open) await g.openThread(ct);
          expect(contacts(g), hasLength(1));
          expect(g.contactRequests, hasLength(1));
          expect(g.isThreadOpen(ct), open);
          if (!open) expect(g.unreadCount, 2);
          expect(g.debugPrivateTimeline, isNotNull);
          g.setContactPolicy(ContactPolicy.off);
          await Future<void>.delayed(_settle);
          expect(contacts(g), isEmpty);
          expect(g.contactRequests, isEmpty);
          expect(g.isThreadOpen(ct), isFalse, reason: 'Zeitleiste geschlossen');
          expect(g.unreadCount, 0, reason: 'keine Kontakt-Peers mehr');
          expect(g.debugPrivateTimeline, isNull, reason: 'kein Abo des privaten Raums ohne Familie und ohne Bereich');
        });
      }

      test('Gate: Bereich aus, Konto ohne Familie: kein Abo des privaten Raums, kein Kontaktsignal, keine Threads', () async {
        final (_, g) = await _signedIn(encryption: true, familySynced: false);
        await settle(g, <String, Object?>{
          ...privateRoom(),
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'de.inneso.familynexus.private_room', 'content': <String, Object?>{'room_id': priv}},
            ],
          },
        });
        await kick(g);
        expect(g.debugPrivateTimeline, isNull);
        expect(g.threads, isEmpty);
        expect(g.debugContactSignalHistoryLength, 0);
        expect(g.contactRequests, isEmpty);
      });
    });

    test('9: eigener Verlauf für Kontaktsignale: 5001 andere Signale verdrängen ein Kontaktsignal nicht; 2001 Kontaktsignale kappen das älteste; Reihenfolge je Verlauf bleibt', () async {
      final (_, g) = await _signedIn(encryption: true, familySynced: false);
      final c0 = ContactSignal(_me, DateTime.utc(2026), <String, Object?>{'i': 0});
      g.debugEmit(c0);
      for (var i = 0; i < 5001; i++) {
        g.debugEmit(PrivateEventSignal(_me, DateTime.utc(2026), <String, Object?>{'i': i}));
      }
      final late = <CalendarSignal>[];
      final sub = g.calendarSignals.listen(late.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(late.whereType<ContactSignal>().map((s) => s.content['i']), <Object?>[0], reason: 'nicht verdrängt');
      final others = late.whereType<PrivateEventSignal>().toList();
      expect(others, hasLength(5000), reason: 'übrige Signale: Kappung wie bisher, ältestes zuerst verdrängt');
      expect(others.first.content['i'], 1);
      expect(others.last.content['i'], 5000, reason: 'Reihenfolge je Verlauf bleibt');
      // 2001 Kontaktsignale: das älteste fehlt (Kappung der Ereignisse, ContactLimits.maxRecords).
      final (_, g2) = await _signedIn(encryption: true, familySynced: false);
      for (var i = 0; i < 2001; i++) {
        g2.debugEmit(ContactSignal(_me, DateTime.utc(2026), <String, Object?>{'i': i}));
      }
      expect(g2.debugContactSignalHistoryLength, ContactLimits.maxRecords);
      final late2 = <ContactSignal>[];
      final sub2 = g2.calendarSignals.listen((s) {
        if (s is ContactSignal) late2.add(s);
      });
      addTearDown(sub2.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(late2.first.content['i'], 1);
      expect(late2.last.content['i'], 2000);
    });
  });

  group('Einzelchat-Einstufung (#119, K2a)', () {
    const dm = '!dm:hs.example';

    Future<bool> shown(SdkMatrixGateway g, Map<String, Object?> update) async {
      await _sync(g, update);
      await Future<void>.delayed(_settle);
      return g.threads.any((t) => t.id == dm && t.kind == ThreadKind.direct);
    }

    test('Kontrollfall: beigetretener, verschlüsselter Raum mit m.direct, zwei Personen, Gegenüber beigetretenes Mitglied: Einzelchat', () async {
      final (_, g) = await _signedIn(encryption: true);
      expect(g.debugParticipantsLoaded, isTrue, reason: 'Voraussetzung: Mitgliederliste geladen');
      expect(await shown(g, dmJoined(dm, _ben)), isTrue);
    });

    test('ohne Verschlüsselung im Client wird kein Raum zum Einzelchat (Naht ausdrücklich aus)', () async {
      final (_, g) = await _signedIn(encryption: false);
      expect(await shown(g, dmJoined(dm, _ben)), isFalse);
    });

    test('Standard der Produktion (Gateway ohne die Naht): im Harness ohne vodozemac ist die Verschlüsselung nicht verfügbar, kein Einzelchat', () async {
      final (_, g) = await _signedIn(defaultEncryption: true);
      expect(await shown(g, dmJoined(dm, _ben)), isFalse);
    });

    test('Gegenproben: nie Einzelchat bei fehlendem m.direct, ohne Megolm, drei Personen, unbekannter Anzahl, Gegenüber kein oder nur eingeladenes Mitglied, Gegenüber = ich', () async {
      final cases = <String, Map<String, Object?>>{
        'kein m.direct': dmJoined(dm, _ben, direct: false),
        'ohne Megolm': dmJoined(dm, _ben, megolm: false),
        'drei Personen': dmJoined(dm, _ben, joined: 3, members: <String>[_me, _ben, _cara]),
        'zwei beigetreten und einer eingeladen': dmJoined(dm, _ben, invited: 1),
        'Gegenüber kein Mitglied der Familie': dmJoined(dm, _fremd),
        'Gegenüber nur eingeladen (Dora)': dmJoined(dm, _dora),
        'Gegenüber ich selbst': dmJoined(dm, _me, members: <String>[_me]),
      };
      for (final e in cases.entries) {
        final (_, g) = await _signedIn(encryption: true);
        expect(await shown(g, e.value), isFalse, reason: e.key);
      }
    });

    test('Familien- und privater Raum werden nie Einzelchat (Vorrang), auch wenn sie sonst alle Bedingungen erfüllen', () async {
      const priv = '!privat:hs.example';
      final (_, g) = await _signedIn(encryption: true);
      // Der Familienraum meldet zwei Personen (Paar) und steht in m.direct auf Ben: ohne Vorrang wäre er ein Einzelchat.
      await _sync(g, <String, Object?>{
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_ben: <String>[_familyRoom, priv]}},
            <String, Object?>{'type': 'de.inneso.familynexus.private_room', 'content': <String, Object?>{'room_id': priv}},
          ],
        },
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            _familyRoom: <String, Object?>{
              'summary': <String, Object?>{'m.joined_member_count': 2, 'm.invited_member_count': 0},
            },
            priv: <String, Object?>{
              'summary': <String, Object?>{'m.joined_member_count': 2, 'm.invited_member_count': 0},
              'state': <String, Object?>{
                'events': <Object?>[
                  _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
                  _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
                  _memberEvent(_me, 'join'),
                  _memberEvent(_ben, 'join'),
                ],
              },
            },
          },
        },
      });
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.direct), isEmpty);
      // Gegenprobe: derselbe private Raum ohne den Vermerk in den Kontodaten wäre ein Einzelchat.
      final (_, g2) = await _signedIn(encryption: true);
      await _sync(g2, <String, Object?>{
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_ben: <String>[priv]}},
          ],
        },
        'rooms': (dmJoined(priv, _ben)['rooms']! as Map<String, Object?>),
      });
      await Future<void>.delayed(_settle);
      expect(g2.threads.any((t) => t.id == priv && t.kind == ThreadKind.direct), isTrue);
    });

    test('bei mehreren Räumen mit demselben Gegenüber gilt der mit der kleinsten Raum-ID', () async {
      final (_, g) = await _signedIn(encryption: true);
      final a = dmJoined('!a-dm:hs.example', _ben);
      final b = dmJoined('!b-dm:hs.example', _ben);
      await _sync(g, <String, Object?>{
        'account_data': <String, Object?>{
          'events': <Object?>[
            <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_ben: <String>['!b-dm:hs.example', '!a-dm:hs.example']}},
          ],
        },
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            ...((a['rooms']! as Map)['join']! as Map<String, Object?>),
            ...((b['rooms']! as Map)['join']! as Map<String, Object?>),
          },
        },
      });
      await Future<void>.delayed(_settle);
      expect(g.threads.where((t) => t.kind == ThreadKind.direct).map((t) => t.id), <String>['!a-dm:hs.example']);
    });

    test('Einladung von einem Mitglied mit ungeklärter Identitätsänderung wird nicht angenommen', () async {
      final (hs, g) = await _signedIn(encryption: true);
      g.debugIdentityChanged.add(_ben);
      await _sync(g, dmInvite(dm, _ben));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isEmpty);
    });

    test('familyUnreadCount des Gateways gleich unreadCount (ohne Kontakte); lesbare Nachrichten lassen sich im Harness ohne Entschlüsselung nicht erzeugen, die Zahl ist hier 0', () async {
      final (_, g) = await _signedIn(encryption: true);
      await _sync(g, <String, Object?>{
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            _familyRoom: <String, Object?>{
              'unread_notifications': <String, Object?>{'notification_count': 2},
            },
          },
        },
      });
      await Future<void>.delayed(_settle);
      expect(g.familyUnreadCount, g.unreadCount);
    });

    test('Kontaktrichtlinie: Standard aus; Familien-Einzelchats bleiben unverändert (ab K3a-2 nimmt das Gateway Einladungen eigener Kontakte an)', () async {
      final (hs, g) = await _signedIn(encryption: true);
      expect(g.debugContactPolicy, ContactPolicy.off);
      g.setContactPolicy(const ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted}));
      expect(g.debugContactPolicy.enabled, isTrue);
      expect(await shown(g, dmJoined(dm, _ben)), isTrue, reason: 'Familien-Einzelchat unverändert');
      await _sync(g, dmInvite('!kontakt:hs.example', _fremd));
      await Future<void>.delayed(_settle);
      // Seit K3a-2: Einladung eines Kontakts mit Datensatz (accepted) wird über `autoAcceptContact` angenommen; der Raum
      // bleibt aber ohne beigetretenes Gegenüber im Raumzustand unsichtbar (kein Thread).
      expect(hs.where('POST', '/join'), isNotEmpty);
      expect(g.threads.where((t) => t.id == '!kontakt:hs.example'), isEmpty);
    });

    test('Kontaktrichtlinie fließt in den Kontext der Einstufung: Bereich, Kontakte, Blockierte, Familie in jedem Status', () async {
      final (_, g) = await _signedIn(encryption: true);
      final before = g.debugPolicyContext;
      expect(before, isNotNull, reason: 'Voraussetzung: Familie bekannt');
      expect(before!.contactsEnabled, isFalse);
      expect(before.contacts, isEmpty);
      expect(before.blockedUsers, isEmpty);
      g.setContactPolicy(const ContactPolicy(
        enabled: true,
        contacts: <String, ContactState>{_fremd: ContactState.accepted},
        blocked: <String>{'@x:hs.example'},
      ));
      final c = g.debugPolicyContext!;
      expect(c.contactsEnabled, isTrue);
      expect(c.contacts, <String, ContactState>{_fremd: ContactState.accepted});
      expect(c.blockedUsers, <String>{'@x:hs.example'});
      expect(c.familyIds, containsAll(<String>[_me, _cara, _ben, _dora]), reason: 'auch Eingeladene (Dora)');
      expect(c.joinedMembers, isNot(contains(_dora)), reason: 'beigetreten ist nur, wer beigetreten ist');
    });

    test('Kontaktrichtlinie: gleiche Richtlinie meldet nicht erneut, eine andere schon; nach dispose ohne Wirkung und ohne Wurf', () async {
      final (_, g) = await _signedIn(encryption: true);
      var calls = 0;
      g.addListener(() => calls++);
      const p = ContactPolicy(enabled: true);
      g.setContactPolicy(p);
      g.setContactPolicy(const ContactPolicy(enabled: true));
      expect(calls, 1);
      g.setContactPolicy(ContactPolicy.off);
      expect(calls, 2);
      g.dispose();
      expect(() => g.setContactPolicy(p), returnsNormally);
      expect(g.debugContactPolicy, ContactPolicy.off);
    });

    test('Kontaktrichtlinie: ein Familienwechsel lässt sie stehen, Abmelden setzt sie zurück (Kontakte gehören zum Konto)', () async {
      final (_, g) = await _signedIn(encryption: true);
      const p = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted});
      g.setContactPolicy(p);
      g.debugLeaveFamilyScope();
      expect(g.debugContactPolicy, p);
      await g.logout();
      expect(g.debugContactPolicy, ContactPolicy.off);
    });

    test('Einladung is_direct von einem beigetretenen Mitglied: wird angenommen (/join)', () async {
      final (hs, g) = await _signedIn(encryption: true);
      await _sync(g, dmInvite(dm, _ben));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isNotEmpty);
    });

    test('Einladung is_direct nie angenommen: Fremder, Nur-eingeladener, ich selbst, ohne is_direct', () async {
      for (final c in <(String, String, bool)>[('Fremder', _fremd, true), ('nur eingeladen', _dora, true), ('ich selbst', _me, true), ('ohne is_direct', _ben, false)]) {
        final (hs, g) = await _signedIn(encryption: true);
        await _sync(g, dmInvite(dm, c.$2, direct: c.$3));
        await Future<void>.delayed(_settle);
        expect(hs.where('POST', '/join'), isEmpty, reason: c.$1);
      }
    });

    test('Einladung is_direct bei unvollständiger Mitgliederliste: keine Annahme (B6)', () async {
      final (hs, g) = await _signedIn(encryption: true, familyMembersFail: true);
      expect(g.debugParticipantsLoaded, isFalse);
      await _sync(g, dmInvite(dm, _ben));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isEmpty);
    });

    test('Einladung ohne is_direct von einem Mitglied erscheint nicht als Familieneinladung, solange Familie bekannt ist (kein Beitritt)', () async {
      final (hs, g) = await _signedIn(encryption: true);
      await _sync(g, dmInvite(dm, _ben, direct: false));
      await Future<void>.delayed(_settle);
      expect(hs.where('POST', '/join'), isEmpty);
    });
  });

  group('Datenübersicht: Raumart (Teil 4b)', () {
    test('ein Buch-Raum ist ein Kassenbuch, ein Raum ohne Kennzeichen „sonstiger Raum“, der Familienraum bleibt Familie; unabhängig vom Schalter', () async {
      for (final enabled in <bool>[true, false]) {
        final (_, g) = await _signedIn(enabled: enabled);
        await _sync(g, _bookJoin(_book, members: <String>[_cara]));
        await _sync(g, _bookJoin('!ohne:hs.example', marker: false));
        await Future<void>.delayed(_settle);
        final inv = await g.dataInventory(refresh: false);
        final kinds = <String, InventoryRoomKind>{for (final r in inv.rooms) r.id: r.kind};
        expect(kinds[_book], InventoryRoomKind.book, reason: 'enabled=$enabled');
        expect(kinds['!ohne:hs.example'], InventoryRoomKind.other, reason: 'enabled=$enabled');
        expect(kinds[_familyRoom], InventoryRoomKind.family, reason: 'enabled=$enabled');
      }
    });
  });

  group('bookMembers und staleBooks (Teil 4)', () {
    test('bookMembers: beigetretene und eingeladene, frisch vom Server; leave und ban nicht', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.members = <String>[_me, _cara];
      hs.left = <String>{_ben};
      hs.extra[_dora] = 'invite';
      hs.extra[_fremd] = 'ban';
      final m = await g.bookMembers(_book);
      expect(<String, BookMembership>{for (final x in m) x.userId: x.membership}, <String, BookMembership>{
        _me: BookMembership.joined,
        _cara: BookMembership.joined,
        _dora: BookMembership.invited,
      });
    });

    test('bookMembers: leere Antwort fail-closed; Buch einer anderen Familie notAllowed; gesperrt notAllowed ohne Anfrage', () async {
      final (hs, g) = await _signedIn();
      await _sync(g, _bookJoin(_book, members: <String>[_cara]));
      hs.emptyMembers = true;
      await expectLater(g.bookMembers(_book), _error(GatewayError.serverUnreachable));
      await _sync(g, _bookJoin('!anderes:hs.example', family: '!andere:hs.example'));
      hs.emptyMembers = false;
      hs.members = <String>[_me];
      await expectLater(g.bookMembers('!anderes:hs.example'), _notAllowed());
      final (hs2, g2) = await _signedIn(enabled: false);
      final before = hs2.calls.length;
      await expectLater(g2.bookMembers(_book), _notAllowed());
      expect(hs2.calls.length, before);
    });

    test('staleBooks: beigetretenes Buch einer anderen Familie ja; das der aktuellen und ein Raum ohne Buch-Kennzeichen nie', () async {
      final (hs, g) = await _signedIn();
      hs.members = <String>[_me];
      await _syncJoined(g, _bookJoin(_book, members: <String>[_cara]));
      await _sync(g, _bookJoin('!alt:hs.example', family: '!andere:hs.example'));
      await _sync(g, _bookJoin('!ohne:hs.example', marker: false));
      await Future<void>.delayed(_settle);
      expect(g.staleBooks, <String>['!alt:hs.example']);
    });

    test('staleBooks: eingeladen (nicht beigetreten) und verlassen zählen nicht', () async {
      final (hs, g) = await _signedIn();
      hs.members = <String>[_me];
      await _syncJoined(g, <String, Object?>{'rooms': <String, Object?>{'join': <String, Object?>{}}});
      await _sync(g, <String, Object?>{
        'rooms': <String, Object?>{
          'invite': <String, Object?>{
            '!eingeladen:hs.example': <String, Object?>{
              'invite_state': <String, Object?>{
                'events': <Object?>[
                  <String, Object?>{
                    'type': 'm.room.create',
                    'state_key': '',
                    'sender': _cara,
                    'content': <String, Object?>{'room_version': '10', ...BookRoomMarker.cashCreationContent('!andere:hs.example')},
                  },
                ],
              },
            },
          },
        },
      });
      expect(g.staleBooks, isEmpty);
    });

    test('staleBooks: ein Buch-Raum ohne Familienvermerk gilt nie als alt (nie verlassen)', () async {
      final (hs, g) = await _signedIn();
      hs.members = <String>[_me];
      await _sync(g, <String, Object?>{
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            '!ohnefamilie:hs.example': <String, Object?>{
              'state': <String, Object?>{
                'events': <Object?>[
                  _state('m.room.create', _cara, <String, Object?>{'room_version': '10', BookRoomMarker.bookKey: BookRoomMarker.cashKind}),
                  _memberEvent(_me, 'join'),
                ],
              },
            },
          },
        },
      });
      await _syncJoined(g, <String, Object?>{'rooms': <String, Object?>{}});
      await Future<void>.delayed(_settle);
      expect(g.staleBooks, isEmpty);
    });

    test('staleBooks ist leer, solange die Mitgliederliste der Familie nicht geladen ist', () async {
      final (_, g) = await _signedIn(familyMembersFail: true);
      await _sync(g, _bookJoin('!alt:hs.example', family: '!andere:hs.example'));
      await Future<void>.delayed(_settle);
      expect(g.debugParticipantsLoaded, isFalse, reason: 'Voraussetzung des Tests');
      expect(g.staleBooks, isEmpty);
    });

    test('staleBooks ist leer: gesperrt, ohne bekannte Familie, ohne ersten Sync', () async {
      final (_, locked) = await _signedIn(enabled: false);
      await _sync(locked, _bookJoin('!alt:hs.example', family: '!andere:hs.example'));
      expect(locked.staleBooks, isEmpty);
      final (_, noFamily) = await _signedIn(familySynced: false);
      await _sync(noFamily, _bookJoin('!alt:hs.example', family: '!andere:hs.example'));
      expect(noFamily.staleBooks, isEmpty);
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

  // ---- #119, K4-2a: Gruppen im echten Gateway (Lesen, Anfragen, Anlegen, Beitritt, Verlassen; Senden gesperrt) ----
  group('Gruppen (#119, K4-2a)', () {
    const gr = '!gr:hs.example';
    const anna = '@anna:hs.example';
    const rec = ContactPolicy(enabled: true, groups: <String>{gr});
    const recAccepted = ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted}, groups: <String>{gr});
    const nobody = ContactPolicy(enabled: true);

    Future<(_Hs, SdkMatrixGateway)> signedIn([ContactPolicy p = rec, bool familySynced = true]) async {
      final (hs, g) = await _signedIn(encryption: true, familySynced: familySynced);
      g.setContactPolicy(p);
      g.debugDevicesOf = (id) => <bool>[true];
      return (hs, g);
    }

    /// Beigetretene Gruppe: Zähler und Zustand einzeln steuerbar (`null` lässt die Angabe weg).
    Map<String, Object?> groupJoined(
      String room, {
      String name = 'Skatrunde',
      bool megolm = true,
      int? joined,
      int? invited = 0,
      String? rule = 'invite',
      String? history = 'invited',
      List<String>? members,
      bool direct = false,
      int? unread,
      int memberEvents = -1,
    }) {
      final all = members ?? <String>[_me, _fremd, anna];
      final shown = memberEvents < 0 ? all : all.take(memberEvents).toList();
      final j = joined ?? all.length;
      return <String, Object?>{
        if (direct)
          'account_data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{'type': 'm.direct', 'content': <String, Object?>{_fremd: <String>[room]}},
            ],
          },
        'rooms': <String, Object?>{
          'join': <String, Object?>{
            room: <String, Object?>{
              'summary': <String, Object?>{
                'm.joined_member_count': j,
                'm.invited_member_count': ?invited,
              },
              if (unread != null) 'unread_notifications': <String, Object?>{'notification_count': unread, 'highlight_count': 0},
              'state': <String, Object?>{
                'events': <Object?>[
                  _state('m.room.create', _me, <String, Object?>{'room_version': '10'}),
                  if (megolm) _state('m.room.encryption', _me, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
                  _state('m.room.name', _me, <String, Object?>{'name': name}),
                  if (rule != null) _state('m.room.join_rules', _me, <String, Object?>{'join_rule': rule}),
                  if (history != null) _state('m.room.history_visibility', _me, <String, Object?>{'history_visibility': history}),
                  _state('m.room.power_levels', _me, <String, Object?>{'users': <String, int>{_me: 100}, 'users_default': 0, 'state_default': 50, 'invite': 50, 'kick': 50}),
                  for (final m in shown) _memberEvent(m, 'join'),
                ],
              },
            },
          },
        },
      };
    }

    /// Gruppen mit unbekannter Beitrittszahl: der Zähler fehlt im `summary`.
    Map<String, Object?> groupUnknownSize(String room) {
      final u = groupJoined(room);
      ((((u['rooms']! as Map)['join']! as Map)[room]! as Map)['summary']! as Map).remove('m.joined_member_count');
      return u;
    }

    Map<String, Object?> groupInvite(String room, String from, {String name = 'Skatrunde', String? rule = 'invite', bool direct = false}) => <String, Object?>{
          'rooms': <String, Object?>{
            'invite': <String, Object?>{
              room: <String, Object?>{
                'invite_state': <String, Object?>{
                  'events': <Object?>[
                    <String, Object?>{
                      'type': 'm.room.member',
                      'state_key': _me,
                      'sender': from,
                      'content': <String, Object?>{'membership': 'invite', if (direct) 'is_direct': true},
                    },
                    if (rule != null) <String, Object?>{'type': 'm.room.join_rules', 'state_key': '', 'sender': from, 'content': <String, Object?>{'join_rule': rule}},
                    <String, Object?>{'type': 'm.room.name', 'state_key': '', 'sender': from, 'content': <String, Object?>{'name': name}},
                  ],
                },
              },
            },
          },
        };

    Map<String, Object?> merge(List<Map<String, Object?>> updates) {
      final out = <String, Object?>{'rooms': <String, Object?>{'invite': <String, Object?>{}, 'join': <String, Object?>{}}};
      final rooms = out['rooms']! as Map<String, Object?>;
      for (final u in updates) {
        final r = (u['rooms'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
        for (final k in <String>['invite', 'join']) {
          (rooms[k]! as Map<String, Object?>).addAll((r[k] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{});
        }
      }
      return out;
    }

    Future<void> settle(SdkMatrixGateway g, Map<String, Object?> update) async {
      await _sync(g, update);
      await Future<void>.delayed(_settle);
    }

    Future<ChatThread?> groupThread(SdkMatrixGateway g, Map<String, Object?> update, [String room = gr]) async {
      await settle(g, update);
      return g.threads.where((t) => t.id == room && t.kind == ThreadKind.group).firstOrNull;
    }

    int membersCalls(_Hs hs, [String room = gr]) => hs.where('GET', '$room/members').length;

    /// Der Server liefert den Zustand des Raums wie `ContactGroupSpec` ihn verlangt (Nachprüfung nach dem Beitritt).
    void serveGroup(_Hs hs, String room, {String? rule = 'invite', String? history = 'invited'}) {
      if (rule != null) hs.serverState['$room|m.room.join_rules'] = <String, Object?>{'join_rule': rule};
      if (history != null) hs.serverState['$room|m.room.history_visibility'] = <String, Object?>{'history_visibility': history};
    }

    group('Einstufung und Anzeige', () {
      test('Kontrollfall: Datensatz, beigetreten, Megolm ⇒ Gruppen-Thread (Titel, Mitglieder, Rechte, keine Sperre, nie ein Einzelchat)', () async {
        final (_, g) = await signedIn();
        final t = await groupThread(g, groupJoined(gr));
        expect(t, isNotNull);
        expect(t!.title, 'Skatrunde');
        expect(t.peerId, isNull);
        expect(t.isOutside, isTrue);
        expect(t.isFamily, isFalse);
        expect(t.memberCount, 3);
        expect(t.canManage, isTrue, reason: 'ich bin Ersteller (100)');
        expect(t.sendLock, GroupSendLock.keiner);
        expect(g.threads.where((x) => x.kind == ThreadKind.contact), isEmpty);
        expect(g.debugGroups, <String, String>{gr: 'Skatrunde'});
      });

      test('Gegenproben je einzeln: ohne Datensatz, Bereich aus, Liste unvollständig, bewusst verlassen ⇒ kein Gruppen-Thread', () async {
        for (final p in <ContactPolicy>[nobody, const ContactPolicy(groups: <String>{gr}), ContactPolicy.off]) {
          final (_, g) = await signedIn(p);
          expect(await groupThread(g, groupJoined(gr)), isNull, reason: '$p');
        }
        final (_, g2) = await _signedIn(encryption: true, familyMembersFail: true);
        g2.setContactPolicy(rec);
        expect(await groupThread(g2, groupJoined(gr)), isNull, reason: 'Mitgliederliste der Familie unvollständig');
        final (hs3, g3) = await signedIn();
        expect(await groupThread(g3, groupJoined(gr)), isNotNull);
        await g3.leaveConversation(gr);
        expect(hs3.where('POST', '$gr/leave'), isNotEmpty);
        await settle(g3, groupJoined(gr));
        expect(g3.threads.where((t) => t.kind == ThreadKind.group), isEmpty, reason: 'bewusst verlassene Räume nie wieder zeigen');
      });

      test('die Einstufung ist von Größe, Regel, Verlauf und Verschlüsselung unabhängig: sichtbar, mit Sperrgrund (nie unsichtbar)', () async {
        final cases = <String, (Map<String, Object?>, GroupSendLock)>{
          'zu groß (51)': (groupJoined(gr, joined: 51), GroupSendLock.zuGross),
          '40 beigetreten + 30 eingeladen (G = 70)': (groupJoined(gr, joined: 40, invited: 30), GroupSendLock.zuGross),
          '10 000 beigetreten': (groupJoined(gr, joined: 10000), GroupSendLock.zuGross),
          'Größe unbekannt': (groupUnknownSize(gr), GroupSendLock.groesseUnbekannt),
          'unverschlüsselt': (groupJoined(gr, megolm: false), GroupSendLock.unverschluesselt),
          'Regel public': (groupJoined(gr, rule: 'public'), GroupSendLock.regelGeaendert),
          'Regel fehlt': (groupJoined(gr, rule: null), GroupSendLock.regelGeaendert),
          'Verlauf shared': (groupJoined(gr, history: 'shared'), GroupSendLock.verlaufGeoeffnet),
          'Verlauf fehlt (unbekannt zählt als geöffnet)': (groupJoined(gr, history: null), GroupSendLock.verlaufGeoeffnet),
        };
        for (final e in cases.entries) {
          final (_, g) = await signedIn();
          final t = await groupThread(g, e.value.$1);
          expect(t, isNotNull, reason: e.key);
          expect(t!.sendLock, e.value.$2, reason: e.key);
        }
      });

      test('ein Gruppen-Datensatz gewinnt gegen m.direct: Gruppe, nie Kontakt-Einzelchat; verlassen als Gruppe, ohne m.direct anzufassen', () async {
        final (hs, g) = await signedIn(recAccepted);
        final t = await groupThread(g, groupJoined(gr, direct: true, members: <String>[_me, _fremd], joined: 2));
        expect(t, isNotNull);
        expect(g.threads.where((x) => x.kind == ThreadKind.contact), isEmpty);
        await g.leaveConversation(gr);
        expect(hs.where('POST', '$gr/leave'), isNotEmpty);
        expect(hs.where('PUT', 'account_data/m.direct'), isEmpty, reason: 'kein removeFromDirectChat für Gruppen');
      });

      test('Raum war erst Kontakt-Einzelchat und bekommt dann einen Gruppen-Datensatz: der Einzelchat-Thread verschwindet, die Gruppe erscheint', () async {
        final (_, g) = await signedIn(const ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted}));
        final u = groupJoined(gr, direct: true, members: <String>[_me, _fremd], joined: 2);
        await settle(g, u);
        expect(g.threads.where((x) => x.id == gr).map((x) => x.kind), <ThreadKind>[ThreadKind.contact]);
        g.setContactPolicy(recAccepted);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((x) => x.id == gr).map((x) => x.kind), <ThreadKind>[ThreadKind.group]);
      });

      test('Bereich aus oder Datensatz entfällt mitten in der Sitzung: die Gruppe verschwindet ohne weiteren Sync', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        g.setContactPolicy(nobody);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.group), isEmpty);
        g.setContactPolicy(rec);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.group), hasLength(1));
        g.setContactPolicy(ContactPolicy.off);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.group), isEmpty);
        expect(g.debugGroups, isEmpty);
      });

      test('Familienwechsel räumt die Gruppen, die Richtlinie bleibt (Zustand und Epoche)', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        await g.openThread(gr);
        expect(g.debugGroupTimelines, <String>{gr});
        g.debugLeaveFamilyScope();
        expect(g.debugContactPolicy, rec);
        expect(g.threads.where((t) => t.kind == ThreadKind.group), isEmpty);
        expect(g.debugGroups, isEmpty);
        expect(g.debugGroupTimelines, isEmpty);
      });

      test('Abmelden räumt alle Gruppen und erhöht die Kontakt-Epoche', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        final epoch = g.debugContactEpoch;
        await g.logout();
        expect(g.debugGroups, isEmpty);
        expect(g.debugGroupTimelines, isEmpty);
        expect(g.debugContactEpoch, greaterThan(epoch));
      });

      test('Gruppen-Threads sind sortiert, melden Ausgelassene aus bekannten Schlüsseln und das Gateway liest dafür nie das Netz', () async {
        final (hs, g) = await signedIn();
        g.debugDevicesOf = (id) => id == _fremd ? <bool>[false] : <bool>[true];
        final t = await groupThread(g, groupJoined(gr));
        expect(t!.unreachableCount, 1);
        expect(t.identityChangedCount, 0);
        expect(hs.where('POST', '/keys/query').where((c) => c.$3.contains(_fremd)), isEmpty);
      });

      test('PolicyContext trägt die Gruppen (mit Familie), bei Bereich aus ändert sich nichts am Verhalten (enabled == false)', () async {
        final (_, g) = await signedIn();
        expect(g.debugPolicyContext!.groups, <String>{gr});
        final (_, off) = await signedIn(const ContactPolicy(groups: <String>{gr}));
        expect(await groupThread(off, groupJoined(gr)), isNull);
        expect(off.contactRequests, isEmpty);
        expect(off.threads.where((t) => t.kind == ThreadKind.family), hasLength(1), reason: 'Familie unverändert');
        expect(off.unreadCount, 0);
      });

      test('Datenübersicht: Raumart „Gruppe“, auch gegen m.direct; ohne Datensatz „sonstiger Raum“', () async {
        final (_, g) = await signedIn(recAccepted);
        await settle(g, groupJoined(gr, direct: true, members: <String>[_me, _fremd], joined: 2));
        var inv = await g.dataInventory(refresh: false);
        expect({for (final r in inv.rooms) r.id: r.kind}[gr], InventoryRoomKind.group);
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.accepted}));
        await Future<void>.delayed(_settle);
        inv = await g.dataInventory(refresh: false);
        expect({for (final r in inv.rooms) r.id: r.kind}[gr], isNot(InventoryRoomKind.group));
      });

      test('importantStateEvents enthält Regel und Verlauf; der Verlauf bleibt nach einem Neustart im Raumzustand', () async {
        final (_, g) = await signedIn();
        final important = g.sdkClient!.importantStateEvents;
        expect(important, contains('m.room.join_rules'));
        expect(important, contains('m.room.history_visibility'));
        await _sync(g, groupJoined(gr, history: 'invited'));
        await Future<void>.delayed(_settle);
        final dir = _lastDir!;
        await g.close();
        final hs2 = _Hs();
        final g2 = await _restarted(hs2, dir);
        final room = g2.sdkClient!.getRoomById(gr);
        expect(room, isNotNull);
        expect(room!.getState('m.room.history_visibility')?.content['history_visibility'], 'invited');
        expect(room.getState('m.room.join_rules')?.content['join_rule'], 'invite');
      });

      test('unreadCount zählt Gruppen, familyUnreadCount nie (B7)', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr, unread: 4)), isNotNull);
        expect(g.unreadCount, 4);
        expect(g.familyUnreadCount, 0);
        expect(g.threads.firstWhere((t) => t.kind == ThreadKind.group).unread, 4);
      });
    });

    group('Anfragen', () {
      test('Gruppenanfrage: Gruppenname, Einladender, inviterIsFamily nach Familie; kein Auto-Beitritt, kein Rauminhalt, nie in invitations', () async {
        final (hs, g) = await signedIn(nobody);
        await settle(g, merge(<Map<String, Object?>>[
          groupInvite('!g1:hs.example', _fremd, name: 'Skat'),
          groupInvite('!g2:hs.example', _cara, name: 'Familienausflug'),
        ]));
        final byRoom = {for (final r in g.contactRequests) r.roomId: r};
        expect(byRoom.keys, containsAll(<String>['!g1:hs.example', '!g2:hs.example']));
        expect(byRoom['!g1:hs.example']!.isGroup, isTrue);
        expect(byRoom['!g1:hs.example']!.groupName, 'Skat');
        expect(byRoom['!g1:hs.example']!.fromUserId, _fremd);
        expect(byRoom['!g1:hs.example']!.inviterIsFamily, isFalse);
        expect(byRoom['!g2:hs.example']!.inviterIsFamily, isTrue, reason: 'Cara ist Familienmitglied (D5: erlaubt, nur Anzeige)');
        expect(hs.where('POST', '/join'), isEmpty, reason: 'Gruppen werden nie automatisch angenommen (D1)');
        expect(g.threads.where((t) => t.kind != ThreadKind.family), isEmpty);
        expect(g.invitations, isEmpty, reason: 'nie als Familieneinladung');
        expect(g.debugGroupTimelines, isEmpty);
      });

      test('ohne geladene Familie ist inviterIsFamily false, auch für eine Kennung, die später Familie würde', () async {
        final (_, g) = await signedIn(nobody, false);
        expect(g.family, isNull);
        await settle(g, groupInvite('!g1:hs.example', _cara));
        expect(g.contactRequests.single.inviterIsFamily, isFalse);
      });

      test('ein eigener Kontakt lädt in eine Gruppe ein: Anfrage, nie automatisch angenommen', () async {
        final (hs, g) = await signedIn(recAccepted);
        await settle(g, groupInvite('!g1:hs.example', _fremd));
        expect(g.contactRequests.map((r) => r.roomId), <String>['!g1:hs.example']);
        expect(hs.where('POST', '/join'), isEmpty);
      });

      test('Gegenproben: Bereich aus, Einladender blockiert, Regel knock/null/public ⇒ keine Gruppenanfrage', () async {
        final (_, off) = await signedIn(ContactPolicy.off);
        await settle(off, groupInvite('!g1:hs.example', _fremd));
        expect(off.contactRequests, isEmpty);
        final (_, blocked) = await signedIn(const ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.blocked}, blocked: <String>{_fremd}));
        await settle(blocked, groupInvite('!g1:hs.example', _fremd));
        expect(blocked.contactRequests, isEmpty);
        for (final rule in <String?>['knock', null, 'public']) {
          final (_, g) = await signedIn(nobody);
          await settle(g, groupInvite('!g1:hs.example', _fremd, rule: rule));
          expect(g.contactRequests, isEmpty, reason: '$rule');
        }
      });

      test('Ablehnen verlässt die Einladung; danach keine Anfrage mehr, ein zweites Ablehnen ist notAllowed', () async {
        final (hs, g) = await signedIn(nobody);
        await settle(g, groupInvite('!g1:hs.example', _fremd));
        await g.declineContactRequest('!g1:hs.example');
        expect(hs.where('POST', '!g1:hs.example/leave'), isNotEmpty);
        await expectLater(g.declineContactRequest('!g1:hs.example'), _notAllowed());
        await Future<void>.delayed(_settle);
        expect(g.contactRequests, isEmpty);
      });

      test('Grenzen: je Raum eine, je Einladendem höchstens 3 (Rest „weitere“), je Server höchstens 5, gesamt 50', () async {
        final (_, g) = await signedIn(nobody);
        await settle(g, merge(<Map<String, Object?>>[for (var i = 0; i < 5; i++) groupInvite('!a$i:hs.example', '@e1:srv1.example')]));
        expect(g.contactRequests, hasLength(3), reason: 'je Einladendem höchstens 3');
        expect(g.contactRequestsHidden, 2);
        final (_, g2) = await signedIn(nobody);
        await settle(g2, merge(<Map<String, Object?>>[for (var i = 0; i < 7; i++) groupInvite('!b$i:hs.example', '@u$i:srv2.example')]));
        expect(g2.contactRequests, hasLength(5), reason: 'je Server höchstens 5');
        expect(g2.contactRequestsHidden, 2);
        final (_, g3) = await signedIn(nobody);
        await settle(g3, merge(<Map<String, Object?>>[for (var i = 0; i < 60; i++) groupInvite('!c${i.toString().padLeft(3, '0')}:hs.example', '@u$i:s$i.example')]));
        expect(g3.contactRequests, hasLength(50), reason: 'gesamt 50');
        expect(g3.contactRequestsHidden, 10);
      });

      test('Einzelchat-Anfrage und Gruppenanfragen desselben Absenders verdrängen sich nicht', () async {
        final (_, g) = await signedIn(nobody);
        final dm = <String, Object?>{
          'rooms': <String, Object?>{
            'invite': <String, Object?>{
              '!dm:hs.example': <String, Object?>{
                'invite_state': <String, Object?>{
                  'events': <Object?>[
                    <String, Object?>{'type': 'm.room.member', 'state_key': _me, 'sender': _fremd, 'content': <String, Object?>{'membership': 'invite', 'is_direct': true}},
                  ],
                },
              },
            },
          },
        };
        await settle(g, merge(<Map<String, Object?>>[dm, groupInvite('!g1:hs.example', _fremd), groupInvite('!g2:hs.example', _fremd)]));
        expect(g.contactRequests.map((r) => r.roomId).toSet(), <String>{'!dm:hs.example', '!g1:hs.example', '!g2:hs.example'});
        expect(g.contactRequests.where((r) => r.isGroup), hasLength(2));
        expect(g.contactRequests.where((r) => !r.isGroup).single.groupName, isNull);
      });

      test('Abnahme 9: Gruppeneinladung (invite) nie in invitations, nie als Familie annehmbar; knock bleibt Familieneinladung; null bleibt familyInvite', () async {
        // (1) invite: nie in invitations (mit und ohne Bereich), acceptInvitation ⇒ notAllowed.
        for (final p in <ContactPolicy>[nobody, ContactPolicy.off]) {
          final (hs, g) = await signedIn(p);
          await settle(g, groupInvite('!g1:hs.example', _cara));
          expect(g.invitations, isEmpty, reason: '$p');
          hs.serverState['!g1:hs.example|m.room.join_rules'] = <String, Object?>{'join_rule': 'invite'};
          await expectLater(g.acceptInvitation('!g1:hs.example'), _notAllowed());
          expect(hs.where('POST', '/join'), isEmpty);
        }
        // (2) knock: erscheint nie als Gruppenanfrage, bleibt Familieneinladung.
        final (_, k) = await signedIn(nobody, false);
        await settle(k, groupInvite('!k1:hs.example', _fremd, rule: 'knock'));
        expect(k.contactRequests, isEmpty);
        expect(k.invitations.map((i) => i.roomId), <String>['!k1:hs.example']);
        // (3) null (mit und ohne Familie): familyInvite, nicht in contactRequests; die Annahme prüft den Server (invite ⇒ notAllowed).
        for (final withFamily in <bool>[true, false]) {
          final (hs, g) = await signedIn(nobody, withFamily);
          await settle(g, groupInvite('!n1:hs.example', _fremd, rule: null));
          expect(g.contactRequests, isEmpty, reason: 'null, Familie $withFamily');
          if (!withFamily) {
            expect(g.invitations.map((i) => i.roomId), <String>['!n1:hs.example']);
            hs.serverState['!n1:hs.example|m.room.join_rules'] = <String, Object?>{'join_rule': 'invite'};
            hs.onJoin = (r) => Future<void>.delayed(const Duration(milliseconds: 100), () => _syncJoined(g, groupJoined(r))).ignore();
            await expectLater(g.acceptInvitation('!n1:hs.example'), _notAllowed());
            expect(hs.where('POST', '!n1:hs.example/leave'), isNotEmpty, reason: 'nach dem Beitritt vom Server geprüft, verlassen');
          }
        }
      });

      test('Gruppeneinladung ist nie eine Familien- oder Direktkontakt-Einladung: kein /join, kein Einzelchat-Thread, Gruppen im PolicyContext (Lücke L3)', () async {
        final (hs, g) = await signedIn(const ContactPolicy(enabled: true, contacts: <String, ContactState>{_cara: ContactState.accepted}, groups: <String>{'!g1:hs.example'}));
        await settle(g, groupInvite('!g1:hs.example', _cara));
        expect(hs.where('POST', '/join'), isEmpty);
        expect(g.threads.where((t) => t.kind == ThreadKind.direct || t.kind == ThreadKind.contact), isEmpty);
        expect(g.contactRequests.single.inviterIsFamily, isTrue, reason: 'Absturzfall D2: Datensatz da, Einladung offen ⇒ bleibt Anfrage');
        expect(g.debugPolicyContext!.groups, <String>{'!g1:hs.example'});
      });
    });

    group('acceptGroupInvite', () {
      Future<(_Hs, SdkMatrixGateway)> invited({Map<String, Object?>? joinedState, String? rule = 'invite', String? history = 'invited', ContactPolicy p = rec}) async {
        final (hs, g) = await signedIn(p);
        await settle(g, groupInvite(gr, _fremd));
        serveGroup(hs, gr, rule: rule, history: history);
        hs.onJoin = (r) => Future<void>.delayed(const Duration(milliseconds: 100), () => _syncJoined(g, joinedState ?? groupJoined(gr))).ignore();
        return (hs, g);
      }

      bool wroteFamilyPointer(_Hs hs) => hs.calls.any((c) => c.$1 == 'PUT' && c.$2.contains('account_data') && c.$2.contains('de.inneso.familynexus.family'));

      test('Erfolg: Beitritt, Nachprüfung vom Server, Gruppe sichtbar; schreibt nie familyAccountData und keinen Datensatz', () async {
        final (hs, g) = await invited();
        await g.acceptGroupInvite(gr);
        expect(hs.where('POST', '$gr/join'), hasLength(1));
        expect(hs.where('POST', '$gr/leave'), isEmpty);
        expect(wroteFamilyPointer(hs), isFalse);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.group).map((t) => t.id), <String>[gr]);
        expect(g.contactRequests, isEmpty);
        await g.acceptGroupInvite(gr); // idempotent (erneuter Tipp)
        expect(hs.where('POST', '$gr/join'), hasLength(1));
      });

      test('Nachprüfung: Verstoß ⇒ Raum sofort verlassen und notAllowed, je Fall einzeln', () async {
        final cases = <String, ({Map<String, Object?> joined, String? rule, String? history})>{
          'unverschlüsselt': (joined: groupJoined(gr, megolm: false), rule: 'invite', history: 'invited'),
          'Regel knock': (joined: groupJoined(gr), rule: 'knock', history: 'invited'),
          'Regel nicht abrufbar': (joined: groupJoined(gr), rule: null, history: 'invited'),
          'Verlauf shared': (joined: groupJoined(gr), rule: 'invite', history: 'shared'),
          'Verlauf nicht abrufbar': (joined: groupJoined(gr), rule: 'invite', history: null),
          'bekannt 51': (joined: groupJoined(gr, joined: 51), rule: 'invite', history: 'invited'),
          '40 + 30 eingeladen': (joined: groupJoined(gr, joined: 40, invited: 30), rule: 'invite', history: 'invited'),
        };
        for (final e in cases.entries) {
          final (hs, g) = await invited(joinedState: e.value.joined, rule: e.value.rule, history: e.value.history);
          await expectLater(g.acceptGroupInvite(gr), _notAllowed(), reason: e.key);
          expect(hs.where('POST', '$gr/leave'), isNotEmpty, reason: e.key);
          await Future<void>.delayed(_settle);
          expect(g.threads.where((t) => t.kind == ThreadKind.group), isEmpty, reason: e.key);
          expect(wroteFamilyPointer(hs), isFalse, reason: e.key);
        }
      });

      test('unbekannte Beitrittszahl: nicht verlassen, Gruppe sichtbar und sendegesperrt (nicht unsichtbar)', () async {
        final (hs, g) = await invited(joinedState: groupUnknownSize(gr));
        await g.acceptGroupInvite(gr);
        expect(hs.where('POST', '$gr/leave'), isEmpty);
        await Future<void>.delayed(_settle);
        final t = g.threads.where((x) => x.kind == ThreadKind.group).single;
        expect(t.sendLock, GroupSendLock.groesseUnbekannt);
      });

      test('Vorbedingungen: Einzelchat-Einladung, keine Einladung, ungültige ID, Bereich aus, Blockierter, Regel nicht invite ⇒ kein /join', () async {
        final (hs, g) = await signedIn(nobody);
        await settle(g, groupInvite('!dm:hs.example', _fremd, direct: true));
        await expectLater(g.acceptGroupInvite('!dm:hs.example'), _notAllowed(), reason: 'Einzelchat-Einladung');
        await expectLater(g.acceptGroupInvite('!gibtsnicht:hs.example'), _error(GatewayError.notFound));
        await expectLater(g.acceptGroupInvite('kein-raum'), _error(GatewayError.invalidInput));
        await settle(g, groupInvite('!kn:hs.example', _fremd, rule: 'knock'));
        await expectLater(g.acceptGroupInvite('!kn:hs.example'), _notAllowed(), reason: 'knock ist keine Gruppenanfrage');
        g.setContactPolicy(const ContactPolicy(enabled: true, contacts: <String, ContactState>{_fremd: ContactState.blocked}, blocked: <String>{_fremd}));
        await settle(g, groupInvite('!bl:hs.example', _fremd));
        await expectLater(g.acceptGroupInvite('!bl:hs.example'), _notAllowed(), reason: 'blockierter Einladender');
        g.setContactPolicy(ContactPolicy.off);
        await settle(g, groupInvite('!off:hs.example', anna));
        await expectLater(g.acceptGroupInvite('!off:hs.example'), _notAllowed(), reason: 'Bereich aus');
        expect(hs.where('POST', '/join'), isEmpty);
      });

      test('zweiter gleichzeitiger Tipp für dieselbe Gruppe: alreadyExists; mehr als 4 gleichzeitige Beitritte: rateLimited', () async {
        final (hs, g) = await invited();
        final first = g.acceptGroupInvite(gr);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await expectLater(g.acceptGroupInvite(gr), _error(GatewayError.alreadyExists));
        await first;
        expect(hs.where('POST', '$gr/join'), hasLength(1));

        final ids = <String>[for (var i = 0; i < 5; i++) '!p$i:hs.example'];
        final (hs2, g2) = await signedIn(ContactPolicy(enabled: true, groups: ids.toSet()));
        await settle(g2, merge(<Map<String, Object?>>[for (final id in ids) groupInvite(id, _fremd)]));
        for (final id in ids) {
          serveGroup(hs2, id);
        }
        hs2.holdJoin = Completer<void>();
        hs2.onJoin = (r) => Future<void>.delayed(const Duration(milliseconds: 100), () => _syncJoined(g2, groupJoined(r))).ignore();
        final running = <Future<void>>[for (final id in ids.take(4)) g2.acceptGroupInvite(id)];
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await expectLater(g2.acceptGroupInvite(ids.last), _error(GatewayError.rateLimited));
        hs2.holdJoin!.complete();
        await Future.wait(running);
      });

      test('Abmelden während des Beitritts: der Raum wird verlassen, notAllowed', () async {
        final (hs, g) = await invited();
        hs.onJoin = (r) => Future<void>.delayed(const Duration(milliseconds: 200), () => _syncJoined(g, groupJoined(gr))).ignore();
        final f = g.acceptGroupInvite(gr);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await g.logout();
        await expectLater(f.timeout(const Duration(seconds: 5)), throwsA(isA<Object>()));
        expect(g.debugGroups, isEmpty);
      });
    });

    group('createGroup', () {
      void armCreate(_Hs hs, SdkMatrixGateway g, {String room = '!neu:hs.example', int joined = 1}) {
        hs.createdRoom = room;
        hs.onCreate = (r) => Future<void>.delayed(
              const Duration(milliseconds: 100),
              () => _syncJoined(g, groupJoined(r, name: 'Neue Gruppe', members: <String>[_me], joined: joined)),
            ).ignore();
      }

      test('Anlegen nur über ContactGroupSpec: privat, Version 10, Megolm, Verlauf invited, Regel invite, Schwellen 100, ohne Einladungen und ohne Datensatz', () async {
        final (hs, g) = await signedIn(nobody);
        armCreate(hs, g);
        final id = await g.createGroup('  Neue Gruppe ');
        expect(id, '!neu:hs.example');
        final body = hs.where('POST', '/createRoom').single.$3;
        final m = json.decode(body) as Map<String, Object?>;
        expect(m['room_version'], '10');
        expect(m['preset'], 'private_chat');
        expect(m['visibility'], 'private');
        expect(m['name'], 'Neue Gruppe');
        expect(m.containsKey('invite'), isFalse, reason: 'ohne Mitglieder (D3)');
        final initial = {for (final s in m['initial_state']! as List) (s as Map)['type']: s['content']};
        expect(initial['m.room.encryption'], <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'});
        expect(initial['m.room.history_visibility'], <String, Object?>{'history_visibility': 'invited'});
        expect(initial['m.room.join_rules'], <String, Object?>{'join_rule': 'invite'});
        final events = ((m['power_level_content_override']! as Map)['events']! as Map);
        expect(events['m.room.join_rules'], 100);
        expect(events['m.room.history_visibility'], 100);
        expect(events['m.room.encryption'], 100);
        expect(hs.calls.where((c) => c.$1 == 'PUT' && (c.$2.contains('/send/') || c.$2.contains('account_data'))), isEmpty, reason: 'kein Datensatz, keine Zuordnung');
        expect(g.debugCreatingGroups, <String>{'!neu:hs.example'});
        expect(g.threads.where((t) => t.kind == ThreadKind.group), isEmpty, reason: 'ohne Datensatz keine Gruppe');
      });

      test('Vorbedingungen: Name, Bereich aus, Liste nicht geladen, keine Verschlüsselung, 50 Gruppen ⇒ kein Raum', () async {
        final (hs, g) = await signedIn(nobody);
        await expectLater(g.createGroup('   '), _error(GatewayError.invalidInput));
        await expectLater(g.createGroup('x' * 61), _error(GatewayError.invalidInput));
        await expectLater(g.createGroup('\u202E·'), _error(GatewayError.invalidInput), reason: 'nach der Bereinigung leer');
        g.setContactPolicy(ContactPolicy.off);
        await expectLater(g.createGroup('Gruppe'), _notAllowed());
        g.setContactPolicy(ContactPolicy(enabled: true, groups: <String>{for (var i = 0; i < ContactLimits.maxGroups; i++) '!x$i:hs.example'}));
        await expectLater(g.createGroup('Gruppe'), _notAllowed(), reason: '50 Gruppen');
        final (hs2, g2) = await _signedIn(encryption: true, familyMembersFail: true);
        g2.setContactPolicy(nobody);
        await expectLater(g2.createGroup('Gruppe'), _notAllowed());
        final (hs3, g3) = await _signedIn(encryption: false);
        g3.setContactPolicy(nobody);
        await expectLater(g3.createGroup('Gruppe'), _error(GatewayError.encryptionUnavailable));
        for (final h in <_Hs>[hs, hs2, hs3]) {
          expect(h.where('POST', '/createRoom'), isEmpty);
        }
      });

      test('Doppelstart ⇒ alreadyExists; nach einem Fehler beim Anlegen ist ein neuer Versuch möglich, nichts bleibt stehen', () async {
        final (hs, g) = await signedIn(nobody);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final first = g.createGroup('Eins');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await expectLater(g.createGroup('Zwei'), _error(GatewayError.alreadyExists));
        hs.holdCreate!.complete();
        expect(await first, '!neu:hs.example');
        expect(hs.where('POST', '/createRoom'), hasLength(1));
      });

      test('Abmelden während des Anlegens: der Raum wird verlassen (kein verwaister Raum)', () async {
        final (hs, g) = await signedIn(nobody);
        hs.holdCreate = Completer<void>();
        hs.createdRoom = '!neu:hs.example';
        hs.onCreate = (r) => Future<void>.delayed(const Duration(milliseconds: 100), () => _syncJoined(g, groupJoined(r, members: <String>[_me], joined: 1))).ignore();
        final f = g.createGroup('Eins');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await g.logout();
        hs.holdCreate!.complete();
        await expectLater(f.timeout(const Duration(seconds: 5)), throwsA(isA<Object>()));
        expect(g.debugCreatingGroups, isEmpty, reason: 'der Raum gehört nicht mehr in diesen Zustand');
      });

      test('Familienwechsel mit unvollständiger Liste während des Anlegens: der Raum wird verlassen, notAllowed', () async {
        final (hs, g) = await signedIn(nobody);
        hs.holdCreate = Completer<void>();
        armCreate(hs, g);
        final f = g.createGroup('Eins');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        hs.familyMembersFail = true;
        g.debugLeaveFamilyScope();
        final done = expectLater(f, _notAllowed());
        hs.holdCreate!.complete();
        await done;
        expect(hs.where('POST', '!neu:hs.example/leave'), isNotEmpty);
        expect(g.debugCreatingGroups, isEmpty);
      });

      test('eine angelegte Gruppe ohne sichtbaren Datensatz lässt sich verlassen (Rücknahme durch den Controller, D3); mit Datensatz räumt der Sync den Schwebezustand', () async {
        final (hs, g) = await signedIn(nobody);
        armCreate(hs, g);
        final id = await g.createGroup('Eins');
        await g.leaveConversation(id);
        expect(hs.where('POST', '$id/leave'), isNotEmpty);
        expect(g.debugCreatingGroups, isEmpty);
        // Mit Datensatz: der nächste Abgleich nimmt die Gruppe auf und beendet den Schwebezustand.
        final (hs2, g2) = await signedIn(nobody);
        armCreate(hs2, g2, room: '!zwei:hs.example');
        final id2 = await g2.createGroup('Zwei');
        g2.setContactPolicy(ContactPolicy(enabled: true, groups: <String>{id2}));
        await Future<void>.delayed(_settle);
        expect(g2.debugCreatingGroups, isEmpty);
        expect(g2.threads.where((t) => t.kind == ThreadKind.group).map((t) => t.id), <String>[id2]);
      });

      test('createGroup liest sich nicht als Gruppe, solange kein Datensatz da ist; ein fremder Raum lässt sich über leaveConversation nie verlassen', () async {
        final (hs, g) = await signedIn(nobody);
        await settle(g, groupJoined('!fremd:hs.example'));
        await expectLater(g.leaveConversation('!fremd:hs.example'), _notAllowed());
        expect(hs.where('POST', '/leave'), isEmpty);
      });
    });

    group('leaveConversation und leftGroupRooms', () {
      test('Erfolg räumt Zustand und Zeitleiste; leftGroupRooms nennt die Gruppe; Familie und Einzelchats bleiben ausgeschlossen', () async {
        final (hs, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        await g.openThread(gr);
        expect(g.leftGroupRooms, isEmpty);
        await g.leaveConversation(gr);
        expect(hs.where('POST', '$gr/leave'), hasLength(1));
        expect(g.debugGroups, isEmpty);
        expect(g.debugGroupTimelines, isEmpty);
        await Future<void>.delayed(_settle);
        expect(g.threads.where((t) => t.kind == ThreadKind.group), isEmpty);
        expect(g.leftGroupRooms, <String>{gr});
        await expectLater(g.leaveConversation(ChatThread.familyId), _notAllowed());
      });

      test('Fehler beim Verlassen lässt alles unverändert, ein zweiter Versuch ist möglich', () async {
        final (hs, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        hs.failLeave = true;
        await expectLater(g.leaveConversation(gr), throwsA(isA<GatewayException>()));
        expect(g.debugGroups, <String, String>{gr: 'Skatrunde'});
        expect(g.leftGroupRooms, isEmpty);
        hs.failLeave = false;
        await g.leaveConversation(gr);
        expect(g.debugGroups, isEmpty);
      });

      test('auch überfüllte, unbekannt große, unverschlüsselte und sendegesperrte Gruppen lassen sich verlassen', () async {
        final cases = <String, Map<String, Object?>>{
          'überfüllt': groupJoined(gr, joined: 60),
          '40 + 30': groupJoined(gr, joined: 40, invited: 30),
          'unbekannt groß': groupUnknownSize(gr),
          'unverschlüsselt': groupJoined(gr, megolm: false),
          'Regel public': groupJoined(gr, rule: 'public'),
          'Verlauf shared': groupJoined(gr, history: 'shared'),
        };
        for (final e in cases.entries) {
          final (hs, g) = await signedIn();
          final t = await groupThread(g, e.value);
          expect(t, isNotNull, reason: e.key);
          expect(t!.sendLock, isNot(GroupSendLock.keiner), reason: e.key);
          await g.leaveConversation(gr);
          expect(hs.where('POST', '$gr/leave'), hasLength(1), reason: e.key);
        }
      });

      test('leftGroupRooms: Mitgliedschaft leave/ban (auch nach Entfernen durch andere) und bewusst verlassen; nie unbekannte Räume', () async {
        const gone = '!weg:hs.example';
        const banned = '!ban:hs.example';
        const unknown = '!unbekannt:hs.example';
        final (_, g) = await signedIn(const ContactPolicy(enabled: true, groups: <String>{gr, gone, banned, unknown}));
        await settle(g, merge(<Map<String, Object?>>[groupJoined(gr), groupJoined(gone), groupJoined(banned)]));
        expect(g.debugGroups.keys.toSet(), <String>{gr, gone, banned});
        expect(g.leftGroupRooms, isEmpty, reason: 'beigetreten und unbekannt zählen nie');
        // Entfernen durch andere und Verbannen: das SDK wirft verlassene Räume aus `client.rooms` (kein `includeLeave`).
        await settle(g, <String, Object?>{
          'rooms': <String, Object?>{
            'leave': <String, Object?>{
              for (final id in <String>[gone, banned])
                id: <String, Object?>{
                  'state': <String, Object?>{
                    'events': <Object?>[
                      _state('m.room.member', id == banned ? _fremd : _me, <String, Object?>{'membership': id == banned ? 'ban' : 'leave'}, key: _me),
                    ],
                  },
                },
            },
          },
        });
        expect(g.debugGroups.keys.toSet(), <String>{gr});
        expect(g.leftGroupRooms, <String>{gone, banned}, reason: 'bekannt gewesene Gruppen, jetzt weg; `unbekannt` nie');
      });

      test('Lesen, Melden und Ungelesen laufen über den Raum der Gruppe; Ereignisse einer Gruppe landen nie in den Kontakt-Zeitleisten', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        await g.openThread(gr);
        expect(g.debugGroupTimelines, <String>{gr});
        expect(g.debugContactTimelines, isEmpty);
        await expectLater(g.reportMessage(ReportRequest(threadId: gr, messageId: r'$gibtsnicht', category: ReportCategory.spam)), _error(GatewayError.notFound));
      });
    });

    group('Zeitleiste öffnen', () {
      test('isThreadOpen erst nach openThread, idempotent; messagesIn leer', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        expect(g.isThreadOpen(gr), isFalse);
        await g.openThread(gr);
        await g.openThread(gr);
        expect(g.isThreadOpen(gr), isTrue);
        expect(g.debugGroupTimelines, <String>{gr});
        expect(g.messagesIn(gr), isEmpty);
      });

      test('Datensatz entfällt oder Familienwechsel während des Öffnens ⇒ keine Zeitleiste', () async {
        final (_, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        final open = g.openThread(gr);
        g.setContactPolicy(nobody);
        await open;
        expect(g.debugGroupTimelines, isEmpty);
        g.setContactPolicy(rec);
        await Future<void>.delayed(_settle);
        final open2 = g.openThread(gr);
        g.debugLeaveFamilyScope();
        await open2;
        expect(g.debugGroupTimelines, isEmpty);
      });
    });

    group('Senden in Gruppen ist gesperrt (Platzhalter bis K4-2b)', () {
      test('Text, Antwort, Anhang, Reaktion und Wiederholen: notAllowed, auch bei bester Lage; nichts geht an den Server', () async {
        final (hs, g) = await signedIn();
        expect(await groupThread(g, groupJoined(gr)), isNotNull);
        await expectLater(g.sendMessage('Hallo', threadId: gr), _notAllowed(), reason: 'vor openThread');
        await g.openThread(gr);
        await expectLater(g.sendMessage('Hallo', threadId: gr), _notAllowed());
        await expectLater(g.sendMessage('Hallo', threadId: gr, replyToId: r'$x'), _notAllowed());
        await expectLater(g.sendAttachment(fileName: 'a.pdf', bytes: Uint8List.fromList('%PDF-1.4\n1 0 obj\n'.codeUnits), threadId: gr), _notAllowed());
        await expectLater(g.sendReaction(r'$e', '👍', threadId: gr), _notAllowed());
        await expectLater(g.retryMessage(r'$e', threadId: gr), throwsA(isA<GatewayException>()));
        expect(hs.sends, isEmpty);
      });
    });

    group('Große Gruppen: kein Abruf der Mitgliederliste (Aufrufzähler)', () {
      test('G > 50 oder Größe unbekannt: nie requestParticipants, weder im Sync noch in openThread', () async {
        final cases = <String, Map<String, Object?>>{
          '51': groupJoined(gr, joined: 51, memberEvents: 1),
          '10 000': groupJoined(gr, joined: 10000, memberEvents: 1),
          '40 + 30 (G = 70, Beitrittszahl ≤ 50)': groupJoined(gr, joined: 40, invited: 30, memberEvents: 1),
          'unbekannt': (() {
            final u = groupJoined(gr, memberEvents: 1);
            ((((u['rooms']! as Map)['join']! as Map)[gr]! as Map)['summary']! as Map).remove('m.joined_member_count');
            return u;
          })(),
        };
        for (final e in cases.entries) {
          final (hs, g) = await signedIn();
          final t = await groupThread(g, e.value);
          expect(t, isNotNull, reason: e.key);
          await g.openThread(gr);
          await _sync(g, <String, Object?>{'account_data': <String, Object?>{'events': <Object?>[<String, Object?>{'type': 'x.kick', 'content': <String, Object?>{'n': _n++}}]}});
          await Future<void>.delayed(_settle);
          expect(membersCalls(hs), 0, reason: e.key);
          expect(g.debugGroupMembers, isEmpty, reason: e.key);
        }
      });

      test('G ≤ 50 und lokal vollständig: kein Serverabruf, Mitglieder aus dem lokalen Zustand', () async {
        final (hs, g) = await signedIn();
        await groupThread(g, groupJoined(gr));
        expect(membersCalls(hs), 0);
        expect(g.debugGroupMembers[gr]!.keys.toSet(), <String>{_me, _fremd, anna});
      });

      test('G ≤ 50, lokal unvollständig: ein Abruf; Drosselung: viele Syncs ⇒ höchstens ein Abruf je Raum (Einladungszahl unbekannt ⇒ nie „vollständig“)', () async {
        final (hs, g) = await signedIn();
        hs.members = <String>[_me, _fremd, anna];
        await groupThread(g, groupJoined(gr, invited: null, memberEvents: 1));
        for (var i = 0; i < 4; i++) {
          await _sync(g, <String, Object?>{'account_data': <String, Object?>{'events': <Object?>[<String, Object?>{'type': 'x.kick', 'content': <String, Object?>{'n': _n++}}]}});
          await Future<void>.delayed(_settle);
        }
        expect(membersCalls(hs), 1);
        expect(g.debugGroupMembers[gr]!.keys.toSet(), <String>{_me, _fremd, anna});
      });

      test('nach dem Abruf ist G exakt: 40 beigetreten, Einladungszahl unbekannt, Liste mit 30 Eingeladenen ⇒ G = 70, zuGross', () async {
        final (hs, g) = await signedIn();
        hs.members = <String>[_me, for (var i = 0; i < 39; i++) '@m$i:hs.example'];
        for (var i = 0; i < 30; i++) {
          hs.extra['@i$i:hs.example'] = 'invite';
        }
        expect(await groupThread(g, groupJoined(gr, joined: 40, invited: null, memberEvents: 1)), isNotNull);
        expect(membersCalls(hs), 1, reason: 'summary G = 40 ≤ 50 ⇒ ein Abruf');
        // Der Abruf läuft im Hintergrund: warten, bis die Liste im Zustand ist (kein fester Zeitpunkt, kein Wettlauf).
        for (var i = 0; i < 30 && g.threads.where((x) => x.kind == ThreadKind.group).first.memberCount != 70; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        final after = g.threads.firstWhere((x) => x.kind == ThreadKind.group);
        expect(after.memberCount, 70);
        expect(after.sendLock, GroupSendLock.zuGross);
      });
    });
  });
}

/// Nur als Platzhalter für `KeyVerification.encryption`: `isDone` und `state` fassen die Verschlüsselung nicht an.
class _NoEncryption implements Encryption {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
