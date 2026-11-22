import 'dart:convert';
import 'dart:typed_data';

import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_decode.dart';
import 'package:family_nexus/domain/avatar_photo_processing.dart';
import 'package:family_nexus/domain/jpeg_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/avatar_photo_fixtures.dart';

/// Zweifarbiges Bild: links rot, rechts blau.
img.Image _twoColors(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    if (p.x < w ~/ 2) {
      p
        ..r = 220
        ..g = 20
        ..b = 20;
    } else {
      p
        ..r = 20
        ..g = 20
        ..b = 220;
    }
  }
  return image;
}

AvatarPhotoProcessingError? _error(void Function() f) {
  try {
    f();
  } on AvatarPhotoProcessingException catch (e) {
    return e.error;
  }
  return null;
}

/// Namen der APPn-Segmente eines JPEG.
List<int> _appMarkers(Uint8List b) {
  final out = <int>[];
  var i = 2;
  while (i + 3 < b.length && b[i] == 0xFF) {
    final m = b[i + 1];
    if (m == 0xDA) break;
    if (m >= 0xE0 && m <= 0xEF) out.add(m - 0xE0);
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return out;
}

void main() {
  group('Formate und Größen', () {
    test('JPEG, PNG und WebP werden angenommen; GIF, BMP und Unbekanntes (z. B. HEIC) nicht', () {
      final base = img.Image(width: 40, height: 40);
      expect(_error(() => AvatarPhotoProcessing.prepare(Uint8List.fromList(img.encodeJpg(base)))), isNull);
      expect(_error(() => AvatarPhotoProcessing.prepare(Uint8List.fromList(img.encodePng(base)))), isNull);
      expect(
        _error(() => AvatarPhotoProcessing.prepare(Uint8List.fromList(img.encodeGif(base)))),
        AvatarPhotoProcessingError.unsupportedFormat,
      );
      expect(
        _error(() => AvatarPhotoProcessing.prepare(Uint8List.fromList(img.encodeBmp(base)))),
        AvatarPhotoProcessingError.unsupportedFormat,
      );
      // HEIC beginnt mit einer „ftyp“-Box, kein bekannter Decoder passt.
      final heic = Uint8List.fromList(<int>[
        0,
        0,
        0,
        24,
        0x66,
        0x74,
        0x79,
        0x70,
        0x68,
        0x65,
        0x69,
        0x63,
        ...List<int>.filled(32, 0),
      ]);
      expect(_error(() => AvatarPhotoProcessing.prepare(heic)), AvatarPhotoProcessingError.unsupportedFormat);
      expect(_error(() => AvatarPhotoProcessing.prepare(Uint8List(0))), AvatarPhotoProcessingError.unsupportedFormat);
    });

    test('die Grenze liegt bei genau 15 MiB: 15 MiB passieren die Größenprüfung, ein Byte mehr nicht', () {
      expect(AvatarPhotoProcessing.maxInputBytes, 15 * 1024 * 1024);
      final exact = Uint8List(AvatarPhotoProcessing.maxInputBytes);
      exact.setRange(0, 8, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      // Kein gültiges PNG: die Größenprüfung ist bestanden, erst der Decoder lehnt ab (nicht `tooLarge`).
      expect(_error(() => AvatarPhotoProcessing.prepare(exact)), isNot(AvatarPhotoProcessingError.tooLarge));
      expect(_error(() => AvatarPhotoProcessing.prepare(exact)), isNotNull);
      final over = Uint8List(AvatarPhotoProcessing.maxInputBytes + 1);
      over.setRange(0, 8, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(_error(() => AvatarPhotoProcessing.prepare(over)), AvatarPhotoProcessingError.tooLarge);
    });

    test('ein WebP wird angenommen (kleinstes gültiges verlustfreies WebP, 1 x 1)', () {
      final webp = base64Decode('UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==');
      expect(img.findDecoderForData(webp), isA<img.WebPDecoder>(), reason: 'Voraussetzung: das Bild ist ein WebP');
      final out = AvatarPhotoProcessing.prepare(webp);
      expect(JpegHeader.read(out, maxSide: 192), isNotNull);
    });

    test('eine Datei über 15 MiB wird vor jeder Dekodierung abgelehnt', () {
      final big = Uint8List(AvatarPhotoProcessing.maxInputBytes + 1);
      big.setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
      expect(_error(() => AvatarPhotoProcessing.prepare(big)), AvatarPhotoProcessingError.tooLarge);
      expect(_error(() => AvatarPhotoProcessing.preview(big)), AvatarPhotoProcessingError.tooLarge);
    });

    test('Maße über 4096 px je Seite werden abgelehnt (Breite und Höhe), vor dem Dekodieren des Bildes', () {
      for (final (w, h) in <(int, int)>[(5000, 10), (10, 5000), (4097, 4097)]) {
        final png = Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));
        expect(
          _error(() => AvatarPhotoProcessing.prepare(png)),
          AvatarPhotoProcessingError.tooManyPixels,
          reason: '$w x $h',
        );
        expect(
          _error(() => AvatarPhotoProcessing.preview(png)),
          AvatarPhotoProcessingError.tooManyPixels,
          reason: '$w x $h',
        );
      }
      final ok = Uint8List.fromList(img.encodePng(img.Image(width: 4096, height: 20)));
      expect(_error(() => AvatarPhotoProcessing.prepare(ok)), isNull, reason: '4096 ist erlaubt');
    });

    test('der Pixelgrenzwert gilt im Ganzen (Web 4 MP) und lässt sich je Plattform setzen', () {
      final small = Uint8List.fromList(img.encodeJpg(img.Image(width: 64, height: 48)));
      expect(
        _error(() => AvatarPhotoProcessing.prepare(small, pixelLimit: 3000)),
        AvatarPhotoProcessingError.tooManyPixels,
      );
      expect(
        _error(() => AvatarPhotoProcessing.prepare(small, pixelLimit: 64 * 48)),
        isNull,
        reason: 'genau am Grenzwert',
      );
      expect(AvatarPhotoProcessing.maxPixelsWeb, lessThan(AvatarPhotoProcessing.maxPixels));
      expect(AvatarPhotoProcessing.maxPixels, 12 * 1000 * 1000);
      expect(AvatarPhotoProcessing.maxSide, 4096);
    });

    test('Bildkopf gültig, Bilddaten abgeschnitten oder Müll: nicht lesbar, kein Absturz', () {
      final good = jpegBytes(width: 200, height: 150, noisy: true);
      final cut = Uint8List.fromList(good.sublist(0, good.length ~/ 3));
      final e = _error(() => AvatarPhotoProcessing.prepare(cut));
      // Entweder der Decoder lehnt ab oder er liefert ein Teilbild; nie ein anderer Fehler und nie ein Absturz.
      expect(e, anyOf(isNull, AvatarPhotoProcessingError.notDecodable));
      final garbage = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 4, 1, 2, 0xFF, 0xD9]);
      expect(
        _error(() => AvatarPhotoProcessing.prepare(garbage)),
        anyOf(AvatarPhotoProcessingError.notDecodable, AvatarPhotoProcessingError.unsupportedFormat),
      );
    });
  });

  group('Ergebnis', () {
    test('quadratisches Baseline-JPEG, höchstens 192 px und 16 KiB, vom Leser und vom Decoder angenommen', () {
      final out = AvatarPhotoProcessing.prepare(jpegBytes(width: 800, height: 600));
      expect(out.length, lessThanOrEqualTo(AvatarPhotoLimits.maxBytes));
      final head = JpegHeader.read(out, maxSide: AvatarPhotoLimits.maxSide)!;
      expect((head.width, head.height), (192, 192));
      expect(AvatarPhotoDecoder.decode(out), isNotNull);
    });

    test('ein kleines Bild wird nicht vergrößert über seine Größe hinaus, bleibt quadratisch', () {
      final out = AvatarPhotoProcessing.prepare(jpegBytes(width: 100, height: 60));
      final head = JpegHeader.read(out, maxSide: 192)!;
      expect(head.width, head.height);
      expect(head.width, lessThanOrEqualTo(192));
    });

    test('kein EXIF und kein ICC im Ergebnis (nur das JFIF-Segment), auch wenn die Quelle beides trägt', () {
      final source = img.Image(width: 300, height: 300);
      source.exif.imageIfd.make = 'Kamera';
      source.exif.gpsIfd[0x0002] = img.IfdValueAscii('GPS-Test');
      source.iccProfile = img.IccProfile(
        'x',
        img.IccProfileCompression.none,
        Uint8List.fromList(List<int>.filled(64, 3)),
      );
      final input = Uint8List.fromList(img.encodeJpg(source));
      expect(_appMarkers(input), containsAll(<int>[1]), reason: 'Voraussetzung: die Quelle trägt EXIF');
      final out = AvatarPhotoProcessing.prepare(input);
      final apps = _appMarkers(out);
      expect(apps, isNot(contains(1)), reason: 'APP1 (EXIF) fehlt');
      expect(apps, isNot(contains(2)), reason: 'APP2 (ICC) fehlt');
      expect(apps, isNot(contains(13)), reason: 'APP13 fehlt');
    });

    test('Transparenz wird auf Weiß gesetzt, nicht auf Schwarz', () {
      final rgba = img.Image(width: 64, height: 64, numChannels: 4);
      for (final p in rgba) {
        p
          ..r = 0
          ..g = 0
          ..b = 0
          ..a = 0;
      }
      final out = AvatarPhotoProcessing.prepare(Uint8List.fromList(img.encodePng(rgba)));
      final px = AvatarPhotoDecoder.decode(out)!;
      expect(<int>[px.rgba[0], px.rgba[1], px.rgba[2]].every((c) => c >= 240), isTrue, reason: 'weiß, nicht schwarz');
    });

    test('verrauschtes Bild: die Rückfallkette senkt Qualität und Kantenlänge, bis es unter 16 KiB passt', () {
      final out = AvatarPhotoProcessing.prepare(jpegBytes(width: 1200, height: 1200, quality: 98, noisy: true));
      expect(out.length, lessThanOrEqualTo(AvatarPhotoLimits.maxBytes));
      final head = JpegHeader.read(out, maxSide: 192)!;
      expect(<int>[192, 160, 128], contains(head.width));
      expect(head.width, head.height);
    });

    test('das JPEG ist 4:2:0 (zweifaches Abtasten der Helligkeit), nicht 4:4:4', () {
      final out = AvatarPhotoProcessing.prepare(jpegBytes(width: 400, height: 400));
      final sof = segmentAt(out, 0xC0);
      expect(sof, greaterThan(0));
      expect(out[sof + 9], 3, reason: 'drei Komponenten');
      expect(out[sof + 11], 0x22, reason: 'Y-Abtastfaktoren 2 x 2 (4:2:0); 4:4:4 wäre 0x11');
    });

    test('Rückfallkette: Qualität und Kantenlänge sinken Schritt für Schritt, jede Stufe kommt vor', () {
      final noisy = jpegBytes(width: 600, height: 600, quality: 98, noisy: true);
      final baseline = AvatarPhotoProcessing.prepare(noisy, maxBytes: 1 << 30);
      expect(JpegHeader.read(baseline, maxSide: 192)!.width, 192, reason: 'ohne Druck: höchste Stufe');
      final widths = <int>{};
      var lowerQuality192 = false;
      var last = 192;
      for (var limit = 20000; limit >= 1500; limit -= 250) {
        Uint8List out;
        try {
          out = AvatarPhotoProcessing.prepare(noisy, maxBytes: limit);
        } on AvatarPhotoProcessingException catch (e) {
          expect(e.error, AvatarPhotoProcessingError.cannotShrink);
          break;
        }
        final w = JpegHeader.read(out, maxSide: 192)!.width;
        expect(out.length, lessThanOrEqualTo(limit));
        expect(w, lessThanOrEqualTo(last), reason: 'je kleiner das Limit, desto kleiner oder gleich das Bild');
        last = w;
        widths.add(w);
        if (w == 192 && out.length < baseline.length) lowerQuality192 = true;
      }
      expect(widths, containsAll(<int>[192, 160, 128]), reason: 'alle drei Kantenlängen kommen vor');
      expect(lowerQuality192, isTrue, reason: 'bei 192 px sinkt zuerst die Qualität');
    });

    test('Vorschau: Verkleinern mit Mittelwert, ein feines Schachbrett wird grau', () {
      final board = img.Image(width: 1536, height: 1536);
      for (final p in board) {
        final v = (p.x + p.y).isEven
            ? 0
            : 255; // Zellen von 1 Pixel: jeder 2 x 2-Block der Vorschau enthält beide Farben
        p
          ..r = v
          ..g = v
          ..b = v;
      }
      final pv = AvatarPhotoProcessing.preview(Uint8List.fromList(img.encodePng(board)), pixelLimit: 3000000);
      expect((pv.width, pv.height), (768, 768));
      var extreme = 0;
      for (var i = 0; i < pv.rgba.length; i += 4) {
        if (pv.rgba[i] < 40 || pv.rgba[i] > 215) extreme++;
      }
      expect(extreme / (pv.width * pv.height), lessThan(0.05));
    });

    test('cannotShrink: passt es auch bei der kleinsten Größe und Qualität nicht, gibt es einen Fehler statt eines zu großen Fotos', () {
      final noisy = jpegBytes(width: 400, height: 400, quality: 95, noisy: true);
      expect(
        _error(() => AvatarPhotoProcessing.prepare(noisy, maxBytes: 300)),
        AvatarPhotoProcessingError.cannotShrink,
      );
      // Gegenprobe: mit dem echten Limit gelingt dasselbe Bild.
      expect(_error(() => AvatarPhotoProcessing.prepare(noisy)), isNull);
    });

    test(
      'Verkleinern mit Mittelwert (average), nicht nearest: ein feines Schachbrett wird grau, nicht schwarzweiß',
      () {
        final board = img.Image(width: 768, height: 768);
        for (final p in board) {
          final v = ((p.x ~/ 2) + (p.y ~/ 2)).isEven ? 0 : 255;
          p
            ..r = v
            ..g = v
            ..b = v;
        }
        final out = AvatarPhotoProcessing.prepare(Uint8List.fromList(img.encodePng(board)));
        final px = AvatarPhotoDecoder.decode(out)!;
        var extreme = 0;
        for (var i = 0; i < px.rgba.length; i += 4) {
          if (px.rgba[i] < 40 || px.rgba[i] > 215) extreme++;
        }
        expect(
          extreme / (px.width * px.height),
          lessThan(0.05),
          reason: 'nearest ließe fast nur Schwarz und Weiß übrig',
        );
        expect(px.rgba[(px.height ~/ 2 * px.width + px.width ~/ 2) * 4], inInclusiveRange(90, 165));
      },
    );

    test('Qualitätsschleife: ein einfaches Bild bleibt bei 192 px (höchste Stufe genügt)', () {
      final out = AvatarPhotoProcessing.prepare(jpegBytes(width: 600, height: 600));
      expect(JpegHeader.read(out, maxSide: 192)!.width, 192);
    });
  });

  group('Ausrichtung und Ausschnitt', () {
    test('die EXIF-Drehung wird angewandt: Hoch- statt Querformat in der Vorschau', () {
      final source = _twoColors(200, 100);
      source.exif.imageIfd.orientation = 6; // 90° im Uhrzeigersinn
      final preview = AvatarPhotoProcessing.preview(Uint8List.fromList(img.encodeJpg(source)));
      expect((preview.width, preview.height), (100, 200));
    });

    test('Vorschau: höchstens 768 px an der langen Seite, RGBA, Seitenverhältnis bleibt', () {
      final p = AvatarPhotoProcessing.preview(Uint8List.fromList(img.encodeJpg(_twoColors(1600, 800))));
      expect((p.width, p.height), (768, 384));
      expect(p.rgba.length, 768 * 384 * 4);
      final q = AvatarPhotoProcessing.preview(Uint8List.fromList(img.encodeJpg(_twoColors(300, 500))));
      expect((q.width, q.height), (300, 500), reason: 'kleine Bilder bleiben unverkleinert');
    });

    test('der Ausschnitt bestimmt den Inhalt: links rot, rechts blau', () {
      final input = Uint8List.fromList(img.encodePng(_twoColors(400, 200)));
      final left = AvatarPhotoDecoder.decode(
        AvatarPhotoProcessing.prepare(input, crop: const AvatarCrop(centerX: 0.25, zoom: 2)),
      )!;
      final right = AvatarPhotoDecoder.decode(
        AvatarPhotoProcessing.prepare(input, crop: const AvatarCrop(centerX: 0.75, zoom: 2)),
      )!;
      int mid(AvatarPixels p, int channel) => p.rgba[((p.height ~/ 2) * p.width + p.width ~/ 2) * 4 + channel];
      expect(mid(left, 0), greaterThan(150), reason: 'rot');
      expect(mid(left, 2), lessThan(100));
      expect(mid(right, 2), greaterThan(150), reason: 'blau');
      expect(mid(right, 0), lessThan(100));
    });
  });

  group('AvatarCrop.rect', () {
    test('Standard: die größte quadratische Mitte', () {
      expect(AvatarCrop.center.rect(400, 200), (x: 100, y: 0, side: 200));
      expect(AvatarCrop.center.rect(200, 400), (x: 0, y: 100, side: 200));
      expect(AvatarCrop.center.rect(300, 300), (x: 0, y: 0, side: 300));
    });

    test('Zoom verkleinert den Ausschnitt, die Mitte folgt dem Anteil', () {
      expect(const AvatarCrop(zoom: 2).rect(400, 200), (x: 150, y: 50, side: 100));
      expect(const AvatarCrop(centerX: 0.25, zoom: 2).rect(400, 200), (x: 50, y: 50, side: 100));
    });

    test('der Ausschnitt liegt immer im Bild, auch bei Werten außerhalb', () {
      for (final c in const <AvatarCrop>[
        AvatarCrop(centerX: -3, centerY: 9, zoom: 4),
        AvatarCrop(centerX: 5, centerY: -5, zoom: 1),
        AvatarCrop(zoom: 0.2),
        AvatarCrop(zoom: 1000),
      ]) {
        final r = c.rect(640, 480);
        expect(r.side, inInclusiveRange(1, 480));
        expect(r.x, inInclusiveRange(0, 640 - r.side));
        expect(r.y, inInclusiveRange(0, 480 - r.side));
      }
    });
  });

  group('AvatarCrop.fromViewport (Rechnung zum Betrachter)', () {
    List<double> matrix({double scale = 1, double tx = 0, double ty = 0}) => <double>[
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      tx,
      ty,
      0,
      1,
    ];

    test('keine Verschiebung, kein Zoom: die Mitte des Querformats', () {
      final c = AvatarCrop.fromViewport(transform: matrix(), viewportSide: 100, imageWidth: 400, imageHeight: 200);
      expect(
        (c.centerX, c.centerY, c.zoom),
        (0.25, 0.5, 1.0),
        reason: 'links im Kind, Betrachter zeigt das linke Quadrat',
      );
    });

    test('nach links verschoben zeigt der Betrachter den rechten Teil', () {
      final c = AvatarCrop.fromViewport(
        transform: matrix(tx: -100),
        viewportSide: 100,
        imageWidth: 400,
        imageHeight: 200,
      );
      expect(c.centerX, 0.75);
    });

    test('Zoom 2 und Verschiebung: Mitte und Zoom stimmen mit dem Quadrat im Bild überein', () {
      // Bild 400 x 200, Betrachter 100: Kind 200 x 100. Zoom 2, Betrachter zeigt Kindbereich ab (50, 25) mit Seite 50.
      final c = AvatarCrop.fromViewport(
        transform: matrix(scale: 2, tx: -100, ty: -50),
        viewportSide: 100,
        imageWidth: 400,
        imageHeight: 200,
      );
      expect(c.zoom, 2);
      expect(c.centerX, (50 + 25) / 200);
      expect(c.centerY, (25 + 25) / 100);
      final r = c.rect(400, 200);
      expect(r.side, 100);
    });

    test('Zoom unter 1 wird auf 1 begrenzt', () {
      final c = AvatarCrop.fromViewport(
        transform: matrix(scale: 0.5),
        viewportSide: 100,
        imageWidth: 100,
        imageHeight: 100,
      );
      expect(c.zoom, 1);
    });
  });
}
