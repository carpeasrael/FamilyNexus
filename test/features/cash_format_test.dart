import 'dart:io';

import 'package:family_nexus/features/cashbook/cash_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// #311, E-113 (Teil 4a-2): Formate des Kassenbuchs und Wächter für die Bildanzeige.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  test('Beträge im Gebietsschema, immer zwei Nachkommastellen, mit Währungszeichen', () {
    expect(CashFormat.money('de', 1250, 'EUR'), '12,50 €');
    expect(CashFormat.money('en', 1250, 'USD'), r'$12.50');
    expect(CashFormat.money('de', 5, 'EUR'), '0,05 €');
    expect(CashFormat.money('de', 99999999, 'EUR'), '999.999,99 €');
    expect(CashFormat.money('de', 100, 'JPY'), contains('1,00'), reason: 'zwei Nachkommastellen auch bei Währungen ohne Cent');
  });

  test('eine unbekannte, aber gültige Währung wird mit ihrem Kürzel angezeigt, nie mit einer Ausnahme', () {
    expect(() => CashFormat.money('de', 1250, 'XTS'), returnsNormally);
    expect(CashFormat.money('de', 1250, 'XTS'), contains('XTS'));
    expect(() => CashFormat.money('xx-unbekannt', 1250, 'EUR'), returnsNormally);
  });

  test('Eingabe: deutsch und englisch, mit Tausendertrenner, Ungültiges null', () {
    expect(CashFormat.parseAmount('de', '12,50'), 1250);
    expect(CashFormat.parseAmount('de', '1.250,50'), 125050);
    expect(CashFormat.parseAmount('en', '12.50'), 1250);
    expect(CashFormat.parseAmount('en', '1,250.50'), 125050);
    expect(CashFormat.parseAmount('de', 'abc'), isNull);
    expect(CashFormat.parseAmount('de', '12 50'), isNull);
  });

  test('Betrag als Eingabetext: ohne Tausendertrenner, rundlaufend mit parseAmount', () {
    expect(CashFormat.amountText('de', 125050), '1250,50');
    expect(CashFormat.amountText('en', 125050), '1250.50');
    for (final cents in <int>[1, 99, 100, 1250, 125050, 99999999]) {
      for (final l in <String>['de', 'en']) {
        expect(CashFormat.parseAmount(l, CashFormat.amountText(l, cents)), cents, reason: '$l $cents');
      }
    }
  });

  test('Währungsauswahl: feste Liste, die Währung des Gebietsschemas vorn, wenn sie fehlt; Vorgabe aus dem Gebietsschema', () {
    expect(CashFormat.localeCurrency('de'), 'EUR');
    expect(CashFormat.localeCurrency('en'), 'USD');
    expect(CashFormat.choices('de'), CashFormat.currencies);
    expect(CashFormat.choices('ja').first, 'JPY');
    expect(CashFormat.choices('ja').skip(1), CashFormat.currencies);
    expect(CashFormat.localeCurrency('xx-unbekannt'), isA<String>());
  });

  test('Datum numerisch mit zweistelligem Tag und Monat (E-20)', () {
    expect(CashFormat.date('de', DateTime.utc(2026, 11, 3)), '03.11.2026');
    expect(CashFormat.date('en', DateTime.utc(2026, 11, 3)), '11/03/2026');
    expect(CashFormat.month('de', DateTime(2026, 11)), 'November 2026');
  });

  test('Wächter: die Bildschirme des Kassenbuchs zeichnen Bons nie über Image.memory, Image.file, Image.network oder einen nativen Decoder', () {
    final bad = RegExp(r'Image\.(memory|file|network|asset)\(|decodeImageFromList|instantiateImageCodec|MemoryImage|FileImage|NetworkImage');
    final files = Directory('lib/features/cashbook').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(bad.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
    final picture = File('lib/features/cashbook/cash_receipt_picture.dart').readAsStringSync();
    expect(picture, contains('RawImage'), reason: 'das Bild entsteht aus Rohpixeln');
    expect(picture, contains('decodeImageFromPixels'));
  });
}
