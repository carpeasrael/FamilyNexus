import 'dart:convert';
import 'dart:typed_data';

import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/jpeg_header.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/avatar_photo_fixtures.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _id1 = '00000000-0000-4000-8000-000000000001';
const String _id2 = '00000000-0000-4000-8000-000000000002';
final DateTime _now = DateTime.utc(2026, 11, 21, 12);
final int _nowMs = _now.millisecondsSinceEpoch;

AvatarPhoto _photo({String owner = _anna, String id = _id1, int? createdAt, Uint8List? bytes}) {
  final b = bytes ?? jpegBytes();
  return AvatarPhoto(
    owner: owner,
    id: id,
    createdAt: createdAt ?? _nowMs,
    cleared: false,
    width: 64,
    height: 48,
    bytes: b,
  );
}

Map<String, Object?> _content({Map<String, Object?> override = const <String, Object?>{}, Uint8List? bytes}) {
  final c = AvatarPhotoCodec.encode(_photo(bytes: bytes));
  return <String, Object?>{...c, ...override};
}

int _widthOf(Uint8List jpeg) => JpegHeader.read(jpeg, maxSide: 192)!.width;

AvatarPhoto? _decode(Map<String, Object?> c, {String sender = _anna}) =>
    AvatarPhotoCodec.decode(c, sender: sender, now: _now);

