import 'package:family_nexus/features/security/sas_emoji_names.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/encryption.dart';

/// #39: Die Bedienungshilfe liest die Vergleichssymbole in der Sprache der App.
void main() {
  test('alle 64 Symbole des SDK haben einen deutschen Namen', () {
    final names = <String>[for (var i = 0; i < 64; i++) KeyVerificationEmoji(i).name];
    expect(names.toSet(), hasLength(64));
    for (final n in names) {
      expect(SasEmojiNames.known, contains(n));
    }
    // Gleich geschrieben sind nur Panda, Pizza, Hammer und Ball.
    expect(names.where((n) => SasEmojiNames.of(n, 'de') == n).toSet(), <String>{'Panda', 'Pizza', 'Hammer', 'Ball'});
    expect(SasEmojiNames.of('Fire', 'de'), 'Feuer');
    expect(SasEmojiNames.of('Butterfly', 'de'), 'Schmetterling');
    expect(SasEmojiNames.of('Apple', 'de'), 'Apfel');
  });

  test('Englisch und unbekannte Namen bleiben unverändert', () {
    expect(SasEmojiNames.of('Fire', 'en'), 'Fire');
    expect(SasEmojiNames.of('Spaceship', 'de'), 'Spaceship');
  });
}
