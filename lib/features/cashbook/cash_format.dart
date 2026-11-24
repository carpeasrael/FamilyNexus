import 'package:intl/intl.dart';

import '../../domain/cash_amount.dart';
import '../calendar/formatting.dart';

/// Formatieren und Einlesen von Beträgen, Daten und Währungen im Kassenbuch (#311, E-113), nach dem Gebietsschema.
/// Beträge sind immer Cent (zwei Nachkommastellen); Summen werden nie über Währungen addiert.
class CashFormat {
  const CashFormat._();

  /// Feste Auswahl beim Anlegen (E-113); die Währung des Gebietsschemas kommt dazu.
  static const List<String> currencies = <String>['EUR', 'USD', 'CHF', 'GBP', 'PLN', 'CZK', 'DKK', 'SEK', 'NOK', 'HUF', 'TRY'];

  /// Währung des Gebietsschemas (ISO-4217) oder [fallback].
  static String localeCurrency(String locale, {String fallback = 'EUR'}) {
    try {
      final name = NumberFormat.simpleCurrency(locale: locale).currencyName;
      if (name != null && RegExp(r'^[A-Z]{3}$').hasMatch(name)) return name;
    } catch (_) {
      // Unbekanntes Gebietsschema: der Rückfall gilt.
    }
    return fallback;
  }

  /// Auswahl für das Anlegen: die feste Liste, die Gebietsschema-Währung vorangestellt, wenn sie fehlt.
  static List<String> choices(String locale) {
    final local = localeCurrency(locale);
    return <String>[if (!currencies.contains(local)) local, ...currencies];
  }

  /// „12,50 €“ im Gebietsschema; jede gültige ISO-Währung wird angezeigt (unbekannte mit ihrem Kürzel), immer zwei
  /// Nachkommastellen, weil das Kassenbuch in Cent rechnet.
  static String money(String locale, int cents, String currency) {
    try {
      return NumberFormat.simpleCurrency(locale: locale, name: currency, decimalDigits: 2).format(cents / 100);
    } catch (_) {
      // Unbekannte Währung oder Gebietsschema: Kürzel und Zahl.
      return '$currency ${NumberFormat.decimalPatternDigits(locale: 'en', decimalDigits: 2).format(cents / 100)}';
    }
  }

  /// Betrag der Eingabe in Cent oder `null` (Dezimal- und Gruppentrenner des Gebietsschemas).
  static int? parseAmount(String locale, String input) {
    final s = NumberFormat.decimalPattern(locale).symbols;
    return CashAmount.parse(input, decimalSeparator: s.DECIMAL_SEP, groupSeparator: s.GROUP_SEP);
  }

  /// Betrag als Eingabetext im Gebietsschema („12,50“), für das Bearbeiten.
  static String amountText(String locale, int cents) =>
      NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2).format(cents / 100).replaceAll(NumberFormat.decimalPattern(locale).symbols.GROUP_SEP, '');

  /// Numerisches Datum über die eine Stelle der App (E-20: Tag und Monat zweistellig).
  static String date(String locale, DateTime day) => formatDateNumeric(day, locale);

  static String month(String locale, DateTime firstOfMonth) => DateFormat.yMMMM(locale).format(firstOfMonth);
}
