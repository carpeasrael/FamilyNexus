import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/member_avatars.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Role;

import 'e2e_support.dart';

/// #422, E-101: Avatar als Raumzustand gegen den echten Synapse. Alle Gateways starten mit
/// `ensureAvatarPermission: false`, damit die Freischaltung nie automatisch und nie zufällig läuft: Welches Gateway
/// wann freischaltet, legen allein die Aufrufe von `debugRunAvatarPermission()` fest. Das automatische Verhalten
/// (Lauf bei jedem Aufbau, Pausen, Wiederholung nach `M_FORBIDDEN`) deckt `test/data/avatar_gateway_test.dart` ab.
const String _type = AvatarPresets.type;

/// Wie in der App: Anmeldung, dann Pflicht-Schlüsselsicherung (nur verifizierte Geräte erhalten Schlüssel).
Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix, ensureAvatarPermission: false);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

/// Beitritt über Anfrage → Bestätigung → Annahme (dupliziert aus `gateway_family_e2e_test.dart`, dort dateiprivat).
Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => user.joinRequestPending, what: 'Anfrage wartet');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht Anfrage');
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

Future<SdkMatrixGateway> _family(String prefix) async {
  final g = await _login(prefix);
  await g.createFamily('Avatar-Familie');
  await E2e.until(() => g.family != null, what: 'Familie angelegt');
  return g;
}

Map<String, Object?> _levels(SdkMatrixGateway g) {
  final c = g.sdkClient!.getRoomById(g.family!.roomId)!.getState(EventTypes.RoomPowerLevels)?.content;
  return c ?? const <String, Object?>{};
}

bool _hasPermission(SdkMatrixGateway g) => AvatarPresets.isPermitted(_levels(g));

/// Zustand einer Familie von vor dem Update: ohne Freigabe des Avatar-Typs, Ersteller auf [creatorLevel].
Future<void> _revokePermission(SdkMatrixGateway creator, {required int creatorLevel}) async {
  final client = creator.sdkClient!;
  final roomId = creator.family!.roomId;
  final current = await client.getRoomStateWithKey(roomId, EventTypes.RoomPowerLevels, '');
  final events = <String, Object?>{...(current['events']! as Map).cast<String, Object?>()}..remove(_type);
  final users = <String, Object?>{...(current['users']! as Map).cast<String, Object?>(), creator.userId!: creatorLevel};
  await client.setRoomStateWithKey(roomId, EventTypes.RoomPowerLevels, '', <String, Object?>{...current, 'events': events, 'users': users});
}

Future<Map<String, Object?>> _serverLevels(SdkMatrixGateway g) =>
    g.sdkClient!.getRoomStateWithKey(g.family!.roomId, EventTypes.RoomPowerLevels, '');

/// Familie von vor dem Update: G1 (Ersteller), G2 (Mitglied), G3 (ernannter Moderator, 50). Der Zustand ohne
/// Freigabe ist bei allen angekommen, bevor die Funktion zurückkehrt.
Future<({SdkMatrixGateway g1, SdkMatrixGateway g2, SdkMatrixGateway g3})> _oldFamily(String prefix, {required int creatorLevel}) async {
  final g1 = await _family('${prefix}1');
  final g2 = await _login('${prefix}2');
  final g3 = await _login('${prefix}3');
  await _join(g1, g2);
  await _join(g1, g3);
  await g1.promote(g3.userId!);
  await E2e.until(() => g3.family?.myRole == Role.moderator, what: 'G3 ist Moderator');
  await _revokePermission(g1, creatorLevel: creatorLevel);
  // Der Stand ohne Freigabe ist im SDK der Gateways angekommen.
  for (final g in <SdkMatrixGateway>[g1, g2, g3]) {
    await E2e.until(() => !_hasPermission(g) && _levels(g).isNotEmpty, what: 'Stand ohne Freigabe bei ${g.userId}');
  }
  await E2e.until(() => g2.avatarAvailability == AvatarAvailability.needsModerator, what: 'G2 sieht needsModerator');
  return (g1: g1, g2: g2, g3: g3);
}

