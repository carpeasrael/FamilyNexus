import 'dart:async';
import 'dart:typed_data';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/data/sync/cash_book_receipts.dart';
import 'package:family_nexus/data/sync/cash_book_sync.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/book_signal.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:family_nexus/domain/cash_month.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:family_nexus/domain/receipt_photo_processing.dart';
import 'package:family_nexus/domain/receipt_preview.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/cashbook/cash_book_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/fake_matrix.dart';
import '../support/memory_cash_book_store.dart';
import '../support/test_app.dart';

const String _cara = '@cara:fake.test';
const String _ben = '@ben:fake.test';

/// #311, E-113 (Teil 4a-1): `CashBookController` gegen Fake-Gateway und Memory-Ablage.
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gw;
  late MemoryCashBookStore store;
  late CashBookService service;
  late CashBookReceipts receipts;
  late CashBookSync sync;
  late CashBookController c;
  late FakeFileAccess files;
  var today = DateTime.utc(2026, 11, 22);
  var previews = 0;
  ReceiptPreview? previewResult;
  Uint8List Function(Uint8List)? prepare;
  final jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6]);
  late String me;
  late String room;

  CashBookView? viewOf(String roomId) {
    for (final b in c.books) {
      if (b.roomId == roomId) return b;
    }
    return null;
  }

  Future<void> build({bool enabled = true, bool moderator = true}) async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('cara', 'pw2', displayName: 'Cara');
    server.addAccount('ben', 'pw3', displayName: 'Ben');
    gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gw.createFamily('Familie');
    final fr = gw.familyRoom!;
    server.addMember(fr, _cara, power: 50);
    server.addMember(fr, _ben);
    if (!moderator) {
      gw = server.newDevice();
      await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'ben', password: 'pw3');
      gw.attachFamilyRoom(fr.id);
    }
    me = gw.userId!;
    room = kBookRoom;
    store = MemoryCashBookStore();
    service = CashBookService(store: store, myUserId: me, clock: () => DateTime.utc(2026, 11, 22, 12));
    receipts = CashBookReceipts(gateway: gw, service: service, store: store, enabled: enabled);
    sync = CashBookSync(gateway: gw, service: service, store: store, familyRoom: fr.id, enabled: enabled, receipts: receipts, retryInterval: const Duration(hours: 1));
    files = FakeFileAccess();
    previews = 0;
    previewResult = ReceiptPreview(width: 1, height: 1, rgba: Uint8List.fromList(<int>[0, 0, 0, 255]));
    prepare = null;
    c = CashBookController(
      gateway: gw,
      service: service,
      store: store,
      sync: sync,
      receipts: receipts,
      enabled: enabled,
      today: () => today,
      files: files,
      prepareReceipt: (b) async => (prepare ?? (x) => x)(b),
      decodePreview: (b) async {
        previews++;
        return previewResult;
      },
    );
    gw.nextBookRoom = room;
    gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me)];
    await store.putBook(bookMeta(room: room, owner: me));
  }

  setUp(() async {
    today = DateTime.utc(2026, 11, 22);
    await build();
  });

  tearDown(() {
    c.dispose();
    sync.dispose();
    receipts.dispose();
  });

  Future<void> settle() async {
    await c.load();
    await pumpEventQueue();
  }

  CashEntry own({String id = kEntryId1, int cents = 1250, DateTime? date, bool deleted = false}) =>
      cashEntry(id: id, author: me, cents: cents, date: date ?? DateTime.utc(2026, 11, 20), deleted: deleted);

  group('Sperre und Berechtigung', () {
    test('gesperrt: keine Zugriffe, leere Ansicht, jede Aktion notAllowed', () async {
      c.dispose();
      await build(enabled: false);
      gw.bookCalls = 0;
      c.start();
      await settle();
      expect(c.available, isFalse);
      expect(c.books, isEmpty);
      expect(c.invitations, isEmpty);
      for (final f in <Future<Object?> Function()>[
        () => c.createBook(title: 'Haushalt', currency: 'EUR'),
        () => c.acceptInvitation('!x'),
        () => c.declineInvitation('!x'),
        () => c.addEntry(room, date: today, store: 'x', amountCents: 5),
        () => c.deleteEntry(room, kEntryId1),
        () => c.pickPhoto(),
        () => c.inviteCandidates(CashBookView(meta: bookMeta(owner: me), mine: true, isPlaceholder: false, complete: true, blocked: false, pendingOwn: 0, monthTotalCents: 0, month: CashMonth.of(today))),
      ]) {
        await expectLater(f(), throwsA(isA<CashBookException>().having((e) => e.error, 'error', CashBookError.notAllowed)));
      }
      expect((await c.loadReceipt(room, own())).status, BookReceiptStatus.missing);
      expect(await c.entriesOf(room, CashMonth.of(today)), isEmpty);
      expect(gw.bookCalls, 0);
      expect(sync.onChanged, isNull, reason: 'gesperrt: der Slot bleibt frei');
      expect(CashBookFlags.enabled, isFalse);
    });

    test('Nicht-Moderator: nichts verfügbar, Aktionen notAllowed ohne Gateway-Aufruf', () async {
      c.dispose();
      await build(moderator: false);
      gw.bookCalls = 0;
      expect(c.isModerator, isFalse);
      expect(c.available, isFalse);
      c.start();
      await settle();
      expect(c.books, isEmpty);
      await expectLater(c.createBook(title: 'Haushalt', currency: 'EUR'), throwsA(isA<CashBookException>()));
      await expectLater(c.addEntry(room, date: today, store: 'x', amountCents: 5), throwsA(isA<CashBookException>()));
      expect(gw.invitedToBook, isEmpty);
      expect(gw.acceptedBooks, isEmpty);
    });
  });

  group('Ansicht', () {
    test('Schnittmenge aus Ablage und Gateway: nur beigetretene Bücher; Platzhalter, Ersteller, Verlauf, Sendeschutz, Ungesendetes, Monatssumme', () async {
      await store.putBook(bookMeta(room: '!zwei:fake.test', title: 'Urlaub', currency: 'USD', owner: _cara, version: 0));
      await store.putBook(bookMeta(room: '!weg:fake.test', title: 'Nicht beigetreten', owner: _cara));
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
      await store.setComplete(room, true);
      await store.putEntry(room, own(), publishedVersion: 0);
      await store.putEntry(room, own(id: kEntryId2, cents: 750, date: DateTime.utc(2026, 11, 1)), publishedVersion: 1);
      await store.putEntry(room, cashEntry(id: '33333333-3333-4333-8333-333333333333', author: _cara, cents: 100, date: DateTime.utc(2026, 11, 2)), publishedVersion: 1);
      await store.putEntry(room, cashEntry(id: '44444444-4444-4444-8444-444444444444', author: me, cents: 9999, date: DateTime.utc(2026, 10, 31)), publishedVersion: 1);
      await store.putEntry(room, cashEntry(id: '55555555-5555-4555-8555-555555555555', author: me, cents: 5000, date: DateTime.utc(2026, 11, 3), deleted: true), publishedVersion: 1);
      sync.blockedRooms.add('!zwei:fake.test');
      c.start();
      await settle();
      expect(c.books.map((b) => b.meta.title), <String>['Haushalt', 'Urlaub'], reason: 'sortiert, ohne das nicht beigetretene');
      final a = viewOf(room)!;
      expect(a.mine, isTrue);
      expect(a.isPlaceholder, isFalse);
      expect(a.complete, isTrue);
      expect(a.blocked, isFalse);
      expect(a.pendingOwn, 1);
      expect(a.monthTotalCents, 1250 + 750 + 100, reason: 'nur November, ohne Löschmarke');
      final b = viewOf('!zwei:fake.test')!;
      expect(b.mine, isFalse);
      expect(b.isPlaceholder, isTrue);
      expect(b.blocked, isTrue);
      expect(b.complete, isFalse);
      expect(b.meta.currency, 'USD');
    });

    test('der Monat „laufend“ folgt dem lokalen Datum (Monatsgrenze)', () async {
      await store.putEntry(room, own(date: DateTime.utc(2026, 11, 30), cents: 100), publishedVersion: 1);
      await store.putEntry(room, own(id: kEntryId2, date: DateTime.utc(2026, 12, 1), cents: 300), publishedVersion: 1);
      today = DateTime.utc(2026, 11, 30);
      c.start();
      await settle();
      expect(viewOf(room)!.monthTotalCents, 100);
      today = DateTime.utc(2026, 12, 1);
      await settle();
      expect(viewOf(room)!.monthTotalCents, 300);
    });

    test('eingehende Änderungen (sync.onChanged) und des Gateways bauen die Ansicht neu auf', () async {
      c.start();
      await settle();
      expect(viewOf(room)!.monthTotalCents, 0);
      await store.putEntry(room, own(), publishedVersion: 1);
      sync.onChanged!();
      await pumpEventQueue();
      expect(viewOf(room)!.monthTotalCents, 1250);
      await store.putEntry(room, own(id: kEntryId2, cents: 50), publishedVersion: 1);
      server.notifyAll();
      await pumpEventQueue();
      expect(viewOf(room)!.monthTotalCents, 1300);
    });

    test('Einladungen werden angezeigt, aber nie von selbst angenommen', () async {
      gw.fakeInvitations = <BookInvitationInfo>[const BookInvitationInfo(roomId: '!einl:fake.test', inviterId: _cara, inviterName: 'Cara')];
      c.start();
      await settle();
      expect(c.invitations.single.roomId, '!einl:fake.test');
      for (var i = 0; i < 3; i++) {
        await settle();
        server.notifyAll();
        await pumpEventQueue();
      }
      expect(gw.acceptedBooks, isEmpty);
      expect(gw.declinedBooks, isEmpty);
    });

    test('Sendeschutz erscheint nach einer Sendung ohne weiteres Zutun (Meldung des Syncs)', () async {
      await store.putEntry(room, own(), publishedVersion: 0);
      c.start();
      await settle();
      expect(viewOf(room)!.blocked, isFalse);
      gw.publishHandler = (r, ev) => List<BookSendResult>.filled(ev.length, BookSendResult.blocked);
      await sync.publishPending();
      await pumpEventQueue();
      expect(viewOf(room)!.blocked, isTrue);
    });

    test('start/dispose: Controller besitzt sync.onChanged, dispose gibt ihn frei; dispose des Syncs leert nur seine Abos', () async {
      expect(sync.onChanged, isNull);
      c.start();
      expect(sync.onChanged, isNotNull);
      c.dispose();
      expect(sync.onChanged, isNull);
    });

    test('entriesOf und monthTotal: nur dieses Buch und Monat, nie über Währungen addiert', () async {
      await store.putBook(bookMeta(room: '!usd:fake.test', currency: 'USD', owner: _cara));
      await store.putEntry(room, own(cents: 1000), publishedVersion: 1);
      await store.putEntry('!usd:fake.test', cashEntry(id: kEntryId2, author: _cara, cents: 5000, date: DateTime.utc(2026, 11, 5)), publishedVersion: 1);
      c.start();
      final m = CashMonth.of(today);
      expect((await c.entriesOf(room, m)).map((e) => e.amountCents), <int>[1000]);
      expect(await c.monthTotal(room, m), 1000);
      expect(await c.monthTotal('!usd:fake.test', m), 5000);
      expect(await c.entriesOf(room, m.previous), isEmpty);
    });
  });

  group('Bücher anlegen, einladen, verlassen', () {
    test('ungültiger Titel oder Währung: invalid, kein Gateway-Aufruf', () async {
      c.start();
      await settle();
      gw.bookCalls = 0;
      for (final (t, cur) in <(String, String)>[('', 'EUR'), ('   ', 'EUR'), ('x' * 61, 'EUR'), ('Haushalt', 'eur'), ('Haushalt', 'EU')]) {
        await expectLater(c.createBook(title: t, currency: cur), throwsA(isA<CashBookException>().having((e) => e.error, 'error', CashBookError.invalid)));
      }
      expect(gw.bookCalls, 0);
    });

    test('Anlegen: Raum über das Gateway, Metadaten lokal ungesendet (Sync sendet), Ansicht aktualisiert', () async {
      await store.deleteBook(room);
      c.start();
      await settle();
      gw.nextBookRoom = '!neu:fake.test';
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: '!neu:fake.test', creatorId: me)];
      final id = await c.createBook(title: '  Haushalt  ', currency: 'CHF');
      expect(id, '!neu:fake.test');
      final meta = (await store.getBook(id))!;
      expect((meta.title, meta.currency, meta.owner, meta.version), ('Haushalt', 'CHF', me, 1));
      expect((await store.pendingBooks(me)).single.roomId, id);
      await pumpEventQueue();
      expect(viewOf(id)!.mine, isTrue);
    });

    test('Gateway scheitert beim Anlegen: kein lokales Buch', () async {
      await store.deleteBook(room);
      c.start();
      gw.bookActionError = const GatewayException(GatewayError.serverUnreachable);
      await expectLater(c.createBook(title: 'Haushalt', currency: 'EUR'), throwsA(isA<GatewayException>()));
      expect(await store.books(), isEmpty);
    });

    test('Einladen und Entfernen: nur der Ersteller, nie mich selbst', () async {
      c.start();
      await settle();
      final mine = viewOf(room)!;
      await c.inviteMember(mine, _cara);
      await c.removeMember(mine, _cara);
      expect(gw.invitedToBook, <(String, String)>[(room, _cara)]);
      expect(gw.removedFromBook, <(String, String)>[(room, _cara)]);
      await expectLater(c.removeMember(mine, me), throwsA(isA<CashBookException>()));
      final foreign = CashBookView(meta: bookMeta(room: '!f:fake.test', owner: _cara), mine: false, isPlaceholder: false, complete: true, blocked: false, pendingOwn: 0, monthTotalCents: 0, month: CashMonth.of(today));
      await settle();
      gw.bookCalls = 0;
      await expectLater(c.inviteMember(foreign, _ben), throwsA(isA<CashBookException>()));
      await expectLater(c.removeMember(foreign, _ben), throwsA(isA<CashBookException>()));
      expect(gw.bookCalls, 0);
    });

    test('Mitglieder mit Namen; Entfernen nur für den Ersteller und nie für mich', () async {
      gw.bookMemberList[room] = <BookMember>[BookMember(me, BookMembership.joined), const BookMember(_cara, BookMembership.joined), const BookMember(_ben, BookMembership.invited)];
      c.start();
      await settle();
      final m = await c.members(viewOf(room)!);
      expect(m.map((x) => (x.name, x.joined, x.isCreator, x.canRemove)), <(String, bool, bool, bool)>[('Anna', true, true, false), ('Cara', true, false, true), ('Ben', false, false, true)]);
    });

    test('Einladungskandidaten: beigetretene Moderatoren, die noch nicht im Buch sind; Mitglieder und Nicht-Ersteller nicht', () async {
      gw.bookMemberList[room] = <BookMember>[BookMember(me, BookMembership.joined)];
      c.start();
      await settle();
      expect((await c.inviteCandidates(viewOf(room)!)).map((m) => m.userId), <String>[_cara], reason: 'Ben ist kein Moderator, ich bin schon drin');
      gw.bookMemberList[room] = <BookMember>[BookMember(me, BookMembership.joined), const BookMember(_cara, BookMembership.invited)];
      expect(await c.inviteCandidates(viewOf(room)!), isEmpty);
      final foreign = CashBookView(meta: bookMeta(room: room, owner: _cara), mine: false, isPlaceholder: false, complete: true, blocked: false, pendingOwn: 0, monthTotalCents: 0, month: CashMonth.of(today));
      expect(await c.inviteCandidates(foreign), isEmpty);
    });

    test('Verlassen: der Ersteller nie (vor jedem Gateway-Aufruf); sonst nur das Gateway, das Buch verschwindet sofort und bleibt nach Neustart weg; kein Löschen am Sync vorbei', () async {
      await store.putBook(bookMeta(room: '!zwei:fake.test', owner: _cara));
      await store.putEntry('!zwei:fake.test', cashEntry(author: _cara), publishedVersion: 1);
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
      c.start();
      await settle();
      final creator = viewOf(room)!;
      expect(c.canLeave(creator), isFalse);
      gw.bookCalls = 0;
      await expectLater(c.leaveBook(creator), throwsA(isA<CashBookException>().having((e) => e.error, 'error', CashBookError.notAllowed)));
      expect(gw.bookCalls, 0);
      final other = viewOf('!zwei:fake.test')!;
      expect(c.canLeave(other), isTrue);
      await c.leaveBook(other);
      await pumpEventQueue();
      expect(gw.leftBooks, <String>['!zwei:fake.test']);
      expect(viewOf('!zwei:fake.test'), isNull, reason: 'sofort ausgeblendet, obwohl das Gateway es noch listet');
      expect(await store.getBook('!zwei:fake.test'), isNotNull, reason: 'das lokale Löschen gehört dem Sync');
      expect(await store.entries('!zwei:fake.test'), hasLength(1));
      // Neustart: neuer Controller, das Gateway listet das Buch nicht mehr
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me)];
      final c2 = CashBookController(gateway: gw, service: service, store: store, sync: sync, receipts: receipts, enabled: true, today: () => today);
      await c2.load();
      expect(c2.books.map((b) => b.roomId), <String>[room]);
      c2.dispose();
    });

    test('Verlassen scheitert: das Buch bleibt sichtbar', () async {
      await store.putBook(bookMeta(room: '!zwei:fake.test', owner: _cara));
      gw.fakeBooks = <BookRoomInfo>[const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
      c.start();
      await settle();
      gw.bookActionError = const GatewayException(GatewayError.serverUnreachable);
      await expectLater(c.leaveBook(viewOf('!zwei:fake.test')!), throwsA(isA<GatewayException>()));
      await settle();
      expect(viewOf('!zwei:fake.test'), isNotNull);
    });

    test('Einladung annehmen und ablehnen: nur auf ausdrücklichen Aufruf', () async {
      c.start();
      await settle();
      await c.acceptInvitation('!a:fake.test');
      await c.declineInvitation('!b:fake.test');
      expect(gw.acceptedBooks, <String>['!a:fake.test']);
      expect(gw.declinedBooks, <String>['!b:fake.test']);
    });
  });

  group('Einträge und Fotos', () {
    test('Eintrag anlegen ohne Foto: Dienst, wartet auf Senden, der Sync wird angestoßen und sendet', () async {
      gw.nextBookRoom = room;
      c.start();
      await settle();
      final e = await c.addEntry(room, date: today, store: 'Edeka', amountCents: 1250);
      expect(e.author, me);
      expect((await store.pending(me)).single.entry.id, e.id);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(gw.bookPublished.expand((p) => p.events).map((x) => x.type), contains(CashBookCodec.entryType), reason: 'kick löst das Senden aus');
      expect(viewOf(room)!.monthTotalCents, 1250);
    });

    test('mit Foto: zuerst aufbereitet, dann Datei, dann Eintrag mit Bon-Verweis', () async {
      final order = <String>[];
      prepare = (b) {
        order.add('prepare');
        return jpeg;
      };
      final original = Uint8List.fromList(<int>[9, 9, 9]);
      c.start();
      final e = await c.addEntry(room, date: today, store: 'Edeka', amountCents: 100, photo: original);
      expect(order, <String>['prepare']);
      expect(gw.sentReceipts.single.bytes, jpeg, reason: 'gesendet wird die aufbereitete Datei, nicht das Original');
      expect(e.receipt, CashReceipt(eventId: r'$receipt1', sha256: ReceiptCheck.sha256Hex(jpeg), size: jpeg.length));
    });

    test('Aufbereitung scheitert: weder Datei noch Eintrag', () async {
      prepare = (_) => throw const ReceiptPhotoProcessingException(ReceiptPhotoProcessingError.cannotShrink);
      c.start();
      await expectLater(
        c.addEntry(room, date: today, store: 'x', amountCents: 5, photo: jpeg),
        throwsA(isA<ReceiptPhotoProcessingException>().having((e) => e.error, 'error', ReceiptPhotoProcessingError.cannotShrink)),
      );
      expect(gw.sentReceipts, isEmpty);
      expect(await store.entries(room), isEmpty);
    });

    test('Senden der Datei scheitert: kein Eintrag', () async {
      gw.sendReceiptError = const GatewayException(GatewayError.serverUnreachable);
      c.start();
      await expectLater(c.addEntry(room, date: today, store: 'x', amountCents: 5, photo: jpeg), throwsA(isA<GatewayException>()));
      expect(await store.entries(room), isEmpty);
    });

    test('ändern: Foto ersetzen, entfernen, unverändert; fremde Einträge nie', () async {
      c.start();
      final e = await c.addEntry(room, date: today, store: 'Edeka', amountCents: 100, photo: jpeg);
      final changed = await c.editEntry(room, e.copyWith(amountCents: 200));
      expect(changed.version, 2);
      expect(changed.receipt, e.receipt, reason: 'der Bon bleibt');
      final replaced = await c.editEntry(room, changed, newPhoto: jpeg);
      expect(replaced.receipt!.eventId, r'$receipt2');
      final removed = await c.editEntry(room, replaced, removePhoto: true);
      expect(removed.receipt, isNull);
      final foreign = cashEntry(id: kEntryId2, author: _cara);
      await store.putEntry(room, foreign, publishedVersion: 1);
      await expectLater(c.editEntry(room, foreign.copyWith(amountCents: 1)), throwsA(isA<CashBookException>()));
      await expectLater(c.deleteEntry(room, kEntryId2), throwsA(isA<CashBookException>()));
    });

    test('löschen: Löschmarke, Ansicht ohne den Eintrag', () async {
      c.start();
      final e = await c.addEntry(room, date: today, store: 'Edeka', amountCents: 100);
      await c.deleteEntry(room, e.id);
      await settle();
      expect(await c.entriesOf(room, CashMonth.of(today)), isEmpty);
      expect(viewOf(room)!.monthTotalCents, 0);
    });

    test('Aktionen laufen nacheinander, busy ist währenddessen gesetzt', () async {
      final gate = Completer<void>();
      var starts = 0;
      c.start();
      final first = c.addEntry(room, date: today, store: 'A', amountCents: 1, photo: jpeg);
      // `prepareReceipt` des Controllers wartet auf das Gate
      c.dispose();
      c = CashBookController(
        gateway: gw,
        service: service,
        store: store,
        sync: sync,
        receipts: receipts,
        enabled: true,
        today: () => today,
        prepareReceipt: (b) async {
          starts++;
          await gate.future;
          return jpeg;
        },
      );
      await first;
      final a = c.addEntry(room, date: today, store: 'B', amountCents: 2, photo: jpeg);
      final b = c.addEntry(room, date: today, store: 'C', amountCents: 3, photo: jpeg);
      await pumpEventQueue();
      expect(c.busy, isTrue);
      expect(starts, 1, reason: 'die zweite Aktion wartet');
      gate.complete();
      await Future.wait<Object?>(<Future<Object?>>[a, b]);
      expect(starts, 2);
      expect(c.busy, isFalse);
    });

    test('Foto wählen: Dateidialog, abgebrochen → null, zu groß → Ausnahme', () async {
      c.start();
      files.nextImage = PickedFile(name: 'bon.jpg', bytes: jpeg);
      expect(await c.pickPhoto(), jpeg);
      files.nextImage = null;
      expect(await c.pickPhoto(), isNull);
      files.imageTooLarge = true;
      await expectLater(c.pickPhoto(), throwsA(isA<FileTooLargeException>()));
    });
  });

  group('Bon anzeigen', () {
    Future<CashEntry> withReceipt() async {
      final e = own().copyWith(receipt: const CashReceipt(eventId: r'$bon', sha256: kHash, size: 1000));
      await store.putEntry(room, e, publishedVersion: 1);
      return e;
    }

    test('ok: Rohpixel aus der Dekodierung', () async {
      final e = await withReceipt();
      gw.loadReceiptHandler = (r, ev, rc, a) => BookReceiptLoad(BookReceiptStatus.ok, jpeg);
      final v = await c.loadReceipt(room, e);
      expect(v.status, BookReceiptStatus.ok);
      expect(v.preview, isNotNull);
      expect(previews, 1);
    });

    test('missing, invalid, unavailable: Platzhalter, die Dekodierung wird nie aufgerufen', () async {
      final e = await withReceipt();
      for (final s in <BookReceiptStatus>[BookReceiptStatus.missing, BookReceiptStatus.invalid, BookReceiptStatus.unavailable]) {
        gw.loadReceiptHandler = (r, ev, rc, a) => BookReceiptLoad(s, jpeg);
        final v = await c.loadReceipt(room, e);
        expect(v.status, s);
        expect(v.preview, isNull);
      }
      expect(previews, 0);
    });

    test('geprüfte Bytes, aber nicht anzeigbar: invalid, kein Absturz', () async {
      final e = await withReceipt();
      gw.loadReceiptHandler = (r, ev, rc, a) => BookReceiptLoad(BookReceiptStatus.ok, jpeg);
      previewResult = null;
      expect((await c.loadReceipt(room, e)).status, BookReceiptStatus.invalid);
    });

    test('Eintrag ohne Bon: missing ohne Gateway-Zugriff und ohne Dekodierung', () async {
      gw.bookCalls = 0;
      expect((await c.loadReceipt(room, own())).status, BookReceiptStatus.missing);
      expect(gw.bookCalls, 0);
      expect(previews, 0);
    });
  });

  CashBookView viewFor(String roomId, {required String owner, bool mine = true}) => CashBookView(
        meta: bookMeta(room: roomId, owner: owner),
        mine: mine,
        isPlaceholder: false,
        complete: true,
        blocked: false,
        pendingOwn: 0,
        monthTotalCents: 0,
        month: CashMonth.of(today),
      );

  group('Härtung (Mutationsprobe Teil 4a-1)', () {
    test('Ersteller zählt nach dem Raum (Gateway), nicht nach den Metadaten: mine und canLeave stimmen überein', () async {
      await store.putBook(bookMeta(room: '!a:fake.test', owner: me));
      await store.putBook(bookMeta(room: '!b:fake.test', owner: _cara));
      gw.fakeBooks = <BookRoomInfo>[const BookRoomInfo(roomId: '!a:fake.test', creatorId: _cara), BookRoomInfo(roomId: '!b:fake.test', creatorId: me)];
      c.start();
      await settle();
      final a = viewOf('!a:fake.test')!;
      final b = viewOf('!b:fake.test')!;
      expect((a.mine, c.canLeave(a)), (false, true), reason: 'Meta sagt „ich“, der Raum sagt Cara');
      expect((b.mine, c.canLeave(b)), (true, false), reason: 'Meta sagt Cara, der Raum sagt „ich“');
      gw.bookCalls = 0;
      await expectLater(c.leaveBook(b), throwsA(isA<CashBookException>()));
      expect(gw.bookCalls, 0);
    });

    Future<void> allActionsRejected(String why) async {
      await store.putEntry(room, own(cents: 777), publishedVersion: 1);
      gw.bookCalls = 0;
      var loads = 0;
      gw.loadReceiptHandler = (r, e, rc, a) {
        loads++;
        return BookReceiptLoad(BookReceiptStatus.ok, jpeg);
      };
      final v = viewFor(room, owner: me);
      final actions = <String, Future<Object?> Function()>{
        'leaveBook': () => c.leaveBook(viewFor(room, owner: _cara, mine: false)),
        'inviteMember': () => c.inviteMember(v, _cara),
        'removeMember': () => c.removeMember(v, _cara),
        'editEntry': () => c.editEntry(room, own()),
        'deleteEntry': () => c.deleteEntry(room, kEntryId1),
        'members': () => c.members(v),
        'inviteCandidates': () => c.inviteCandidates(v),
        'acceptInvitation': () => c.acceptInvitation('!x'),
        'createBook': () => c.createBook(title: 'Haushalt', currency: 'EUR'),
        'addEntry': () => c.addEntry(room, date: today, store: 'x', amountCents: 5),
        'pickPhoto': () => c.pickPhoto(),
      };
      for (final e in actions.entries) {
        await expectLater(e.value(), throwsA(isA<CashBookException>().having((x) => x.error, 'error', CashBookError.notAllowed)), reason: '$why: ${e.key}');
      }
      expect(await c.entriesOf(room, CashMonth.of(today)), isEmpty, reason: why);
      expect(await c.monthTotal(room, CashMonth.of(today)), 0, reason: why);
      expect((await c.loadReceipt(room, own().copyWith(receipt: const CashReceipt(eventId: r'$b', sha256: kHash, size: 10)))).status, BookReceiptStatus.missing, reason: why);
      expect(loads, 0, reason: '$why: der Bon wird nicht einmal geladen');
      expect(gw.bookCalls, 0, reason: '$why: keine Zugriffe auf das Gateway');
      expect(gw.invitedToBook, isEmpty);
      expect(gw.leftBooks, isEmpty);
    }

    test('gesperrt: jede Aktion und jede Abfrage wird abgelehnt, bevor etwas das Gateway erreicht', () async {
      c.dispose();
      await build(enabled: false);
      await allActionsRejected('gesperrt');
    });

    test('Nicht-Moderator: jede Aktion und jede Abfrage wird abgelehnt, bevor etwas das Gateway erreicht', () async {
      c.dispose();
      await build(moderator: false);
      await allActionsRejected('Nicht-Moderator');
    });

    test('ohne bekannte Familie: nicht verfügbar, kein Absturz, nichts sichtbar', () async {
      c.start();
      await settle();
      expect(c.books, isNotEmpty);
      await gw.logout();
      expect(gw.family, isNull);
      expect(c.isModerator, isFalse);
      expect(c.available, isFalse);
      await c.load();
      expect(c.books, isEmpty);
      await expectLater(c.leaveBook(viewFor(room, owner: _cara, mine: false)), throwsA(isA<CashBookException>()));
    });

    test('Eintrag ändern mit neuem Foto: das Foto wird zuerst aufbereitet (nie die rohen Bytes gesendet)', () async {
      prepare = (b) => jpeg;
      c.start();
      final e = await c.addEntry(room, date: today, store: 'A', amountCents: 5);
      final raw = Uint8List.fromList(<int>[7, 7, 7, 7]);
      await c.editEntry(room, e, newPhoto: raw);
      expect(gw.sentReceipts.single.bytes, jpeg);
      expect(gw.sentReceipts.single.bytes, isNot(raw));
    });

    test('Bon „ok“ ohne Bytes gibt es nicht: invalid, kein Bild, keine Dekodierung', () async {
      gw.loadReceiptHandler = (r, e, rc, a) => const BookReceiptLoad(BookReceiptStatus.ok);
      final e = own().copyWith(receipt: const CashReceipt(eventId: r'$b', sha256: kHash, size: 10));
      c.start();
      final v = await c.loadReceipt(room, e);
      expect(v.status, BookReceiptStatus.invalid);
      expect(v.preview, isNull);
      expect(previews, 0);
    });

    test('Einladungskandidaten: für Nicht-Ersteller leer und ohne Abfrage der Mitglieder', () async {
      c.start();
      await settle();
      gw.bookCalls = 0;
      expect(await c.inviteCandidates(viewFor(room, owner: _cara, mine: false)), isEmpty);
      expect(gw.bookCalls, 0, reason: 'keine Mitgliederabfrage');
    });

    test('pendingOwn zählt je Buch (zwei Bücher mit offenen Einträgen)', () async {
      await store.putBook(bookMeta(room: '!zwei:fake.test', owner: me));
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), BookRoomInfo(roomId: '!zwei:fake.test', creatorId: me)];
      await store.putEntry(room, own(), publishedVersion: 0);
      await store.putEntry(room, own(id: kEntryId2), publishedVersion: 0);
      await store.putEntry('!zwei:fake.test', own(id: '66666666-6666-4666-8666-666666666666'), publishedVersion: 0);
      c.start();
      await settle();
      expect(viewOf(room)!.pendingOwn, 2);
      expect(viewOf('!zwei:fake.test')!.pendingOwn, 1);
    });

    test('Buch nach erneutem Beitritt: erscheint wieder (das Merken „verlassen“ ist nur vorübergehend)', () async {
      await store.putBook(bookMeta(room: '!zwei:fake.test', owner: _cara));
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
      c.start();
      await settle();
      await c.leaveBook(viewOf('!zwei:fake.test')!);
      await pumpEventQueue();
      expect(viewOf('!zwei:fake.test'), isNull);
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me)];
      await settle();
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
      await settle();
      expect(viewOf('!zwei:fake.test'), isNotNull, reason: 'nach dem Verschwinden aus dem Gateway ist das Merken gelöscht');
    });

    test('eine Änderung während eines laufenden Aufbaus löst genau einen weiteren Aufbau aus (nichts geht verloren)', () async {
      final gated = _GatedStore();
      await gated.putBook(bookMeta(room: room, owner: me));
      final c2 = CashBookController(gateway: gw, service: CashBookService(store: gated, myUserId: me), store: gated, sync: sync, receipts: receipts, enabled: true, today: () => today);
      gated.gate = Completer<void>();
      final first = c2.load();
      await pumpEventQueue();
      expect(gated.booksCalls, 1, reason: 'der erste Lauf steht am Tor');
      await gated.putEntry(room, own(cents: 4200), publishedVersion: 1);
      final second = c2.load();
      gated.gate!.complete();
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(gated.booksCalls, 2, reason: 'genau ein Folgelauf');
      expect(c2.books.single.monthTotalCents, 4200, reason: 'der Stand nach der Änderung ist sichtbar');
      c2.dispose();
    });

    test('dispose: ein fremder Besitzer des Slots bleibt; der Gateway-Hörer ist weg; start nach dispose tut nichts', () async {
      c.start();
      await pumpEventQueue();
      void other() {}
      sync.onChanged = other;
      c.dispose();
      expect(sync.onChanged, other, reason: 'nur der eigene Eintrag wird gelöst');
      gw.bookCalls = 0;
      server.notifyAll();
      await pumpEventQueue();
      expect(gw.bookCalls, 0, reason: 'der Hörer am Gateway wurde entfernt');
      sync.onChanged = null;
      c.start();
      expect(sync.onChanged, isNull, reason: 'nach dispose startet nichts mehr');
    });
  });
}

/// Ablage, deren `books()` an einem Tor wartet (Test: Änderung während eines laufenden Aufbaus).
class _GatedStore extends MemoryCashBookStore {
  Completer<void>? gate;
  int booksCalls = 0;

  @override
  Future<List<CashBookMeta>> books() async {
    booksCalls++;
    final g = gate;
    if (g != null && booksCalls == 1) await g.future;
    return super.books();
  }
}
