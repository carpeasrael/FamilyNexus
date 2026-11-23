import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'cash_book.dart';

/// Ergebnis der Prüfung einer Bon-Datei.
enum ReceiptVerdict { ok, invalid }

/// Zustand beim Laden einer Bon-Datei (#311, E-113). Die Oberfläche zeigt bei jedem Wert außer [ok] einen Platzhalter und
/// dekodiert nur bei [ok].
enum BookReceiptStatus {
  /// Die Datei ist geprüft (Absender, Größe, Hash, Magic).
  ok,

  /// Das Ereignis existiert nicht oder ist geschwärzt.
  missing,

  /// Eine Prüfung ist gescheitert (Fälschung, falscher Typ, falsche Größe oder Hash, Klartext).
  invalid,

  /// Netz, Server oder noch fehlender Schlüssel: später erneut versuchen.
  unavailable,
}

class BookReceiptLoad {
  const BookReceiptLoad(this.status, [this.bytes]);
  final BookReceiptStatus status;

  /// Nur bei [BookReceiptStatus.ok].
  final Uint8List? bytes;
}

/// Reine Prüfungen für Bon-Dateien (#311, E-113): vor dem Laden anhand der Angaben des Ereignisses, nach dem Laden anhand
/// der Bytes. Nichts davon dekodiert ein Bild.
class ReceiptCheck {
  const ReceiptCheck._();

  /// JPEG beginnt mit `FF D8 FF`.
  static bool looksLikeJpeg(Uint8List b) => b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  static String sha256Hex(Uint8List b) => crypto.sha256.convert(b).toString();

  /// Vor dem Laden: Absender der Datei == Autor des Eintrags, Nachrichtentyp `m.image` oder `m.file`, MIME `image/jpeg`,
  /// `info.size` vorhanden, höchstens [CashBookLimits.maxReceiptBytes] und gleich der Größe im Eintrag.
  static ReceiptVerdict verifyInfo({
    required String sender,
    required String author,
    required String? msgtype,
    required String? mimeType,
    required int? infoSize,
    required CashReceipt receipt,
  }) {
    if (sender != author) return ReceiptVerdict.invalid;
    if (msgtype != 'm.image' && msgtype != 'm.file') return ReceiptVerdict.invalid;
    if (mimeType?.toLowerCase() != 'image/jpeg') return ReceiptVerdict.invalid;
    if (infoSize == null || infoSize > CashBookLimits.maxReceiptBytes || infoSize != receipt.size) {
      return ReceiptVerdict.invalid;
    }
    return ReceiptVerdict.ok;
  }

  /// Nach dem Laden: Länge ≤ 1 MiB und gleich der Größe im Eintrag, JPEG-Magic, SHA-256 gleich dem Hash im Eintrag.
  static ReceiptVerdict verifyBytes(Uint8List b, CashReceipt receipt) {
    if (b.length > CashBookLimits.maxReceiptBytes || b.length != receipt.size) return ReceiptVerdict.invalid;
    if (!looksLikeJpeg(b)) return ReceiptVerdict.invalid;
    if (sha256Hex(b) != receipt.sha256) return ReceiptVerdict.invalid;
    return ReceiptVerdict.ok;
  }
}
