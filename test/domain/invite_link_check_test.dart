import 'package:family_nexus/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/invite_links.dart';

/// Issue #6: „Dieser Link ist ungültig oder abgelaufen“ bei Anmeldung per Link. Die Fälle der Analyse
/// sind hier dauerhaft festgehalten.
void main() {
  final now = DateTime.utc(2026, 10, 24, 20);
  const n = '0123456789abcdef0123456789abcdef';
  String mk(String room, String via, String inv, {String? own, Duration validity = InviteLink.defaultValidity}) =>
      InviteLink.create(
        roomId: room,
        via: via,
        inviter: inv,
        now: now,
        nonce: n,
        ownHost: own,
        validity: validity,
        inviterName: 'Anna & Co. (Mama)',
      );
  final ok = mk('!AbCdEfGhIjKlMnOpQr:matrix.org', 'matrix.org', '@anna:matrix.org');
  final exp = now.add(InviteLink.defaultValidity).millisecondsSinceEpoch ~/ 1000;
  // Links der Version 3 gelten noch bis zu 7 Tage: Ihr Klartext-Pfad bleibt abgesichert.
  String fields({String room = '!AbCdEfGhIjKlMnOpQr:matrix.org', String via = 'matrix.org', String srv = 'matrix.org', String inv = '@anna:matrix.org', int? expires, String? family, String? by}) =>
      inviteFields(room: room, via: via, srv: srv, inv: inv, exp: expires ?? exp, family: family, by: by, n: n);
  final okV3 = v3Link(fields(family: 'Familie Müller', by: 'Anna & Co. (Mama)'));

  InviteLinkCheck check(String text, {DateTime? at, String? own}) => InviteLink.check(text, now: at ?? now, ownHost: own);

  group('gültige Links', () {
    test('normal, auch wenn man auf einem anderen Server angemeldet ist', () {
      expect(check(ok).ok, isTrue);
      expect(check(ok, own: 'beispiel.de').ok, isTrue);
      expect(check(ok).link!.onLocalServer, isFalse);
      expect(check(mk('!x:matrix.example.org:8448', 'matrix.example.org:8448', '@anna:matrix.example.org:8448')).ok, isTrue);
    });

    test('Standardgültigkeit 3 Tage, wählbar 1/3/7 Tage', () {
      expect(InviteLink.defaultValidity, const Duration(days: 3));
      expect(InviteLink.validityChoices, const <Duration>[Duration(days: 1), Duration(days: 3), Duration(days: 7)]);
      expect(check(ok, at: now.add(const Duration(days: 2, hours: 23))).ok, isTrue, reason: 'am übernächsten Tag noch gültig');
      final week = mk('!x:matrix.org', 'matrix.org', '@anna:matrix.org', validity: const Duration(days: 7));
      expect(check(week, at: now.add(const Duration(days: 6))).ok, isTrue);
    });
  });

  group('eigene Ursache je Ablehnung (statt „ungültig oder abgelaufen“)', () {
    test('abgelaufen', () {
      final c = check(ok, at: now.add(const Duration(days: 4)));
      expect(c.problem, InviteLinkProblem.expired);
      expect(c.link, isNotNull, reason: 'Link selbst ist in Ordnung');
    });

    test('kein Einladungslink', () {
      for (final t in <String>['', 'hallo', 'https://example.org/join?v=2', ok.replaceFirst('familynexus', 'https')]) {
        expect(check(t).problem, InviteLinkProblem.notALink, reason: t);
      }
    });

    test('aus neuerer App-Version', () {
      expect(check(ok.replaceFirst('v=4', 'v=5')).problem, InviteLinkProblem.newerVersion);
      expect(check(okV3.replaceFirst('v=3', 'v=5')).problem, InviteLinkProblem.newerVersion);
    });

    test('beschädigt oder manipuliert', () {
      for (final t in <String>[
        'familynexus://join?v=1&room=x',
        okV3.replaceFirst('via=matrix.org', 'via=evil.example'),
        okV3.replaceAll(RegExp(r'&n=[0-9a-f]+'), ''),
        '$okV3&x=1',
        v4(fields(via: 'evil.example')),
        v4(fields().replaceAll(RegExp(r'&n=[0-9a-f]+'), '')),
        '$ok&x=1',
      ]) {
        expect(check(t).problem, InviteLinkProblem.damaged, reason: t);
      }
    });

    test('Uhr der eingeladenen Person stark nachgehend → beschädigt (unplausible Gültigkeit)', () {
      expect(check(ok, at: now.subtract(const Duration(days: 8))).problem, InviteLinkProblem.damaged);
    });
  });

  group('beim Weitergeben beschädigte Links werden repariert', () {
    final damaged = <String, String>{
      'HTML-Mail: &amp; statt &': ok.replaceAll('&', '&amp;'),
      'in spitzen Klammern': '<$ok>',
      'in deutschen Anführungszeichen': '„$ok“',
      'in englischen Anführungszeichen': '"$ok"',
      'Text davor und danach': 'Hier dein Link: $ok – bis gleich!',
      'Punkt am Satzende': '$ok.',
      'in Klammern mit Satzzeichen': '($ok).',
      'Zeilenumbruch nach = (Version 3)': okV3.replaceFirst('&exp=', '&exp=\n'),
      'Zeilenumbruch vor & (Version 3)': okV3.replaceFirst('&n=', '\n&n='),
      'Schema in Großbuchstaben': ok.replaceFirst('familynexus', 'FamilyNexus'),
      'nicht dekodiertes Quoted-Printable': '${ok.replaceAll('=', '=3D').substring(0, 60)}=\n${ok.replaceAll('=', '=3D').substring(60)}',
    };
    damaged.forEach((name, text) {
      test(name, () {
        final c = check(text);
        expect(c.ok, isTrue, reason: '$name: ${c.problem}');
        expect(c.link!.inviterName, 'Anna & Co. (Mama)');
        expect(c.link!.nonce, n);
        expect(InviteLink.tryParse(c.raw!, now: now), isNotNull, reason: 'vorgemerkte Form ist streng lesbar');
      });
    });

    test('Mail mit Anleitung: der Link wird aus dem ganzen Text gelöst', () {
      final mail = 'Hallo,\n\nich lade dich ein.\n\n2. Tippe auf diesen Link:\n\n$ok\n\n3. Lege dein Konto an.';
      expect(check(mail).link!.via, 'matrix.org');
    });

    test('der Text nach dem Link wird nicht angehängt', () {
      expect(InviteLink.extract('$ok\n\n3. Lege dein Konto an'), ok);
      expect(InviteLink.extract('$ok und dann weiter'), ok);
    });
  });

  group('E-79: Zeilenumbruch im Payload (Version 4)', () {
    const prefix = 'familynexus://join?v=4&d=';
    final payload = ok.substring(prefix.length);
    final half = payload.length ~/ 2;
    final first = '$prefix${payload.substring(0, half)}';
    final second = payload.substring(half);
    final wrappedAt76 = '${ok.substring(0, 76)}\n${ok.substring(76)}';

    void repaired(String name, String text, {String? raw}) {
      test(name, () {
        final c = check(text);
        expect(c.ok, isTrue, reason: '$name: ${c.problem}');
        expect(c.raw, raw ?? ok);
        expect(c.link!.inviterName, 'Anna & Co. (Mama)');
      });
    }

    void stillDamaged(String name, String text) {
      test(name, () => expect(check(text).problem, InviteLinkProblem.damaged));
    }

    test('Kontrolle: Link ist lang genug für einen Umbruch an Stelle 76', () {
      expect(ok.length, greaterThan(76));
    });
    repaired('an Stelle 76', wrappedAt76);
    repaired('Windows-Zeilenende', '$first\r\n$second');
    repaired('mehrfach', <String>[for (var i = 0; i < ok.length; i += 40) ok.substring(i, i + 40 < ok.length ? i + 40 : ok.length)].join('\n'));
    repaired('mit Folgetext', '$first\n$second\n\nViele Grüße\nAnna');
    repaired('mit Folgetext direkt in der nächsten Zeile', '$first\n$second\nViele Grüße');
    repaired('mit Text davor', 'Hier ist der Link:\n$first\n$second');
    repaired('in spitzen Klammern', '<$first\n$second>');
    repaired('Punkt am Satzende', '$first\n$second.');
    repaired('in Klammern mit Punkt', '($first\n$second).');
    repaired('direkt nach d= und danach ein weiterer Umbruch', '$prefix\n${payload.substring(0, half)}\n$second');
    repaired('v=4 und &d= getrennt', 'familynexus://join?v=4\n&d=${payload.substring(0, half)}\n$second');
    repaired('Präfix großgeschrieben', '${first.replaceFirst('familynexus://join', 'FAMILYNEXUS://JOIN')}\n$second');
    repaired('Weblink', '${InviteLink.toWebLink(first)!}\n$second');
    repaired('Quoted-Printable mit weichem Umbruch', '${ok.replaceAll('=', '=3D').substring(0, 76)}=\n${ok.replaceAll('=', '=3D').substring(76)}');

    test('nach `-` im Payload', () {
      final link = InviteLink.create(roomId: '!x:matrix.org', via: 'matrix.org', inviter: '@anna:matrix.org', now: now, nonce: n, inviterName: 'a~~~~~');
      final i = link.indexOf('-') + 1;
      expect(i, greaterThan(prefix.length), reason: 'Kontrolle: Payload enthält ein Minus');
      expect(check('${link.substring(0, i)}\n${link.substring(i)}').raw, link);
    });

    test('32 Stücke werden angehängt, ein 33. nicht', () {
      String chunks(int count) {
        final size = payload.length ~/ count;
        final parts = <String>[for (var i = 0; i < count; i++) payload.substring(i * size, i == count - 1 ? payload.length : (i + 1) * size)];
        return '$prefix${parts.first}\n${parts.skip(1).join('\n')}';
      }

      expect(check(chunks(33)).ok, isTrue);
      expect(check(chunks(34)).problem, InviteLinkProblem.damaged);
    });

    test('der unveränderte Link geht vor, Folgetext wird nie angehängt', () {
      expect(InviteLink.extract('$ok\nViele'), ok);
      expect(InviteLink.extract('$first\n$second'), first);
      expect(check('$ok\nViele').raw, ok);
    });

    test('abgelaufen schlägt beschädigt', () {
      expect(check(wrappedAt76, at: now.add(const Duration(days: 4))).problem, InviteLinkProblem.expired);
    });

    stillDamaged('Schlusszeichen im ersten Stück: keine Fortsetzung', '$first.\n$second');
    stillDamaged('Schlusszeichen mitten im Link beendet ihn', '$first.\n${second.substring(0, 5)}\n${second.substring(5)}');
    stillDamaged('Schlusszeichen in einem mittleren Stück beendet ihn', '$first\n${second.substring(0, 5)}.\n${second.substring(5)}');
    stillDamaged('zitierte Zeilen bleiben beschädigt', '> $first\n> $second');
    stillDamaged('fremdes Zeichen im Folgestück', '$first\n${second.substring(0, 5)}+${second.substring(5)}');
    stillDamaged('abgeschnittener Link mit Folgetext', '$first\nViele Grüße\nAnna');
    stillDamaged('Version 3 wird nicht stückweise zusammengesetzt', 'familynexus://join?v=3&d=${payload.substring(0, half)}\n$second');
  });

  group('Server im Heimnetz (vor der Anmeldung unbekannt)', () {
    final local = <String, (String, String, String)>{
      'IP-Adresse': ('!x:192.168.1.10', '192.168.1.10', '@anna:192.168.1.10'),
      'localhost': ('!x:localhost', 'localhost', '@anna:localhost'),
      'Name ohne Punkt': ('!x:nas', 'nas', '@anna:nas'),
      'IP mit Port': ('!x:192.168.1.10:8448', '192.168.1.10:8448', '@anna:192.168.1.10:8448'),
    };
    local.forEach((name, v) {
      test('$name: angenommen und als Heimnetz markiert', () {
        final link = mk(v.$1, v.$2, v.$3, own: v.$2);
        final c = check(link);
        expect(c.ok, isTrue);
        expect(c.link!.onLocalServer, isTrue);
        expect(InviteLink.tryParse(link, now: now), isNull, reason: 'strenge Prüfung bleibt (Deep-Link-Schutz S8)');
        expect(check(link, own: v.$2).link!.onLocalServer, isFalse, reason: 'eigener Server: keine Warnung');
      });
    });

    test('Heimnetz-Server muss der Server des Raums sein', () {
      final local = fields(room: '!x:192.168.1.10', via: '192.168.1.10', srv: '192.168.1.10', inv: '@anna:192.168.1.10');
      final public = fields(room: '!x:matrix.org');
      final otherLocal = local.replaceFirst('via=192.168.1.10', 'via=192.168.1.11');
      final viaLocal = public.replaceFirst('via=matrix.org', 'via=localhost');
      expect(check(v3Link(local)).ok, isTrue, reason: 'Kontrolle');
      expect(check(v4(local)).ok, isTrue, reason: 'Kontrolle');
      expect(check(v3Link(otherLocal)).problem, InviteLinkProblem.damaged);
      expect(check(v4(otherLocal)).problem, InviteLinkProblem.damaged);
      expect(check(v3Link(viaLocal)).problem, InviteLinkProblem.damaged);
      expect(check(v4(viaLocal)).problem, InviteLinkProblem.damaged);
    });
  });

  test('R4: lange Texte (Mail mit Zitat und Signatur) werden durchsucht, übergroße nur bis zur Grenze', () {
    expect(check('${'Zitat ' * 1000}\n$ok\n${'Signatur ' * 500}').ok, isTrue);
    expect(check('${'x' * (InviteLink.maxInput + 10)}$ok').problem, InviteLinkProblem.notALink);
  });

  group('Review-Funde', () {
    String named(String family, String by) => v3Link(fields(family: family, by: by));

    test('R1: Namen wie „3D-Club“ oder „12er“ werden nicht als Quoted-Printable verfälscht', () {
      for (final link in <String>[named('3D-Club', '3Dee'), named('12er Runde', 'Fam=3DMüller'), named('ABC', 'A=3D')]) {
        final c = check(link);
        expect(c.ok, isTrue, reason: link);
        expect(c.raw, InviteLink.normalized(link), reason: 'unverändert');
        expect(check(c.raw!).ok, isTrue, reason: 'Neustart: vorgemerkte Form erneut lesbar (idempotent)');
      }
      expect(check(named('3D-Club', 'x')).link!.familyName, '3D-Club');
    });

    test('R1: echtes Quoted-Printable mit „3D“ im Namen wird gelesen und bleibt nach Neustart lesbar', () {
      final link = named('3D-Club', 'Anna');
      final qp = link.replaceAll('=', '=3D');
      final mail = '${qp.substring(0, 70)}=\n${qp.substring(70)}';
      final c = check(mail);
      expect(c.ok, isTrue);
      expect(c.link!.familyName, '3D-Club');
      expect(check(c.raw!).link!.familyName, '3D-Club');
    });

    test('R5: alter und neuer Link im Text – der gültige gewinnt; mitkopierte Fehlermeldung stört nicht', () {
      final old = mk('!x:matrix.org', 'matrix.org', '@anna:matrix.org', validity: const Duration(days: 1));
      final later = now.add(const Duration(days: 2));
      final fresh = InviteLink.create(
        roomId: '!y:matrix.org',
        via: 'matrix.org',
        inviter: '@anna:matrix.org',
        now: later,
        nonce: n,
      );
      expect(check('Alt: $old\nNeu: $fresh', at: later).link!.roomId, '!y:matrix.org');
      expect(check('Ein Einladungslink beginnt mit „familynexus://join“. Hier: $fresh', at: later).ok, isTrue);
      expect(check('Alt: $old', at: later).problem, InviteLinkProblem.expired, reason: 'aussagekräftigster Grund');
    });

    test('R7: lokale Endungen gelten als Heimnetz', () {
      for (final h in <String>['fritz.box', 'nas.local', 'server.lan', 'pi.home.arpa', 'matrix.internal', 'box.localdomain', 'NAS.LOCAL']) {
        expect(InviteLink.isLocalServer(h), isTrue, reason: h);
      }
      for (final h in <String>['matrix.org', 'beispiel.de', 'matrix.example.org:8448']) {
        expect(InviteLink.isLocalServer(h), isFalse, reason: h);
      }
    });

    test('Schema und Host komplett groß geschrieben', () {
      expect(check(ok.replaceFirst('familynexus://join', 'FAMILYNEXUS://JOIN')).ok, isTrue);
    });

    test('#59: App-Link mit „#“ statt „?“ (wie hinter der Landingpage) wird angenommen', () {
      final hash = okV3.replaceFirst('familynexus://join?', 'familynexus://join#');
      final slashHash = okV3.replaceFirst('familynexus://join?', 'familynexus://join/#');
      for (final l in <String>[hash, slashHash, 'Einladung: $hash.']) {
        final r = check(l);
        expect(r.ok, isTrue, reason: l);
        expect(r.link!.roomId, check(okV3).link!.roomId);
        expect(r.link!.familyName, 'Familie Müller');
      }
      expect(check(ok.replaceFirst('familynexus://join?', 'familynexus://join#')).raw, ok);
    });
  });
}
