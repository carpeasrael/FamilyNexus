import 'dart:typed_data';

import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/text_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

  test('erlaubt passende Bilddatei', () {
    expect(AttachmentPolicy.check(fileName: 'foto.PNG', bytes: png), isNull);
  });

  test('lehnt ausführbare/unbekannte Typen ab', () {
    for (final n in <String>['x.exe', 'x.apk', 'x.sh', 'x.html', 'x.svg', 'x.js', 'x', 'x.', 'archiv.zip']) {
      expect(AttachmentPolicy.check(fileName: n, bytes: png), AttachmentRejection.typeNotAllowed, reason: n);
    }
  });

  test('lehnt leere und zu große Dateien ab', () {
    expect(AttachmentPolicy.check(fileName: 'a.png', bytes: Uint8List(0)), AttachmentRejection.empty);
    expect(
      AttachmentPolicy.check(fileName: 'a.txt', bytes: Uint8List(AttachmentPolicy.maxBytes + 1)),
      AttachmentRejection.tooLarge,
    );
    expect(AttachmentPolicy.check(fileName: 'a.txt', bytes: Uint8List(AttachmentPolicy.maxBytes)), isNull);
  });

  test('lehnt Endung/Inhalt-Widerspruch ab (z. B. ausführbar als .png getarnt)', () {
    expect(
      AttachmentPolicy.check(fileName: 'a.png', bytes: Uint8List.fromList(<int>[0x4D, 0x5A, 0, 0])),
      AttachmentRejection.contentMismatch,
    );
    expect(
      AttachmentPolicy.check(fileName: 'a.pdf', bytes: png),
      AttachmentRejection.contentMismatch,
    );
  });

  test('Dateinamen werden bereinigt', () {
    expect(AttachmentPolicy.sanitizeFileName('../../etc/passwd'), 'passwd');
    expect(AttachmentPolicy.sanitizeFileName(r'C:\temp\a.png'), 'a.png');
    expect(AttachmentPolicy.sanitizeFileName('a\u0000b.png'), 'a_b.png');
    expect(AttachmentPolicy.sanitizeFileName('...'), 'datei');
    expect(AttachmentPolicy.sanitizeFileName('.hidden.png'), 'hidden.png');
    expect(AttachmentPolicy.sanitizeFileName('foto\u202Egnp.exe'), isNot(contains('\u202E')));
    final long = AttachmentPolicy.sanitizeFileName('${'a' * 300}.png');
    expect(long.length, 100);
    expect(long, endsWith('.png'));
  });

  test('Dateinamen: unsichtbare Zeichen wie bei TextSanitizer entfernt (#164)', () {
    for (final cp in <int>[0x85, 0x9F, 0x61C, 0x200B, 0x200D, 0x200E, 0x200F, 0x2060, 0x2064, 0xFEFF]) {
      final c = String.fromCharCode(cp);
      expect(AttachmentPolicy.sanitizeFileName('a${c}b.png'), 'a_b.png', reason: 'U+${cp.toRadixString(16)}');
    }
    // Am Namensende: Endung stimmt nicht mehr, der Anhang bleibt abgelehnt.
    final tail = AttachmentPolicy.sanitizeFileName('a.png‏');
    expect(tail, isNot(contains('‏')));
    expect(AttachmentPolicy.mimeForName(tail), isNull);
  });

  test('Dateinamen: jedes von TextSanitizer entfernte Zeichen wird auch hier ersetzt (#164)', () {
    final missed = <String>[];
    for (var cp = 0; cp <= 0xFFFF; cp++) {
      if (cp >= 0xD800 && cp <= 0xDFFF) continue; // einzelne Surrogate
      final c = String.fromCharCode(cp);
      // Gewöhnlicher Leerraum wird von clean nur zu ' ' normalisiert (U+FEFF zählt für Dart als
      // Leerraum und steht im Test oben); alles andere, was zu ' ' wird, ist ein entferntes Zeichen.
      if (RegExp(r'\s').hasMatch(c)) continue;
      if (TextSanitizer.clean('a${c}b') != 'a b') continue;
      if (AttachmentPolicy.sanitizeFileName('a${c}b.png').contains(c)) {
        missed.add('U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}');
      }
    }
    expect(missed, isEmpty);
  });

  test('eingehende Metadaten', () {
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: 100), isTrue);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'IMAGE/PNG', size: 100), isTrue);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'application/x-msdownload', size: 100), isFalse);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: AttachmentPolicy.maxBytes + 1), isFalse);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: -1), isFalse);
  });
}
