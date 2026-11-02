import 'package:family_nexus/ui/widgets/length_limit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #221: Längenbegrenzung der Eingabefelder nach Codepunkten bzw. UTF-16-Einheiten.
const String _family = '👨‍👩‍👧‍👦'; // 1 Graphem, 7 Codepunkte, 11 UTF-16-Einheiten

TextEditingValue _at(String text, [int? offset]) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset ?? text.length));

void main() {
  test('Maße zählen Codepunkte und UTF-16-Einheiten', () {
    expect(LengthMeasure.codePoints.of(_family), 7);
    expect(LengthMeasure.utf16.of(_family), 11);
    expect(LengthMeasure.codePoints.of('😀'), 1);
    expect(LengthMeasure.utf16.of('😀'), 2);
    expect(LengthMeasure.codePoints.of('Milch'), 5);
    expect(LengthMeasure.utf16.of(''), 0);
  });

  group('Standard (Android: enforced)', () {
    test('Text unter der Grenze bleibt unverändert', () {
      final f = MeasuredLengthFormatter(30, LengthMeasure.codePoints);
      final v = _at('Aldi$_family');
      expect(f.formatEditUpdate(_at('Aldi'), v), same(v));
    });

    test('24 Buchstaben + Familien-Emoji bei 30 Codepunkten: gekürzt auf die Buchstaben, kein halbes Emoji', () {
      final f = MeasuredLengthFormatter(30, LengthMeasure.codePoints);
      final r = f.formatEditUpdate(_at('a' * 24), _at('${'a' * 24}$_family'));
      expect(r.text, 'a' * 24);
      expect(r.text.contains('‍'), isFalse);
      expect(r.selection, const TextSelection.collapsed(offset: 24));
    });

    test('Familien-Emoji passt genau: 23 Buchstaben + 7 Codepunkte = 30', () {
      final f = MeasuredLengthFormatter(30, LengthMeasure.codePoints);
      final v = _at('${'a' * 23}$_family');
      expect(f.formatEditUpdate(_at('a' * 23), v), same(v));
    });

    test('29 Buchstaben + 😀 bei 30 UTF-16-Einheiten: gekürzt auf 29 Buchstaben', () {
      final f = MeasuredLengthFormatter(30, LengthMeasure.utf16);
      final r = f.formatEditUpdate(_at('a' * 29), _at('${'a' * 29}😀'));
      expect(r.text, 'a' * 29);
    });

    test('Einfügen in der Mitte eines vollen Feldes ändert nichts', () {
      final f = MeasuredLengthFormatter(30, LengthMeasure.codePoints);
      final old = _at('a' * 30, 10);
      final r = f.formatEditUpdate(old, _at('${'a' * 10}b${'a' * 20}', 11));
      expect(r, same(old));
    });

    test('Ersetzen einer Auswahl im vollen Feld kürzt statt abzulehnen', () {
      final f = MeasuredLengthFormatter(10, LengthMeasure.codePoints);
      const old = TextEditingValue(text: 'abcdefghij', selection: TextSelection(baseOffset: 0, extentOffset: 2));
      final r = f.formatEditUpdate(old, _at('XYZ${'cdefghij'}', 3));
      expect(r.text, 'XYZcdefghi');
    });

    test('Auswahl und Komposition liegen nach dem Kürzen im Text', () {
      final f = MeasuredLengthFormatter(5, LengthMeasure.codePoints);
      const v = TextEditingValue(
        text: 'abcd$_family',
        selection: TextSelection(baseOffset: 2, extentOffset: 4 + 11),
        composing: TextRange(start: 3, end: 4 + 11),
      );
      final r = f.formatEditUpdate(_at('abcd'), v);
      expect(r.text, 'abcd');
      expect(r.selection, const TextSelection(baseOffset: 2, extentOffset: 4));
      expect(r.composing, const TextRange(start: 3, end: 4));
    });
  });

  group('IME-Komposition (iOS: truncateAfterCompositionEnds)', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('während der Komposition bleibt der zu lange Text stehen', () {
      final f = MeasuredLengthFormatter(5, LengthMeasure.codePoints);
      const v = TextEditingValue(text: 'abcdかな', selection: TextSelection.collapsed(offset: 6), composing: TextRange(start: 4, end: 6));
      expect(f.formatEditUpdate(_at('abcd'), v), same(v));
    });

    test('nach Ende der Komposition wird gekürzt', () {
      final f = MeasuredLengthFormatter(5, LengthMeasure.codePoints);
      const old = TextEditingValue(text: 'abcdかな', selection: TextSelection.collapsed(offset: 6), composing: TextRange(start: 4, end: 6));
      final r = f.formatEditUpdate(old, _at('abcd仮名'));
      expect(r.text, 'abcd仮');
    });

    test('volles Feld ohne Komposition bleibt beim Weitertippen unverändert', () {
      final f = MeasuredLengthFormatter(5, LengthMeasure.codePoints);
      final old = _at('abcde');
      expect(f.formatEditUpdate(old, _at('abcdef')), same(old));
    });
  });
}
