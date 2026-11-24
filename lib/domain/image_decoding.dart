import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Gründe, warum eine Bilddatei nicht dekodiert wird.
enum ImageDecodeError {
  /// Kein JPEG, PNG oder WebP (zum Beispiel HEIC oder GIF).
  unsupportedFormat,

  /// Die Datei ist größer als erlaubt.
  tooLarge,

  /// Mehr Pixel je Seite oder im Ganzen als erlaubt.
  tooManyPixels,

  /// Der Decoder liest das Bild nicht (defekt, abgeschnitten).
  notDecodable,
}

class ImageDecodeException implements Exception {
  const ImageDecodeException(this.error);
  final ImageDecodeError error;

  @override
  String toString() => 'ImageDecodeException(${error.name})';
}

/// Gemeinsame, speichersichere Dekodierung für Avatar-Fotos und Bon-Fotos (#434, #311): im Dart-Paket `image`.
///
/// Reihenfolge (sicherheitsrelevant): Dateigröße, Format (nur JPEG, PNG, WebP), Maße aus dem **Kopf** vor jeder
/// Dekodierung, nur das **erste** Bild, danach die EXIF-Drehung.
class ImageDecoding {
  const ImageDecoding._();

  static img.Image decode(
    Uint8List input, {
    required int maxInputBytes,
    required int maxSide,
    required int pixelLimit,
  }) {
    if (input.length > maxInputBytes) throw const ImageDecodeException(ImageDecodeError.tooLarge);
    final decoder = img.findDecoderForData(input);
    if (decoder is! img.JpegDecoder && decoder is! img.PngDecoder && decoder is! img.WebPDecoder) {
      throw const ImageDecodeException(ImageDecodeError.unsupportedFormat);
    }
    final img.Image? frame;
    try {
      final info = decoder!.startDecode(input);
      if (info == null) throw const ImageDecodeException(ImageDecodeError.notDecodable);
      if (info.width < 1 || info.height < 1) {
        throw const ImageDecodeException(ImageDecodeError.notDecodable);
      }
      if (info.width > maxSide || info.height > maxSide || info.width * info.height > pixelLimit) {
        throw const ImageDecodeException(ImageDecodeError.tooManyPixels);
      }
      // Nur das erste Bild: `decodeImage` würde bei Animationen alle Einzelbilder in den Speicher holen.
      frame = decoder.decodeFrame(0);
    } on ImageDecodeException {
      rethrow;
    } catch (_) {
      // Jede Ausnahme des Decoders heißt: das Bild ist nicht lesbar (defekt, abgeschnitten).
      throw const ImageDecodeException(ImageDecodeError.notDecodable);
    }
    if (frame == null) throw const ImageDecodeException(ImageDecodeError.notDecodable);
    return img.bakeOrientation(frame);
  }
}
