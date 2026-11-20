import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// #558: Testplan 1.56 folgt Build 1.2.3 (31) und den Entscheidungen zu #552, #553 und #557.
/// Der Test prüft je Korrektur die neue und die alte Aussage in der betroffenen Zeile.
final String _plan = readNormalized('User E2E Test/Testplan_FamilyNexus.md');
final String _decisions = readNormalized('docs/ENTSCHEIDUNGEN.md');

/// Tabellenzeile des Schritts [id], z. B. `| A-09 | G1 | …`.
String _row(String id) {
  final line = _plan.split('\n').firstWhere((l) => l.startsWith('| $id |'), orElse: () => '');
  expect(line, isNotEmpty, reason: 'Zeile $id fehlt im Testplan');
  return line;
}

void main() {
  test('Planversion 1.56 mit Historie und P-104', () {
    expect(_plan, contains('**Planversion: 1.56**'));
    expect(_plan, contains('| 1.56 |'));
    expect(_plan, contains('| P-104 |'));
  });

  test('1 A-09: Schritt 3 von 4, Konto-Formular Schritt 2 von 4', () {
    final r = _row('A-09');
    expect(r, contains('„Schritt 3 von 4“'));
    expect(r, contains('„Schritt 2 von 4“'));
    expect(r, isNot(contains('„Schritt 2 von 3“')));
    expect(r, isNot(contains('„Schritt 1 von 3“')));
  });

  test('2 A-12: dreistufige Einführungstour', () {
    final r = _row('A-12');
    for (final s in ['Dreistufige Einführungstour', 'Kalender', 'Chat', 'Einkauf', 'Schritt 3 von 3', 'nur auf Stufe 1 und 2', 'Los geht’s', 'Heute']) {
      expect(r, contains(s));
    }
  });

  test('3 B-27: „Person anlegen“', () {
    final r = _row('B-27');
    expect(r, contains('„Person anlegen“'));
    expect(r, isNot(contains('„Person hinzufügen“')));
  });

  test('4 Notfall-Schlüssel: H-07 erzeugt KN1c, KN1b wird ungültig', () {
    expect(_row('H-07'), contains('**KN1c**'));
    expect(_row('F-05'), contains('**KN1c**'));
    expect(_row('F-05'), contains('KN1b, falls H-07 nicht gelaufen ist'));
    expect(_row('F-05a'), contains('ersetzt KN1c bzw. KN1b'));
    expect(_row('H-09'), contains('KN1, KN1b, KN1c'));
    expect(_row('C-07'), contains('**KN1b**'));
    expect(_plan, contains('KN1c (N1, H-07)'));
  });

  test('4b H-19 läuft nach H-07 und schaltet mit KN1c frei', () {
    final r = _row('H-19');
    expect(r, contains('mit KN1c freischalten (KN1b, falls H-07 nicht gelaufen ist)'));
    expect(r, isNot(contains('mit KN1b freischalten |')));
  });

  test('4c jede Zeile nach H-07, die KN1b nennt, kennzeichnet es als ungültig oder als Rückfall', () {
    final h07 = _plan.indexOf('| H-07 |');
    final after = _plan.substring(h07).split('\n').where((l) => l.startsWith('| ') && l.contains('KN1b'));
    for (final l in after) {
      final id = l.split('|')[1].trim();
      if (id.startsWith('P-')) continue; // Änderungsverlauf
      expect(l, anyOf(contains('KN1b wird ungültig'), contains('falls H-07 nicht gelaufen'), contains('KN1c bzw. KN1b'), contains('KN1, KN1b, KN1c')),
          reason: 'Zeile $id nennt KN1b nach H-07 ohne Hinweis');
    }
  });

  test('5 B-18 und Android-Gerät: Ausgangslage AN, dann AUS, danach wieder AN', () {
    expect(_row('B-18'), contains('Ausgangslage ist AN (Standard, E-18, #553)'));
    expect(_row('B-18'), contains('an → aus → wieder an'));
    final dev = _plan.split('\n').firstWhere((l) => l.startsWith('| Android-Gerät |'));
    expect(dev, contains('ab Werk an (E-18, #553)'));
    expect(dev, contains('AN, dann AUS, danach wieder AN'));
  });

  test('6 E-32 läuft nach H-01 bis H-17 und H-20, vor F-01', () {
    expect(_row('E-32'), contains('Nach E-31, H-01 bis H-17 und H-20, vor F-01'));
    expect(_plan, contains('E (ohne E-32) → H (H-01 bis H-17 und H-20) → E-32 → F'));
    expect(_plan, isNot(contains('A → B → C → D → E → H (H-01 bis H-17) → F')));
    expect(_plan, contains('H-01 bis H-17 und H-20 laufen **nach E (ohne E-32) und vor E-32 und F**'));
  });

  test('7 F-06: zweites Gerät bei Builds ohne #556', () {
    expect(_row('F-06'), contains('Builds ohne #556 zeigen auf dem anderen Gerät „Anmelden“ ohne diesen Hinweis'));
  });

  test('8 D-02a und E-81: Diagnoseinhalt bleibt deutsch', () {
    expect(_row('D-02a'), contains('bleibt in jeder App-Sprache deutsch'));
    expect(_decisions, contains('Nachtrag (2026-11-18, Issue #552)'));
  });

  test('9 C-04, C-08: Anbieter nach Abmelden wieder matrix.org', () {
    expect(_row('C-04'), contains('Anbieter steht wieder auf matrix.org'));
    expect(_row('C-08'), contains('Anbieter wieder matrix.org'));
    expect(_decisions, contains('Nachtrag (2026-11-18, Issue #557'));
  });

  test('E-18: Nachtrag zu Android-Standard AN', () {
    expect(_decisions, contains('Nachtrag (2026-11-18, Issue #553'));
  });
}
