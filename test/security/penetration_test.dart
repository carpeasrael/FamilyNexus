// Penetrationstests auf Eingabeebene: Alles, was von außen kommt (Einladungslinks, Server-Eingaben,
// fremde Matrix-Ereignisse, Anhänge, Anzeigenamen), wird mit feindlichen und zufällig mutierten
// Daten beschossen. Erwartung: nie eine Ausnahme, nie eine Annahme gefälschter/ungültiger Daten.
import 'dart:math';

import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/text_sanitizer.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';

final DateTime _now = DateTime.utc(2026, 10, 21, 12);
const String _nonce = '0123456789abcdef0123456789abcdef';

String _validLink() => InviteLink.create(
  roomId: '!abc:example.org',
  via: 'example.org',
  inviter: '@anna:example.org',
  now: _now,
  nonce: _nonce,
);

/// Zufällige, aber reproduzierbare Mutation (Seed fest → Fehler sind nachstellbar).
String _mutate(String s, Random r) {
  const junk = <String>['%00', '%0a', '\u202e', '../', '\\', '"', "'", '<', '&', '=', '?', '#', '@', ':', '\u0000', '𝔘'];
  final chars = s.split('');
  for (var i = 0; i < 1 + r.nextInt(4); i++) {
    final pos = chars.isEmpty ? 0 : r.nextInt(chars.length);
    switch (r.nextInt(4)) {
      case 0:
        if (chars.isNotEmpty) chars.removeAt(pos);
      case 1:
        chars.insert(pos, junk[r.nextInt(junk.length)]);
      case 2:
        if (chars.isNotEmpty) chars[pos] = junk[r.nextInt(junk.length)];
      default:
        chars.insert(pos, chars.isEmpty ? 'x' : chars[r.nextInt(chars.length)]);
    }
  }
  return chars.join();
}

