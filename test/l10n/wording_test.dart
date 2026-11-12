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
  test('#326 Gruppe 5: eindeutige Formulierungen', () {
    expect(de.familyCodeHint, contains('Wer deiner Familie ohne Link beitreten will'));
    expect(de.familyCodeHint, isNot(contains('dir ohne Link')));
    expect(de.accountDeleteBody('@a:b.c', 'b.c'), contains('Die Benutzer-ID kann danach'));
    expect(de.accountDeleteBody('@a:b.c', 'b.c'), isNot(contains('Matrix-ID')));
    expect(enL.accountDeleteBody('@a:b.c', 'b.c'), contains('The user ID cannot be used again'));
    expect(enL.accountDeleteBody('@a:b.c', 'b.c'), isNot(contains('Matrix ID')));
    expect(de.presenceSeenJustNow, 'Eben noch online');
    expect(enL.presenceSeenJustNow, 'Last online just now');
    expect(de.reminderBodyNow, 'Der Termin beginnt jetzt');
    expect(enL.reminderBodyNow, 'The event starts now');
    // Das „nur“ der Datenschutzaussage bleibt wahr: beide Erinnerungstexte sind genannt.
    expect(de.privacy5Body, contains('„Termin in …“ oder „Der Termin beginnt jetzt“'));
    expect(enL.privacy5Body, contains('“Event in …” or “The event starts now”'));
  });

  test('#273 (a): Meldungen nur bei geöffneter App, auf Mobilgeräten im Hintergrund nicht zugesagt', () {
    expect(de.settingsActivityHint, contains('nur solange die App geöffnet ist'));
    expect(de.settingsActivityHint, contains('Auf Mobilgeräten können sie im Hintergrund und bei beendeter App ausbleiben'));
    expect(de.settingsActivityHint, isNot(contains('solange die App läuft')));
    expect(enL.settingsActivityHint, contains('only while the app is open'));
    expect(enL.settingsActivityHint, contains('On mobile devices they may not arrive while the app is in the background or closed'));
    expect(enL.settingsActivityHint, isNot(contains('is running')));
    expect(de.privacy5Body, contains('nur, solange sie geöffnet ist (auf Mobilgeräten können sie im Hintergrund ausbleiben)'));
    expect(de.privacy5Body, isNot(contains('solange sie läuft')));
    expect(enL.privacy5Body, contains('only while it is open (on mobile devices they may not arrive in the background)'));
    expect(enL.privacy5Body, isNot(contains('while it is running')));
    // Desktop läuft im Hintergrund weiter: dieser Satz bleibt.
    expect(de.privacy6DesktopNote, contains('solange die App läuft'));
  });
}
