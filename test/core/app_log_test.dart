import 'package:family_nexus/core/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppLog.captured.clear();
    AppLog.capture = true;
  });
  tearDown(() => AppLog.capture = false);

  test('maskiert Matrix-IDs und Raum-IDs', () {
    AppLog.d('t', 'user @anna:example.org in !abc123:example.org');
    final line = AppLog.captured.single;
    expect(line, isNot(contains('anna')));
    expect(line, isNot(contains('abc123')));
  });

  test('maskiert Geheimnisse in allen üblichen Schreibweisen', () {
    for (final s in <String>[
      'password=hunter2',
      'password: hunter2',
      'Password hunter2',
      'token abc123xyz',
      'access_token: syt_abc',
      'Authorization: Bearer abcDEF',
      'passphrase="mein geheimnis"',
      'key=geheim',
    ]) {
      AppLog.captured.clear();
      AppLog.d('t', s);
      final line = AppLog.captured.single;
      for (final secret in <String>['hunter2', 'abc123xyz', 'syt_abc', 'abcDEF', 'geheim']) {
        expect(line, isNot(contains(secret)), reason: s);
      }
    }
  });

  test('maskiert lange Schlüsselzeichenketten ohne Stichwort', () {
    AppLog.d('t', 'wert ${'A1b2' * 12}');
    expect(AppLog.captured.single, isNot(contains('A1b2A1b2')));
  });

  test('harmlose Wörter wie keyboard bleiben lesbar', () {
    AppLog.d('t', 'keyboard geöffnet');
    expect(AppLog.captured.single, contains('keyboard'));
  });

  test('Fehler loggt nur den Typ, nicht die Nachricht des Fehlers', () {
    AppLog.e('t', 'fehlgeschlagen', Exception('geheimer Inhalt'));
    expect(AppLog.captured.single, isNot(contains('geheimer')));
    expect(AppLog.captured.single, contains('_Exception'));
  });
}
