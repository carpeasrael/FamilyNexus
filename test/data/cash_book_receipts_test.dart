import 'dart:typed_data';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/sync/cash_book_receipts.dart';
import 'package:family_nexus/data/sync/cash_book_sync.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/fake_matrix.dart';
import '../support/memory_cash_book_store.dart';

/// #311, E-113 (Teil 3b): `CashBookReceipts` gegen den Gateway-Fake: Datei vor Eintrag, Aufräumen nach der
/// Veröffentlichung, Gegenlesen, Terminierung, Laden, Sperre.
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gw;
  late MemoryCashBookStore store;
  late CashBookService service;
  late CashBookReceipts receipts;
  var now = DateTime.utc(2026, 11, 22, 12);
  final jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6]);

  Future<void> build({bool enabled = true}) async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gw.createFamily('Familie');
    store = MemoryCashBookStore();
    service = CashBookService(store: store, myUserId: kBookOwner, clock: () => now);
    receipts = CashBookReceipts(gateway: gw, service: service, store: store, enabled: enabled, clock: () => now);
    await store.putBook(bookMeta());
  }

  setUp(() async {
    now = DateTime.utc(2026, 11, 22, 12);
    await build();
  });

  tearDown(() => receipts.dispose());

  CashReceipt rcpt(String id) => CashReceipt(eventId: id, sha256: kHash, size: 1000);

  /// Eintrag als veröffentlicht markieren (wie der Sync nach dem Senden).
  Future<void> publishAll() async {
    for (final p in await store.pending(kBookOwner)) {
      await store.markPublished(p.roomId, p.entry.author, p.entry.id, p.entry.version);
    }
  }

  List<String> redacted() => <String>[for (final r in gw.redactedReceipts) r.eventId];

  group('Datei zuerst, dann Eintrag', () {
    test('createWithReceipt: Datei gesendet, Eintrag trägt Ereignis, Hash und Größe der Bytes', () async {
      final e = await receipts.createWithReceipt(kBookRoom, date: now, store: 'Edeka', amountCents: 1250, jpeg: jpeg);
      expect(gw.sentReceipts.single.bytes, jpeg);
      expect(e.receipt, CashReceipt(eventId: r'$receipt1', sha256: ReceiptCheck.sha256Hex(jpeg), size: jpeg.length));
      expect((await store.getEntry(kBookRoom, kBookOwner, e.id))!.receipt, e.receipt);
    });

    test('scheitert das Senden der Datei, entsteht kein Eintrag', () async {
      gw.sendReceiptError = const GatewayException(GatewayError.notAllowed);
      await expectLater(receipts.createWithReceipt(kBookRoom, date: now, store: 'Edeka', amountCents: 5, jpeg: jpeg), throwsA(isA<GatewayException>()));
      expect(await store.entries(kBookRoom), isEmpty);
      expect(receipts.jobCount, 0);
    });

    test('scheitert der Eintrag, wird die verwaiste Datei sofort fällig und geschwärzt; die Ausnahme geht weiter', () async {
      await expectLater(receipts.createWithReceipt(kBookRoom, date: now, store: 'Edeka', amountCents: -1, jpeg: jpeg), throwsA(isA<CashBookException>()));
      expect(gw.sentReceipts, hasLength(1));
      expect(receipts.jobCount, 1);
      await receipts.flushCleanup();
      expect(redacted(), <String>[r'$receipt1']);
      expect(receipts.jobCount, 0);
    });

    test('updateWithReceipt: neue Datei, neue Fassung; scheitert die Änderung, wird die neue Datei aufgeräumt', () async {
      final e = await receipts.createWithReceipt(kBookRoom, date: now, store: 'Edeka', amountCents: 1, jpeg: jpeg);
      final r2 = await receipts.updateWithReceipt(kBookRoom, e.copyWith(amountCents: 2), jpeg);
      expect(r2.version, 2);
      expect(r2.receipt!.eventId, r'$receipt2');
      await expectLater(receipts.updateWithReceipt(kBookRoom, r2.copyWith(amountCents: -5), jpeg), throwsA(isA<CashBookException>()));
      await receipts.flushCleanup();
      expect(redacted(), <String>[r'$receipt3'], reason: 'nur die verwaiste neue Datei sofort; die frühere wartet auf die Veröffentlichung');
    });
  });

  group('Aufräumen erst nach der Veröffentlichung', () {
    test('Ersetzen: die alte Datei bleibt, solange die neue Fassung wartet, und wird danach geschwärzt', () async {
      final e = await receipts.createWithReceipt(kBookRoom, date: now, store: 'Edeka', amountCents: 1, jpeg: jpeg);
      await publishAll();
      await receipts.updateWithReceipt(kBookRoom, e, jpeg);
      await receipts.flushCleanup();
      expect(redacted(), isEmpty, reason: 'neue Fassung nicht veröffentlicht: nicht schwärzen');
      expect(receipts.jobCount, 1);
      await publishAll();
      await receipts.flushCleanup();
      expect(redacted(), <String>[r'$receipt1']);
    });

    test('Löschen und Entfernen des Bons: ebenso erst nach der Veröffentlichung', () async {
      final a = await receipts.createWithReceipt(kBookRoom, date: now, store: 'A', amountCents: 1, jpeg: jpeg);
      final b = await receipts.createWithReceipt(kBookRoom, date: now, store: 'B', amountCents: 1, jpeg: jpeg);
      await publishAll();
      await service.delete(kBookRoom, a.id);
      await service.update(kBookRoom, b.copyWith(clearReceipt: true));
      await receipts.flushCleanup();
      expect(redacted(), isEmpty);
      await publishAll();
      await receipts.flushCleanup();
      expect(redacted(), unorderedEquals(<String>[r'$receipt1', r'$receipt2']));
    });

    test('Warten auf die Veröffentlichung zählt nicht als Fehlversuch und verwirft nie', () async {
      final e = await receipts.createWithReceipt(kBookRoom, date: now, store: 'A', amountCents: 1, jpeg: jpeg);
      await service.delete(kBookRoom, e.id);
      for (var i = 0; i < 20; i++) {
        now = now.add(const Duration(hours: 1));
        await receipts.flushCleanup();
      }
      expect(receipts.jobCount, 1);
      expect(redacted(), isEmpty);
      await publishAll();
      await receipts.flushCleanup();
      expect(redacted(), <String>[r'$receipt1']);
    });

    test('Gegenlesen: verweist noch ein Eintrag auf die Datei (A → B → A), wird sie nicht geschwärzt', () async {
      final e = await service.create(kBookRoom, date: now, store: 'A', amountCents: 1, receipt: rcpt(r'$A'));
      await publishAll();
      final b = await service.update(kBookRoom, e.copyWith(receipt: rcpt(r'$B')));
      await service.update(kBookRoom, b.copyWith(receipt: rcpt(r'$A')));
      await publishAll();
      await receipts.flushCleanup();
      expect(redacted(), <String>[r'$B'], reason: 'A wird wieder verwendet, nur B ist frei');
    });

    test('der Eintrag ist lokal weg (Buch entfernt): der Auftrag entfällt ohne Schwärzen', () async {
      final e = await receipts.createWithReceipt(kBookRoom, date: now, store: 'A', amountCents: 1, jpeg: jpeg);
      await service.delete(kBookRoom, e.id);
      await store.deleteBook(kBookRoom);
      await receipts.flushCleanup();
      expect(receipts.jobCount, 0);
      expect(redacted(), isEmpty);
    });

    test('fremde Einträge, Empfang und restamp erzeugen nie einen Auftrag', () async {
      final foreign = cashEntry(author: kBookMember, receipt: rcpt(r'$f'));
      await service.applyEntry(kBookRoom, foreign);
      await service.applyEntry(kBookRoom, foreign.copyWith(version: 2, clearReceipt: true));
      expect(receipts.jobCount, 0);
    });

    test('derselbe Verweis wird nur einmal eingereiht', () async {
      final e = await service.create(kBookRoom, date: now, store: 'A', amountCents: 1, receipt: rcpt(r'$A'));
      final cleared = await service.update(kBookRoom, e.copyWith(clearReceipt: true));
      expect(receipts.jobCount, 1);
      final restored = await service.update(kBookRoom, cleared.copyWith(receipt: rcpt(r'$A')));
      await service.update(kBookRoom, restored.copyWith(clearReceipt: true));
      expect(receipts.jobCount, 1);
    });
  });

  group('Fehler und Terminierung', () {
    Future<void> orphan() async {
      await expectLater(receipts.createWithReceipt(kBookRoom, date: now, store: 'x', amountCents: -1, jpeg: jpeg), throwsA(isA<CashBookException>()));
    }

    test('dauerhafte Fehler (notAllowed, notFound, invalidInput) entfernen den Auftrag sofort', () async {
      for (final err in <GatewayError>[GatewayError.notAllowed, GatewayError.notFound, GatewayError.invalidInput]) {
        await orphan();
        gw.redactReceiptHandler = (_, _) => GatewayException(err);
        await receipts.flushCleanup();
        expect(receipts.jobCount, 0, reason: err.name);
      }
    });

    test('vorläufige Fehler: Backoff, erst nach Ablauf wieder, nach 8 Versuchen aufgegeben', () async {
      await orphan();
      var calls = 0;
      gw.redactReceiptHandler = (_, _) {
        calls++;
        return const GatewayException(GatewayError.serverUnreachable);
      };
      await receipts.flushCleanup();
      expect(calls, 1);
      expect(receipts.jobCount, 1);
      await receipts.flushCleanup();
      expect(calls, 1, reason: 'Backoff: noch nicht wieder dran');
      for (var i = 0; i < 20 && receipts.jobCount > 0; i++) {
        now = now.add(const Duration(hours: 1));
        await receipts.flushCleanup();
      }
      expect(calls, CashBookReceipts.maxAttempts);
      expect(receipts.jobCount, 0, reason: 'nach 8 vorläufigen Fehlversuchen aufgegeben');
    });

    test('ein späterer Erfolg nach vorläufigen Fehlern beendet den Auftrag', () async {
      await orphan();
      var n = 0;
      gw.redactReceiptHandler = (_, _) => ++n < 3 ? const GatewayException(GatewayError.serverUnreachable) : null;
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(hours: 1));
        await receipts.flushCleanup();
      }
      expect(receipts.jobCount, 0);
      expect(redacted(), <String>[r'$receipt1']);
    });

    test('höchstens 100 Aufträge: der älteste fällt weg', () async {
      for (var i = 0; i < CashBookReceipts.maxJobs + 5; i++) {
        final e = await service.create(kBookRoom, date: now, store: 'A$i', amountCents: 1, receipt: rcpt('\$f$i'));
        await service.delete(kBookRoom, e.id);
      }
      expect(receipts.jobCount, CashBookReceipts.maxJobs);
    });

    test('ohne Sitzung, ersten Sync oder Familie wird nichts geschwärzt', () async {
      await orphan();
      gw.syncDone = false;
      await receipts.flushCleanup();
      expect(redacted(), isEmpty);
      gw.syncDone = true;
      await gw.logout();
      await receipts.flushCleanup();
      expect(redacted(), isEmpty);
      expect(receipts.jobCount, 1);
    });
  });

  group('load', () {
    test('Zustände des Gateways werden durchgereicht; Autor und Verweis des Eintrags gehen mit', () async {
      final e = cashEntry(author: kBookMember, receipt: rcpt(r'$bon'));
      late CashReceipt seen;
      late String seenAuthor;
      gw.loadReceiptHandler = (room, ev, r, a) {
        seen = r;
        seenAuthor = a;
        return BookReceiptLoad(BookReceiptStatus.ok, jpeg);
      };
      final l = await receipts.load(kBookRoom, e);
      expect(l.status, BookReceiptStatus.ok);
      expect(l.bytes, jpeg);
      expect(seen, e.receipt);
      expect(seenAuthor, kBookMember);
      for (final s in <BookReceiptStatus>[BookReceiptStatus.invalid, BookReceiptStatus.missing, BookReceiptStatus.unavailable]) {
        gw.loadReceiptHandler = (_, _, _, _) => BookReceiptLoad(s);
        expect((await receipts.load(kBookRoom, e)).status, s);
      }
    });

    test('ohne Bon oder bei Löschmarke: missing ohne Gateway-Zugriff; Ausnahme des Gateways: unavailable', () async {
      gw.bookCalls = 0;
      expect((await receipts.load(kBookRoom, cashEntry())).status, BookReceiptStatus.missing);
      expect((await receipts.load(kBookRoom, cashEntry(deleted: true, receipt: rcpt(r'$x')))).status, BookReceiptStatus.missing);
      expect(gw.bookCalls, 0);
      gw.loadReceiptHandler = (_, _, _, _) => throw const GatewayException(GatewayError.notAllowed);
      expect((await receipts.load(kBookRoom, cashEntry(receipt: rcpt(r'$x')))).status, BookReceiptStatus.unavailable);
    });
  });

  group('Sperre und Sync', () {
    test('gesperrt: kein Rückruf, kein Gateway-Zugriff, Methoden wirken nicht', () async {
      receipts.dispose();
      await build(enabled: false);
      expect(service.onReceiptReleased, isNull);
      gw.bookCalls = 0;
      await expectLater(receipts.createWithReceipt(kBookRoom, date: now, store: 'x', amountCents: 1, jpeg: jpeg), throwsA(isA<CashBookException>()));
      await expectLater(receipts.attach(kBookRoom, jpeg), throwsA(isA<CashBookException>()));
      expect((await receipts.load(kBookRoom, cashEntry(receipt: rcpt(r'$x')))).status, BookReceiptStatus.missing);
      await receipts.flushCleanup();
      expect(gw.bookCalls, 0);
      expect(gw.sentReceipts, isEmpty);
      expect(CashBookFlags.enabled, isFalse);
      expect(CashBookReceipts(gateway: gw, service: service, store: store).enabled, isFalse);
    });

    test('dispose löst den Rückruf', () {
      expect(service.onReceiptReleased, isNotNull);
      receipts.dispose();
      expect(service.onReceiptReleased, isNull);
    });

    test('der Zeitgeber des Syncs arbeitet fällige Aufräumaufträge ab', () async {
      gw.fakeBooks = <BookRoomInfo>[const BookRoomInfo(roomId: kBookRoom, creatorId: kBookOwner)];
      final sync = CashBookSync(
        gateway: gw,
        service: service,
        store: store,
        familyRoom: gw.familyRoom!.id,
        enabled: true,
        receipts: receipts,
        retryInterval: const Duration(hours: 1),
        clock: () => now,
      );
      await expectLater(receipts.createWithReceipt(kBookRoom, date: now, store: 'x', amountCents: -1, jpeg: jpeg), throwsA(isA<CashBookException>()));
      await sync.tick();
      expect(redacted(), <String>[r'$receipt1']);
      sync.dispose();
    });
  });
}
