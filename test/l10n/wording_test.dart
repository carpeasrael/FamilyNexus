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
    // #422, E-101: die Avatar-Wahl bleibt im Familienraum stehen
    expect(de.accountDeleteBody('@a:b.c', 'b.c'), contains('Avatars'));
    expect(enL.accountDeleteBody('@a:b.c', 'b.c'), contains('avatar'));
    expect(de.presenceSeenJustNow, 'Eben noch online');
    expect(enL.presenceSeenJustNow, 'Last online just now');
    expect(de.reminderBodyNow, 'Der Termin beginnt jetzt');
    expect(enL.reminderBodyNow, 'The event starts now');
    // Das „nur“ der Datenschutzaussage bleibt wahr: beide Erinnerungstexte sind genannt.
    expect(de.privacy5Body, contains('„Termin in …“ oder „Der Termin beginnt jetzt“'));
    expect(enL.privacy5Body, contains('“Event in …” or “The event starts now”'));
  });

  test('#326 Gruppe 6 E5: Datenansicht heißt „Datenübersicht“, die Meldefunktion bleibt „Report“/„Meldung“', () {
    expect(de.settingsReportLocal, 'Datenübersicht: alle lokal gespeicherten Daten zeigen');
    expect(de.settingsReportOnline, 'Datenübersicht: alle online gespeicherten Daten zeigen');
    expect(enL.settingsReportLocal, 'Data overview: show all locally stored data');
    expect(enL.settingsReportOnline, 'Data overview: show all data stored online');
    expect(de.reportWarning, startsWith('Die Übersicht zeigt deine Daten im Klartext.'));
    expect(enL.reportWarning, startsWith('The overview shows your data in plain text.'));
    expect(de.reportCopied, startsWith('Übersicht kopiert. Die App versucht, die Zwischenablage nach einer Minute zu leeren.'));
    expect(enL.reportCopied, startsWith('Overview copied. The app tries to clear the clipboard after one minute.'));
    expect(de.reportSaved, 'Übersicht gespeichert.');
    expect(enL.reportSaved, 'Overview saved.');
    for (final t in <String>[de.settingsReportLocal, de.settingsReportOnline, de.reportWarning, de.reportCopied, de.reportSaved]) {
      expect(t, isNot(contains('Protokoll')));
    }
    for (final t in <String>[enL.settingsReportLocal, enL.settingsReportOnline, enL.reportWarning, enL.reportCopied, enL.reportSaved]) {
      expect(t.toLowerCase(), isNot(contains('report')));
    }
    expect(enL.reportTitle, 'Report message');
    expect(de.reportDone, 'Meldung gesendet.');
  });

  test('#326 Gruppe 6 E11: Erinnerungszeile', () {
    expect(de.remindersFiresAt('12.11. 08:50'), 'Erinnerung: 12.11. 08:50');
    expect(enL.remindersFiresAt('12.11. 08:50'), 'Reminder: 12.11. 08:50');
  });

  test('#326 Gruppe 6 E17: Satzbau Verantwortlicher und Löschung', () {
    expect(de.privacy1Body, contains('Für die Verarbeitung auf dem Server ist der Betreiber des von dir gewählten Anbieters (Matrix-Server) verantwortlich; du siehst ihn bei der Einrichtung unter „Erweitert“.'));
    expect(enL.privacy1Body, contains('The operator of the provider you chose (Matrix server) is responsible for processing on the server; you can see it during setup under “Advanced”.'));
    expect(de.privacy9Body, contains('„Konto löschen“. Weitere Serverdaten verwaltet der Betreiber deines Servers.'));
    expect(enL.privacy9Body, contains('“Delete account”. Other server data is managed by your server’s operator.'));
  });

  test('#326 Gruppe 6 E32: „Geräteeinstellungen“ statt plattformabhängiger Systemeinstellungen', () {
    expect(de.settingsActivityBadgeApple, contains('in den Geräteeinstellungen unter Mitteilungen'));
    expect(de.remindersPermissionSystem, contains('in den Geräteeinstellungen ausgeschaltet'));
    expect(enL.settingsActivityBadgeApple, contains('in device settings under Notifications'));
    expect(enL.remindersPermissionSystem, contains('in the device settings'));
    for (final t in <String>[de.settingsActivityBadgeApple, de.remindersPermissionSystem]) {
      expect(t, isNot(contains('Systemeinstellungen')));
    }
    for (final t in <String>[enL.settingsActivityBadgeApple, enL.remindersPermissionSystem]) {
      expect(t.toLowerCase(), isNot(contains('system settings')));
    }
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