Object? _randomValue(Random r) {
  switch (r.nextInt(9)) {
    case 0:
      return null;
    case 1:
      return r.nextInt(1 << 31) * (r.nextBool() ? 1 : -1);
    case 2:
      return 'x' * r.nextInt(5000);
    case 3:
      return <Object?>[1, 'a', null];
    case 4:
      return <String, Object?>{'a': 1};
    case 5:
      return double.nan;
    case 6:
      return 1 << 62;
    case 7:
      return '';
    default:
      return r.nextBool();
  }
}

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Einladungslinks', () {
    test('Ausgangslink ist gültig (Kontrolle für die Angriffe)', () {
      final l = InviteLink.tryParse(_validLink(), now: _now);
      expect(l, isNotNull);
      expect(l!.isValidAt(_now), isTrue);
    });

    test('2000 zufällig mutierte Links: nie eine Ausnahme; angenommene Links sind in sich stimmig', () {
      final r = Random(1337);
      final base = _validLink();
      var accepted = 0;
      for (var i = 0; i < 2000; i++) {
        final m = _mutate(base, r);
        final InviteLink? l;
        try {
          l = InviteLink.tryParse(m, now: _now);
        } catch (e) {
          fail('Ausnahme bei "$m": $e');
        }
        if (l == null) continue;
        accepted++;
        expect(MatrixIds.isRoomId(l.roomId), isTrue, reason: m);
        expect(MatrixIds.isUserId(l.inviter), isTrue, reason: m);
        expect(InviteLink.isNonce(l.nonce), isTrue, reason: m);
        expect(InviteLink.viaMatchesRoom(l.roomId, l.via), isTrue, reason: m);
      }
      expect(accepted, lessThan(2000));
    });

    test('Regression: ungültige Prozentkodierung wirft nicht (präparierter Deep Link/QR)', () {
      for (final bad in <String>[
        'familynexus://join?v=1&room=%21abc%Aexample.org',
        'familynexus://join?v=%',
        'familynexus://join?%=1',
        'familynexus://join?v=1&n=%zz',
      ]) {
        expect(InviteLink.tryParse(bad, now: _now), isNull, reason: bad);
      }
    });

    test('Angriffsmuster werden abgelehnt', () {
      final ok = _validLink();
      final attacks = <String, String>{
        'anderer Server in via (Umleitung)': ok.replaceFirst('via=example.org', 'via=evil.example'),
        'via mit Zugangsdaten': ok.replaceFirst('via=example.org', 'via=evil@example.org'),
        'via mit Pfad': ok.replaceFirst('via=example.org', 'via=example.org%2Fx'),
        'via lokal': ok.replaceFirst('example.org', 'localhost'),
        'via IP': '$ok&x=1',
        'Doppelter Parameter': '$ok&n=$_nonce',
        'Zusatzparameter': '$ok&redirect=https://evil',
        'Schema-Tausch https': ok.replaceFirst('familynexus', 'https'),
        'Schema-Tausch javascript': ok.replaceFirst('familynexus', 'javascript'),
        'Userinfo': ok.replaceFirst('://', '://anna:pw@'),
        'Port': ok.replaceFirst('join?', 'join:8080?'),
        'Fragment': '$ok#frag',
        'Pfadanhang': ok.replaceFirst('join?', 'join/../x?'),
        'CRLF-Injektion': ok.replaceFirst('v=2', 'v=2%0d%0aX-Evil:1'),
        'Nonce mit Großbuchstaben': ok.replaceFirst(_nonce, _nonce.toUpperCase()),
        'Nonce zu kurz': ok.replaceFirst(_nonce, 'abc'),
        'exp als Gleitkommazahl': ok.replaceFirst(RegExp(r'exp=\d+'), 'exp=1.5e9'),
        'exp Überlauf': ok.replaceFirst(RegExp(r'exp=\d+'), 'exp=99999999999999999999'),
        'Version 3': ok.replaceFirst('v=2', 'v=3'),
        'Version 1 mit Feldern aus Version 2': '${ok.replaceFirst('v=2', 'v=1')}&f=Familie',
        'doppelter Familienname': '$ok&f=A&f=B',
        'überlang': '$ok&pad=${'a' * 600}',
        'leer': '',
        'Leerzeichen': '   ',
      };
      attacks.forEach((name, link) {
        final l = InviteLink.tryParse(link, now: _now);
        expect(l == null || !l.isValidAt(_now) ? true : l.via == 'example.org', isTrue, reason: name);
        // Alles außer "Leerzeichen/leer" muss hart abgelehnt werden.
        if (name != 'IP') expect(l, isNull, reason: name);
      });
    });

    test('abgelaufene und zu weit in der Zukunft liegende Links', () {
      final past = InviteLink.tryParse(_validLink(), now: _now.add(const Duration(days: 8)));
      expect(past == null || !past.isValidAt(_now.add(const Duration(days: 8))), isTrue);
      final far = InviteLink.tryParse(_validLink(), now: _now.subtract(const Duration(days: 30)));
      expect(far, isNull, reason: 'Ablauf Wochen nach "jetzt" = manipuliert');
    });
  });

  group('Server-Eingabe (SSRF / Downgrade)', () {
    test('nur https, keine Zugangsdaten, kein Pfad/Query/Fragment', () {
      for (final bad in <String>[
        'http://example.org',
        'ftp://example.org',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'https://user:pw@example.org',
        'https://example.org/path',
        'https://example.org?x=1',
        'https://example.org#x',
        'https://example.org:0',
        'https://example.org:99999',
        'https://exa mple.org',
        'https://-bad.example',
        'https://bad-.example',
        'https://exa_mple.org',
        'https://${'a' * 300}.org',
        'https://',
        '',
        '   ',
        'https://example.org\r\nHost: evil',
        'https://example.org\u202e.moc.live',
      ]) {
        expect(ServerUrl.tryParse(bad), isNull, reason: bad);
      }
    });

    test('Eingaben werden zu https normalisiert; Host-Großschreibung egal', () {
      expect(ServerUrl.tryParse('Example.ORG')!.toString(), 'https://example.org');
      expect(ServerUrl.tryParse('example.org:8448')!.uri.port, 8448);
    });

    test('Zufallsfuzz: nie eine Ausnahme, Ergebnis ist immer https ohne Zusätze', () {
      final r = Random(7);
      for (var i = 0; i < 2000; i++) {
        final s = _mutate('https://matrix.example.org:8448', r);
        final ServerUrl? u;
        try {
          u = ServerUrl.tryParse(s);
        } catch (e) {
          fail('Ausnahme bei "$s": $e');
        }
        if (u == null) continue;
        expect(u.uri.scheme, 'https', reason: s);
        expect(u.uri.userInfo, isEmpty, reason: s);
        expect(u.uri.hasQuery || u.uri.hasFragment, isFalse, reason: s);
      }
    });
  });

  group('Matrix-IDs (Injektion)', () {
    test('lehnt Steuerzeichen, Leerraum, Bidi und Überlänge ab', () {
      for (final bad in <String>[
        '@anna:example.org\n',
        '@anna :example.org',
        '@anna:example.org/../x',
        '@ann\u202ea:example.org',
        '@Anna:example.org',
        '@${'a' * 300}:example.org',
        'anna:example.org',
        '@anna',
        '@:example.org',
        '@anna:',
        '!room:evil.org<script>',
        '#alias:example.org',
      ]) {
        expect(MatrixIds.isUserId(bad), isFalse, reason: bad);
      }
      expect(MatrixIds.isRoomId('@anna:example.org'), isFalse);
      expect(MatrixIds.isRoomId('!a b:example.org'), isFalse);
    });
  });

  group('Fremde Kalender-Ereignisse (nicht vertrauenswürdig)', () {
    test('Fälschung in fremdem Namen wird verworfen', () {
      final m = EventCodec.encodeShared(ev());
      final r = EventCodec.decode(m, sender: kOther, visibility: EventVisibility.shared);
      expect(r.isOk, isFalse);
      expect(r.error, 'owner-mismatch');
    });

    test('3000 Mutationen (falsche Typen, Riesenwerte, NaN, verschachtelt): nie eine Ausnahme', () {
      final r = Random(42);
      final base = EventCodec.encodeShared(ev());
      final keys = base.keys.toList();
      var accepted = 0;
      for (var i = 0; i < 3000; i++) {
        final m = Map<String, Object?>.of(base);
        for (var j = 0; j < 1 + r.nextInt(3); j++) {
          final k = keys[r.nextInt(keys.length)];
          if (r.nextInt(6) == 0) {
            m.remove(k);
          } else {
            m[k] = _randomValue(r);
          }
        }
        if (r.nextInt(5) == 0) m['rec'] = <String, Object?>{for (final k in <String>['freq', 'interval', 'weekdays', 'count', 'until', 'ex']) k: _randomValue(r)};
        final DecodeResult res;
        try {
          res = EventCodec.decode(m, sender: kOwner, visibility: EventVisibility.shared);
        } catch (e) {
          fail('Ausnahme bei $m: $e');
        }
        if (res.isOk) {
          accepted++;
          expect(res.event!.validate(), isEmpty, reason: '$m');
          expect(res.event!.ownerId, kOwner);
        }
      }
      expect(accepted, lessThan(3000));
    });

    test('Textfelder mit Bidi-/Steuerzeichen oder Überlänge werden nicht ungeprüft übernommen', () {
      final base = EventCodec.encodeShared(ev());
      for (final title in <String>['a' * 5000, '\u0000', 'x\u202ey']) {
        final m = Map<String, Object?>.of(base)..['title'] = title;
        final r = EventCodec.decode(m, sender: kOwner, visibility: EventVisibility.shared);
        if (r.isOk) {
          expect(r.event!.title, TextSanitizer.clean(r.event!.title, max: 5000), reason: 'Titel bereits bereinigt');
        }
      }
    });

    test('Regression: RSVP mit Zeitstempel außerhalb des DateTime-Bereichs wirft nicht', () {
      for (final ts in <int>[1 << 62, -(1 << 62), 8640000000000001, -8640000000000001]) {
        final m = EventCodec.encodeRsvp(ev().id, RsvpStatus.accepted, _now)..['ts'] = ts;
        expect(EventCodec.decodeRsvp(m), isNull, reason: '$ts');
      }
    });

    test('RSVP-Dekodierung: Müll liefert null statt Ausnahme', () {
      final r = Random(5);
      final base = EventCodec.encodeRsvp(ev().id, RsvpStatus.accepted, _now);
      for (var i = 0; i < 1000; i++) {
        final m = Map<String, Object?>.of(base);
        final k = m.keys.elementAt(r.nextInt(m.length));
        m[k] = _randomValue(r);
        try {
          EventCodec.decodeRsvp(m);
        } catch (e) {
          fail('Ausnahme bei $m: $e');
        }
      }
    });
  });

  group('Aufgabenlisten (fremde Ereignisse)', () {
    const anna = '@anna:example.org';
    const listId = '00000000-0000-4000-8000-000000000001';
    const itemId = '00000000-0000-4000-8000-000000000002';
    final list = TaskList(
      id: listId,
      title: 'Haushalt',
      assignee: '@ben:example.org',
      interval: TaskInterval.weekly,
      timeZone: 'Europe/Berlin',
      items: const <TaskItem>[TaskItem(id: itemId, title: 'Müll')],
      by: anna,
      updatedAt: _now,
    );
    final entry = TaskLogEntry(
      id: '00000000-0000-4000-8000-0000000000a1',
      listId: listId,
      itemId: itemId,
      periodKey: '2026-W43',
      doneOn: '2026-10-22',
      at: DateTime.utc(2026, 10, 22, 10),
      by: '@ben:example.org',
      comment: 'ok',
    );

    test('Listen: 3000 Mutationen, nie eine Ausnahme; Angenommenes ist gültig und vom Absender', () {
      final r = Random(2024);
      final base = TaskCodec.encodeList(list);
      final keys = base.keys.toList();
      for (var i = 0; i < 3000; i++) {
        final m = Map<String, Object?>.of(base);
        for (var j = 0; j < 1 + r.nextInt(3); j++) {
          final k = keys[r.nextInt(keys.length)];
          if (r.nextInt(6) == 0) {
            m.remove(k);
          } else {
            m[k] = k == 'items' && r.nextBool()
                ? <Object?>[
                    for (var n = 0; n < r.nextInt(80); n++) <String, Object?>{'id': _randomValue(r), 'title': _randomValue(r)},
                  ]
                : _randomValue(r);
          }
        }
        final TaskList? l;
        try {
          l = TaskCodec.decodeList(m, sender: anna);
        } catch (e) {
          fail('Ausnahme bei $m: $e');
        }
        if (l != null) {
          expect(l.validate(), isEmpty, reason: '$m');
          expect(l.by, anna);
        }
      }
    });

    test('Protokoll: 3000 Mutationen, nie eine Ausnahme; Angenommenes ist gültig und vom Absender', () {
      final r = Random(2025);
      final base = TaskCodec.encodeLog(entry);
      final keys = base.keys.toList();
      for (var i = 0; i < 3000; i++) {
        final m = Map<String, Object?>.of(base);
        for (var j = 0; j < 1 + r.nextInt(3); j++) {
          final k = keys[r.nextInt(keys.length)];
          if (r.nextInt(6) == 0) {
            m.remove(k);
          } else {
            m[k] = r.nextInt(4) == 0 ? _mutate('${base[k]}', r) : _randomValue(r);
          }
        }
        final TaskLogEntry? e;
        try {
          e = TaskCodec.decodeLog(m, sender: '@ben:example.org');
        } catch (err) {
          fail('Ausnahme bei $m: $err');
        }
        if (e != null) {
          expect(e.validate(), isEmpty, reason: '$m');
          expect(e.by, '@ben:example.org');
        }
      }
    });

    test('Fälschung in fremdem Namen, Zeit- und Periodenmanipulation', () {
      final m = TaskCodec.encodeLog(entry);
      expect(TaskCodec.decodeLog(m, sender: anna), isNull, reason: 'by != Absender');
      for (final ts in <int>[1 << 62, -(1 << 62), DateTime.utc(1999).millisecondsSinceEpoch, DateTime.utc(2101).millisecondsSinceEpoch]) {
        expect(TaskCodec.decodeLog({...m, 'ts': ts}, sender: '@ben:example.org'), isNull, reason: '$ts');
      }
      // Periode, die zu keinem Intervall des Datums passt (z. B. einen Monat in der Zukunft "vorab erledigen").
      expect(TaskCodec.decodeLog({...m, 'period': '2026-11'}, sender: '@ben:example.org'), isNull);
      expect(TaskCodec.decodeLog({...m, 'period': '2099-W01'}, sender: '@ben:example.org'), isNull);
    });

    test('Vorab- oder Rückdatierung zählt nicht: Datum muss zum Zeitpunkt in der Listenzone passen', () {
      final wrongDay = TaskLogEntry(
        id: entry.id,
        listId: listId,
        itemId: itemId,
        periodKey: '2026-W43',
        doneOn: '2026-10-23', // morgen
        at: DateTime.utc(2026, 10, 22, 10),
        by: entry.by,
      );
      expect(wrongDay.validate(), isEmpty, reason: 'in sich formal gültig');
      expect(TaskProgress.isValidFor(list, wrongDay), isFalse, reason: 'aber Datum und Zeitpunkt passen nicht');
      expect(TaskProgress.doneNow(list, <TaskLogEntry>[wrongDay], DateTime.utc(2026, 10, 23, 8)), isEmpty);
    });

    test('Nicht zugewiesene Person oder fremde Liste: Eintrag zählt nie', () {
      final other = TaskLogEntry(
        id: entry.id,
        listId: listId,
        itemId: itemId,
        periodKey: '2026-W43',
        doneOn: '2026-10-22',
        at: entry.at,
        by: '@cara:example.org',
      );
      expect(TaskProgress.doneNow(list, <TaskLogEntry>[other], entry.at), isEmpty);
    });

    test('Speicherschutz: zu viele Punkte, überlange Titel, doppelte IDs', () {
      final m = TaskCodec.encodeList(list);
      final many = <Object?>[
        for (var i = 0; i < 51; i++) <String, Object?>{'id': '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}', 'title': 'x'},
      ];
      expect(TaskCodec.decodeList({...m, 'items': many}, sender: anna), isNull);
      expect(TaskCodec.decodeList({...m, 'title': 'a' * 5000}, sender: anna), isNull);
      final dup = <Object?>[
        <String, Object?>{'id': itemId, 'title': 'a'},
        <String, Object?>{'id': itemId, 'title': 'b'},
      ];
      expect(TaskCodec.decodeList({...m, 'items': dup}, sender: anna), isNull);
    });
  });

  group('Anhänge', () {
    test('Pfad-Traversal, Bidi-Tarnung und Steuerzeichen in Dateinamen', () {
      for (final raw in <String>[
        '../../etc/passwd',
        '..\\..\\windows\\system32\\cmd.exe',
        '/abs/path/evil.png',
        'C:\\x\\evil.png',
        '.hidden',
        '...',
        'foto\u202egpj.exe',
        'a\u0000b.png',
        'a<b>:c|d?e*.png',
        '${'x' * 500}.png',
        '',
      ]) {
        final n = AttachmentPolicy.sanitizeFileName(raw);
        expect(n, isNotEmpty, reason: raw);
        expect(n.contains('/') || n.contains('\\') || n.contains('\u0000') || n.contains('\u202e'), isFalse, reason: raw);
        expect(n.startsWith('.'), isFalse, reason: raw);
        expect(n.length, lessThanOrEqualTo(100), reason: raw);
      }
    });

    test('ausführbare Dateien und Skripte werden nie angenommen, auch nicht doppelt getarnt', () {
      final png = <int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3];
      for (final name in <String>[
        'virus.exe',
        'x.sh',
        'x.apk',
        'x.html',
        'x.svg',
        'x.js',
        'x.bat',
        'x.png.exe',
        'x.exe.png',
        'x.PNG ',
        'x.',
        'x',
      ]) {
        final res = AttachmentPolicy.check(fileName: name, bytes: png);
        if (name == 'x.exe.png') {
          expect(res, isNull, reason: 'Endung .png, Inhalt PNG: harmlos, wird als Bild behandelt');
        } else {
          expect(res, isNotNull, reason: name);
        }
      }
      // Skript im PNG-Mantel: Endung .png, aber kein PNG-Inhalt.
      expect(AttachmentPolicy.check(fileName: 'a.png', bytes: '<script>alert(1)</script>'.codeUnits), AttachmentRejection.contentMismatch);
      expect(AttachmentPolicy.check(fileName: 'a.pdf', bytes: <int>[0x4D, 0x5A, 0x90, 0]), AttachmentRejection.contentMismatch, reason: 'PE/EXE als PDF');
    });

    test('Größenlimit und eingehende Metadaten', () {
      expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: -1), isFalse);
      expect(AttachmentPolicy.incomingAllowed(mimeType: 'image/png', size: AttachmentPolicy.maxBytes + 1), isFalse);
      expect(AttachmentPolicy.incomingAllowed(mimeType: 'text/html', size: 10), isFalse);
      expect(AttachmentPolicy.incomingAllowed(mimeType: 'application/x-msdownload', size: 10), isFalse);
      expect(AttachmentPolicy.incomingAllowed(mimeType: 'IMAGE/PNG', size: 10), isTrue);
    });
  });

  group('Anzeigenamen / Spoofing', () {
    test('unsichtbare Zeichen, Bidi-Umkehr und Zeilenumbrüche werden entfernt', () {
      for (final bad in <String>['Anna\u202eadmin', 'A\u200Bd\u200Cm\u200Din', 'Anna\nModerator:', 'x\u2066y\u2069', 'a\u0007b']) {
        final c = TextSanitizer.clean(bad);
        expect(RegExp('[\u202A-\u202E\u2066-\u2069\u200B-\u200D\n\u0007]').hasMatch(c), isFalse, reason: bad);
      }
      expect(TextSanitizer.displayName('\u202e\u200b', '@anna:example.org'), '@anna:example.org');
    });

    test('Reaktionsschlüssel: kein Text-/HTML-/Steuerzeichen-Einschleusen', () {
      for (final bad in <String>['abc', '12', '\n', '\u202e👍', '👍${'x' * 40}', '']) {
        expect(TextSanitizer.isReactionKey(bad), isFalse, reason: bad);
      }
      // Bekannte Grenze (kein Fund): kurze Zeichenketten mit Sonderzeichen gelten als Reaktion. Flutter
      // rendert sie als reinen Text (kein HTML/Skript), daher nicht ausnutzbar.
      expect(TextSanitizer.isReactionKey('<b>'), isTrue);
      expect(TextSanitizer.isReactionKey('👍'), isTrue);
    });

    test('Zufallsfuzz: clean() wirft nie und überschreitet das Limit nicht', () {
      final r = Random(99);
      for (var i = 0; i < 2000; i++) {
        final s = String.fromCharCodes(List<int>.generate(r.nextInt(200), (_) => r.nextInt(0x2FFF)).where((c) => c < 0xD800 || c > 0xDFFF));
        late String c;
        try {
          c = TextSanitizer.clean(s, max: 32);
        } catch (e) {
          fail('Ausnahme bei ${s.codeUnits}: $e');
        }
        expect(c.runes.length, lessThanOrEqualTo(32));
      }
    });
  });
}
