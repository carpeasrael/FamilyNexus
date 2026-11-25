import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #119, K1 (B1, B3): Die echte Verdrahtung des SDK-Pfads ist ohne E2E gegen Synapse nicht ausführbar. Dieser Test sichert
/// sie am Quelltext (Wächter, wie `architecture_test`): Nur der Familienraum darf Terminverweise zulassen, und der Client
/// behält `m.room.join_rules` im Speicher. Das ersetzt keinen E2E-Lauf (`test/e2e/gateway_security_e2e_test.dart`).
void main() {
  final gateway = File('lib/data/matrix/sdk_matrix_gateway.dart').readAsStringSync();
  final direct = File('lib/data/matrix/gateway/direct_chats.dart').readAsStringSync();

  test('der Familienraum lässt Terminverweise zu', () {
    final call = RegExp(r'ChatMapper\.messages\(timeline, threadId: ChatThread\.familyId[^;]*;').firstMatch(gateway);
    expect(call, isNotNull);
    expect(call!.group(0), contains('allowEventRefs: true'));
  });

  test('Einzelchats (und jeder andere Raum) lassen sie nie zu', () {
    expect(direct, isNot(contains('allowEventRefs: true')));
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('sdk_matrix_gateway.dart') || f.path.endsWith('chat_mapper.dart')) continue;
      expect(f.readAsStringSync().contains('allowEventRefs: true'), isFalse, reason: f.path);
    }
    expect('allowEventRefs: true'.allMatches(gateway).length, 1, reason: 'genau ein Aufruf, der des Familienraums');
  });

  test('m.room.join_rules bleibt im Speicher des Clients (Einladungszustand nach einem Neustart)', () {
    expect(gateway, contains('client.importantStateEvents.add(EventTypes.RoomJoinRules);'));
  });
}
