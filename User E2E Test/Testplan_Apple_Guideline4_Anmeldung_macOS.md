# Testplan Apple-Rückmeldung Guideline 4 (Design): Anmeldung auf macOS

**Dokument-ID** `TP-FN-A4-MAC v03` · 14.11.2026 · Soll-Version **1.2.3 (29)**, Stand `main` @ `e4bc0b4` + #430

Bezug: App-Review-Rückmeldung vom 12.11.2026 (Submission `2caec11f-cf19-4664-8200-97fcc20b86b2`, MacBook Pro, „1.2.1 (27)“): *Der Nutzer wird zum Standardbrowser geführt, um sich anzumelden oder ein Konto anzulegen.* Apple akzeptiert den Browser nur mit `ASWebAuthenticationSession`. Issue #268, `docs/ENTSCHEIDUNGEN.md` E-91, `macos/Runner/MainFlutterWindow.swift:93-150`, `lib/data/platform/browser_launcher.dart:78-100`.

## 1. Zweck und Abgrenzung

Der Plan belegt am **laufenden macOS-Build**, ob Anmeldung und Kontoanlage beim Standardanbieter matrix.org in einer System-Sitzung **innerhalb der App** öffnen und **nicht** im Standardbrowser. Das ist die Lücke aus TP-OAUTH-11 (#268), die bisher nicht getestet war.

**Nicht Gegenstand von Block A (bewusst):** Eingabe von Zugangsdaten, Anlegen oder Löschen eines Kontos bei matrix.org (CLAUDE.md: keine echten Konten ohne Freigabe; Block B hat diese Freigabe vom Nutzer am 14.11.2026), Kontolöschung und Passwortänderung (brauchen ein Konto), iOS, Android, Notarisierung/App-Store-Signatur. Die Seite wird nur **geöffnet und angesehen**, dann mit „Abbrechen“ geschlossen.

## 2. Testobjekt und Umgebung

| Angabe | Wert |
|---|---|
| Build | `build/macos/Build/Products/Release/FamilyNexus.app`, 1.2.3 (29), Release |
| Prüfkopie | Kopie im Scratchpad, Bundle-ID `de.inneso.familynexus.apple4`, ad hoc neu signiert (Sandbox, `network.client`, **kein** `network.server`). Eigene Bundle-ID, damit Container und Schlüsselbund des Nutzers unberührt bleiben und der Start ohne Konto erfolgt |
| System | macOS 27.3 (dieser Mac), Standardbrowser laut `LaunchServices` (wird in A-01 erfasst) |
| Werkzeuge | `cliclick`, `osascript`, `screencapture`, `lsappinfo`, `codesign`, `strings` |
| Evidenz | Screenshot je Schritt in `screenshots/`, Befehlsausgaben in `logs/` |

## 3. Abnahmekriterien

1. Anmeldeseite von matrix.org erscheint als **Fenster der System-Sitzung vor der App**, nicht als Fenster oder Tab eines Browsers.
2. Das Fenster ist die System-Sitzung: „Privates Surfen“ im Titel, **keine Werkzeugleiste, keine Tabs**. Safari darf Vordergrundprozess sein (macOS hostet die Sitzung in Safari); es öffnet kein normales Browserfenster und kein Tab in einem anderen Browser (Vergleich vor/nach).
3. Abbrechen führt in die App zurück und zeigt einen **Hinweis** (zweite Textfarbe, Info-Symbol, kein roter Fehler, seit #430); Wiederholen funktioniert.
4. Gilt für Anmeldung **und** Kontoanlage und unabhängig vom eingestellten Standardbrowser.

Ergebnisse: ✅ bestanden · ⚠️ mit Befund · ❌ fehlgeschlagen · ⏳ nicht durchgeführt (mit Grund). Ein Schritt gilt nur als ✅, wenn das Erwartete am Screenshot oder an der Ausgabe nachweisbar ist.

## 4. Schritte

| Nr. | Schritt | Erwartung | Evidenz |
|---|---|---|---|
| A-01 | Versionen, Signatur, Entitlements der Prüfkopie, Standardbrowser, laufende Browser vor dem Test erfassen | 1.2.3 (29); Kanal `de.inneso.familynexus/webauth` im Binary; `network.client` ohne `network.server`; Liste der Browser-Prozesse notiert; Knopf „Bei matrix.org anmelden“ ohne „extern öffnen“-Symbol (Anmelde-Symbol) | `logs/A-01.txt` |
| A-02 | Prüfkopie starten, Willkommensseite ansehen | Willkommensseite mit „Neue Familie gründen“ und „Ich habe schon ein Konto“; keine Schlüsselbund-Abfrage | `screenshots/A-02.png` |
| A-03 | „Ich habe schon ein Konto“ öffnen | Standardanbieter matrix.org vorbelegt und geprüft, Knopf „Bei matrix.org anmelden“ | `screenshots/A-03.png` |
| A-04 | „Bei matrix.org anmelden“ klicken, 6 s warten | Anmeldefenster der System-Sitzung vor der App (Adresse account.matrix.org); Fenster toolbarlos mit „Privates Surfen“ (Safari darf Vordergrund sein); kein Tab in einem anderen Browser | `screenshots/A-04.png`, `logs/A-04.txt` |
| A-05 | Sitzung mit „Abbrechen“ schließen | Zurück in der App, **Hinweis** statt rotem Fehler, Knopf wieder bedienbar | `screenshots/A-05.png` |
| A-06 | A-04 und A-05 wiederholen | gleiches Ergebnis (kein hängender Zustand nach Abbruch) | `screenshots/A-06.png` |
| A-07 | Zurück, „Neue Familie gründen“, Name eingeben, „Konto bei matrix.org anlegen“ klicken | Kontoanlage öffnet ebenfalls in der System-Sitzung vor der App, nicht im Browser; **nichts ausfüllen** | `screenshots/A-07.png`, `logs/A-07.txt` |
| A-08 | Sitzung abbrechen, App beenden, Prüfkopie samt Container aufräumen | Rückkehr mit Hinweis, ohne Fehler; Container `de.inneso.familynexus.apple4` entfernt, Nutzerdaten unberührt | `logs/A-08.txt` |
| A-09 | Grenzfall Standardbrowser: Ergebnis aus A-04 mit dem in A-01 erfassten Standardbrowser bewerten | Sitzung ist unabhängig vom Standardbrowser; ⏳ falls kein zweiter Browser umgestellt werden darf (Systemeinstellung des Nutzers wird nicht verändert) | Bewertung im Bericht |

## 4b. Block B: echte Anmeldung bei matrix.org mit anschließender Löschung (v03)

**Freigabe:** Der Nutzer hat am 14.11.2026 ein echtes, kurzlebiges Konto bei matrix.org ausdrücklich freigegeben (CLAUDE.md „Grenzen ohne ausdrückliche Freigabe“). Das Konto wird mit einer vom Nutzer genannten Wegwerf-Mailadresse angelegt und am Ende gelöscht.

**Regeln für Block B**
- Der Tester **tippt keine Passwörter**, löst kein CAPTCHA und bestätigt keine Mails. Das macht der Nutzer; der Tester startet jeden Schritt, sagt, wann der Nutzer eingibt, und erfasst danach.
- Aufnahmen entstehen nur, wenn weder Passwort noch Mailadresse noch Notfall-Schlüssel sichtbar sind (zuschneiden oder verwerfen). Benutzername, Mailadresse, Notfall-Schlüssel und Passwort kommen **weder in Repository, Issue, Bericht noch Logs**; der Bericht nennt das Konto „Testkonto“.
- Standardbrowser: Vor B-02 wird der eingestellte Standardbrowser erfasst und in B-09 **wiederhergestellt**. Die Umstellung läuft über die Systemeinstellungen (Schreibtisch & Dock, „Standard-Webbrowser“) und wird vom Nutzer bei der Systemabfrage bestätigt.
- Abbruch: Scheitert die Kontolöschung, bleibt das Konto stehen; das wird im Bericht als offener Zustand mit nächstem Schritt für den Nutzer genannt, nicht als bestanden.

| Nr. | Schritt | Erwartung | Beleg |
|---|---|---|---|
| B-01 | Ausgangslage erfassen: Standardbrowser, laufende Browser, Prüfkopie mit frischer Bundle-ID | Standardbrowser dokumentiert; kein Konto angemeldet | `logs/B-01.txt` |
| B-02 | Standardbrowser auf Firefox (zweiter Lauf optional Chrome) umstellen, Wirkung per `LaunchServices` prüfen | Firefox ist Standard; Safari ist es nicht | `logs/B-02.txt` |
| B-03 | Prüfkopie starten, „Neue Familie gründen“, Name eingeben, „Konto bei matrix.org erstellen“ | Sitzung öffnet **vor der App** als Safari-gehostetes Fenster (nicht in Firefox); Firefox öffnet kein neues Fenster und keinen Tab | `screenshots/B-03.png` (zugeschnitten), `logs/B-03.txt` (Fensterlisten) |
| B-04 | **Nutzer** registriert im Sitzungsfenster mit der Wegwerf-Adresse (Passwort, CAPTCHA, Mailbestätigung) | Rücksprung in die App ohne Fehler; Anmeldung abgeschlossen | `screenshots/B-04.png` ohne Zugangsdaten |
| B-05 | In der App weiter: Notfall-Schlüssel erstellen (**nicht** aufnehmen, nicht speichern), Familie gründen | Hauptansicht erreichbar | `screenshots/B-05.png` |
| B-06 | Abmelden und über „Ich habe schon ein Konto“ erneut **in derselben Sitzung** anmelden (Nutzer tippt) | Anmeldung gelingt, wieder Sitzungsfenster, kein Standardbrowser | `screenshots/B-06.png`, `logs/B-06.txt` |
| B-07 | „Einstellungen > Konto > Konto löschen“, „Löschseite öffnen“ | Löschseite von account.matrix.org in der Sitzung (nicht in Firefox) | `screenshots/B-07.png` |
| B-08 | **Nutzer** bestätigt die Löschung auf der Anbieterseite, schließt mit „Abbrechen“, in der App „Löschung prüfen“ | App erkennt die Löschung, räumt lokal auf, zurück zur Willkommensseite | `screenshots/B-08.png` |
| B-09 | Standardbrowser auf den Ausgangswert zurückstellen, Prüfkopie samt Daten löschen | Standardbrowser wie in B-01; kein Rest im Scratchpad | `logs/B-09.txt` |
| B-10 | Gegenprobe: Anmeldung mit dem gelöschten Konto (Nutzer tippt) | Anmeldung schlägt fehl; Konto besteht nicht mehr | `screenshots/B-10.png` ohne Zugangsdaten |

**Abnahme Block B:** B-03, B-06 und B-07 zeigen die Sitzung unabhängig vom eingestellten Standardbrowser (schließt A-09 und Kriterium 4); B-04 und B-06 belegen Rücksprung nach echter Anmeldung; B-08 und B-10 belegen die Löschung.

## 5. Ausdrücklich nicht belegt durch diesen Plan

Passwortänderung und Verhalten auf dem Prüfer-Mac des App-Reviews, iOS-Gerät, signierter App-Store-Build. (Echte Anmeldung und Kontolöschung belegt Block B, nur wenn er ausgeführt wurde.)
