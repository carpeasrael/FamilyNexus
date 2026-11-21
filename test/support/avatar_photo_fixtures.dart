import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Erzeugt ein gültiges Baseline-JPEG für die Avatar-Foto-Tests (#434).
Uint8List jpegBytes({int width = 64, int height = 48, int quality = 70, bool noisy = false}) {
  final image = img.Image(width: width, height: height);
  var seed = 7;
  for (final p in image) {
    if (noisy) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      p
        ..r = seed & 255
        ..g = (seed >> 8) & 255
        ..b = (seed >> 16) & 255;
    } else {
      p
        ..r = 200
        ..g = (p.x * 255 ~/ width)
        ..b = (p.y * 255 ~/ height);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

/// Stelle (Index des Markerbytes `FF`) des ersten Segments mit dem Marker [marker], oder -1.
int segmentAt(Uint8List b, int marker) {
  var i = 2;
  while (i + 3 < b.length && b[i] == 0xFF) {
    final m = b[i + 1];
    if (m == marker) return i;
    if (m == 0xDA) return -1;
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return -1;
}

/// Ein JPEG-Segment: Marker plus Länge plus Inhalt.
Uint8List segment(int marker, List<int> payload) {
  final len = payload.length + 2;
  return Uint8List.fromList(<int>[0xFF, marker, len >> 8, len & 255, ...payload]);
}
