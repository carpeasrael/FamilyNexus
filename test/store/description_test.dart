import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
