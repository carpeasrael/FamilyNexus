import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'cash_book.dart';
import 'image_decoding.dart';
import 'receipt_photo_processing.dart';

/// Rohpixel (RGBA) eines Bon-Fotos für die Anzeige (#311, E-113): fremde Bytes erreichen keinen nativen Decoder.
class ReceiptPreview {
  const ReceiptPreview({required this.width, required this.height, required this.rgba});
  final int width;
  final int height;
  final Uint8List rgba;

  /// Dekodiert **bereits geprüfte** Bytes ([ReceiptCheck]) im speichersicheren Dart-Paket `image`, mit denselben Grenzen,
  /// die die Aufbereitung erzeugt: Eingabe ≤ 1 MiB, lange Kante ≤ 3000, höchstens 4 MP (Rohpixel höchstens 16 MB). `null`
  /// bei jedem Fehler (kein Bild, zu groß, defekt). Nie aufrufen, solange der Zustand nicht `ok` ist.
  static ReceiptPreview? decode(Uint8List verifiedBytes) {
    try {
      final frame = ImageDecoding.decode(
        verifiedBytes,
        maxInputBytes: CashBookLimits.maxReceiptBytes,
        maxSide: ReceiptPhotoProcessing.maxLongSide,
        pixelLimit: ReceiptPhotoProcessing.maxOutputPixels,
      );
      final rgba = frame.convert(numChannels: 4, format: img.Format.uint8, alpha: 255);
      return ReceiptPreview(width: rgba.width, height: rgba.height, rgba: rgba.getBytes(order: img.ChannelOrder.rgba));
    } on ImageDecodeException {
      return null;
    } catch (_) {
      // Jede weitere Ausnahme des Decoders heißt: nicht anzeigbar.
      return null;
    }
  }
}
