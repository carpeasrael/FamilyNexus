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
    expect(ContactPolicy.of(<ContactRecord>[GroupRecord(id: '!g:example.org', version: 1, updatedAt: t)]), ContactPolicy.off, reason: 'Gruppen sind kein Kontakt');
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
}
