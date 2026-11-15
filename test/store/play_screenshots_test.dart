import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// #349 (A11): Play-Bilderpaket `store/screenshots/android/<de-DE|en-US>/phoneScreenshots/`. Prüft Dateien und Format
/// (aus dem Kenntnisstand zu den Play-Vorgaben, nicht gegen die Konsole geprüft), die Überschriften aus
/// `tool/preview/play_captions.json` und, dass die Aufnahmen aus erfundenen Daten stammen. Nur dart:io.
const _locales = <String>['de-DE', 'en-US'];
const _expected = <String>[
  '01-kalender.png',
  '02-chat.png',
  '03-einkauf.png',
  '04-datenschutz.png',
  '05-heute.png',
  '06-einzelchat.png',
  '07-familie.png',
];
const _maxBytes = 8 * 1024 * 1024;

Directory _dir(String locale) => Directory('store/screenshots/android/$locale/phoneScreenshots');

/// Chunks der PNG-Datei in Reihenfolge bis einschließlich IEND; wirft bei Bruch der Struktur.
List<({String type, int length, int offset})> _chunks(Uint8List b) {
  const sig = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  expect(b.length, greaterThan(8 + 25), reason: 'zu klein für ein PNG');
  expect(b.sublist(0, 8), sig, reason: 'PNG-Signatur');
  final data = ByteData.sublistView(b);
  final out = <({String type, int length, int offset})>[];
  var pos = 8;
  while (pos + 12 <= b.length) {
    final len = data.getUint32(pos);
    final type = ascii.decode(b.sublist(pos + 4, pos + 8));
    out.add((type: type, length: len, offset: pos + 8));
    pos += 12 + len;
    if (type == 'IEND') break;
  }
  expect(out.last.type, 'IEND', reason: 'IEND fehlt');
  return out;
}

List<Map<String, dynamic>> _shots() {
  final json = jsonDecode(File('tool/preview/play_captions.json').readAsStringSync()) as Map<String, dynamic>;
  return (json['shots'] as List<dynamic>).cast<Map<String, dynamic>>();
}

void main() {
  for (final locale in _locales) {
    group('#349 Play-Bilder $locale', () {
      test('genau die sieben erwarteten Dateien, sonst nichts', () {
        expect(_dir(locale).existsSync(), isTrue, reason: '${_dir(locale).path} fehlt');
        final names = _dir(locale).listSync().map((e) => e.uri.pathSegments.last).toList()..sort();
        expect(names, _expected);
      });

      for (final name in _expected) {
        test('$name: PNG RGB 8 Bit ohne Alpha, 1080×1920, höchstens 8 MB', () {
          final file = File('${_dir(locale).path}/$name');
          expect(file.existsSync(), isTrue, reason: '${file.path} fehlt');
          expect(file.lengthSync(), lessThanOrEqualTo(_maxBytes));
          final bytes = file.readAsBytesSync();
          final chunks = _chunks(bytes);
          expect(chunks.first.type, 'IHDR', reason: 'IHDR muss der erste Chunk sein');
          expect(chunks.first.length, 13);
          final h = ByteData.sublistView(bytes, chunks.first.offset, chunks.first.offset + 13);
          expect(h.getUint32(0), 1080, reason: 'Breite');
          expect(h.getUint32(4), 1920, reason: 'Höhe');
          expect(h.getUint8(8), 8, reason: 'Bittiefe');
          expect(h.getUint8(9), 2, reason: 'Farbtyp 2 = RGB ohne Alpha');
          expect(h.getUint8(12), 0, reason: 'kein Interlace');
          expect(chunks.map((c) => c.type), isNot(contains('tRNS')), reason: 'Transparenz-Chunk');
        });
      }
    });
  }

  test('#349 DE und EN sind verschiedene Bilder, die Reihenfolge beginnt mit den vier Funktionen des Issues', () {
    for (final name in _expected) {
      final de = File('${_dir('de-DE').path}/$name');
      final en = File('${_dir('en-US').path}/$name');
      expect(de.existsSync() && en.existsSync(), isTrue, reason: '$name fehlt');
      expect(de.readAsBytesSync(), isNot(en.readAsBytesSync()), reason: '$name: DE und EN sind gleich');
    }
    expect(_expected.take(4).map((n) => n.substring(3, n.length - 4)), <String>['kalender', 'chat', 'einkauf', 'datenschutz']);
  });

  group('#349 Überschriften (tool/preview/play_captions.json)', () {
    final shots = _shots();
    test('Motive, Reihenfolge und Dateinamen passen zu den Dateien', () {
      expect(<String>[for (var i = 0; i < shots.length; i++) '${(i + 1).toString().padLeft(2, '0')}-${shots[i]['name']}.png'], _expected);
      expect(shots.map((s) => s['raw']), <String>['2-kalender', '3-chat', '5-einkauf', '7-datenschutz', '1-heute', '4-einzelchat', '6-familie']);
    });

    final price = RegExp(r'[€$£]|\b(free|gratis|kostenlos|price|preis|euro|usd)\b', caseSensitive: false);
    final url = RegExp(r'http|www|\.com|\.de|\.org|://', caseSensitive: false);
    final award = RegExp(r'\bbest(e|en|er|es)?\b|#\s?1|award|auszeichnung|preisgekr|nummer 1|number one|\btop\b|führend|leading|world|weltweit', caseSensitive: false);
    // Liste wie in test/store/store_wording_test.dart.
    final british = RegExp(r'colour|synchronis|cancell|licence|authoris|organis|behaviour|centre|whilst|amongst|defence|\btick(s|ed)?\b', caseSensitive: false);
    for (final lang in <String>['de', 'en']) {
      for (final s in shots) {
        final text = s[lang] as String;
        test('„$text“ ($lang): kurz, ohne Preise, URLs, Auszeichnungen, Superlative', () {
          expect(text.trim(), isNotEmpty);
          expect(text.length, lessThanOrEqualTo(40));
          expect(price.hasMatch(text), isFalse, reason: 'Preis');
          expect(url.hasMatch(text), isFalse, reason: 'URL');
          expect(award.hasMatch(text), isFalse, reason: 'Auszeichnung/Superlativ');
          if (lang == 'en') expect(british.hasMatch(text), isFalse, reason: 'britische Schreibweise');
        });
      }
    }
    test('Datenschutz-Überschrift nur belegbar (Play-Beschreibung, docs/STORE.md)', () {
      final p = shots.firstWhere((s) => s['name'] == 'datenschutz');
      expect(p['de'], 'Kein Tracking, keine Werbung');
      expect(p['en'], 'No tracking, no ads');
    });
  });

  group('#349 Aufnahmedaten sind erfunden (tool/preview/preview_data.dart)', () {
    final src = File('tool/preview/preview_data.dart').readAsStringSync();
    test('Fake-Server mit Host fake.test, Demo-Namen', () {
      expect(src, contains('FakeMatrixServer()'), reason: 'Standard-Host des Fake-Servers');
      expect(src, isNot(contains('FakeMatrixServer(host')), reason: 'kein eigener Host');
      expect(File('test/support/fake_matrix.dart').readAsStringSync(), contains("this.host = 'fake.test'"));
      for (final n in <String>['Anna', 'Ben', 'Clara', 'Familie Berger', 'Berger Family']) {
        expect(src, contains(n));
      }
    });
    test('keine Kennungen des Projekts oder eines echten Servers', () {
      for (final bad in <String>['inneso', 'carpeasrael', 'matrix.org']) {
        expect(src.toLowerCase(), isNot(contains(bad)), reason: bad);
      }
    });
  });
}
