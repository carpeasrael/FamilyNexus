import 'dart:async';
import 'dart:typed_data';

import 'package:family_nexus/data/matrix/background_image_work.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

/// Unkomprimiertes 24-Bit-BMP: braucht keine Abhängigkeit und kostet beim Dekodieren spürbar Zeit.
Uint8List _bmp(int width, int height) {
  final rowSize = (width * 3 + 3) & ~3;
  final pixels = rowSize * height;
  final bytes = Uint8List(54 + pixels);
  final d = ByteData.sublistView(bytes)
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4D)
    ..setUint32(2, bytes.length, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, pixels, Endian.little);
  assert(d.lengthInBytes == bytes.length);
  for (var i = 54; i < bytes.length; i++) {
    bytes[i] = i & 0xFF;
  }
  return bytes;
}

void main() {
  // `test` statt `testWidgets`: Der Timer muss in echter Zeit laufen.
  test('#129: die Oberfläche läuft weiter, während ein 12-MP-Bild verkleinert wird', () async {
    final args = MatrixImageFileResizeArguments(
      bytes: _bmp(4000, 3000),
      maxDimension: 800,
      fileName: 'foto.bmp',
      calcBlurhash: true,
    );
    var ticks = 0;
    final ticker = Timer.periodic(const Duration(milliseconds: 1), (_) => ticks++);
    addTearDown(ticker.cancel);

    final result = await resizeImageInBackground(args);

    ticker.cancel();
    // Über 1: Eine synchrone Ausführung kann nach dem Abgeben des Event-Loops einen Tick liefern.
    expect(ticks, greaterThan(10));
    expect((result!.width, result.height, result.originalWidth, result.originalHeight), (800, 600, 4000, 3000));
  });

  test('das Ergebnis gleicht der Berechnung des SDK', () async {
    final args = MatrixImageFileResizeArguments(
      bytes: _bmp(64, 48),
      maxDimension: 32,
      fileName: 'klein.bmp',
      calcBlurhash: true,
    );
    final background = (await resizeImageInBackground(args))!;
    final direct = MatrixImageFile.resizeImplementation(args)!;
    expect(background.bytes, direct.bytes);
    expect(background.blurhash, direct.blurhash);
    expect((background.width, background.height, background.mimeType), (direct.width, direct.height, direct.mimeType));
  });

  test('nicht dekodierbare Bytes kommen als Fehler beim Aufrufer an', () async {
    final args = MatrixImageFileResizeArguments(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      maxDimension: 32,
      fileName: 'kaputt.png',
      calcBlurhash: false,
    );
    await expectLater(resizeImageInBackground(args), throwsA(anything));
  });
}
