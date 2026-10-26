import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Texte der App (de/en), Platzhalter wie in den Notizen: `{host}` = matrix.org, `{name}` = `<name>`.
List<String> _appTexts(String lang) {
  final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, Object?>;
  return <String>[
    for (final e in arb.entries)
      if (!e.key.startsWith('@') && e.value is String)
        (e.value! as String).replaceAll('{host}', 'matrix.org').replaceAll('{name}', '<name>'),
  ];
}

/// Beschriftungen außerhalb der App (App Store Connect, Seite des Anbieters).
const Set<String> _external = <String>{'Sign-in information', 'Anmeldeinformationen', 'Continue', 'Weiter'};

void main() {
  // TC-15 (#13): Jede in den Review-Notizen zitierte Beschriftung gibt es in der App so.
  for (final platform in <String>['ios', 'macos']) {
    test('Review-Notizen $platform: zitierte Beschriftungen stehen so in der App', () {
      final notes = File('store/metadata/$platform/review_notes.txt').readAsStringSync();
      final parts = notes.split('[Deutsch]');
      expect(parts, hasLength(2), reason: 'englischer und deutscher Teil');
      for (final (lang, text, quote) in <(String, String, RegExp)>[
        ('en', parts[0], RegExp(r'"([^"]+)"')),
        ('de', parts[1], RegExp('„([^“]+)“')),
      ]) {
        final texts = _appTexts(lang);
        final quoted = quote.allMatches(text).map((m) => m.group(1)!).toSet();
        expect(quoted, isNotEmpty);
        for (final q in quoted.difference(_external)) {
          expect(texts.any((t) => t.contains(q)), isTrue, reason: '„$q“ ($lang) fehlt in der App');
        }
      }
    });

    test('Review-Notizen $platform: keine überholten Aussagen, Grenze von App Store Connect', () {
      final notes = File('store/metadata/$platform/review_notes.txt').readAsStringSync();
      expect(notes, isNot(contains('keine Konten')));
      expect(notes, isNot(contains('Sprache →')));
      expect(notes, contains('Delete account'));
      expect(notes.length, lessThanOrEqualTo(4000));
    });
  }
}
