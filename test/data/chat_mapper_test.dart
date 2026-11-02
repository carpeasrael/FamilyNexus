import 'dart:async';

import 'package:family_nexus/data/matrix/chat_mapper.dart';
import 'package:family_nexus/data/matrix/local_sends.dart';
import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/reaction_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
// ignore: implementation_imports
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ereignis, dessen Inhalt nach dem Aufbau der Zeitleiste beim Lesen wirft.
class _ThrowingEvent extends Event {
  _ThrowingEvent(Room room)
      : super(
          content: <String, Object?>{},
          type: ReactionCodec.type,
          eventId: r'$wirft',
          senderId: '@ben:fake.test',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(3),
          room: room,
          originalSource: MatrixEvent(
            type: 'm.room.encrypted',
            content: <String, Object?>{},
            senderId: '@ben:fake.test',
            eventId: r'$wirft',
            originServerTs: DateTime.fromMillisecondsSinceEpoch(3),
          ),
        );

  bool armed = false;

  @override
  Map<String, Object?> get content => armed ? throw StateError('kaputt') : super.content;
}

/// Prüft die Übersetzung mit echten SDK-Objekten (Client/Room/Timeline/Event)
/// gegen feindselige Eingaben anderer Teilnehmer.
void main() {
  late Client client;
  late Room room;
  late LocalSends sends;
  var n = 0;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    client = Client('test', database: await MatrixSdkDatabase.init('t${n++}', database: db));
    room = Room(id: '!room:fake.test', client: client);
    sends = LocalSends();
  });

  Event ev(
    String id,
    Map<String, Object?> content, {
    String type = 'm.room.message',
    String sender = '@ben:fake.test',
    int ts = 1000,
    int? status,
    bool encrypted = true,
    Map<String, Object?>? unsigned,
  }) =>
      Event.fromJson(<String, Object?>{
        'type': type,
        'event_id': id,
        'sender': sender,
        'origin_server_ts': ts,
        'content': content,
        'status': ?status,
        'unsigned': ?unsigned,
        // Wie nach der Entschlüsselung: Die Quelle setzt nur das SDK, aus der Datenbank kommt sie so zurück.
        if (encrypted)
          'original_source': <String, Object?>{
            'type': 'm.room.encrypted',
            'event_id': id,
            'sender': sender,
            'origin_server_ts': ts,
            'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
          },
      }, room);

  Timeline timeline(List<Event> newestFirst) => Timeline(room: room, chunk: TimelineChunk(events: newestFirst));

  List<ChatMessage> map(List<Event> chronological, {String? me}) => ChatMapper.messages(
        timeline(chronological.reversed.toList()),
        threadId: 'family',
        sends: sends,
        myUserId: me,
      );

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

    group('eigener verschlüsselter Typ (#139)', () {
      const me = '@ida:fake.test';
      const ben = '@ben:fake.test';

      Event neu(
        String id,
        String key, {
        String sender = ben,
        String? claimed,
        String target = r'$a',
        EventStatus? status,
        bool encrypted = true,
        Map<String, Object?>? unsigned,
      }) =>
          ev(
            id,
            ReactionCodec.encode(target: target, key: key, sender: claimed ?? sender),
            type: ReactionCodec.type,
            sender: sender,
            ts: 5,
            status: status?.intValue,
            encrypted: encrypted,
            unsigned: unsigned,
          );

      ChatMessage withMessage(List<Event> reactions) =>
          map(<Event>[ev(r'$a', text('Hi'), ts: 1), ...reactions], me: me).single;

      Map<String, Object?> redactedBecause() => <String, Object?>{
            'redacted_because': <String, Object?>{
              'type': 'm.room.redaction',
              'event_id': r'$weg',
              'sender': ben,
              'origin_server_ts': 9,
              'content': <String, Object?>{},
            },
          };

      test('verschlüsselt angekommen: erscheint, Absender ist der des Ereignisses', () {
        final m = withMessage(<Event>[neu(r'$r1', '👍'), neu(r'$r2', '👍', sender: '@cara:fake.test')]);
        expect(m.reactions['👍'], <String>{ben, '@cara:fake.test'});
      });

      test('Klartext vom neuen Typ wird verworfen, auch mit eigenem Absender', () {
        final m = withMessage(<Event>[
          neu(r'$r1', '👍', encrypted: false),
          neu(r'$r2', '🎉', sender: me, encrypted: false),
          neu(r'$r3', '😀', sender: me, encrypted: false, status: EventStatus.synced),
        ]);
        expect(m.reactions, isEmpty);
      });

      test('eigene Reaktion ist in sending und sent ohne Quelle sichtbar, fremde nicht', () {
        final m = withMessage(<Event>[
          neu('txn1', '👍', sender: me, encrypted: false, status: EventStatus.sending),
          neu(r'$r2', '🎉', sender: me, encrypted: false, status: EventStatus.sent),
          neu('txn3', '😀', encrypted: false, status: EventStatus.sending),
          neu(r'$r4', '😎', encrypted: false, status: EventStatus.sent),
        ]);
        expect(m.reactions.keys, unorderedEquals(<String>['👍', '🎉']));
        expect(m.reactions['👍'], <String>{me});
      });

      test('gefälschter sender im Inhalt wird ignoriert', () {
        final m = withMessage(<Event>[
          neu(r'$r1', '👍', claimed: '@cara:fake.test'),
          neu('txn2', '🎉', sender: me, claimed: ben, encrypted: false, status: EventStatus.sending),
        ]);
        expect(m.reactions, isEmpty);
      });

      test('Fehler und Redaktionen zählen nicht', () {
        final m = withMessage(<Event>[
          neu('txn1', '👍', sender: me, encrypted: false, status: EventStatus.error),
          neu('txn2', '😀', sender: me, status: EventStatus.error),
          neu(r'$r3', '🎉', unsigned: redactedBecause()),
        ]);
        expect(m.reactions, isEmpty);
      });

      test('alte und neue Reaktion desselben Mitglieds zählen einmal, verschiedene Mitglieder je einmal', () {
        final m = withMessage(<Event>[
          react(r'$alt', '👍'),
          neu(r'$r1', '👍'),
          neu(r'$r2', '👍'),
          neu(r'$r3', '👍', sender: '@cara:fake.test'),
          react(r'$alt2', '🎉'),
        ]);
        expect(m.reactions['👍'], <String>{ben, '@cara:fake.test'});
        expect(m.reactions['🎉'], <String>{ben});
      });

      test('maxReactionKeys gilt für die Summe aus alten und neuen', () {
        final events = <Event>[
          for (var i = 0; i < 8; i++) react('\$alt$i', String.fromCharCode(0x1F600 + i)),
          for (var i = 8; i < 30; i++) neu('\$neu$i', String.fromCharCode(0x1F600 + i)),
        ];
        expect(withMessage(events).reactions.length, ChatMapper.maxReactionKeys);
      });

      test('Ziel in einer anderen Zeitleiste zählt nicht', () {
        expect(withMessage(<Event>[neu(r'$r1', '👍', target: r'$anderswo')]).reactions, isEmpty);
      });

      test('die Reaktion selbst erscheint nicht als Nachricht', () {
        expect(map(<Event>[neu(r'$r1', '👍')], me: me), isEmpty);
      });

      test('ein Wurf in der Sammelschleife leert den Chat nicht', () {
        final bad = _ThrowingEvent(room);
        final t = timeline(<Event>[neu(r'$r1', '👍'), bad, ev(r'$a', text('Hi'), ts: 1)]);
        bad.armed = true;
        final m = ChatMapper.messages(t, threadId: 'family', sends: sends, myUserId: me);
        expect(m.single.body, 'Hi');
        expect(m.single.reactions.keys, <String>['👍']);
      });

      group('Doppelprüfung vor dem Senden', () {
        Event target() => ev(r'$a', text('Hi'), ts: 1);

        bool has(List<Event> reactions, {String key = '👍'}) {
          final e = target();
          return ChatMapper.hasOwnReaction(timeline(<Event>[...reactions.reversed, e]), e, key, me);
        }

        test('jedes eigene Ereignis zählt, unabhängig von Status und Quelle', () {
          expect(has(<Event>[neu(r'$r', '👍', sender: me)]), isTrue, reason: 'verschlüsselt angekommen');
          for (final s in <EventStatus>[EventStatus.sending, EventStatus.sent, EventStatus.synced]) {
            expect(has(<Event>[neu(r'$r', '👍', sender: me, encrypted: false, status: s)]), isTrue, reason: '$s');
          }
        });

        test('Fehler, Redaktion, anderes Ziel, anderes Emoji und fremder Absender zählen nicht', () {
          expect(has(<Event>[]), isFalse);
          expect(has(<Event>[neu('txn', '👍', sender: me, encrypted: false, status: EventStatus.error)]), isFalse);
          expect(has(<Event>[neu(r'$r', '👍', sender: me, unsigned: redactedBecause())]), isFalse);
          expect(has(<Event>[neu(r'$r', '👍', sender: me, target: r'$b')]), isFalse);
          expect(has(<Event>[neu(r'$r', '👍', sender: me)], key: '🎉'), isFalse);
          expect(has(<Event>[neu(r'$r', '👍')]), isFalse);
          expect(has(<Event>[neu(r'$r', '👍', claimed: me)]), isFalse);
        });

        Event alt({int? status, Map<String, Object?>? unsigned, String sender = me}) => ev(r'$alt', <String, Object?>{
              'm.relates_to': <String, Object?>{'rel_type': 'm.annotation', 'event_id': r'$a', 'key': '👍'},
            }, type: 'm.reaction', sender: sender, ts: 5, status: status, unsigned: unsigned);

        test('alte m.reaction: eigene zählt, gescheiterte, redigierte und fremde nicht', () {
          expect(has(<Event>[alt()]), isTrue);
          expect(has(<Event>[alt()], key: '🎉'), isFalse);
          expect(has(<Event>[alt(status: EventStatus.error.intValue)]), isFalse);
          expect(has(<Event>[alt(unsigned: redactedBecause())]), isFalse);
          expect(has(<Event>[alt(sender: ben)]), isFalse);
        });
      });
    });
  });

  test('#29: Verifizierungsanfrage als Raumnachricht erscheint nicht als Chat-Text', () {
    final m = map(<Event>[
      ev(r'$a', text('Hallo'), ts: 1),
      ev(r'$v', <String, Object?>{
        'msgtype': 'm.key.verification.request',
        'body': 'Attempting verification request. (m.key.verification.request) Apparently your client doesn\'t support this',
        'from_device': 'DEV',
        'methods': <String>['m.sas.v1'],
        'to': '@anna:fake.test',
      }, ts: 2),
    ]);
    expect(m.map((e) => e.body), <String>['Hallo']);
  });

  group('#35: nicht lesbare Ereignisse vor dem eigenen Beitritt', () {
    const me = '@ida:fake.test';
    Event member(String id, String membership, {String? prev, int ts = 0}) => Event.fromJson(<String, Object?>{
          'type': 'm.room.member',
          'event_id': id,
          'sender': me,
          'state_key': me,
          'origin_server_ts': ts,
          'content': <String, Object?>{'membership': membership, 'displayname': 'Ida'},
          if (prev != null) 'unsigned': <String, Object?>{'prev_content': <String, Object?>{'membership': prev}},
        }, room);
    Event encrypted(String id, int ts) => ev(id, <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
        type: 'm.room.encrypted', ts: ts);

    List<ChatMessage> mapAs(List<Event> chronological) => map(chronological, me: me);

    test('werden zu einem Hinweis zusammengefasst, spätere bleiben einzeln sichtbar', () {
      final m = mapAs(<Event>[
        encrypted(r'$e1', 10),
        encrypted(r'$e2', 20),
        encrypted(r'$e3', 30),
        member(r'$j', 'join', prev: 'invite', ts: 40),
        ev(r'$t', text('Willkommen!'), ts: 50),
        encrypted(r'$e4', 60),
      ]);
      expect(m.first.beforeJoin, isTrue);
      expect(m.where((e) => e.beforeJoin), hasLength(1));
      expect(m.where((e) => e.undecryptable && !e.beforeJoin).map((e) => e.id), <String>[r'$e4']);
      expect(m.map((e) => e.id), <String>[ChatMapper.beforeJoinId, r'$t', r'$e4']);
    });

    test('#139: Lesbare Reaktion bleibt unsichtbar, nicht entschlüsselbare geht in den Hinweis', () {
      final m = mapAs(<Event>[
        ev(r'$r', ReactionCodec.encode(target: r'$t', key: '👍', sender: '@ben:fake.test'), type: ReactionCodec.type, ts: 10),
        encrypted(r'$e1', 20),
        member(r'$j', 'join', prev: 'invite', ts: 30),
        ev(r'$t', text('Willkommen!'), ts: 40),
      ]);
      expect(m.map((e) => e.id), <String>[ChatMapper.beforeJoinId, r'$t']);
      expect(m.last.reactions.keys, <String>['👍']);
    });

    group('#65: Zähler ungelesener Nachrichten', () {
      int unread(List<Event> chronological, int server) =>
          ChatMapper.unreadReadable(timeline(chronological.reversed.toList()), serverCount: server, myUserId: me);

      test('#139: Reaktionen zählen nicht, eine eigene stoppt die Zählung nicht', () {
        Event reaction(String id, String sender, int ts) => ev(
              id,
              ReactionCodec.encode(target: r'$a', key: '👍', sender: sender),
              type: ReactionCodec.type,
              sender: sender,
              ts: ts,
            );
        final events = <Event>[
          ev(r'$a', text('eins'), ts: 10),
          reaction(r'$r1', me, 20),
          ev(r'$b', text('zwei'), ts: 30),
          reaction(r'$r2', '@ben:fake.test', 40),
        ];
        expect(unread(events, 9), 2);
      });

      test('nicht lesbare Ereignisse und App-Daten zählen nicht, nur die lesbare Nachricht', () {
        final events = <Event>[
          encrypted(r'$e1', 10),
          encrypted(r'$e2', 20),
          member(r'$j', 'join', prev: 'invite', ts: 40),
          encrypted(r'$e3', 45), // z. B. noch nicht entschlüsselte Kalenderänderung
          ev(r'$cal', <String, Object?>{'id': 'x'}, type: 'de.inneso.familynexus.event', ts: 50),
          ev(r'$t', text('Hallo von Nutzer 1'), ts: 60),
        ];
        expect(unread(events, 8), 1, reason: 'Server meldet 8, lesbar ist eine');
      });

      test('Server meldet 0: nichts ungelesen; mehr Nachrichten als der Server: Server ist Obergrenze', () {
        final events = <Event>[ev(r'$a', text('eins'), ts: 1), ev(r'$b', text('zwei'), ts: 2)];
        expect(unread(events, 0), 0);
        expect(unread(events, 1), 1);
        expect(unread(events, 5), 2);
      });

      test('zählt nur nach der eigenen Lesemarke bzw. eigenen Nachricht', () {
        room.roomAccountData['m.fully_read'] =
            BasicEvent(type: 'm.fully_read', content: <String, Object?>{'event_id': r'$b'});
        final events = <Event>[
          ev(r'$a', text('alt'), ts: 1),
          ev(r'$b', text('gelesen'), ts: 2),
          ev(r'$c', text('neu'), ts: 3),
        ];
        expect(unread(events, 3), 1);
        room.roomAccountData.remove('m.fully_read');
        final withOwn = <Event>[
          ev(r'$a', text('alt'), ts: 1),
          ev(r'$own', text('meine Antwort'), sender: me, ts: 2),
          ev(r'$c', text('neu'), ts: 3),
          ev(r'$edit', text('* neu', extra: <String, Object?>{
            'm.relates_to': <String, Object?>{'rel_type': 'm.replace', 'event_id': r'$c'},
            'm.new_content': <String, Object?>{'msgtype': 'm.text', 'body': 'neu'},
          }), ts: 4),
        ];
        expect(unread(withOwn, 3), 1, reason: 'Bearbeitung zählt nicht extra');
      });
    });

    test('Namensänderung nach dem Beitritt zählt nicht als Beitritt', () {
      final m = mapAs(<Event>[
        encrypted(r'$e1', 10),
        member(r'$j', 'join', prev: 'invite', ts: 20),
        encrypted(r'$e2', 30),
        member(r'$n', 'join', prev: 'join', ts: 40),
      ]);
      expect(m.map((e) => e.id), <String>[ChatMapper.beforeJoinId, r'$e2']);
    });

    test('Beitritt nicht in der geladenen Zeitleiste: nichts wird ausgeblendet', () {
      final m = mapAs(<Event>[encrypted(r'$e1', 10), encrypted(r'$e2', 20)]);
      expect(m.map((e) => e.id), <String>[r'$e1', r'$e2']);
      expect(m.any((e) => e.beforeJoin), isFalse);
    });
  });

  group('#138: Klartext in verschlüsselten Räumen', () {
    const me = '@ida:fake.test';
    const room138 = '!room:fake.test';

    Event own(String id, String body, EventStatus status, {String? txid, bool encrypted = false, int ts = 1000}) => ev(
          id,
          text(body),
          sender: me,
          status: status.intValue,
          encrypted: encrypted,
          ts: ts,
          unsigned: <String, Object?>{'transaction_id': ?txid},
        );

    /// Merkt eine laufende Sendung; [Completer.complete] beendet sie.
    Completer<String?> running(String txid, {String tail = 'x', String threadId = 'family', String roomId = room138}) {
      final c = Completer<String?>();
      unawaited(sends.run(txid: txid, threadId: threadId, roomId: roomId, tail: tail, send: () => c.future));
      return c;
    }

    /// Sendung, deren Versuch gescheitert ist: bleibt offen.
    Future<void> failed(String txid, {String threadId = 'family', String roomId = room138}) =>
        sends.run(txid: txid, threadId: threadId, roomId: roomId, tail: 'x', send: () async => null);

    test('Klartext anderer wird verworfen, Verschlüsseltes bleibt sichtbar', () {
      final m = map(<Event>[
        ev(r'$plain', text('gefälscht'), encrypted: false, ts: 1),
        ev(r'$real', text('echt'), ts: 2),
      ], me: me);
      expect(m.map((e) => e.body), <String>['echt']);
    });

    test('Klartext mit angeblich eigenem Absender und Status synced wird verworfen', () {
      expect(map(<Event>[ev(r'$a', text('gefälscht'), sender: me, encrypted: false)], me: me), isEmpty);
    });

    test('laufende eigene Sendung bleibt sichtbar und zeigt „wird gesendet“', () async {
      final c = running('txn1');
      final m = map(<Event>[own('txn1', 'Hallo', EventStatus.sending, txid: 'txn1')], me: me).single;
      expect(m.status, MessageStatus.sending);
      expect(m.retryable, isFalse, reason: 'während des Laufs nie wiederholbar');
      c.complete(r'$server');
    });

    test('der Zustand „gesendet“ kommt vor der Rückkehr von run: sichtbar, solange die Sendung läuft', () async {
      final c = running('txn1');
      expect(map(<Event>[own(r'$server', 'Hallo', EventStatus.sent, txid: 'txn1')], me: me), hasLength(1));
      c.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(map(<Event>[own(r'$server', 'Hallo', EventStatus.sent, txid: 'txn1')], me: me), isEmpty, reason: 'Sendung läuft nicht mehr');
    });

    test('„gesendet“ mit der Kennung und dem Text aus der Antwort des Servers ist sichtbar', () async {
      await sends.run(txid: 'txn1', threadId: 'family', roomId: room138, tail: 'Hallo', send: () async => r'$server');
      expect(map(<Event>[own(r'$server', 'Hallo', EventStatus.sent)], me: me).single.body, 'Hallo');
      expect(map(<Event>[own(r'$server', '> <@b:x> Frage\n\nHallo', EventStatus.sent)], me: me), hasLength(1), reason: 'Antwort stellt das Zitat voran');
    });

    test('nur exakt „gesendet“ nutzt die gemerkte Kennung: synced ohne Quelle bleibt draußen', () async {
      await sends.run(txid: 'txn1', threadId: 'family', roomId: room138, tail: 'Hallo', send: () async => r'$server');
      expect(map(<Event>[own(r'$server', 'Hallo', EventStatus.synced)], me: me), isEmpty, reason: 'den Status setzt der Server');
    });

    test('gefälschtes „gesendet“ ohne Treffer oder mit fremdem Text wird verworfen', () async {
      await sends.run(txid: 'txn1', threadId: 'family', roomId: room138, tail: 'Hallo', send: () async => r'$server');
      expect(map(<Event>[own(r'$anders', 'Hallo', EventStatus.sent)], me: me), isEmpty, reason: 'unbekannte Kennung');
      expect(map(<Event>[own(r'$server', 'Zahl an Konto 123', EventStatus.sent)], me: me), isEmpty, reason: 'falscher Text');
    });

    test('fremdes Klartext-Ereignis nützt kein Status und keine bekannte Kennung', () async {
      await sends.run(txid: 'txn1', threadId: 'family', roomId: room138, tail: 'Hallo', send: () async => r'$server');
      final c = running('txn2');
      for (final s in <EventStatus>[EventStatus.sent, EventStatus.sending, EventStatus.error, EventStatus.synced]) {
        expect(
          map(<Event>[
            ev(r'$server', text('Hallo'), status: s.intValue, encrypted: false, unsigned: <String, Object?>{'transaction_id': 'txn2'}),
          ], me: me),
          isEmpty,
          reason: '$s',
        );
      }
      c.complete(null);
    });

    test('„wird gesendet“ ohne laufende Sendung gilt als gescheitert (Neustart)', () {
      final m = map(<Event>[own('txn1', 'alt', EventStatus.sending, txid: 'txn1')], me: me).single;
      expect(m.status, MessageStatus.failed);
      expect(m.retryable, isFalse, reason: 'nach dem Neustart liegt nichts mehr vor');
    });

    test('„wird gesendet“ mit offener, nicht laufender Sendung: Ausnahme ohne Fehler-Echo hängt nicht', () async {
      await failed('txn1');
      final m = map(<Event>[own('txn1', 'Hallo', EventStatus.sending, txid: 'txn1')], me: me).single;
      expect(m.status, MessageStatus.failed);
      expect(m.retryable, isTrue);
    });

    test('Fehler ohne offene Sendung ist sichtbar, aber nicht wiederholbar', () {
      final m = map(<Event>[own('txn1', 'Hallo', EventStatus.error, txid: 'txn1')], me: me).single;
      expect(m.status, MessageStatus.failed);
      expect(m.retryable, isFalse);
    });

    test('wiederholbar nur im gleichen Thread und Raum', () async {
      await failed('txn1');
      await failed('txn2', threadId: '!dm:fake.test', roomId: '!dm:fake.test');
      await failed('txn3', roomId: '!anderer:fake.test');
      final m = map(<Event>[
        own('txn1', 'eins', EventStatus.error, txid: 'txn1', ts: 1),
        own('txn2', 'zwei', EventStatus.error, txid: 'txn2', ts: 2),
        own('txn3', 'drei', EventStatus.error, txid: 'txn3', ts: 3),
      ], me: me);
      expect(m.map((e) => e.retryable), <bool>[true, false, false]);
    });

    Map<String, Object?> edit(String target, String body) => text('* $body', extra: <String, Object?>{
          'm.relates_to': <String, Object?>{'rel_type': 'm.replace', 'event_id': target},
          'm.new_content': <String, Object?>{'msgtype': 'm.text', 'body': body},
        });

    test('Klartext-Bearbeitung mit späterem Zeitstempel verdrängt die echte nicht', () {
      final m = map(<Event>[
        ev(r'$a', text('Original'), ts: 1),
        ev(r'$e', edit(r'$a', 'echt bearbeitet'), ts: 2),
        ev(r'$f', edit(r'$a', 'gefälscht'), encrypted: false, ts: 9),
      ]);
      expect(m.map((e) => e.body), <String>['echt bearbeitet']);
    });

    test('die neueste von zwei echten Bearbeitungen gewinnt, unabhängig von der Listenfolge', () {
      expect(map(<Event>[ev(r'$a', text('Original'), ts: 1), ev(r'$1', edit(r'$a', 'erste'), ts: 2), ev(r'$2', edit(r'$a', 'zweite'), ts: 3)]).map((e) => e.body), <String>['zweite']);
      expect(map(<Event>[ev(r'$a', text('Original'), ts: 1), ev(r'$2', edit(r'$a', 'zweite'), ts: 3), ev(r'$1', edit(r'$a', 'erste'), ts: 2)]).map((e) => e.body), <String>['zweite']);
    });

    test('m.new_content als Text ist keine Bearbeitung', () {
      final m = map(<Event>[ev(r'$a', text('Original'), ts: 1), ev(r'$e', <String, Object?>{...edit(r'$a', 'x'), 'm.new_content': 'kein Objekt'}, ts: 2)]);
      expect(m.first.body, 'Original');
    });

    test('Klartext-Bearbeitung allein ändert nichts und erscheint nicht', () {
      final m = map(<Event>[ev(r'$a', text('Original'), ts: 1), ev(r'$f', edit(r'$a', 'gefälscht'), encrypted: false, ts: 9)]);
      expect(m.map((e) => e.body), <String>['Original']);
    });

    test('Bearbeitung anderen Typs oder anderen Absenders wird ignoriert', () {
      final m = map(<Event>[
        ev(r'$a', text('Original'), ts: 1),
        ev(r'$t', edit(r'$a', 'anderer Typ'), type: 'de.inneso.familynexus.event', ts: 2),
        ev(r'$s', edit(r'$a', 'anderer Absender'), sender: '@cara:fake.test', ts: 3),
      ]);
      expect(m.map((e) => e.body), <String>['Original']);
    });

    test('Hülle „m.replace“ ohne m.new_content: bleibt eine normale Nachricht und ersetzt nichts', () {
      final m = map(<Event>[
        ev(r'$a', text('Original'), ts: 1),
        ev(r'$b', text('Meine Antwort', extra: <String, Object?>{
          'm.relates_to': <String, Object?>{'rel_type': 'm.replace', 'event_id': r'$a'},
        }), ts: 2),
      ]);
      expect(m.map((e) => e.body), <String>['Original', 'Meine Antwort']);
    });

    test('entfernte Nachricht zeigt keine Bearbeitung', () {
      final redacted = ev(r'$a', text('Original'), ts: 1, unsigned: <String, Object?>{
        'redacted_because': <String, Object?>{
          'type': 'm.room.redaction',
          'event_id': r'$r',
          'sender': '@ben:fake.test',
          'origin_server_ts': 2,
          'content': <String, Object?>{},
        },
      });
      expect(map(<Event>[redacted, ev(r'$e', edit(r'$a', 'neu'), ts: 3)]), isEmpty);
    });

    test('m.reaction bleibt hier zulässig (#139)', () {
      final m = map(<Event>[
        ev(r'$a', text('Hi'), ts: 1),
        ev(r'$r', <String, Object?>{
          'm.relates_to': <String, Object?>{'rel_type': 'm.annotation', 'event_id': r'$a', 'key': '👍'},
        }, type: 'm.reaction', encrypted: false, ts: 2),
      ]).single;
      expect(m.reactions.keys, <String>['👍']);
    });

    group('Ungelesen', () {
      int unread(List<Event> chronological, int server) =>
          ChatMapper.unreadReadable(timeline(chronological.reversed.toList()), serverCount: server, myUserId: me);

      test('Klartext anderer zählt nicht', () {
        expect(unread(<Event>[ev(r'$a', text('Lock'), encrypted: false, ts: 1), ev(r'$b', text('echt'), ts: 2)], 5), 1);
      });

      test('angeblich eigener Klartext stoppt die Zählung nicht', () {
        final events = <Event>[
          ev(r'$a', text('eins'), ts: 1),
          ev(r'$own', text('gefälscht'), sender: me, encrypted: false, ts: 2),
          ev(r'$b', text('zwei'), ts: 3),
        ];
        expect(unread(events, 5), 2);
      });

      test('eigene verschlüsselte Nachricht und Mitglieds-Ereignis stoppen sie', () {
        expect(
          unread(<Event>[ev(r'$a', text('alt'), ts: 1), ev(r'$own', text('meins'), sender: me, ts: 2), ev(r'$b', text('neu'), ts: 3)], 5),
          1,
        );
        final member = Event.fromJson(<String, Object?>{
          'type': 'm.room.member',
          'event_id': r'$m',
          'sender': me,
          'state_key': me,
          'origin_server_ts': 2,
          'content': <String, Object?>{'membership': 'join'},
        }, room);
        expect(unread(<Event>[ev(r'$a', text('alt'), ts: 1), member, ev(r'$b', text('neu'), ts: 3)], 5), 1);
      });

      test('eigener verschlüsselter Termin stoppt sie nicht', () {
        final events = <Event>[
          ev(r'$a', text('eins'), ts: 1),
          ev(r'$cal', <String, Object?>{'id': 'x'}, type: 'de.inneso.familynexus.event', sender: me, ts: 2),
          ev(r'$b', text('zwei'), ts: 3),
        ];
        expect(unread(events, 5), 2);
      });

      test('echte Nachricht mit Hülle „m.replace“ ohne m.new_content zählt', () {
        final events = <Event>[
          ev(r'$a', text('Original'), ts: 1),
          ev(r'$b', text('Antwort', extra: <String, Object?>{
            'm.relates_to': <String, Object?>{'rel_type': 'm.replace', 'event_id': r'$a'},
          }), ts: 2),
        ];
        expect(unread(events, 5), 2);
      });
    });
  });

  group('#60: Absender mit gelöschtem Konto', () {
    const gone = '@ida:fake.test';
    Event member(String id, String membership, {String? name, String? prevName, int ts = 0}) =>
        Event.fromJson(<String, Object?>{
          'type': 'm.room.member',
          'event_id': id,
          'sender': gone,
          'state_key': gone,
          'origin_server_ts': ts,
          'content': <String, Object?>{'membership': membership, 'displayname': ?name},
          if (prevName != null)
            'unsigned': <String, Object?>{
              'prev_content': <String, Object?>{'membership': 'join', 'displayname': prevName},
            },
        }, room);

    test('Name aus früheren Mitglieds-Ereignissen statt Matrix-ID', () {
      // Löschen mit Datenlöschung: erst Name geleert (Profiländerung), dann Austritt ohne Namen.
      final leave = member(r'$leave', 'leave', ts: 40);
      room.setState(leave);
      final m = map(<Event>[
        member(r'$join', 'join', name: 'Ida', ts: 10),
        ev(r'$t', text('Tschüss'), sender: gone, ts: 20),
        member(r'$clear', 'join', prevName: 'Ida', ts: 30),
        leave,
      ]);
      expect(m.single.senderName, 'Ida');
    });

    test('kein früherer Name geladen (z. B. nach Wiederherstellung): leer = „Ehemaliges Mitglied“', () {
      room.setState(member(r'$leave', 'leave', ts: 40));
      final m = map(<Event>[ev(r'$t', text('Tschüss'), sender: gone, ts: 20)]);
      expect(m.single.senderName, isEmpty);
    });

    test('noch Mitglied ohne Namen: Matrix-ID wie bisher', () {
      final m = map(<Event>[ev(r'$t', text('Hallo'), sender: '@neu:fake.test', ts: 20)]);
      expect(m.single.senderName, '@neu:fake.test');
    });
  });
}
