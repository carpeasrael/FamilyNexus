import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #165: Begriffe sind einheitlich. E-57 führt „Notfall-Schlüssel“ ein
/// („emergency key“), Einzelchats heißen „direct chat“ („privat“ ist die
/// Terminsichtbarkeit).
void main() {
  final oldKey = RegExp('Wiederherstellungsschlüssel|recovery key', caseSensitive: false);

  Map<String, dynamic> arb(String name) =>
      json.decode(File('lib/l10n/$name.arb').readAsStringSync()) as Map<String, dynamic>;

  for (final name in ['app_de', 'app_en']) {
    test('$name: kein „Wiederherstellungsschlüssel“ / „recovery key“', () {
      final offenders = <String>[
        for (final e in arb(name).entries)
          if (!e.key.startsWith('@') && e.value is String && oldKey.hasMatch(e.value as String)) e.key,
      ];
      expect(offenders, isEmpty);
    });
  }

  test('app_en: Einzelchat heißt „direct chat“, nicht „private chat“', () {
    final offenders = <String>[
      for (final e in arb('app_en').entries)
        if (!e.key.startsWith('@') &&
            e.value is String &&
            (e.value as String).toLowerCase().contains('private chat'))
          e.key,
    ];
    expect(offenders, isEmpty);
  });

  test('Store-Beschreibungen: kein „Wiederherstellungsschlüssel“ / „recovery key“', () {
    final files = Directory('store/metadata')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
      final n = f.uri.pathSegments.last;
      return n == 'description.txt' || n == 'full_description.txt';
    }).toList();
    expect(files, isNotEmpty);
    final offenders = [
      for (final f in files)
        if (oldKey.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });
}
