import 'package:family_nexus/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);
  const nonce = '0123456789abcdef0123456789abcdef';
  String make({Duration validity = InviteLink.defaultValidity}) => InviteLink.create(
        roomId: '!abc123:matrix.org',
        via: 'matrix.org',
        inviter: '@mod:matrix.org',
        now: now,
        validity: validity,
        nonce: nonce,
      );

  test('Roundtrip', () {
    final l = InviteLink.tryParse(make(), now: now)!;
    expect(l.roomId, '!abc123:matrix.org');
    expect(l.via, 'matrix.org');
    expect(l.inviter, '@mod:matrix.org');
    expect(l.expires, now.add(const Duration(hours: 24)));
    expect(l.isValidAt(now), isTrue);
    expect(l.isValidAt(now.add(const Duration(hours: 24))), isFalse, reason: 'Ablauf ist exklusiv');
    expect(l.isValidAt(now.add(const Duration(days: 2))), isFalse);
  });

  test('Port in via ist erlaubt', () {
    final s = InviteLink.create(roomId: '!a:h.example:8448', via: 'h.example:8448', inviter: '@m:h.example:8448', now: now, nonce: nonce);
    expect(InviteLink.tryParse(s, now: now), isNotNull);
  });

  test('Erzeugung validiert Eingaben und Gültigkeit', () {
    expect(() => InviteLink.create(roomId: 'x', via: 'a.org', inviter: '@m:a.org', now: now, nonce: nonce), throwsArgumentError);
    expect(() => InviteLink.create(roomId: '!a:a.org', via: 'a b', inviter: '@m:a.org', now: now, nonce: nonce), throwsArgumentError);
    expect(() => InviteLink.create(roomId: '!a:a.org', via: 'a.org', inviter: 'kein-mxid', now: now, nonce: nonce), throwsArgumentError);
    expect(() => make(validity: const Duration(days: 8)), throwsArgumentError);
    expect(() => make(validity: Duration.zero), throwsArgumentError);
  });

  group('Ablehnung manipulierter/falscher Links', () {
    final good = make();
    final bad = <String, String>{
      'anderes Schema': good.replaceFirst('familynexus', 'https'),
      'anderer Host': good.replaceFirst('//join', '//evil'),
      'Version 3': good.replaceFirst('v=2', 'v=3'),
      'Version fehlt': good.replaceFirst('v=2&', ''),
      'Version 1 mit Familienname': '${good.replaceFirst('v=2', 'v=1')}&f=Familie',
      'doppelter Familienname': '$good&f=A&f=B',
      'unbekanntes Feld in Version 2': '$good&hs=https%3A%2F%2Fevil.example',
      'Raum fehlt': good.replaceFirst('room=%21abc123%3Amatrix.org&', ''),
      'zusätzliches Feld': '$good&x=1',
      'doppelter Parameter': '$good&exp=1',
      'Fragment': '$good#frag',
      'Nutzerinfo': good.replaceFirst('//join', '//u:p@join'),
      'Port am Host': good.replaceFirst('//join', '//join:80'),
      'Pfad': good.replaceFirst('//join?', '//join/x?'),
      'ungültige Raum-ID': good.replaceFirst('%21abc123%3Amatrix.org', 'abc'),
      'Alias statt Raum-ID': good.replaceFirst('%21abc123%3Amatrix.org', '%23alias%3Amatrix.org'),
      'via mit Pfad': good.replaceFirst('via=matrix.org', 'via=matrix.org%2Fx'),
      'Einladender ungültig': good.replaceFirst('%40mod%3Amatrix.org', 'mod'),
      'exp kein Zahl': good.replaceAll(RegExp(r'exp=\d+'), 'exp=abc'),
      'exp negativ': good.replaceAll(RegExp(r'exp=\d+'), 'exp=-5'),
      'exp zu weit in der Zukunft': good.replaceAll(RegExp(r'exp=\d+'), 'exp=${now.add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000}'),
      'Nonce fehlt': good.replaceAll(RegExp(r'&n=[0-9a-f]+'), ''),
      'Nonce ungültig': good.replaceAll(RegExp(r'n=[0-9a-f]+'), 'n=XYZ'),
      'exp riesig (Überlauf)': good.replaceAll(RegExp(r'exp=\d+'), 'exp=99999999999999999'),
      'via passt nicht zum Raum': good.replaceFirst('via=matrix.org', 'via=evil.example'),
      'leer': '',
      'Müll': 'hallo welt',
      'zu lang': '$good&${'a' * 800}=1',
    };
    for (final e in bad.entries) {
      test(e.key, () => expect(InviteLink.tryParse(e.value, now: now), isNull));
    }
  });

  test('via muss zur Raum-ID passen und darf nicht lokal/IP sein (außer eigener Server)', () {
    expect(InviteLink.viaMatchesRoom('!a:matrix.org', 'matrix.org'), isTrue);
    expect(InviteLink.viaMatchesRoom('!a:matrix.org', 'evil.example'), isFalse);
    expect(InviteLink.viaMatchesRoom('!a:localhost', 'localhost'), isFalse);
    expect(InviteLink.viaMatchesRoom('!a:192.168.0.5', '192.168.0.5'), isFalse);
    expect(InviteLink.viaMatchesRoom('!a:localhost:8448', 'localhost:8448', ownHost: 'localhost:8448'), isTrue);
  });

  test('abgelaufener Link wird gelesen, aber als ungültig erkannt', () {
    final l = InviteLink.tryParse(make(), now: now.add(const Duration(days: 3)))!;
    expect(l.isValidAt(now.add(const Duration(days: 3))), isFalse);
  });

  test('Leerraum um den Link wird toleriert', () {
    expect(InviteLink.tryParse('  ${make()}\n', now: now), isNotNull);
  });

  group('Version 2 (E-56): Namen für Neulinge', () {
    String v2({String? family = 'Familie Müller', String? by = 'Anna'}) => InviteLink.create(
          roomId: '!abc123:matrix.org',
          via: 'matrix.org',
          inviter: '@mod:matrix.org',
          now: now,
          nonce: nonce,
          familyName: family,
          inviterName: by,
        );

    test('TP-INV-01 Roundtrip mit Familien- und Einladendenname', () {
      final s = v2();
      expect(s, contains('v=2'));
      final l = InviteLink.tryParse(s, now: now)!;
      expect(l.familyName, 'Familie Müller');
      expect(l.inviterName, 'Anna');
      expect(l.inviterServer, 'matrix.org');
    });

    test('TP-INV-02 Links der Version 1 bleiben gültig', () {
      final exp = now.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000;
      final v1 = 'familynexus://join?v=1&room=%21abc123%3Amatrix.org&via=matrix.org&inv=%40mod%3Amatrix.org&exp=$exp&n=$nonce';
      final l = InviteLink.tryParse(v1, now: now)!;
      expect(l.familyName, isNull);
      expect(l.inviterName, isNull);
      expect(l.isValidAt(now), isTrue);
    });

    test('TP-INV-04 Namen werden bereinigt und begrenzt; leere Namen entfallen', () {
      final l = InviteLink.tryParse(v2(family: '\u202Egefährlich\u0000 ${'x' * 80}', by: '   '), now: now)!;
      expect(l.familyName!.contains('\u202E'), isFalse);
      expect(l.familyName!.contains('\u0000'), isFalse);
      expect(l.familyName!.runes.length, lessThanOrEqualTo(InviteLink.maxNameLength));
      expect(l.inviterName, isNull);
      expect(v2(family: null, by: null), isNot(contains('f=')));
    });

    test('TP-INV-06 Link mit langen Namen passt in die Längengrenze (QR lesbar)', () {
      final s = InviteLink.create(
        roomId: '!${'r' * 40}:${'h' * 40}.example',
        via: '${'h' * 40}.example',
        inviter: '@${'u' * 40}:${'h' * 40}.example',
        now: now,
        nonce: nonce,
        familyName: 'Ü' * 40,
        inviterName: 'Ö' * 40,
      );
      expect(s.length, lessThanOrEqualTo(InviteLink.maxLength));
      expect(InviteLink.tryParse(s, now: now), isNotNull);
    });
  
    test('R13 viele Emoji in den Namen: Link wird gekürzt statt zu lang, bleibt lesbar', () {
      final s = InviteLink.create(
        roomId: '!${'r' * 40}:${'h' * 40}.example',
        via: '${'h' * 40}.example',
        inviter: '@${'u' * 40}:${'h' * 40}.example',
        now: now,
        nonce: nonce,
        familyName: '👨‍👩‍👧' * 20,
        inviterName: '🦄' * 40,
      );
      expect(s.length, lessThanOrEqualTo(InviteLink.maxLength));
      expect(InviteLink.tryParse(s, now: now), isNotNull);
    });

    test('R14 Schreibweise wird vereinheitlicht (Schema in Kleinbuchstaben) und bleibt lesbar', () {
      final raw = v2().replaceFirst('familynexus', 'FamilyNexus');
      expect(InviteLink.tryParse(raw, now: now), isNotNull);
      final n = InviteLink.normalized(' $raw ');
      expect(n, startsWith('familynexus://join?'));
      expect(InviteLink.tryParse(n, now: now)!.familyName, 'Familie Müller');
    });
  });
}