void main() {
  test('Die Sperre ist in diesem Teil-PR aus', () {
    expect(AvatarPhotoFlags.enabled, isFalse);
  });

  group('AvatarPhotoCodec', () {
    test('Hin und zurück: Foto', () {
      final p = _photo();
      expect(_decode(AvatarPhotoCodec.encode(p)), p);
    });

    test('Hin und zurück: Löschmarke ohne Daten', () {
      final p = AvatarPhoto.clearedMarker(owner: _anna, id: _id2, createdAt: _nowMs);
      final c = AvatarPhotoCodec.encode(p);
      expect(c['data'], '');
      expect(_decode(c), p);
    });

    test('Kennzeichen des Formats', () {
      final c = AvatarPhotoCodec.encode(_photo());
      expect(AvatarPhotoCodec.type, 'de.inneso.familynexus.avatarphoto');
      expect(c['v'], 1);
      expect(c.keys.toSet(), <String>{'v', 'owner', 'id', 'created_at', 'cleared', 'mime', 'w', 'h', 'data'});
      expect(c['mime'], 'image/jpeg');
    });

    test('Base64 ist kanonisch und passt unter die Grenze', () {
      final big = jpegBytes(width: 192, height: 192, quality: 40);
      expect(big.length, lessThanOrEqualTo(AvatarPhotoLimits.maxBytes));
      final photo = AvatarPhoto(
        owner: _anna,
        id: _id1,
        createdAt: _nowMs,
        cleared: false,
        width: 192,
        height: 192,
        bytes: big,
      );
      final data = AvatarPhotoCodec.encode(photo)['data']! as String;
      expect(data.length, lessThanOrEqualTo(AvatarPhotoLimits.maxBase64));
      expect(base64.encode(base64.decode(data)), data);
    });

    test('unbekannte Felder werden ignoriert', () {
      expect(_decode(_content(override: <String, Object?>{'extra': 1, 'zukunft': 'x'})), isNotNull);
    });

    group('verwirft', () {
      test('falsche Schemaversion', () {
        expect(_decode(_content(override: <String, Object?>{'v': 2})), isNull);
        expect(_decode(_content(override: <String, Object?>{'v': '1'})), isNull);
        expect(_decode(<String, Object?>{..._content()}..remove('v')), isNull);
      });

      test('Eigentümer ungleich Absender, ungültiger Absender', () {
        expect(_decode(_content(), sender: _ben), isNull);
        expect(_decode(_content(), sender: 'anna'), isNull);
      });

      test('falsche Feldtypen und fehlende Felder', () {
        for (final key in <String>['owner', 'id', 'created_at', 'cleared', 'mime', 'w', 'h', 'data']) {
          expect(_decode(<String, Object?>{..._content()}..remove(key)), isNull, reason: 'fehlt: $key');
        }
        expect(_decode(_content(override: <String, Object?>{'created_at': '1'})), isNull);
        expect(_decode(_content(override: <String, Object?>{'cleared': 0})), isNull);
        expect(_decode(_content(override: <String, Object?>{'w': 64.0})), isNull);
        expect(_decode(_content(override: <String, Object?>{'data': 5})), isNull);
      });

      test('anderen MIME-Typ', () {
        expect(_decode(_content(override: <String, Object?>{'mime': 'image/png'})), isNull);
      });

      test('ungültige Foto-ID', () {
        expect(_decode(_content(override: <String, Object?>{'id': 'nicht-uuid'})), isNull);
        expect(
          _decode(_content(override: <String, Object?>{'id': 'abcdef00-0000-4000-8000-000000000001'.toUpperCase()})),
          isNull,
        );
      });

      test('Zeitstempel: nicht positiv, und mehr als einen Tag in der Zukunft', () {
        expect(_decode(_content(override: <String, Object?>{'created_at': 0})), isNull);
        expect(_decode(_content(override: <String, Object?>{'created_at': -5})), isNull);
        final limit = _now.add(AvatarPhotoLimits.maxFuture).millisecondsSinceEpoch;
        expect(_decode(_content(override: <String, Object?>{'created_at': limit})), isNotNull);
        expect(_decode(_content(override: <String, Object?>{'created_at': limit + 1})), isNull);
      });

      test('Base64 ohne Padding, mit Umbrüchen oder im URL-Alphabet (nicht kanonisch)', () {
        // Ein Bild, dessen Base64 ein Padding und ein „+“ oder „/“ enthält, damit alle drei Fälle greifen.
        late Uint8List bytes;
        late String data;
        for (var w = 40; w < 80; w++) {
          bytes = jpegBytes(width: w, height: 48);
          data = base64.encode(bytes);
          if (data.endsWith('=') && (data.contains('+') || data.contains('/'))) break;
        }
        expect(data, endsWith('='), reason: 'Testbild mit Padding gefunden');
        expect(data.contains('+') || data.contains('/'), isTrue);
        final photo = AvatarPhoto(
          owner: _anna,
          id: _id1,
          createdAt: _nowMs,
          cleared: false,
          width: _widthOf(bytes),
          height: 48,
          bytes: bytes,
        );
        Map<String, Object?> with_(String d) => <String, Object?>{...AvatarPhotoCodec.encode(photo), 'data': d};
        expect(_decode(with_(data)), isNotNull, reason: 'kanonisch: gültig');
        expect(_decode(with_(data.replaceAll('=', ''))), isNull, reason: 'ohne Padding');
        expect(_decode(with_('${data.substring(0, 8)}\n${data.substring(8)}')), isNull, reason: 'Umbruch');
        // Das URL-Alphabet nimmt Darts Dekoder an; die Prüfung muss es trotzdem ablehnen.
        final urlSafe = data.replaceAll('+', '-').replaceAll('/', '_');
        expect(urlSafe, isNot(data));
        expect(
          () => base64.decode(urlSafe),
          returnsNormally,
          reason: 'Voraussetzung: Dart akzeptiert das URL-Alphabet',
        );
        expect(_decode(with_(urlSafe)), isNull, reason: 'URL-Alphabet');
        expect(_decode(with_('!!!nicht base64!!!')), isNull);
      });

      test('Daten über der Zeichengrenze', () {
        expect(_decode(_content(override: <String, Object?>{'data': 'A' * (AvatarPhotoLimits.maxBase64 + 4)})), isNull);
      });

      test('Bild über 16 KiB', () {
        final big = jpegBytes(width: 192, height: 192, quality: 95, noisy: true);
        expect(big.length, greaterThan(AvatarPhotoLimits.maxBytes));
        final c = <String, Object?>{..._content(), 'w': 192, 'h': 192, 'data': base64.encode(big)};
        expect(_decode(c), isNull);
      });

      test('gültiges Base64, aber kein JPEG', () {
        final c = _content(
          override: <String, Object?>{'data': base64.encode(utf8.encode('Das ist kein Bild, nur Text.'))},
        );
        expect(_decode(c), isNull);
      });

      test('Maße im Ereignis weichen vom JPEG-Kopf ab, oder liegen über 192', () {
        expect(_decode(_content(override: <String, Object?>{'w': 63})), isNull);
        expect(_decode(_content(override: <String, Object?>{'h': 49})), isNull);
        final wide = jpegBytes(width: 200, height: 100);
        expect(_decode(_content(override: <String, Object?>{'w': 200, 'h': 100, 'data': base64.encode(wide)})), isNull);
      });

      test('Löschmarke mit Daten oder Maßen', () {
        final marker = AvatarPhotoCodec.encode(AvatarPhoto.clearedMarker(owner: _anna, id: _id2, createdAt: _nowMs));
        expect(_decode(<String, Object?>{...marker, 'data': base64.encode(jpegBytes())}), isNull);
        expect(_decode(<String, Object?>{...marker, 'w': 64, 'h': 48}), isNull);
      });

      test('Foto ohne Bilddaten', () {
        expect(_decode(_content(override: <String, Object?>{'data': ''})), isNull);
      });
    });

    test('encode lehnt Ungültiges ab', () {
      expect(() => AvatarPhotoCodec.encode(_photo(id: 'x')), throwsStateError);
      expect(() => AvatarPhotoCodec.encode(_photo(bytes: Uint8List.fromList(<int>[1, 2, 3]))), throwsStateError);
    });
  });

  group('Reihenfolge (neuestes gewinnt)', () {
    test('größeres createdAt gewinnt', () {
      final older = _photo(createdAt: 1000);
      final newer = _photo(id: _id2, createdAt: 2000);
      expect(newer.isNewerThan(older), isTrue);
      expect(older.isNewerThan(newer), isFalse);
    });

    test('bei Gleichstand gewinnt die größere ID, und nie beide', () {
      final a = _photo(createdAt: 1000);
      final b = _photo(id: _id2, createdAt: 1000);
      expect(b.isNewerThan(a), isTrue);
      expect(a.isNewerThan(b), isFalse);
      expect(a.isNewerThan(a), isFalse);
    });
  });

  group('AvatarResetCodec', () {
    final reset = const AvatarReset(target: _ben, photoId: _id1, photoCreatedAt: 12345);

    test('Hin und zurück', () {
      final c = AvatarResetCodec.encode(reset);
      expect(AvatarResetCodec.type, 'de.inneso.familynexus.avatarreset');
      expect(c.keys.toSet(), <String>{'v', 'target', 'photo_id', 'photo_created_at'});
      expect(AvatarResetCodec.decode(c, sender: _anna), reset);
    });

    test('verwirft Ungültiges', () {
      final c = AvatarResetCodec.encode(reset);
      expect(AvatarResetCodec.decode(<String, Object?>{...c, 'v': 2}, sender: _anna), isNull);
      expect(AvatarResetCodec.decode(c, sender: 'anna'), isNull);
      expect(AvatarResetCodec.decode(<String, Object?>{...c, 'target': 'ben'}, sender: _anna), isNull);
      expect(AvatarResetCodec.decode(<String, Object?>{...c, 'photo_id': 'x'}, sender: _anna), isNull);
      expect(AvatarResetCodec.decode(<String, Object?>{...c, 'photo_created_at': 0}, sender: _anna), isNull);
      expect(AvatarResetCodec.decode(<String, Object?>{...c, 'photo_created_at': '5'}, sender: _anna), isNull);
      expect(AvatarResetCodec.decode(<String, Object?>{...c}..remove('target'), sender: _anna), isNull);
    });

    test('encode lehnt Ungültiges ab', () {
      expect(
        () => AvatarResetCodec.encode(const AvatarReset(target: 'x', photoId: _id1, photoCreatedAt: 1)),
        throwsStateError,
      );
    });
  });
}
