import 'dart:typed_data';

/// Liest die Maße eines JPEG-Bildes aus dem Kopf, ohne es zu dekodieren (#434, E-111).
///
/// Streng: nur Baseline (SOF0), Marker für Marker, jedes Segment wird über seine Längenangabe übersprungen
/// (ein Vorschaubild in APP1/EXIF mit eigenem SOF wird nie als Bildkopf gelesen). Alles Unklare ergibt `null`.
class JpegHeader {
  const JpegHeader._();

  /// Obergrenze für Marker, damit ein präpariertes Bild die Schleife nicht unnötig lange laufen lässt.
  static const int maxSegments = 64;

  /// Obergrenze für Füllbytes `FF` hintereinander.
  static const int maxFill = 64;

  static const int _sof0 = 0xC0;
  static const int _sos = 0xDA;
  static const int _eoi = 0xD9;

  /// Maße (Breite, Höhe) oder `null`, wenn der Kopf ungültig ist oder ein Maß über [maxSide] liegt.
  static ({int width, int height})? read(Uint8List b, {required int maxSide}) {
    final n = b.length;
    if (n < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
    var i = 2;
    ({int width, int height})? size;
    for (var segments = 0; segments < maxSegments; segments++) {
      if (i >= n || b[i] != 0xFF) return null;
      var fill = 0;
      while (i < n && b[i] == 0xFF) {
        fill++;
        i++;
      }
      if (fill - 1 > maxFill || i >= n) return null;
      final m = b[i++];
      if (m == 0x00 || m == 0xD8) return null; // gestopftes Byte oder zweites SOI
      if (m == _eoi) return null; // Ende vor SOF oder vor SOS
      if (m == 0x01 || (m >= 0xD0 && m <= 0xD7)) continue; // Marker ohne Länge
      if (i + 2 > n) return null;
      final len = (b[i] << 8) | b[i + 1];
      if (len < 2 || i + len > n) return null;
      if (m == _sos) return size; // nach SOS wird nicht mehr gesucht; ohne SOF vorher ungültig
      final isSof = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
      if (isSof) {
        if (m != _sof0 || size != null) return null; // nur das erste SOF0 (Baseline) zählt
        size = _parseSof0(b, i, len, maxSide);
        if (size == null) return null;
      }
      i += len;
    }
    return null;
  }

  static ({int width, int height})? _parseSof0(Uint8List b, int i, int len, int maxSide) {
    if (len < 8) return null;
    if (b[i + 2] != 8) return null; // Präzision 8 Bit
    final height = (b[i + 3] << 8) | b[i + 4];
    final width = (b[i + 5] << 8) | b[i + 6];
    final comps = b[i + 7];
    if (comps != 1 && comps != 3) return null;
    if (len != 8 + 3 * comps) return null;
    if (width < 1 || height < 1 || width > maxSide || height > maxSide) return null;
    final ids = <int>{};
    for (var k = 0; k < comps; k++) {
      final id = b[i + 8 + 3 * k];
      final samp = b[i + 9 + 3 * k];
      final h = samp >> 4;
      final v = samp & 15;
      if (h < 1 || h > 4 || v < 1 || v > 4) return null;
      if (!ids.add(id)) return null;
    }
    return (width: width, height: height);
  }
}
