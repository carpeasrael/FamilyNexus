import 'dart:convert';

import 'package:family_nexus/domain/reaction_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const me = '@ida:fake.test';
  Map<String, Object?> valid() => ReactionCodec.encode(target: r'$ziel', key: '👍', sender: me);

  test('Hin- und Rückweg', () {
    final r = ReactionCodec.decode(json.decode(json.encode(valid())) as Map<String, Object?>, sender: me)!;
    expect(r.target, r'$ziel');
    expect(r.key, '👍');
  });

  test('Inhalt ohne m.relates_to: Emoji und Ziel liegen im Chiffretext', () {
    expect(valid().keys, unorderedEquals(<String>['v', 'target', 'key', 'sender']));
    expect(ReactionCodec.type, isNot('m.reaction'));
  });

  test('andere Fassungen werden ignoriert', () {
    for (final v in <Object?>[0, 2, '1', null]) {
      expect(ReactionCodec.decode(<String, Object?>{...valid(), 'v': v}, sender: me), isNull, reason: '$v');
    }
  });

  test('unbekannte Felder werden geduldet', () {
    expect(ReactionCodec.decode(<String, Object?>{...valid(), 'neu': 1}, sender: me), isNotNull);
  });

  test('ungültige Felder', () {
    final bad = <Map<String, Object?>>[
      <String, Object?>{},
      <String, Object?>{...valid()}..remove('target'),
      <String, Object?>{...valid()}..remove('key'),
      <String, Object?>{...valid()}..remove('sender'),
      <String, Object?>{...valid(), 'target': 1},
      <String, Object?>{...valid(), 'target': 'ziel'},
      <String, Object?>{...valid(), 'target': ''},
      <String, Object?>{...valid(), 'target': '\$${'x' * 255}'},
      <String, Object?>{...valid(), 'key': 1},
      <String, Object?>{...valid(), 'key': ''},
      <String, Object?>{...valid(), 'key': 'Klickhier'},
      <String, Object?>{...valid(), 'key': '👍\u202E'},
      <String, Object?>{...valid(), 'sender': 1},
    ];
    for (final c in bad) {
      expect(ReactionCodec.decode(c, sender: me), isNull, reason: '$c');
    }
  });

  test('längstes erlaubtes Ziel', () {
    final id = '\$${'x' * 254}';
    expect(id.length, 255);
    expect(ReactionCodec.decode(<String, Object?>{...valid(), 'target': id}, sender: me), isNotNull);
  });

  test('fremder Chiffretext lässt sich nicht umadressieren', () {
    expect(ReactionCodec.decode(valid(), sender: '@ben:fake.test'), isNull);
  });
}
