import 'package:family_nexus/data/matrix/chat_mapper.dart';
import 'package:family_nexus/data/matrix/event_trust.dart';
import 'package:family_nexus/data/matrix/local_sends.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
// ignore: implementation_imports
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// #138: Prüft mit echten SDK-Objekten, worauf sich Vertrauen stützt, und das Rennen „Sync-Echo vor Sendeantwort“.
void main() {
  const me = '@ida:fake.test';
  const roomId = '!room:fake.test';
  const calendarType = 'de.inneso.familynexus.event';
  const ticketType = 'de.inneso.familynexus.invite';
  late Client client;
  late Room room;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    Logs().level = Level.wtf; // `senderFromMemoryOrFallback` fragt ohne Server nach dem Profil
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    client = Client('test', database: await MatrixSdkDatabase.init('trust${n++}', database: db));
    room = Room(id: roomId, client: client);
    client.rooms.add(room);
  });

  Map<String, Object?> source(String id, {String type = 'm.room.encrypted', String sender = me}) => <String, Object?>{
        'type': type,
        'event_id': id,
        'sender': sender,
        'origin_server_ts': 1000,
        'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
      };

  Map<String, Object?> plain(
    String id, {
    String type = 'm.room.message',
    String sender = me,
    int? status,
    String? txid,
    Map<String, Object?>? content,
    Map<String, Object?>? extra,
  }) =>
      <String, Object?>{
        'type': type,
        'event_id': id,
        'sender': sender,
        'origin_server_ts': 1000,
        'content': content ?? <String, Object?>{'msgtype': 'm.text', 'body': 'Hallo'},
        'unsigned': <String, Object?>{'transaction_id': ?txid, messageSendingStatusKey: ?status},
        ...?extra,
      };

  Event decrypted(String id, {String type = 'm.room.message', Map<String, Object?>? content}) =>
      Event.fromJson(<String, Object?>{...plain(id, type: type, content: content), 'original_source': source(id)}, room);

  group('arrivedEncrypted', () {
    test('von der Entschlüsselung gesetzte Quelle zählt', () {
      final e = Event(
        content: <String, Object?>{'msgtype': 'm.text', 'body': 'x'},
        type: EventTypes.Message,
        senderId: me,
        eventId: r'$a',
        room: room,
        originServerTs: DateTime.now(),
        originalSource: MatrixEvent.fromJson(source(r'$a')),
      );
      expect(arrivedEncrypted(e), isTrue);
    });

    test('aus der Datenbank gelesene Quelle zählt, eine Quelle anderen Typs nicht', () {
      expect(arrivedEncrypted(decrypted(r'$a')), isTrue);
      final other = Event.fromJson(<String, Object?>{...plain(r'$b'), 'original_source': source(r'$b', type: 'm.room.message')}, room);
      expect(arrivedEncrypted(other), isFalse);
    });

    test('`original_source` im Sync-JSON ist wirkungslos', () {
      final json = <String, Object?>{...plain(r'$a'), 'original_source': source(r'$a')};
      final fromSync = Event.fromMatrixEvent(MatrixEvent.fromJson(json), room);
      expect(fromSync.originalSource, isNull);
      expect(arrivedEncrypted(fromSync), isFalse);
      expect(arrivedEncrypted(Event.fromJson(fromSync.toJson(), room)), isFalse, reason: 'auch nicht nach dem Speichern');
    });

    test('`original_source` in `unsigned` ist wirkungslos', () {
      final json = plain(r'$a');
      (json['unsigned']! as Map<String, Object?>)['original_source'] = source(r'$a');
      expect(arrivedEncrypted(Event.fromMatrixEvent(MatrixEvent.fromJson(json), room)), isFalse);
    });

    test('Klartext mit bekannter Transaktions-ID, Kennung und jedem Status, eigener Absender: nicht vertrauenswürdig', () {
      for (final status in EventStatus.values) {
        for (final type in <String>['m.room.message', calendarType, ticketType]) {
          final e = Event.fromMatrixEvent(
            MatrixEvent.fromJson(plain(r'$bekannt', type: type, status: status.intValue, txid: 'txn1')),
            room,
          );
          expect(e.status, status, reason: 'den Status setzt der Server aus `unsigned`');
          expect(e.transactionId, 'txn1');
          expect(arrivedEncrypted(e), isFalse, reason: '$type $status');
        }
      }
    });
  });

  group('BoundedIdSet', () {
    test('meldet Neues, begrenzt, die älteste fällt heraus', () {
      final s = BoundedIdSet(2);
      expect(s.add('a'), isTrue);
      expect(s.add('a'), isFalse);
      s.add('b');
      s.add('c');
      expect(s.add('b'), isFalse);
      expect(s.add('a'), isTrue, reason: 'a war herausgefallen');
    });
  });

  group('isEchoCandidate', () {
    Event of(Map<String, Object?> json) => Event.fromJson(json, room);

    test('eigenes Ereignis im Status synced ohne Quelle', () {
      expect(isEchoCandidate(of(plain(r'$a')), me), isTrue);
    });

    test('alle anderen nicht', () {
      expect(isEchoCandidate(of(plain(r'$a', sender: '@ben:fake.test')), me), isFalse, reason: 'fremd');
      expect(isEchoCandidate(of(plain(r'$a', status: EventStatus.sent.intValue)), me), isFalse, reason: 'noch nicht synced');
      expect(isEchoCandidate(of(plain(r'$a', status: EventStatus.error.intValue)), me), isFalse, reason: 'Fehler');
      expect(isEchoCandidate(of(plain(r'$a', type: 'm.room.encrypted')), me), isFalse, reason: 'nicht entschlüsselt');
      expect(isEchoCandidate(decrypted(r'$a'), me), isFalse, reason: 'hat eine Quelle');
      expect(
        isEchoCandidate(of(<String, Object?>{...plain(r'$a', type: 'm.room.member'), 'state_key': me}), me),
        isFalse,
        reason: 'Zustandsereignis',
      );
      final redacted = plain(r'$a');
      (redacted['unsigned']! as Map<String, Object?>)['redacted_because'] = source(r'$r');
      expect(isEchoCandidate(of(redacted), me), isFalse, reason: 'entfernt');
    });
  });

  group('Sync-Echo vor Sendeantwort', () {
    Future<void> sync(Map<String, Object?> json) => client.database.transaction(
          () => client.handleSync(
            SyncUpdate(
              nextBatch: '',
              rooms: RoomsUpdate(join: <String, JoinedRoomUpdate>{
                roomId: JoinedRoomUpdate(timeline: TimelineUpdate(events: <MatrixEvent>[MatrixEvent.fromJson(json)])),
              }),
            ),
          ),
        );

    /// Wie das SDK beim Rennen: Das Sync-Echo liegt entschlüsselt in Datenbank und Zeitleiste, dann ersetzt die verspätete
    /// Sendeantwort es im Speicher durch ein Ereignis ohne Quelle. Die Datenbank bleibt richtig.
    Future<Timeline> raced(String id, {String type = 'm.room.message', Map<String, Object?>? content}) async {
      final echo = decrypted(id, type: type, content: content);
      await client.database.storeEventUpdate(roomId, echo, EventUpdateType.timeline, client);
      final t = Timeline(room: room, chunk: TimelineChunk(events: <Event>[echo]));
      addTearDown(t.cancelSubscriptions);
      await sync(plain(id, type: type, status: EventStatus.sent.intValue, txid: 'txn-$id', content: content));
      return t;
    }

    Future<bool> repair(Timeline t, [EchoRepair? r, bool Function()? isCurrent]) =>
        (r ?? EchoRepair()).run(t, me: me, database: client.database, isCurrent: isCurrent ?? () => true);

    test('das SDK verdrängt wirklich die Quelle, die Datenbank behält sie', () async {
      final t = await raced(r'$a');
      expect(t.events.single.status, EventStatus.synced);
      expect(t.events.single.originalSource, isNull);
      expect(arrivedEncrypted((await client.database.getEventById(r'$a', room))!), isTrue);
    });

    test('Chat: die Reparatur stellt das Ereignis wieder her, die Nachricht ist sichtbar', () async {
      final t = await raced(r'$a');
      final sends = LocalSends();
      expect(ChatMapper.messages(t, threadId: 'family', sends: sends, myUserId: me), isEmpty, reason: 'ohne Reparatur verschwände sie');

      expect(await repair(t), isTrue);
      expect(arrivedEncrypted(t.events.single), isTrue);
      expect(ChatMapper.messages(t, threadId: 'family', sends: sends, myUserId: me).single.status, MessageStatus.sent);
    });

    test('Kalender und Link-Vermerk: auch andere Sendewege werden repariert', () async {
      for (final (i, type) in <String>[calendarType, ticketType].indexed) {
        final t = await raced('\$t$i', type: type, content: <String, Object?>{'v': 1});
        expect(arrivedEncrypted(t.events.single), isFalse);
        await repair(t);
        expect(arrivedEncrypted(t.events.single), isTrue, reason: type);
        expect(t.events.single.type, type);
      }
    });

    test('Wiederholen: gleiche Reparatur, das Echo kommt vom selben Weg', () async {
      final t = await raced(r'$w');
      await repair(t, EchoRepair());
      expect(arrivedEncrypted(t.events.single), isTrue);
    });

    test('gefälschtes Ereignis ohne gespeicherte Quelle bleibt draußen', () async {
      await client.database.storeEventUpdate(
        roomId,
        Event.fromJson(plain(r'$f'), room),
        EventUpdateType.timeline,
        client,
      );
      final forged = Event.fromMatrixEvent(MatrixEvent.fromJson(plain(r'$f', txid: 'txn1')), room);
      final t = Timeline(room: room, chunk: TimelineChunk(events: <Event>[forged]));
      addTearDown(t.cancelSubscriptions);

      await repair(t);
      expect(arrivedEncrypted(t.events.single), isFalse);
      expect(ChatMapper.messages(t, threadId: 'family', sends: LocalSends(), myUserId: me), isEmpty);
    });

    test('Quelle ohne Verschlüsselung: Zeitleiste bleibt unverändert', () async {
      await client.database.storeEventUpdate(roomId, Event.fromJson(plain(r'$x'), room), EventUpdateType.timeline, client);
      final forged = Event.fromMatrixEvent(MatrixEvent.fromJson(plain(r'$x', txid: 'txn1')), room);
      final t = Timeline(room: room, chunk: TimelineChunk(events: <Event>[forged]));
      addTearDown(t.cancelSubscriptions);
      await repair(t);
      expect(identical(t.events.single, forged), isTrue);
    });

    test('Kennung unbekannt in der Datenbank: nichts geschieht', () async {
      final forged = Event.fromMatrixEvent(MatrixEvent.fromJson(plain(r'$neu')), room);
      final t = Timeline(room: room, chunk: TimelineChunk(events: <Event>[forged]));
      addTearDown(t.cancelSubscriptions);
      expect(await repair(t), isTrue);
      expect(identical(t.events.single, forged), isTrue);
    });

    test('jede Kennung wird nur einmal nachgeschlagen', () async {
      final db = _CountingDatabase(client.database);
      final forged = Event.fromMatrixEvent(MatrixEvent.fromJson(plain(r'$f')), room);
      final t = Timeline(room: room, chunk: TimelineChunk(events: <Event>[forged]));
      addTearDown(t.cancelSubscriptions);
      final r = EchoRepair();
      for (var i = 0; i < 3; i++) {
        await r.run(t, me: me, database: db, isCurrent: () => true);
      }
      expect(db.reads, 1);
      r.clear();
      await r.run(t, me: me, database: db, isCurrent: () => true);
      expect(db.reads, 2, reason: 'clear beim Abmelden');
    });

    test('Zustandsereignisse verursachen keinen Datenbankzugriff', () async {
      final db = _CountingDatabase(client.database);
      final member = Event.fromJson(<String, Object?>{...plain(r'$m', type: 'm.room.member'), 'state_key': me}, room);
      final t = Timeline(room: room, chunk: TimelineChunk(events: <Event>[member]));
      addTearDown(t.cancelSubscriptions);
      await EchoRepair().run(t, me: me, database: db, isCurrent: () => true);
      expect(db.reads, 0);
    });

    test('nach dem await wird der Index neu gesucht', () async {
      final t = await raced(r'$a');
      final db = _CountingDatabase(client.database, onRead: () {
        t.events.insert(0, decrypted(r'$davor')); // neues Ereignis während des Lesens
      });
      await EchoRepair().run(t, me: me, database: db, isCurrent: () => true);
      expect(t.events.map((e) => e.eventId), <String>[r'$davor', r'$a']);
      expect(arrivedEncrypted(t.events.last), isTrue);
    });

    test('verschwindet das Ereignis während des Lesens, passiert nichts', () async {
      final t = await raced(r'$a');
      final db = _CountingDatabase(client.database, onRead: t.events.clear);
      expect(await EchoRepair().run(t, me: me, database: db, isCurrent: () => true), isTrue);
      expect(t.events, isEmpty);
    });

    test('ein neuer Client während des Lesens beendet die Reparatur, ohne etwas zu ändern', () async {
      final t = await raced(r'$a');
      var current = true;
      final db = _CountingDatabase(client.database, onRead: () => current = false);
      expect(await EchoRepair().run(t, me: me, database: db, isCurrent: () => current), isFalse);
      expect(arrivedEncrypted(t.events.single), isFalse);
    });

    test('die Schleife läuft über eine Kopie: Änderungen der Zeitleiste stören sie nicht', () async {
      final t = await raced(r'$a');
      final second = Event.fromMatrixEvent(MatrixEvent.fromJson(plain(r'$b')), room);
      t.events.add(second);
      final db = _CountingDatabase(client.database, onRead: () => t.events.add(decrypted('\$x${t.events.length}')));
      await EchoRepair().run(t, me: me, database: db, isCurrent: () => true);
      expect(db.reads, 2);
    });

    test('ein Lesefehler stoppt nichts und wird später erneut versucht', () async {
      final t = await raced(r'$a');
      final failing = _CountingDatabase(client.database, fail: true);
      final r = EchoRepair();
      expect(await r.run(t, me: me, database: failing, isCurrent: () => true), isTrue);
      expect(arrivedEncrypted(t.events.single), isFalse);
      await r.run(t, me: me, database: client.database, isCurrent: () => true);
      expect(arrivedEncrypted(t.events.single), isTrue);
    });
  });
}

/// Zählt Zugriffe auf `getEventById` und reicht alles andere an die echte Datenbank.
class _CountingDatabase implements DatabaseApi {
  _CountingDatabase(this._db, {this.onRead, this.fail = false});

  final DatabaseApi _db;
  final void Function()? onRead;
  final bool fail;
  int reads = 0;

  @override
  Future<Event?> getEventById(String eventId, Room room) async {
    reads++;
    if (fail) throw StateError('Datenbank');
    final e = await _db.getEventById(eventId, room);
    onRead?.call();
    return e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
