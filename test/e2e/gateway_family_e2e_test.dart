import 'dart:async';
import 'dart:io';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Role;

import '../support/events.dart';
import 'e2e_support.dart';

/// Wie in der App: Anmeldung, dann Pflicht-Schlüsselsicherung (nur verifizierte Geräte erhalten Schlüssel).
Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

/// Alle Teilnehmer treten über Anfrage → Bestätigung → Annahme bei.
Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => user.joinRequestPending, what: 'Anfrage wartet');
  await E2e.until(
    () => mod.family?.member(user.userId!)?.status == MemberStatus.requested,
    what: 'Moderator sieht Anfrage',
  );
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

/// #140: Konto in einem zweiten Raum. Über den rohen Client, weil `acceptInvitation` bei bestehender Familie abbricht.
Future<void> _rawJoin(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final roomId = mod.family!.roomId;
  await mod.inviteUser(user.userId!);
  final client = user.sdkClient!;
  await E2e.until(() => client.getRoomById(roomId)?.membership == Membership.invite, what: 'Einladung über den Sync');
  await client.joinRoomById(roomId);
  await E2e.until(() => client.getRoomById(roomId)?.membership == Membership.join, what: 'Beitritt über den Sync');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Moderator sieht den Beitritt');
}

/// Die Kontodaten zeigen auf einen anderen Raum: Join B, Leave A und Kontodaten können in einer Sync-Antwort kommen.
Future<void> _pointFamilyTo(SdkMatrixGateway g, String roomId) =>
    g.sdkClient!.setAccountData(g.userId!, SdkMatrixGateway.familyAccountData, <String, Object?>{'room_id': roomId});

/// Wie die neuen Dienste nach einem Wechsel: Zuhörer ab jetzt, samt Wiedergabe der Historie.
List<CalendarSignal> _listen(SdkMatrixGateway g) {
  final got = <CalendarSignal>[];
  final sub = g.calendarSignals.listen(got.add);
  addTearDown(sub.cancel);
  return got;
}

/// Anwendungsereignisse eines Raums laut Server (Chiffretext); so zeigt sich, ob etwas angekommen ist.
Future<int> _sent(SdkMatrixGateway reader, String roomId) async {
  final raw = await reader.sdkClient!.getRoomEvents(roomId, Direction.b, limit: 100);
  return raw.chunk.where((e) => e.type == 'm.room.encrypted').length;
}

CalendarEvent _shared(SdkMatrixGateway owner, String id, String title) => ev(owner: owner.userId!, id: id, title: title);

Iterable<String> _sharedFrom(List<CalendarSignal> got, SdkMatrixGateway sender) =>
    got.whereType<SharedEventSignal>().where((s) => s.sender == sender.userId).map((s) => s.content['title']! as String);

