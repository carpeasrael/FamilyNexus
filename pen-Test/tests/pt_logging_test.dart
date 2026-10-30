// Pen-Test 2026-10-30 – Datenabfluss über Protokolle (AppLog.redact).
import 'package:family_nexus/core/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PT-G1: typische Geheimnisse werden geschwärzt', () {
    final cases = <String, String>{
      'Zugangs-Token': 'request failed access_token=syt_YWxpY2U_aBcDeFgHiJkLmNoPqRsT_0a1b2c',
      'Bearer-Header': 'Authorization: Bearer syt_YWxpY2U_aBcDeFgHiJkLmNoPqRsT_0a1b2c',
      'Matrix-ID': 'user @anna:example.org failed',
      'Raum-ID': 'room !AbCdEf:example.org',
      'DB-Schlüssel': 'key Zm9vYmFyYmF6cXV4cXV1eHF1dXhxdXV4cXV1eHF1dXg=',
    };
    cases.forEach((what, raw) {
      final red = AppLog.redact(raw);
      // ignore: avoid_print
      print('PT-G1 $what: $red');
      expect(red.contains('syt_YWxpY2U'), isFalse, reason: what);
      expect(red.contains('Sommer2026'), isFalse, reason: what);
      expect(red.contains('@anna'), isFalse, reason: what);
      expect(red.contains('AbCdEf'), isFalse, reason: what);
    });
  });

  test('PT-G1b: Passwort in JSON-Schreibweise ("password":"…") wird geschwärzt (F-07 behoben)', () {
    final red = AppLog.redact('{"password":"Sommer2026!"}');
    // ignore: avoid_print
    print('PT-G1b: $red');
    expect(red.contains('Sommer2026'), isFalse, reason: 'F-07: Anführungszeichen hinter dem Stichwort');
  });

  test('PT-G2: Notfall-Schlüssel im Matrix-Format (Vierergruppen mit Leerzeichen) ohne Stichwort', () {
    const recovery = 'EsTc 5rr1 4Jhp Uc18 hwCn 2b9T tSvj 5h4T TXBk 1VZD f3Zw 4Kmz';
    final red = AppLog.redact('Wiederherstellung fehlgeschlagen für $recovery');
    // ignore: avoid_print
    print('PT-G2: $red');
    // Seit der Behebung von F-07: eigene Regel für 12 Vierergruppen Base58.
    expect(red.contains('EsTc'), isFalse, reason: 'F-07: gruppierte Schlüssel');
  });

  test('PT-G3: AppLog.e gibt nie den Fehlertext aus', () {
    AppLog.capture = true;
    AppLog.captured.clear();
    AppLog.e('pt', 'Fehler', Exception('Inhalt: Arzttermin bei Dr. Müller, passwort=xyz'));
    expect(AppLog.captured.single, contains('_Exception'));
    expect(AppLog.captured.single.contains('Arzttermin'), isFalse);
    AppLog.capture = false;
  });
}
