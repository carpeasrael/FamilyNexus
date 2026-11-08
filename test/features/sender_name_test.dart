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

  // #326 (E4): Im Satz („Von …“, „Nachricht von …“, „… blockieren?“) steht der Fallback in Anführungszeichen,
  // damit weder Kasus noch Großschreibung falsch sind.
  test('#326: im Satz steht „Ehemaliges Mitglied“ in Anführungszeichen, sonst unverändert', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(msg('').senderLabel(de, inSentence: true), '„Ehemaliges Mitglied“');
    expect(msg('').senderLabel(en, inSentence: true), '“Former member”');
    expect(msg('').senderLabel(de), 'Ehemaliges Mitglied');
    expect(msg('Ida').senderLabel(de, inSentence: true), 'Ida', reason: 'echte Namen bleiben unverändert');
    expect(de.chatMessageFrom(msg('').senderLabel(de, inSentence: true)), 'Nachricht von „Ehemaliges Mitglied“');
    expect(en.chatBlockSender(msg('').senderLabel(en, inSentence: true)), 'Block “Former member”');
    expect(en.blockDone(msg('').senderLabel(en, inSentence: true)), '“Former member” is blocked.');
  });

  test('#326: memberLabel: eigene Person bleibt „Du“, Unbekannte im Satz in Anführungszeichen, nie die Matrix-ID', () {
    final de = lookupAppLocalizations(const Locale('de'));
    const me = '@anna:fake.test';
    expect(memberLabel(de, null, me, me: me, inSentence: true), de.chatYou);
    expect(memberLabel(de, null, '@geloescht:fake.test', me: me), 'Ehemaliges Mitglied');
    expect(memberLabel(de, null, '@geloescht:fake.test', me: me, inSentence: true), '„Ehemaliges Mitglied“');
    expect(memberLabel(de, null, '@geloescht:fake.test', me: me, inSentence: true), isNot(contains('@')));
  });
}
