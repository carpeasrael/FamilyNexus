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
    expect(l.expires, now.add(InviteLink.defaultValidity));
    expect(InviteLink.defaultValidity, const Duration(days: 3), reason: 'Issue #6: Standard 3 Tage');
    expect(l.isValidAt(now), isTrue);
    expect(l.isValidAt(now.add(InviteLink.defaultValidity)), isFalse, reason: 'Ablauf ist exklusiv');
    expect(l.isValidAt(now.add(const Duration(days: 4))), isFalse);
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
      'Version 4': good.replaceFirst('v=3', 'v=4'),
      'Version fehlt': good.replaceFirst('v=3&', ''),
      'Version 1 mit Familienname': '${good.replaceFirst('v=3', 'v=1')}&f=Familie',
      'Version 2 mit Konto-Server': good.replaceFirst('v=3', 'v=2'),
      'Konto-Server fehlt (Version 3)': good.replaceFirst(RegExp(r'srv=[^&]*&'), ''),
      'Konto-Server ungültig': good.replaceFirst(RegExp(r'srv=[^&]*'), 'srv=a%20b'),
      'Konto-Server mit Pfad': good.replaceFirst(RegExp(r'srv=[^&]*'), 'srv=evil.example%2Fx'),
      'Konto-Server doppelt': '\$good&srv=evil.example',
      'Konto-Server im Heimnetz': good.replaceFirst(RegExp(r'srv=[^&]*'), 'srv=192.168.0.2'),
      'doppelter Familienname': '$good&f=A&f=B',
      'unbekanntes Feld in Version 3': '$good&hs=https%3A%2F%2Fevil.example',
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

  group('Version 3 (E-56, E-63): Namen und Konto-Server für Neulinge', () {
    String v3({String? family = 'Familie Müller', String? by = 'Anna'}) => InviteLink.create(
          roomId: '!abc123:matrix.org',
          via: 'matrix.org',
          inviter: '@mod:matrix.org',
          now: now,
          nonce: nonce,
          familyName: family,
          inviterName: by,
        );

    test('TP-INV-01 Roundtrip mit Familien- und Einladendenname', () {
      final s = v3();
      expect(s, contains('v=3'));
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

    test('TP-INV-07 Konto-Server (srv): Standard ist der Server des Einladenden, ein anderer wird ausdrücklich übernommen', () {
      final same = InviteLink.tryParse(v3(), now: now)!;
      expect(same.accountServer, 'matrix.org');
      expect(v3(), contains('srv=matrix.org'));

      final other = InviteLink.create(
        roomId: '!abc123:matrix.org',
        via: 'matrix.org',
        inviter: '@mod:matrix.org',
        now: now,
        nonce: nonce,
        accountServer: 'familie.example:8448',
      );
      final l = InviteLink.tryParse(other, now: now)!;
      expect(l.accountServer, 'familie.example:8448');
      expect(l.inviterServer, 'matrix.org', reason: 'Einladender und Konto-Server sind getrennte Angaben');
    });

    test('TP-INV-08 Links der Version 2 bleiben gültig; Konto-Server ist dann der des Einladenden', () {
      final exp = now.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000;
      final v2 = 'familynexus://join?v=2&room=%21abc123%3Aclan.example&via=clan.example&inv=%40mod%3Aclan.example&exp=$exp&n=$nonce&f=Clan&by=Mo';
      final l = InviteLink.tryParse(v2, now: now)!;
      expect(l.accountServer, 'clan.example');
      expect(InviteLink.check(v2, now: now).ok, isTrue);
    });

    test('TP-INV-09 Konto-Server im Heimnetz: nur der eigene beim Erzeugen, ohne Prüfung nur über check', () {
      String make({String? own}) => InviteLink.create(
            roomId: '!a:nas',
            via: 'nas',
            inviter: '@mod:nas',
            now: now,
            nonce: nonce,
            ownHost: own,
          );
      expect(() => make(), throwsArgumentError, reason: 'fremder Heimnetz-Server darf nicht in einen Link');
      final s = make(own: 'nas');
      expect(InviteLink.tryParse(s, now: now), isNull, reason: 'ohne eigenen Server nicht still annehmen');
      expect(InviteLink.tryParse(s, now: now, ownHost: 'nas')!.accountServer, 'nas');
      final c = InviteLink.check(s, now: now);
      expect(c.ok, isTrue);
      expect(c.link!.accountServer, 'nas');
      expect(InviteLink.isLocalServer(c.link!.accountServer), isTrue, reason: 'Oberfläche fragt vor dem Verbinden nach');
    });

    test('TP-INV-04 Namen werden bereinigt und begrenzt; leere Namen entfallen', () {
      final l = InviteLink.tryParse(v3(family: '\u202Egefährlich\u0000 ${'x' * 80}', by: '   '), now: now)!;
      expect(l.familyName!.contains('\u202E'), isFalse);
      expect(l.familyName!.contains('\u0000'), isFalse);
      expect(l.familyName!.runes.length, lessThanOrEqualTo(InviteLink.maxNameLength));
      expect(l.inviterName, isNull);
      expect(v3(family: null, by: null), isNot(contains('f=')));
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
      final raw = v3().replaceFirst('familynexus', 'FamilyNexus');
      expect(InviteLink.tryParse(raw, now: now), isNotNull);
      final n = InviteLink.normalized(' $raw ');
      expect(n, startsWith('familynexus://join?'));
      expect(InviteLink.tryParse(n, now: now)!.familyName, 'Familie Müller');
    });
  });
}
