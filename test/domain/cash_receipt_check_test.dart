import 'dart:typed_data';

import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';

/// #311, E-113 (Teil 3b): reine Prüfungen der Bon-Datei.
void main() {
  final jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5]);
  CashReceipt receiptOf(Uint8List b) => CashReceipt(eventId: r'$bon', sha256: ReceiptCheck.sha256Hex(b), size: b.length);

  ReceiptVerdict info({
    String sender = kBookMember,
    String author = kBookMember,
    String? msgtype = 'm.image',
    String? mime = 'image/jpeg',
    int? size,
    CashReceipt? receipt,
  }) =>
      ReceiptCheck.verifyInfo(
        sender: sender,
        author: author,
        msgtype: msgtype,
        mimeType: mime,
        infoSize: size ?? jpeg.length,
        receipt: receipt ?? receiptOf(jpeg),
      );

  test('SHA-256: Referenzwerte', () {
    expect(ReceiptCheck.sha256Hex(Uint8List(0)), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(ReceiptCheck.sha256Hex(Uint8List.fromList('abc'.codeUnits)), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('JPEG-Kennung: FF D8 FF; kürzer oder anders nicht', () {
    expect(ReceiptCheck.looksLikeJpeg(jpeg), isTrue);
    expect(ReceiptCheck.looksLikeJpeg(Uint8List.fromList(<int>[0xFF, 0xD8])), isFalse);
    expect(ReceiptCheck.looksLikeJpeg(Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47])), isFalse);
    expect(ReceiptCheck.looksLikeJpeg(Uint8List(0)), isFalse);
    expect(ReceiptCheck.looksLikeJpeg(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFE])), isFalse);
  });

  group('verifyInfo (vor dem Laden)', () {
    test('gültig', () => expect(info(), ReceiptVerdict.ok));
    test('m.file und Großschreibung der MIME sind erlaubt', () {
      expect(info(msgtype: 'm.file'), ReceiptVerdict.ok);
      expect(info(mime: 'IMAGE/JPEG'), ReceiptVerdict.ok);
    });
    test('Absender ungleich Autor', () => expect(info(sender: kBookOwner), ReceiptVerdict.invalid));
    test('Nachrichtentyp: m.text, fehlt', () {
      expect(info(msgtype: 'm.text'), ReceiptVerdict.invalid);
      expect(info(msgtype: null), ReceiptVerdict.invalid);
    });
    test('MIME: png, fehlt', () {
      expect(info(mime: 'image/png'), ReceiptVerdict.invalid);
      expect(info(mime: null), ReceiptVerdict.invalid);
    });
    test('info.size: fehlt, ungleich, genau 1 MiB erlaubt (wenn gleich), 1 MiB + 1 nicht', () {
      expect(ReceiptCheck.verifyInfo(sender: 'a', author: 'a', msgtype: 'm.image', mimeType: 'image/jpeg', infoSize: null, receipt: receiptOf(jpeg)), ReceiptVerdict.invalid);
      expect(info(size: jpeg.length + 1), ReceiptVerdict.invalid);
      const big = CashBookLimits.maxReceiptBytes;
      final bigReceipt = CashReceipt(eventId: r'$b', sha256: ReceiptCheck.sha256Hex(jpeg), size: big);
      expect(info(size: big, receipt: bigReceipt), ReceiptVerdict.ok);
      final over = CashReceipt(eventId: r'$b', sha256: ReceiptCheck.sha256Hex(jpeg), size: big + 1);
      expect(info(size: big + 1, receipt: over), ReceiptVerdict.invalid, reason: 'über dem Limit, selbst wenn beide gleich sind');
    });
  });

  group('verifyBytes (nach dem Laden)', () {
    test('gültig', () => expect(ReceiptCheck.verifyBytes(jpeg, receiptOf(jpeg)), ReceiptVerdict.ok));
    test('Hash anders bei gleicher Länge', () {
      final other = Uint8List.fromList(jpeg)..[5] ^= 1;
      expect(ReceiptCheck.verifyBytes(other, receiptOf(jpeg)), ReceiptVerdict.invalid);
    });
    test('Länge anders', () {
      final longer = Uint8List.fromList(<int>[...jpeg, 0]);
      expect(ReceiptCheck.verifyBytes(longer, receiptOf(jpeg)), ReceiptVerdict.invalid);
    });
    test('kein JPEG trotz passendem Hash und passender Länge', () {
      final png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
      expect(ReceiptCheck.verifyBytes(png, receiptOf(png)), ReceiptVerdict.invalid);
    });
    test('über 1 MiB: abgelehnt, auch wenn Hash und Größe im Verweis stimmen würden', () {
      final big = Uint8List(CashBookLimits.maxReceiptBytes + 1)..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
      final r = CashReceipt(eventId: r'$b', sha256: ReceiptCheck.sha256Hex(big), size: big.length);
      expect(ReceiptCheck.verifyBytes(big, r), ReceiptVerdict.invalid);
    });
  });
}
