import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'avatar_photo.dart';

/// Gründe, warum ein gewähltes Bild nicht als Avatar-Foto taugt (#434, E-111).
enum AvatarPhotoProcessingError {
  /// Kein JPEG, PNG oder WebP (zum Beispiel HEIC oder GIF).
  unsupportedFormat,

  /// Die Datei ist größer als [AvatarPhotoProcessing.maxInputBytes].
  tooLarge,

  /// Mehr als [AvatarPhotoProcessing.maxSide] Pixel je Seite oder mehr als die erlaubten Megapixel.
  tooManyPixels,

  /// Der Decoder liest das Bild nicht (defekt, abgeschnitten).
  notDecodable,

  /// Auch bei der kleinsten Größe und Qualität bleibt das JPEG über [AvatarPhotoLimits.maxBytes].
  cannotShrink,
}

class AvatarPhotoProcessingException implements Exception {
  const AvatarPhotoProcessingException(this.error);
  final AvatarPhotoProcessingError error;

  @override
  String toString() => 'AvatarPhotoProcessingException(${error.name})';
}

/// Ausschnitt eines Bildes, unabhängig von dessen Größe: [centerX] und [centerY] sind Anteile (0 bis 1) der Breite und
/// Höhe des **ausgerichteten** Bildes (nach der EXIF-Drehung), [zoom] ≥ 1 vergrößert den Ausschnitt. Der Ausschnitt ist
/// ein Quadrat mit der Seitenlänge `min(Breite, Höhe) / zoom` und bleibt immer im Bild.
class AvatarCrop {
  const AvatarCrop({this.centerX = 0.5, this.centerY = 0.5, this.zoom = 1});

  final double centerX;
  final double centerY;
  final double zoom;

  /// Mitte des Bildes, größtmöglicher Ausschnitt.
  static const AvatarCrop center = AvatarCrop();

  /// Ausschnitt aus dem Betrachter eines Vorschaubildes (`InteractiveViewer`): [transform] bildet das Kind (das Bild in
  /// der Größe, in der es die Fläche [viewportSide] mit der kürzeren Seite füllt) auf den Betrachter ab. Reine
  /// Rechnung ohne Oberfläche, deshalb prüfbar.
  factory AvatarCrop.fromViewport({
    required List<double> transform,
    required double viewportSide,
    required int imageWidth,
    required int imageHeight,
  }) {
    // Die Matrix hat die Form [scale 0 0 0; 0 scale 0 0; 0 0 1 0; tx ty 0 1] (nur Verschieben und Zoomen).
    final scale = transform[0];
    final tx = transform[12];
    final ty = transform[13];
    final k = viewportSide / math.min(imageWidth, imageHeight);
    final childW = imageWidth * k;
    final childH = imageHeight * k;
    // Sichtbarer Bereich im Kind: (Betrachter - Verschiebung) / Zoom.
    final left = (0 - tx) / scale;
    final top = (0 - ty) / scale;
    final side = viewportSide / scale;
    return AvatarCrop(
      centerX: ((left + side / 2) / childW).clamp(0.0, 1.0),
      centerY: ((top + side / 2) / childH).clamp(0.0, 1.0),
      zoom: scale < 1 ? 1 : scale,
    );
  }

  /// Quadrat in Pixeln des ausgerichteten Bildes: (x, y, Seite). Liegt immer vollständig im Bild.
  ({int x, int y, int side}) rect(int width, int height) {
    final base = math.min(width, height);
    final side = math.max(1, (base / (zoom < 1 ? 1 : zoom)).round()).clamp(1, base);
    final x = (centerX.clamp(0.0, 1.0) * width - side / 2).round().clamp(0, width - side);
    final y = (centerY.clamp(0.0, 1.0) * height - side / 2).round().clamp(0, height - side);
    return (x: x, y: y, side: side);
  }
}

/// Vorschau des ausgerichteten Bildes für die Zuschnitt-Oberfläche: Rohpixel (RGBA), höchstens [maxPreviewSide] Pixel
/// an der langen Seite. Entsteht aus derselben Dart-Pipeline wie das spätere Foto, damit Ausschnitt und Ergebnis
/// zusammenpassen und kein nativer Decoder die Datei sieht.
class AvatarPreview {
  const AvatarPreview({required this.width, required this.height, required this.rgba});
  final int width;
  final int height;
  final Uint8List rgba;
}

/// Bildaufbereitung für Avatar-Fotos (#434, E-111): im speichersicheren Dart-Paket `image`.
///
/// Reihenfolge: Format und Größe prüfen, Maße aus dem Kopf lesen (vor jeder Dekodierung), nur das **erste** Bild
/// dekodieren, EXIF-Drehung anwenden, Ausschnitt, verkleinern (`average`), Transparenz auf Weiß, EXIF und ICC leeren,
/// als Baseline-JPEG (4:2:0) kodieren; reicht die Größe nicht, sinkt erst die Qualität, dann die Kantenlänge.
class AvatarPhotoProcessing {
  const AvatarPhotoProcessing._();

