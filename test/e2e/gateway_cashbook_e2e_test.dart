import 'dart:typed_data';

import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/sync/cash_book_receipts.dart';
import 'package:family_nexus/data/sync/cash_book_sync.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/receipt_photo_processing.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/memory_cash_book_store.dart';
import 'e2e_support.dart';

/// #311, E-113 (Teil 2c): Kassenbuch als eigener verschlüsselter Raum gegen den echten Synapse, über die ganze Kette
/// (Gateway, Zeitleisten, Sync, lokale Ablage). Läuft nur mit `tool/e2e.sh` (Docker, Synapse, vodozemac); ohne
/// diese Umgebung ist der Test **nicht ausgeführt** (übersprungen), nie bestanden.
///
/// Der Schalter `CashBookFlags.enabled` ist in diesem Stand `false`; die Tests schalten das Gateway und die Sync-Klasse
/// ausdrücklich über die Konstruktoren ein.

/// Wie in der App: Anmeldung, dann Pflicht-Schlüsselsicherung (nur verifizierte Geräte erhalten Schlüssel).
Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix, ensureAvatarPermission: false, cashBooksEnabled: true);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

/// Beitritt über Anfrage → Bestätigung → Annahme.
Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => user.joinRequestPending, what: 'Anfrage wartet');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht Anfrage');
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

/// Ein Gerät mit lokaler Ablage, Dienst und eingeschaltetem Sync.
class _Peer {
  _Peer(this.gateway, this.store, this.service, this.sync);
  final SdkMatrixGateway gateway;
  final MemoryCashBookStore store;
  final CashBookService service;
  final CashBookSync sync;

  String get userId => gateway.userId!;

  static _Peer start(SdkMatrixGateway g) {
    final store = MemoryCashBookStore();
    final service = CashBookService(store: store, myUserId: g.userId!);
    final sync = CashBookSync(
      gateway: g,
      service: service,
      store: store,
      familyRoom: g.family!.roomId,
      enabled: true,
      retryInterval: const Duration(seconds: 2),
      memberFetchInterval: const Duration(seconds: 1),
    );
    sync.start();
    return _Peer(g, store, service, sync);
  }

  void close() => sync.dispose();
}

