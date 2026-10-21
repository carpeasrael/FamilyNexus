import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerUrl', () {
    test('ergänzt https und normalisiert', () {
      expect(ServerUrl.tryParse('Matrix.Org')?.toString(), 'https://matrix.org');
      expect(ServerUrl.tryParse(' https://example.com/ ')?.toString(), 'https://example.com');
      expect(ServerUrl.tryParse('https://example.com:8448')?.toString(), 'https://example.com:8448');
    });

    test('lehnt unsichere und fremde Schemata ab', () {
      for (final s in <String>[
        'http://example.com',
        'ftp://example.com',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'HTTP://example.com',
      ]) {
        expect(ServerUrl.tryParse(s), isNull, reason: s);
      }
    });

    test('lehnt Zugangsdaten, Query, Fragment, Pfad, Leerraum ab', () {
      for (final s in <String>[
        'https://user:pw@example.com',
        'https://example.com?x=1',
        'https://example.com#frag',
        'https://example.com/path',
        'https://exa mple.com',
        'https://',
        '',
        '   ',
        'https://-bad-.com',
        'https://exa_mple.com',
        'https://example.com:99999',
      ]) {
        expect(ServerUrl.tryParse(s), isNull, reason: s);
      }
    });

    test('lehnt überlange Eingaben ab', () {
      expect(ServerUrl.tryParse('https://${'a' * 300}.com'), isNull);
    });
  });

  group('MatrixIds', () {
    test('gültige und ungültige Benutzer-IDs', () {
      expect(MatrixIds.isUserId('@anna:example.org'), isTrue);
      expect(MatrixIds.isUserId('@anna:example.org:8448'), isTrue);
      for (final s in <String>['anna:example.org', '@anna', '@Anna:example.org', '@a b:example.org', '@a:ex ample', '@:x.org']) {
        expect(MatrixIds.isUserId(s), isFalse, reason: s);
      }
    });

    test('Raum-IDs', () {
      expect(MatrixIds.isRoomId('!abcDEF123:example.org'), isTrue);
      expect(MatrixIds.isRoomId('#alias:example.org'), isFalse);
      expect(MatrixIds.isRoomId('!a<script>:x.org'), isFalse);
    });
  });
}
