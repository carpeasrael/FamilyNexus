import 'package:family_nexus/data/matrix/book_signal_scan.dart';
import 'package:family_nexus/domain/book_signal.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// #311, E-113 (Teil 2c): Prüfung eines SDK-Ereignisses aus einem Buch-Raum mit echten `Event`-Objekten (ohne
/// Verschlüsselung). Der Raum kommt nie aus dem Inhalt, `bookmeta` zählt nur vom Ersteller, Klartext nie.
void main() {
  const creator = '@anna:fake.test';
  const other = '@cara:fake.test';
  const roomId = '!buch:fake.test';
  late Room room;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    Logs().level = Level.wtf;
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final client = Client('test', database: await MatrixSdkDatabase.init('scan${n++}', database: db));
    room = Room(id: roomId, client: client);
    client.rooms.add(room);
  });

  Map<String, Object?> json(String id, String type, {String sender = creator, Map<String, Object?>? content, Map<String, Object?>? extra}) =>
      <String, Object?>{
        'type': type,
        'event_id': id,
        'sender': sender,
        'origin_server_ts': 1000,
        'content': content ?? <String, Object?>{'version': 1, 'room_id': '!anderer:fake.test'},
        ...?extra,
      };

  Map<String, Object?> source(String id, {String type = 'm.room.encrypted', String sender = creator}) => <String, Object?>{
        'type': type,
        'event_id': id,
        'sender': sender,
        'origin_server_ts': 1000,
        'content': <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2', 'ciphertext': 'x'},
      };

  Event arrived(String id, String type, {String sender = creator, Map<String, Object?>? content}) =>
      Event.fromJson(<String, Object?>{...json(id, type, sender: sender, content: content), 'original_source': source(id)}, room);

  BookScanResult scan(Event e) => BookSignalScan.scan(e, roomId: roomId, creatorId: creator);

  test('verschlüsselt angekommen: Signal mit Raum aus der Karte (nie aus dem Inhalt) und Ersteller', () {
    final r = scan(arrived(r'$a', CashBookCodec.entryType, sender: other));
    expect(r.outcome, BookScanOutcome.signal);
    final s = r.signal!;
    expect(s.roomId, roomId, reason: 'der Inhalt nennt einen anderen Raum');
    expect(s.creatorId, creator);
    expect(s.sender, other);
    expect(s.kind, BookSignalKind.entry);
    expect(s.eventId, r'$a');
  });

  test('Klartext löst nie ein Signal aus (auch bei richtigem Typ und Absender)', () {
    for (final type in <String>[CashBookCodec.entryType, CashBookCodec.metaType]) {
      final e = Event.fromJson(json(r'$p', type), room);
      expect(scan(e).outcome, BookScanOutcome.plaintext, reason: type);
      expect(scan(e).signal, isNull);
    }
  });

  test('bookmeta nur vom Ersteller; von anderen ignoriert', () {
    expect(scan(arrived(r'$m1', CashBookCodec.metaType)).signal!.kind, BookSignalKind.meta);
    final r = scan(arrived(r'$m2', CashBookCodec.metaType, sender: other));
    expect(r.outcome, BookScanOutcome.ignored);
    expect(r.signal, isNull);
  });

  test('nicht entschlüsselt (m.room.encrypted): undecrypted, zählt später neu', () {
    final e = Event.fromJson(json(r'$u', 'm.room.encrypted'), room);
    expect(scan(e).outcome, BookScanOutcome.undecrypted);
  });

  test('geschwärzt, Fehlerstatus und fremde Typen werden ignoriert', () {
    expect(scan(arrived(r'$x', 'm.room.message')).outcome, BookScanOutcome.ignored);
    expect(scan(arrived(r'$y', 'de.inneso.familynexus.event')).outcome, BookScanOutcome.ignored);
    final failed = Event.fromJson(json(r'$f', CashBookCodec.entryType, extra: <String, Object?>{
      'unsigned': <String, Object?>{messageSendingStatusKey: EventStatus.error.intValue},
      'original_source': source(r'$f'),
    }), room);
    expect(scan(failed).outcome, BookScanOutcome.ignored);
    final redacted = Event.fromJson(json(r'$r', CashBookCodec.entryType, extra: <String, Object?>{
      'unsigned': <String, Object?>{'redacted_because': <String, Object?>{'type': 'm.room.redaction', 'event_id': r'$red', 'sender': creator, 'origin_server_ts': 1, 'content': <String, Object?>{}}},
      'original_source': source(r'$r'),
    }), room);
    expect(scan(redacted).outcome, BookScanOutcome.ignored);
  });

  test('die Buchtypen sind genau bookmeta und cashentry', () {
    expect(BookSignalScan.types, <String>{CashBookCodec.metaType, CashBookCodec.entryType});
  });
}
