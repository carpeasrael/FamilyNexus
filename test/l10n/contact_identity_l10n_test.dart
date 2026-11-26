import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #119, K3b-2b: Die Texte zur Identität von Kontakten gibt es in de und en und nennen nie die Familie (Kontakte sind
/// außerhalb der Familie; nur „Außerhalb der Familie“ im Banner ist ausgenommen).
void main() {
  const keys = <String>[
    'contactIdentityVerified',
    'contactIdentityPinned',
    'contactIdentityUnknown',
    'contactIdentityChangedBanner',
    'contactIdentityChangedComposer',
    'contactVerifyAction',
    'contactAcceptChangeAction',
    'contactAcceptChangeConfirm',
    'contactSendBlockedChanged',
    'contactAcceptChangeFailed',
  ];
  Map<String, Object?> arb(String l) => json.decode(File('lib/l10n/app_$l.arb').readAsStringSync()) as Map<String, Object?>;

  test('alle Schlüssel in de und en, nicht leer, ohne Familienbegriff', () {
    for (final l in <String>['de', 'en']) {
      final m = arb(l);
      for (final k in keys) {
        final v = m[k];
        expect(v, isA<String>(), reason: '$l/$k');
        expect((v! as String).trim(), isNotEmpty, reason: '$l/$k');
        expect(RegExp(r'famil', caseSensitive: false).hasMatch(v as String), isFalse, reason: '$l/$k: $v');
      }
    }
  });

  test('Platzhalter {name} im Banner in beiden Sprachen', () {
    for (final l in <String>['de', 'en']) {
      expect((arb(l)['contactIdentityChangedBanner']! as String).contains('{name}'), isTrue, reason: l);
    }
  });
}
