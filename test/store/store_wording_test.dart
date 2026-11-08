import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// #326 Gruppe 4: Store-Texte und Datenschutzerklärung. Englisch einheitlich US, „GDPR“ statt „DSGVO“,
/// „check off“ statt „tick off“; deutsche Pflichtstellen.
const _en = <String>[
  'store/privacy/privacy-policy.en.md',
  'store/metadata/android/en-US/release_notes.txt',
  'store/metadata/android/en-US/full_description.txt',
  'store/metadata/android/en-US/short_description.txt',
  'store/metadata/android/en-US/title.txt',
  'store/metadata/ios/en-US/description.txt',
  'store/metadata/ios/en-US/release_notes.txt',
  'store/metadata/macos/en-US/description.txt',
  'store/metadata/macos/en-US/release_notes.txt',
];

/// Liste wie in `test/l10n/wording_test.dart`, dazu „defence“ und „ticks/ticked“.
final _british = RegExp(
  r'colour|synchronis|cancell|licence|authoris|organis|behaviour|centre|whilst|amongst|defence|\btick(s|ed)?\b',
  caseSensitive: false,
);

void main() {
  for (final f in _en) {
    test('#326 $f: US-Englisch, GDPR, „check off“', () {
      final text = readNormalized(f);
      final lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        expect(_british.hasMatch(lines[i]), isFalse, reason: '$f:${i + 1}: ${lines[i]}');
        expect(lines[i].contains('DSGVO'), isFalse, reason: '$f:${i + 1}: englischer Text nennt „GDPR“');
      }
    });
  }

  test('#326 E27: „Neither … nor … guarantees“ (Singular)', () {
    expect(
      readNormalized('store/privacy/privacy-policy.en.md').replaceAll(RegExp(r'\s+'), ' '),
      contains('Neither local deletion nor account deletion guarantees'),
    );
  });

  test('#326 D34: Die deutsche Erklärung sagt, wer die Seite öffnet', () {
    final text = readNormalized('store/privacy/privacy-policy.de.md').replaceAll(RegExp(r'\s+'), ' ');
    expect(text, isNot(contains('öffnet sie')));
    expect(text, contains('öffnet die App sie in einem Anmeldefenster'));
    expect(text, contains('öffnet die App sie in der Regel in einem Custom Tab'));
  });

  test('#326 D40: „Einladungslinks“ in den Android-Release-Notes (de-DE)', () {
    final text = readNormalized('store/metadata/android/de-DE/release_notes.txt');
    expect(text, contains('Einladungslinks'));
    expect(text, isNot(contains('Einladelink')));
    expect(text.runes.length, lessThanOrEqualTo(500));
  });

  test('Die geprüften Dateien gibt es', () {
    for (final f in _en) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
  });
}
