import 'dart:convert';

import 'package:family_nexus/domain/contacts.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K2b (E-114): Format, Konfliktregel und Kennungs-Eingabe der Kontakte.
void main() {
  const me = '@ich:hs.example';
  final t0 = DateTime.utc(2026, 11, 25, 10);
  final contact = Contact(id: '@carla:example.org', state: ContactState.accepted, nick: 'Carla', room: '!raum:example.org', version: 3, updatedAt: t0);
  final grp = GroupRecord(id: '!gruppe:example.org', version: 2, updatedAt: t0);
  final prefs = ContactPrefs(enabled: true, version: 4, updatedAt: t0);

  Map<String, Object?> content(ContactRecord r) => ContactCodec.encode(r);
  ContactRecord? decode(Map<String, Object?> c, {String sender = me, String who = me, DateTime? server}) =>
      ContactCodec.decode(c, sender: sender, me: who, serverTime: server ?? t0);

  group('Codec', () {
    test('Roundtrip je Art; Ereignis und Ablage', () {
      for (final r in <ContactRecord>[contact, grp, prefs]) {
        expect(decode(content(r)), r, reason: '${r.kind}');
        expect(ContactCodec.decodeStored(content(r)), r, reason: 'Ablage ${r.kind}');
      }
      expect(content(contact)['v'], 1);
      expect(content(contact)['rec'], 'contact');
    });

    test('nur das eigene Konto ist ein zulässiger Absender; leeres me lehnt fail-closed ab', () {
      expect(decode(content(contact), sender: '@fremd:example.org'), isNull);
      expect(decode(content(contact), sender: '', who: ''), isNull);
      expect(decode(content(contact), who: ''), isNull);
      expect(decode(content(contact), sender: 'kein-konto', who: 'kein-konto'), isNull);
    });

    test('Zeitstempel: höchstens zwei Tage neben der Serverzeit; die Ablage prüft ihn nicht', () {
      expect(decode(content(contact), server: t0.add(const Duration(days: 2))), isNotNull);
      expect(decode(content(contact), server: t0.add(const Duration(days: 2, seconds: 1))), isNull);
      expect(decode(content(contact), server: t0.subtract(const Duration(days: 2, seconds: 1))), isNull);
      expect(ContactCodec.decodeStored(content(contact)), contact);
    });

    test('jede Verletzung einzeln: Schema, Art, Felder, Typen', () {
      Map<String, Object?> m([Map<String, Object?> change = const <String, Object?>{}, List<String> drop = const <String>[]]) =>
          <String, Object?>{...content(contact), ...change}..removeWhere((k, _) => drop.contains(k));
      final bad = <String, Map<String, Object?>>{
        'v 2': m(<String, Object?>{'v': 2}),
        'v fehlt': m(const <String, Object?>{}, <String>['v']),
        'rec unbekannt': m(<String, Object?>{'rec': 'fremd'}),
        'rec Zahl': m(<String, Object?>{'rec': 1}),
        'id Zahl': m(<String, Object?>{'id': 5}),
        'id keine Nutzer-ID': m(<String, Object?>{'id': 'carla'}),
        'id nicht kanonisch (Servername groß)': m(<String, Object?>{'id': '@carla:Example.ORG'}),
        'state unbekannt': m(<String, Object?>{'state': 'friend'}),
        'state Zahl': m(<String, Object?>{'state': 1}),
        'nick Zahl': m(<String, Object?>{'nick': 7}),
        'nick zu lang': m(<String, Object?>{'nick': 'x' * 41}),
        'nick mit Steuerzeichen': m(<String, Object?>{'nick': 'a\u0007b'}),
        'nick mit Bidi-Zeichen': m(<String, Object?>{'nick': 'a\u202eb'}),
        'room keine Raum-ID': m(<String, Object?>{'room': 'raum'}),
        'room Zahl': m(<String, Object?>{'room': 5}),
        'ver 0': m(<String, Object?>{'ver': 0}),
        'ver negativ': m(<String, Object?>{'ver': -1}),
        'ver zu groß': m(<String, Object?>{'ver': ContactLimits.maxVersion + 1}),
        'ver Kommazahl': m(<String, Object?>{'ver': 1.5}),
        'ver Text': m(<String, Object?>{'ver': '3'}),
        'ts Kommazahl': m(<String, Object?>{'ts': 1.5}),
        'ts bool': m(<String, Object?>{'ts': true}),
        'ts Überlauf': m(<String, Object?>{'ts': 9000000000000000}),
        'del Zahl': m(<String, Object?>{'del': 0}),
        'del fehlt': m(const <String, Object?>{}, <String>['del']),
      };
      for (final e in bad.entries) {
        expect(ContactCodec.decodeStored(e.value), isNull, reason: e.key);
        expect(decode(e.value), isNull, reason: e.key);
      }
    });

    test('Gruppe und Einstellung: eigene Regeln', () {
      expect(ContactCodec.decodeStored(<String, Object?>{...content(grp), 'id': '@kein:raum'}), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'id': 'andere'}), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'enabled': 1}), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'del': true}), isNull, reason: 'die Einstellung wird nie gelöscht');
    });

    test('Größe des Inhalts wird vor dem Zerlegen geprüft', () {
      final big = <String, Object?>{...content(contact), 'extra': 'x' * ContactLimits.maxContentBytes};
      expect(ContactCodec.decodeStored(big), isNull);
      expect(utf8.encode(json.encode(content(contact))).length, lessThan(ContactLimits.maxContentBytes));
    });

    test('encode lehnt ungültige Datensätze ab', () {
      expect(() => ContactCodec.encode(Contact(id: 'x', state: ContactState.accepted, version: 1, updatedAt: t0)), throwsStateError);
      expect(() => ContactCodec.encode(contact.copyWith(version: 0)), throwsStateError);
      expect(() => ContactCodec.encode(contact.copyWith(nick: 'x' * 41)), throwsStateError);
    });
  });

  group('Grenzwerte und Randfälle des Codecs', () {
    test('Grenzen: ver == maxVersion und ts == ±8,64e15 sind gültig, ein Schritt darüber nicht', () {
      Map<String, Object?> m(Map<String, Object?> change) => <String, Object?>{...content(contact), ...change};
      expect(ContactCodec.decodeStored(m(<String, Object?>{'ver': ContactLimits.maxVersion})), isNotNull);
      expect(ContactCodec.decodeStored(m(<String, Object?>{'ver': ContactLimits.maxVersion + 1})), isNull);
      expect(ContactCodec.decodeStored(m(<String, Object?>{'ts': 8640000000000000})), isNotNull);
      expect(ContactCodec.decodeStored(m(<String, Object?>{'ts': -8640000000000000})), isNotNull);
      expect(ContactCodec.decodeStored(m(<String, Object?>{'ts': 8640000000000001})), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'ver': ContactLimits.maxVersion}), isNotNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'ver': ContactLimits.maxVersion + 1}), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'ver': 0}), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(prefs), 'ts': 8640000000000001}), isNull);
      expect(() => ContactCodec.encode(prefs.copyWith(version: 0)), throwsStateError);
    });

    test('Spitzname: genau 40 Zeichen ist gültig, 41 nicht; Zeichen statt Bytes; kein Randleerraum, kein doppelter Leerraum', () {
      Contact withNick(String n) => contact.copyWith(nick: n);
      expect(withNick('x' * 40).validate(), isEmpty);
      expect(withNick('x' * 41).validate(), contains('nick'));
      expect(withNick('\u{1F600}' * 40).validate(), isEmpty, reason: '40 Zeichen, auch wenn jedes zwei UTF-16-Einheiten hat');
      expect(withNick('\u{1F600}' * 41).validate(), contains('nick'));
      expect(withNick(' Carla').validate(), contains('nick'));
      expect(withNick('Carla ').validate(), contains('nick'));
      expect(withNick('a  b').validate(), contains('nick'));
      expect(withNick('').validate(), isEmpty, reason: 'leer ist erlaubt');
    });

    test('rec unbekannt wird auch mit gültiger Raum-ID als Kennung abgelehnt (nicht als Gruppe gelesen)', () {
      expect(ContactCodec.decodeStored(<String, Object?>{...content(grp), 'rec': 'fremd'}), isNull);
    });

    test('Größe zählt UTF-8-Bytes, nicht Zeichen; nicht als JSON darstellbarer Inhalt liefert null statt einer Ausnahme', () {
      final multibyte = <String, Object?>{...content(contact), 'extra': '\u00e4' * 1100};
      expect(multibyte['extra'].toString().length, lessThan(ContactLimits.maxContentBytes));
      expect(ContactCodec.decodeStored(multibyte), isNull);
      expect(ContactCodec.decodeStored(<String, Object?>{...content(contact), 'extra': DateTime(2026)}), isNull);
    });
  });

  group('Konfliktregel (Totalordnung)', () {
    test('höhere Version gewinnt, dann späterer Zeitstempel', () {
      expect(Contacts.supersedes(contact.copyWith(version: 4), contact), isTrue);
      expect(Contacts.supersedes(contact, contact.copyWith(version: 4)), isFalse);
      expect(Contacts.supersedes(contact.copyWith(updatedAt: t0.add(const Duration(seconds: 1))), contact), isTrue);
      expect(Contacts.supersedes(contact, contact), isFalse, reason: 'Gleichheit gewinnt nie');
    });

    test('gleiche Version und Zeit: jede andere Fassung ist eindeutig geordnet (Zustand, Löschmarke, Raum, Name)', () {
      final variants = <Contact>[
        contact,
        contact.copyWith(state: ContactState.blocked),
        contact.copyWith(state: ContactState.outgoing),
        contact.copyWith(deleted: true),
        contact.copyWith(room: null),
        contact.copyWith(nick: 'Anna'),
      ];
      for (final a in variants) {
        for (final b in variants) {
          if (a == b) {
            expect(Contacts.compare(a, b), 0);
          } else {
            expect(Contacts.compare(a, b), isNot(0), reason: '$a gegen $b');
            expect(Contacts.compare(a, b), -Contacts.compare(b, a).sign * Contacts.compare(a, b).abs().sign, reason: 'antisymmetrisch');
          }
        }
      }
      // Gewinner ist unabhängig von der Reihenfolge der Eingänge.
      final winners = <Contact>{};
      for (final order in <List<int>>[<int>[0, 1, 2, 3, 4, 5], <int>[5, 4, 3, 2, 1, 0], <int>[2, 0, 5, 1, 4, 3], <int>[3, 3, 1, 5, 0, 2]]) {
        var w = variants[order.first];
        for (final i in order) {
          if (Contacts.supersedes(variants[i], w)) w = variants[i];
        }
        winners.add(w);
      }
      expect(winners, hasLength(1));
    });

    test('die Version geht vor dem Zeitstempel; bei gleicher Version entscheidet der spätere Zeitstempel vor dem Inhalt', () {
      final olderButHigher = contact.copyWith(version: 4, updatedAt: t0.subtract(const Duration(days: 1)));
      expect(Contacts.supersedes(olderButHigher, contact), isTrue, reason: 'höhere Version gewinnt trotz älterem ts');
      expect(Contacts.supersedes(contact, olderButHigher), isFalse);
      final laterOther = contact.copyWith(state: ContactState.outgoing, nick: 'A', updatedAt: t0.add(const Duration(seconds: 1)));
      final earlierOther = contact.copyWith(state: ContactState.blocked, nick: 'Z');
      expect(Contacts.supersedes(laterOther, earlierOther), isTrue, reason: 'späterer ts vor Zustand und Name');
      expect(Contacts.supersedes(earlierOther, laterOther), isFalse);
    });

    test('Einstellung: Wert entscheidet bei gleicher Version und Zeit', () {
      final on = ContactPrefs(enabled: true, version: 1, updatedAt: t0);
      final off = ContactPrefs(enabled: false, version: 1, updatedAt: t0);
      expect(Contacts.compare(on, off), isNot(0));
    });
  });

  group('ContactId.parse', () {
    test('Großbuchstaben im lokalen Teil sind keine gültige Nutzer-ID (Matrix-Regel): null, nie stillschweigend umgedeutet', () {
      expect(ContactId.parse('@Carla:example.org'), isNull);
      expect(ContactId.parse('https://matrix.to/#/@Carla:example.org'), isNull);
    });

    test('Nutzer-ID: getrimmt, Servername klein, lokaler Teil unverändert', () {
      expect(ContactId.parse('@carla:example.org'), '@carla:example.org');
      expect(ContactId.parse('  @carla:example.org \n'), '@carla:example.org');
      expect(ContactId.parse('@carla:Example.ORG'), '@carla:example.org');
      expect(ContactId.parse('@carla:example.org:8448'), '@carla:example.org:8448');
    });

    test('matrix.to-Link: einfach kodiert erlaubt, Parameter verworfen', () {
      expect(ContactId.parse('https://matrix.to/#/@carla:example.org'), '@carla:example.org');
      expect(ContactId.parse('https://matrix.to/#/@carla:example.org?via=example.org'), '@carla:example.org');
      expect(ContactId.parse('https://matrix.to/#/%40carla%3Aexample.org'), '@carla:example.org');
      expect(ContactId.parse('https://matrix.to/#/%40carla%3Aexample.org?via=a.b&via=c.d'), '@carla:example.org');
    });

    test('feindliche und falsche Eingaben liefern null', () {
      final bad = <String>[
        '',
        '   ',
        'carla',
        'carla@example.org',
        '@carla',
        '@:example.org',
        '@carla:',
        '@carla:example.org @ben:example.org',
        '@carla:example.org\n@ben:example.org',
        '@carla:example.org\u0000',
        '@carla:exam\u202eple.org',
        '@carla:example.org\u200b',
        '@carla:example.org\u2066',
        '@ca rla:example.org',
        'javascript:alert(1)',
        'http://matrix.to/#/@carla:example.org',
        'ftp://matrix.to/#/@carla:example.org',
        'https://matrix.to.evil.example/#/@carla:example.org',
        'https://evil-matrix.to/#/@carla:example.org',
        'https://user@matrix.to/#/@carla:example.org',
        'https://matrix.to:8443/#/@carla:example.org',
        'https://matrix.to/@carla:example.org',
        'https://matrix.to/other/#/@carla:example.org',
        'https://matrix.to/#@carla:example.org',
        'https://matrix.to/#x@carla:example.org',
        'https://matrix.to/#/@car/la:example.org',
        'https://matrix.to/#/!raum:example.org',
        'https://matrix.to/#/#alias:example.org',
        'https://matrix.to/#/%2540carla%253Aexample.org',
        'https://matrix.to/#/@carla:example.org/@ben:example.org',
        'https://matrix.to/#/%E0%A4%A',
        '@${'a' * 300}:example.org',
        'https://matrix.to/#/@carla:example.org?${'x' * 700}',
      ];
      for (final b in bad) {
        expect(ContactId.parse(b), isNull, reason: b.replaceAll(RegExp(r'[\u0000-\u001f -⁯]'), '?'));
      }
    });
  });
}
