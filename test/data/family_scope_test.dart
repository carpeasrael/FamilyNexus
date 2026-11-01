import 'package:family_nexus/data/matrix/family_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// #140: Zu welchem Familienraum die Zustände des Gateways gehören.
void main() {
  test('enter meldet nur Änderungen und zählt nur dann die Generation', () {
    final s = FamilyScope();
    expect(s.roomId, isNull);
    expect(s.generation, 0);
    expect(s.enter(null), isFalse, reason: 'weiterhin keine Familie');
    expect(s.generation, 0);
    expect(s.enter('!a:x'), isTrue);
    expect(s.roomId, '!a:x');
    expect(s.generation, 1);
    expect(s.enter('!a:x'), isFalse);
    expect(s.generation, 1);
  });

  test('direkter Wechsel und Wechsel über „keine Familie“ gelten beide als Änderung', () {
    final s = FamilyScope()..enter('!a:x');
    expect(s.enter('!b:x'), isTrue);
    expect(s.enter(null), isTrue);
    expect(s.enter('!b:x'), isTrue);
    expect(s.generation, 4);
  });

  test('clear setzt den Raum zurück, die Generation zählt weiter und fällt nie zurück', () {
    final s = FamilyScope()..enter('!a:x');
    s.clear();
    expect(s.roomId, isNull);
    expect(s.generation, 2);
    s.clear();
    expect(s.generation, 3, reason: 'auch ohne Raum: Verspätetes aus der Sitzung davor gilt nicht');
    expect(s.enter('!a:x'), isTrue);
    expect(s.generation, 4, reason: 'A → abgemeldet → A: nie dieselbe Generation wie zuvor');
  });
}
