import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #146: Die Texte der App und der englischen Datenschutzerklärung versprechen nicht, ein eigener Server
/// „vermeide“ Metadaten oder der Server sehe „nur verschlüsselte Ereignisse“. Raum- und Profilnamen
/// (u. a. der Familienname) gehen im Klartext zum Server; ein eigener Server bestimmt, wer sie sieht.
void main() {
  Map<String, dynamic> arb(String lang) =>
      json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

  final names = {
    'de': RegExp('Raum- und Profilnamen|Raumnamen'),
    'en': RegExp('room and profile names|room names'),
  };
  final avoid = {
    'de': RegExp('vermeiden', caseSensitive: false),
    'en': RegExp('to avoid|avoid that', caseSensitive: false),
  };
  final onlyEncrypted = {
    'de': RegExp('nur verschlüsselte Ereignisse', caseSensitive: false),
    'en': RegExp('only sees encrypted events', caseSensitive: false),
  };
  final onlyMetadata = {
    'de': RegExp('nur Metadaten wie Zeitpunkte und Größe', caseSensitive: false),
    'en': RegExp('only sees metadata such as', caseSensitive: false),
  };

  for (final lang in ['de', 'en']) {
    group(lang, () {
      final a = arb(lang);
      String t(String key) => a[key] as String;

      test('serverMetadataNote, privacy3Body, reportOnlineNote nennen Raum- und Profilnamen', () {
        for (final k in ['serverMetadataNote', 'privacy3Body', 'reportOnlineNote']) {
          expect(names[lang]!.hasMatch(t(k)), isTrue, reason: '$k: ${t(k)}');
        }
      });

      test('kein „eigener Server vermeidet Metadaten“, kein „nur verschlüsselte Ereignisse“', () {
        for (final k in ['serverMetadataNote', 'privacy3Body']) {
          expect(avoid[lang]!.hasMatch(t(k)), isFalse, reason: '$k: ${t(k)}');
        }
        expect(onlyEncrypted[lang]!.hasMatch(t('privacy3Body')), isFalse);
      });

      test('#422, E-101: Die Avatar-Wahl steht als für den Anbieter sichtbares Metadatum in allen Texten, nicht verschlüsselt', () {
        final avatar = RegExp('avatar', caseSensitive: false);
        final notE2ee = lang == 'de' ? RegExp('nicht Ende-zu-Ende-verschlüsselt') : RegExp('not end-to-end encrypted');
        for (final k in ['serverMetadataNote', 'privacy3Body', 'privacy10Body', 'privacy12Body']) {
          expect(avatar.hasMatch(t(k)), isTrue, reason: '$k nennt den Avatar');
          expect(notE2ee.hasMatch(t(k)), isTrue, reason: '$k sagt „nicht Ende-zu-Ende-verschlüsselt“');
        }
        expect(avatar.hasMatch(t('reportOnlineNote')), isTrue);
        expect(RegExp(lang == 'de' ? 'Raumzustand im Klartext' : 'room state in plain text').hasMatch(t('reportOnlineNote')), isTrue);
        expect(avatar.hasMatch(t('privacy2Body')), isTrue, reason: 'Datenarten');
        expect(avatar.hasMatch(t('privacy10Title')), isTrue);
        // Löschung: die Wahl bleibt im Raum stehen
        expect(avatar.hasMatch(t('accountDeleteBody')), isTrue, reason: 'Kontolöschung nennt, dass die Avatar-Wahl stehen bleibt');
      });

      test('privacy10Body und privacy12Body sagen nicht „nur Metadaten wie Zeitpunkte und Größe“', () {
        for (final k in ['privacy10Body', 'privacy12Body']) {
          expect(onlyMetadata[lang]!.hasMatch(t(k)), isFalse, reason: '$k: ${t(k)}');
        }
      });
    });
  }

  test('englische Datenschutzerklärung: keine Zusage, ein eigener Server vermeide Metadaten', () {
    final text = File('store/privacy/privacy-policy.en.md').readAsStringSync();
    expect(text, isNot(contains('Use your own server to avoid')));
    expect(RegExp('only sees encrypted events', caseSensitive: false).hasMatch(text), isFalse);
  });

  test('#422, E-101: Store-Datenschutzerklärungen nennen die Avatar-Wahl (Datenart, sichtbares Metadatum, Löschung)', () {
    for (final (file, avatar, notE2ee, stays) in <(String, String, String, String)>[
      ('store/privacy/privacy-policy.de.md', 'Avatar', 'nicht Ende-zu-Ende-verschlüsselt', 'bleibt auch nach dem Entfernen'),
      ('store/privacy/privacy-policy.en.md', 'avatar', 'not end-to-end encrypted', 'stays\nin the family room'),
    ]) {
      final text = File(file).readAsStringSync();
      expect(RegExp(avatar).allMatches(text).length, greaterThanOrEqualTo(3), reason: file);
      expect(text, contains(notE2ee), reason: file);
      expect(text, contains(stays), reason: '$file: die Wahl bleibt nach Entfernen oder Kontolöschung stehen');
    }
  });
}
