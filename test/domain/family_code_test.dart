import 'package:family_nexus/domain/family_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Familien-Code ist eine Raum-ID mit Server', () {
    expect(FamilyCode.parse('!abcDEF:matrix.org'), '!abcDEF:matrix.org');
    expect(FamilyCode.parse('  !abc:matrix.org\n'), '!abc:matrix.org', reason: 'Leerraum aus Mail/Zwischenablage');
    expect(FamilyCode.parse('!abc:example.org:8448'), '!abc:example.org:8448');
    expect(FamilyCode.serverOf('!abc:example.org:8448'), 'example.org:8448');
  });

  test('alles andere wird abgelehnt', () {
    for (final bad in <String>['', 'hallo', '#alias:matrix.org', '@anna:matrix.org', '!abc', '!abc:', '!abc:ex ample.org', '!abc:https://evil.test/x', 'familynexus://join?v=3']) {
      expect(FamilyCode.parse(bad), isNull, reason: bad);
    }
  });
}
