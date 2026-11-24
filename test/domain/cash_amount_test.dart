import 'package:family_nexus/domain/cash_amount.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:flutter_test/flutter_test.dart';

/// #311, E-113 (Teil 4): Betragseingabe in Cent, gebietsschema-sensitiv.
void main() {
  int? de(String s) => CashAmount.parse(s, decimalSeparator: ',', groupSeparator: '.');
  int? en(String s) => CashAmount.parse(s, decimalSeparator: '.', groupSeparator: ',');

  test('deutsche Eingaben', () {
    expect(de('12,50'), 1250);
    expect(de('12,5'), 1250);
    expect(de('12'), 1200);
    expect(de('0,99'), 99);
    expect(de('0,01'), 1);
    expect(de('1.250,50'), 125050);
    expect(de('1.250'), 125000, reason: 'Punkt ist hier der Tausendertrenner');
    expect(de(' 7,00 '), 700);
    expect(de('1\u00A0250,50'), isNull, reason: 'Im deutschen Format ist der Punkt die Gruppe; ein Leerzeichen im Inneren gilt nicht');
  });

  test('englische Eingaben', () {
    expect(en('12.50'), 1250);
    expect(en('1,250.50'), 125050);
    expect(en('1,250'), 125000);
    expect(en('12'), 1200);
  });

  test('ungültig: leer, Text, Vorzeichen, Exponent, mehrere Trenner, zu viele Nachkommastellen', () {
    for (final s in <String>['', ' ', 'abc', '-5', '+5', '1e3', '1,2,3', '12,345', '12,', ',50', '1..000', '12,5x', '0', '0,00', '€5', '5€']) {
      expect(de(s), isNull, reason: '"$s"');
    }
  });

  test('Gruppentrenner nur in gültiger Stellung', () {
    expect(de('1.25'), isNull, reason: 'Gruppe mit zwei Ziffern');
    expect(de('1234.567'), isNull, reason: 'erste Gruppe über drei Ziffern');
    expect(de('.123'), isNull);
    expect(de('1.2345'), isNull);
    expect(de('123.456'), 12345600);
    expect(de('12.345.678'), isNull, reason: 'gültig gruppiert, aber über dem Höchstbetrag');
  });

  test('Grenzen: höchstens 999 999,99, größerer Betrag ungültig, sehr lange Eingabe ungültig', () {
    expect(de('999.999,99'), CashBookLimits.maxAmountCents);
    expect(de('1.000.000,00'), isNull);
    expect(de('99999999999999999999,99'), isNull);
    expect(de('1' * 30), isNull);
  });

  test('gleiche Trenner für Dezimal und Gruppe: keine Gruppierung', () {
    expect(CashAmount.parse('1.250', decimalSeparator: '.', groupSeparator: '.'), isNull);
    expect(CashAmount.parse('12.5', decimalSeparator: '.', groupSeparator: '.'), 1250);
  });

  test('Leerzeichen: am Rand egal, im Inneren nur als Gruppentrenner (sonst wäre „12 50“ ein Betrag von 1250)', () {
    expect(de('12 50'), isNull);
    expect(de('1 250,50'), isNull, reason: 'Punkt ist hier der Gruppentrenner, Leerzeichen nicht');
    expect(de('\t7,00\n'), 700);
    int? fr(String s) => CashAmount.parse(s, decimalSeparator: ',', groupSeparator: '\u202F');
    expect(fr('1 250,50'), 125050, reason: 'gewöhnliches Leerzeichen als Gruppe im Format mit Leerzeichen-Trenner');
    expect(fr('1\u202F250,50'), 125050);
    expect(fr('12 5 0'), isNull);
  });

  test('Schweizer Format: Apostroph als Gruppentrenner', () {
    expect(CashAmount.parse("1'250.50", decimalSeparator: '.', groupSeparator: "'"), 125050);
  });
}
