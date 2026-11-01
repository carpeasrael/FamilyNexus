import 'dart:async';
import 'dart:convert';

import 'package:family_nexus/data/matrix/event_trust.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/invite_ticket.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart' hide Role;

import '../support/events.dart';
import 'e2e_support.dart';

Matcher _error(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

Future<({SdkMatrixGateway g, String user, String password})> _fresh(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync');
  return (g: a.gateway, user: a.user, password: a.password);
}

/// #138: Netz eines Geräts. `PUT …/send/…` lässt sich scheitern lassen und in der Antwort zurückhalten; [puts] hält
/// fest, was das Gerät wirklich senden wollte.
class _Net extends http.BaseClient {
  final http.Client _inner = E2e.lenientClient();
  bool failSends = false;
  Future<void> Function()? holdResponse;
  final List<String> puts = <String>[];

  int putsTo(String roomId) => puts.where((p) => p.contains(roomId)).length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isSend = request.method == 'PUT' && request.url.path.contains('/send/');
    if (isSend) puts.add(Uri.decodeComponent(request.url.path));
    if (isSend && failSends) {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode('{"errcode":"M_UNKNOWN","error":"Testfehler"}')),
        400,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }
    final res = await _inner.send(request);
    final hold = holdResponse;
    if (isSend && hold != null) await hold();
    return res;
  }
}

