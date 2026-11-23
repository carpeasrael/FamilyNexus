// Bon-Dateien des SdkMatrixGateway (Kassenbuch, #311, E-113, Teil 3b) gegen einen nachgestellten Homeserver: senden ohne
// Vorschau, geprüft laden, nur eigene schwärzen. Läuft ohne vodozemac (Naht `requireEncryptionForBooks`).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/book_room.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:matrix/matrix.dart' show SyncUpdate;
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

  /// Hochgeladene Dateien (Pfad, Bytes), abrufbare Medien (`mxc`-Name → Bytes) und Ereignisse (`event_id` → JSON, `null` = 404).
  final List<(String, Uint8List)> uploads = <(String, Uint8List)>[];
  final Map<String, Uint8List> media = <String, Uint8List>{};
  final Map<String, Map<String, Object?>?> events = <String, Map<String, Object?>?>{};
  final List<String> downloads = <String>[];
  bool eventFetchFails = false;
  int? mediaStatus;
  Uint8List Function(Uint8List)? mediaTransform;
  bool mediaThrows = false;
  int mediaChunksSent = 0;
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
        final raw = await body.expand((e) => e).toList();
        final rawBytes = Uint8List.fromList(raw);
        final text = utf8.decode(raw, allowMalformed: true);
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
        if (req.method == 'GET' && path.endsWith('/media/config')) return _json(<String, Object?>{'m.upload.size': 50000000});
        if (req.method == 'POST' && path.contains('/upload')) {
          uploads.add((path, rawBytes));
          return _json(<String, Object?>{'content_uri': 'mxc://hs.example/up${uploads.length}'});
        }
        if (req.method == 'GET' && path.contains('/download/')) {
          final name = path.split('/').last;
          downloads.add(name);
          final data = media[name];
          if (data == null || (mediaStatus ?? 200) != 200) return _json(<String, Object?>{'errcode': 'M_NOT_FOUND'}, mediaStatus ?? 404);
          if (mediaThrows) throw const SocketException('Verbindung getrennt');
          final out = mediaTransform?.call(data) ?? data;
          Stream<List<int>> chunks() async* {
            for (var i = 0; i < out.length; i += 65536) {
              mediaChunksSent++;
              yield out.sublist(i, i + 65536 > out.length ? out.length : i + 65536);
            }
          }

          return http.StreamedResponse(chunks(), 200, headers: <String, String>{'content-type': 'image/jpeg'});
        }
        final ev = RegExp(r'/rooms/([^/]+)/event/([^/]+)$').firstMatch(path);
        if (ev != null && req.method == 'GET') {
          if (eventFetchFails) return _json(<String, Object?>{'errcode': 'M_UNKNOWN', 'error': 'Fehler'}, 500);
          final e = events[ev.group(2)];
          if (e == null) return _json(<String, Object?>{'errcode': 'M_NOT_FOUND', 'error': 'nicht da'}, 404);
          return _json(e);
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

Matcher _notAllowed() => throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed));

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

