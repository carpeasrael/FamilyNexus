import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _texts(String name) {
  final m = json.decode(File('lib/l10n/$name.arb').readAsStringSync()) as Map<String, dynamic>;
  return <String, String>{
    for (final e in m.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// Text-Audit #326 (Gruppe 3): Wortwahl DE/EN, amerikanisches Englisch, typografische Zeichen.
void main() {
  final en = _texts('app_en');
  final de = lookupAppLocalizations(const Locale('de'));
  final enL = lookupAppLocalizations(const Locale('en'));

  test('#326 E15: englische Texte ohne gerade Apostrophe und Anführungszeichen (typografisch ’ “ ”)', () {
    final bad = <String>[for (final e in en.entries) if (e.value.contains("'") || e.value.contains('"')) e.key];
    expect(bad, isEmpty, reason: 'gerades \' oder " in: $bad');
  });

  test('#326 E7/E28: amerikanisches Englisch, keine britischen Formen', () {
    final uk = RegExp(
      r'colour|synchronis|cancell|licence|authoris|organis|behaviour|centre|whilst|amongst|\btick\b|at the weekend',
      caseSensitive: false,
    );
    final bad = <String>[for (final e in en.entries) if (uk.hasMatch(e.value)) e.key];
    expect(bad, isEmpty, reason: 'britische Form in: $bad');
  });

  test('#326 D4/D5/D7: deutsche Grammatik', () {
    expect(de.privacy7Rest, contains('technisch nicht zwangsweise löschen'));
    expect(de.privacy7Rest, isNot(contains('nicht erzwungen')));
    expect(de.onbInvitedOther, 'Stattdessen eine neue Familie gründen oder einer anderen beitreten');
    final w = de.identityChangedWarning('Ida');
    expect(w, contains('Die Geräte von Ida sind gesperrt'));
    expect(w, isNot(contains('Seine')), reason: 'Genus hängt am Namen, nicht am Satz');
  });

  test('#326 E6/E8/E14: englische Wortwahl', () {
    expect(enL.settingsAccentHint, contains('dark theme'));
    expect(enL.settingsAccentHint.toLowerCase(), isNot(contains('design')));
    expect(enL.privacy13Body, contains('a computer that is not yours or that others share'));
    expect(enL.privacy13Body, isNot(contains('foreign')));
    expect(enL.attachmentSaveWarning, contains('signing out'));
    expect(enL.attachmentSaveWarning, isNot(contains('logging out')));
  });

  test('#326 E25: „Was für Daten gibt es?“ nennt die Aufgabenlisten samt Verlauf', () {
    expect(de.privacy2Body('X', 'Y'), contains('Aufgabenlisten mit ihrem Verlauf'));
    expect(enL.privacy2Body('X', 'Y'), contains('task lists with their history'));
  });
}
