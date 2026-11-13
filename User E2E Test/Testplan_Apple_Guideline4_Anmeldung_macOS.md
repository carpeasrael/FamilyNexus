# Testplan Apple-Rückmeldung Guideline 4 (Design): Anmeldung auf macOS

**Dokument-ID** `TP-FN-A4-MAC v02` · 13.11.2026 · Soll-Version **1.2.3 (29)**, Stand `main` @ `e4bc0b4` + #430

Bezug: App-Review-Rückmeldung vom 12.11.2026 (Submission `2caec11f-cf19-4664-8200-97fcc20b86b2`, MacBook Pro, „1.2.1 (27)“): *Der Nutzer wird zum Standardbrowser geführt, um sich anzumelden oder ein Konto anzulegen.* Apple akzeptiert den Browser nur mit `ASWebAuthenticationSession`. Issue #268, `docs/ENTSCHEIDUNGEN.md` E-91, `macos/Runner/MainFlutterWindow.swift:93-150`, `lib/data/platform/browser_launcher.dart:78-100`.

## 1. Zweck und Abgrenzung

Der Plan belegt am **laufenden macOS-Build**, ob Anmeldung und Kontoanlage beim Standardanbieter matrix.org in einer System-Sitzung **innerhalb der App** öffnen und **nicht** im Standardbrowser. Das ist die Lücke aus TP-OAUTH-11 (#268), die bisher nicht getestet war.

**Nicht Gegenstand (bewusst):** Eingabe von Zugangsdaten, Anlegen oder Löschen eines Kontos bei matrix.org (CLAUDE.md: keine echten Konten ohne Freigabe), Kontolöschung und Passwortänderung (brauchen ein Konto), iOS, Android, Notarisierung/App-Store-Signatur. Die Seite wird nur **geöffnet und angesehen**, dann mit „Abbrechen“ geschlossen.

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

## 5. Ausdrücklich nicht belegt durch diesen Plan

Anmeldung mit echten Zugangsdaten und Rücksprung in die App (Callback), Kontolöschung und Passwortseite auf dem Mac, Verhalten auf dem Prüfer-Mac des App-Reviews, iOS-Gerät, signierter App-Store-Build.
