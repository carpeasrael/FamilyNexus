import 'package:family_nexus/domain/username_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TP-REG-02 Vorschlag aus dem Namen: Umlaute, Akzente, Leerzeichen', () {
    expect(UsernameSuggestion.fromName('Anna Müller'), 'anna.mueller');
    expect(UsernameSuggestion.fromName('  Jörg   Groß '), 'joerg.gross');
    expect(UsernameSuggestion.fromName('José-Luis Núñez'), 'jose-luis.nunez');
    expect(UsernameSuggestion.fromName('Łukasz Żółć'), 'lukasz.zolc');
    expect(UsernameSuggestion.fromName('Oma 👵 Hilde'), 'oma.hilde');
  });

  test('kurze, leere und überlange Namen', () {
    expect(UsernameSuggestion.fromName(''), '');
    expect(UsernameSuggestion.fromName('😀'), '');
    expect(UsernameSuggestion.fromName('Al'), 'al.familie');
    final long = UsernameSuggestion.fromName('Maximilian Alexander von und zu Hohenstein-Waldburg');
    expect(long.length, lessThanOrEqualTo(UsernameSuggestion.maxLength));
    expect(UsernameSuggestion.isValid(long), isTrue);
  });

  test('Vorschläge sind immer gültige Benutzernamen', () {
    for (final n in <String>['Anna Müller', 'Ünal Çelik', 'a.b', 'Zoë', '__x__', 'Peter...Pan']) {
      final s = UsernameSuggestion.fromName(n);
      if (s.isNotEmpty) expect(UsernameSuggestion.isValid(s), isTrue, reason: '$n → $s');
    }
  });

  test('Prüfung: nur a-z 0-9 . _ - und 3 bis 32 Zeichen, kein Punkt am Rand', () {
    expect(UsernameSuggestion.isValid('anna'), isTrue);
    expect(UsernameSuggestion.isValid('an'), isFalse);
    expect(UsernameSuggestion.isValid('Anna'), isFalse);
    expect(UsernameSuggestion.isValid('anna müller'), isFalse);
    expect(UsernameSuggestion.isValid('.anna'), isFalse);
    expect(UsernameSuggestion.isValid('anna.'), isFalse);
    expect(UsernameSuggestion.isValid('a' * 33), isFalse);
    expect(UsernameSuggestion.isValid('@anna:server'), isFalse);
  });

  test('TP-REG-03 Ausweichvorschläge: stabil, gültig, ohne Doppelte', () {
    expect(UsernameSuggestion.alternatives('anna'), <String>['anna2', 'anna.familie', 'anna3', 'anna4']);
    final long = UsernameSuggestion.alternatives('a' * 32);
    expect(long.every(UsernameSuggestion.isValid), isTrue);
    expect(long.every((s) => s.length <= 32), isTrue);
    expect(UsernameSuggestion.alternatives(''), isEmpty);
  });
}
