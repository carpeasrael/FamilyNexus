import 'dart:typed_data';

import 'package:family_nexus/domain/jpeg_header.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/avatar_photo_fixtures.dart';

({int width, int height})? _read(Uint8List b, {int maxSide = 192}) => JpegHeader.read(b, maxSide: maxSide);

Uint8List _patched(Uint8List b, int offsetInSof, int value) {
  final out = Uint8List.fromList(b);
  out[segmentAt(b, 0xC0) + offsetInSof] = value;
  return out;
}

void main() {
  final good = jpegBytes(width: 64, height: 48);

  group('gültige Köpfe', () {
    test('liefert Breite und Höhe', () {
      expect(_read(good), (width: 64, height: 48));
    });

    test('Randmaße 192 x 192 sind erlaubt, 193 nicht', () {
      expect(_read(jpegBytes(width: 192, height: 192)), (width: 192, height: 192));
      expect(_read(jpegBytes(width: 193, height: 40)), isNull);
      expect(_read(jpegBytes(width: 40, height: 193)), isNull);
    });

    test('Füllbytes FF vor einem Marker sind erlaubt (bis 64), mehr nicht', () {
      Uint8List withFill(int extra) =>
          Uint8List.fromList(<int>[0xFF, 0xD8, ...List<int>.filled(extra, 0xFF), ...good.sublist(2)]);
      expect(_read(withFill(3)), (width: 64, height: 48));
      expect(_read(withFill(64)), (width: 64, height: 48));
      expect(_read(withFill(65)), isNull);
    });

    test('Marker ohne Länge (RSTn) vor dem SOF werden übersprungen', () {
      final b = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD0, ...good.sublist(2)]);
      expect(_read(b), (width: 64, height: 48));
    });

    test('Graustufen mit einer Komponente', () {
      final b = Uint8List.fromList(<int>[
        0xFF,
        0xD8,
        ...segment(0xC0, <int>[8, 0, 10, 0, 20, 1, 1, 0x11, 0]),
        ...segment(0xDA, <int>[1, 1, 0, 0, 63, 0]),
        0xFF,
        0xD9,
      ]);
      expect(_read(b), (width: 20, height: 10));
    });
  });

  test('Plausibilität: Patches mit dem Originalwert lassen das Bild gültig (die Offsets stimmen)', () {
    final at = segmentAt(good, 0xC0);
    for (final offset in <int>[4, 9, 10, 11, 12, 13]) {
      expect(_read(_patched(good, offset, good[at + offset])), (width: 64, height: 48), reason: 'Offset $offset');
    }
  });

  group('ungültige Köpfe', () {
    test('leer, zu kurz, kein JPEG', () {
      expect(_read(Uint8List(0)), isNull);
      expect(_read(Uint8List.fromList(<int>[0xFF, 0xD8])), isNull);
      expect(_read(Uint8List.fromList('hallo welt, kein bild'.codeUnits)), isNull);
      expect(_read(Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4])), isNull);
    });

    test('abgeschnitten vor dem SOS', () {
      final cut = good.sublist(
        0,
        segmentAt(good, 0xC0) + 2 + ((good[segmentAt(good, 0xC0) + 2] << 8) | good[segmentAt(good, 0xC0) + 3]),
      );
      expect(_read(Uint8List.fromList(cut)), isNull);
    });

    test('abgeschnitten mitten im Segment', () {
      expect(_read(Uint8List.fromList(good.sublist(0, 12))), isNull);
    });

    test('Segmentlänge unter 2 oder über das Ende hinaus', () {
      expect(_read(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x01, 1, 2, 3, 4])), isNull);
      expect(_read(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xFF, 1, 2, 3, 4])), isNull);
    });

    test('EOI vor dem SOF', () {
      expect(_read(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9, 0xFF, 0xD8, ...good.sublist(2)])), isNull);
    });

    test('EOI vor dem SOF, danach eine plausible Länge und ein gültiges SOF: trotzdem ungültig', () {
      // Ohne die EOI-Regel würde „FF D9 00 02“ als leeres Segment gelesen und das folgende SOF akzeptiert.
      final at = segmentAt(good, 0xC0);
      final sof = good.sublist(at, at + 2 + 17);
      final b = Uint8List.fromList(<int>[
        0xFF, 0xD8, 0xFF, 0xD9, 0x00, 0x02, //
        ...sof,
        ...segment(0xDA, <int>[3, 1, 0, 2, 0x11, 3, 0x11, 0, 63, 0]),
        0xFF, 0xD9,
      ]);
      expect(_read(b), isNull);
    });

    test('SOS-Segment mit Länge über das Dateiende hinaus', () {
      final at = segmentAt(good, 0xC0);
      final sof = good.sublist(at, at + 2 + 17);
      final b = Uint8List.fromList(<int>[0xFF, 0xD8, ...sof, 0xFF, 0xDA, 0x00, 0xFF, 1, 2, 3]);
      expect(_read(b), isNull);
      // Gegenprobe: dasselbe mit passender Länge ist gültig.
      final ok = Uint8List.fromList(<int>[
        0xFF,
        0xD8,
        ...sof,
        ...segment(0xDA, <int>[1, 1, 0, 0, 63, 0]),
      ]);
      expect(_read(ok), (width: 64, height: 48));
    });

    test('SOS vor dem SOF (SOF nach SOS wird nie gesucht)', () {
      final sof = good.sublist(segmentAt(good, 0xC0), segmentAt(good, 0xC0) + 2 + 17);
      final b = Uint8List.fromList(<int>[
        0xFF,
        0xD8,
        ...segment(0xDA, <int>[1, 1, 0, 0, 63, 0]),
        ...sof,
      ]);
      expect(_read(b), isNull);
    });

    test('progressiv (SOF2) und weitere SOFn', () {
      for (final m in <int>[0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]) {
        final b = Uint8List.fromList(good);
        b[segmentAt(good, 0xC0) + 1] = m;
        expect(_read(b), isNull, reason: 'SOF-Marker 0x${m.toRadixString(16)}');
      }
    });

    test('ein zweites SOF', () {
      final at = segmentAt(good, 0xC0);
      final second = good.sublist(at, at + 2 + 17);
      final b = Uint8List.fromList(<int>[...good.sublist(0, at), ...second, ...good.sublist(at)]);
      expect(_read(b), isNull);
    });

    test('SOF im EXIF-Vorschaubild (APP1) wird nie als Bildkopf gelesen', () {
      final thumb = jpegBytes(width: 16, height: 16);
      final app1 = segment(0xE1, <int>[...'Exif'.codeUnits, 0, 0, ...thumb]);
      // Echtes Bild nach dem Vorschaubild: die Maße des echten Bildes zählen, nicht die des Vorschaubilds.
      final withReal = Uint8List.fromList(<int>[0xFF, 0xD8, ...app1, ...good.sublist(2)]);
      expect(_read(withReal), (width: 64, height: 48));
      // Nur das Vorschaubild hat ein SOF, das Hauptbild fehlt: ungültig.
      final onlyThumb = Uint8List.fromList(<int>[0xFF, 0xD8, ...app1, 0xFF, 0xD9]);
      expect(_read(onlyThumb), isNull);
    });

    test('Null-Maße', () {
      expect(_read(_patched(good, 5, 0)..[segmentAt(good, 0xC0) + 6] = 0), isNull); // Breite 0
      final h0 = Uint8List.fromList(good);
      h0[segmentAt(good, 0xC0) + 5] = 0;
      h0[segmentAt(good, 0xC0) + 6] = 0;
      expect(_read(h0), isNull);
    });

    test('Präzision ungleich 8 Bit', () {
      expect(_read(_patched(good, 4, 12)), isNull);
    });

    test('Komponentenzahl 2 oder 4', () {
      expect(_read(_patched(good, 9, 2)), isNull);
      expect(_read(_patched(good, 9, 4)), isNull);
    });

    test('Abtastfaktoren 0 und 5', () {
      expect(_read(_patched(good, 11, 0x01)), isNull); // horizontal 0
      expect(_read(_patched(good, 11, 0x10)), isNull); // vertikal 0
      expect(_read(_patched(good, 11, 0x51)), isNull); // horizontal 5
    });

    test('doppelte Komponenten-IDs', () {
      final b = Uint8List.fromList(good);
      final at = segmentAt(good, 0xC0);
      b[at + 13] = b[at + 10]; // ID der zweiten Komponente = ID der ersten
      expect(_read(b), isNull);
    });

    test('zu viele Segmente vor dem SOF', () {
      final many = <int>[
        for (var i = 0; i < 70; i++) ...segment(0xFE, <int>[1]),
      ];
      expect(_read(Uint8List.fromList(<int>[0xFF, 0xD8, ...many, ...good.sublist(2)])), isNull);
    });

    test('Daten, die nicht mit einem Marker beginnen', () {
      expect(_read(Uint8List.fromList(<int>[0xFF, 0xD8, 0x12, 0x34, 0x56, 0x78])), isNull);
    });
  });
}
