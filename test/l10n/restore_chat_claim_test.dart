import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// E-107 (#516): Das zuletzt geöffnete Gespräch wird nur bei eingeschaltetem Schalter lokal gemerkt und beim Abmelden
/// gelöscht. Datenschutztexte und Schalter nennen das (Pflichtaussagen).
Map<String, dynamic> _arb(String lang) => json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final de = _arb('de');
  final en = _arb('en');

  test('Schalter-Texte in de und en vorhanden', () {
    for (final k in <String>['settingsRestoreLastChat', 'settingsRestoreLastChatHint']) {
      expect((de[k] as String?) ?? '', isNotEmpty, reason: 'de $k');
      expect((en[k] as String?) ?? '', isNotEmpty, reason: 'en $k');
    }
    expect(AppLocalizationsDe().settingsRestoreLastChat, 'Letztes Gespräch wieder öffnen');
    expect(AppLocalizationsEn().settingsRestoreLastChat, 'Reopen last conversation');
  });

  test('Hinweis: nur auf diesem Gerät, beim Abmelden gelöscht', () {
    expect(de['settingsRestoreLastChatHint'], contains('nur auf diesem Gerät'));
    expect(de['settingsRestoreLastChatHint'], contains('beim Abmelden gelöscht'));
    expect(en['settingsRestoreLastChatHint'], contains('only on this device'));
    expect(en['settingsRestoreLastChatHint'], contains('deleted when you sign out'));
  });

  test('privacy2Body nennt das zuletzt geöffnete Gespräch, nur wenn eingeschaltet', () {
    expect(de['privacy2Body'], contains('das zuletzt geöffnete Gespräch (nur wenn eingeschaltet)'));
    expect(en['privacy2Body'], contains('the conversation you last had open (only if switched on)'));
  });

  test('Datenschutzerklärung de: Tabelle, Abmelden, Stand', () {
    final t = _flat(File('store/privacy/privacy-policy.de.md').readAsStringSync());
    expect(t, contains('**Stand: 18. November 2026**'));
    expect(t, contains('nur wenn „Letztes Gespräch wieder öffnen“ eingeschaltet ist, die Kennung des zuletzt geöffneten Gesprächs'));
    expect(t, contains('Die gemerkte Kennung des zuletzt geöffneten Gesprächs wird gelöscht.'));
  });

  test('Datenschutzerklärung en: Tabelle, Abmelden, Stand', () {
    final t = _flat(File('store/privacy/privacy-policy.en.md').readAsStringSync());
    expect(t, contains('**Last updated: 18 November 2026**'));
    expect(t, contains('only if “Reopen last conversation” is switched on, the ID of the conversation you last had open'));
    expect(t, contains('The remembered ID of the conversation you last had open is deleted.'));
  });

  test('E-107 steht im Entscheidungsprotokoll und E-100 verweist darauf', () {
    final t = File('docs/ENTSCHEIDUNGEN.md').readAsStringSync();
    expect(t, contains('## E-107 Chat: Ungelesene zuerst, letztes Gespräch wieder öffnen'));
    expect(t, contains('Nachtrag (Issue #516, E-107)'));
  });
}
