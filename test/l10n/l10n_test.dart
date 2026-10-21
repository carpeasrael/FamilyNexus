import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String name) =>
    json.decode(File('lib/l10n/$name.arb').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('de und en haben identische Schlüssel', () {
    final de = _arb('app_de').keys.where((k) => !k.startsWith('@')).toSet();
    final en = _arb('app_en').keys.where((k) => !k.startsWith('@')).toSet();
    expect(de.difference(en), isEmpty, reason: 'fehlt in en');
    expect(en.difference(de), isEmpty, reason: 'fehlt in de');
  });

  test('keine festen UI-Texte im Code (mehrzeilig, alle üblichen Parameter)', () {
    final literal = RegExp(
      r'''(\bText\(\s*|\bSelectableText\(\s*|\blabel:\s*|\btitle:\s*|\bsubtitle:\s*|\bhintText:\s*|\blabelText:\s*|\btooltip:\s*|\bsemanticLabel:\s*|\bmessage:\s*|\bcontent:\s*|\bhelperText:\s*|\berrorText:\s*)(const\s+)?(Text\(\s*)?['"][^'"]*[A-Za-zÄÖÜäöüß]{2,}[^'"]*['"]''',
      multiLine: true,
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/l10n/gen/')) continue;
      final text = f.readAsStringSync();
      for (final m in literal.allMatches(text)) {
        // Interpolationen (`${l.x}`, `$e`) zählen nicht als fester Text.
        final stripped = m.group(0)!.replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
        if (!RegExp('[A-Za-zÄÖÜäöüß]{2,}').hasMatch(stripped.replaceFirst(RegExp(r'^[^\x27"]*'), ''))) continue;
        final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
        offenders.add('${f.path}:$line: ${m.group(0)!.replaceAll(RegExp(r'\s+'), ' ')}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
