import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/features/chat/sender_name.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// #60: Nachrichten gelöschter Mitglieder zeigen einen Namen, nie eine leere Zeile.
void main() {
  ChatMessage msg(String name) => ChatMessage(id: r'$a', senderId: '@ida:fake.test', senderName: name, time: DateTime.utc(2026));

  test('leerer Name → „Ehemaliges Mitglied“, sonst der Name', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(msg('').senderLabel(de), 'Ehemaliges Mitglied');
    expect(msg('').senderLabel(en), 'Former member');
    expect(msg('Ida').senderLabel(de), 'Ida');
  });
}
