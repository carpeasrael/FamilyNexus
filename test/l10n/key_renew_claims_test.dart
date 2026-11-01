import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// #149 / E-72: Der alte Notfall-Schlüssel öffnet den Master-Key weiterhin. Die Texte zum
/// Erneuern dürfen daher nicht behaupten, er sei danach allgemein ungültig.
void main() {
  final de = AppLocalizationsDe();
  final en = AppLocalizationsEn();

  test('Erneuern-Texte behaupten keine allgemeine Ungültigkeit des alten Schlüssels', () {
    final texts = <String>[de.keyRenewIntro, de.securityKeyRenewHint, en.keyRenewIntro, en.securityKeyRenewHint]
        .map((s) => s.toLowerCase());
    for (final t in texts) {
      expect(t, isNot(contains('funktioniert danach nicht mehr')));
      expect(t, isNot(contains('gilt danach nicht mehr')));
      expect(t, isNot(contains('stops working')));
    }
  });

  test('Einleitung nennt die Grenze und behält die Anweisung, nur den neuen aufzubewahren', () {
    expect(de.keyRenewIntro, contains('fremde Hände'));
    expect(de.keyRenewIntro, contains('nur noch der neue'));
    expect(en.keyRenewIntro, contains('wrong hands'));
    expect(en.keyRenewIntro, contains('only the new one'));
  });
}
