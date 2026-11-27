import 'package:family_nexus/data/matrix/contact_group_spec.dart';
import 'package:family_nexus/data/matrix/family_room_spec.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/group_rights.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K4-1 (KONTAKTE §5): Anlagedaten und Schwellen der Gruppe und die Nachprüfung beim Beitritt.
void main() {
  const me = '@ich:hs.example';

  test('Konstanten: Raumversion 10, Name höchstens 60, Megolm, Obergrenze wie ContactLimits', () {
    expect(ContactGroupSpec.roomVersion, '10');
    expect(ContactGroupSpec.nameMax, 60);
    expect(ContactGroupSpec.megolm, 'm.megolm.v1.aes-sha2');
    expect(ContactGroupSpec.maxMembers, ContactLimits.maxGroupMembers);
    expect(ContactGroupSpec.maxMembers, 50);
  });

  test('Anfangszustand: Megolm, Verlauf invited, Beitritt nur auf Einladung (nie knock, nie shared)', () {
    final s = {for (final e in ContactGroupSpec.initialState()) e.type: e.content};
    expect(s.keys.toSet(), <String>{'m.room.encryption', 'm.room.history_visibility', 'm.room.join_rules'});
    expect(s['m.room.encryption'], <String, Object?>{'algorithm': ContactGroupSpec.megolm});
    expect(s['m.room.history_visibility'], <String, Object?>{'history_visibility': 'invited'});
    expect(s['m.room.join_rules'], <String, Object?>{'join_rule': 'invite'});
    expect(ContactGroupSpec.initialState(), hasLength(3));
  });

  test('Power-Levels: Ersteller 100, Schwellen 50, join_rules/history_visibility/encryption 100, Tombstone/ACL 101, kein Avatar', () {
    final p = ContactGroupSpec.powerLevels(me);
    expect(p['users'], <String, int>{me: 100});
    expect(p['users_default'], 0);
    expect(p['events_default'], 0);
    for (final k in <String>['state_default', 'invite', 'kick', 'ban', 'redact']) {
      expect(p[k], 50, reason: k);
    }
    final ev = p['events']! as Map<String, int>;
    expect(ev['m.room.power_levels'], 50);
    expect(ev['m.room.name'], 50);
    expect(ev['m.room.join_rules'], 100);
    expect(ev['m.room.history_visibility'], 100);
    expect(ev['m.room.encryption'], 100);
    expect(ev['m.room.tombstone'], 101);
    expect(ev['m.room.server_acl'], 101);
    expect(ev.keys.where((k) => k.contains('avatar')), isEmpty, reason: 'kein Avatar-Eintrag');
    expect(ev, hasLength(7));
  });

  test('gegenüber der Familie: nur diese drei Schwellen sind höher (Familie 50)', () {
    final fam = FamilyRoomSpec.powerLevels(me)['events']! as Map<String, int>;
    final grp = ContactGroupSpec.powerLevels(me)['events']! as Map<String, int>;
    for (final k in <String>['m.room.join_rules', 'm.room.history_visibility', 'm.room.encryption']) {
      expect(fam[k], 50, reason: 'Familie $k');
      expect(grp[k], 100, reason: 'Gruppe $k');
    }
  });

  group('verifyJoined (Beitrittsmoment)', () {
    bool ok({
      String? algo = ContactGroupSpec.megolm,
      String? rule = 'invite',
      String? history = 'invited',
      int? joined = 3,
      int? invited = 0,
    }) =>
        ContactGroupSpec.verifyJoined(encryptionAlgorithm: algo, joinRule: rule, historyVisibility: history, joined: joined, invited: invited);

    test('Kontrollfall bleibt', () => expect(ok(), isTrue));

    test('Algorithmus: nur Megolm', () {
      expect(ok(algo: null), isFalse);
      expect(ok(algo: 'm.olm.v1.curve25519-aes-sha2'), isFalse);
    });

    test('Regel invite/knock/public/null: nur invite bleibt', () {
      expect(ok(rule: 'knock'), isFalse);
      expect(ok(rule: 'public'), isFalse);
      expect(ok(rule: null), isFalse);
    });

    test('Verlauf: nur invited bleibt (auch null und unbekannt verlassen)', () {
      for (final h in <String?>['shared', 'world_readable', 'joined', 'x', null]) {
        expect(ok(history: h), isFalse, reason: '$h');
      }
    });

    test('Größe G = beigetreten + eingeladen: 49/50 bleiben, 51 verlässt; 30 Eingeladene: 51 verlässt', () {
      expect(ok(joined: 49), isTrue);
      expect(ok(joined: 50), isTrue);
      expect(ok(joined: 51), isFalse);
      expect(ok(joined: 21, invited: 29), isTrue, reason: 'G = 50');
      expect(ok(joined: 21, invited: 30), isFalse, reason: 'G = 51');
      expect(ok(joined: 40, invited: 30), isFalse);
      expect(ok(joined: 50, invited: null), isTrue, reason: 'unbekannte Einladungszahl zählt 0');
    });

    test('unbekannte Beitrittszahl verlässt nicht (Gruppe bleibt sichtbar und sendegesperrt); sonstige Verstöße verlassen trotzdem', () {
      expect(ok(joined: null, invited: null), isTrue);
      expect(ok(joined: null, invited: 99), isTrue);
      expect(ok(joined: null, rule: 'public'), isFalse);
      expect(ok(joined: null, history: 'shared'), isFalse);
      expect(ok(joined: null, algo: null), isFalse);
    });
  });

  group('verifyJoined und GroupHealth.evaluate sind dieselbe Regel', () {
    test('über alle Kombinationen: bleiben genau dann, wenn nicht gesperrt (außer unbekannter Größe)', () {
      for (final megolm in <bool>[true, false]) {
        for (final rule in <String?>['invite', 'public', null]) {
          for (final history in <String?>['invited', 'shared', null]) {
            for (final joined in <int?>[null, 1, 50, 51]) {
              for (final invited in <int?>[null, 0, 1]) {
                final lock = GroupHealth.evaluate(
                    megolm: megolm, joinRule: rule, historyVisibility: history, joined: joined, invited: invited);
                final stays = ContactGroupSpec.verifyJoined(
                    encryptionAlgorithm: megolm ? ContactGroupSpec.megolm : 'm.other',
                    joinRule: rule,
                    historyVisibility: history,
                    joined: joined,
                    invited: invited);
                final expected = lock == GroupSendLock.keiner || lock == GroupSendLock.groesseUnbekannt;
                expect(stays, expected, reason: '$megolm/$rule/$history/$joined/$invited -> $lock');
              }
            }
          }
        }
      }
    });
  });
}
