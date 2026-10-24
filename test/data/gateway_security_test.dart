import 'dart:async';

import 'package:family_nexus/app/quiet_zone.dart';
import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/matrix/family_room_spec.dart';
import 'package:family_nexus/data/matrix/https_only_client.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart' hide Role;

void main() {
  group('HttpsOnlyClient (TLS-Pflicht für alle SDK-Verbindungen)', () {
    test('lehnt http ab, ohne die Anfrage abzusetzen', () async {
      var called = false;
      final c = HttpsOnlyClient(MockClient((r) async {
        called = true;
        return http.Response('', 200);
      }));
      await expectLater(c.get(Uri.parse('http://example.org/x')), throwsA(isA<http.ClientException>()));
      expect(called, isFalse);
    });

    test('erlaubt https und deaktiviert Weiterleitungen', () async {
      late http.BaseRequest seen;
      final c = HttpsOnlyClient(MockClient((r) async {
        seen = r;
        return http.Response('ok', 200);
      }));
      expect((await c.get(Uri.parse('https://example.org/x'))).body, 'ok');
      expect(seen.followRedirects, isFalse);
    });

    test('lehnt weitere Schemata ab', () async {
      final c = HttpsOnlyClient(MockClient((r) async => http.Response('', 200)));
      for (final u in <String>['ftp://x.org/a', 'file:///etc/passwd', 'ws://x.org']) {
        await expectLater(c.get(Uri.parse(u)), throwsA(anything), reason: u);
      }
    });
  });

  group('SDK-Logs', () {
    setUp(() {
      AppLog.captured.clear();
      AppLog.capture = true;
    });
    tearDown(() {
      AppLog.capture = false;
      Logs().onLog = null;
    });

    test('schwerer SDK-Fehler: nur der Typ landet im Log, Text/Titel nie', () {
      SdkMatrixGateway.hardenSdkLogging();
      runInQuietZone(() {
        Logs().wtf('Schlüssel abc @anna:x.org', Exception('geheimer Text'), StackTrace.current);
      });
      expect(AppLog.captured, hasLength(1));
      expect(AppLog.captured.single, isNot(contains('geheimer')));
      expect(AppLog.captured.single, isNot(contains('anna')));
      expect(AppLog.captured.single, isNot(contains('abc')));
      expect(Logs().outputEvents, isEmpty, reason: 'SDK-Logpuffer wird geleert');
    });

    test('Debug-/Info-Ereignisse mit Inhalt werden gar nicht weitergegeben', () {
      SdkMatrixGateway.hardenSdkLogging();
      Logs().i('Sending payload {"body":"Geheim"}');
      Logs().d('Key verification: emoji');
      expect(AppLog.captured, isEmpty);
    });

    test('Ruhige Zone verschluckt print vollständig', () {
      final seen = <String>[];
      runZoned(
        () => runInQuietZone(() {
          // ignore: avoid_print
          print('SDK: Ausnahme mit Inhalt');
        }),
        zoneSpecification: ZoneSpecification(print: (s, p, z, l) => seen.add(l)),
      );
      expect(seen, isEmpty);
    });
  });

  group('Familienraum-Spezifikation (E-12)', () {
    final pl = FamilyRoomSpec.powerLevels('@anna:x.org');

    test('Anfangszustand: Megolm, Verlauf für Mitglieder, anklopfbar', () {
      final s = {for (final e in FamilyRoomSpec.initialState()) e.type: e.content};
      expect(s['m.room.encryption'], <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'});
      expect(s['m.room.join_rules'], <String, Object?>{'join_rule': 'knock'});
      expect(s['m.room.history_visibility'], <String, Object?>{'history_visibility': 'shared'});
    });

    test('Ersteller ist Administrator (100, in der App Moderator), alle anderen 0 (E-61)', () {
      expect(pl['users'], <String, int>{'@anna:x.org': 100});
      expect(PowerLevels.roleFor(PowerLevels.admin), Role.moderator);
      expect(pl['users_default'], 0);
      expect(pl['events_default'], 0);
    });

    test('Moderationsrechte liegen auf 50, Rollenänderung ebenfalls', () {
      for (final k in <String>['invite', 'kick', 'ban', 'redact', 'state_default']) {
        expect(pl[k], 50, reason: k);
      }
      expect((pl['events']! as Map<String, int>)['m.room.power_levels'], 50);
    });

    test('unveränderliche Zustände liegen unerreichbar über dem Administrator', () {
      final ev = pl['events']! as Map<String, int>;
      expect(ev['m.room.tombstone'], 101);
      expect(ev['m.room.server_acl'], 101);
    });

    test('jeder beim Anlegen gesetzte Zustand ist für den Ersteller (100) erlaubt', () {
      final ev = pl['events']! as Map<String, int>;
      for (final s in FamilyRoomSpec.initialState()) {
        final needed = ev[s.type] ?? (pl['state_default']! as int);
        expect(needed, lessThanOrEqualTo(PowerLevels.admin), reason: s.type);
        expect(needed, lessThanOrEqualTo(PowerLevels.moderator), reason: '${s.type} (auch Moderatoren)');
      }
    });

    test('Raumversion 10 (Ersteller ohne unendliche Macht)', () {
      expect(FamilyRoomSpec.roomVersion, '10');
    });
  });
}
