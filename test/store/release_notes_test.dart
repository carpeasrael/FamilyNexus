import 'package:family_nexus/app/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// Release Notes (#353: die erste Zeile nennt die aktuelle Version, docs/STORE.md Abschnitt 7 Nr. 2); 1.2.2 (#242, #243): Sie versprechen nur, was die App kann, und folgen den Entscheidungen
/// zu älteren App-Versionen (E-40 Nachträge #161, #211; E-86).
const _files = <String>[
  'store/metadata/android/de-DE/release_notes.txt',
  'store/metadata/android/en-US/release_notes.txt',
  'store/metadata/ios/de-DE/release_notes.txt',
  'store/metadata/ios/en-US/release_notes.txt',
  'store/metadata/macos/de-DE/release_notes.txt',
  'store/metadata/macos/en-US/release_notes.txt',
];

bool _isGerman(String f) => f.contains('/de-DE/');

/// Teilsätze: getrennt an `.`, `;`, `:`, `•` und Zeilenumbruch.
List<String> _clauses(String text) =>
    text.split(RegExp(r'[.;:•\n]')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

void main() {
  for (final f in _files) {
    final de = _isGerman(f);
    final text = readNormalized(f);

    test('#242 $f: zusammengesetzte Emojis nicht in Terminen und nicht „überall“', () {
      final negation = de ? 'in Terminen weiterhin nicht' : 'still not in events';
      for (final c in _clauses(text).where((c) => c.toLowerCase().contains('emoji'))) {
        final lower = c.toLowerCase();
        expect(lower.contains('überall') || lower.contains('everywhere'), isFalse, reason: c);
        if (lower.contains('termin') || lower.contains('event')) {
          expect(c, contains(negation), reason: 'Termine sperren ZWJ/ZWNJ (E-33, E-40 Nachtrag #161): $c');
        }
      }
    });

    test('#353 $f: beginnt mit den Neuerungen der aktuellen Version', () {
      expect(text.split('\n').first.trim(), '${de ? 'Neu in' : 'New in'} $appVersion:');
    });

    test('#243 $f: bittet, alle Geräte zu aktualisieren', () {
      expect(text, contains(de ? 'alle Geräte' : 'all devices'));
      expect(text, isNot(contains(de ? 'nur ohne Gruppe' : 'just without a group')));
      if (!f.contains('/android/')) {
        expect(text, contains(de ? 'für alle verloren' : 'lost for everyone'));
      }
    });

    test('#577 $f: nennt Geburts- und Gedenktage', () {
      expect(text.toLowerCase(), contains(de ? 'geburts- und gedenktage' : 'birthdays and memorial days'));
    });

    test('#577 $f: nennt die standardmäßig öffentliche Lesebestätigung mit Ausweg (E-106)', () {
      // Die Bestätigung ist für Bestandsnutzer nach dem Update ohne Zutun an und nicht rücknehmbar; der Store-Text ist
      // der einzige Kanal zum Zeitpunkt des Updates (die App zeigt keinen Hinweis).
      final line = text.split('\n').where((l) => l.contains(de ? 'Einstellungen → Datenschutz' : 'Settings → Privacy'));
      expect(line, hasLength(1), reason: 'genau ein Punkt nennt den Schalter unter Datenschutz');
      final l = line.single;
      expect(l, contains(de ? 'Gelesen' : 'Read'));
      expect(l, contains(f.contains('/android/') ? (de ? 'Standard an' : 'on by default') : (de ? 'standardmäßig an' : 'on by default')));
      if (!f.contains('/android/')) {
        expect(l, contains(de ? 'nicht Ende-zu-Ende-verschlüsselt' : 'not end-to-end encrypted'));
        expect(l, contains(de ? 'nicht zurücknehmen' : 'cannot be taken back'));
      } else {
        expect(l, contains(de ? 'Server sehen es' : 'servers see it'));
      }
    });

    if (f.contains('/android/')) {
      test('$f: höchstens 500 Zeichen (Google Play)', () {
        expect(text.runes.length, lessThanOrEqualTo(500));
      });
    } else {
      test('#577 $f: höchstens 4000 Zeichen (App Store, docs/STORE.md)', () {
        expect(text.runes.length, lessThanOrEqualTo(4000));
      });
    }
  }
}
