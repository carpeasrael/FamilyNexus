// Pen-Test 2026-10-30 – Zugriffskontrolle Familie (E2E gegen lokalen Synapse, tool/synapse/up.sh).
//
// Seit E-78 bestätigt jede Anfrage ein Moderator; die automatische Bestätigung aus dem Pen-Test gibt es nicht mehr.
//
// PT-A1: Einmal-Einladungslink. Ein weitergegebener/abgefangener Link wird von zwei Konten gleichzeitig
//        benutzt, während das Gerät des Moderators kurz nicht synchronisiert (z. B. Hintergrund, Funkloch).
//        Erwartung: Niemand wird von selbst eingeladen; bestätigt der Moderator beide fast gleichzeitig,
//        wird genau EINE Person eingeladen (S2).
// PT-A2: Beitrittsanfrage mit erfundener Link-ID → keine Einladung, nicht bestätigbar.
// PT-A3: Normales Mitglied veröffentlicht einen gefälschten „Link-Vermerk“ (InviteTicket, Rohformat einer alten
//        App mit auto=true) → wird ignoriert, Anfrage bleibt unbestätigt.
// ignore_for_file: invalid_use_of_visible_for_testing_member (Testcode außerhalb von test/)
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/invite_ticket.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/e2e/e2e_support.dart';

Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

void main() {
  setUpAll(E2e.init);

  test('PT-A1: Race – derselbe Link, zwei gleichzeitige Anfragen', () async {
    final a = await _login('ptra');
    await a.createFamily('PT-Race');
    await E2e.until(() => a.family != null, what: 'Familie bei A');
    final link = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
    final c = await _login('ptrc');
    final d = await _login('ptrd');

    // Moderator-Gerät kurz „offline“: Sync anhalten.
    final client = a.sdkClient!;
    client.backgroundSync = false;
    await client.abortSync();

    await Future.wait(<Future<void>>[c.requestToJoin(link), d.requestToJoin(link)]);

    // Moderator kommt zurück.
    client.backgroundSync = true;
    await E2e.until(
      () => a.family?.member(c.userId!) != null && a.family?.member(d.userId!) != null,
      what: 'A sieht beide Anfragen',
    );
    await E2e.until(
      () => a.family?.member(c.userId!)?.request == RequestCheck.valid && a.family?.member(d.userId!)?.request == RequestCheck.valid,
      what: 'A prüft beide Anfragen',
    );
    // Eine alte App würde hier von selbst bestätigen.
    await Future<void>.delayed(const Duration(seconds: 12));
    expect(c.invitations, isEmpty, reason: 'keine Einladung ohne Moderator (E-78)');
    expect(d.invitations, isEmpty, reason: 'keine Einladung ohne Moderator (E-78)');

    // Der Moderator bestätigt beide fast gleichzeitig.
    final results = await Future.wait(<Future<bool>>[
      a.approveRequest(c.userId!).then((_) => true, onError: (Object _) => false),
      a.approveRequest(d.userId!).then((_) => true, onError: (Object _) => false),
    ]);
    // ignore: avoid_print
    print('PT-A1: Bestätigung C=${results.first}, D=${results.last}; '
        'Status bei A: C=${a.family!.member(c.userId!)?.status.name}, D=${a.family!.member(d.userId!)?.status.name}');
    expect(results.where((ok) => ok), hasLength(1), reason: 'Einmal-Link darf nur EINE Person einladen');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('PT-A2: erfundene Link-ID → keine Einladung', () async {
    final a = await _login('ptfa');
    await a.createFamily('PT-Fake');
    await E2e.until(() => a.family != null, what: 'Familie bei A');
    final real = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
    final forged = InviteLink.tryParse(
      InviteLink.create(
        roomId: real.roomId,
        via: real.via,
        inviter: real.inviter,
        now: DateTime.now(),
        nonce: 'deadbeefdeadbeefdeadbeefdeadbeef',
        ownHost: 'localhost',
      ),
      now: DateTime.now(),
      ownHost: 'localhost',
    )!;
    final e = await _login('ptfe');
    await e.requestToJoin(forged);
    await E2e.until(() => a.family?.member(e.userId!)?.status == MemberStatus.requested, what: 'A sieht die Anfrage');
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(e.invitations, isEmpty);
    expect(a.family!.member(e.userId!)!.request, RequestCheck.unknown);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('PT-A3: Mitglied fälscht Link-Vermerk (auto=true) → ignoriert', () async {
    final a = await _login('ptta');
    await a.createFamily('PT-Ticket');
    await E2e.until(() => a.family != null, what: 'Familie bei A');
    // M wird normales Mitglied.
    final m = await _login('pttm');
    final l1 = InviteLink.tryParse(await a.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
    await m.requestToJoin(l1);
    await E2e.until(() => a.family?.member(m.userId!)?.status == MemberStatus.requested, what: 'Anfrage M');
    await E2e.until(() => a.family!.member(m.userId!)!.request == RequestCheck.valid, what: 'Link M gültig');
    await a.approveRequest(m.userId!);
    await E2e.until(() => m.invitations.isNotEmpty, what: 'Einladung M');
    await m.acceptInvitation(m.invitations.single.roomId);
    await E2e.until(() => m.family != null, what: 'M in Familie');
    expect(m.family!.myRole, Role.member);

    // M schickt einen gefälschten Vermerk direkt über das SDK in den Familienraum.
    const nonce = 'feedfacefeedfacefeedfacefeedface';
    final exp = DateTime.now().toUtc().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
    final room = m.sdkClient!.getRoomById(m.family!.roomId)!;
    await room.sendEvent(<String, Object?>{'v': InviteTicket.version, 'n': nonce, 'exp': exp, 'auto': true}, type: InviteTicket.type);

    final x = await _login('pttx');
    final forged = InviteLink.tryParse(
      InviteLink.create(roomId: a.family!.roomId, via: 'localhost', inviter: m.userId!, now: DateTime.now(), nonce: nonce, ownHost: 'localhost'),
      now: DateTime.now(),
      ownHost: 'localhost',
    )!;
    await x.requestToJoin(forged);
    await E2e.until(() => a.family?.member(x.userId!)?.status == MemberStatus.requested, what: 'A sieht Anfrage X');
    await Future<void>.delayed(const Duration(seconds: 8));
    // ignore: avoid_print
    print('PT-A3: Prüfergebnis bei A: ${a.family!.member(x.userId!)!.request?.name}, X eingeladen=${x.invitations.isNotEmpty}');
    expect(x.invitations, isEmpty);
    expect(a.family!.member(x.userId!)!.request, isNot(RequestCheck.valid));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