/// Wie in der App: Anmeldung, dann Pflicht-Schlüsselsicherung (nur verifizierte Geräte erhalten Schlüssel).
Future<SdkMatrixGateway> _secured(String prefix, {_Net? net}) async {
  await E2e.init();
  final acc = await E2e.registerUser(prefix);
  final g = await E2e.newGateway(httpClient: net);
  await g.restore();
  await g.login(server: E2e.server, username: acc.user, password: acc.password);
  await E2e.until(() => g.initialSyncDone, what: 'Sync $prefix');
  await g.setUpSecurity();
  await E2e.until(() => g.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return g;
}

/// Alle Teilnehmer treten über Anfrage → Bestätigung → Annahme bei.
Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht Anfrage');
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

/// Moderator [g] mit steuerbarem Netz und ein Mitglied.
Future<({SdkMatrixGateway g, _Net net, SdkMatrixGateway peer, String roomId})> _familyWithNet(String prefix) async {
  final net = _Net();
  final g = await _secured('${prefix}g', net: net);
  await g.createFamily('Familie $prefix');
  await E2e.until(() => g.family != null);
  final peer = await _secured('${prefix}p');
  await _join(g, peer);
  await E2e.until(() => g.debugParticipantsLoaded, what: 'Mitglieder geladen');
  return (g: g, net: net, peer: peer, roomId: g.family!.roomId);
}

/// Stellt ein Ereignis zu, wie es ein Server im Sync liefern könnte, auch mit `unsigned` und `original_source`.
Future<void> _forge(SdkMatrixGateway g, String roomId, Map<String, Object?> event) {
  final c = g.sdkClient!;
  return c.database.transaction(
    () => c.handleSync(
      SyncUpdate(
        nextBatch: '',
        rooms: RoomsUpdate(join: <String, JoinedRoomUpdate>{
          roomId: JoinedRoomUpdate(timeline: TimelineUpdate(events: <MatrixEvent>[MatrixEvent.fromJson(event)])),
        }),
      ),
    ),
  );
}

Map<String, Object?> _forged(
  String id, {
  required String sender,
  String type = 'm.room.message',
  Map<String, Object?>? content,
  EventStatus? status,
  String? txid,
  Map<String, Object?>? originalSource,
}) =>
    <String, Object?>{
      'type': type,
      'event_id': id,
      'sender': sender,
      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
      'content': content ?? <String, Object?>{'msgtype': 'm.text', 'body': 'GEFAELSCHT'},
      'unsigned': <String, Object?>{'transaction_id': ?txid, messageSendingStatusKey: ?status?.intValue},
      'original_source': ?originalSource,
    };

List<CalendarSignal> _listen(SdkMatrixGateway g) {
  final got = <CalendarSignal>[];
  final sub = g.calendarSignals.listen(got.add);
  addTearDown(sub.cancel);
  return got;
}

Iterable<String> _titles(List<CalendarSignal> got) => got.whereType<SharedEventSignal>().map((s) => s.content['title']! as String);

/// Anwendungsereignisse eines Raums laut Server (Chiffretext).
Future<int> _sent(SdkMatrixGateway reader, String roomId) async {
  final raw = await reader.sdkClient!.getRoomEvents(roomId, Direction.b, limit: 100);
  return raw.chunk.where((e) => e.type == 'm.room.encrypted').length;
}

ChatMessage? _message(SdkMatrixGateway g, String body, {String threadId = ChatThread.familyId}) =>
    g.messagesIn(threadId).where((m) => m.body == body).firstOrNull;

/// Sendet und wartet, bis die Nachricht als gescheitert und wiederholbar dasteht; liefert ihre Transaktions-ID.
Future<String> _failedSend(SdkMatrixGateway g, String body, {String threadId = ChatThread.familyId}) async {
  await g.sendMessage(body, threadId: threadId);
  await E2e.until(
    () => _message(g, body, threadId: threadId)?.status == MessageStatus.failed && _message(g, body, threadId: threadId)!.retryable,
    what: 'Nachricht gescheitert',
  );
  return _message(g, body, threadId: threadId)!.id;
}

const String _id1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String _id2 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const String _id3 = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Klartext in verschlüsselten Räumen (#138)', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('echter Klartext eines Mitglieds: weder Nachricht noch Signal noch Vermerk; Verschlüsseltes kommt weiter an', () async {
      final t = await _familyWithNet('klar');
      await t.g.promote(t.peer.userId!);
      await E2e.until(() => t.peer.family?.myRole == Role.moderator, what: 'Mitglied ist Moderator');
      final got = _listen(t.g);
      final raw = t.peer.sdkClient!;
      Future<void> plain(String type, Map<String, Object?> content) =>
          raw.sendMessage(t.roomId, type, raw.generateUniqueTransactionId(), content);

      final valid = InviteLink.tryParse(await t.g.createInviteLink(), now: DateTime.now(), ownHost: 'localhost')!;
      const nonce = '0123456789abcdef0123456789abcdef';
      final expires = valid.expires.toUtc().millisecondsSinceEpoch ~/ 1000;
      await plain('m.room.message', <String, Object?>{'msgtype': 'm.text', 'body': 'KLARTEXT'});
      await plain(EventCodec.sharedType, EventCodec.encodeShared(ev(owner: t.peer.userId!, id: _id1, title: 'KLARTEXT-TERMIN')));
      await plain(InviteTicket.type, InviteTicket(nonce: nonce, expires: expires).encode());

      await t.peer.sendMessage('VERSCHLUESSELT');
      await t.peer.publishSharedEvent(ev(owner: t.peer.userId!, id: _id2, title: 'ECHTER-TERMIN'));
      await E2e.until(() => _message(t.g, 'VERSCHLUESSELT') != null, what: 'verschlüsselte Nachricht');
      await E2e.until(() => _titles(got).contains('ECHTER-TERMIN'), what: 'echtes Signal');
      expect(_message(t.g, 'KLARTEXT'), isNull);
      expect(_titles(got), isNot(contains('KLARTEXT-TERMIN')));

      final asking = await _secured('klaranfrage');
      await asking.requestToJoin(InviteLink(roomId: t.roomId, via: 'localhost', inviter: t.peer.userId!, expires: valid.expires, nonce: nonce));
      await E2e.until(() => t.g.family?.member(asking.userId!)?.status == MemberStatus.requested, what: 'Anfrage');
      expect(t.g.family!.member(asking.userId!)!.request, RequestCheck.unknown, reason: 'Klartext-Vermerk gilt nicht');
    });

    test('gefälschte eigene Ereignisse mit bekannter Kennung und Status: kein Signal, kein Vermerk, keine Nachricht', () async {
      final t = await _familyWithNet('fake');
      final me = t.g.userId!;
      final got = _listen(t.g);
      await t.g.sendMessage('ECHT');
      await E2e.until(() => _message(t.g, 'ECHT')?.status == MessageStatus.sent, what: 'eigene Nachricht');
      final known = _message(t.g, 'ECHT')!.id;
      final shared = EventCodec.encodeShared(ev(owner: me, id: _id1, title: 'GEFAELSCHT'));

      for (final (i, status) in <EventStatus>[EventStatus.sent, EventStatus.synced].indexed) {
        await _forge(t.g, t.roomId, _forged('\$t$i', sender: me, type: EventCodec.sharedType, content: shared, status: status, txid: known));
        await _forge(t.g, t.roomId, _forged('\$m$i', sender: me, content: <String, Object?>{'msgtype': 'm.text', 'body': 'GEFAELSCHT$i'}, status: status));
      }
      // Fremde Kennung wie eine eigene, Quelle im Sync-JSON: Beides darf nichts öffnen.
      await _forge(t.g, t.roomId, _forged(known, sender: me, content: <String, Object?>{'msgtype': 'm.text', 'body': 'UEBERSCHRIEBEN'}, status: EventStatus.sent));
      await _forge(t.g, t.roomId, _forged(r'$q', sender: me, content: <String, Object?>{'msgtype': 'm.text', 'body': 'MIT-QUELLE'}, originalSource: _forged(r'$q', sender: me, type: 'm.room.encrypted')));

      await t.peer.sendMessage('DANACH');
      await E2e.until(() => _message(t.g, 'DANACH') != null, what: 'Abgleich danach');
      await E2e.until(() => t.g.messages.every((m) => !m.body.startsWith('GEFAELSCHT')), what: 'Fälschungen verworfen');
      expect(_message(t.g, 'MIT-QUELLE'), isNull);
      expect(_message(t.g, 'UEBERSCHRIEBEN'), isNull);
      expect(_titles(got), isEmpty);
    });

    test('nach einem Neustart: Verschlüsseltes bleibt aus der SDK-Datenbank lesbar, Klartext und Gefälschtes draußen', () async {
      final net = _Net();
      await E2e.init();
      final acc = await E2e.registerUser('neu');
      final device = await E2e.newDevice();
      final g = await E2e.newGateway(httpClient: net, device: device);
      await g.restore();
      await g.login(server: E2e.server, username: acc.user, password: acc.password);
      await E2e.until(() => g.initialSyncDone, what: 'Sync');
      await g.setUpSecurity();
      await E2e.until(() => g.securityState == SecurityState.ready, what: 'Sicherung');
      await g.createFamily('Neustart');
      await E2e.until(() => g.family != null);
      final peer = await _secured('neupeer');
      await _join(g, peer);
      final roomId = g.family!.roomId;

      await g.sendMessage('EIGENE');
      await peer.sendMessage('FREMDE');
      await E2e.until(() => _message(g, 'EIGENE') != null && _message(g, 'FREMDE') != null, what: 'Nachrichten');
      final raw = peer.sdkClient!;
      await raw.sendMessage(roomId, 'm.room.message', raw.generateUniqueTransactionId(), <String, Object?>{'msgtype': 'm.text', 'body': 'KLARTEXT'});
      await _forge(g, roomId, _forged(r'$q', sender: g.userId!, content: <String, Object?>{'msgtype': 'm.text', 'body': 'MIT-QUELLE'}, originalSource: _forged(r'$q', sender: g.userId!, type: 'm.room.encrypted')));
      net.failSends = true;
      await g.sendMessage('UNTERWEGS');
      await E2e.until(() => _message(g, 'UNTERWEGS')?.status == MessageStatus.failed, what: 'gescheitert');
      await peer.sendMessage('LETZTE');
      await E2e.until(() => _message(g, 'LETZTE') != null, what: 'letzte Nachricht');
      final put = net.puts.length;
      await g.close();

      final again = await E2e.newGateway(httpClient: net, device: device);
      await again.restore();
      await E2e.until(() => again.initialSyncDone, what: 'Sync nach dem Neustart');
      await E2e.until(() => _message(again, 'FREMDE') != null && _message(again, 'EIGENE') != null, what: 'Nachrichten aus der Datenbank');
      expect(_message(again, 'KLARTEXT'), isNull);
      expect(_message(again, 'MIT-QUELLE'), isNull);

      final lost = _message(again, 'UNTERWEGS')!;
      expect(lost.status, MessageStatus.failed);
      expect(lost.retryable, isFalse, reason: 'nach dem Neustart fehlt die Sendefunktion');
      await expectLater(again.retryMessage(lost.id), _error(GatewayError.notFound));
      await peer.sendMessage('NEUSTART');
      await E2e.until(() => _message(again, 'NEUSTART') != null, what: 'neue Nachricht');
      expect(net.puts.length, put, reason: 'kein automatischer Versuch aus der Zeitleiste');
    });

    test('zweites eigenes Gerät: dessen Ereignisse kommen an, ältere über requestHistory, Klartext bleibt draußen', () async {
      final a = await _fresh('zwei');
      await a.g.createFamily('Zweitgerät');
      await E2e.until(() => a.g.family != null);
      final key = await a.g.setUpSecurity();
      await E2e.until(() => a.g.securityState == SecurityState.ready);
      final peer = await _secured('zweipeer');
      await _join(a.g, peer);
      final roomId = a.g.family!.roomId;
      final got = _listen(a.g);

      // Mehr als eine Sync-Seite, damit die ältesten nur über `requestHistory` kommen.
      for (var i = 0; i < 14; i++) {
        await a.g.sendMessage('ALT $i');
      }
      final raw = peer.sdkClient!;
      await raw.sendMessage(roomId, 'm.room.message', raw.generateUniqueTransactionId(), <String, Object?>{'msgtype': 'm.text', 'body': 'KLARTEXT'});
      await Future<void>.delayed(const Duration(seconds: 6)); // Schlüsselsicherung

      final d2 = await E2e.loginAs(a.user, a.password);
      await d2.restoreSecurity(key);
      await E2e.until(() => d2.securityState == SecurityState.ready, what: 'Gerät 2 verifiziert');
      await E2e.until(() => d2.family != null, what: 'Familie auf Gerät 2');
      await d2.loadOlderMessages();
      await E2e.until(() => _message(d2, 'ALT 0') != null && _message(d2, 'ALT 13') != null, what: 'alte Nachrichten über requestHistory');
      expect(_message(d2, 'KLARTEXT'), isNull);

      await d2.sendMessage('VON GERAET 2');
      await d2.publishSharedEvent(ev(owner: d2.userId!, id: _id3, title: 'TERMIN VON GERAET 2'));
      await E2e.until(() => _message(a.g, 'VON GERAET 2')?.status == MessageStatus.sent, what: 'Nachricht vom zweiten Gerät');
      await E2e.until(() => _titles(got).contains('TERMIN VON GERAET 2'), what: 'Signal vom zweiten Gerät');
    });

    test('fehlgeschlagenes Senden: automatisch höchstens fünfmal, von Hand wiederholbar, kommt verschlüsselt an', () async {
      final t = await _familyWithNet('wdh');
      t.net.puts.clear(); // Link-Vermerke aus dem Beitritt
      t.net.failSends = true;
      final txid = await _failedSend(t.g, 'WIEDERHOLT');

      var n = 0;
      Future<void> nudge() async {
        final body = 'ANSTOSS ${n++}';
        await t.peer.sendMessage(body);
        await E2e.until(() => _message(t.g, body) != null, what: 'Anstoß');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      while (t.net.puts.length < 1 + SdkMatrixGateway.maxRetriesPerEvent && n < 25) {
        await nudge();
      }
      expect(t.net.puts, hasLength(1 + SdkMatrixGateway.maxRetriesPerEvent));
      for (var i = 0; i < 3; i++) {
        await nudge();
      }
      expect(t.net.puts, hasLength(1 + SdkMatrixGateway.maxRetriesPerEvent), reason: 'Obergrenze');
      expect(t.net.puts.toSet(), hasLength(1), reason: 'immer dieselbe Transaktion');
      expect(t.net.puts.first, contains(txid));
      expect(t.net.puts.first, contains('m.room.encrypted'));

      // Ein gefälschtes Fehler-Ereignis hebt die Obergrenze nicht auf.
      await _forge(t.g, t.roomId, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      await nudge();
      expect(t.net.puts, hasLength(1 + SdkMatrixGateway.maxRetriesPerEvent));

      t.net.failSends = false;
      await t.g.retryMessage(txid);
      await E2e.until(() => _message(t.peer, 'WIEDERHOLT') != null, what: 'kommt an');
      await E2e.until(() => _message(t.g, 'WIEDERHOLT')?.status == MessageStatus.sent, what: 'gesendet');
      expect(t.g.debugLocalSends.openCount, 0);

      // Auch ein gefälschtes „gesendet“ vor dem Fehler-Ereignis setzt den Zähler nicht zurück (bis #138 löschte es ihn).
      t.net.failSends = true;
      t.net.puts.clear();
      final second = await _failedSend(t.g, 'ZWEITE');
      while (t.net.puts.length < 1 + SdkMatrixGateway.maxRetriesPerEvent && n < 50) {
        await nudge();
      }
      expect(t.net.puts, hasLength(1 + SdkMatrixGateway.maxRetriesPerEvent));
      await _forge(t.g, t.roomId, _forged(second, sender: t.g.userId!, status: EventStatus.sent, txid: second));
      await _forge(t.g, t.roomId, _forged(second, sender: t.g.userId!, status: EventStatus.error, txid: second));
      await nudge();
      expect(t.net.puts, hasLength(1 + SdkMatrixGateway.maxRetriesPerEvent));
      expect(t.g.debugLocalSends.takeAutoRetry(second), isFalse);
    });

    test('fehlt die Verschlüsselung vorübergehend, bleiben die Versuche erhalten', () async {
      final t = await _familyWithNet('enc');
      t.net.puts.clear();
      t.net.failSends = true;
      final room = t.g.sdkClient!.getRoomById(t.roomId)!;
      final encryption = room.getState(EventTypes.Encryption)!;
      final txid = await _failedSend(t.g, 'WARTET');

      // Wie ein Raum, dem der Megolm-Zustand fehlt: Das Gateway darf nicht senden und nichts verbrauchen.
      room.setState(Event.fromJson(<String, Object?>{
        ...encryption.toJson(),
        'content': <String, Object?>{'algorithm': 'unbekannt'},
      }, room));
      addTearDown(() => room.setState(encryption));
      final before = t.net.puts.length;
      for (var i = 0; i < 8; i++) {
        await _forge(t.g, t.roomId, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(t.net.puts, hasLength(before));

      final used = before - 1;
      var left = 0;
      while (t.g.debugLocalSends.takeAutoRetry(txid)) {
        left++;
      }
      expect(left, SdkMatrixGateway.maxRetriesPerEvent - used, reason: 'nur echte Versuche zählen');
    });

    test('Anhang und geteilter Termin: gescheitert, aus dem Original wiederholt', () async {
      final t = await _familyWithNet('anh');
      t.net.failSends = true;
      await t.g.sendAttachment(fileName: 'notiz.txt', bytes: utf8.encode('Inhalt des Anhangs'));
      await E2e.until(() => t.g.messages.any((m) => m.attachment != null && m.status == MessageStatus.failed && m.retryable), what: 'Anhang gescheitert');
      final file = t.g.messages.firstWhere((m) => m.attachment != null).id;
      final event = ev(owner: t.g.userId!, id: _id1, title: 'Grillfest', visibility: EventVisibility.shared);
      await expectLater(t.g.shareEventInChat(event), _error(GatewayError.serverUnreachable));
      await E2e.until(() => t.g.messages.any((m) => m.sharedEventId == _id1 && m.retryable), what: 'Termin gescheitert');
      final card = t.g.messages.firstWhere((m) => m.sharedEventId == _id1).id;

      t.net.failSends = false;
      await t.g.retryMessage(file);
      await t.g.retryMessage(card);
      await E2e.until(() => t.peer.messages.any((m) => m.attachment?.name == 'notiz.txt'), what: 'Anhang kommt an');
      await E2e.until(() => t.peer.messages.any((m) => m.sharedEventId == _id1), what: 'Karte kommt an');
      await E2e.until(() => t.g.messages.every((m) => m.status == MessageStatus.sent), what: 'alles gesendet');
      expect(t.g.debugLocalSends.openCount, 0);
    });

    test('gefälschtes Fehler-Ereignis mit Einzelchat-Kennung in der Familien-Zeitleiste: kein Versuch dort', () async {
      final t = await _familyWithNet('fdm');
      final dm = await t.g.startDirectChat(t.peer.userId!);
      await E2e.until(() => t.g.threads.any((x) => x.id == dm), what: 'Einzelchat bei G');
      await E2e.until(() => t.peer.threads.any((x) => x.id == dm), what: 'Einzelchat beim Mitglied');
      t.net.failSends = true;
      final txid = await _failedSend(t.g, 'NUR EINZELCHAT', threadId: dm);
      final before = t.net.putsTo(t.roomId);

      await _forge(t.g, t.roomId, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid, content: <String, Object?>{'msgtype': 'm.text', 'body': 'EINZELCHAT-ECHO'}));
      await E2e.until(() => _message(t.g, 'EINZELCHAT-ECHO')?.status == MessageStatus.failed, what: 'Fälschung in der Familie');
      expect(_message(t.g, 'EINZELCHAT-ECHO')!.retryable, isFalse);
      await expectLater(t.g.retryMessage(txid), _error(GatewayError.notFound));
      await t.peer.sendMessage('ANSTOSS');
      await E2e.until(() => _message(t.g, 'ANSTOSS') != null, what: 'Sync danach');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(t.net.putsTo(t.roomId), before, reason: 'nichts geht in den Familienraum');

      // Mitglied entfernt: Der Thread ist weg, die offene Sendung geht nirgends mehr hin, auch nicht über die Fälschung.
      await t.g.removeMember(t.peer.userId!);
      await E2e.until(() => t.g.threads.length == 1, what: 'Einzelchat ausgeblendet');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      t.net.puts.clear();
      await _forge(t.g, t.roomId, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      await _forge(t.g, dm, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      await expectLater(t.g.retryMessage(txid, threadId: dm), _error(GatewayError.notFound));
      await expectLater(t.g.retryMessage(txid), _error(GatewayError.notFound));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(t.net.puts, isEmpty, reason: 'kein Versuch');
    });

    test('ausgetretenes Mitglied im richtigen Thread: Die Prüfung vor dem Versuch hält die Sendung auf', () async {
      final t = await _familyWithNet('aus');
      final dm = await t.g.startDirectChat(t.peer.userId!);
      await E2e.until(() => t.g.threads.any((x) => x.id == dm), what: 'Einzelchat bei G');
      await E2e.until(() => t.peer.threads.any((x) => x.id == dm), what: 'Einzelchat beim Mitglied');
      t.net.failSends = true;
      final txid = await _failedSend(t.g, 'NUR EINZELCHAT', threadId: dm);

      await t.g.removeMember(t.peer.userId!);
      await E2e.until(() => t.g.family?.member(t.peer.userId!) == null, what: 'Mitglied entfernt');
      t.net.puts.clear();
      t.net.failSends = false;
      await _forge(t.g, dm, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      await expectLater(t.g.retryMessage(txid, threadId: dm), throwsA(isA<GatewayException>()));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(t.net.puts, isEmpty);
    });

    Future<({SdkMatrixGateway modB, String roomB})> secondFamily(SdkMatrixGateway user, String prefix) async {
      final modB = await _secured('${prefix}b');
      await modB.createFamily('Familie B');
      await E2e.until(() => modB.family != null);
      final roomB = modB.family!.roomId;
      await modB.inviteUser(user.userId!);
      final client = user.sdkClient!;
      await E2e.until(() => client.getRoomById(roomB)?.membership == Membership.invite, what: 'Einladung über den Sync');
      await client.joinRoomById(roomB);
      await E2e.until(() => client.getRoomById(roomB)?.membership == Membership.join, what: 'Beitritt über den Sync');
      await E2e.until(() => client.getRoomById(roomB)?.encryptionAlgorithm == 'm.megolm.v1.aes-sha2', what: 'B ist verschlüsselt');
      return (modB: modB, roomB: roomB);
    }

    test('offene Familien-Sendung, Kontodaten wechseln im selben Sync: kein PUT, kein Inhalt im neuen Raum', () async {
      final t = await _familyWithNet('sync');
      final b = await secondFamily(t.g, 'sync');
      t.net.failSends = true;
      final txid = await _failedSend(t.g, 'NUR FUER A');
      final inB = await _sent(b.modB, b.roomB);

      // Kontodaten und das gefälschte Fehler-Ereignis im neuen Raum treffen vor dem Abgleich ein.
      t.g.sdkClient!.accountData[SdkMatrixGateway.familyAccountData] = BasicEvent(
        type: SdkMatrixGateway.familyAccountData,
        content: <String, Object?>{'room_id': b.roomB},
      );
      expect(t.g.family!.roomId, t.roomId);
      final toA = t.net.putsTo(t.roomId);
      await expectLater(t.g.retryMessage(txid), throwsA(isA<GatewayException>()), reason: 'Die Sendung gehört zu A, die Kontodaten zeigen auf B');
      expect(t.g.debugLocalSends.isOpen(txid), isTrue);
      await _forge(t.g, b.roomB, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      await _forge(t.g, t.roomId, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(t.net.putsTo(b.roomB), 0, reason: 'nichts in den neuen Raum');
      expect(t.net.putsTo(t.roomId), toA, reason: 'Die Zeitleiste zeigt noch den alten Raum: kein Versuch');
      expect(await _sent(b.modB, b.roomB), inB);
    });

    test('offene Familien-Sendung, nach dem Zeitleisten-Wechsel: auch ein gefälschtes Fehler-Ereignis löst nichts aus', () async {
      final t = await _familyWithNet('tl');
      final b = await secondFamily(t.g, 'tl');
      t.net.failSends = true;
      final txid = await _failedSend(t.g, 'NUR FUER A');
      final inB = await _sent(b.modB, b.roomB);

      await t.g.sdkClient!.setAccountData(t.g.userId!, SdkMatrixGateway.familyAccountData, <String, Object?>{'room_id': b.roomB});
      await E2e.until(() => t.g.family?.roomId == b.roomB, what: 'Familie B übernommen');
      t.net.puts.clear();
      t.net.failSends = false;

      await _forge(t.g, b.roomB, _forged(txid, sender: t.g.userId!, status: EventStatus.error, txid: txid, content: <String, Object?>{'msgtype': 'm.text', 'body': 'SERVER-INHALT'}));
      await E2e.until(() => _message(t.g, 'SERVER-INHALT') != null, what: 'Fälschung in der Zeitleiste');
      expect(_message(t.g, 'SERVER-INHALT')!.retryable, isFalse);
      await expectLater(t.g.retryMessage(txid), _error(GatewayError.notFound));
      await b.modB.sendMessage('ANSTOSS');
      await E2e.until(() => _message(t.g, 'ANSTOSS') != null || t.g.messages.any((m) => m.undecryptable), what: 'Sync danach');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(t.net.puts, isEmpty, reason: 'kein Versuch in irgendeinen Raum');
      expect(await _sent(b.modB, b.roomB), inB + 1, reason: 'nur der Anstoß selbst');
    });

    test('Sync-Echo vor der Sendeantwort: Nachricht, Termin und Wiederholen bleiben erhalten', () async {
      final t = await _familyWithNet('echo');
      final me = t.g.userId!;
      final got = _listen(t.g);
      var echoes = 0;
      final sub = t.g.sdkClient!.onTimelineEvent.stream.listen((e) {
        if (e.senderId == me && arrivedEncrypted(e)) echoes++;
      });
      addTearDown(sub.cancel);

      /// Die Antwort auf das PUT kommt erst, wenn das Sync-Echo da ist.
      Future<void> raced(Future<void> Function() send) async {
        final before = echoes;
        t.net.holdResponse = () => E2e.until(() => echoes > before, what: 'Sync-Echo');
        await send();
        t.net.holdResponse = null;
      }

      await raced(() => t.g.sendMessage('RENNEN'));
      await E2e.until(() => _message(t.g, 'RENNEN')?.status == MessageStatus.sent, what: 'Nachricht nach dem Rennen');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(_message(t.g, 'RENNEN')?.status, MessageStatus.sent, reason: 'bleibt nach dem Abgleich');

      await raced(() => t.g.publishSharedEvent(ev(owner: me, id: _id1, title: 'EIGENER-TERMIN')));
      await E2e.until(() => _titles(got).contains('EIGENER-TERMIN'), what: 'eigenes Signal nach dem Rennen');

      t.net.failSends = true;
      final txid = await _failedSend(t.g, 'WIEDERHOLT');
      t.net.failSends = false;
      await raced(() => t.g.retryMessage(txid));
      await E2e.until(() => _message(t.g, 'WIEDERHOLT')?.status == MessageStatus.sent, what: 'wiederholt nach dem Rennen');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(_message(t.g, 'WIEDERHOLT')?.status, MessageStatus.sent);
    });

    test('Abmelden während einer laufenden Sendung: kein Absturz, nichts bleibt offen', () async {
      final t = await _familyWithNet('ab');
      final gate = Completer<void>();
      t.net.holdResponse = () => gate.future;
      final sending = t.g.sendMessage('UNTERWEGS').then<Object?>((_) => null, onError: (Object e) => e);
      await E2e.until(() => t.g.debugLocalSends.openCount == 1 && t.net.puts.isNotEmpty, what: 'Sendung läuft');
      t.net.holdResponse = null;
      await t.g.logout();
      expect(t.g.debugLocalSends.openCount, 0);
      gate.complete();
      await sending.timeout(const Duration(seconds: 30));
      expect(t.g.debugLocalSends.openCount, 0, reason: 'Eine späte Antwort trägt nichts nach');
    });
  });

  group('Schlüsselsicherung und Verifizierung gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Ersteinrichtung: Wiederherstellungsschlüssel, Cross-Signing, Gerät verifiziert', () async {
      final a = await _fresh('sec');
      await E2e.until(() => a.g.securityState == SecurityState.needsSetup, what: 'needsSetup');
      // Die erste Einrichtung verlangt keine Passwortbestätigung (Synapse: erstmaliger Upload).
      final key = await a.g.setUpSecurity();
      expect(key.replaceAll(' ', '').length, greaterThan(40));
      await E2e.until(() => a.g.securityState == SecurityState.ready, what: 'ready');
      await a.g.refreshSecurity();
      expect(a.g.devices.where((d) => d.isCurrent).single.verified, isTrue);
      // zweites Einrichten wird abgelehnt (nichts überschreiben)
      await expectLater(a.g.setUpSecurity(), _error(GatewayError.alreadyExists));
    });

    test('zweites Gerät: Emoji-Verifizierung mit dem ersten', () async {
      final a = await _fresh('ver');
      await a.g.setUpSecurity();
      await E2e.until(() => a.g.securityState == SecurityState.ready);

      final d2 = await E2e.loginAs(a.user, a.password);
      await E2e.until(() => d2.securityState == SecurityState.needsRestore, what: 'Gerät 2 unverifiziert');
      await d2.refreshSecurity();
      final other = d2.devices.firstWhere((d) => !d.isCurrent);
      expect(other.verified, isFalse, reason: 'aus Sicht des neuen Geräts noch nicht vertrauenswürdig');

      await d2.startVerification(userId: d2.userId!, deviceId: other.deviceId);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.incomingRequest, what: 'Anfrage bei Gerät 1');
      expect(a.g.verification!.incoming, isTrue);
      await a.g.acceptVerification();
      await E2e.until(
        () => a.g.verification?.phase == VerificationPhase.comparing && d2.verification?.phase == VerificationPhase.comparing,
        what: 'Emoji-Vergleich',
      );
      expect(a.g.verification!.emojis, hasLength(7));
      expect(a.g.verification!.emojis.map((e) => e.emoji).toList(), d2.verification!.emojis.map((e) => e.emoji).toList(), reason: 'beide Seiten zeigen dieselben Emoji');

      await a.g.confirmEmojiMatch(true);
      await d2.confirmEmojiMatch(true);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.done && d2.verification?.phase == VerificationPhase.done, what: 'fertig');
      await E2e.until(() => d2.securityState == SecurityState.ready, what: 'Gerät 2 verifiziert');
    });

    test('Abbruch: abweichende Emoji → keine Verifizierung', () async {
      final a = await _fresh('abb');
      await a.g.setUpSecurity();
      final d2 = await E2e.loginAs(a.user, a.password);
      await d2.refreshSecurity();
      await d2.startVerification(userId: d2.userId!, deviceId: d2.devices.firstWhere((d) => !d.isCurrent).deviceId);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.incomingRequest);
      await a.g.acceptVerification();
      await E2e.until(() => d2.verification?.phase == VerificationPhase.comparing);
      await d2.confirmEmojiMatch(false);
      await E2e.until(() => d2.verification?.phase == VerificationPhase.cancelled && a.g.verification?.phase == VerificationPhase.cancelled, what: 'abgebrochen');
      expect(d2.securityState, SecurityState.needsRestore);
    });

    test('Wiederherstellung mit Schlüssel: falscher Schlüssel scheitert, richtiger verifiziert und entschlüsselt alte Nachrichten', () async {
      final a = await _fresh('rest');
      await a.g.createFamily('Altbestand');
      await E2e.until(() => a.g.family != null);
      final key = await a.g.setUpSecurity();
      await a.g.sendMessage('alte Nachricht');
      await E2e.until(() => a.g.messages.any((m) => m.body == 'alte Nachricht'));
      // Schlüsselsicherung braucht einen Moment (Sitzungsschlüssel werden hochgeladen).
      await Future<void>.delayed(const Duration(seconds: 6));

      final d3 = await E2e.loginAs(a.user, a.password);
      await E2e.until(() => d3.securityState == SecurityState.needsRestore);
      await expectLater(d3.restoreSecurity('EsTx falsch falsch falsch falsch falsch falsch falsch falsch falsch'), throwsA(isA<GatewayException>()));
      expect(d3.securityState, SecurityState.needsRestore);

      await d3.restoreSecurity(key);
      await E2e.until(() => d3.securityState == SecurityState.ready, what: 'Gerät 3 verifiziert');
      await E2e.until(() => d3.family != null, what: 'Familie auf Gerät 3');
      await E2e.until(() => d3.messages.any((m) => m.body == 'alte Nachricht'), what: 'alte Nachricht über Backup entschlüsselt');
    });

    test('neuer Schlüssel (#11): alter scheitert, neuer verifiziert und entschlüsselt alte Nachrichten', () async {
      final a = await _fresh('renew');
      await a.g.createFamily('Neuer Schlüssel');
      await E2e.until(() => a.g.family != null);
      final oldKey = await a.g.setUpSecurity();
      await a.g.sendMessage('vor dem neuen Schlüssel');
      await E2e.until(() => a.g.messages.any((m) => m.body == 'vor dem neuen Schlüssel'));
      await Future<void>.delayed(const Duration(seconds: 6));

      // Unverifiziertes Gerät darf keinen neuen Schlüssel erstellen.
      final d2 = await E2e.loginAs(a.user, a.password);
      await E2e.until(() => d2.securityState == SecurityState.needsRestore);
      await expectLater(d2.resetRecoveryKey(), _error(GatewayError.notAllowed));

      final newKey = await a.g.resetRecoveryKey();
      expect(newKey, isNot(oldKey));
      expect(a.g.securityState, SecurityState.ready, reason: 'Gerät 1 bleibt verifiziert');

      await expectLater(d2.restoreSecurity(oldKey), throwsA(isA<GatewayException>()));
      expect(d2.securityState, SecurityState.needsRestore);
      await d2.restoreSecurity(newKey);
      await E2e.until(() => d2.securityState == SecurityState.ready, what: 'Gerät 2 mit neuem Schlüssel verifiziert');
      await E2e.until(() => d2.messages.any((m) => m.body == 'vor dem neuen Schlüssel'), what: 'alte Nachricht über Backup entschlüsselt');

      // Gerät 2 kann seinerseits wieder einen neuen Schlüssel erstellen (Signaturschlüssel liegen vor).
      final third = await d2.resetRecoveryKey();
      final d3 = await E2e.loginAs(a.user, a.password);
      await E2e.until(() => d3.securityState == SecurityState.needsRestore);
      await d3.restoreSecurity(third);
      await E2e.until(() => d3.securityState == SecurityState.ready, what: 'Gerät 3 mit drittem Schlüssel verifiziert');
    });

    test('Unverifiziertes Gerät erhält keine Raumschlüssel; nach Verifizierung neue Nachrichten lesbar', () async {
      final a = await _fresh('keys');
      await a.g.createFamily('Schlüssel');
      await E2e.until(() => a.g.family != null);
      await a.g.setUpSecurity();
      await E2e.until(() => a.g.securityState == SecurityState.ready);

      final d2 = await E2e.loginAs(a.user, a.password);
      // Mit „abgeglichen“ steht auch die Familie fest: ein bestehendes Mitglied darf nie „keine Familie“ sehen.
      expect(d2.initialSyncDone, isTrue);
      expect(d2.family, isNotNull, reason: 'Familie des Kontos auf dem neuen Gerät sofort bekannt');
      await a.g.sendMessage('vor Verifizierung');
      await E2e.until(() => d2.messages.any((m) => m.undecryptable), what: 'Gerät 2 sieht nur Chiffretext');
      expect(d2.messages.any((m) => m.body == 'vor Verifizierung'), isFalse, reason: 'unverifiziertes Gerät liest nichts');

      await d2.refreshSecurity();
      await d2.startVerification(userId: d2.userId!, deviceId: d2.devices.firstWhere((d) => !d.isCurrent).deviceId);
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.incomingRequest);
      await a.g.acceptVerification();
      await E2e.until(() => a.g.verification?.phase == VerificationPhase.comparing && d2.verification?.phase == VerificationPhase.comparing);
      await a.g.confirmEmojiMatch(true);
      await d2.confirmEmojiMatch(true);
      await E2e.until(() => d2.securityState == SecurityState.ready, what: 'Gerät 2 verifiziert');

      await a.g.sendMessage('nach Verifizierung');
      await E2e.until(() => d2.messages.any((m) => m.body == 'nach Verifizierung'), what: 'Gerät 2 liest nach Verifizierung');
    });
  });
}