void main() {
  group('Kassenbuch als verschlüsselter Raum (#311, E-113)', skip: E2e.enabled ? false : E2e.skipReason, () {
    final peers = <_Peer>[];
    tearDown(() {
      for (final p in peers) {
        p.close();
      }
      peers.clear();
    });

    /// Zwei Moderatoren einer Familie (der zweite wird befördert), beide mit Sync.
    Future<({SdkMatrixGateway g1, SdkMatrixGateway g2, _Peer p1, _Peer p2})> twoModerators(String prefix) async {
      final g1 = await _login('${prefix}1');
      await g1.createFamily('Buch-Familie');
      await E2e.until(() => g1.family != null, what: 'Familie angelegt');
      final g2 = await _login('${prefix}2');
      await _join(g1, g2);
      await g1.promote(g2.userId!);
      await E2e.until(() => g2.family?.myRole == Role.moderator, what: 'G2 ist Moderator');
      final p1 = _Peer.start(g1);
      final p2 = _Peer.start(g2);
      peers.addAll(<_Peer>[p1, p2]);
      return (g1: g1, g2: g2, p1: p1, p2: p2);
    }

    test('anlegen, einladen, annehmen, Einträge in beide Richtungen, Metadaten, Entfernen', () async {
      final t = await twoModerators('cb-a');
      final room = await t.g1.createBook();
      await E2e.until(() => t.g1.books.any((b) => b.roomId == room), what: 'G1 sieht sein Buch');
      await t.p1.service.applyBook(CashBookMeta(roomId: room, title: 'Haushalt', currency: 'EUR', owner: t.g1.userId!), published: false);

      await t.g1.inviteToBook(room, t.g2.userId!);
      await E2e.until(() => t.g2.bookInvitations.any((i) => i.roomId == room), what: 'G2 sieht die Einladung');
      expect(t.g2.invitations.where((i) => i.roomId == room), isEmpty, reason: 'nie als Familieneinladung');
      await t.g2.acceptBookInvitation(room);
      await E2e.until(() => t.g2.books.any((b) => b.roomId == room), what: 'G2 ist im Buch');

      // Metadaten (Ersteller) und Eintrag von G1.
      final e1 = await t.p1.service.create(room, date: DateTime.now(), store: 'Edeka', amountCents: 1250);
      await t.p1.sync.publishPending();
      await E2e.untilAsync(() async => (await t.p2.store.getBook(room))?.title == 'Haushalt', what: 'G2 kennt den Titel');
      await E2e.untilAsync(() async => await t.p2.store.getEntry(room, t.g1.userId!, e1.id) != null, what: 'G2 sieht den Eintrag von G1');

      // Eintrag von G2 zurück zu G1.
      final e2 = await t.p2.service.create(room, date: DateTime.now(), store: 'Rewe', amountCents: 800);
      await t.p2.sync.publishPending();
      await E2e.untilAsync(() async => await t.p1.store.getEntry(room, t.g2.userId!, e2.id) != null, what: 'G1 sieht den Eintrag von G2');
      expect(await t.p1.service.monthTotal(room, DateTime.now().year, DateTime.now().month), 2050);

      // Entfernen: G2 verliert den Zugriff.
      await t.g1.removeFromBook(room, t.g2.userId!);
      await E2e.until(() => t.g2.bookRoomGone(room), what: 'G2 ist nicht mehr im Buch');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Bon-Foto: senden, empfangen, Hash geprüft; Fälschung durch ein anderes Mitglied; Schwärzen nur eigener Dateien', () async {
      final t = await twoModerators('cb-d');
      final room = await t.g1.createBook();
      await E2e.until(() => t.g1.books.any((b) => b.roomId == room), what: 'Buch da');
      await t.g1.inviteToBook(room, t.g2.userId!);
      await E2e.until(() => t.g2.bookInvitations.any((i) => i.roomId == room), what: 'Einladung');
      await t.g2.acceptBookInvitation(room);
      await E2e.until(() => t.g2.books.any((b) => b.roomId == room), what: 'G2 im Buch');
      await t.p1.service.applyBook(CashBookMeta(roomId: room, title: 'Bons', currency: 'EUR', owner: t.g1.userId!), published: false);

      final jpeg = ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodeJpg(img.Image(width: 300, height: 400)))).bytes;
      final r1 = CashBookReceipts(gateway: t.g1, service: t.p1.service, store: t.p1.store, enabled: true);
      final r2 = CashBookReceipts(gateway: t.g2, service: t.p2.service, store: t.p2.store, enabled: true);
      addTearDown(() {
        r1.dispose();
        r2.dispose();
      });
      final entry = await r1.createWithReceipt(room, date: DateTime.now(), store: 'Edeka', amountCents: 990, jpeg: jpeg);
      await t.p1.sync.publishPending();
      await E2e.untilAsync(() async => await t.p2.store.getEntry(room, t.g1.userId!, entry.id) != null, what: 'G2 sieht den Eintrag');
      final got = await r2.load(room, (await t.p2.store.getEntry(room, t.g1.userId!, entry.id))!);
      expect(got.status, BookReceiptStatus.ok);
      expect(got.bytes, jpeg);

      // Fälschung: Ein Eintrag von G2, der die Datei von G1 als seinen Bon ausgibt, ist ungültig (Absender != Autor).
      final forged = CashEntry(
        id: '33333333-3333-4333-8333-333333333333',
        author: t.g2.userId!,
        date: DateTime.now(),
        store: 'Fälschung',
        amountCents: 1,
        receipt: entry.receipt,
        updatedAt: DateTime.now(),
      );
      expect((await r1.load(room, forged)).status, BookReceiptStatus.invalid);

      // Schwärzen: nur eigene Dateien.
      await expectLater(
        t.g2.redactBookReceipt(room, entry.receipt!.eventId),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
      await t.g1.redactBookReceipt(room, entry.receipt!.eventId);
      await E2e.untilAsync(
        () async => (await r2.load(room, (await t.p2.store.getEntry(room, t.g1.userId!, entry.id))!)).status == BookReceiptStatus.missing,
        what: 'geschwärzte Datei gilt als fehlend',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Familienmitglied ohne Moderatorrolle wird nicht eingeladen', () async {
      final t = await twoModerators('cb-b');
      final g3 = await _login('cb-b3');
      await _join(t.g1, g3);
      final room = await t.g1.createBook();
      await E2e.until(() => t.g1.books.any((b) => b.roomId == room), what: 'Buch da');
      await expectLater(
        t.g1.inviteToBook(room, g3.userId!),
        throwsA(isA<GatewayException>().having((e) => e.error, 'error', GatewayError.notAllowed)),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('neues Gerät: der Verlauf wird nachgeladen (Backfill), Einträge und Titel sind wieder da', () async {
      final t = await twoModerators('cb-c');
      final room = await t.g1.createBook();
      await E2e.until(() => t.g1.books.any((b) => b.roomId == room), what: 'Buch da');
      await t.p1.service.applyBook(CashBookMeta(roomId: room, title: 'Urlaub', currency: 'EUR', owner: t.g1.userId!), published: false);
      await t.g1.inviteToBook(room, t.g2.userId!);
      await E2e.until(() => t.g2.bookInvitations.any((i) => i.roomId == room), what: 'Einladung');
      await t.g2.acceptBookInvitation(room);
      final e = await t.p1.service.create(room, date: DateTime.now(), store: 'Tankstelle', amountCents: 5000);
      await t.p1.sync.publishPending();
      await E2e.untilAsync(() async => await t.p2.store.getEntry(room, t.g1.userId!, e.id) != null, what: 'Eintrag angekommen');
      // Ein frisches Gerät desselben Kontos beginnt ohne lokalen Bestand und liest den Verlauf.
      final fresh = _Peer.start(t.g2);
      peers.add(fresh);
      await E2e.untilAsync(() async => await fresh.store.getEntry(room, t.g1.userId!, e.id) != null, what: 'Backfill/Replay liefert den Eintrag');
      await E2e.untilAsync(() async => (await fresh.store.getBook(room))?.title == 'Urlaub', what: 'Titel aus dem Verlauf');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
