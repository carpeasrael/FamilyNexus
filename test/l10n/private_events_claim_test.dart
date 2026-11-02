import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #143: Private Termine werden über einen verschlüsselten privaten Raum zwischen den eigenen Geräten abgeglichen
/// (E-09). Kein Text darf versprechen, sie blieben nur auf dem Gerät.
const _forbidden = <String>[
  'verlassen nie',
  'never leave',
  'bleiben auf deinen eigenen Geräten',
  'stay on your own devices',
  'Nur auf deinen eigenen Geräten',
  'Only on your own devices',
  'own devices only',
  'Stored locally only',
  'never sent to Matrix',
];

const _files = <String>[
  'lib/l10n/app_de.arb',
  'lib/l10n/app_en.arb',
  'store/metadata/ios/de-DE/description.txt',
  'store/metadata/ios/en-US/description.txt',
  'store/metadata/macos/de-DE/description.txt',
  'store/metadata/macos/en-US/description.txt',
  'store/metadata/android/de-DE/full_description.txt',
  'store/metadata/android/en-US/full_description.txt',
  'README.md',
  'Concept.md',
];

void main() {
  for (final f in _files) {
    test('$f: keine Zusage „nur auf dem Gerät“ für private Termine', () {
      final text = File(f).readAsStringSync();
      for (final phrase in _forbidden) {
        expect(text.contains(phrase), isFalse, reason: '„$phrase“ in $f');
      }
    });
  }

  for (final lang in ['de', 'en']) {
    test('app_$lang.arb: Willkommen und Termin-Editor nennen die Verschlüsselung', () {
      final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      final word = lang == 'de' ? 'verschlüsselt' : 'encrypted';
      expect(arb['onbPoint3'] as String, contains(word));
      expect(arb['visibilityPrivateHint'] as String, contains(word));
    });
  }
}
