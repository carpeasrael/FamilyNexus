import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E-104: Geburts- und Gedenktage (Name und Datum, auch Dritter und Verstorbener) liegen Ende-zu-Ende-verschlüsselt
/// im Familienraum. Datenschutztexte, Löschtexte und Store-Angaben nennen die Kategorie; nach der Kontolöschung
/// bleiben die angelegten Einträge für die Familie bestehen. Der Test `private_events_claim_test.dart` prüft nur
/// verbotene Formulierungen, dieser die Pflichtaussagen.
Map<String, dynamic> _arb(String lang) => json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final de = _arb('de');
  final en = _arb('en');

  for (final key in <String>['privacy2Body', 'privacy12Body']) {
    test('$key nennt Geburts- und Gedenktage (de und en)', () {
      expect(de[key], contains('Geburts- und Gedenktage'));
      expect(en[key], contains(key == 'privacy12Body' ? 'Birthdays and memorial days' : 'birthdays and memorial days'));
    });
  }

  test('privacy2Body nennt Name und Datum, auch Dritter und Verstorbener', () {
    expect(de['privacy2Body'], contains('Name und Datum, auch von Dritten und Verstorbenen'));
    expect(en['privacy2Body'], contains('name and date, including third parties and deceased people'));
  });

  test('privacy12Body: Ende-zu-Ende-verschlüsselt im Familienraum', () {
    expect(de['privacy12Body'], contains('Geburts- und Gedenktage'));
    expect(de['privacy12Body'], contains('Ende-zu-Ende-verschlüsselt im Familienraum'));
    expect(en['privacy12Body'], contains('end-to-end encrypted in the family room'));
  });

  test('accountDeleteBody: angelegte Einträge bleiben für die Familie bestehen (de und en)', () {
    expect(de['accountDeleteBody'], contains('Geburts- und Gedenktage, die du angelegt hast, bleiben für die Familie bestehen'));
    expect(en['accountDeleteBody'], contains('Birthdays and memorial days you created remain for the family'));
  });

  test('Datenschutzerklärung de: Datentabelle, Familienraum, Kontolöschung', () {
    final t = _flat(File('store/privacy/privacy-policy.de.md').readAsStringSync());
    expect(t, contains('| Geburts- und Gedenktage (frei gewählter Name'));
    expect(t, contains('auch von Dritten und Verstorbenen'));
    expect(t, contains('sowie Geburts- und Gedenktage sind'));
    expect(t, contains('Geburts- und Gedenktage, die du angelegt hast, bleiben für die Familie bestehen'));
  });

  test('Datenschutzerklärung en: Datentabelle, Familienraum, Kontolöschung', () {
    final t = _flat(File('store/privacy/privacy-policy.en.md').readAsStringSync());
    expect(t, contains('| Birthdays and memorial days (freely chosen name'));
    expect(t, contains('including third parties and deceased people'));
    expect(t, contains('and birthdays and memorial days are'));
    expect(t, contains('Birthdays and memorial days you created remain for the family'));
  });

  test('docs/STORE.md (Datensicherheit) nennt die Kategorie und das Bestehenbleiben', () {
    final t = File('docs/STORE.md').readAsStringSync();
    expect(t, contains('Geburts- und Gedenktage (Name, Datum, auch Dritter und Verstorbener'));
    expect(t, contains('bleiben nach Kontolöschung für die Familie bestehen'));
  });
}