Future<void> _g2ChoosesAfter(SdkMatrixGateway runner, SdkMatrixGateway g2, SdkMatrixGateway reader) async {
  // Der Moderator liest den Stand erst, wenn der Stand ohne Freigabe bei ihm im SDK angekommen ist (siehe `_oldFamily`).
  await runner.debugRunAvatarPermission();
  expect(AvatarPresets.isPermitted(await _serverLevels(runner)), isTrue, reason: 'Server hat die Freigabe');
  await E2e.until(() => g2.avatarAvailability == AvatarAvailability.settable, what: 'G2 sieht settable nach dem Abgleich');
  await g2.setMemberAvatar('p05');
  await E2e.until(() => reader.avatarOf(g2.userId!) == 'p05', what: 'Wahl von G2 sichtbar');
}

void main() {
  group('Avatar als Raumzustand (#422, E-101)', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('(a) neue Familie: Mitglied wählt, Ersteller sieht es; fremden Schlüssel setzen scheitert mit 403', () async {
      final g1 = await _family('av-a1');
      final g2 = await _login('av-a2');
      await _join(g1, g2);
      expect(_hasPermission(g1), isTrue, reason: 'neue Familien erhalten die Freigabe beim Anlegen');
      await E2e.until(() => g2.avatarAvailability == AvatarAvailability.settable, what: 'G2 darf wählen');
      await g2.setMemberAvatar('p03');
      await E2e.until(() => g1.avatarOf(g2.userId!) == 'p03', what: 'G1 sieht die Wahl von G2');
      expect(g2.avatarOf(g2.userId!), 'p03');
      expect(g1.avatarOf(g1.userId!), isNull);
      // Fremder Schlüssel: der Server lehnt ab
      await expectLater(
        g2.sdkClient!.setRoomStateWithKey(g2.family!.roomId, _type, g1.userId!, AvatarPresets.content('p01')),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(g1.avatarOf(g1.userId!), isNull, reason: 'die Ablehnung hat nichts verändert');
    });

    test('(b) bestehende Familie ohne Freigabe: G2 needsModerator; ernannter Moderator G3 (50) schaltet frei, G2 wählt', () async {
      final f = await _oldFamily('av-b', creatorLevel: 100);
      expect(f.g2.avatarAvailability, AvatarAvailability.needsModerator);
      await expectLater(f.g2.setMemberAvatar('p05'), throwsA(isA<Object>()));
      await _g2ChoosesAfter(f.g3, f.g2, f.g1);
      expect((await _serverLevels(f.g1))['users'], isA<Map<String, dynamic>>(), reason: 'übrige Felder sind noch da');
    });

    test('(b2) Ersteller auf Stufe 50 schaltet frei', () async {
      final f = await _oldFamily('av-b2', creatorLevel: 50);
      expect(f.g2.avatarAvailability, AvatarAvailability.needsModerator);
      await _g2ChoosesAfter(f.g1, f.g2, f.g3);
      final users = ((await _serverLevels(f.g1))['users']! as Map).cast<String, Object?>();
      expect(users[f.g1.userId], 50, reason: 'Ersteller bleibt auf 50');
      expect(users[f.g3.userId], 50);
    });

    test('(b3) Ersteller bleibt auf Stufe 100 und schaltet frei', () async {
      final f = await _oldFamily('av-b3', creatorLevel: 100);
      await _g2ChoosesAfter(f.g1, f.g2, f.g3);
      final users = ((await _serverLevels(f.g1))['users']! as Map).cast<String, Object?>();
      expect(users[f.g1.userId], 100);
      expect(users[f.g3.userId], 50);
    });

    test('(c) später beigetretenes Mitglied sieht beide Avatare sofort; (d) Wechsel ersetzt die frühere Wahl', () async {
      final g1 = await _family('av-c1');
      final g2 = await _login('av-c2');
      final g3 = await _login('av-c3');
      await _join(g1, g2);
      await E2e.until(() => g2.avatarAvailability == AvatarAvailability.settable);
      await g1.setMemberAvatar('p04');
      await g2.setMemberAvatar('p03');
      await E2e.until(() => g1.avatarOf(g2.userId!) == 'p03' && g2.avatarOf(g1.userId!) == 'p04', what: 'beide Wahlen angekommen');
      await _join(g1, g3);
      await E2e.until(() => g3.avatarOf(g1.userId!) == 'p04' && g3.avatarOf(g2.userId!) == 'p03', what: 'G3 sieht beide Avatare sofort');
      // (d) Wechsel
      final before = g1.avatarRevision.value;
      await g2.setMemberAvatar('p08');
      await E2e.until(() => g1.avatarOf(g2.userId!) == 'p08' && g3.avatarOf(g2.userId!) == 'p08', what: 'Wechsel bei allen');
      // Der Zähler folgt dem entprellten Aufbau der Familie, nicht dem Eintreffen des Zustands.
      await E2e.until(() => g1.avatarRevision.value > before, what: 'die Änderungsmeldung zählt hoch');
      await g2.setMemberAvatar(null);
      await E2e.until(() => g1.avatarOf(g2.userId!) == null, what: 'kein Avatar (leerer Inhalt)');
      final raw = await g1.sdkClient!.getRoomStateWithKey(g1.family!.roomId, _type, g2.userId!);
      expect(raw, isEmpty, reason: 'der Schlüssel bleibt mit leerem Inhalt bestehen');
    });

    test('(e) Moderator entfernt eine Person: avatarOf liefert weiter, nicht mehr beigetreten, Ändern scheitert mit 403', () async {
      final g1 = await _family('av-e1');
      final g2 = await _login('av-e2');
      await _join(g1, g2);
      await E2e.until(() => g2.avatarAvailability == AvatarAvailability.settable);
      await g2.setMemberAvatar('p06');
      await E2e.until(() => g1.avatarOf(g2.userId!) == 'p06');
      final roomId = g1.family!.roomId;
      final removed = g2.userId!;
      await g1.removeMember(removed);
      await E2e.until(() => g1.family?.member(removed)?.status != MemberStatus.joined, what: 'G2 ist nicht mehr beigetreten');
      expect(g1.avatarOf(removed), 'p06', reason: 'die Wahl bleibt im Raumzustand stehen (die Anzeige blendet sie aus)');
      await expectLater(
        g2.sdkClient!.setRoomStateWithKey(roomId, _type, removed, AvatarPresets.content('p01')),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
    });

    test('(f) zwei ernannte Moderatoren auf Stufe 50 schalten gleichzeitig frei: Endzustand, beide bleiben auf 50', () async {
      final g1 = await _family('av-f1');
      final g2 = await _login('av-f2');
      final g3 = await _login('av-f3');
      final g4 = await _login('av-f4');
      await _join(g1, g2);
      await _join(g1, g3);
      await _join(g1, g4);
      await g1.promote(g3.userId!);
      await g1.promote(g4.userId!);
      await E2e.until(() => g3.family?.myRole == Role.moderator && g4.family?.myRole == Role.moderator, what: 'beide Moderatoren');
      await _revokePermission(g1, creatorLevel: 100);
      for (final g in <SdkMatrixGateway>[g3, g4]) {
        await E2e.until(() => !_hasPermission(g) && _levels(g).isNotEmpty, what: 'Stand ohne Freigabe bei ${g.userId}');
      }
      // Endzustandstest: erzwingt keine Überschneidung und beobachtet keine Wiederholung.
      await Future.wait(<Future<void>>[g3.debugRunAvatarPermission(), g4.debugRunAvatarPermission()]);
      final server = await _serverLevels(g1);
      expect(AvatarPresets.isPermitted(server), isTrue, reason: 'am Ende steht der Eintrag');
      final users = (server['users']! as Map).cast<String, Object?>();
      expect(users[g3.userId], 50);
      expect(users[g4.userId], 50);
      expect(users[g1.userId], 100);
    });
  });
}
