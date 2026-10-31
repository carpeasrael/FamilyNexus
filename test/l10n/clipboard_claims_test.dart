import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #148: Die App sagt das Leeren der Zwischenablage nicht fest zu (SA-8): Ohne Rückkehr in die App
/// bleibt der Schlüssel unter Android, Linux und Windows liegen.
void main() {
  Map<String, dynamic> arb(String lang) =>
      json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

  final promise = RegExp(
    r'Zwischenablage wird nach einer Minute geleert|clipboard is cleared after one minute',
    caseSensitive: false,
  );

  for (final (lang, tries) in [('de', 'versucht'), ('en', 'tries')]) {
    for (final key in ['keyCopied', 'privacy7Body']) {
      test('$lang/$key: „$tries“ statt fester Zusage', () {
        final text = arb(lang)[key] as String;
        expect(promise.hasMatch(text), isFalse, reason: 'feste Zusage: $text');
        expect(text, contains(tries));
      });
    }
  }
}
