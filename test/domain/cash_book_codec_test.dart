import 'package:family_nexus/domain/cash_book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';

/// #311, E-113: Format, Grenzen und Absenderbindung von Buch und Eintrag.
void main() {
  test('Grenzwerte aus E-113 stehen fest (3000 je Autor, 10 Bücher, 10 Mitglieder, 99 999 999 Cent, 2 Tage, 1 MiB, Sprung 1000)', () {
    expect(CashBookLimits.maxEntriesPerAuthor, 3000);
    expect(CashBookLimits.maxBooksPerFamily, 10);
    expect(CashBookLimits.maxMembersPerBook, 10);
    expect(CashBookLimits.maxAmountCents, 99999999);
    expect(CashBookLimits.maxSkew, const Duration(days: 2));
    expect(CashBookLimits.maxReceiptBytes, 1048576);
    expect(CashBookLimits.maxVersionStep, 1000);
    expect(CashBookLimits.maxTitle, 60);
    expect(CashBookLimits.maxStore, 60);
    expect(CashBookLimits.maxNote, 200);
  });

  test('Sperre: das Kassenbuch ist bis zum letzten Teil-PR ausgeschaltet (E-113)', () {
    expect(CashBookFlags.enabled, isFalse);
  });

  Map<String, Object?> wire(CashEntry e) => CashBookCodec.encodeEntry(e);
  CashEntry? dec(Map<String, Object?> c, {String sender = kBookOwner, DateTime? at}) =>
      CashBookCodec.decodeEntry(c, sender: sender, serverTime: at);

  group('Eintrag', () {
    test('Rundlauf mit und ohne Bon', () {
      final e = cashEntry(note: 'Wocheneinkauf');
      expect(dec(wire(e)), e);
      final r = cashEntry(receipt: const CashReceipt(eventId: r'$abc:fake.test', sha256: kHash, size: 4000));
      expect(dec(wire(r)), r);
      expect(wire(e).containsKey('receipt'), isFalse);
    });

    test('Betrag als Cent-Ganzzahl; negativ, zu groß, Gleitkommazahl werden verworfen', () {
      expect(dec(wire(cashEntry(cents: 0))), isNotNull);
      expect(dec(wire(cashEntry(cents: CashBookLimits.maxAmountCents))), isNotNull);
      expect(() => wire(cashEntry(cents: -1)), throwsStateError);
      expect(() => wire(cashEntry(cents: CashBookLimits.maxAmountCents + 1)), throwsStateError);
      expect(dec(wire(cashEntry())..['amount_cents'] = 12.5), isNull);
      expect(dec(wire(cashEntry())..['amount_cents'] = '1250'), isNull);
    });

    test('author muss der Absender sein (kein Schreiben in fremdem Namen)', () {
      expect(dec(wire(cashEntry(author: kBookMember)), sender: kBookOwner), isNull);
      expect(dec(wire(cashEntry(author: kBookMember)), sender: kBookMember), isNotNull);
      expect(dec(wire(cashEntry()), sender: 'anna'), isNull);
    });

    test('Datum: Grenzen und Tageswerte (kein 31. Februar, kein Jahr 1999 oder 2101)', () {
      for (final bad in <String>['2026-02-31', '1999-12-31', '2101-01-01', '2026-13-01', '2026-1-1', '20261120', '', 'x']) {
        expect(dec(wire(cashEntry())..['date'] = bad), isNull, reason: bad);
      }
      expect(dec(wire(cashEntry())..['date'] = '2000-01-01'), isNotNull);
      expect(dec(wire(cashEntry())..['date'] = '2100-12-31'), isNotNull);
      expect(dec(wire(cashEntry())..['date'] = 20261120), isNull);
    });

    test('Texte: Länge, Steuerzeichen, Typ', () {
      expect(() => wire(cashEntry(store: '')), throwsStateError);
      expect(() => wire(cashEntry(store: 'a' * 61)), throwsStateError);
      expect(() => wire(cashEntry(store: 'Ede\u202Eka')), throwsStateError);
      expect(() => wire(cashEntry(note: 'x' * 201)), throwsStateError);
      expect(dec(wire(cashEntry())..['store'] = 5), isNull);
      expect(dec(wire(cashEntry())..['note'] = null), isNull);
    });

    test('Version: 0, zu groß, falscher Typ', () {
      expect(() => wire(cashEntry(version: 0)), throwsStateError);
      expect(dec(wire(cashEntry())..['version'] = CashBookLimits.maxVersion + 1), isNull);
      expect(dec(wire(cashEntry())..['version'] = '1'), isNull);
    });

    test('Kennung, Schema, fehlende Felder', () {
      expect(dec(wire(cashEntry())..['id'] = 'nicht-uuid'), isNull);
      expect(dec(wire(cashEntry())..['v'] = 2), isNull);
      for (final k in <String>['id', 'author', 'version', 'deleted', 'date', 'store', 'amount_cents', 'note', 'updated_at']) {
        expect(dec(wire(cashEntry())..remove(k)), isNull, reason: k);
      }
    });

    test('updated_at gegen die Serverzeit: ±2 Tage; ohne Serverzeit (Ablage) keine Prüfung', () {
      final e = cashEntry(updatedAt: DateTime.utc(2026, 11, 20, 12));
      expect(dec(wire(e), at: DateTime.utc(2026, 11, 22, 11)), isNotNull);
      expect(dec(wire(e), at: DateTime.utc(2026, 11, 23, 13)), isNull);
      expect(dec(wire(e), at: DateTime.utc(2026, 11, 17, 11)), isNull);
      expect(dec(wire(e)), isNotNull);
    });

    test('Bon-Verweis: Hash, Größe, Ereignis-ID, Typ', () {
      CashEntry withReceipt(String id, String hash, int size) =>
          cashEntry(receipt: CashReceipt(eventId: id, sha256: hash, size: size));
      expect(() => wire(withReceipt(r'$a', 'ABC', 5)), throwsStateError);
      expect(() => wire(withReceipt(r'$a', kHash.toUpperCase(), 5)), throwsStateError, reason: 'nur Kleinbuchstaben-Hex');
      expect(() => wire(withReceipt(r'$a', kHash, 0)), throwsStateError);
      expect(() => wire(withReceipt(r'$a', kHash, CashBookLimits.maxReceiptBytes + 1)), throwsStateError);
      expect(() => wire(withReceipt('a', kHash, 5)), throwsStateError);
      final c = wire(withReceipt(r'$a', kHash, 5));
      expect(dec(c..['receipt'] = 'x'), isNull);
      expect(dec(wire(withReceipt(r'$a', kHash, 5))..['receipt'] = <String, Object?>{'event_id': r'$a', 'sha256': kHash}), isNull);
    });

    test('Löschmarke trägt keinen Inhalt und keinen Bon', () {
      final t = cashEntry(receipt: const CashReceipt(eventId: r'$a', sha256: kHash, size: 5)).tombstone(DateTime.utc(2026, 11, 21));
      expect(t.deleted, isTrue);
      expect(t.receipt, isNull);
      expect(t.store, '–');
      expect(t.amountCents, 0);
      expect(t.date, CashBookLimits.minDate);
      expect(t.note, '');
      expect(t.version, 2);
      expect(dec(wire(t)), t);
    });
  });

  group('Buch', () {
    Map<String, Object?> meta(CashBookMeta m) => CashBookCodec.encodeMeta(m);
    CashBookMeta? decMeta(Map<String, Object?> c, {String sender = kBookOwner}) =>
        CashBookCodec.decodeMeta(c, roomId: kBookRoom, sender: sender, creator: kBookOwner);

    test('Rundlauf; nur der Ersteller des Raums darf es senden', () {
      expect(decMeta(meta(bookMeta())), bookMeta());
      expect(decMeta(meta(bookMeta()), sender: kBookMember), isNull);
    });

    test('Titel, Währung, Version', () {
      expect(() => meta(bookMeta(title: '')), throwsStateError);
      expect(() => meta(bookMeta(title: 'x' * 61)), throwsStateError);
      expect(() => meta(bookMeta(currency: 'eur')), throwsStateError);
      expect(() => meta(bookMeta(currency: 'EURO')), throwsStateError);
      expect(() => meta(bookMeta(version: 0)), throwsStateError);
      expect(decMeta(meta(bookMeta())..['currency'] = 5), isNull);
      expect(decMeta(meta(bookMeta())..['v'] = 9), isNull);
    });
  });

  test('Summen: Monat und Jahr ohne gelöschte Einträge, in Cent', () {
    final list = <CashEntry>[
      cashEntry(id: kEntryId1, cents: 1000, date: DateTime.utc(2026, 11, 3)),
      cashEntry(id: kEntryId2, cents: 250, date: DateTime.utc(2026, 11, 30)),
      cashEntry(id: '33333333-3333-4333-8333-333333333333', cents: 999, date: DateTime.utc(2026, 10, 31)),
      cashEntry(id: '44444444-4444-4444-8444-444444444444', cents: 5000, date: DateTime.utc(2025, 11, 3)),
      cashEntry(id: '55555555-5555-4555-8555-555555555555', cents: 7777, date: DateTime.utc(2026, 11, 5)).tombstone(DateTime.utc(2026, 11, 6)),
    ];
    expect(CashTotals.month(list, 2026, 11), 1250);
    expect(CashTotals.year(list, 2026), 2249);
    expect(CashTotals.month(list, 2026, 12), 0);
    // Gelöscht, aber mit Betrag und Datum (aus einem Ereignis): zählt nie mit.
    final withAmount = cashEntry(id: '66666666-6666-4666-8666-666666666666', cents: 4000, date: DateTime.utc(2026, 11, 8)).copyWith(deleted: true);
    expect(CashTotals.month(<CashEntry>[...list, withAmount], 2026, 11), 1250);
    expect(CashTotals.year(<CashEntry>[...list, withAmount], 2026), 2249);
  });
}
