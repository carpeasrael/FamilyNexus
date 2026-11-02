import 'text_sanitizer.dart';

/// Inhalt einer verschlüsselten Reaktion.
class ReactionContent {
  const ReactionContent({required this.target, required this.key});

  /// Kennung der Nachricht, auf die sich die Reaktion bezieht.
  final String target;

  /// Das Emoji.
  final String key;
}

/// Reaktion als eigener, verschlüsselter Ereignistyp (E-86).
///
/// Bewusst **ohne** `m.relates_to`: Das Feld stünde in der unverschlüsselten Hülle. Emoji und Ziel liegen deshalb im
/// Chiffretext. Das Format ist schwer rückholbar: Gesendete Reaktionen bleiben auf dem Server, ältere Apps und andere
/// Matrix-Clients zeigen sie nicht.
class ReactionCodec {
  const ReactionCodec._();

  static const String type = 'de.inneso.familynexus.reaction';
  static const int version = 1;
  static const int _maxTargetLength = 255;

  static bool isTarget(String id) => id.startsWith(r'$') && id.length <= _maxTargetLength;

  static Map<String, Object?> encode({required String target, required String key, required String sender}) =>
      <String, Object?>{'v': version, 'target': target, 'key': key, 'sender': sender};

  /// `null` bei anderer Fassung oder ungültigem Inhalt; unbekannte Felder bleiben für spätere Erweiterungen erlaubt.
  /// Das Feld `sender` muss mit [sender] übereinstimmen: Fremder Chiffretext lässt sich nicht umadressieren.
  static ReactionContent? decode(Map<String, Object?> c, {required String sender}) {
    if (c['v'] != version) return null;
    final target = c['target'];
    final key = c['key'];
    final by = c['sender'];
    if (target is! String || !isTarget(target)) return null;
    if (key is! String || !TextSanitizer.isReactionKey(key)) return null;
    if (by is! String || by != sender) return null;
    return ReactionContent(target: target, key: key);
  }
}
