import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// Release Notes 1.2.2 (#242, #243): Sie versprechen nur, was die App kann, und folgen den Entscheidungen
/// zu älteren App-Versionen (E-40 Nachträge #161, #211; E-86).
const _files = <String>[
  'store/metadata/android/de-DE/release_notes.txt',
  'store/metadata/android/en-US/release_notes.txt',
  'store/metadata/ios/de-DE/release_notes.txt',
  'store/metadata/ios/en-US/release_notes.txt',
  'store/metadata/macos/de-DE/release_notes.txt',
  'store/metadata/macos/en-US/release_notes.txt',
];

bool _isGerman(String f) => f.contains('/de-DE/');

/// Teilsätze: getrennt an `.`, `;`, `:`, `•` und Zeilenumbruch.
List<String> _clauses(String text) =>
    text.split(RegExp(r'[.;:•\n]')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

void main() {
  for (final f in _files) {
    final de = _isGerman(f);
    final text = readNormalized(f);

    test('#242 $f: zusammengesetzte Emojis nicht in Terminen und nicht „überall“', () {
      final negation = de ? 'in Terminen weiterhin nicht' : 'still not in events';
      for (final c in _clauses(text).where((c) => c.toLowerCase().contains('emoji'))) {
        final lower = c.toLowerCase();
        expect(lower.contains('überall') || lower.contains('everywhere'), isFalse, reason: c);
        if (lower.contains('termin') || lower.contains('event')) {
          expect(c, contains(negation), reason: 'Termine sperren ZWJ/ZWNJ (E-33, E-40 Nachtrag #161): $c');
        }
      }
    });

    test('#243 $f: bittet, alle Geräte zu aktualisieren', () {
      expect(text, contains(de ? 'alle Geräte' : 'all devices'));
      expect(text, isNot(contains(de ? 'nur ohne Gruppe' : 'just without a group')));
      if (!f.contains('/android/')) {
        expect(text, contains(de ? 'für alle verloren' : 'lost for everyone'));
      }
    });

    if (f.contains('/android/')) {
      test('$f: höchstens 500 Zeichen (Google Play)', () {
        expect(text.runes.length, lessThanOrEqualTo(500));
      });
    }
  }
}
