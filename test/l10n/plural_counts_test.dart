import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // #326 (D1–D3, E1–E3): Zähltexte brauchen einen Plural, sonst steht „1 erledigte Einträge“.
  test('de: Einkauf entfernen und Anfragen-Label im Singular und Plural', () {
    final l = AppLocalizationsDe();
    expect(l.shoppingClearConfirm(1), '1 erledigten Eintrag für die ganze Familie entfernen?');
    expect(l.shoppingClearConfirm(2), '2 erledigte Einträge für die ganze Familie entfernen?');
    expect(l.shoppingCleared(0), '0 Einträge entfernt');
    expect(l.shoppingCleared(1), '1 Eintrag entfernt');
    expect(l.shoppingCleared(2), '2 Einträge entfernt');
    expect(l.tabFamilyRequests(1), 'Familie – 1 offene Anfrage');
    expect(l.tabFamilyRequests(3), 'Familie – 3 offene Anfragen');
  });

  test('en: shopping clear and requests label in singular and plural', () {
    final l = AppLocalizationsEn();
    expect(l.shoppingClearConfirm(1), 'Remove 1 done item for the whole family?');
    expect(l.shoppingClearConfirm(2), 'Remove 2 done items for the whole family?');
    expect(l.shoppingCleared(0), '0 items removed');
    expect(l.shoppingCleared(1), '1 item removed');
    expect(l.shoppingCleared(2), '2 items removed');
    expect(l.tabFamilyRequests(1), 'Family – 1 open request');
    expect(l.tabFamilyRequests(3), 'Family – 3 open requests');
  });
}
