import 'dart:typed_data';

import 'package:family_nexus/domain/receipt_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// #311, E-113 (Teil 4): Rohpixel eines geprüften Bon-Fotos.
void main() {
  Uint8List jpeg(int w, int h) {
    final image = img.Image(width: w, height: h);
    for (final p in image) {
      p
        ..r = (p.x * 3) & 255
        ..g = (p.y * 5) & 255
        ..b = 90;
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 70));
  }

  test('ein gültiges JPEG ergibt Rohpixel (RGBA) in den Maßen des Bildes', () {
    final p = ReceiptPreview.decode(jpeg(120, 80))!;
    expect((p.width, p.height), (120, 80));
    expect(p.rgba.length, 120 * 80 * 4);
  });

  test('Müll, leer und fremde Formate: null, kein Absturz', () {
    expect(ReceiptPreview.decode(Uint8List(0)), isNull);
    expect(ReceiptPreview.decode(Uint8List.fromList(<int>[1, 2, 3, 4, 5])), isNull);
    expect(ReceiptPreview.decode(Uint8List.fromList(img.encodeGif(img.Image(width: 8, height: 8)))), isNull);
    final cut = jpeg(200, 200);
    expect(ReceiptPreview.decode(Uint8List.fromList(cut.sublist(0, 30))), isNull);
  });

  test('über 3000 px an einer Kante oder über 4 MP: null (die Aufbereitung erzeugt nie mehr)', () {
    expect(ReceiptPreview.decode(Uint8List.fromList(img.encodePng(img.Image(width: 3001, height: 10)))), isNull);
    expect(ReceiptPreview.decode(Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 3001)))), isNull);
    expect(ReceiptPreview.decode(Uint8List.fromList(img.encodePng(img.Image(width: 2100, height: 2000)))), isNull, reason: '4,2 MP');
    expect(ReceiptPreview.decode(Uint8List.fromList(img.encodePng(img.Image(width: 3000, height: 8)))), isNotNull, reason: 'genau 3000 geht');
  });

  test('Farbreihenfolge RGBA und volle Deckkraft (ein rotes Bild bleibt rot und sichtbar)', () {
    final red = img.Image(width: 8, height: 4);
    img.fill(red, color: img.ColorRgb8(255, 0, 0));
    final p = ReceiptPreview.decode(Uint8List.fromList(img.encodeJpg(red, quality: 95)))!;
    expect(p.rgba[0], greaterThan(200), reason: 'Rot');
    expect(p.rgba[1], lessThan(60));
    expect(p.rgba[2], lessThan(60), reason: 'Blau, nicht Rot (keine BGRA-Reihenfolge)');
    expect(p.rgba[3], 255, reason: 'volle Deckkraft');
  });

  test('ein gültiges Bild zwischen 1 und 2 MiB: null (Grenze der Eingabe, nicht erst ein anderes Limit)', () {
    Uint8List? big;
    for (var side = 700; side <= 1400 && big == null; side += 50) {
      final image = img.Image(width: side, height: side);
      var seed = 3;
      for (final px in image) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        px
          ..r = seed & 255
          ..g = (seed >> 8) & 255
          ..b = (seed >> 16) & 255;
      }
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
      if (bytes.length > 1024 * 1024 && bytes.length < 2 * 1024 * 1024) big = bytes;
    }
    expect(big, isNotNull, reason: 'Voraussetzung: ein Testbild zwischen 1 und 2 MiB');
    expect(ReceiptPreview.decode(big!), isNull);
  });

  test('über 1 MiB: null', () {
    final big = Uint8List(1024 * 1024 + 1)..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
    expect(ReceiptPreview.decode(big), isNull);
  });
}