const String _idA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String _idB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const String _idC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  group('Familienwechsel im selben Prozess (#140)', skip: E2e.enabled ? false : E2e.skipReason, () {
    /// Zwei Familien, dazu ein Konto, das zunächst nur in A ist.
    Future<({SdkMatrixGateway modA, SdkMatrixGateway modB, SdkMatrixGateway user, String roomA, String roomB})> twoFamilies(String prefix) async {
      final modA = await _login('${prefix}moda');
      await modA.createFamily('Familie A');
      await E2e.until(() => modA.family != null);
      final modB = await _login('${prefix}modb');
      await modB.createFamily('Familie B');
      await E2e.until(() => modB.family != null);
      final user = await _login('${prefix}user');
      return (modA: modA, modB: modB, user: user, roomA: modA.family!.roomId, roomB: modB.family!.roomId);
    }

    test('A → keine Familie → B: nichts aus A, kein Beitrittssignal; der private Termin kommt wieder', () async {
      final t = await twoFamilies('leer');
      await _join(t.modA, t.user);
      final before = _listen(t.user);
      await t.modA.publishSharedEvent(_shared(t.modA, _idA, 'AUS-A'));
      await t.user.publishPrivateEvent(ev(owner: t.user.userId!, id: _idC, title: 'PRIVAT', visibility: EventVisibility.private));
      await E2e.until(() => _sharedFrom(before, t.modA).isNotEmpty && before.whereType<PrivateEventSignal>().isNotEmpty, what: 'Signale aus A');
      await E2e.until(() => t.user.debugParticipantsLoaded, what: 'Mitglieder von A');

      await t.modA.removeMember(t.user.userId!);
      await E2e.until(() => t.user.family == null, what: 'Familie entfernt');
      await _join(t.modB, t.user);
      await t.modB.publishSharedEvent(_shared(t.modB, _idB, 'AUS-B'));

      // Wie `calendarBuilder` nach dem Wipe: Die neuen Dienste hören ab jetzt zu.
      final fresh = _listen(t.user);
      await E2e.until(() => _sharedFrom(fresh, t.modB).isNotEmpty, what: 'Signal aus B');
      await E2e.until(() => fresh.whereType<PrivateEventSignal>().isNotEmpty, what: 'privater Termin erneut');
      await E2e.until(() => t.user.debugParticipantsLoaded, what: 'Mitglieder von B');
      expect(t.user.family!.member(t.modB.userId!)?.status, MemberStatus.joined);

      // Ein weiterer Abgleich: Die Mitglieder von B sind jetzt die Basis, nicht „neu beigetreten“.
      await t.modB.publishSharedEvent(_shared(t.modB, _idC, 'AUS-B-2'));
      await E2e.until(() => _sharedFrom(fresh, t.modB).length == 2, what: 'zweites Signal aus B');
      expect(_sharedFrom(fresh, t.modA), isEmpty, reason: 'Termine aus A kehren nicht zurück');
      expect(fresh.whereType<MemberJoinedSignal>(), isEmpty, reason: 'sonst Resync der Daten aus A nach B');

      // Der Resync für echte Beitritte bleibt.
      final next = await _login('leerneu');
      await _join(t.modB, next);
      await E2e.until(() => fresh.whereType<MemberJoinedSignal>().any((s) => s.sender == next.userId), what: 'echter Beitritt gemeldet');
    });

    test('direkter Wechsel über die Kontodaten: kein Signal aus A, Mitgliederliste von B geladen', () async {
      final t = await twoFamilies('dir');
      await _join(t.modA, t.user);
      await _rawJoin(t.modB, t.user);
      final before = _listen(t.user);
      await t.modA.publishSharedEvent(_shared(t.modA, _idA, 'AUS-A'));
      await E2e.until(() => _sharedFrom(before, t.modA).isNotEmpty, what: 'Signal aus A');
      await E2e.until(() => t.user.debugParticipantsLoaded, what: 'Mitglieder von A');

      await _pointFamilyTo(t.user, t.roomB);
      await E2e.until(() => t.user.family?.roomId == t.roomB, what: 'Familie B übernommen');
      await t.modB.publishSharedEvent(_shared(t.modB, _idB, 'AUS-B'));

      final fresh = _listen(t.user);
      await E2e.until(() => _sharedFrom(fresh, t.modB).isNotEmpty, what: 'Signal aus B');
      await E2e.until(() => t.user.debugParticipantsLoaded, what: 'Mitglieder von B');
      await E2e.until(() => t.user.family?.member(t.modB.userId!)?.status == MemberStatus.joined, what: 'Mitgliederliste von B');
      expect(t.user.family!.member(t.modA.userId!), isNull);
      expect(_sharedFrom(fresh, t.modA), isEmpty);
      expect(fresh.whereType<MemberJoinedSignal>(), isEmpty);
    });

    test('Wiederbeitritt zu A: idempotent, jedes Ereignis höchstens einmal, kein Beitrittssignal', () async {
      final modA = await _login('wiedermod');
      await modA.createFamily('Familie A');
      await E2e.until(() => modA.family != null);
      final user = await _login('wiederuser');
      await _join(modA, user);
      final roomA = modA.family!.roomId;
      await modA.publishSharedEvent(_shared(modA, _idA, 'ERSTES'));
      final before = _listen(user);
      await E2e.until(() => _sharedFrom(before, modA).isNotEmpty, what: 'erstes Signal');

      await modA.removeMember(user.userId!);
      await E2e.until(() => user.family == null, what: 'Familie entfernt');
      // Die Kontodaten zeigen noch auf A, `acceptInvitation` hielte das für eine bestehende Familie.
      await _rawJoin(modA, user);
      await E2e.until(() => user.family?.roomId == roomA, what: 'wieder in A');
      await modA.publishSharedEvent(_shared(modA, _idB, 'ZWEITES'));

      final fresh = _listen(user);
      await E2e.until(() => _sharedFrom(fresh, modA).contains('ZWEITES'), what: 'neues Signal nach dem Wiederbeitritt');
      await E2e.until(() => user.debugParticipantsLoaded, what: 'Mitglieder geladen');
      final titles = _sharedFrom(fresh, modA).toList();
      expect(titles.toSet(), hasLength(titles.length), reason: 'kein Ereignis doppelt');
      expect(fresh.whereType<MemberJoinedSignal>(), isEmpty);
      await user.sendMessage('wieder da');
      await E2e.until(() => modA.messages.any((m) => m.body == 'wieder da'), what: 'Nachricht nach dem Wiederbeitritt');
    });

    test('der Link-Vermerk eines anderen Moderators aus A macht eine Anfrage in B nicht gültig', () async {
      final t = await twoFamilies('link');
      await _join(t.modA, t.user);
      await t.modA.promote(t.user.userId!);
      await E2e.until(() => t.user.family?.myRole == Role.moderator, what: 'Moderator in A');
      final viaA = InviteLink.tryParse(await t.modA.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      final first = await _login('linkerst');
      await first.requestToJoin(viaA);
      await E2e.until(() => t.user.family?.member(first.userId!)?.request == RequestCheck.valid, what: 'Vermerk aus A liegt vor');

      await _rawJoin(t.modB, t.user);
      await t.modB.promote(t.user.userId!);
      await _pointFamilyTo(t.user, t.roomB);
      await E2e.until(() => t.user.family?.roomId == t.roomB && t.user.family?.myRole == Role.moderator, what: 'Moderator in B');

      final second = await _login('linkzweit');
      final forged = InviteLink(roomId: t.roomB, via: 'localhost', inviter: t.modB.userId!, expires: viaA.expires, nonce: viaA.nonce);
      await second.requestToJoin(forged);
      await E2e.until(() => t.user.family?.member(second.userId!)?.status == MemberStatus.requested, what: 'Anfrage in B');
      expect(t.user.family!.member(second.userId!)!.request, RequestCheck.unknown);
      await expectLater(t.user.approveRequest(second.userId!), _error(GatewayError.notAllowed));
    });

    test('verspätete Mitgliederliste aus A: keine Basis für B', () async {
      final t = await twoFamilies('gen');
      final gates = <Completer<void>>[];
      t.user.debugBeforeParticipantsLoaded = () {
        final c = Completer<void>();
        gates.add(c);
        return c.future;
      };
      await _join(t.modA, t.user);
      await E2e.until(() => gates.length == 1, what: 'Liste aus A wartet');
      await _rawJoin(t.modB, t.user);
      await _pointFamilyTo(t.user, t.roomB);
      await E2e.until(() => t.user.family?.roomId == t.roomB && gates.length == 2, what: 'Liste aus B wartet');

      gates.first.complete();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(t.user.debugParticipantsLoaded, isFalse, reason: 'die Liste aus A gilt nicht für B');

      final fresh = _listen(t.user);
      gates.last.complete();
      await E2e.until(() => t.user.debugParticipantsLoaded, what: 'Liste aus B');
      await t.modB.publishSharedEvent(_shared(t.modB, _idB, 'AUS-B'));
      await E2e.until(() => _sharedFrom(fresh, t.modB).isNotEmpty, what: 'Abgleich nach der Liste aus B');
      expect(fresh.whereType<MemberJoinedSignal>(), isEmpty);
    });

    test('vor dem ersten Abgleich nach dem Kontodaten-Wechsel geht nichts in den neuen Raum', () async {
      final t = await twoFamilies('vorab');
      await _join(t.modA, t.user);
      await _rawJoin(t.modB, t.user);
      final inB = await _sent(t.modB, t.roomB);

      // Wie direkt nach dem Sync: Die Kontodaten stehen, der entprellte Abgleich (150 ms) steht noch aus.
      t.user.sdkClient!.accountData[SdkMatrixGateway.familyAccountData] = BasicEvent(
        type: SdkMatrixGateway.familyAccountData,
        content: <String, Object?>{'room_id': t.roomB},
      );
      expect(t.user.family!.roomId, t.roomA);
      final shared = t.user.publishSharedEvent(_shared(t.user, _idA, 'AUS-A'));
      final message = t.user.sendMessage('falscher Raum');
      await expectLater(shared, _error(GatewayError.serverUnreachable));
      await expectLater(message, _error(GatewayError.serverUnreachable));

      await _pointFamilyTo(t.user, t.roomB);
      await E2e.until(() => t.user.family?.roomId == t.roomB, what: 'Familie B übernommen');
      expect(await _sent(t.modB, t.roomB), inB);
    });

    test('Fenster vor dem Abgleich: Senden, Raumaktionen und Link-Vermerk gehen nicht in den neuen Raum', () async {
      final t = await twoFamilies('fenster');
      await _join(t.modA, t.user);
      await t.modA.promote(t.user.userId!);
      await E2e.until(() => t.user.family?.myRole == Role.moderator, what: 'Moderator in A');
      await _rawJoin(t.modB, t.user);
      final asker = await _login('fensterfrage');
      await asker.requestToJoin(InviteLink.tryParse(await t.user.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!);
      await E2e.until(() => t.user.family?.member(asker.userId!)?.request == RequestCheck.valid, what: 'Anfrage in A');
      final inB = await _sent(t.modB, t.roomB);

      final gate = Completer<void>();
      t.user.debugBeforeFamilyTimeline = () => gate.future;
      await _pointFamilyTo(t.user, t.roomB);
      await E2e.until(
        () => t.user.sdkClient!.accountData[SdkMatrixGateway.familyAccountData]?.content['room_id'] == t.roomB,
        what: 'Kontodaten über den Sync',
      );
      expect(t.user.family!.roomId, t.roomA, reason: '`_familyRoom()` ist B, `family` noch A');

      final unreachable = _error(GatewayError.serverUnreachable);
      await expectLater(t.user.publishSharedEvent(_shared(t.user, _idA, 'AUS-A')), unreachable);
      await expectLater(t.user.publishRsvp(_idA, RsvpStatus.accepted, DateTime.utc(2026, 3, 1)), unreachable);
      await expectLater(t.user.sendMessage('falscher Raum'), unreachable);
      await expectLater(t.user.approveRequest(asker.userId!), unreachable);
      await expectLater(t.user.renameFamily('Gekapert'), unreachable);
      await t.user.createInviteLink(); // Der Link entsteht, sein Vermerk geht nicht in den neuen Raum.

      gate.complete();
      await E2e.until(() => t.user.family?.roomId == t.roomB, what: 'Familie B übernommen');
      t.user.debugBeforeFamilyTimeline = null;
      await t.modB.sendMessage('Marke');
      await E2e.until(() => t.user.messages.any((m) => m.body == 'Marke'), what: 'B läuft');

      expect(await _sent(t.modB, t.roomB), inB + 1, reason: 'nur die Marke kam in B an');
      expect(t.modB.family!.name, 'Familie B');
      expect(t.modA.family!.member(asker.userId!)?.status, MemberStatus.requested, reason: 'die Anfrage in A ist unberührt');

      // Nach dem Abgleich geht wieder alles, in die neue Familie.
      await t.user.sendMessage('angekommen');
      await E2e.until(() => t.modB.messages.any((m) => m.body == 'angekommen'), what: 'Senden nach dem Wechsel');
    });
  });

  group('Familie, Einladung, Rollen gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('#129: Foto mit Vorschaubild kommt beim Mitglied an, die Datei bleibt unverändert', () async {
      final a = await _login('fotoa');
      await a.createFamily('Familie Foto');
      await E2e.until(() => a.family != null);
      final b = await _login('fotob');
      await _join(a, b);

      final photo = File('assets/icon/app_icon.png').readAsBytesSync(); // 1254 × 1254 Pixel
      await a.sendAttachment(fileName: 'foto.png', bytes: photo);
      await E2e.until(() => b.messages.any((m) => m.attachment?.name == 'foto.png'), what: 'Foto beim Mitglied');
      final message = b.messages.lastWhere((m) => m.attachment?.name == 'foto.png');
      expect(await b.loadAttachment(message.id), photo);

      final event = (await a.sdkClient!.getRoomById(a.family!.roomId)!.getEventById(message.id))!;
      expect(event.type, 'm.room.message');
      expect(event.content.tryGetMap<String, Object?>('info')?['thumbnail_file'], isNotNull, reason: 'Vorschaubild verschlüsselt');
    });

    test('Beitritt per Link: Anfrage → Bestätigung → Annahme; Chat wird entschlüsselt', () async {
      final a = await _login('mod');
      await a.createFamily('Familie Einladung');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');

      await _join(a, b);
      expect(b.family!.myRole, Role.member);
      expect(b.family!.name, 'Familie Einladung');
      expect(b.joinRequestPending, isFalse);

      await a.sendMessage('Willkommen!');
      await E2e.until(() => b.messages.any((m) => m.body == 'Willkommen!'), what: 'B entschlüsselt Annes Nachricht');
      await b.sendMessage('Danke!');
      await E2e.until(() => a.messages.any((m) => m.body == 'Danke!'), what: 'A entschlüsselt Bens Nachricht');
    });

    test('Einladungslink: gefälschte ID nicht bestätigbar, Link nur einmal verwendbar, Identität vermerkt', () async {
      final a = await _login('mod');
      await a.createFamily('Nonce');
      await E2e.until(() => a.family != null);
      final forger = await _login('fake');
      final real = await _login('real');

      // Link mit selbst gewählter ID (nicht vom Moderator ausgegeben).
      final good = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      final forged = InviteLink(roomId: good.roomId, via: good.via, inviter: good.inviter, expires: good.expires, nonce: 'a' * 32);
      await forger.requestToJoin(forged);
      await E2e.until(() => a.family?.member(forger.userId!)?.status == MemberStatus.requested, what: 'Anfrage des Fälschers');
      expect(a.family!.member(forger.userId!)!.request, RequestCheck.unknown);
      await expectLater(a.approveRequest(forger.userId!), _error(GatewayError.notAllowed));
      await a.rejectRequest(forger.userId!);

      // Echter Link: bestätigbar, danach verbraucht.
      await real.requestToJoin(good);
      await E2e.until(() => a.family?.member(real.userId!)?.request == RequestCheck.valid, what: 'gültige Anfrage');
      await a.approveRequest(real.userId!);
      await forger.cancelJoinRequest();
      await forger.requestToJoin(good);
      await E2e.until(() => a.family?.member(forger.userId!)?.status == MemberStatus.requested, what: 'zweite Anfrage');
      await E2e.until(() => a.family?.member(forger.userId!)?.request == RequestCheck.unknown, what: 'Link verbraucht');
      await expectLater(a.approveRequest(forger.userId!), _error(GatewayError.notAllowed));
    });

    test('Mitglied hat keine Verwaltungsrechte – im Gateway UND auf dem Server', () async {
      final a = await _login('mod');
      await a.createFamily('Rechte');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      await _join(a, b);
      final c = await _login('dritter');

      await expectLater(b.createInviteLink(), throwsA(isA<GatewayException>()));
      await expectLater(b.inviteUser(c.userId!), _error(GatewayError.notAllowed));
      await expectLater(b.renameFamily('Gekapert'), _error(GatewayError.notAllowed));
      await expectLater(b.removeMember(a.userId!), _error(GatewayError.notAllowed));
      await expectLater(b.promote(b.userId!), _error(GatewayError.notAllowed));

      // Selbst bei umgangener Oberfläche lehnt der Server ab (Power-Level 0 < 50).
      final raw = b.sdkClient!;
      await expectLater(
        raw.inviteUser(b.family!.roomId, c.userId!),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      await expectLater(
        raw.setRoomStateWithKey(b.family!.roomId, 'm.room.name', '', <String, Object?>{'name': 'Gekapert'}),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      await expectLater(
        raw.setRoomStateWithKey(b.family!.roomId, 'm.room.encryption', '', <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'}),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      expect(a.family!.name, 'Rechte');
    });

    test('Ernennen, Umbenennen, Moderatoren sind gleichrangig', () async {
      final a = await _login('mod');
      await a.createFamily('Rollen');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      await _join(a, b);

      await a.promote(b.userId!);
      await E2e.until(() => b.family?.myRole == Role.moderator, what: 'B ist Moderator');
      await E2e.until(() => a.family?.moderatorCount == 2);
      expect(a.family!.needsSecondModerator, isFalse);

      await b.renameFamily('Neuer Name');
      await E2e.until(() => a.family?.name == 'Neuer Name', what: 'Umbenennung sichtbar');

      // Moderatoren können einander weder entfernen noch herabstufen (E-10).
      await expectLater(a.removeMember(b.userId!), _error(GatewayError.notAllowed));
      await expectLater(b.removeMember(a.userId!), _error(GatewayError.notAllowed));
    });

    test('Issue #7: Mitglied zum Moderator hochstufen – auch durch einen ernannten Moderator und mehrfach hintereinander', () async {
      final a = await _login('mod');
      await a.createFamily('Hochstufen');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      final c = await _login('dritter');
      final d = await _login('vierter');
      await _join(a, b);
      await _join(a, c);
      await _join(a, d);

      // Ersteller ernennt B; B (ernannt, nicht Ersteller) ernennt C.
      await a.promote(b.userId!);
      await E2e.until(() => b.family?.myRole == Role.moderator, what: 'B ist Moderator');
      await b.promote(c.userId!);
      await E2e.until(() => a.family?.member(c.userId!)?.role == Role.moderator, what: 'C ist Moderator (aus A-Sicht)');
      await E2e.until(() => c.family?.myRole == Role.moderator, what: 'C ist Moderator');

      // Sofort danach ernennt A noch D, ohne den Abgleich abzuwarten.
      await a.promote(d.userId!);
      await E2e.until(() => d.family?.myRole == Role.moderator, what: 'D ist Moderator');
      await E2e.until(() => a.family?.moderatorCount == 4, what: 'Vier Moderatoren');
    });

    test('Issue #7: zwei Ernennungen unmittelbar hintereinander (veralteter Zwischenspeicher)', () async {
      final a = await _login('mod');
      await a.createFamily('Hintereinander');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      final c = await _login('dritter');
      await _join(a, b);
      await _join(a, c);

      await a.promote(b.userId!);
      await a.promote(c.userId!); // ohne den Abgleich von B abzuwarten
      await E2e.until(() => b.family?.myRole == Role.moderator, what: 'B ist Moderator');
      await E2e.until(() => c.family?.myRole == Role.moderator, what: 'C ist Moderator');
      await E2e.until(() => a.family?.moderatorCount == 3, what: 'Drei Moderatoren');
    });

    test('Issue #9: Ersteller ist im Raum Administrator (100), in der App Moderator; Moderator bleibt bei 50', () async {
      final a = await _login('mod');
      await a.createFamily('Admin');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      await _join(a, b);
      await a.promote(b.userId!);
      await E2e.until(() => b.family?.myRole == Role.moderator, what: 'B ist Moderator');

      final roomA = a.sdkClient!.getRoomById(a.family!.roomId)!;
      expect(roomA.getPowerLevelByUserId(a.userId!).level, 100);
      expect(roomA.getPowerLevelByUserId(b.userId!).level, 50);
      expect(a.family!.myRole, Role.moderator);
      expect(a.family!.member(a.userId!)!.role, Role.moderator);
      expect(a.family!.moderatorCount, 2);

      // Der Administrator bleibt für den ernannten Moderator unantastbar (App und Server).
      await expectLater(b.removeMember(a.userId!), _error(GatewayError.notAllowed));
      await expectLater(
        b.sdkClient!.setRoomStateWithKey(a.family!.roomId, 'm.room.power_levels', '', <String, Object?>{
          ...roomA.getState('m.room.power_levels')!.content,
          'users': <String, Object?>{a.userId!: 50, b.userId!: 50},
        }),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      await expectLater(
        b.sdkClient!.kick(a.family!.roomId, a.userId!),
        throwsA(isA<MatrixException>().having((e) => e.errcode, 'errcode', 'M_FORBIDDEN')),
      );
      // Der ernannte Moderator darf weiterhin alles Übliche (Umbenennen).
      await b.renameFamily('Von B');
      await E2e.until(() => a.family?.name == 'Von B', what: 'Umbenennung sichtbar');
    });

    test('Ablehnen einer Anfrage und abgelaufene/ungültige Links', () async {
      final a = await _login('mod');
      await a.createFamily('Ablehnen');
      await E2e.until(() => a.family != null);
      final d = await _login('fremd');

      final link = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      await d.requestToJoin(link);
      await E2e.until(() => a.family?.member(d.userId!)?.status == MemberStatus.requested);
      await a.rejectRequest(d.userId!);
      await E2e.until(() => a.family?.member(d.userId!) == null, what: 'Anfrage entfernt');
      // Die Ablehnung kommt als „verlassen“-Ereignis an (das SDK liefert den knock-Abschnitt nicht).
      await E2e.until(() => d.joinRequestRejected, what: 'Ablehnung sichtbar');
      expect(d.joinRequestPending, isFalse);
      await d.cancelJoinRequest();
      expect(d.joinRequestRejected, isFalse);
      expect(d.joinRequestPending, isFalse);
      expect(d.family, isNull);

      // abgelaufen
      final old = InviteLink.tryParse(
        InviteLink.create(roomId: a.family!.roomId, via: 'localhost', inviter: a.userId!, now: DateTime.now().subtract(const Duration(days: 3)), validity: const Duration(hours: 1), nonce: '0123456789abcdef0123456789abcdef', ownHost: 'localhost'),
        now: DateTime.now().subtract(const Duration(days: 3)),
        ownHost: 'localhost',
      )!;
      await expectLater(d.requestToJoin(old), _error(GatewayError.invalidInput));
      // unbekannter Raum
      final bogus = InviteLink(roomId: '!gibtsnicht:localhost', via: 'localhost', inviter: a.userId!, expires: DateTime.now().add(const Duration(hours: 1)), nonce: '0123456789abcdef0123456789abcdef');
      await expectLater(d.requestToJoin(bogus), throwsA(isA<GatewayException>()));
    });

    test('Entfernen rotiert den Raumschlüssel; Entfernte lesen neue Nachrichten nicht', () async {
      final a = await _login('mod');
      await a.createFamily('Rotation');
      await E2e.until(() => a.family != null);
      final b = await _login('mem');
      final c = await _login('ausscheiden');
      await _join(a, b);
      await _join(a, c);

      await a.sendMessage('vor dem Entfernen');
      await E2e.until(() => c.messages.any((m) => m.body == 'vor dem Entfernen'), what: 'C liest vorher');

      await a.removeMember(c.userId!);
      await E2e.until(() => a.family?.member(c.userId!) == null, what: 'C entfernt');
      await E2e.until(() => c.family == null, what: 'C hat keine Familie mehr');

      await a.sendMessage('nach dem Entfernen');
      await E2e.until(() => b.messages.any((m) => m.body == 'nach dem Entfernen'), what: 'B liest nachher');
      expect(c.messages.any((m) => m.body == 'nach dem Entfernen'), isFalse);

      final client = a.sdkClient!;
      final raw = await client.getRoomEvents(a.family!.roomId, Direction.b, limit: 50);
      final sessions = <String>[
        for (final e in raw.chunk.reversed)
          if (e.type == 'm.room.encrypted') (e.content['session_id'] as String?) ?? '',
      ];
      expect(sessions.length, greaterThanOrEqualTo(2));
      expect(sessions.first, isNot(sessions.last), reason: 'neue Megolm-Sitzung nach dem Entfernen');
    });

    test('Einladung per Matrix-ID und Ablehnen einer Einladung', () async {
      final a = await _login('mod');
      await a.createFamily('Direkt');
      await E2e.until(() => a.family != null);
      final e1 = await _login('direkt');
      await a.inviteUser(e1.userId!);
      await E2e.until(() => e1.invitations.isNotEmpty);
      expect(e1.invitations.single.roomName, 'Direkt');
      expect(e1.invitations.single.inviterId, a.userId);
      await e1.declineInvitation(e1.invitations.single.roomId);
      await E2e.until(() => e1.invitations.isEmpty, what: 'Einladung abgelehnt');
      expect(e1.family, isNull);
    });
  });
}
