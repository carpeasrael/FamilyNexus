import 'package:family_nexus/domain/text_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entfernt Steuer-, Bidi- und Nullbreiten-Zeichen und normalisiert Leerraum', () {
    expect(TextSanitizer.clean('A\u202Eb\u200Bc\u0000\n  d'), 'A b c d');
    expect(TextSanitizer.clean('  \u2066x\u2069  '), 'x');
  });

  test('kürzt nach Zeichen, nicht nach UTF-16-Einheiten', () {
    final s = TextSanitizer.clean('😀' * 100, max: 10);
    expect(s.runes.length, 10);
  });

  test('Anzeigename fällt auf die ID zurück, wenn nach der Bereinigung leer', () {
    expect(TextSanitizer.displayName('\u202E\u200B', '@a:x.org'), '@a:x.org');
    expect(TextSanitizer.displayName(null, '@a:x.org'), '@a:x.org');
    expect(TextSanitizer.displayName('Anna', '@a:x.org'), 'Anna');
  });

  test('Reaktionsschlüssel: Emojis ja, Text/Steuerzeichen/zu lang nein', () {
    expect(TextSanitizer.isReactionKey('👍'), isTrue);
    expect(TextSanitizer.isReactionKey('❤️'), isTrue);
    for (final bad in <String>['', 'hallo', 'ab 12', '👍\u202E', '😀😀😀😀😀😀😀😀😀']) {
      expect(TextSanitizer.isReactionKey(bad), isFalse, reason: bad);
    }
  });
}
