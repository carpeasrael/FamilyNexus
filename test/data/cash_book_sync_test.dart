import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/sync/cash_book_sync.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/book_signal.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/fake_matrix.dart';
import '../support/memory_cash_book_store.dart';

const String _room2 = '!zwei:fake.test';

/// Ablage, deren `pending()` eine zuvor gelesene (veraltete) Fassung liefert, obwohl die gespeicherte schon weiter ist.
class _StaleStore extends MemoryCashBookStore {
  List<({String roomId, CashEntry entry})> snapshot = const <({String roomId, CashEntry entry})>[];

  @override
  Future<List<({String roomId, CashEntry entry})>> pending(String author) async => snapshot;
}

/// #311, E-113 (Teil 2c): `CashBookSync` gegen den Gateway-Fake: Annahmeregel, Warten, Rückfall, Senden, Resync,
/// Aufräumen, Abgleich, Sperre.
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gw;
  late MemoryCashBookStore store;
  late CashBookService service;
  late CashBookSync sync;
  var now = DateTime.utc(2026, 11, 22, 12);

  BookRoomInfo book([String room = kBookRoom, String creator = kBookOwner]) => BookRoomInfo(roomId: room, creatorId: creator);

  Future<void> build({bool enabled = true, String? familyRoom, String me = kBookOwner}) async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gw.createFamily('Familie');
    store = MemoryCashBookStore();
    service = CashBookService(store: store, myUserId: me, clock: () => now);
    sync = CashBookSync(
      gateway: gw,
      service: service,
      store: store,
      familyRoom: familyRoom ?? gw.familyRoom!.id,
      enabled: enabled,
      retryInterval: const Duration(hours: 1),
      clock: () => now,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 11, 22, 12);
    await build();
    gw.fakeBooks = <BookRoomInfo>[book()];
    gw.knownMembers[kBookRoom] = <String>{kBookOwner, kBookMember};
  });

  tearDown(() => sync.dispose());

  CashEntry fresh({String id = kEntryId1, String author = kBookOwner, int version = 1, int cents = 1250, DateTime? updatedAt, bool deleted = false}) =>
      cashEntry(id: id, author: author, version: version, cents: cents, deleted: deleted, updatedAt: updatedAt ?? now);

  BookSignal entrySignal(CashEntry e, {String? sender, String room = kBookRoom, String creator = kBookOwner}) => BookSignal(
        roomId: room,
        creatorId: creator,
        kind: BookSignalKind.entry,
        sender: sender ?? e.author,
        timestamp: now,
        content: CashBookCodec.encodeEntry(e),
      );

  BookSignal metaSignal(CashBookMeta m, {String? sender, String creator = kBookOwner}) => BookSignal(
        roomId: m.roomId,
        creatorId: creator,
        kind: BookSignalKind.meta,
        sender: sender ?? creator,
        timestamp: now,
        content: CashBookCodec.encodeMeta(m),
      );

  Future<void> feed(Iterable<BookSignal> signals) async {
    sync.start();
    await Future<void>.delayed(Duration.zero); // `Stream.multi` hängt den Zuhörer erst im nächsten Mikrotask an
    for (final s in signals) {
      gw.injectBookSignal(s);
    }
    await Future<void>.delayed(Duration.zero); // die Zustellung über `Stream.multi` ist asynchron
    await sync.idle();
  }

  group('Eingang', () {
    test('bookmeta nur vom Ersteller; von einem anderen Mitglied verworfen', () async {
      await feed(<BookSignal>[metaSignal(bookMeta(title: 'Falsch'), sender: kBookMember)]);
      expect(await store.getBook(kBookRoom), isNull);
      expect(sync.rejected, 1);
      await feed(<BookSignal>[metaSignal(bookMeta(title: 'Haushalt'))]);
      expect((await store.getBook(kBookRoom))!.title, 'Haushalt');
    });

    test('Eintrag eines Mitglieds wird angenommen, auch der des Erstellers selbst', () async {
      await store.putBook(bookMeta());
      await feed(<BookSignal>[entrySignal(fresh(author: kBookMember)), entrySignal(fresh(id: kEntryId2, author: kBookOwner))]);
      expect(await store.getEntry(kBookRoom, kBookMember, kEntryId1), isNotNull);
      expect(await store.getEntry(kBookRoom, kBookOwner, kEntryId2), isNotNull);
      expect(sync.rejected, 0);
    });

    test('Eintrag eines Fremden (nie im Raum): verworfen, nicht gespeichert', () async {
      await store.putBook(bookMeta());
      await feed(<BookSignal>[entrySignal(fresh(author: '@fremd:fake.test'))]);
      expect(await store.entries(kBookRoom), isEmpty);
      expect(sync.rejected, 1);
      expect(sync.heldCount, 0);
    });

    test('Autor ungleich Absender: verworfen (kein Schreiben in fremdem Namen)', () async {
      await store.putBook(bookMeta());
      await feed(<BookSignal>[entrySignal(fresh(author: kBookMember), sender: kBookOwner)]);
      expect(await store.entries(kBookRoom), isEmpty);
      expect(sync.rejected, 1);
    });

    test('Eintrag vor dem Meta wartet und wird angenommen, sobald das Meta da ist', () async {
      await feed(<BookSignal>[entrySignal(fresh(author: kBookMember))]);
      expect(sync.heldCount, 1);
      expect(await store.entries(kBookRoom), isEmpty);
      await feed(<BookSignal>[metaSignal(bookMeta())]);
      expect(sync.heldCount, 0);
      expect(await store.getEntry(kBookRoom, kBookMember, kEntryId1), isNotNull);
    });

    test('Mitglieder nicht ladbar: Eintrag wartet (nie angenommen, nie verworfen), später angenommen', () async {
      await store.putBook(bookMeta());
      gw.knownMembersError = const GatewayException(GatewayError.serverUnreachable);
      await feed(<BookSignal>[entrySignal(fresh(author: kBookMember))]);
      expect(sync.heldCount, 1);
      expect(sync.rejected, 0);
      gw.knownMembersError = null;
      now = now.add(const Duration(seconds: 31));
      await sync.publishPending();
      expect(sync.heldCount, 0);
      expect(await store.getEntry(kBookRoom, kBookMember, kEntryId1), isNotNull);
    });

    test('höchstens ein Abruf der Mitglieder je Raum und 30 Sekunden; danach wird ein weiterhin Unbekannter verworfen', () async {
      await store.putBook(bookMeta());
      final stranger = '@fremd:fake.test';
      await feed(<BookSignal>[
        entrySignal(fresh(id: kEntryId1, author: stranger)),
        entrySignal(fresh(id: kEntryId2, author: stranger)),
      ]);
      expect(gw.knownMembersCalls, 1, reason: 'kein Abruf je Eintrag');
      expect(sync.rejected, 1, reason: 'erster Eintrag nach dem Abruf verworfen');
      expect(sync.heldCount, 1, reason: 'zweiter wartet bis zum nächsten Abruf');
      now = now.add(const Duration(seconds: 31));
      await sync.publishPending();
      expect(gw.knownMembersCalls, 2);
      expect(sync.rejected, 2);
      expect(sync.heldCount, 0);
    });

    test('ein später beigetretenes Mitglied: der Zwischenspeicher wird beim Beitritt verworfen und frisch geladen', () async {
      await store.putBook(bookMeta());
      await feed(<BookSignal>[entrySignal(fresh(author: kBookMember))]);
      expect(gw.knownMembersCalls, 1);
      gw.knownMembers[kBookRoom] = <String>{kBookOwner, kBookMember, '@neu:fake.test'};
      now = now.add(const Duration(seconds: 31));
      await feed(<BookSignal>[
        BookSignal(roomId: kBookRoom, creatorId: kBookOwner, kind: BookSignalKind.memberJoined, sender: '@neu:fake.test', timestamp: now),
        entrySignal(fresh(id: kEntryId2, author: '@neu:fake.test')),
      ]);
      expect(await store.getEntry(kBookRoom, '@neu:fake.test', kEntryId2), isNotNull);
    });

    test('Warteliste behält je Eintrag die höchste Version (eine ältere verdrängt nie eine neuere)', () async {
      await store.putBook(bookMeta());
      gw.knownMembersError = const GatewayException(GatewayError.serverUnreachable);
      await feed(<BookSignal>[
        entrySignal(fresh(author: kBookMember, version: 2, cents: 200)),
        entrySignal(fresh(author: kBookMember, version: 1, cents: 100)),
      ]);
      expect(sync.heldCount, 1);
      gw.knownMembersError = null;
      now = now.add(const Duration(seconds: 31));
      await sync.publishPending();
      expect((await store.getEntry(kBookRoom, kBookMember, kEntryId1))!.version, 2);
    });

    test('genau nach 30 Sekunden ist ein neuer Abruf erlaubt (Grenze)', () async {
      await store.putBook(bookMeta());
      await feed(<BookSignal>[entrySignal(fresh(author: '@fremd:fake.test'))]);
      expect(gw.knownMembersCalls, 1);
      await feed(<BookSignal>[entrySignal(fresh(id: kEntryId2, author: '@fremd:fake.test'))]);
      expect(gw.knownMembersCalls, 1, reason: 'innerhalb des Fensters');
      now = now.add(const Duration(seconds: 30));
      await sync.publishPending();
      expect(gw.knownMembersCalls, 2);
    });

    test('Doppelzustellung und Reihenfolge konvergieren (Summe gleich)', () async {
      await store.putBook(bookMeta());
      final v1 = fresh(cents: 100);
      final v2 = fresh(version: 2, cents: 250, updatedAt: now.add(const Duration(minutes: 1)));
      await feed(<BookSignal>[entrySignal(v2), entrySignal(v1), entrySignal(v2), entrySignal(v1)]);
      expect((await store.getEntry(kBookRoom, kBookOwner, kEntryId1))!.amountCents, 250);
      expect(await service.monthTotal(kBookRoom, 2026, 11), 250);
    });

    test('Warteliste: höchstens 2000, bei Überlauf fällt der älteste weg und das Buch gilt als unvollständig', () async {
      await store.putBook(bookMeta());
      await store.setComplete(kBookRoom, true);
      gw.knownMembersError = const GatewayException(GatewayError.serverUnreachable);
      String id(int i) => '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
      await feed(<BookSignal>[for (var i = 0; i <= CashBookSync.maxHeld; i++) entrySignal(fresh(id: id(i), author: kBookMember))]);
      expect(sync.heldCount, CashBookSync.maxHeld);
      expect(await store.isComplete(kBookRoom), isFalse);
    });
  });

  group('Vollständigkeit und Platzhalter-Buch', () {
    test('Verlauf vollständig und nichts unentschlüsselt: Platzhalter-Buch, Wartende werden angenommen, Buch gilt als vollständig', () async {
      await feed(<BookSignal>[entrySignal(fresh(author: kBookMember))]);
      gw.completeBooks.add(kBookRoom);
      await sync.tick();
      final b = (await store.getBook(kBookRoom))!;
      expect(b.version, 0);
      expect(b.title, CashBookMeta.fallbackTitle);
      expect(await store.getEntry(kBookRoom, kBookMember, kEntryId1), isNotNull);
      expect(await store.isComplete(kBookRoom), isTrue);
    });

    test('Verlauf nicht vollständig: kein Platzhalter', () async {
      await sync.tick();
      expect(await store.getBook(kBookRoom), isNull);
    });

    test('unentschlüsselbare Ereignisse: Platzhalter erst nach zwei Läufen mit gleichem Stand, Buch bleibt „unvollständig“', () async {
      gw.completeBooks.add(kBookRoom);
      gw.undecryptableBooks[kBookRoom] = 3;
      await sync.tick();
      expect(await store.getBook(kBookRoom), isNull, reason: 'erster Lauf: noch nicht stabil');
      gw.undecryptableBooks[kBookRoom] = 2;
      await sync.tick();
      expect(await store.getBook(kBookRoom), isNull, reason: 'Zähler hat sich geändert');
      await sync.tick();
      expect((await store.getBook(kBookRoom))!.version, 0);
      expect(await store.isComplete(kBookRoom), isFalse, reason: 'mit unentschlüsselbaren Ereignissen nie vollständig');
    });

    test('ein echtes Meta ersetzt das Platzhalter-Buch und wird nie vom Platzhalter verdrängt', () async {
      gw.completeBooks.add(kBookRoom);
      await sync.tick();
      await feed(<BookSignal>[metaSignal(bookMeta(title: 'Aaa', currency: 'AUD'))]);
      expect((await store.getBook(kBookRoom))!.title, 'Aaa');
      await sync.tick();
      expect((await store.getBook(kBookRoom))!.version, 1);
    });
  });

  group('Senden', () {
    test('eigener Eintrag wird mit Inhalt des Codecs gesendet und als gesendet markiert; Fremdes nie', () async {
      await store.putBook(bookMeta());
      final e = fresh();
      await store.putEntry(kBookRoom, e, publishedVersion: 0);
      await store.putEntry(kBookRoom, fresh(id: kEntryId2, author: kBookMember), publishedVersion: 0);
      await sync.tick();
      final sent = gw.bookPublished.single;
      expect(sent.roomId, kBookRoom);
      expect(sent.events.single.type, CashBookCodec.entryType);
      expect(sent.events.single.content, CashBookCodec.encodeEntry(e));
      expect(await store.pending(kBookOwner), isEmpty);
      expect((await store.pending(kBookMember)), hasLength(1), reason: 'fremde Einträge bleiben unberührt');
    });

    test('Buch-Metadaten: eigene, ungesendete werden gesendet; das Platzhalter-Buch nie', () async {
      await store.putBook(bookMeta(), published: false);
      await store.putBook(bookMeta(room: _room2, version: 0), published: false);
      gw.fakeBooks = <BookRoomInfo>[book(), book(_room2)];
      await sync.tick();
      expect(gw.bookPublished.map((p) => p.roomId), <String>[kBookRoom]);
      expect(gw.bookPublished.single.events.single.type, CashBookCodec.metaType);
      expect(await store.pendingBooks(kBookOwner), isEmpty);
    });

    test('Metadaten gehen vor den Einträgen hinaus', () async {
      await store.putBook(bookMeta(), published: false);
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      await sync.tick();
      expect(gw.bookPublished.map((p) => p.events.single.type), <String>[CashBookCodec.metaType, CashBookCodec.entryType]);
    });

    test('vor dem ersten Sync oder nach dem Abmelden wird nichts gesendet', () async {
      await store.putBook(bookMeta(), published: false);
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      gw.syncDone = false;
      await sync.publishPending();
      expect(gw.bookPublished, isEmpty);
      gw.syncDone = true;
      await gw.logout();
      await sync.publishPending();
      expect(gw.bookPublished, isEmpty);
    });

    test('Raum nicht in der Liste der Bücher: nichts gesendet, der Eintrag bleibt in der Warteschlange', () async {
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      gw.fakeBooks = const <BookRoomInfo>[];
      await sync.tick();
      expect(gw.bookPublished, isEmpty);
      expect(await store.pending(kBookOwner), hasLength(1));
    });

    test('über einen Tag alter Zeitstempel wird vor dem Senden neu gestempelt, Version bleibt', () async {
      await store.putBook(bookMeta());
      final old = fresh(updatedAt: now.subtract(const Duration(days: 6)));
      await store.putEntry(kBookRoom, old, publishedVersion: 0);
      await sync.tick();
      final content = gw.bookPublished.single.events.single.content;
      expect(content['updated_at'], now.millisecondsSinceEpoch, reason: 'jetzt, nicht vor sechs Tagen');
      expect(content['version'], 1);
      expect(await store.pending(kBookOwner), isEmpty);
    });

    test('Teilergebnis: gesendet wird markiert, Fehlgeschlagenes bleibt und zählt als Fehlversuch', () async {
      await store.putBook(bookMeta());
      final a = fresh(id: kEntryId1, updatedAt: now.subtract(const Duration(minutes: 3)));
      final b = fresh(id: kEntryId2, updatedAt: now.subtract(const Duration(minutes: 2)));
      await store.putEntry(kBookRoom, a, publishedVersion: 0);
      await store.putEntry(kBookRoom, b, publishedVersion: 0);
      gw.publishHandler = (_, ev) => <BookSendResult>[BookSendResult.sent, BookSendResult.failed];
      await sync.tick();
      expect((await store.pending(kBookOwner)).map((p) => p.entry.id), <String>[kEntryId2]);
      expect(sync.backoff.failures, 1);
    });

    test('ungültig (invalid): Warteschlange wird bereinigt, andere Einträge blockiert das nicht', () async {
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(id: kEntryId1, updatedAt: now.subtract(const Duration(minutes: 3))), publishedVersion: 0);
      await store.putEntry(kBookRoom, fresh(id: kEntryId2, updatedAt: now.subtract(const Duration(minutes: 2))), publishedVersion: 0);
      gw.publishHandler = (_, ev) => <BookSendResult>[BookSendResult.invalid, BookSendResult.sent];
      await sync.tick();
      expect(await store.pending(kBookOwner), isEmpty);
      expect(sync.backoff.failures, 0);
    });

    test('Sendeschutz (blocked): Eintrag bleibt, Raum gemerkt, die anderen Räume werden trotzdem bedient, kein Backoff', () async {
      await store.putBook(bookMeta());
      await store.putBook(bookMeta(room: _room2));
      gw.fakeBooks = <BookRoomInfo>[book(), book(_room2)];
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      await store.putEntry(_room2, fresh(id: kEntryId2), publishedVersion: 0);
      gw.publishHandler = (room, ev) => List<BookSendResult>.filled(ev.length, room == kBookRoom ? BookSendResult.blocked : BookSendResult.sent);
      await sync.tick();
      expect(sync.blockedRooms, <String>{kBookRoom});
      expect((await store.pending(kBookOwner)).single.roomId, kBookRoom);
      expect(sync.backoff.failures, 0);
      gw.publishHandler = null;
      await sync.publishPending();
      expect(sync.blockedRooms, isEmpty, reason: 'Sendeschutz aufgehoben, gesendet');
      expect(await store.pending(kBookOwner), isEmpty);
    });

    test('Fehler des Gateways beim Senden: Fehlversuch, nichts als gesendet markiert', () async {
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      gw.publishError = const GatewayException(GatewayError.encryptionUnavailable);
      await sync.tick();
      expect(sync.backoff.failures, 1);
      expect(await store.pending(kBookOwner), hasLength(1));
    });

    test('höchstens 50 Ereignisse je Aufruf, der Rest folgt im nächsten Durchlauf', () async {
      await store.putBook(bookMeta());
      String id(int i) => '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
      for (var i = 0; i < 120; i++) {
        await store.putEntry(kBookRoom, fresh(id: id(i), updatedAt: now.subtract(Duration(minutes: 200 - i))), publishedVersion: 0);
      }
      await sync.tick();
      expect(gw.bookPublished.map((p) => p.events.length), <int>[50, 50, 20]);
      expect(await store.pending(kBookOwner), isEmpty);
    });

    test('ein Eintrag, der sich zwischen Lesen und Senden ändert, wird nicht als gesendet markiert', () async {
      await store.putBook(bookMeta());
      final e = fresh();
      await store.putEntry(kBookRoom, e, publishedVersion: 0);
      gw.publishHandler = (room, ev) {
        // während des Sendens ändert der Nutzer den Eintrag (Version 2)
        store.putEntry(kBookRoom, e.copyWith(version: 2, amountCents: 5));
        return List<BookSendResult>.filled(ev.length, BookSendResult.sent);
      };
      await sync.publishPending();
      expect((await store.pending(kBookOwner)).single.entry.version, 2);
    });
  });

  group('Rennen zwischen Lesen und Senden', () {
    test('ändert sich ein Eintrag zwischen pending() und restamp(), wird die alte Fassung nicht gesendet', () async {
      sync.dispose();
      final stale = _StaleStore();
      stale.snapshot = <({String roomId, CashEntry entry})>[(roomId: kBookRoom, entry: fresh(updatedAt: now.subtract(const Duration(days: 6))))];
      await stale.putBook(bookMeta());
      await stale.putEntry(kBookRoom, fresh(version: 2, cents: 5), publishedVersion: 0);
      final s = CashBookSync(
        gateway: gw,
        service: CashBookService(store: stale, myUserId: kBookOwner, clock: () => now),
        store: stale,
        familyRoom: gw.familyRoom!.id,
        enabled: true,
        retryInterval: const Duration(hours: 1),
        clock: () => now,
      );
      await s.publishPending();
      expect(gw.bookPublished, isEmpty, reason: 'die Kopie aus der Warteschlange ist veraltet');
      s.dispose();
    });
  });

  group('Resync', () {
    test('Beitritt eines Mitglieds: eigene Einträge und (als Ersteller) die Metadaten werden erneut vorgemerkt', () async {
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 1);
      await store.putEntry(kBookRoom, fresh(id: kEntryId2, author: kBookMember), publishedVersion: 1);
      expect(await store.pending(kBookOwner), isEmpty);
      await feed(<BookSignal>[BookSignal(roomId: kBookRoom, creatorId: kBookOwner, kind: BookSignalKind.memberJoined, sender: '@neu:fake.test', timestamp: now)]);
      expect((await store.pending(kBookOwner)).single.entry.id, kEntryId1);
      expect((await store.pending(kBookMember)), isEmpty, reason: 'fremde Einträge sendet nur ihr Autor');
      expect((await store.pendingBooks(kBookOwner)).single.roomId, kBookRoom);
    });

    test('nur der eigene Beitritt: nichts wird vorgemerkt', () async {
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 1);
      await feed(<BookSignal>[BookSignal(roomId: kBookRoom, creatorId: kBookOwner, kind: BookSignalKind.memberJoined, sender: kBookOwner, timestamp: now)]);
      expect(await store.pending(kBookOwner), isEmpty);
      expect(await store.pendingBooks(kBookOwner), isEmpty);
    });

    test('Nicht-Ersteller sendet keine Metadaten erneut; eigener Beitritt löst nichts aus', () async {
      await store.putBook(bookMeta(owner: kBookMember));
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 1);
      await feed(<BookSignal>[
        BookSignal(roomId: kBookRoom, creatorId: kBookMember, kind: BookSignalKind.memberJoined, sender: '@neu:fake.test', timestamp: now),
        BookSignal(roomId: kBookRoom, creatorId: kBookMember, kind: BookSignalKind.memberJoined, sender: kBookOwner, timestamp: now),
      ]);
      expect(await store.pendingBooks(kBookMember), isEmpty);
      expect(await store.pending(kBookOwner), hasLength(1), reason: 'der erste Beitritt hat die eigenen Einträge vorgemerkt');
    });
  });

  group('Zeitgeber: Abgleich und Aufräumen', () {
    test('Abgleich nur im Zeitgeber, nur für eigene Bücher; Senden allein ruft ihn nie', () async {
      gw.fakeBooks = <BookRoomInfo>[book(), book(_room2, kBookMember)];
      await sync.publishPending();
      expect(gw.reconcileCalls, 0);
      await sync.tick();
      expect(gw.reconcileCalls, 1, reason: 'nur das Buch, dessen Ersteller ich bin');
      await sync.tick();
      expect(gw.reconcileCalls, 2);
    });

    test('verlassenes Buch: erst nach zwei Läufen mit Abstand gelöscht, nur wenn es in dieser Sitzung gesehen wurde', () async {
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      await sync.publishPending(); // gesehen
      gw.fakeBooks = const <BookRoomInfo>[];
      gw.goneBooks.add(kBookRoom);
      await sync.tick();
      expect(await store.getBook(kBookRoom), isNotNull, reason: 'erster Lauf');
      now = now.add(const Duration(minutes: 31));
      await sync.tick();
      expect(await store.getBook(kBookRoom), isNull);
      expect(await store.entries(kBookRoom), isEmpty);
    });

    test('Buch fehlt nur kurz in der Liste (nicht „weg“): nie gelöscht', () async {
      await store.putBook(bookMeta());
      await sync.publishPending();
      gw.fakeBooks = const <BookRoomInfo>[];
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(minutes: 31));
        await sync.tick();
      }
      expect(await store.getBook(kBookRoom), isNotNull);
    });

    test('Kehrt das Buch zurück, beginnt das Zählen von vorn', () async {
      await store.putBook(bookMeta());
      await sync.publishPending();
      gw.fakeBooks = const <BookRoomInfo>[];
      gw.goneBooks.add(kBookRoom);
      await sync.tick();
      gw.fakeBooks = <BookRoomInfo>[book()];
      gw.goneBooks.clear();
      now = now.add(const Duration(minutes: 31));
      await sync.tick();
      gw.fakeBooks = const <BookRoomInfo>[];
      gw.goneBooks.add(kBookRoom);
      await sync.tick();
      expect(await store.getBook(kBookRoom), isNotNull);
    });

    test('Buch, das in dieser Sitzung nie in der Liste stand: nie gelöscht (andere Geräte, Neustart)', () async {
      await store.putBook(bookMeta(room: _room2));
      gw.goneBooks.add(_room2);
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(minutes: 31));
        await sync.tick();
      }
      expect(await store.getBook(_room2), isNotNull);
    });
  });

  group('Sperre und Familie', () {
    test('gesperrt (enabled = false): kein Zuhören, kein Senden, kein Zeitgeber, kein Zugriff auf Gateway und Ablage', () async {
      sync.dispose();
      await build(enabled: false);
      gw.fakeBooks = <BookRoomInfo>[book()];
      await store.putBook(bookMeta(), published: false);
      await store.putEntry(kBookRoom, fresh(), publishedVersion: 0);
      gw.bookCalls = 0;
      sync.start();
      await sync.publishPending();
      await sync.tick();
      await sync.idle();
      sync.dispose();
      expect(gw.bookCalls, 0);
      expect(gw.bookPublished, isEmpty);
      expect((await store.pending(kBookOwner)), hasLength(1));
    });

    test('der eingebaute Standard ist gesperrt (CashBookFlags.enabled = false)', () async {
      final s = CashBookSync(gateway: gw, service: service, store: store, familyRoom: gw.familyRoom!.id);
      expect(s.enabled, isFalse);
      expect(CashBookFlags.enabled, isFalse);
    });

    test('andere Familie als die des Bestands: Signale werden ignoriert, nichts gesendet', () async {
      sync.dispose();
      await build(familyRoom: '!andere:fake.test');
      gw.fakeBooks = <BookRoomInfo>[book()];
      gw.knownMembers[kBookRoom] = <String>{kBookOwner};
      await store.putBook(bookMeta());
      await store.putEntry(kBookRoom, fresh(id: kEntryId2), publishedVersion: 0);
      await feed(<BookSignal>[entrySignal(fresh())]);
      await sync.publishPending();
      expect(await store.getEntry(kBookRoom, kBookOwner, kEntryId1), isNull);
      expect(gw.bookPublished, isEmpty);
    });
  });
}
