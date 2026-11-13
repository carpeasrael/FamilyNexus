import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// #422: der Hash der Personenfarbe wurde aus `colorIndexFor` herausgezogen; das Verhalten bleibt gleich.
int _reference(String id) => id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff) % 8;

void main() {
  test('personColorFallback: gleicher Index wie die frühere Formel, stabil und im Bereich', () {
    expect(AuroraTokens.personColors, hasLength(8));
    for (final id in <String>['@anna:hs.example', '@ben:hs.example', '@a:b', '', '@sehr-lang-${'x' * 200}:hs.example']) {
      final i = AuroraTokens.personColorFallback(id);
      expect(i, _reference(id), reason: id);
      expect(i, inInclusiveRange(0, AuroraTokens.personColors.length - 1));
      expect(AuroraTokens.personColorFallback(id), i);
    }
  });
}
