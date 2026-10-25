import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/presence.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/task_period.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Role;

import 'e2e_support.dart';

Future<SdkMatrixGateway> _login(String prefix) async {
  final a = await E2e.loggedIn(prefix);
  await E2e.until(() => a.gateway.initialSyncDone, what: 'Sync $prefix');
  await a.gateway.setUpSecurity();
  await E2e.until(() => a.gateway.securityState == SecurityState.ready, what: 'Sicherung $prefix');
  return a.gateway;
}

Future<void> _join(SdkMatrixGateway mod, SdkMatrixGateway user) async {
  final link = InviteLink.tryParse(await mod.createInviteLink(autoApprove: false), now: DateTime.now(), ownHost: 'localhost')!;
  await user.requestToJoin(link);
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.requested, what: 'Moderator sieht Anfrage');
  await mod.approveRequest(user.userId!);
  await E2e.until(() => user.invitations.isNotEmpty, what: 'Einladung eingetroffen');
  await user.acceptInvitation(user.invitations.single.roomId);
  await E2e.until(() => user.family != null, what: 'Familie beim neuen Mitglied');
  await E2e.until(() => mod.family?.member(user.userId!)?.status == MemberStatus.joined, what: 'Mitglied beigetreten');
}

/// Zwei Mitglieder (Moderator [a], Mitglied [b]); wartet, bis a die Geräteschlüssel von b kennt.
Future<(SdkMatrixGateway, SdkMatrixGateway)> _family(String name) async {
  final a = await _login('p6a');
  await a.createFamily(name);
  await E2e.until(() => a.family != null);
  final b = await _login('p6b');
  await _join(a, b);
  return (a, b);
}

