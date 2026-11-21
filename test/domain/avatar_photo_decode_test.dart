import 'dart:typed_data';

import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_decode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/avatar_photo_fixtures.dart';

void main() {
  test('dekodiert ein gültiges Foto zu Rohpixeln (RGBA)', () {
    final px = AvatarPhotoDecoder.decode(jpegBytes(width: 64, height: 48));
    expect(px, isNotNull);
    expect(px!.width, 64);
    expect(px.height, 48);
    expect(px.rgba.length, 64 * 48 * 4);
    // Die Fläche ist am linken Rand rot-dominant (r = 200), und alles ist deckend.
    expect(px.rgba[0], inInclusiveRange(170, 230));
    expect(<int>{for (var i = 3; i < px.rgba.length; i += 4) px.rgba[i]}, <int>{255});
  });

  test('Randgröße 192 x 192 wird dekodiert', () {
    final px = AvatarPhotoDecoder.decode(jpegBytes(width: 192, height: 192, quality: 40));
    expect(px?.width, 192);
    expect(px?.rgba.length, 192 * 192 * 4);
  });

  test('Bild über 192 px wird verworfen, ohne es zu dekodieren', () {
    expect(AvatarPhotoDecoder.decode(jpegBytes(width: 200, height: 100)), isNull);
  });

  test('Bild über 16 KiB wird verworfen', () {
    final big = jpegBytes(width: 192, height: 192, quality: 95, noisy: true);
    expect(big.length, greaterThan(AvatarPhotoLimits.maxBytes));
    expect(AvatarPhotoDecoder.decode(big), isNull);
  });

  test('leer und Nicht-JPEG ergeben null', () {
    expect(AvatarPhotoDecoder.decode(Uint8List(0)), isNull);
    expect(AvatarPhotoDecoder.decode(Uint8List.fromList('Text statt Bild'.codeUnits)), isNull);
  });

  test('gültiger Kopf, aber Bilddaten sind Müll: kein Absturz, nie falsche Maße', () {
    final good = jpegBytes(width: 64, height: 48);
    final sos = segmentAt(good, 0xDA);
    expect(sos, greaterThan(0));
    final garbage = Uint8List.fromList(good);
    for (var i = sos + 14; i < garbage.length - 2; i++) {
      garbage[i] = (i * 37 + 11) & 0xFF == 0xFF ? 0x7F : (i * 37 + 11) & 0xFF;
    }
    late AvatarPixels? px;
    expect(() => px = AvatarPhotoDecoder.decode(garbage), returnsNormally);
    if (px != null) {
      expect(px!.width, 64);
      expect(px!.height, 48);
      expect(px!.rgba.length, 64 * 48 * 4);
    }
  });

  test('abgeschnittenes Bild: kein Absturz, nie falsche Maße', () {
    final good = jpegBytes(width: 64, height: 48);
    final cut = Uint8List.fromList(good.sublist(0, good.length ~/ 2));
    late AvatarPixels? px;
    expect(() => px = AvatarPhotoDecoder.decode(cut), returnsNormally);
    if (px != null) {
      expect(px!.width, 64);
      expect(px!.height, 48);
    }
  });
}
