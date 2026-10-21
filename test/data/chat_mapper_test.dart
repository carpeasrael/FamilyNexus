import 'package:family_nexus/data/matrix/chat_mapper.dart';
import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
// ignore: implementation_imports
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prüft die Übersetzung mit echten SDK-Objekten (Client/Room/Timeline/Event)
/// gegen feindselige Eingaben anderer Teilnehmer.
void main() {
  late Client client;
  late Room room;
  var n = 0;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    client = Client('test', database: await MatrixSdkDatabase.init('t${n++}', database: db));
    room = Room(id: '!room:fake.test', client: client);
  });

  Event ev(
    String id,
    Map<String, Object?> content, {
    String type = 'm.room.message',
    String sender = '@ben:fake.test',
    int ts = 1000,
    int? status,
  }) =>
      Event.fromJson(<String, Object?>{
        'type': type,
        'event_id': id,
        'sender': sender,
        'origin_server_ts': ts,
        'content': content,
        'status': ?status,
      }, room);

  Timeline timeline(List<Event> newestFirst) => Timeline(room: room, chunk: TimelineChunk(events: newestFirst));

  List<ChatMessage> map(List<Event> chronological) => ChatMapper.messages(timeline(chronological.reversed.toList()));

  Map<String, Object?> text(String body, {Map<String, Object?>? extra}) =>
      <String, Object?>{'msgtype': 'm.text', 'body': body, ...?extra};

  Map<String, Object?> file(String name, String mime, Object? size, {String type = 'm.file'}) => <String, Object?>{
        'msgtype': type,
        'body': name,
        'url': 'mxc://fake.test/abc',
        'info': <String, Object?>{'mimetype': mime, 'size': size},
      };

  test('einfache Nachricht, Reihenfolge älteste zuerst', () {
    final m = map(<Event>[ev(r'$a', text('eins'), ts: 1), ev(r'$b', text('zwei'), ts: 2)]);
    expect(m.map((e) => e.body), <String>['eins', 'zwei']);
    expect(m.first.senderId, '@ben:fake.test');
  });

  test('Antwort: Zitat-Fallback wird aus dem Text entfernt, Bezug bleibt', () {
    final m = map(<Event>[
      ev(r'$a', text('Wer holt ab?')),
      ev(r'$b', text('> <@ben:fake.test> Wer holt ab?\n\nIch', extra: <String, Object?>{
        'm.relates_to': <String, Object?>{
          'm.in_reply_to': <String, Object?>{'event_id': r'$a'},
        },
      })),
    ]);
    expect(m.last.body, 'Ich');
    expect(m.last.replyToId, r'$a');
  });

  group('Anhänge', () {
    test('passender Bildanhang wird übernommen', () {
      final m = map(<Event>[ev(r'$a', file('foto.png', 'image/png', 1234, type: 'm.image'))]).single;
      expect(m.attachment!.name, 'foto.png');
      expect(m.attachment!.size, 1234);
      expect(m.blockedAttachment, isFalse);
    });

    test('Größe als Kommazahl/Text/fehlend blockiert den Anhang, bricht aber nichts ab', () {
      for (final size in <Object?>[1.5, '10', null, -1]) {
        final m = map(<Event>[
          ev(r'$a', file('foto.png', 'image/png', size, type: 'm.image'), ts: 1),
          ev(r'$b', text('danach'), ts: 2),
        ]);
        expect(m, hasLength(2), reason: '$size');
        expect(m.first.blockedAttachment, isTrue, reason: '$size');
        expect(m.last.body, 'danach');
      }
    });

    test('Typ/Endung passen nicht zusammen oder nicht erlaubt → blockiert', () {
      for (final c in <(String, String)>[
        ('x.apk', 'text/plain'),
        ('x.exe', 'application/x-msdownload'),
        ('x.png', 'application/pdf'),
        ('x.html', 'text/html'),
        ('x', 'image/png'),
      ]) {
        final m = map(<Event>[ev(r'$a', file(c.$1, c.$2, 10))]).single;
        expect(m.blockedAttachment, isTrue, reason: '$c');
        expect(m.attachment, isNull);
      }
    });

    test('zu große Datei wird blockiert', () {
      final m = map(<Event>[ev(r'$a', file('a.pdf', 'application/pdf', AttachmentPolicy.maxBytes + 1))]).single;
      expect(m.blockedAttachment, isTrue);
    });

    test('Dateiname aus fremder Quelle wird bereinigt', () {
      final m = map(<Event>[ev(r'$a', file('../../etc/passwd.png', 'image/png', 10, type: 'm.image'))]).single;
      expect(m.attachment!.name, 'passwd.png');
    });
  });

  test('nicht entschlüsselbare Nachricht wird sichtbar markiert', () {
    final m = map(<Event>[
      ev(r'$a', <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'}, type: 'm.room.encrypted'),
    ]).single;
    expect(m.undecryptable, isTrue);
    expect(m.body, isEmpty);
  });

  test('Bearbeitungen, Entfernte und fremde Ereignistypen werden nicht als Nachricht gezeigt', () {
    final m = map(<Event>[
      ev(r'$a', text('Original'), ts: 1),
      ev(r'$e', text('* neu', extra: <String, Object?>{
        'm.relates_to': <String, Object?>{'rel_type': 'm.replace', 'event_id': r'$a'},
        'm.new_content': <String, Object?>{'msgtype': 'm.text', 'body': 'neu'},
      }), ts: 2),
      ev(r'$s', <String, Object?>{'name': 'x'}, type: 'm.room.name', ts: 3),
      ev(r'$c', <String, Object?>{'v': 1}, type: 'de.inneso.familynexus.event', ts: 4),
    ]);
    expect(m, hasLength(1));
    expect(m.single.body, 'neu', reason: 'bearbeiteter Text wird angezeigt');
  });

  test('Status: Fehler → failed, sonst sent', () {
    final m = map(<Event>[
      ev(r'$a', text('ok'), ts: 1),
      ev(r'$b', text('kaputt'), ts: 2, status: EventStatus.error.intValue),
    ]);
    expect(m.first.status, MessageStatus.sent);
    expect(m.last.status, MessageStatus.failed);
  });

  group('Reaktionen', () {
    Event react(String id, String key, {String sender = '@ben:fake.test'}) => ev(id, <String, Object?>{
          'm.relates_to': <String, Object?>{'rel_type': 'm.annotation', 'event_id': r'$a', 'key': key},
        }, type: 'm.reaction', sender: sender, ts: 5);

    test('Emojis werden gezählt, Text als „Reaktion“ verworfen', () {
      final m = map(<Event>[
        ev(r'$a', text('Hi'), ts: 1),
        react(r'$r1', '👍'),
        react(r'$r2', '👍', sender: '@cara:fake.test'),
        react(r'$r3', 'Klickhier http://böse'),
      ]).single;
      expect(m.reactions.keys, <String>['👍']);
      expect(m.reactions['👍'], hasLength(2));
    });

    test('Anzahl verschiedener Reaktionen ist begrenzt', () {
      final events = <Event>[ev(r'$a', text('Hi'), ts: 1)];
      for (var i = 0; i < 40; i++) {
        events.add(react('\$r$i', String.fromCharCode(0x1F600 + i)));
      }
      expect(map(events).single.reactions.length, ChatMapper.maxReactionKeys);
    });
  });
}
