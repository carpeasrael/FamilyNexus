import 'dart:convert';
import 'dart:typed_data';

import 'package:family_nexus/domain/avatar_photo_processing.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/jpeg_header.dart';
import 'package:family_nexus/domain/receipt_photo_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/avatar_photo_fixtures.dart';

ReceiptPhotoProcessingError? _error(void Function() f) {
  try {
    f();
  } on ReceiptPhotoProcessingException catch (e) {
    return e.error;
  }
  return null;
}

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

/// Einfarbiger Verlauf als JPEG (klein im Dateiumfang, schnell zu erzeugen).
Uint8List _gradient(int w, int h) => jpegBytes(width: w, height: h, quality: 80);

/// Maße des Ergebnisses laut JPEG-Kopf.
({int width, int height}) _dims(Uint8List b) {
  final h = JpegHeader.read(b, maxSide: 4096)!;
  return (width: h.width, height: h.height);
}

void main() {
  group('Basisgröße (harte Grenzen)', () {
    test('lange Kante ≤ 3000, höchstens 4 MP, nie vergrößert, Seitenverhältnis bis ±1 px', () {
      for (final (w, h) in <(int, int)>[(1500, 2000), (1000, 4000), (4096, 800), (3500, 3000), (4096, 4096), (100, 60), (1, 4096), (4096, 1)]) {
        final b = ReceiptPhotoProcessing.baseSize(w, h);
        expect(b.width, lessThanOrEqualTo(w), reason: '$w x $h nie vergrößert');
        expect(b.height, lessThanOrEqualTo(h));
        expect(b.width > b.height ? b.width : b.height, lessThanOrEqualTo(ReceiptPhotoProcessing.maxLongSide), reason: '$w x $h lange Kante');
        expect(b.width * b.height, lessThanOrEqualTo(ReceiptPhotoProcessing.maxOutputPixels), reason: '$w x $h Fläche');
        expect(b.width, greaterThanOrEqualTo(1));
        expect(b.height, greaterThanOrEqualTo(1));
        if (w >= 100 && h >= 100) {
          // Bis auf Rundung (floor): die kürzere Kante weicht höchstens um 1 px vom exakten Verhältnis ab.
          final errW = (b.width - b.height * w / h).abs();
          final errH = (b.height - b.width * h / w).abs();
          expect(errW < 1.5 || errH < 1.5, isTrue, reason: '$w x $h Seitenverhältnis');
        }
      }
    });

    test('Beispiele: 1500×2000 bleibt (kurze Kante ≥ 1000); 1000×4000 → 750×3000 (3000 hat Vorrang vor 1000); 3500×3000 → unter 4 MP', () {
      expect(ReceiptPhotoProcessing.baseSize(1500, 2000), (width: 1500, height: 2000));
      expect(ReceiptPhotoProcessing.baseSize(1000, 4000), (width: 750, height: 3000));
      expect(ReceiptPhotoProcessing.baseSize(4000, 1000), (width: 3000, height: 750));
      final b = ReceiptPhotoProcessing.baseSize(3500, 3000);
      expect(b.width * b.height, lessThanOrEqualTo(4000000));
      expect(b.width * b.height, greaterThan(3900000), reason: 'nutzt die 4 MP aus, nicht deutlich weniger');
      expect(ReceiptPhotoProcessing.baseSize(100, 60), (width: 100, height: 60));
    });

    test('Grenzen der Konstanten: 3000, 4 MP, Ziel 600 KiB, hart 1 MiB, Qualität 85 bis 60', () {
      expect(ReceiptPhotoProcessing.maxLongSide, 3000);
      expect(ReceiptPhotoProcessing.maxOutputPixels, 4000000);
      expect(ReceiptPhotoProcessing.minShortSide, 1000);
      expect(ReceiptPhotoProcessing.targetBytes, 600 * 1024);
      expect(CashBookLimits.maxReceiptBytes, 1024 * 1024);
      expect(ReceiptPhotoProcessing.qualityStart, 85);
      expect(ReceiptPhotoProcessing.qualityMin, 60);
      expect(ReceiptPhotoProcessing.scaleSteps, <double>[1.0, 0.85, 0.7, 0.55, 0.4]);
    });
  });

  group('Eingabe: Formate und Größen (wie bei den Avatar-Fotos, gemeinsame Dekodierung)', () {
    test('JPEG, PNG und WebP werden angenommen; GIF, BMP, HEIC und leer nicht', () {
      final base = img.Image(width: 40, height: 40);
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodeJpg(base)))), isNull);
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodePng(base)))), isNull);
      expect(_error(() => ReceiptPhotoProcessing.prepare(base64Decode('UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=='))), isNull);
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodeGif(base)))), ReceiptPhotoProcessingError.unsupportedFormat);
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodeBmp(base)))), ReceiptPhotoProcessingError.unsupportedFormat);
      final heic = Uint8List.fromList(<int>[0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, ...List<int>.filled(32, 0)]);
      expect(_error(() => ReceiptPhotoProcessing.prepare(heic)), ReceiptPhotoProcessingError.unsupportedFormat);
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List(0))), ReceiptPhotoProcessingError.unsupportedFormat);
    });

    test('15 MiB: genau erlaubt (erst der Decoder lehnt ab), ein Byte mehr: tooLarge vor jeder Dekodierung', () {
      expect(ReceiptPhotoProcessing.maxInputBytes, 15 * 1024 * 1024);
      final exact = Uint8List(ReceiptPhotoProcessing.maxInputBytes)..setRange(0, 8, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(_error(() => ReceiptPhotoProcessing.prepare(exact)), isNot(ReceiptPhotoProcessingError.tooLarge));
      expect(_error(() => ReceiptPhotoProcessing.prepare(exact)), isNotNull);
      final over = Uint8List(ReceiptPhotoProcessing.maxInputBytes + 1)..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);
      expect(_error(() => ReceiptPhotoProcessing.prepare(over)), ReceiptPhotoProcessingError.tooLarge);
    });

    test('Maße über 4096 je Seite und die Pixelgrenze (auch Web 4 MP, genau am Grenzwert) werden vor dem Dekodieren abgelehnt', () {
      for (final (w, h) in <(int, int)>[(5000, 10), (10, 5000), (4097, 4097)]) {
        final png = Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));
        expect(_error(() => ReceiptPhotoProcessing.prepare(png)), ReceiptPhotoProcessingError.tooManyPixels, reason: '$w x $h');
      }
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodePng(img.Image(width: 4096, height: 20))))), isNull);
      final small = Uint8List.fromList(img.encodeJpg(img.Image(width: 64, height: 48)));
      expect(_error(() => ReceiptPhotoProcessing.prepare(small, pixelLimit: 3000)), ReceiptPhotoProcessingError.tooManyPixels);
      expect(_error(() => ReceiptPhotoProcessing.prepare(small, pixelLimit: 64 * 48)), isNull);
      expect(ReceiptPhotoProcessing.maxPixelsWeb, 4000000);
      expect(ReceiptPhotoProcessing.maxPixels, 12000000);
      expect(ReceiptPhotoProcessing.maxSide, 4096);
    });

    test('abgeschnittene oder defekte Daten: nicht lesbar, kein Absturz', () {
      final good = jpegBytes(width: 200, height: 150, noisy: true);
      expect(_error(() => ReceiptPhotoProcessing.prepare(Uint8List.fromList(good.sublist(0, good.length ~/ 3)))), anyOf(isNull, ReceiptPhotoProcessingError.notDecodable));
      final garbage = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 4, 1, 2, 0xFF, 0xD9]);
      expect(_error(() => ReceiptPhotoProcessing.prepare(garbage)), anyOf(ReceiptPhotoProcessingError.notDecodable, ReceiptPhotoProcessingError.unsupportedFormat));
    });

    test('Fehler der gemeinsamen Dekodierung bleiben für beide Aufrufer gleich (tooManyPixels wird nie zu notDecodable)', () {
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 5000, height: 10)));
      expect(_error(() => ReceiptPhotoProcessing.prepare(png)), ReceiptPhotoProcessingError.tooManyPixels);
      try {
        AvatarPhotoProcessing.prepare(png);
        fail('erwartet');
      } on AvatarPhotoProcessingException catch (e) {
        expect(e.error, AvatarPhotoProcessingError.tooManyPixels);
      }
    });
  });

  group('Ergebnis', () {
    test('1500×2000: Maße bleiben (kurze Kante ≥ 1000), Seitenverhältnis, Größe ≤ 600 KiB, Maße stimmen mit dem JPEG-Kopf', () {
      final r = ReceiptPhotoProcessing.prepare(_gradient(1500, 2000));
      expect((r.width, r.height), (1500, 2000));
      expect(_dims(r.bytes), (width: 1500, height: 2000));
      expect(r.bytes.length, lessThanOrEqualTo(ReceiptPhotoProcessing.targetBytes));
    });

    test('langer Bon 1000×4000: lange Kante genau 3000, Seitenverhältnis bleibt (750×3000)', () {
      final r = ReceiptPhotoProcessing.prepare(_gradient(1000, 4000));
      expect((r.width, r.height), (750, 3000));
    });

    test('über 4 MP: das Ergebnis hat höchstens 4 MP, das Seitenverhältnis bleibt', () {
      final r = ReceiptPhotoProcessing.prepare(_gradient(2400, 2000));
      expect(r.width * r.height, lessThanOrEqualTo(4000000));
      expect((r.width / r.height - 1.2).abs(), lessThan(0.01));
    });

    test('ein kleines Bild wird nicht vergrößert', () {
      final r = ReceiptPhotoProcessing.prepare(_gradient(100, 60));
      expect((r.width, r.height), (100, 60));
    });

    test('kein EXIF, ICC oder APP13 im Ergebnis (GPS, Kameramodell), auch wenn die Quelle sie trägt', () {
      final source = img.Image(width: 300, height: 300);
      source.exif.imageIfd.make = 'Kamera';
      source.exif.gpsIfd[0x0002] = img.IfdValueAscii('GPS-Test');
      source.iccProfile = img.IccProfile('x', img.IccProfileCompression.none, Uint8List.fromList(List<int>.filled(64, 3)));
      final input = Uint8List.fromList(img.encodeJpg(source));
      expect(_appMarkers(input), contains(1), reason: 'Voraussetzung: die Quelle trägt EXIF');
      final apps = _appMarkers(ReceiptPhotoProcessing.prepare(input).bytes);
      expect(apps, isNot(contains(1)));
      expect(apps, isNot(contains(2)));
      expect(apps, isNot(contains(13)));
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
      final out = ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodePng(rgba))).bytes;
      final px = img.decodeJpg(out)!.getPixel(32, 32);
      expect(<num>[px.r, px.g, px.b].every((c) => c >= 240), isTrue, reason: 'weiß');
    });

    test('das JPEG ist 4:2:0', () {
      final out = ReceiptPhotoProcessing.prepare(_gradient(400, 400)).bytes;
      final sof = segmentAt(out, 0xC0);
      expect(sof, greaterThan(0));
      expect(out[sof + 9], 3);
      expect(out[sof + 11], 0x22);
    });

    test('die EXIF-Drehung wird angewandt: aus Querformat wird Hochformat', () {
      final source = img.Image(width: 300, height: 100);
      source.exif.imageIfd.orientation = 6;
      final r = ReceiptPhotoProcessing.prepare(Uint8List.fromList(img.encodeJpg(source)));
      expect((r.width, r.height), (100, 300));
    });

    test('nur das erste Bild einer Animation wird verwendet', () {
      final first = img.Image(width: 30, height: 20, frameType: img.FrameType.animation);
      img.fill(first, color: img.ColorRgb8(255, 0, 0));
      final second = img.Image(width: 50, height: 40);
      img.fill(second, color: img.ColorRgb8(0, 0, 255));
      first.addFrame(second);
      final png = Uint8List.fromList(img.encodePng(first));
      final r = ReceiptPhotoProcessing.prepare(png);
      expect((r.width, r.height), (30, 20));
      final px = img.decodeJpg(r.bytes)!.getPixel(5, 5);
      expect(px.r, greaterThan(200));
      expect(px.b, lessThan(60));
    });
  });

  group('Rückfallkette und hartes Limit (mit gesenkten Grenzen, kleine Bilder)', () {
    final noisy = jpegBytes(width: 400, height: 300, quality: 98, noisy: true);

    int width(Uint8List b) => _dims(b).width;

    test('erst sinkt die Qualität, dann die Größe: bei Druck bleibt zunächst das Maß der Basisgröße', () {
      final top = ReceiptPhotoProcessing.prepare(noisy, targetBytes: 1 << 30);
      expect(width(top.bytes), 400, reason: 'ohne Druck: höchste Stufe, höchste Qualität');
      var lowerQualityAtFullSize = false;
      for (var limit = top.bytes.length - 1; limit > top.bytes.length ~/ 2; limit -= 2000) {
        final r = ReceiptPhotoProcessing.prepare(noisy, targetBytes: limit);
        if (width(r.bytes) == 400) {
          expect(r.bytes.length, lessThanOrEqualTo(limit));
          lowerQualityAtFullSize = true;
        }
      }
      expect(lowerQualityAtFullSize, isTrue, reason: 'bei voller Größe sinkt zuerst die Qualität');
    });

    test('alle Stufen kommen vor und die Größe sinkt mit dem Limit monoton', () {
      final widths = <int>[];
      var last = 400;
      for (var limit = 60000; limit >= 800; limit -= 1500) {
        final ReceiptPhoto r;
        try {
          r = ReceiptPhotoProcessing.prepare(noisy, targetBytes: limit);
        } on ReceiptPhotoProcessingException {
          break;
        }
        final w = width(r.bytes);
        expect(w, lessThanOrEqualTo(last));
        last = w;
        if (r.bytes.length <= limit) widths.add(w);
      }
      final expected = <int>[for (final f in ReceiptPhotoProcessing.scaleSteps) (400 * f).floor()];
      expect(widths.toSet(), containsAll(expected.take(4)), reason: 'die ersten vier Stufen kommen vor');
    });

    test('Ziel nie erreicht: das kleinste Ergebnis (kleinste Stufe, Qualität 60) gilt, wenn es unter dem harten Limit liegt', () {
      final r = ReceiptPhotoProcessing.prepare(noisy, targetBytes: 1);
      expect((r.width, r.height), ((400 * 0.4).floor(), (300 * 0.4).floor()));
      expect(r.bytes.length, lessThanOrEqualTo(CashBookLimits.maxReceiptBytes));
    });

    test('hartes Limit: genau das kleinste Ergebnis geht noch, ein Byte weniger ist cannotShrink', () {
      final smallest = ReceiptPhotoProcessing.prepare(noisy, targetBytes: 1).bytes.length;
      expect(_error(() => ReceiptPhotoProcessing.prepare(noisy, targetBytes: 1, hardLimitBytes: smallest)), isNull);
      expect(_error(() => ReceiptPhotoProcessing.prepare(noisy, targetBytes: 1, hardLimitBytes: smallest - 1)), ReceiptPhotoProcessingError.cannotShrink);
    });

    test('Ziel erreicht, aber über dem harten Limit ist unmöglich (Ziel gilt zuerst, hartes Limit nur für den Rückfall)', () {
      final r = ReceiptPhotoProcessing.prepare(noisy, targetBytes: 1 << 30, hardLimitBytes: 1);
      expect(width(r.bytes), 400, reason: 'das Ziel ist erreicht, das harte Limit wird nur im Rückfall angewandt');
    });

    test('echte Standardwerte mit einem verrauschten 4-MP-Bild: die Kette senkt die Größe bis unter 600 KiB (Stufe 0.55: 1100×1100)', () {
      final big = Uint8List.fromList(img.encodeJpg(_noise(2000, 2000), quality: 95));
      final r = ReceiptPhotoProcessing.prepare(big);
      expect((r.width, r.height), (1100, 1100));
      expect(r.bytes.length, lessThanOrEqualTo(ReceiptPhotoProcessing.targetBytes));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

img.Image _noise(int w, int h) {
  final image = img.Image(width: w, height: h);
  var seed = 11;
  for (final p in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    p
      ..r = seed & 255
      ..g = (seed >> 8) & 255
      ..b = (seed >> 16) & 255;
  }
  return image;
}
