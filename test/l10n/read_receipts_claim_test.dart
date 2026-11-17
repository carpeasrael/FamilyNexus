import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// E-106 (#526): Der öffentliche Lesemarker ist kein Ende-zu-Ende-verschlüsselter Inhalt, sondern für den Server und den
/// Anbieter der Gesprächspartner sichtbar; Standard an, abschaltbar, nicht zurücknehmbar. Datenschutztexte, Schalter und
/// Store-Angaben nennen das (Pflichtaussagen; `metadata_claims_test.dart` prüft verbotene Formulierungen).
Map<String, dynamic> _arb(String lang) => json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final de = _arb('de');
  final en = _arb('en');
  const keys = <String>[
    'chatStatusSent',
    'chatStatusRead',
    'chatStatusReadBy',
    'chatReadByTitle',
    'settingsShareReadReceipts',
    'settingsShareReadReceiptsHint',
  ];

  test('Schlüssel in de und en vorhanden und nicht leer', () {
    for (final k in keys) {
      expect((de[k] as String?) ?? '', isNotEmpty, reason: 'de $k');
      expect((en[k] as String?) ?? '', isNotEmpty, reason: 'en $k');
    }
  });

  test('Texte der Stufen und Plural von „Gelesen von n“', () {
    final d = AppLocalizationsDe();
    final e = AppLocalizationsEn();
    expect(d.chatStatusSent, 'Gesendet');
    expect(d.chatStatusRead, 'Gelesen');
    expect(d.chatStatusReadBy(1), 'Gelesen von 1');
    expect(d.chatStatusReadBy(3), 'Gelesen von 3');
    expect(e.chatStatusSent, 'Sent');
    expect(e.chatStatusRead, 'Read');
    expect(e.chatStatusReadBy(1), 'Read by 1');
    expect(e.chatStatusReadBy(3), 'Read by 3');
  });

  test('Schalter-Hinweis nennt Sichtbarkeit, Gegenseitigkeit und Unwiderruflichkeit (de und en)', () {
    expect(de['settingsShareReadReceiptsHint'], contains('Der Server und der Anbieter der Gesprächspartner sehen'));
    expect(de['settingsShareReadReceiptsHint'], contains('nur private Lesemarker'));
    expect(de['settingsShareReadReceiptsHint'], contains('nicht zurücknehmen'));
    expect(de['settingsShareReadReceiptsHint'], contains('nichts nachgesendet'));
    expect(en['settingsShareReadReceiptsHint'], contains('The server and the provider of your chat partners see'));
    expect(en['settingsShareReadReceiptsHint'], contains('only send private read markers'));
    expect(en['settingsShareReadReceiptsHint'], contains('cannot be taken back'));
    expect(en['settingsShareReadReceiptsHint'], contains('nothing is sent afterwards'));
  });

  test('privacy3Body: öffentliche Lesebestätigungen sind sichtbare Metadaten', () {
    expect(de['privacy3Body'], contains('öffentliche Lesebestätigungen'));
    expect(de['privacy3Body'], contains('Anbieter deiner Gesprächspartner'));
    expect(en['privacy3Body'], contains('public read receipts'));
    expect(en['privacy3Body'], contains('provider of your chat partners'));
  });

  test('privacy10Body: Lesebestätigung, Standard an, abschaltbar, nicht zurücknehmbar', () {
    expect(de['privacy10Title'], contains('Lesebestätigung'));
    expect(de['privacy10Body'], contains('standardmäßig an'));
    expect(de['privacy10Body'], contains('nicht zurücknehmen'));
    expect(en['privacy10Title'], contains('read receipts'));
    expect(en['privacy10Body'], contains('on by default'));
    expect(en['privacy10Body'], contains('cannot be taken back'));
  });

  test('privacy2Body: Lesestand der Mitglieder liegt lokal', () {
    expect(de['privacy2Body'], contains('Lesestand der Mitglieder'));
    expect(en['privacy2Body'], contains('read state'));
  });

  test('Datenschutzerklärung de: Datentabelle, Metadaten, Abschnitt Online-Status, Stand', () {
    final t = _flat(File('store/privacy/privacy-policy.de.md').readAsStringSync());
    expect(t, contains('**Stand: 18. November 2026**'));
    expect(t, contains('| Lesestatus (öffentlicher Lesemarker'));
    expect(t, contains('nicht Ende-zu-Ende-verschlüsselt und für den Anbieter sowie den Anbieter deiner Gesprächspartner sichtbar'));
    expect(t, contains('Dazu gehören öffentliche Lesebestätigungen'));
    expect(t, contains('Einstellungen → Datenschutz → Lesebestätigung senden'));
    expect(t, contains('Bereits gesendete öffentliche Marker lassen sich nicht zurücknehmen'));
  });

  test('Datenschutzerklärung en: Datentabelle, Metadaten, Abschnitt Online-Status, Stand', () {
    final t = _flat(File('store/privacy/privacy-policy.en.md').readAsStringSync());
    expect(t, contains('**Last updated: 18 November 2026**'));
    expect(t, contains('| Read state (public read marker'));
    expect(t, contains('not end-to-end encrypted and is visible to the provider and to the provider of your chat partners'));
    expect(t, contains('This includes public read receipts'));
    expect(t, contains('Settings → Privacy → Send read receipts'));
    expect(t, contains('Public markers already sent cannot be taken back'));
  });

  test('docs/STORE.md (Datensicherheit) nennt den Lesestatus', () {
    final t = File('docs/STORE.md').readAsStringSync();
    expect(t, contains('öffentliche Lesebestätigungen'));
    expect(t, contains('| Lesestatus (öffentlicher Lesemarker'));
    expect(t, contains('bereits gesendete Marker lassen sich nicht zurücknehmen'));
  });

  test('E-106 steht im Entscheidungsprotokoll und E-24 verweist darauf', () {
    final t = File('docs/ENTSCHEIDUNGEN.md').readAsStringSync();
    expect(t, contains('## E-106 Chat: Zustellstatus'));
    expect(t, contains('Angekommen beim Empfänger'));
    expect(t, contains('Issue #526, E-106):** „Lesebestätigungen privat“ gilt nur noch'));
  });
}
