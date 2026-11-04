import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/domain/reaction_codec.dart';
import 'package:family_nexus/features/settings/data_report.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
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

  test('#261: lokales Protokoll nennt den eigenen Anzeigenamen, ohne Namen „nicht gesetzt“', () {
    const local = LocalInventory(
      locations: StorageLocations(
        databaseDirectory: '/tmp/db',
        appDatabase: '/tmp/db/app.db',
        matrixDatabase: '/tmp/db/matrix.db',
        keyStore: KeyStoreKind.linuxSecretService,
      ),
      keys: <LocalKey>[],
      tables: <LocalTable>[],
    );
    OnlineInventory matrix(String? name) => OnlineInventory(
          server: 'https://fake.test',
          userId: '@ida:fake.test',
          deviceId: 'GERAET',
          displayName: name,
          hasAvatar: false,
          devices: const [],
          crossSigning: false,
          keyBackup: false,
          accountDataTypes: const <String>[],
          rooms: const <InventoryRoom>[],
        );
    String localReport(String locale, String? name) => DataReport.local(
          l: lookupAppLocalizations(Locale(locale)),
          inventory: local,
          matrix: matrix(name),
          now: DateTime(2026, 11, 4),
          version: '1.2.2',
        );
    expect(localReport('de', null), contains('Anzeigename: nicht gesetzt'));
    expect(localReport('en', null), contains('Display name: not set'));
    expect(localReport('de', 'Ida'), contains('Anzeigename: Ida'));
  });
}
