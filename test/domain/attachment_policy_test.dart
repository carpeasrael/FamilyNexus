import 'dart:typed_data';

import 'package:family_nexus/domain/attachment_policy.dart';
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

  test('eingehende Metadaten', () {
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: 100), isTrue);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'IMAGE/PNG', size: 100), isTrue);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'application/x-msdownload', size: 100), isFalse);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: AttachmentPolicy.maxBytes + 1), isFalse);
    expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: -1), isFalse);
  });
}
