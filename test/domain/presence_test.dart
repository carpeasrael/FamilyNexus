import 'package:family_nexus/domain/presence.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 10, 21, 12);
const String _anna = '@anna:example.org';

void main() {
  group('PresenceCodec', () {
    test('kodiert und dekodiert online mit Bitte um Antwort', () {
      final c = PresenceCodec.encode(online: true, now: _now, ask: true);
      expect(c['v'], 1);
      final d = PresenceCodec.decode(c, now: _now)!;
      expect(d.online, isTrue);
      expect(d.ask, isTrue);
      expect(d.at, _now);
    });

    test('„offline“ trägt nie eine Bitte um Antwort', () {
      expect(PresenceCodec.encode(online: false, now: _now, ask: true).containsKey('ask'), isFalse);
      expect(PresenceCodec.decode(<String, Object?>{'v': 1, 'state': 'offline', 'ts': _now.millisecondsSinceEpoch, 'ask': true}, now: _now), isNull);
    });

    test('verwirft ungültige Inhalte', () {
      final ts = _now.millisecondsSinceEpoch;
      final bad = <Map<String, Object?>>[
        <String, Object?>{},
        <String, Object?>{'v': 2, 'state': 'online', 'ts': ts},
        <String, Object?>{'v': 1, 'state': 'away', 'ts': ts},
        <String, Object?>{'v': 1, 'state': 'online', 'ts': '$ts'},
        <String, Object?>{'v': 1, 'state': 'online', 'ts': ts, 'ask': 'ja'},
        <String, Object?>{'v': 1, 'state': 1, 'ts': ts},
        <String, Object?>{'v': 1, 'state': 'online', 'ts': -5},
        <String, Object?>{'v': 1, 'state': 'online', 'ts': 9007199254740991},
      ];
      for (final c in bad) {
        expect(PresenceCodec.decode(c, now: _now), isNull, reason: '$c');
      }
    });

    test('verwirft zu alte und zu weit vorausgehende Meldungen', () {
      Map<String, Object?> at(Duration d) => PresenceCodec.encode(online: true, now: _now.add(d));
      expect(PresenceCodec.decode(at(-PresenceCodec.validity - const Duration(seconds: 1)), now: _now), isNull);
      expect(PresenceCodec.decode(at(-PresenceCodec.validity), now: _now), isNotNull);
      expect(PresenceCodec.decode(at(PresenceCodec.maxFutureSkew + const Duration(seconds: 1)), now: _now), isNull);
      expect(PresenceCodec.decode(at(PresenceCodec.maxFutureSkew), now: _now), isNotNull);
    });
  });

  group('PresenceBoard', () {
    test('nur neuere Meldungen ersetzen ältere', () {
      final b = PresenceBoard();
      expect(b.apply(_anna, online: true, at: _now), isTrue);
      expect(b.apply(_anna, online: false, at: _now.subtract(const Duration(seconds: 5))), isFalse);
      expect(b.apply(_anna, online: false, at: _now), isFalse, reason: 'gleicher Zeitpunkt ändert nichts');
      expect(b[_anna]!.online, isTrue);
      expect(b.apply(_anna, online: false, at: _now.add(const Duration(seconds: 1))), isTrue);
      expect(b[_anna]!.online, isFalse);
    });

    test('ungültige Kennungen und zu viele Einträge werden abgelehnt', () {
      final b = PresenceBoard();
      expect(b.apply('kein-mxid', online: true, at: _now), isFalse);
      for (var i = 0; i < PresenceBoard.maxEntries; i++) {
        expect(b.apply('@u$i:example.org', online: true, at: _now), isTrue);
      }
      expect(b.apply('@zu-viel:example.org', online: true, at: _now), isFalse);
      // Bekannte dürfen weiter aktualisiert werden.
      expect(b.apply('@u0:example.org', online: false, at: _now.add(const Duration(seconds: 1))), isTrue);
    });

    test('retainOnly entfernt Nicht-Mitglieder', () {
      final b = PresenceBoard()..apply(_anna, online: true, at: _now)..apply('@ben:example.org', online: true, at: _now);
      expect(b.retainOnly(<String>{_anna}), isTrue);
      expect(b['@ben:example.org'], isNull);
      expect(b.retainOnly(<String>{_anna}), isFalse);
    });

    test('Auswertung: online nur innerhalb der Gültigkeit, danach offline mit „zuletzt“', () {
      final stamp = PresenceStamp(online: true, at: _now);
      expect(PresenceBoard.evaluate(null, _now).status, PresenceStatus.unknown);
      expect(PresenceBoard.evaluate(stamp, _now).status, PresenceStatus.online);
      expect(PresenceBoard.evaluate(stamp, _now.add(PresenceCodec.validity)).status, PresenceStatus.online);
      final late = PresenceBoard.evaluate(stamp, _now.add(PresenceCodec.validity + const Duration(seconds: 1)));
      expect(late.status, PresenceStatus.offline);
      expect(late.lastSeen, _now);
      final off = PresenceBoard.evaluate(PresenceStamp(online: false, at: _now), _now);
      expect(off.status, PresenceStatus.offline);
    });

    test('leicht vorausgehende Absenderuhr gilt als online', () {
      final stamp = PresenceStamp(online: true, at: _now.add(const Duration(seconds: 30)));
      expect(PresenceBoard.evaluate(stamp, _now).status, PresenceStatus.online);
    });
  });

  group('PresenceBoard mit mehreren Geräten', () {
    test('online, solange irgendein Gerät aktuell online meldet', () {
      final b = PresenceBoard();
      b.apply(_anna, deviceId: 'tablet', online: true, at: _now);
      // Das Handy geht in den Hintergrund und meldet „offline“ – das Tablet ist noch aktiv.
      b.apply(_anna, deviceId: 'handy', online: false, at: _now.add(const Duration(seconds: 5)));
      expect(PresenceBoard.evaluate(b.stampOf(_anna, _now.add(const Duration(seconds: 10))), _now.add(const Duration(seconds: 10))).status, PresenceStatus.online);
      // Das Tablet verstummt: nach Ablauf ist die Person offline.
      final later = _now.add(PresenceCodec.validity + const Duration(seconds: 30));
      expect(PresenceBoard.evaluate(b.stampOf(_anna, later), later).status, PresenceStatus.offline);
    });

    test('alle Geräte offline → offline mit jüngster Meldung; Gerätezahl ist begrenzt', () {
      final b = PresenceBoard();
      b.apply(_anna, deviceId: 'a', online: false, at: _now);
      b.apply(_anna, deviceId: 'b', online: false, at: _now.add(const Duration(seconds: 3)));
      final st = b.stampOf(_anna, _now)!;
      expect(st.online, isFalse);
      expect(st.at, _now.add(const Duration(seconds: 3)));
      for (var i = 0; i < PresenceBoard.maxDevicesPerUser; i++) {
        b.apply('@viel:example.org', deviceId: 'd$i', online: true, at: _now);
      }
      expect(b.apply('@viel:example.org', deviceId: 'zu-viel', online: true, at: _now), isFalse);
    });
  });
}