  /// Größe der gewählten Datei.
  static const int maxInputBytes = 15 * 1024 * 1024;

  /// Höchstens so viele Pixel je Seite und, im Ganzen, so viele Megapixel (Web: [maxPixelsWeb]).
  static const int maxSide = 4096;
  static const int maxPixels = 12 * 1000 * 1000;
  static const int maxPixelsWeb = 4 * 1000 * 1000;

  static const int maxPreviewSide = 768;

  /// Kantenlängen in dieser Reihenfolge, Qualität von [qualityStart] bis [qualityMin] in Schritten von 5.
  static const List<int> sizes = <int>[192, 160, 128];
  static const int qualityStart = 85;
  static const int qualityMin = 45;

  /// Dekodiert das erste Bild nach Prüfung von Format, Dateigröße und Maßen. Wirft [AvatarPhotoProcessingException].
  static img.Image _decode(Uint8List input, {required int pixelLimit}) {
    if (input.length > maxInputBytes) throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.tooLarge);
    final decoder = img.findDecoderForData(input);
    if (decoder is! img.JpegDecoder && decoder is! img.PngDecoder && decoder is! img.WebPDecoder) {
      throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.unsupportedFormat);
    }
    final img.Image? frame;
    try {
      final info = decoder!.startDecode(input);
      if (info == null) throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.notDecodable);
      if (info.width < 1 || info.height < 1) {
        throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.notDecodable);
      }
      if (info.width > maxSide || info.height > maxSide || info.width * info.height > pixelLimit) {
        throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.tooManyPixels);
      }
      // Nur das erste Bild: `decodeImage` würde bei Animationen alle Einzelbilder in den Speicher holen.
      frame = decoder.decodeFrame(0);
    } on AvatarPhotoProcessingException {
      rethrow;
    } catch (_) {
      // Jede Ausnahme des Decoders heißt: das Bild ist nicht lesbar (defekt, abgeschnitten).
      throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.notDecodable);
    }
    if (frame == null) throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.notDecodable);
    return img.bakeOrientation(frame);
  }

  /// Vorschau für die Zuschnitt-Oberfläche.
  static AvatarPreview preview(Uint8List input, {int pixelLimit = maxPixels}) {
    final oriented = _decode(input, pixelLimit: pixelLimit);
    final longSide = math.max(oriented.width, oriented.height);
    final small = longSide <= maxPreviewSide
        ? oriented
        : img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? maxPreviewSide : null,
            height: oriented.height > oriented.width ? maxPreviewSide : null,
            interpolation: img.Interpolation.average,
          );
    final rgba = small.convert(numChannels: 4, format: img.Format.uint8, alpha: 255);
    return AvatarPreview(
      width: rgba.width,
      height: rgba.height,
      rgba: rgba.getBytes(order: img.ChannelOrder.rgba),
    );
  }

  /// Das Foto als JPEG (≤ [AvatarPhotoLimits.maxBytes], höchstens 192 × 192, ohne EXIF und ICC).
  static Uint8List prepare(
    Uint8List input, {
    AvatarCrop crop = AvatarCrop.center,
    int pixelLimit = maxPixels,
    int maxBytes = AvatarPhotoLimits.maxBytes,
  }) {
    final oriented = _decode(input, pixelLimit: pixelLimit);
    final r = crop.rect(oriented.width, oriented.height);
    final cropped = img.copyCrop(oriented, x: r.x, y: r.y, width: r.side, height: r.side);
    for (final size in sizes) {
      var square = size == cropped.width
          ? cropped
          : img.copyResize(cropped, width: size, height: size, interpolation: img.Interpolation.average);
      if (square.hasAlpha) {
        // JPEG kennt keine Transparenz: auf Weiß setzen statt Schwarz.
        final bg = img.Image(width: square.width, height: square.height, numChannels: 4);
        img.fill(bg, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(bg, square);
        square = bg;
      }
      square = square.convert(numChannels: 3);
      square.exif = img.ExifData();
      square.iccProfile = null;
      for (var q = qualityStart; q >= qualityMin; q -= 5) {
        final out = Uint8List.fromList(img.encodeJpg(square, quality: q, chroma: img.JpegChroma.yuv420));
        if (out.length <= maxBytes) return out;
      }
    }
    throw const AvatarPhotoProcessingException(AvatarPhotoProcessingError.cannotShrink);
  }
}
