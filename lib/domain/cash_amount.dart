import 'cash_book.dart';

/// Eingabe eines Betrags (#311, E-113): Text in Cent, gebietsschema-sensitiv. Reine Rechnung ohne Oberfläche.
class CashAmount {
  const CashAmount._();

  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _ws = RegExp(r'[\s  ]');

  /// Betrag in Cent oder `null` bei Ungültigem. Erlaubt sind: Ziffern, höchstens ein [decimalSeparator] mit **1 oder 2**
  /// Nachkommastellen (mindestens eine Ziffer davor) und [groupSeparator] nur in gültiger Stellung (Gruppen zu je drei
  /// Ziffern, erste Gruppe 1 bis 3). Leerzeichen jeder Art werden entfernt. Kein Vorzeichen, kein Exponent, nicht null,
  /// höchstens [CashBookLimits.maxAmountCents] (Pfand und Erstattungen sind ausgeschlossen).
  static int? parse(String input, {required String decimalSeparator, required String groupSeparator}) {
    final text = input.replaceAll(_ws, '');
    if (text.isEmpty || text.length > 20) return null;
    final groups = groupSeparator.isNotEmpty && groupSeparator != decimalSeparator;
    final parts = text.split(decimalSeparator);
    if (parts.length > 2) return null;
    var whole = parts.first;
    final fraction = parts.length == 2 ? parts[1] : '';
    if (parts.length == 2 && (fraction.isEmpty || fraction.length > 2 || !_digits.hasMatch(fraction))) return null;
    if (groups && whole.contains(groupSeparator)) {
      final chunks = whole.split(groupSeparator);
      final first = chunks.first;
      if (first.isEmpty || first.length > 3 || chunks.skip(1).any((c) => c.length != 3)) return null;
      whole = chunks.join();
    }
    if (whole.isEmpty || !_digits.hasMatch(whole) || whole.length > 10) return null;
    final cents = int.parse(whole) * 100 + (fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0')));
    if (cents < 1 || cents > CashBookLimits.maxAmountCents) return null;
    return cents;
  }
}
