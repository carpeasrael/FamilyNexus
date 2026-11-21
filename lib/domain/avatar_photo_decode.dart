import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'avatar_photo.dart';
import 'jpeg_header.dart';

/// Rohpixel eines Fotos (RGBA, 4 Byte je Pixel).
class AvatarPixels {
  const AvatarPixels({required this.width, required this.height, required this.rgba});
  final int width;
  final int height;
  final Uint8List rgba;
}

/// Empfangsweg (#434, E-111): Fremde JPEG-Bytes erreichen keinen nativen Decoder. Nach den Kopfprüfungen wird im
/// speichersicheren Dart-Paket `image` dekodiert; die Oberfläche zeigt nur die Rohpixel.
class AvatarPhotoDecoder {
  const AvatarPhotoDecoder._();

  /// `null`, wenn die Bytes kein gültiges Foto sind (Größe, Kopf, Dekodierung oder abweichende Maße).
  static AvatarPixels? decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > AvatarPhotoLimits.maxBytes) return null;
    final head = JpegHeader.read(bytes, maxSide: AvatarPhotoLimits.maxSide);
    if (head == null) return null;
    try {
      final decoder = img.JpegDecoder();
      final info = decoder.startDecode(bytes);
      if (info == null || info.width != head.width || info.height != head.height || decoder.numFrames() != 1) {
        return null;
      }
      final frame = decoder.decodeFrame(0);
      if (frame == null || frame.width != head.width || frame.height != head.height) return null;
      final rgba = frame.convert(numChannels: 4, format: img.Format.uint8, alpha: 255);
      return AvatarPixels(
        width: rgba.width,
        height: rgba.height,
        rgba: rgba.getBytes(order: img.ChannelOrder.rgba),
      );
    } catch (_) {
      // Jede Ausnahme des Decoders heißt: ungültiges Foto (Rückfall auf Avatar oder Buchstabe).
      return null;
    }
  }
}
