import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/domain/avatar_photo_processing.dart';
import 'package:family_nexus/domain/avatar_photo_service.dart';
import 'package:family_nexus/features/common/error_text.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// #434, E-111: Pflichtinhalt der Texte zum Avatar-Foto. Das Foto ist Ende-zu-Ende-verschlüsselt, die Preset-Wahl bleibt
/// sichtbarer Klartext; der Server sieht Größe und Zeitpunkt; Schwärzen ist nur nach bestem Bemühen; ausgetretene
/// Mitglieder behalten, was sie haben; alle Mitglieder sehen das Foto; Moderatoren können es ausblenden; bei Kindern
/// sollen Sorgeberechtigte einwilligen; die Kontolöschung entfernt es nicht von selbst.
void main() {
  Map<String, dynamic> arb(String lang) =>
      json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

  final photo = {'de': RegExp('Foto'), 'en': RegExp('photo', caseSensitive: false)};
  final encrypted = {
    'de': RegExp('Ende-zu-Ende-verschlüsselt|verschlüsselt'),
    'en': RegExp('end-to-end encrypted|encrypted'),
  };

  for (final lang in ['de', 'en']) {
    group(lang, () {
      final a = arb(lang);
      String t(String key) => a[key] as String;

      test('serverMetadataNote, privacy3Body, privacy12Body, reportOnlineNote: Foto verschlüsselt, Größe und Zeitpunkt sichtbar', () {
        for (final k in ['serverMetadataNote', 'privacy3Body', 'privacy12Body', 'reportOnlineNote']) {
          expect(photo[lang]!.hasMatch(t(k)), isTrue, reason: '$k nennt das Foto');
          expect(encrypted[lang]!.hasMatch(t(k)), isTrue, reason: '$k nennt die Verschlüsselung');
        }
        final size = {
          'de': RegExp('Größe und Zeitpunkt|Zeitpunkt und Größe'),
          'en': RegExp('size and time|time and size'),
        };
        for (final k in ['serverMetadataNote', 'privacy3Body', 'privacy12Body', 'reportOnlineNote']) {
          expect(size[lang]!.hasMatch(t(k)), isTrue, reason: '$k: Größe und Zeitpunkt');
        }
      });

      test('die Preset-Wahl bleibt als nicht verschlüsselter Raumzustand benannt (E-101)', () {
        final notE2ee = {'de': 'nicht Ende-zu-Ende-verschlüsselt', 'en': 'not end-to-end encrypted'};
        for (final k in ['serverMetadataNote', 'privacy3Body', 'privacy10Body', 'privacy12Body']) {
          expect(t(k), contains(notE2ee[lang]!), reason: k);
        }
      });

      test('privacy10Body: alle sehen es, Moderatoren, Schwärzen nach bestem Bemühen, Ausgetretene, Kinder', () {
        final body = t('privacy10Body');
        final needles = {
          'de': [
            'Alle Familienmitglieder sehen es',
            'Moderatoren können es aus der Anzeige nehmen',
            'nach bestem Bemühen',
            'auch ausgetretene Mitglieder',
            'Sorgeberechtigte einwilligen',
          ],
          'en': [
            'all family members see it',
            'Moderators can take it out of the display',
            'best-effort',
            'including members who have left',
            'parents or guardians should consent',
          ],
        };
        for (final n in needles[lang]!) {
          expect(body, contains(n), reason: n);
        }
      });

      test('privacy2Body nennt das Foto als Datenart', () {
        expect(photo[lang]!.hasMatch(t('privacy2Body')), isTrue);
      });

      test('accountDeleteBody: das Foto bleibt verschlüsselt im Verlauf, vorher entfernen; der Weg heißt „Foto zuerst entfernen“', () {
        final body = t('accountDeleteBody');
        expect(photo[lang]!.hasMatch(body), isTrue);
        expect(body, contains(lang == 'de' ? 'entferne es vorher' : 'remove it beforehand'));
        expect(t('accountDeleteRemovePhoto'), lang == 'de' ? 'Foto zuerst entfernen' : 'Remove photo first');
      });

      test(
        'Pflicht-Hinweis vor der Auswahl: alle sehen es, Server sieht Chiffretext, Moderatoren, Sorgeberechtigte',
        () {
          final body = t('avatarPhotoNoticeBody');
          final needles = {
            'de': [
              'Alle Familienmitglieder sehen dieses Foto',
              'Ende-zu-Ende-verschlüsselt',
              'Größe und Zeitpunkt',
              'Moderatoren',
              'Sorgeberechtigte einwilligen',
            ],
            'en': [
              'All family members see this photo',
              'end-to-end encrypted',
              'size and time',
              'Moderators',
              'parents or guardians should consent',
            ],
          };
          for (final n in needles[lang]!) {
            expect(body, contains(n), reason: n);
          }
        },
      );
    });
  }

  test(
    'Fehlertexte: jede Art der Bildaufbereitung und des Fotodienstes hat ihren eigenen, richtigen Text (de und en)',
    () {
      for (final (l, ctx) in <(AppLocalizations, String)>[(AppLocalizationsDe(), 'de'), (AppLocalizationsEn(), 'en')]) {
        final expected = <AvatarPhotoProcessingError, String>{
          AvatarPhotoProcessingError.unsupportedFormat: l.avatarPhotoErrFormat,
          AvatarPhotoProcessingError.tooLarge: l.avatarPhotoErrTooLarge,
          AvatarPhotoProcessingError.tooManyPixels: l.avatarPhotoErrPixels,
          AvatarPhotoProcessingError.notDecodable: l.avatarPhotoErrDecode,
          AvatarPhotoProcessingError.cannotShrink: l.avatarPhotoErrShrink,
        };
        for (final e in AvatarPhotoProcessingError.values) {
          expect(errorText(l, AvatarPhotoProcessingException(e)), expected[e], reason: '$ctx ${e.name}');
        }
        expect(expected.values.toSet(), hasLength(expected.length), reason: '$ctx: fünf verschiedene Texte');
        expect(errorText(l, const AvatarPhotoException(AvatarPhotoError.clock)), l.avatarPhotoErrClock, reason: ctx);
        expect(errorText(l, const AvatarPhotoException(AvatarPhotoError.notAllowed)), l.errNotAllowed, reason: ctx);
        expect(errorText(l, const AvatarPhotoException(AvatarPhotoError.invalid)), l.errInvalidInput, reason: ctx);
      }
    },
  );

  test('Store-Angaben und Dokumente nennen das Avatar-Foto verschlüsselt und mit Größe und Zeitpunkt (E-111)', () {
    for (final (file, needles) in <(String, List<String>)>[
      (
        'docs/STORE.md',
        [
          'Avatar-Foto (freiwillig gewählt',
          'Ende-zu-Ende-verschlüsselt als Ereignis',
          'nur Größe und Zeitpunkt',
          'Foto zuerst entfernen',
        ],
      ),
      ('docs/EIGENER_SERVER.md', ['Avatar-Foto', 'Ende-zu-Ende-verschlüsselt', 'Größe und Zeitpunkt']),
      ('Concept.md', ['an avatar photo is encrypted like all content']),
      ('docs/export-compliance/encryption-description-en.md', ['avatar photo', 'Megolm-encrypted room event']),
      ('docs/export-compliance/description-chiffrement-fr.md', ["photo d'avatar", 'chiffré avec Megolm']),
    ]) {
      final text = File(file).readAsStringSync();
      for (final n in needles) {
        expect(text, contains(n), reason: '$file: $n');
      }
    }
  });

  test('Store-Datenschutzerklärungen: Foto als Datenart, Ende-zu-Ende, Größe und Zeitpunkt, Kontolöschung, Schwärzen nach bestem Bemühen', () {
    for (final (file, needles) in <(String, List<String>)>[
      (
        'store/privacy/privacy-policy.de.md',
        [
          'Avatar-Foto (optional',
          'Ende-zu-Ende-verschlüsselt als Ereignis',
          'nur Größe und Zeitpunkt',
          'Foto zuerst entfernen',
          'nur nach bestem Bemühen geschwärzt',
          'Sorgeberechtigte einwilligen',
        ],
      ),
      (
        'store/privacy/privacy-policy.en.md',
        [
          'Avatar photo (optional',
          'end-to-end encrypted as an event',
          'only sees size and time',
          'Remove photo first',
          'best-effort basis',
          'parents or guardians should consent',
        ],
      ),
    ]) {
      final text = File(file).readAsStringSync();
      for (final n in needles) {
        expect(text, contains(n), reason: '$file: $n');
      }
    }
  });
}
