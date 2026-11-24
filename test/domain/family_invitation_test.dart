import 'package:family_nexus/domain/family_invitation.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K1, B1: nur `knock` (oder fehlende Angabe, nur zur Anzeige) ohne Einzelchat und Buch ist eine Familieneinladung.
void main() {
  bool f({String? rule, bool direct = false, bool book = false}) => isFamilyInvitation(joinRule: rule, isDirect: direct, isBook: book);

  test('knock und fehlende Angabe gelten, jede andere Regel nicht', () {
    expect(f(rule: 'knock'), isTrue);
    expect(f(), isTrue);
    for (final r in <String>['invite', 'public', 'restricted', 'knock_restricted', 'private', '']) {
      expect(f(rule: r), isFalse, reason: r);
    }
  });

  test('Einzelchat und Buch gehen vor, auch mit knock', () {
    expect(f(rule: 'knock', direct: true), isFalse);
    expect(f(rule: 'knock', book: true), isFalse);
    expect(f(direct: true), isFalse);
    expect(f(book: true), isFalse);
  });

  test('die Konstante ist die Regel der Familienräume', () {
    expect(knockJoinRule, 'knock');
  });
}
