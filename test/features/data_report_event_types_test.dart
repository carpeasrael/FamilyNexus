import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/domain/event_theme_codec.dart';
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
              eventTypes: <String, int>{ReactionCodec.type: 2, 'm.reaction': 1, EventThemeCodec.type: 3},
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

  test('E-99: der Ereignistyp der Kalender-Themen hat ein eigenes Label (de und en)', () {
    expect(report('de'), contains('Kalender-Themen (${EventThemeCodec.type}): 3'));
    expect(report('en'), contains('Calendar themes (${EventThemeCodec.type}): 3'));
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

  test('#259: Online-Protokoll nennt den über .well-known ermittelten Homeserver nur, wenn er abweicht', () {
    String online(String locale, {required String server, String? homeserver}) => DataReport.online(
          l: lookupAppLocalizations(Locale(locale)),
          now: DateTime(2026, 11, 4),
          version: '1.2.2',
          inventory: OnlineInventory(
            server: server,
            homeserver: homeserver,
            userId: '@ida:chaostribunal.de',
            deviceId: 'GERAET',
            displayName: null,
            hasAvatar: false,
            devices: const [],
            crossSigning: false,
            keyBackup: false,
            accountDataTypes: const <String>[],
            rooms: const <InventoryRoom>[],
          ),
        );
    final de = online('de', server: 'https://matrix-synapse.example', homeserver: 'https://matrix.chaostribunal.de');
    expect(de, contains('Server: https://matrix-synapse.example\n'));
    expect(de, contains('Homeserver (über .well-known ermittelt): https://matrix.chaostribunal.de\n'));
    expect(de.indexOf('Server: '), lessThan(de.indexOf('Homeserver (')), reason: 'Zusatzzeile direkt nach „Server“');
    expect(
      online('en', server: 'https://matrix-synapse.example', homeserver: 'https://matrix.chaostribunal.de'),
      contains('Homeserver (resolved via .well-known): https://matrix.chaostribunal.de'),
    );
    for (final (server, homeserver) in <(String, String?)>[
      ('https://hs.example', 'https://hs.example'),
      ('https://hs.example', 'https://hs.example/'),
      ('https://hs.example', null),
    ]) {
      expect(online('de', server: server, homeserver: homeserver), isNot(contains('Homeserver')), reason: '$homeserver');
    }
  });
}
