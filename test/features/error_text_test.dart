import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_service.dart';
import 'package:family_nexus/features/common/error_text.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// E-104: Abbildung der Fehler der Geburts- und Gedenktage auf Nutzertexte (de und en).
void main() {
  final cases = <(AppLocalizations, AnniversaryError, String)>[
    (AppLocalizationsDe(), AnniversaryError.invalid, 'Bitte Name (höchstens ${AnniversaryPerson.maxName} Zeichen) und gültige Daten angeben.'),
    (AppLocalizationsDe(), AnniversaryError.limit, 'Es sind höchstens ${AnniversaryPerson.maxActive} Personen möglich.'),
    (AppLocalizationsEn(), AnniversaryError.invalid, 'Please enter a name (at most ${AnniversaryPerson.maxName} characters) and valid dates.'),
    (AppLocalizationsEn(), AnniversaryError.limit, 'At most ${AnniversaryPerson.maxActive} people are possible.'),
  ];
  for (final (l, e, text) in cases) {
    test('${l.localeName}: ${e.name}', () => expect(errorText(l, AnniversaryException(e)), text));
  }
  test('notFound nutzt den allgemeinen Text (de und en)', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    expect(errorText(de, const AnniversaryException(AnniversaryError.notFound)), de.errNotFound);
    expect(errorText(en, const AnniversaryException(AnniversaryError.notFound)), en.errNotFound);
  });
}
