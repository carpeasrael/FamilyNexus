import 'dart:convert';

import 'package:family_nexus/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/invite_links.dart';

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
  final defaultExp = now.add(InviteLink.defaultValidity).millisecondsSinceEpoch ~/ 1000;
  String fields({
    String room = '!abc123:matrix.org',
    String via = 'matrix.org',
    String? srv = 'matrix.org',
    String inv = '@mod:matrix.org',
    int? exp,
    String? family,
    String? by,
    String n = nonce,
  }) =>
      inviteFields(room: room, via: via, srv: srv, inv: inv, exp: exp ?? defaultExp, family: family, by: by, n: n);

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

  // Die Manipulationen treffen die Felder im Klartext, also Version 3; Version 4 folgt in der nächsten Gruppe.
  group('Ablehnung manipulierter/falscher Links', () {
    final good = v3Link(fields());
    final bad = <String, String>{
      'anderes Schema': good.replaceFirst('familynexus', 'https'),
      'anderer Host': good.replaceFirst('//join', '//evil'),
      'Version 4 mit Feldern im Klartext': good.replaceFirst('v=3', 'v=4'),
      'Version 5': good.replaceFirst('v=3', 'v=5'),
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

  group('Ablehnung manipulierter Links der Version 4 (E-79)', () {
    final inner = fields();
    final payload = v4Payload(inner);
    final bad = <String, String>{
      'kaputtes base64': 'familynexus://join?v=4&d=!!!!',
      'd fehlt': 'familynexus://join?v=4',
      'd leer': 'familynexus://join?v=4&d=',
      'Padding': '${v4(inner)}=',
      'Padding prozentkodiert': '${v4(inner)}%3D',
      'Länge mod 4 = 1': 'familynexus://join?v=4&d=${payload.substring(0, payload.length - (payload.length % 4))}A',
      'Pluszeichen statt Minus': 'familynexus://join?v=4&d=+/8',
      'Schrägstrich im Payload': '${v4(inner)}/',
      'Zusatzfeld neben d': '${v4(inner)}&x=1',
      'Felder im Klartext neben d': '${v4(inner)}&room=%21abc123%3Amatrix.org',
      'd doppelt': '${v4(inner)}&d=$payload',
      'doppeltes inneres Feld': v4('$inner&n=$nonce'),
      'doppelter innerer Server': v4(fields().replaceFirst('srv=', 'srv=evil.example&srv=')),
      'inneres v=1': v4('v=1&${fields(srv: null)}'),
      'inneres v=4': v4('v=4&$inner'),
      'inneres v=9': v4('v=9&$inner'),
      'ungültiges UTF-8 als Prozentkodierung': v4(fields(by: 'x').replaceFirst('by=x', 'by=%FF')),
      'ungültiges UTF-8 als rohes Byte': 'familynexus://join?v=4&d=${base64Url.encode(<int>[0xFF]).replaceAll('=', '')}',
      'ungültiges UTF-8 am Ende': 'familynexus://join?v=4&d=${base64Url.encode(<int>[...utf8.encode(inner), 0xFF]).replaceAll('=', '')}',
      'inneres f': v4(fields(family: 'Familie')),
      'unbekanntes inneres Feld': v4('$inner&x=1'),
      '%A in room': v4(inner.replaceFirst('abc123', 'abc%A')),
      '# in room': v4(inner.replaceFirst('abc123', 'abc#')),
      '%A in n': v4(inner.replaceFirst(nonce, '${nonce.substring(2)}%A')),
      '# in n': v4(inner.replaceFirst(nonce, '${nonce.substring(1)}#')),
      'leeres Inneres': 'familynexus://join?v=4&d=${v4Payload('=')}',
      'Link ohne srv': v4(fields(srv: null)),
      'srv ungültig': v4(fields(srv: 'evil.example/x')),
      'srv im Heimnetz': v4(fields(srv: '192.168.0.2')),
      'falscher Server in via': v4(fields(via: 'evil.example')),
      'via IP': v4(fields(room: '!abc123:192.168.0.2', via: '192.168.0.2')),
      'Einladender ungültig': v4(fields(inv: 'mod')),
      'exp riesig': v4(fields(exp: 99999999999999)),
      'Nonce ungültig': v4(fields(n: 'XYZ')),
      'zu lang': v4(fields(by: 'a' * 800)),
    };
    for (final e in bad.entries) {
      test(e.key, () => expect(InviteLink.tryParse(e.value, now: now), isNull));
    }

    test('Länge mod 4 = 1 wird schon vor dem Dekodieren abgelehnt', () {
      final d = 'A' * 5;
      expect(d.length % 4, 1);
      expect(InviteLink.tryParse('familynexus://join?v=4&d=$d', now: now), isNull);
    });

    test('Kontrolle: das unveränderte Innere wird angenommen', () {
      expect(InviteLink.tryParse(v4(inner), now: now), isNotNull);
    });

    test('%A und # im Namen bleiben Text, Uri(query:) kodiert sie nur um', () {
      final l = InviteLink.tryParse(v4(fields(by: 'x').replaceFirst('by=x', 'by=100%A#1')), now: now)!;
      expect(l.inviterName, '100%A#1');
    });

    test('abgelaufen: gelesen, aber als abgelaufen gemeldet', () {
      final old = v4(fields(exp: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000));
      expect(InviteLink.tryParse(old, now: now)!.isValidAt(now), isFalse);
      expect(InviteLink.check(old, now: now).problem, InviteLinkProblem.expired);
    });

    test('Version 5: neuere Version statt beschädigt', () {
      expect(InviteLink.check('familynexus://join?v=5&d=$payload', now: now).problem, InviteLinkProblem.newerVersion);
    });

    test('überlanger Server: create wirft, statt einen zu langen Link zu erzeugen', () {
      final host = '${'h' * 200}.example';
      final room = '!a:$host';
      final inv = '@m:$host';
      expect(InviteLink.viaMatchesRoom(room, host), isTrue, reason: 'Kontrolle: die Angaben selbst sind gültig');
      expect(() => InviteLink.create(roomId: room, via: host, inviter: inv, now: now, nonce: nonce, accountServer: host, inviterName: 'Anna'), throwsArgumentError);
    });
  });

  group('Keine lesbaren Angaben im Link (E-79)', () {
    const room = '!raumgeheim:familie-mueller.example';
    const server = 'familie-mueller.example';
    const inviter = '@annamueller:familie-mueller.example';
    String link(String? by) => InviteLink.create(roomId: room, via: server, inviter: inviter, now: now, nonce: nonce, inviterName: by);

    test('Link und Weblink enthalten weder Raum, Matrix-ID, Server noch Namen, auch nicht prozentkodiert', () {
      final app = link('Anna Müller');
      final web = InviteLink.toWebLink(app)!;
      expect(app, startsWith('familynexus://join?v=4&d='));
      expect(web, startsWith('https://carpeasrael.github.io/FamilyNexus/join/#v=4&d='));
      for (final text in <String>[app, web]) {
        for (final secret in <String>[room, 'raumgeheim', server, 'mueller', inviter, 'annamueller', 'Anna', 'Müller', nonce]) {
          expect(text.toLowerCase(), isNot(contains(secret.toLowerCase())), reason: secret);
          expect(text.toLowerCase(), isNot(contains(Uri.encodeQueryComponent(secret).toLowerCase())), reason: secret);
        }
      }
    });

    test('der Payload enthält genau die erlaubten Felder, keinen Familiennamen', () {
      final keys = Uri(query: v4Inner(link('Anna'))).queryParameters.keys.toSet();
      expect(keys, <String>{'room', 'via', 'srv', 'inv', 'exp', 'by', 'n'});
    });

    test('Roundtrip mit Umlauten und Emoji im Namen', () {
      final l = InviteLink.tryParse(link('Zoë Müller 🦄'), now: now)!;
      expect(l.inviterName, 'Zoë Müller 🦄');
      expect(l.familyName, isNull);
      expect(l.roomId, room);
      expect(l.accountServer, server);
    });

    test('Link ohne Namen: Einladender bleibt leer, Karte fällt auf die Matrix-ID zurück', () {
      final l = InviteLink.tryParse(link(null), now: now)!;
      expect(l.inviterName, isNull);
      expect(Uri(query: v4Inner(link(null))).queryParameters.containsKey('by'), isFalse);
    });

    test('Namen werden bereinigt, leere entfallen', () {
      final l = InviteLink.tryParse(link('\u202Egefährlich\u0000 ${'x' * 80}'), now: now)!;
      expect(l.inviterName!.contains('\u202E'), isFalse);
      expect(l.inviterName!.contains('\u0000'), isFalse);
      expect(l.inviterName!.runes.length, lessThanOrEqualTo(InviteLink.maxNameLength));
      expect(InviteLink.tryParse(link('   '), now: now)!.inviterName, isNull);
    });
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

  group('Version 3 und 4 (E-56, E-63, E-79): Namen und Konto-Server für Neulinge', () {
    String v3({String? family = 'Familie Müller', String? by = 'Anna'}) => v3Link(fields(family: family, by: by));

    test('TP-INV-01 Roundtrip mit Einladendenname, ohne Familienname', () {
      final s = InviteLink.create(
        roomId: '!abc123:matrix.org',
        via: 'matrix.org',
        inviter: '@mod:matrix.org',
        now: now,
        nonce: nonce,
        inviterName: 'Anna',
      );
      expect(s, contains('v=4'));
      final l = InviteLink.tryParse(s, now: now)!;
      expect(l.familyName, isNull);
      expect(l.inviterName, 'Anna');
      expect(l.inviterServer, 'matrix.org');
    });

    test('TP-INV-10 Links der Version 3 bleiben gültig, mit Familienname', () {
      final l = InviteLink.tryParse(v3(), now: now)!;
      expect(l.familyName, 'Familie Müller');
      expect(l.inviterName, 'Anna');
      expect(l.accountServer, 'matrix.org');
      expect(InviteLink.check(v3(), now: now).ok, isTrue);
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
      final same = InviteLink.tryParse(make(), now: now)!;
      expect(same.accountServer, 'matrix.org');
      expect(v4Inner(make()), contains('srv=matrix.org'));

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

  group('https-Landingpage (E-68)', () {
    final now = DateTime.utc(2026, 10, 25, 12);
    String app() => InviteLink.create(
          roomId: '!abc:example.org',
          via: 'example.org',
          inviter: '@anna:example.org',
          now: now,
          nonce: '0123456789abcdef0123456789abcdef',
          inviterName: 'Anna',
        );

    test('Web-Link trägt dieselben Angaben im Fragment und wird wie der App-Link gelesen', () {
      final web = InviteLink.toWebLink(app())!;
      expect(web, startsWith('https://carpeasrael.github.io/FamilyNexus/join/#v=4&d='));
      expect(Uri.parse(web).hasQuery, isFalse, reason: 'nichts davon geht als Anfrage an den Server');
      final fromApp = InviteLink.check(app(), now: now).link!;
      final fromWeb = InviteLink.check(web, now: now);
      expect(fromWeb.ok, isTrue);
      expect(fromWeb.link!.roomId, fromApp.roomId);
      expect(fromWeb.link!.nonce, fromApp.nonce);
      expect(fromWeb.link!.accountServer, fromApp.accountServer);
      expect(fromWeb.raw, startsWith('familynexus://join?'), reason: 'vorgemerkt wird immer der App-Link');
    });

    test('auch in Text, mit Satzzeichen, Groß-/Kleinschreibung und ohne Schrägstrich', () {
      final web = InviteLink.toWebLink(app())!;
      expect(InviteLink.check('Hallo!\n$web.\nViele Grüße', now: now).ok, isTrue);
      expect(InviteLink.check(web.replaceFirst('https://carpeasrael.github.io', 'HTTPS://CARPEASRAEL.GITHUB.IO'), now: now).ok, isTrue);
      expect(InviteLink.check(web.replaceFirst('/join/#', '/join#'), now: now).ok, isTrue);
    });

    test('fremde Seiten, fehlendes Fragment und Manipulation werden abgelehnt', () {
      final web = InviteLink.toWebLink(app())!;
      expect(InviteLink.check(web.replaceFirst('carpeasrael.github.io', 'evil.example'), now: now).ok, isFalse);
      expect(InviteLink.check(web.replaceFirst('#', '?'), now: now).ok, isFalse);
      expect(InviteLink.check('$web&evil=1', now: now).ok, isFalse, reason: 'unbekanntes Feld wie beim App-Link');
      expect(InviteLink.toWebLink('https://example.org/x'), isNull);
    });
  });

  group('#26: abgeschnittene Links', () {
    final now = DateTime.utc(2026, 10, 25, 12);
    final link = InviteLink.create(
      roomId: '!abc:example.org',
      via: 'example.org',
      inviter: '@anna:example.org',
      now: now,
      nonce: '0123456789abcdef0123456789abcdef',
      inviterName: 'Test Nutzer 1',
    );

    test('die Zufalls-ID steht am Ende', () {
      expect(v4Inner(link), endsWith('&n=0123456789abcdef0123456789abcdef'));
      expect(v4Inner(InviteLink.toWebLink(link)!), endsWith('&n=0123456789abcdef0123456789abcdef'));
    });

    test('um die letzten Zeichen gekürzt: beschädigt, nicht mit gekürztem Namen angenommen', () {
      for (final cut in <int>[1, 10, 31]) {
        final short = link.substring(0, link.length - cut);
        expect(InviteLink.check(short, now: now).problem, InviteLinkProblem.damaged, reason: 'um $cut Zeichen gekürzt');
        final web = InviteLink.toWebLink(link)!;
        expect(InviteLink.check(web.substring(0, web.length - cut), now: now).problem, InviteLinkProblem.damaged);
      }
    });

    test('ältere Links mit anderer Reihenfolge werden weiterhin gelesen', () {
      final old = 'familynexus://join?v=3&room=%21abc%3Aexample.org&via=example.org&srv=example.org'
          '&inv=%40anna%3Aexample.org&exp=${now.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000}'
          '&n=0123456789abcdef0123456789abcdef&f=Familie+Test&by=Anna';
      final c = InviteLink.check(old, now: now);
      expect(c.ok, isTrue);
      expect(c.link!.inviterName, 'Anna');
    });
  });
}
