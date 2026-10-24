import 'package:family_nexus/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

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
        familyName: 'Familie Müller',
        inviterName: 'Anna & Co. (Mama)',
      );
  final ok = mk('!AbCdEfGhIjKlMnOpQr:matrix.org', 'matrix.org', '@anna:matrix.org');

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
      expect(check(ok.replaceFirst('v=2', 'v=3')).problem, InviteLinkProblem.newerVersion);
    });

    test('beschädigt oder manipuliert', () {
      for (final t in <String>[
        'familynexus://join?v=1&room=x',
        ok.replaceFirst('via=matrix.org', 'via=evil.example'),
        ok.replaceAll(RegExp(r'&n=[0-9a-f]+'), ''),
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
      'Zeilenumbruch nach =': ok.replaceFirst('&exp=', '&exp=\n'),
      'Zeilenumbruch vor &': ok.replaceFirst('&n=', '\n&n='),
      'Schema in Großbuchstaben': ok.replaceFirst('familynexus', 'FamilyNexus'),
      'nicht dekodiertes Quoted-Printable': '${ok.replaceAll('=', '=3D').substring(0, 60)}=\n${ok.replaceAll('=', '=3D').substring(60)}',
    };
    damaged.forEach((name, text) {
      test(name, () {
        final c = check(text);
        expect(c.ok, isTrue, reason: '$name: ${c.problem}');
        expect(c.link!.familyName, 'Familie Müller');
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
      final link = mk('!x:192.168.1.10', '192.168.1.10', '@anna:192.168.1.10', own: '192.168.1.10');
      expect(check(link.replaceFirst('via=192.168.1.10', 'via=192.168.1.11')).problem, InviteLinkProblem.damaged);
      final public = mk('!x:matrix.org', 'matrix.org', '@anna:matrix.org');
      expect(check(public.replaceFirst('via=matrix.org', 'via=localhost')).problem, InviteLinkProblem.damaged);
    });
  });

  test('übergroße Eingaben werden nicht verarbeitet', () {
    expect(check('x' * 5000 + ok).problem, InviteLinkProblem.notALink);
  });
}
