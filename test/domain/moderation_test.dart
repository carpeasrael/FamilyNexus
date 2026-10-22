import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(String id, String sender) =>
    ChatMessage(id: id, senderId: sender, senderName: sender, time: DateTime.utc(2026, 10, 22), body: id);

void main() {
  group('ReportRequest', () {
    test('Grund ohne Freitext ist nur die Kategorie', () {
      final r = ReportRequest(messageId: r'$a', category: ReportCategory.spam);
      expect(r.reason, 'spam');
      expect(r.threadId, ChatThread.familyId);
    });

    test('Freitext wird bereinigt und gekürzt', () {
      final r = ReportRequest(
        messageId: r'$a',
        category: ReportCategory.harassment,
        details: '  Beleidigung${String.fromCharCode(0x202e)}${String.fromCharCode(0)} ${'x' * 500}',
      );
      expect(r.details.length, lessThanOrEqualTo(ReportRequest.maxDetailsLength));
      expect(r.details, isNot(contains(String.fromCharCode(0x202e))));
      expect(r.details, isNot(contains(String.fromCharCode(0))));
      expect(r.reason, startsWith('harassment: Beleidigung'));
    });
  });

  group('BlockedUsers', () {
    test('parse verwirft ungültige IDs, Dubletten und Überlängen', () {
      final parsed = BlockedUsers.parse('@ben:fake.test, kaputt,@ben:fake.test,@cara:fake.test,,@x');
      expect(parsed, <String>['@ben:fake.test', '@cara:fake.test']);
      expect(BlockedUsers.parse(null), isEmpty);
      expect(BlockedUsers.parse(''), isEmpty);
      final many = List<String>.generate(BlockedUsers.maxEntries + 50, (i) => '@u$i:fake.test').join(',');
      expect(BlockedUsers.parse(many), hasLength(BlockedUsers.maxEntries));
    });

    test('add und remove sind idempotent und prüfen die ID', () {
      var list = const <String>[];
      list = BlockedUsers.add(list, '@ben:fake.test');
      list = BlockedUsers.add(list, '@ben:fake.test');
      list = BlockedUsers.add(list, 'kein-user');
      expect(list, <String>['@ben:fake.test']);
      list = BlockedUsers.remove(list, '@cara:fake.test');
      expect(list, <String>['@ben:fake.test']);
      list = BlockedUsers.remove(list, '@ben:fake.test');
      expect(list, isEmpty);
    });

    test('Obergrenze: weitere Einträge werden nicht aufgenommen', () {
      final full = List<String>.generate(BlockedUsers.maxEntries, (i) => '@u$i:fake.test');
      expect(BlockedUsers.add(full, '@neu:fake.test'), full);
    });

    test('Einstellungen speichern und lesen die Liste (ungültige Werte fallen weg)', () {
      final s = const AppSettings().copyWith(blockedUsers: <String>['@ben:fake.test']);
      expect(s.toMap()['blockedUsers'], '@ben:fake.test');
      expect(AppSettings.fromMap(s.toMap()).blockedUsers, <String>['@ben:fake.test']);
      expect(const AppSettings().toMap().containsKey('blockedUsers'), isFalse);
      expect(AppSettings.fromMap(<String, String>{'blockedUsers': '<script>,@ben:fake.test'}).blockedUsers, <String>['@ben:fake.test']);
    });
  });

  group('Filter', () {
    final messages = <ChatMessage>[_msg('1', '@ben:fake.test'), _msg('2', '@anna:fake.test'), _msg('3', '@cara:fake.test')];

    test('blockierte Absender werden ausgeblendet, eigene Nachrichten nie', () {
      final out = visibleMessages(messages, <String>['@ben:fake.test', '@anna:fake.test'], myUserId: '@anna:fake.test');
      expect(out.map((m) => m.id), <String>['2', '3']);
    });

    test('ohne Blockierungen bleibt die Liste unverändert', () {
      expect(identical(visibleMessages(messages, const <String>[]), messages), isTrue);
    });

    test('Einzelchats mit Blockierten verschwinden, der Familienchat nie', () {
      const threads = <ChatThread>[
        ChatThread(id: ChatThread.familyId, kind: ThreadKind.family, title: 'Familie'),
        ChatThread(id: '!a:fake.test', kind: ThreadKind.direct, title: 'Ben', peerId: '@ben:fake.test'),
        ChatThread(id: '!b:fake.test', kind: ThreadKind.direct, title: 'Cara', peerId: '@cara:fake.test'),
      ];
      final out = visibleThreads(threads, <String>['@ben:fake.test']);
      expect(out.map((t) => t.title), <String>['Familie', 'Cara']);
    });
  });
}
