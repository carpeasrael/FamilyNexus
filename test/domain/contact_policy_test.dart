import 'package:family_nexus/domain/contacts.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K3a-1 (E-114): Aus den Datensätzen gebauter Wert, den das Gateway liest.
void main() {
  const carla = '@carla:example.org';
  const dora = '@dora:example.org';
  final t = DateTime.utc(2026, 11, 25);

  Contact c(String id, ContactState s, {bool deleted = false}) => Contact(id: id, state: s, version: 1, updatedAt: t, deleted: deleted);

  test('off: Bereich aus, nichts bekannt', () {
    expect(ContactPolicy.off.enabled, isFalse);
    expect(ContactPolicy.off.contacts, isEmpty);
    expect(ContactPolicy.off.blocked, isEmpty);
    expect(ContactPolicy.of(const <ContactRecord>[]), ContactPolicy.off);
  });

  test('aktive Kontakte mit Zustand, Löschmarken fehlen, blockierte stehen in blocked', () {
    final p = ContactPolicy.of(<ContactRecord>[
      c(carla, ContactState.accepted),
      c(dora, ContactState.blocked),
      c('@gone:example.org', ContactState.accepted, deleted: true),
      c('@gone2:example.org', ContactState.blocked, deleted: true),
    ]);
    expect(p.contacts, <String, ContactState>{carla: ContactState.accepted, dora: ContactState.blocked});
    expect(p.blocked, <String>{dora});
  });

  test('Einstellung: der Datensatz entscheidet; Gruppen sind kein Kontakt', () {
    expect(ContactPolicy.of(<ContactRecord>[ContactPrefs(enabled: true, version: 1, updatedAt: t)]).enabled, isTrue);
    expect(ContactPolicy.of(<ContactRecord>[ContactPrefs(enabled: false, version: 2, updatedAt: t)]).enabled, isFalse);
    // K4-1: Ein Gruppen-Datensatz ist kein Kontakt (contacts/blocked bleiben leer), steht aber in `groups`; deshalb ist der
    // Wert nicht mehr gleich `off` (die frühere Aussage „gleich off“ galt, solange `groups` fehlte).
    final g = ContactPolicy.of(<ContactRecord>[GroupRecord(id: '!g:example.org', version: 1, updatedAt: t)]);
    expect(g.contacts, isEmpty, reason: 'Gruppen sind kein Kontakt');
    expect(g.blocked, isEmpty);
    expect(g.enabled, isFalse);
    expect(g.groups, <String>{'!g:example.org'});
  });

  test('die lokale Blockierliste fließt in blocked ein', () {
    final p = ContactPolicy.of(const <ContactRecord>[], localBlocked: const <String>[carla]);
    expect(p.blocked, <String>{carla});
    expect(p.contacts, isEmpty);
  });

  test('Gleichheit nach Inhalt (Einstellung, Kontakte, Blockierte)', () {
    ContactPolicy mk({bool enabled = true, ContactState s = ContactState.accepted, String b = carla}) =>
        ContactPolicy(enabled: enabled, contacts: <String, ContactState>{carla: s}, blocked: <String>{b});
    expect(mk(), mk());
    expect(mk().hashCode, mk().hashCode);
    expect(mk(), isNot(mk(enabled: false)));
    expect(mk(), isNot(mk(s: ContactState.outgoing)));
    expect(mk(), isNot(mk(b: dora)));
    expect(const ContactPolicy(contacts: <String, ContactState>{carla: ContactState.accepted}),
        isNot(const ContactPolicy(contacts: <String, ContactState>{dora: ContactState.accepted})));
  });

  test('der gebaute Wert lässt sich nicht nachträglich ändern', () {
    final p = ContactPolicy.of(<ContactRecord>[c(carla, ContactState.blocked)]);
    expect(() => p.contacts[dora] = ContactState.accepted, throwsUnsupportedError);
    expect(() => p.blocked.add(dora), throwsUnsupportedError);
  });

  group('ContactNames (K3a-2)', () {
    const id = '@anna:example.org';

    test('Titel „Name · server“, der Server stammt aus der ID', () {
      expect(ContactNames.title('Anna', id), 'Anna · example.org');
    });

    test('leerer oder nach der Bereinigung leerer Name: lokaler Teil der ID', () {
      expect(ContactNames.title(null, id), 'anna · example.org');
      expect(ContactNames.title('   ', id), 'anna · example.org');
      expect(ContactNames.title('\u202E\u200B', id), 'anna · example.org');
    });

    test('feindliche Namen: Trennzeichen „·“, Steuer- und Bidi-Zeichen entfallen, der Server bleibt der aus der ID', () {
      expect(ContactNames.title('Mama · familie.de', id), 'Mama familie.de · example.org');
      expect(ContactNames.title('Ma\u202Ema\u0000\u200F', id), 'Ma ma · example.org');
      expect(ContactNames.title('A\u2022B\u22C5C', id), 'A B C · example.org');
      expect(ContactNames.title('Name\nzwei', id), 'Name zwei · example.org');
    });

    test('Länge begrenzt (40 Zeichen, nicht UTF-16-Einheiten)', () {
      expect(ContactNames.cleanName('x' * 100).length, ContactNames.maxName);
      expect(ContactNames.cleanName('😀' * 100).runes.length, ContactNames.maxName);
    });

    test('ungültige ID: nur der Name', () {
      expect(ContactNames.title('Anna', 'kein-konto'), 'Anna');
    });
  });

  group('ContactReach (K3a-2b)', () {
    test('Wahrheitstabelle: unbekannte Schlüssel sind nie „nicht erreichbar“', () {
      expect(ContactReach.of(keysKnown: false, encryptable: const <bool>[]), ContactReachability.unknown);
      expect(ContactReach.of(keysKnown: false, encryptable: const <bool>[true]), ContactReachability.unknown, reason: 'veralteter Stand zählt nicht');
      expect(ContactReach.of(keysKnown: true, encryptable: const <bool>[]), ContactReachability.notReachable);
      expect(ContactReach.of(keysKnown: true, encryptable: const <bool>[false, false]), ContactReachability.notReachable);
      expect(ContactReach.of(keysKnown: true, encryptable: const <bool>[false, true]), ContactReachability.reachable);
      expect(ContactReach.of(keysKnown: true, encryptable: const <bool>[true]), ContactReachability.reachable);
    });
  });

  group('Gruppen (K4-1)', () {
    GroupRecord grp(String id, {bool deleted = false}) => GroupRecord(id: id, version: 1, updatedAt: t, deleted: deleted);

    test('groups aus aktiven Datensätzen; Löschmarken fehlen; unveränderlich; Standard leer', () {
      final p = ContactPolicy.of(<ContactRecord>[grp('!a:example.org'), grp('!b:example.org', deleted: true), c(carla, ContactState.accepted)]);
      expect(p.groups, <String>{'!a:example.org'});
      expect(p.contacts.keys, <String>[carla]);
      expect(() => p.groups.add('!x:example.org'), throwsUnsupportedError);
      expect(ContactPolicy.off.groups, isEmpty);
    });

    test('== unterscheidet den Gruppen-Datensatz (löst setContactPolicy aus)', () {
      final base = ContactPolicy.of(<ContactRecord>[c(carla, ContactState.accepted)]);
      final withGroup = ContactPolicy.of(<ContactRecord>[c(carla, ContactState.accepted), grp('!a:example.org')]);
      expect(withGroup, isNot(base));
      expect(base, isNot(withGroup));
      expect(withGroup, ContactPolicy.of(<ContactRecord>[grp('!a:example.org'), c(carla, ContactState.accepted)]));
      expect(
        ContactPolicy.of(<ContactRecord>[grp('!a:example.org')]),
        isNot(ContactPolicy.of(<ContactRecord>[grp('!b:example.org')])),
        reason: 'gleiche Zahl, andere Räume',
      );
    });

    test('hashCode unterscheidet sich bei anderer Zahl der Gruppen', () {
      final none = ContactPolicy.of(const <ContactRecord>[]);
      final one = ContactPolicy.of(<ContactRecord>[grp('!a:example.org')]);
      final two = ContactPolicy.of(<ContactRecord>[grp('!a:example.org'), grp('!b:example.org')]);
      expect(one.hashCode, isNot(none.hashCode));
      expect(two.hashCode, isNot(one.hashCode));
      expect(one.hashCode, ContactPolicy.of(<ContactRecord>[grp('!a:example.org')]).hashCode);
    });
  });

  group('ContactNames.groupTitle (K4-1)', () {
    test('bereinigt Steuer-, Bidi- und Trennzeichen, höchstens 60 Zeichen, leer bei nichts Brauchbarem', () {
      expect(ContactNames.groupTitle('  Familie  Müller '), 'Familie Müller');
      expect(ContactNames.groupTitle('A · B‮​'), 'A B');
      expect(ContactNames.groupTitle('x' * 100).length, 60);
      expect(ContactNames.groupTitle(null), '');
      expect(ContactNames.groupTitle('‮​'), '');
      expect(ContactNames.maxGroupName, 60);
    });

    test('der Gruppenname lässt sich mit collides gegen Familiennamen vergleichen (Aufrufer gibt den Familiennamen mit)', () {
      expect(ContactNames.collides(ContactNames.groupTitle('Familie Müller'), <String>['Familie Muller']), isTrue);
      expect(ContactNames.collides(ContactNames.groupTitle('Skatrunde'), <String>['Familie Muller']), isFalse);
    });
  });
}