/// Ein gültiges JPEG (für Hash und Größe).
Uint8List _jpeg([int seed = 1]) {
  final image = img.Image(width: 40, height: 30);
  for (final p in image) {
    p
      ..r = (p.x * 6 + seed) & 255
      ..g = (p.y * 8) & 255
      ..b = 120;
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

CashReceipt _receiptFor(Uint8List b, {String eventId = r'$bon1'}) =>
    CashReceipt(eventId: eventId, sha256: ReceiptCheck.sha256Hex(b), size: b.length);

/// Ereignis einer Bon-Datei, wie der Server es liefert.
Map<String, Object?> _fileEvent(
  String eventId, {
  String sender = _cara,
  String msgtype = 'm.image',
  String mime = 'image/jpeg',
  Object? size,
  String url = 'mxc://hs.example/bon1',
  String type = 'm.room.message',
  Map<String, Object?>? extra,
  bool noInfo = false,
}) =>
    <String, Object?>{
      'type': type,
      'event_id': eventId,
      'sender': sender,
      'origin_server_ts': 1700000000000,
      'room_id': _book,
      'content': <String, Object?>{
        'msgtype': msgtype,
        'body': 'receipt.jpg',
        'url': url,
        if (!noInfo) 'info': <String, Object?>{'mimetype': mime, 'size': size},
      },
      ...?extra,
    };

void main() {
  setUpAll(sqfliteFfiInit);

  Future<(_Hs, SdkMatrixGateway)> ready({bool requireEncryption = false, bool enabled = true}) async {
    final (hs, g) = await _signedIn(enabled: enabled, requireEncryption: requireEncryption);
    await _sync(g, _bookJoin(_book, members: <String>[_cara]));
    hs.members = <String>[_me, _cara];
    return (hs, g);
  }

  group('gesperrt', () {
    test('alle drei Aufrufe notAllowed, nichts an den Server', () async {
      final (hs, g) = await ready(enabled: false);
      final before = hs.calls.length;
      final b = _jpeg();
      await expectLater(g.sendBookReceipt(_book, b), _notAllowed());
      await expectLater(g.loadBookReceipt(_book, r'$bon1', receipt: _receiptFor(b), author: _cara), _notAllowed());
      await expectLater(g.redactBookReceipt(_book, r'$bon1'), _notAllowed());
      expect(hs.calls.length, before);
    });
  });

  group('sendBookReceipt', () {
    test('eine allgemeine Datei: m.image ohne Vorschau, ohne Maße, ohne Blurhash; die Bytes gehen unverändert hoch', () async {
      final (hs, g) = await ready();
      final b = _jpeg();
      final id = await g.sendBookReceipt(_book, b);
      expect(id, startsWith(r'$'));
      expect(hs.uploads, hasLength(1), reason: 'nur die Datei, keine Vorschau');
      expect(hs.uploads.single.$2, b);
      final sent = json.decode(hs.sends.single.$2) as Map<String, Object?>;
      expect(sent['msgtype'], 'm.image');
      final info = sent['info']! as Map<String, Object?>;
      expect(info['mimetype'], 'image/jpeg');
      expect(info['size'], b.length);
      for (final k in <String>['w', 'h', 'thumbnail_url', 'thumbnail_file', 'thumbnail_info', 'xyz.amorgan.blurhash']) {
        expect(info.containsKey(k), isFalse, reason: k);
      }
    });

    test('Sendeschutz: Fremder im Raum → notAllowed, nichts hochgeladen; keine belastbare Liste → serverUnreachable', () async {
      final (hs, g) = await ready();
      hs.members = <String>[_me, _cara, _fremd];
      await expectLater(g.sendBookReceipt(_book, _jpeg()), _notAllowed());
      hs.members = <String>[_me, _cara];
      hs.emptyMembers = true;
      await expectLater(g.sendBookReceipt(_book, _jpeg()), _error(GatewayError.serverUnreachable));
      expect(hs.uploads, isEmpty);
      expect(hs.sends, isEmpty);
    });

    test('Größe, JPEG-Kennung, leer: invalidInput ohne Anfrage; genau 1 MiB geht, ein Byte mehr nicht', () async {
      final (hs, g) = await ready();
      await expectLater(g.sendBookReceipt(_book, Uint8List(0)), _error(GatewayError.invalidInput));
      await expectLater(g.sendBookReceipt(_book, Uint8List.fromList(<int>[1, 2, 3, 4])), _error(GatewayError.invalidInput));
      final over = Uint8List(CashBookLimits.maxReceiptBytes + 1)..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
      await expectLater(g.sendBookReceipt(_book, over), _error(GatewayError.invalidInput));
      final exact = Uint8List(CashBookLimits.maxReceiptBytes)..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
      await g.sendBookReceipt(_book, exact);
      expect(hs.uploads, hasLength(1));
    });

    test('Verschlüsselung ist Pflicht (Standard der Naht): ohne verfügbare Verschlüsselung wird nichts gesendet', () async {
      final (hs, g) = await ready(requireEncryption: true);
      await expectLater(g.sendBookReceipt(_book, _jpeg()), _error(GatewayError.encryptionUnavailable));
      expect(hs.uploads, isEmpty);
    });

    test('Buch einer anderen Familie, unbekannter Raum, Einladung statt Beitritt', () async {
      final (hs, g) = await ready();
      await _sync(g, _bookJoin('!anderes:hs.example', family: '!andere:hs.example'));
      await expectLater(g.sendBookReceipt('!anderes:hs.example', _jpeg()), _notAllowed());
      await expectLater(g.sendBookReceipt('!gibtsnicht:hs.example', _jpeg()), _error(GatewayError.notFound));
      expect(hs.uploads, isEmpty);
    });

    test('Senden scheitert: Fehler, nichts gilt als gesendet', () async {
      final (hs, g) = await ready();
      hs.sendOkCount = 0;
      await expectLater(g.sendBookReceipt(_book, _jpeg()), throwsA(isA<GatewayException>()));
    });
  });

  group('loadBookReceipt', () {
    Future<(_Hs, SdkMatrixGateway, Uint8List, CashReceipt)> withFile({String sender = _cara, Map<String, Object?> Function(Map<String, Object?>)? tweak}) async {
      final (hs, g) = await ready();
      final b = _jpeg();
      final r = _receiptFor(b);
      hs.media['bon1'] = b;
      final ev = _fileEvent(r.eventId, sender: sender, size: b.length);
      hs.events[r.eventId] = tweak == null ? ev : tweak(ev);
      return (hs, g, b, r);
    }

    test('ok: Absender == Autor, Größe, Hash und Kennung stimmen', () async {
      final (_, g, b, r) = await withFile();
      final l = await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara);
      expect(l.status, BookReceiptStatus.ok);
      expect(l.bytes, b);
    });

    test('Absender der Datei ist nicht der Autor des Eintrags: invalid, ohne Download', () async {
      final (hs, g, _, r) = await withFile(sender: _ben);
      final l = await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara);
      expect(l.status, BookReceiptStatus.invalid);
      expect(hs.downloads, isEmpty);
    });

    test('info.size fehlt, ist zu groß oder ungleich der Größe im Eintrag: invalid, ohne Download', () async {
      for (final size in <Object?>[null, CashBookLimits.maxReceiptBytes + 1, 5]) {
        final (hs, g, _, r) = await withFile(tweak: (e) => _fileEvent(e['event_id']! as String, size: size));
        final l = await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara);
        expect(l.status, BookReceiptStatus.invalid, reason: '$size');
        expect(hs.downloads, isEmpty, reason: '$size');
      }
    });

    test('falscher Nachrichtentyp, falsche MIME, anderer Ereignistyp: invalid, ohne Download', () async {
      final (hs, g, b, r) = await withFile();
      for (final ev in <Map<String, Object?>>[
        _fileEvent(r.eventId, msgtype: 'm.text', size: b.length),
        _fileEvent(r.eventId, mime: 'image/png', size: b.length),
        _fileEvent(r.eventId, type: 'm.room.topic', size: b.length),
      ]) {
        hs.events[r.eventId] = ev;
        expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.invalid);
      }
      expect(hs.downloads, isEmpty);
    });

    test('Bytes passen nicht (Hash, Größe, Kennung): invalid, auch bei gleicher behaupteter Größe', () async {
      final (hs, g, b, r) = await withFile();
      // Hash: gleiche Länge, anderer Inhalt
      final other = Uint8List.fromList(b)..[b.length ~/ 2] ^= 0x55;
      hs.media['bon1'] = other;
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.invalid);
      // Kennung: gleiche Länge und (berechneter) Hash, aber kein JPEG
      final notJpeg = Uint8List(b.length)..setRange(0, 4, <int>[1, 2, 3, 4]);
      hs.media['bon1'] = notJpeg;
      final r2 = _receiptFor(notJpeg);
      hs.events[r.eventId] = _fileEvent(r.eventId, size: notJpeg.length);
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r2, author: _cara)).status, BookReceiptStatus.invalid);
      // Größe: Server liefert mehr als behauptet
      hs.media['bon1'] = Uint8List.fromList(<int>[...b, 0]);
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.invalid);
    });

    test('der Download ist auf 1 MiB + 1 KiB gekappt: mehr wird abgelehnt (invalid), nicht geladen', () async {
      final (hs, g, b, r) = await withFile();
      hs.mediaTransform = (_) => Uint8List(CashBookLimits.maxReceiptBytes + 2048);
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.invalid);
      expect(b, isNotEmpty);
    });

    test('der Download wird bei 1 MiB + 1 KiB abgebrochen, nicht ganz gelesen (3 MiB angeboten)', () async {
      final (hs, g, _, r) = await withFile();
      hs.mediaTransform = (_) => Uint8List(3 * 1024 * 1024);
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.invalid);
      expect(hs.mediaChunksSent * 65536, lessThan(CashBookLimits.maxReceiptBytes + 1024 + 3 * 65536), reason: 'nach der Kappung wird nicht weiter gezogen');
      expect(hs.mediaChunksSent * 65536, lessThan(3 * 1024 * 1024));
    });

    test('Verbindungsfehler beim Download (keine GatewayException): unavailable, nicht invalid', () async {
      final (hs, g, _, r) = await withFile();
      hs.mediaThrows = true;
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.unavailable);
    });

    test('Ereignis fehlt (404) oder ist geschwärzt: missing; Netzfehler beim Ereignis oder Download: unavailable', () async {
      final (hs, g, b, r) = await withFile();
      hs.events[r.eventId] = null;
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.missing);
      hs.events[r.eventId] = _fileEvent(r.eventId, size: b.length, extra: <String, Object?>{
        'unsigned': <String, Object?>{
          'redacted_because': <String, Object?>{'type': 'm.room.redaction', 'event_id': r'$red', 'sender': _cara, 'origin_server_ts': 1, 'content': <String, Object?>{}},
        },
      });
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.missing);
      hs.events[r.eventId] = _fileEvent(r.eventId, size: b.length);
      hs.eventFetchFails = true;
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.unavailable);
      hs.eventFetchFails = false;
      hs.mediaStatus = 500;
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.unavailable);
    });

    test('geschwärztes, verschlüsselt angekommenes Ereignis (Typ m.room.encrypted): missing, nicht unavailable', () async {
      final (hs, g) = await ready();
      final b = _jpeg();
      final r = _receiptFor(b);
      hs.events[r.eventId] = <String, Object?>{
        'type': 'm.room.encrypted',
        'event_id': r.eventId,
        'sender': _cara,
        'origin_server_ts': 1700000000000,
        'room_id': _book,
        'content': <String, Object?>{},
        'unsigned': <String, Object?>{
          'redacted_because': <String, Object?>{'type': 'm.room.redaction', 'event_id': r'$red', 'sender': _cara, 'origin_server_ts': 1, 'content': <String, Object?>{}},
        },
      };
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.missing);
    });

    test('noch nicht entschlüsselbar (m.room.encrypted): unavailable, nie invalid', () async {
      final (hs, g) = await ready();
      final b = _jpeg();
      final r = _receiptFor(b);
      hs.events[r.eventId] = <String, Object?>{
        'type': 'm.room.encrypted',
        'event_id': r.eventId,
        'sender': _cara,
        'origin_server_ts': 1700000000000,
        'room_id': _book,
        'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
      };
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara)).status, BookReceiptStatus.unavailable);
    });

    test('Klartext bei Pflicht-Verschlüsselung: invalid (zählt nie), ohne Download', () async {
      final (hs, g) = await ready(requireEncryption: true);
      final b = _jpeg();
      final r = _receiptFor(b);
      hs.media['bon1'] = b;
      hs.events[r.eventId] = _fileEvent(r.eventId, size: b.length);
      final l = await g.loadBookReceipt(_book, r.eventId, receipt: r, author: _cara);
      expect(l.status, BookReceiptStatus.invalid);
      expect(hs.downloads, isEmpty);
    });

    test('ungültige Ereignis-ID oder ungültiger Verweis: invalid ohne Anfrage', () async {
      final (hs, g, b, r) = await withFile();
      final before = hs.calls.length;
      expect((await g.loadBookReceipt(_book, 'kein-id', receipt: r, author: _cara)).status, BookReceiptStatus.invalid);
      expect((await g.loadBookReceipt(_book, r.eventId, receipt: CashReceipt(eventId: r.eventId, sha256: 'x', size: b.length), author: _cara)).status, BookReceiptStatus.invalid);
      expect(hs.calls.length, before);
    });

    test('Buch einer anderen Familie: notAllowed', () async {
      final (hs, g, _, r) = await withFile();
      await _sync(g, _bookJoin('!anderes:hs.example', family: '!andere:hs.example'));
      await expectLater(g.loadBookReceipt('!anderes:hs.example', r.eventId, receipt: r, author: _cara), _notAllowed());
      expect(hs.downloads, isEmpty);
    });
  });

  group('redactBookReceipt', () {
    test('eigene Datei wird geschwärzt', () async {
      final (hs, g) = await ready();
      hs.events[r'$bon1'] = _fileEvent(r'$bon1', sender: _me, size: 10);
      await g.redactBookReceipt(_book, r'$bon1');
      expect(hs.where('PUT', '/redact/'), hasLength(1));
    });

    test('das Schwärzen sendet keinen Grund; ein Fehler beim Abruf des Ereignisses ist kein notFound', () async {
      final (hs, g) = await ready();
      hs.events[r'$bon1'] = _fileEvent(r'$bon1', sender: _me, size: 10);
      await g.redactBookReceipt(_book, r'$bon1');
      expect(hs.where('PUT', '/redact/').single.$3, isNot(contains('reason')));
      hs.eventFetchFails = true;
      await expectLater(
        g.redactBookReceipt(_book, r'$bon1'),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', isNot(GatewayError.notFound))),
      );
    });

    test('fremde Datei: notAllowed, auch wenn ich der Ersteller des Buchs bin (kein Schwärzen)', () async {
      final (hs, g) = await ready();
      hs.events[r'$bon1'] = _fileEvent(r'$bon1', sender: _cara, size: 10);
      await expectLater(g.redactBookReceipt(_book, r'$bon1'), _notAllowed());
      expect(hs.where('PUT', '/redact/'), isEmpty);
    });

    test('fehlt: notFound; schon geschwärzt: Erfolg ohne Anfrage; eigenes, noch unentschlüsselbares: serverUnreachable', () async {
      final (hs, g) = await ready();
      await expectLater(g.redactBookReceipt(_book, r'$weg'), _error(GatewayError.notFound));
      final redacted = <String, Object?>{
        'redacted_because': <String, Object?>{'type': 'm.room.redaction', 'event_id': r'$red', 'sender': _me, 'origin_server_ts': 1, 'content': <String, Object?>{}},
      };
      hs.events[r'$alt'] = <String, Object?>{..._fileEvent(r'$alt', sender: _me, size: 10), 'unsigned': redacted};
      await g.redactBookReceipt(_book, r'$alt');
      hs.events[r'$enc'] = <String, Object?>{
        'type': 'm.room.encrypted',
        'event_id': r'$enc',
        'sender': _me,
        'origin_server_ts': 1700000000000,
        'room_id': _book,
        'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
      };
      await expectLater(g.redactBookReceipt(_book, r'$enc'), _error(GatewayError.serverUnreachable));
      expect(hs.where('PUT', '/redact/'), isEmpty);
    });

    test('ungültige ID und anderer Ereignistyp', () async {
      final (hs, g) = await ready();
      await expectLater(g.redactBookReceipt(_book, 'kein-id'), _error(GatewayError.invalidInput));
      hs.events[r'$topic'] = _fileEvent(r'$topic', sender: _me, size: 10, type: 'm.room.topic');
      await expectLater(g.redactBookReceipt(_book, r'$topic'), _notAllowed());
    });
  });
}
