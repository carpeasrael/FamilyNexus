import 'package:family_nexus/data/matrix/matrix_gateway.dart' show GatewayError, GatewayException;
import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_service.dart';
import 'package:family_nexus/domain/contact_service.dart';
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

  test('peerNotReachable (#119, K3a-2b): eigener Text, de und en, nie der allgemeine', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    const e = GatewayException(GatewayError.peerNotReachable);
    expect(errorText(de, e), 'Diese Person muss in ihrer App die Sicherheitsprüfung einrichten, bevor ihr euch schreiben könnt.');
    expect(errorText(en, e), 'This person needs to set up the security check in their app before you can message each other.');
    expect(errorText(de, e), isNot(de.errUnknown));
    expect(errorText(en, e), isNot(en.errUnknown));
  });

  test('groupNoOtherMembers und groupBusy (#119, K4-2b): eigene Texte, de und en, nie der allgemeine, nie der Servertext', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    const none = GatewayException(GatewayError.groupNoOtherMembers);
    const busy = GatewayException(GatewayError.groupBusy);
    expect(errorText(de, none), 'In dieser Gruppe ist noch niemand. Lade zuerst jemanden ein.');
    expect(errorText(en, none), 'Nobody else is in this group yet. Invite someone first.');
    expect(errorText(de, busy), 'Die Gruppe wird gerade aktualisiert. Bitte warte einen Moment.');
    expect(errorText(en, busy), 'The group is being updated. Please wait a moment.');
    for (final e in <GatewayException>[none, busy]) {
      for (final l in <AppLocalizations>[de, en]) {
        expect(errorText(l, e), isNot(l.errUnknown));
        expect(errorText(l, e), isNot(l.errServerUnreachable));
        expect(errorText(l, e), isNot(l.errPeerNotReachable));
      }
    }
  });

  test('ContactException (#119, K3b-1): jeder Fall hat seinen eigenen Text, de und en', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    final expectedDe = <ContactError, String>{
      ContactError.invalid: 'Die Angabe ist ungültig.',
      ContactError.notAllowed: 'Das ist nicht erlaubt.',
      ContactError.notFound: 'Der Kontakt wurde nicht gefunden.',
      ContactError.limit: 'Die Grenze für Kontakte ist erreicht.',
      ContactError.duplicate: 'Diese Person ist schon in deiner Liste.',
    };
    final expectedEn = <ContactError, String>{
      ContactError.invalid: 'The entry is invalid.',
      ContactError.notAllowed: 'This is not allowed.',
      ContactError.notFound: 'The contact was not found.',
      ContactError.limit: 'The limit for contacts has been reached.',
      ContactError.duplicate: 'This person is already in your list.',
    };
    for (final e in ContactError.values) {
      expect(errorText(de, ContactException(e)), expectedDe[e], reason: 'de ${e.name}');
      expect(errorText(en, ContactException(e)), expectedEn[e], reason: 'en ${e.name}');
    }
  });
}
