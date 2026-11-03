import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/features/chat/chat_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// #254: Datumszeilen und Marke „Neue Nachrichten“ als reine Funktion.
void main() {
  ChatMessage msg(String id, DateTime local) =>
      ChatMessage(id: id, senderId: '@ben:fake.test', senderName: 'Ben', time: local.toUtc(), body: id);

  List<String> keys(List<ChatEntry> entries) => <String>[for (final e in entries) e.key];

  group('Datumszeilen', () {
    test('vor der ersten Nachricht jedes Kalendertags (Ortszeit), auch über Mitternacht', () {
      final entries = chatEntries(<ChatMessage>[
        msg(r'$a', DateTime(2026, 11, 2, 23, 59)),
        msg(r'$b', DateTime(2026, 11, 3, 0, 0)),
        msg(r'$c', DateTime(2026, 11, 3, 8, 15)),
      ]);
      expect(keys(entries), <String>['~fn-day-2026-11-2', r'$a', '~fn-day-2026-11-3', r'$b', r'$c']);
      expect((entries.first as DayEntry).day, DateTime(2026, 11, 2));
    });

    test('Jahreswechsel bekommt eine eigene Zeile', () {
      final entries = chatEntries(<ChatMessage>[
        msg(r'$a', DateTime(2026, 12, 31, 22)),
        msg(r'$b', DateTime(2027, 1, 1, 0, 30)),
      ]);
      expect(entries.whereType<DayEntry>().map((e) => e.day), <DateTime>[DateTime(2026, 12, 31), DateTime(2027)]);
    });

    test('Tag folgt der Ortszeit, nicht UTC', () {
      final local = DateTime(2026, 11, 3, 0, 30);
      final entries = chatEntries(<ChatMessage>[msg(r'$a', local)]);
      expect((entries.first as DayEntry).day, DateTime(local.year, local.month, local.day));
    });

    test('Heute, Gestern, sonst Datum – nach Kalendertagen', () {
      final now = DateTime(2026, 11, 3, 0, 5);
      expect(chatDayOf(DateTime(2026, 11, 3), now), ChatDay.today);
      expect(chatDayOf(DateTime(2026, 11, 2, 23, 59), now), ChatDay.yesterday);
      expect(chatDayOf(DateTime(2026, 11, 1), now), ChatDay.other);
      expect(chatDayOf(DateTime(2026, 12, 31), DateTime(2027, 1, 1, 9)), ChatDay.yesterday);
      expect(chatDayOf(DateTime(2026, 3, 28), DateTime(2026, 3, 29, 12)), ChatDay.yesterday, reason: 'Zeitumstellung');
    });
  });

  group('Marke „Neue Nachrichten“', () {
    final day = DateTime(2026, 11, 3, 10);
    final msgs = <ChatMessage>[
      msg(r'$a', day),
      msg(r'$b', day.add(const Duration(minutes: 1))),
      msg(r'$c', day.add(const Duration(minutes: 2))),
    ];

    test('steht direkt vor der ersten ungelesenen Nachricht', () {
      expect(keys(chatEntries(msgs, unreadFromId: r'$b')), <String>['~fn-day-2026-11-3', r'$a', '~fn-unread', r'$b', r'$c']);
    });

    test('ohne ungelesene Nachricht keine Marke', () {
      expect(chatEntries(msgs).whereType<UnreadMarkerEntry>(), isEmpty);
    });

    test('nicht sichtbare Nachricht (z. B. blockiert): Marke vor der nächsten sichtbaren', () {
      final visible = <ChatMessage>[msgs[0], msgs[2]];
      final entries = chatEntries(visible, unreadFromId: r'$b', allIds: <String>[r'$a', r'$b', r'$c']);
      expect(keys(entries), <String>['~fn-day-2026-11-3', r'$a', '~fn-unread', r'$c']);
    });

    test('keine sichtbare Nachricht danach: keine Marke', () {
      final entries = chatEntries(<ChatMessage>[msgs[0]], unreadFromId: r'$b', allIds: <String>[r'$a', r'$b']);
      expect(entries.whereType<UnreadMarkerEntry>(), isEmpty);
    });

    test('neuer Tag beginnt mit der ungelesenen Nachricht: erst Datum, dann Marke', () {
      final entries = chatEntries(<ChatMessage>[
        msg(r'$a', DateTime(2026, 11, 2, 20)),
        msg(r'$b', DateTime(2026, 11, 3, 7)),
      ], unreadFromId: r'$b');
      expect(keys(entries), <String>['~fn-day-2026-11-2', r'$a', '~fn-day-2026-11-3', '~fn-unread', r'$b']);
    });

    test('Schlüssel von Datum und Marke kollidieren nie mit Nachrichten-IDs', () {
      final entries = chatEntries(msgs, unreadFromId: r'$b');
      final keySet = keys(entries).toSet();
      expect(keySet.length, entries.length);
      expect(entries.whereType<MessageEntry>().every((e) => !e.key.startsWith('~')), isTrue);
    });
  });
}
