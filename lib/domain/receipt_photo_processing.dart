import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'cash_book.dart';
import 'image_decoding.dart';

/// Gründe, warum ein gewähltes Bild nicht als Bon-Foto taugt (#311, E-113).
enum ReceiptPhotoProcessingError {
  /// Kein JPEG, PNG oder WebP (zum Beispiel HEIC oder GIF).
  unsupportedFormat,

  /// Die Datei ist größer als [ReceiptPhotoProcessing.maxInputBytes].
  tooLarge,

  /// Mehr als [ReceiptPhotoProcessing.maxSide] Pixel je Seite oder mehr als die erlaubten Megapixel.
  tooManyPixels,

  /// Der Decoder liest das Bild nicht (defekt, abgeschnitten).
  notDecodable,

  /// Auch bei der kleinsten Größe und Qualität bleibt das JPEG über dem harten Limit.
  cannotShrink,
}

class ReceiptPhotoProcessingException implements Exception {
  const ReceiptPhotoProcessingException(this.error);
  final ReceiptPhotoProcessingError error;

  @override
  String toString() => 'ReceiptPhotoProcessingException(${error.name})';
}

/// Aufbereitetes Bon-Foto: JPEG-Bytes und die Maße des erzeugten Bildes.
class ReceiptPhoto {
  const ReceiptPhoto({required this.bytes, required this.width, required this.height});
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Bildaufbereitung für Bon-Fotos (#311, E-113): im speichersicheren Dart-Paket `image`, mit derselben Dekodierung wie
/// die Avatar-Fotos ([ImageDecoding]: Format, Größe und Maße vor dem Dekodieren, nur das erste Bild, EXIF-Drehung).
///
/// Das Seitenverhältnis bleibt. **Hart:** lange Kante ≤ [maxLongSide] und höchstens [maxOutputPixels] Pixel, nie
/// vergrößert. Die kurze Kante von [minShortSide] ist nur ein Ziel: Es ergibt sich aus dem Verzicht auf unnötiges
/// Verkleinern, nicht aus einer Schranke. Transparenz kommt auf Weiß, EXIF und ICC werden geleert, Ergebnis ist ein
/// Baseline-JPEG (4:2:0).
///
/// Rückfallkette: Stufen [scaleSteps] (Faktor auf die Basisgröße), je Stufe Qualität [qualityStart] bis [qualityMin]
/// in Schritten von 5. Das erste Ergebnis ≤ `targetBytes` gewinnt; wird das nie erreicht, gilt das kleinste erzeugte
/// Ergebnis, wenn es ≤ `hardLimitBytes` ist, sonst [ReceiptPhotoProcessingError.cannotShrink].
class ReceiptPhotoProcessing {
  const ReceiptPhotoProcessing._();

  /// Größe der gewählten Datei.
  static const int maxInputBytes = 15 * 1024 * 1024;

  /// Eingabe: höchstens so viele Pixel je Seite und im Ganzen (Web: [maxPixelsWeb]).
  static const int maxSide = 4096;
  static const int maxPixels = 12 * 1000 * 1000;
  static const int maxPixelsWeb = 4 * 1000 * 1000;

  /// Ausgabe.
  static const int maxLongSide = 3000;
  static const int maxOutputPixels = 4 * 1000 * 1000;
  static const int minShortSide = 1000;
  static const int qualityStart = 85;
  static const int qualityMin = 60;
  static const int targetBytes = 600 * 1024;
  static const List<double> scaleSteps = <double>[1.0, 0.85, 0.7, 0.55, 0.4];

  /// Basisgröße (Breite, Höhe) zu einer ausgerichteten Quelle: harte Grenzen, nie vergrößert, `floor`, Kanten ≥ 1.
  static ({int width, int height}) baseSize(int width, int height) {
    final s = math.min(1.0, math.min(maxLongSide / math.max(width, height), math.sqrt(maxOutputPixels / (width * height))));
    return (width: math.max(1, (width * s).floor()), height: math.max(1, (height * s).floor()));
  }

  /// Das Foto als JPEG. Wirft [ReceiptPhotoProcessingException].
  static ReceiptPhoto prepare(
    Uint8List input, {
    int pixelLimit = maxPixels,
    int targetBytes = ReceiptPhotoProcessing.targetBytes,
    int hardLimitBytes = CashBookLimits.maxReceiptBytes,
  }) {
    final img.Image oriented;
    try {
      oriented = ImageDecoding.decode(input, maxInputBytes: maxInputBytes, maxSide: maxSide, pixelLimit: pixelLimit);
    } on ImageDecodeException catch (e) {
      throw ReceiptPhotoProcessingException(switch (e.error) {
        ImageDecodeError.unsupportedFormat => ReceiptPhotoProcessingError.unsupportedFormat,
        ImageDecodeError.tooLarge => ReceiptPhotoProcessingError.tooLarge,
        ImageDecodeError.tooManyPixels => ReceiptPhotoProcessingError.tooManyPixels,
        ImageDecodeError.notDecodable => ReceiptPhotoProcessingError.notDecodable,
      });
    }
    final base = baseSize(oriented.width, oriented.height);
    ReceiptPhoto? smallest;
    for (final f in scaleSteps) {
      final w = math.max(1, (base.width * f).floor());
      final h = math.max(1, (base.height * f).floor());
      var frame = (w == oriented.width && h == oriented.height)
          ? oriented
          : img.copyResize(oriented, width: w, height: h, interpolation: img.Interpolation.average);
      if (frame.hasAlpha) {
        // JPEG kennt keine Transparenz: auf Weiß setzen statt Schwarz.
        final bg = img.Image(width: frame.width, height: frame.height, numChannels: 4);
        img.fill(bg, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(bg, frame);
        frame = bg;
      }
      frame = frame.convert(numChannels: 3);
      frame.exif = img.ExifData();
      frame.iccProfile = null;
      for (var q = qualityStart; q >= qualityMin; q -= 5) {
        final out = Uint8List.fromList(img.encodeJpg(frame, quality: q, chroma: img.JpegChroma.yuv420));
        final photo = ReceiptPhoto(bytes: out, width: frame.width, height: frame.height);
        if (out.length <= targetBytes) return photo;
        if (smallest == null || out.length < smallest.bytes.length) smallest = photo;
      }
    }
    if (smallest != null && smallest.bytes.length <= hardLimitBytes) return smallest;
    throw const ReceiptPhotoProcessingException(ReceiptPhotoProcessingError.cannotShrink);
  }
}
