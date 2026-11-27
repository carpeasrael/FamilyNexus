import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/features/settings/data_report.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// #555, E-109: Die Datenübersicht nennt keine Raum-IDs (außer bei unbekannten Räumen) und zeigt bei Einzelchats
/// online den Namen der Gegenseite.
void main() {
  InventoryRoom room(InventoryRoomKind kind, {String name = '', String id = '!abc123:fake.test'}) => InventoryRoom(
        id: id,
        kind: kind,
        name: name,
        encrypted: true,
        membership: 'join',
        joinedMembers: 2,
        invitedMembers: 0,
        cachedEvents: 0,
        eventTypes: const <String, int>{},
        attachments: 0,
      );

  OnlineInventory inventory(List<InventoryRoom> rooms) => OnlineInventory(
        server: 'https://fake.test',
        userId: '@ida:fake.test',
        deviceId: 'GERAET',
        displayName: null,
        hasAvatar: false,
        devices: const [],
        crossSigning: false,
        keyBackup: false,
        accountDataTypes: const <String>[],
        rooms: rooms,
      );

  String online(String locale, List<InventoryRoom> rooms) => DataReport.online(
        l: lookupAppLocalizations(Locale(locale)),
        now: DateTime(2026, 11, 18),
        version: '1.2.3',
        inventory: inventory(rooms),
      );

  String local(String locale, List<InventoryRoom> rooms) => DataReport.local(
        l: lookupAppLocalizations(Locale(locale)),
        inventory: const LocalInventory(
          locations: StorageLocations(
            databaseDirectory: '/tmp/db',
            appDatabase: '/tmp/db/app.db',
            matrixDatabase: '/tmp/db/matrix.db',
            keyStore: KeyStoreKind.linuxSecretService,
          ),
          keys: <LocalKey>[],
          tables: <LocalTable>[],
        ),
        matrix: inventory(rooms),
        now: DateTime(2026, 11, 18),
        version: '1.2.3',
      );

  group('Raumzeilen im Online-Bericht', () {
    test('Einzelchat mit Namen: Name der Gegenseite, keine Raum-ID', () {
      final r = online('de', [room(InventoryRoomKind.direct, name: 'Test Nutzer 2')]);
      expect(r, contains('- Einzelchat „Test Nutzer 2“\n'));
      expect(r, isNot(contains('!abc123')));
      expect(online('en', [room(InventoryRoomKind.direct, name: 'Test Nutzer 2')]), contains('- Direct chat „Test Nutzer 2“\n'));
    });

    test('Einzelchat ohne Namen: nur die Art, ohne Klammerrest und doppeltes Leerzeichen', () {
      final r = online('de', [room(InventoryRoomKind.direct)]);
      expect(r, contains('- Einzelchat\n'));
      expect(r, isNot(contains('!')));
      expect(r, isNot(contains('Einzelchat  ')));
      expect(r, isNot(contains('()')));
    });

    test('Familien- und privater Raum ohne Raum-ID (sie ist der Familien-Code, E-65)', () {
      final r = online('de', [
        room(InventoryRoomKind.family, name: 'Familie Muster', id: '!familie:fake.test'),
        room(InventoryRoomKind.private, id: '!privat:fake.test'),
      ]);
      expect(r, contains('- Familie „Familie Muster“\n'));
      expect(r, isNot(contains('!familie')));
      expect(r, isNot(contains('!privat')));
    });

    test('unbekannter Raum behält die Raum-ID, sonst wären mehrere nicht zu unterscheiden', () {
      final r = online('de', [
        room(InventoryRoomKind.other, id: '!eins:fake.test'),
        room(InventoryRoomKind.other, id: '!zwei:fake.test'),
      ]);
      expect(r, contains('- Sonstiger Raum (!eins:fake.test)\n'));
      expect(r, contains('- Sonstiger Raum (!zwei:fake.test)\n'));
    });
  });

  group('Kassenbuch in der Datenübersicht (#311, E-113)', () {
    test('Raumart: Familie, privat und Einzelchat gehen vor dem Buch-Kennzeichen; ohne Kennzeichen gibt es kein Buch', () {
      InventoryRoomKind k({bool f = false, bool p = false, bool d = false, bool b = false}) =>
          inventoryRoomKind(isFamily: f, isPrivate: p, isDirect: d, isBook: b);
      expect(k(f: true, b: true), InventoryRoomKind.family);
      expect(k(p: true, b: true), InventoryRoomKind.private);
      expect(k(d: true, b: true), InventoryRoomKind.direct);
      expect(k(f: true, p: true, d: true, b: true), InventoryRoomKind.family);
      expect(k(p: true, d: true, b: true), InventoryRoomKind.private);
      expect(k(b: true), InventoryRoomKind.book);
      expect(k(), InventoryRoomKind.other);
      expect(k(d: true), InventoryRoomKind.direct);
    });

    test('Kontakt-Einzelchat (#119): geht dem Einzelchat voran, nie der Familie und dem privaten Raum', () {
      InventoryRoomKind k({bool f = false, bool p = false, bool d = false, bool c = false}) =>
          inventoryRoomKind(isFamily: f, isPrivate: p, isDirect: d, isBook: false, isContact: c);
      expect(k(c: true, d: true), InventoryRoomKind.contact);
      expect(k(c: true), InventoryRoomKind.contact);
      expect(k(f: true, c: true, d: true), InventoryRoomKind.family);
      expect(k(p: true, c: true, d: true), InventoryRoomKind.private);
      expect(k(d: true), InventoryRoomKind.direct, reason: 'ohne Kontakt-Kennzeichen unverändert');
    });

    test('Bericht: Kontakt-Chat trägt den Namen nur online mit Mitgliedern, nie die Raum-ID (de und en)', () {
      final r = online('de', [room(InventoryRoomKind.contact, name: 'Carla')]);
      expect(r, contains('- Kontakt-Chat „Carla“\n'));
      expect(r, isNot(contains('!abc123')));
      expect(online('en', [room(InventoryRoomKind.contact, name: 'Carla')]), contains('- Contact chat „Carla“\n'));
      expect(local('de', [room(InventoryRoomKind.contact, name: 'Carla')]), isNot(contains('Carla')));
    });

    test('Gruppe (#119, K4-1): Reihenfolge, Gruppen-Datensatz gewinnt gegen Einzelchat und Kontakt, nie gegen Familie/privat', () {
      InventoryRoomKind k({bool f = false, bool p = false, bool d = false, bool c = false, bool g = false, bool b = false}) =>
          inventoryRoomKind(isFamily: f, isPrivate: p, isDirect: d, isBook: b, isContact: c, isGroup: g);
      expect(k(g: true), InventoryRoomKind.group);
      expect(k(g: true, d: true), InventoryRoomKind.group, reason: 'm.direct-Eintrag gewinnt nicht (D4)');
      expect(k(g: true, c: true, d: true), InventoryRoomKind.group);
      expect(k(g: true, b: true), InventoryRoomKind.group);
      expect(k(f: true, g: true), InventoryRoomKind.family);
      expect(k(p: true, g: true), InventoryRoomKind.private);
      expect(k(c: true, d: true), InventoryRoomKind.contact, reason: 'ohne Gruppen-Kennzeichen unverändert');
      expect(inventoryRoomKind(isFamily: false, isPrivate: false, isDirect: true, isBook: false), InventoryRoomKind.direct,
          reason: 'isGroup hat den Standard false');
    });

    test('Bericht: Gruppe trägt den Namen nur online mit Mitgliedern, nie die Raum-ID (de und en)', () {
      final rooms = [room(InventoryRoomKind.group, name: 'Skatrunde')];
      final r = online('de', rooms);
      expect(r, contains('- Gruppe „Skatrunde“\n'));
      expect(r, isNot(contains('!abc123')));
      expect(online('en', rooms), contains('- Group „Skatrunde“\n'));
      for (final loc in <String>['de', 'en']) {
        expect(local(loc, rooms), isNot(contains('Skatrunde')), reason: 'lokaler Bericht ohne Gruppennamen ($loc)');
      }
      expect(local('de', rooms), contains('- Gruppe\n'));
      expect(local('en', rooms), contains('- Group\n'));
    });

    test('jede Raumart hat in beiden Sprachen einen nicht leeren, von den anderen verschiedenen Text', () {
      for (final loc in <String>['de', 'en']) {
        final texts = <String>{};
        for (final kind in InventoryRoomKind.values) {
          final r = online(loc, [room(kind)]);
          final line = r.split('\n').firstWhere((l) => l.startsWith('- '));
          final t = line.substring(2).split(' (').first.trim();
          expect(t, isNotEmpty, reason: '$kind $loc');
          texts.add(t);
        }
        expect(texts, hasLength(InventoryRoomKind.values.length), reason: 'verschiedene Texte ($loc)');
      }
    });

    test('Kassenbuch: Art ohne Namen (er ist der feste Raumname der App) und ohne Raum-ID, in beiden Sprachen und beiden Berichten', () {
      final rooms = [room(InventoryRoomKind.book, name: 'FamilyNexus', id: '!buch:fake.test')];
      for (final r in [online('de', rooms), local('de', rooms)]) {
        expect(r, contains('- Kassenbuch\n'));
        expect(r, isNot(contains('„FamilyNexus“')));
        expect(r, isNot(contains('!buch')));
        expect(r, isNot(contains('Sonstiger Raum')));
      }
      expect(online('en', rooms), contains('- Cash book\n'));
      expect(online('en', rooms), isNot(contains('Other room')));
    });

    test('die Ereignisarten des Buchs haben Namen (de und en), der Roh-Typ steht in Klammern', () {
      const r = InventoryRoom(
        id: '!buch:fake.test',
        kind: InventoryRoomKind.book,
        name: '',
        encrypted: true,
        membership: 'join',
        joinedMembers: 2,
        invitedMembers: 0,
        cachedEvents: 3,
        eventTypes: <String, int>{CashBookCodec.metaType: 1, CashBookCodec.entryType: 2},
        attachments: 1,
      );
      expect(online('de', [r]), contains('Kassenbuch: Stammdaten (${CashBookCodec.metaType}): 1'));
      expect(online('de', [r]), contains('Kassenbuch: Einträge (${CashBookCodec.entryType}): 2'));
      expect(online('en', [r]), contains('Cash book: master data (${CashBookCodec.metaType}): 1'));
      expect(online('en', [r]), contains('Cash book: entries (${CashBookCodec.entryType}): 2'));
    });
  });

  group('Raumzeilen im lokalen Bericht', () {
    test('Einzelchat zeigt auch bei gefülltem Namen keinen Namen der Gegenseite (E-89), keine Raum-ID', () {
      final r = local('de', [room(InventoryRoomKind.direct, name: 'Test Nutzer 2')]);
      expect(r, contains('- Einzelchat\n'));
      expect(r, isNot(contains('Test Nutzer 2')));
      expect(r, isNot(contains('!abc123')));
    });

    test('Familie behält ihren Namen, ohne Raum-ID', () {
      final r = local('de', [room(InventoryRoomKind.family, name: 'Familie Muster')]);
      expect(r, contains('- Familie „Familie Muster“\n'));
      expect(r, isNot(contains('!abc123')));
    });
  });

  group('directPeerName', () {
    test('liefert den bereinigten Namen', () {
      expect(directPeerName('Test Nutzer 2'), 'Test Nutzer 2');
      expect(directPeerName('  Anna\u0000 Müller  '), isNot(contains('\u0000')));
    });

    test('fehlender Eintrag oder leerer Name bleibt leer, ohne Ersatz', () {
      expect(directPeerName(null), '');
      expect(directPeerName(''), '');
      expect(directPeerName('   '), '');
    });

    test('Matrix-ID oder Raum-ID als Name wird verworfen', () {
      expect(directPeerName('@nutzer2:fake.test'), '');
      expect(directPeerName('!abc123:fake.test'), '');
    });

    test('zu lange Namen werden auf 80 Zeichen gekürzt', () {
      expect(directPeerName('a' * 200).length, lessThanOrEqualTo(80));
    });
  });
}
