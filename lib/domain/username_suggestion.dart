/// Vorschlag für einen Benutzernamen aus dem angegebenen Namen (E-55): „Anna Müller“ → `anna.mueller`.
///
/// Matrix erlaubt im lokalen Teil nur Kleinbuchstaben, Ziffern und `._=-/+`; die App beschränkt sich
/// auf `a-z 0-9 . _ -`, damit Namen leicht zu tippen und vorzulesen sind.
class UsernameSuggestion {
  const UsernameSuggestion._();

  static const int minLength = 3;
  static const int maxLength = 32;

  static const Map<String, String> _map = <String, String>{
    'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss', 'æ': 'ae', 'ø': 'oe', 'å': 'aa', 'œ': 'oe', 'þ': 'th', 'ð': 'd',
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'ç': 'c', 'ć': 'c', 'č': 'c',
    'ď': 'd', 'đ': 'd',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e',
    'ğ': 'g',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i',
    'ł': 'l', 'ľ': 'l',
    'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ō': 'o', 'ő': 'o',
    'ř': 'r',
    'ś': 's', 'š': 's', 'ş': 's', 'ș': 's',
    'ť': 't', 'ț': 't',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ź': 'z', 'ż': 'z', 'ž': 'z',
  };

  static final RegExp _valid = RegExp(r'^[a-z0-9._\-]{3,32}$');

  /// `true`, wenn [name] ein zulässiger Benutzername im Sinne der App ist.
  static bool isValid(String name) => _valid.hasMatch(name) && !name.startsWith('.') && !name.endsWith('.');

  /// Vorschlag aus einem frei eingegebenen Namen; leer, wenn nichts Verwertbares übrig bleibt.
  static String fromName(String name) {
    final buf = StringBuffer();
    for (final ch in name.trim().toLowerCase().split('')) {
      final mapped = _map[ch];
      if (mapped != null) {
        buf.write(mapped);
      } else if (RegExp(r'[a-z0-9_\-]').hasMatch(ch)) {
        buf.write(ch);
      } else if (ch == '.' || RegExp(r'\s').hasMatch(ch)) {
        buf.write('.');
      }
      // Alles andere (Emoji, Satzzeichen, andere Schriften) fällt weg.
    }
    var s = buf.toString().replaceAll(RegExp(r'\.{2,}'), '.').replaceAll(RegExp(r'^[.\-_]+|[.\-_]+$'), '');
    if (s.length > maxLength) s = s.substring(0, maxLength).replaceAll(RegExp(r'[.\-_]+$'), '');
    if (s.isEmpty) return '';
    if (s.length < minLength) s = '$s.familie';
    return s;
  }

  /// Ausweichvorschläge, wenn [base] vergeben ist (stabile Reihenfolge, ohne Zufall).
  static List<String> alternatives(String base) {
    if (base.isEmpty) return const <String>[];
    String fit(String suffix) {
      final room = maxLength - suffix.length;
      final head = base.length > room ? base.substring(0, room) : base;
      return '$head$suffix';
    }

    return <String>[fit('2'), fit('.familie'), fit('3'), fit('4')]
        .where(isValid)
        .toSet()
        .toList();
  }
}