void main() {
  group('Online-Status, Einzelchats, Einkaufszettel gegen echten Synapse', skip: E2e.enabled ? false : E2e.skipReason, () {
    test('Online-Status: verschlüsselt zugestellt, Anfrage wird beantwortet, Fremde und Klartext werden ignoriert', () async {
      final (a, b) = await _family('Status-Familie');
      final asks = <String>[];
      final sub = a.presenceAsks.listen(asks.add);
      addTearDown(sub.cancel);

      await E2e.until(() => b.presence.isEmpty);
      await b.announcePresence(online: true, ask: true);
      await E2e.until(() => PresenceBoard.evaluate(a.presence[b.userId], DateTime.now().toUtc()).status == PresenceStatus.online, what: 'A sieht B online');
      await E2e.until(() => asks.contains(b.userId), what: 'A erhält die Bitte um Antwort');

      await b.announcePresence(online: false);
      await E2e.until(() => PresenceBoard.evaluate(a.presence[b.userId], DateTime.now().toUtc()).status == PresenceStatus.offline, what: 'A sieht B offline');

      // Gezielte Antwort geht nur an den Anfragenden.
      await a.announcePresence(online: true, onlyTo: b.userId);
      await E2e.until(() => b.presence[a.userId]?.online == true, what: 'B sieht A online');

      // Ein Fremder (nicht in der Familie) kann den Status nicht fälschen – weder verschlüsselt noch im Klartext.
      final stranger = await _login('p6s');
      final raw = stranger.sdkClient!;
      final content = PresenceCodec.encode(online: true, now: DateTime.now().toUtc());
      await raw.sendToDevice(PresenceCodec.type, raw.generateUniqueTransactionId(), <String, Map<String, Map<String, Object?>>>{
        a.userId!: <String, Map<String, Object?>>{'*': content},
      });
      await b.announcePresence(online: false);
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(a.presence.keys, <String>[b.userId!], reason: 'nur Familienmitglieder im Status');
      expect(a.presence[stranger.userId], isNull);
      // Auch ein Mitglied kann in Klartext keinen Status vortäuschen (nur verschlüsselt Angekommenes zählt).
      final before = a.presence[b.userId]!.at;
      await b.sdkClient!.sendToDevice(PresenceCodec.type, b.sdkClient!.generateUniqueTransactionId(), <String, Map<String, Map<String, Object?>>>{
        a.userId!: <String, Map<String, Object?>>{'*': PresenceCodec.encode(online: true, now: DateTime.now().toUtc().add(const Duration(seconds: 30)))},
      });
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(a.presence[b.userId]!.at, before, reason: 'unverschlüsseltes Ereignis ignoriert');
      expect(a.presence[b.userId]!.online, isFalse);
    });

    test('Einzelchat: verschlüsselt, automatische Annahme, getrennt vom Familienchat, nach Entfernen gesperrt', () async {
      final (a, b) = await _family('DM-Familie');
      final id = await a.startDirectChat(b.userId!);
      await E2e.until(() => b.threads.any((t) => t.peerId == a.userId), what: 'B nimmt die Einladung automatisch an');
      final bThread = b.threads.firstWhere((t) => t.peerId == a.userId);
      expect(bThread.id, id, reason: 'beide Seiten nutzen denselben Raum');
      // Es ist keine Familieneinladung.
      expect(b.invitations, isEmpty);
      expect(a.sdkClient!.getRoomById(id)!.encrypted, isTrue);

      await a.sendMessage('Nur für dich', threadId: id);
      await E2e.until(() => b.messagesIn(id).any((m) => m.body == 'Nur für dich'), what: 'B entschlüsselt');
      await b.sendMessage('Antwort', threadId: id, replyToId: b.messagesIn(id).first.id);
      await E2e.until(() => a.messagesIn(id).any((m) => m.body == 'Antwort' && m.replyToId != null), what: 'A entschlüsselt');
      await a.sendReaction(a.messagesIn(id).last.id, '👍', threadId: id);
      await E2e.until(() => b.messagesIn(id).any((m) => m.reactions.containsKey('👍')), what: 'Reaktion im Einzelchat');
      expect(a.messages.where((m) => m.body == 'Nur für dich'), isEmpty);
      expect(b.messages.where((m) => m.body == 'Antwort'), isEmpty);
      expect(b.unreadIn(id), greaterThanOrEqualTo(0));

      // Der Server sieht nur Chiffretext.
      final raw = await a.sdkClient!.getRoomEvents(id, Direction.b, limit: 50);
      final texts = raw.chunk.where((e) => e.type == 'm.room.encrypted' || e.type == 'm.room.message').toList();
      expect(texts, isNotEmpty);
      expect(texts.every((e) => e.type == 'm.room.encrypted'), isTrue);

      // Wiederholtes Öffnen liefert denselben Raum.
      expect(await a.startDirectChat(b.userId!), id);

      // Nach dem Entfernen: Gespräch weg, Senden verweigert.
      await a.removeMember(b.userId!);
      await E2e.until(() => a.family?.member(b.userId!) == null, what: 'B entfernt');
      await E2e.until(() => a.threads.length == 1, what: 'Einzelchat ausgeblendet');
      await expectLater(a.sendMessage('mitlesen?', threadId: id), throwsA(isA<GatewayException>()));
      await expectLater(a.startDirectChat(b.userId!), throwsA(isA<GatewayException>()));
    });

    test('Einzelchat-Einladung von Fremden wird weder angenommen noch als Familieneinladung gezeigt', () async {
      final a = await _login('p6a');
      await a.createFamily('Fremde-Familie');
      await E2e.until(() => a.family != null);
      final stranger = await _login('p6x');
      final roomId = await stranger.sdkClient!.startDirectChat(a.userId!, enableEncryption: true);
      await E2e.until(() => a.sdkClient!.getRoomById(roomId)?.membership == Membership.invite, what: 'Einladung eingetroffen');
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(a.sdkClient!.getRoomById(roomId)!.membership, Membership.invite, reason: 'nicht automatisch angenommen');
      expect(a.invitations, isEmpty, reason: 'keine Familieneinladung');
      expect(a.threads.map((t) => t.id), <String>[ChatThread.familyId]);
    });

    test('Einkaufszettel: verschlüsselt im Familienraum, beide Mitglieder erhalten Einträge, Server sieht keinen Klartext', () async {
      final (a, b) = await _family('Einkaufs-Familie');
      final got = <ShoppingSignal>[];
      final sub = b.calendarSignals.listen((s) {
        if (s is ShoppingSignal) got.add(s);
      });
      addTearDown(sub.cancel);
      final item = ShoppingItem(
        id: '00000000-0000-4000-8000-0000000000aa',
        title: 'GEHEIME-MILCH',
        quantity: '2 Liter',
        by: a.userId!,
        updatedAt: DateTime.now().toUtc(),
      );
      await a.publishShoppingItem(item);
      await E2e.until(() => got.isNotEmpty, what: 'B erhält den Eintrag');
      final decoded = ShoppingCodec.decode(got.first.content, sender: got.first.sender)!;
      expect((decoded.title, decoded.quantity, decoded.by), ('GEHEIME-MILCH', '2 Liter', a.userId));

      // Bens Änderung erreicht Anna.
      final gotA = <ShoppingSignal>[];
      final subA = a.calendarSignals.listen((s) {
        if (s is ShoppingSignal && s.sender == b.userId) gotA.add(s);
      });
      addTearDown(subA.cancel);
      await b.publishShoppingItem(decoded.copyWith(checked: true, version: 2, by: b.userId, updatedAt: DateTime.now().toUtc()));
      await E2e.until(() => gotA.isNotEmpty, what: 'A erhält Bens Änderung');
      expect(ShoppingCodec.decode(gotA.first.content, sender: b.userId!)!.checked, isTrue);

      // Fremde Urheberschaft wird schon beim Senden verweigert.
      await expectLater(a.publishShoppingItem(decoded.copyWith(by: b.userId)), throwsA(isA<GatewayException>().having((e) => e.error, 'e', GatewayError.invalidInput)));

      final raw = await a.sdkClient!.getRoomEvents(a.family!.roomId, Direction.b, limit: 60);
      final dump = raw.chunk.map((e) => '${e.type} ${e.content}').join('\n');
      expect(dump, isNot(contains('GEHEIME-MILCH')));
      expect(raw.chunk.where((e) => e.type == ShoppingCodec.type), isEmpty, reason: 'nur als m.room.encrypted');
    });

    test('Issue #1: Liste v2 (Erklärung, monatlich am letzten Freitag) wird verschlüsselt übertragen und gleich gelesen', () async {
      final (a, b) = await _family('Regel-Familie');
      final lists = <TaskListSignal>[];
      final sub = b.calendarSignals.listen((s) {
        if (s is TaskListSignal) lists.add(s);
      });
      addTearDown(sub.cancel);
      final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch, isUtc: true);
      final list = TaskList(
        id: '00000000-0000-4000-8000-0000000000c1',
        title: 'Abrechnung',
        description: 'GEHEIME-ERKLÄRUNG\nzweite Zeile',
        assignee: b.userId!,
        rule: const TaskRule.monthlyByWeekday(TaskRule.last, DateTime.friday),
        timeZone: 'Europe/Berlin',
        items: const <TaskItem>[TaskItem(id: '00000000-0000-4000-8000-0000000000c2', title: 'Belege')],
        by: a.userId!,
        updatedAt: now,
      );
      await a.publishTaskList(list);
      await E2e.until(() => lists.isNotEmpty, what: 'B erhält die Liste');
      expect(lists.first.content['v'], 2);
      expect(TaskCodec.decodeList(lists.first.content, sender: lists.first.sender), list);
      final raw = await a.sdkClient!.getRoomEvents(a.family!.roomId, Direction.b, limit: 60);
      expect(raw.chunk.map((e) => '${e.content}').join('\n'), isNot(contains('GEHEIME-ERKLÄRUNG')));
    });

    test('Aufgabenlisten: Liste und Protokolleintrag verschlüsselt im Familienraum, Server sieht keinen Klartext', () async {
      final (a, b) = await _family('Aufgaben-Familie');
      final lists = <TaskListSignal>[];
      final logs = <TaskLogSignal>[];
      final sub = b.calendarSignals.listen((s) {
        if (s is TaskListSignal) lists.add(s);
        if (s is TaskLogSignal) logs.add(s);
      });
      addTearDown(sub.cancel);
      // Das Ereignisformat kennt Millisekunden; Mikrosekunden würden den Vergleich verfälschen.
      final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch, isUtc: true);
      final list = TaskList(
        id: '00000000-0000-4000-8000-0000000000b1',
        title: 'GEHEIME-LISTE',
        assignee: b.userId!,
        interval: TaskInterval.daily,
        timeZone: 'Europe/Berlin',
        items: const <TaskItem>[TaskItem(id: '00000000-0000-4000-8000-0000000000b2', title: 'GEHEIMER-PUNKT')],
        by: a.userId!,
        updatedAt: now,
      );
      await a.publishTaskList(list);
      await E2e.until(() => lists.isNotEmpty, what: 'B erhält die Liste');
      expect(TaskCodec.decodeList(lists.first.content, sender: lists.first.sender), list);

      final loc = TimeZones.tryGet('Europe/Berlin')!;
      final on = TaskPeriod.localDate(loc, now);
      final entry = TaskLogEntry(
        id: '00000000-0000-4000-8000-0000000000b3',
        listId: list.id,
        itemId: list.items.single.id,
        periodKey: TaskPeriod.keyForDate(TaskInterval.daily, on)!,
        doneOn: on,
        at: now,
        by: b.userId!,
        comment: 'GEHEIMER-KOMMENTAR',
      );
      final gotA = <TaskLogSignal>[];
      final subA = a.calendarSignals.listen((s) {
        if (s is TaskLogSignal) gotA.add(s);
      });
      addTearDown(subA.cancel);
      await b.publishTaskLog(entry);
      await E2e.until(() => gotA.isNotEmpty, what: 'A erhält den Protokolleintrag');
      expect(TaskCodec.decodeLog(gotA.first.content, sender: b.userId!), entry);

      // Fremde Urheberschaft wird schon beim Senden verweigert.
      await expectLater(a.publishTaskLog(entry), throwsA(isA<GatewayException>().having((e) => e.error, 'e', GatewayError.invalidInput)));

      final raw = await a.sdkClient!.getRoomEvents(a.family!.roomId, Direction.b, limit: 60);
      final dump = raw.chunk.map((e) => '${e.type} ${e.content}').join('\n');
      for (final secret in <String>['GEHEIME-LISTE', 'GEHEIMER-PUNKT', 'GEHEIMER-KOMMENTAR']) {
        expect(dump, isNot(contains(secret)));
      }
      expect(raw.chunk.where((e) => e.type == TaskCodec.listType || e.type == TaskCodec.logType), isEmpty);
    });
  });
}
