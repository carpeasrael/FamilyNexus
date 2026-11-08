import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// #159: Die Store-Beschreibung nennt nur, was die App auf der Plattform wirklich kann.
/// macOS hat bewusst keinen Bildschirmschutz (E-18, E-44; `PlatformInfo.hasNoScreenProtection`).
void main() {
  final screenProtection = RegExp('Bildschirmschutz|screen protection', caseSensitive: false);

  for (final lang in ['de-DE', 'en-US']) {
    test('macOS $lang: kein Bildschirmschutz in der Beschreibung', () {
      final text = File('store/metadata/macos/$lang/description.txt').readAsStringSync();
      expect(screenProtection.hasMatch(text), isFalse);
      expect(text, contains(lang == 'de-DE' ? 'App-Sperre über die Geräteanmeldung' : 'App lock with the device credentials'));
    });
  }

  for (final f in [
    'store/metadata/ios/de-DE/description.txt',
    'store/metadata/ios/en-US/description.txt',
    'store/metadata/android/de-DE/full_description.txt',
    'store/metadata/android/en-US/full_description.txt',
  ]) {
    test('$f: Bildschirmschutz bleibt genannt (dort aktiv)', () {
      expect(screenProtection.hasMatch(File(f).readAsStringSync()), isTrue);
    });
  }

  // #167: Die Beschreibungen nennen die Aufgabenlisten (E-51, E-58) und bleiben unter der Store-Grenze von 4000 Zeichen.
  for (final f in [
    'store/metadata/ios/de-DE/description.txt',
    'store/metadata/ios/en-US/description.txt',
    'store/metadata/macos/de-DE/description.txt',
    'store/metadata/macos/en-US/description.txt',
    'store/metadata/android/de-DE/full_description.txt',
    'store/metadata/android/en-US/full_description.txt',
  ]) {
    test('$f: Aufgabenlisten genannt, höchstens 4000 Zeichen', () {
      final text = readNormalized(f);
      final de = f.contains('/de-DE/');
      expect(text, contains(de ? '\nAUFGABEN\n' : '\nTASKS\n'));
      expect(text, contains(de ? 'Montag bis Freitag' : 'Monday to Friday'));
      expect(text.runes.length, lessThanOrEqualTo(4000));
    });
  }
}
