import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/domain/reaction_codec.dart';
import 'package:family_nexus/features/settings/data_report.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String report(String locale) => DataReport.online(
        l: lookupAppLocalizations(Locale(locale)),
        now: DateTime(2026, 11, 1),
        version: '1.2.1',
        inventory: const OnlineInventory(
          server: 'https://fake.test',
          userId: '@ida:fake.test',
          deviceId: 'GERAET',
          displayName: null,
          hasAvatar: false,
          devices: [],
          crossSigning: false,
          keyBackup: false,
          accountDataTypes: <String>[],
          rooms: <InventoryRoom>[
            InventoryRoom(
              id: '!raum:fake.test',
              kind: InventoryRoomKind.family,
              name: '',
              encrypted: true,
              membership: 'join',
              joinedMembers: 2,
              invitedMembers: 0,
              cachedEvents: 3,
              eventTypes: <String, int>{ReactionCodec.type: 2, 'm.reaction': 1},
              attachments: 0,
            ),
          ],
        ),
      );

  test('#139: der neue Reaktionstyp erscheint wie der alte als „Reaktionen“', () {
    expect(report('de'), contains('Reaktionen (${ReactionCodec.type}): 2'));
    expect(report('de'), contains('Reaktionen (m.reaction): 1'));
    expect(report('en'), contains('Reactions (${ReactionCodec.type}): 2'));
  });
}
