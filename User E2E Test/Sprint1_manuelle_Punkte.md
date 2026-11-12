# Sprint 1: manuelle Punkte (Stand 12.11.2026)

Zusammenstellung der Punkte aus dem Sprintplan `Sprint/Sprintplan_26-11.html`, die Agenten nicht ausführen können (Gerät, Konto, Play Console, Entscheidung). Die Einzelschritte stehen in `Checkliste_Geraetenachtests.md` und im Testplan; Ergebnisse gehören in das jeweilige Issue. Alle genannten Issues sind offen; ein Issue schließt sich erst, wenn sein Nachtest bestanden und der Fix auf `main` ist.

**Stand der Code-Issues:** #410 (PR #417) und #412 (PR #418) sind gemergt. PR #419 (#326 Gruppe 6, `Refs`) und PR #420 (#273, Variante (a), `Refs`) warten auf den Merge. #345 (Ladebild folgt dem System, E-94) und #351 (App teilen, nur Zwischenablage, E-95) sind entschieden; offen ist nur der Gerätetest.

## Windows 11 (echte Tastatur)
- [ ] **#263 Zeitwähler:** mit simulierten Tasten bestanden; offen: physische Tastatur.
- [ ] **#144 Screenshot-Hinweis (B-18):** offen: Bildschirmaufnahme und -freigabe.
- [ ] **#254 Meldungen und Overlay (E-16b):** Fix bestanden; das Issue bleibt wegen der Geräte der anderen Plattformen offen.
- [ ] **#274 Desktop-Fenster:** offen: 200 % Schrift.
- [ ] **#330 Overlay „9+“:** bei 100, 125, 150 und 200 % Skalierung, hell und dunkel; ist die Schrift zu klein, Fallback -10 und im Issue vermerken.
- [ ] **#325 Tests auf Windows-Host:** Pfadtrenner und CRLF (8 Tests); braucht einen Windows-Lauf.

## iPhone (echt)
- [ ] **#144 (B-18):** Bildschirmaufnahme und App-Umschalter am Gerät.
- [ ] **#254 (E-16b):** Sperrbildschirm, iOS 15, nachträgliche Freigabe „Kennzeichen“.
- [ ] **#268, #297 (TP-OAUTH-11):** Anmeldung in der System-Sitzung (Captcha, Konto löschen, Hinweis zum Schließen); braucht einen OAuth-Anbieter. Gegen matrix.org nur mit Freigabe und eigenem Konto.
- [ ] **#317 (B-02):** Karte „Berechtigung fehlt“ bei blockierten Benachrichtigungen; hell, dunkel, große Schrift.
- [ ] **#316, #345 (A-01):** Kaltstart hell und dunkel; notieren, ob der Wechsel beim Übergang zur App kommt (erwartet, E-94) und ob iOS im App-Umschalter das Vorschaubild des letzten Zustands zeigt.
- [ ] **#273 (E-16b):** notieren, ob und nach wie vielen Sekunden im Hintergrund eine Meldung kommt. Ausbleiben ist kein Fehler (E-88, Entscheidung (a)).

## Mac (signierter TestFlight-Build 26)
- [ ] **#268:** Anmeldung in der System-Sitzung, Chrome als Standardbrowser, Start ohne `network.server`.
- [ ] **#254:** Meldung, Dock-Zahl, Berechtigungsabfrage.
- [ ] **#274:** wie bei Windows.
- [ ] **#266:** App startet mit `sqlite3` 3.8.0, Tresor und Datenbank lesbar.

## iPad und Android
- [ ] **iPad, #274 (B-25):** vier Ausrichtungen, Split View, Slide Over, Stage Manager, Tastatur, 200 % Schrift, „Entwurf bleibt beim Drehen“; dazu iPad-Screenshots für den App Store.
- [ ] **Android-Tablet, #274 (B-25):** Drehen mit und ohne Rotationssperre, Multi-Window, Tastatur, 200 % Schrift.
- [ ] **Android, #268 (TP-OAUTH-12):** Custom Tab auf frischem AVD oder nach Deinstallation; Geräte mit anderem oder ohne Standardbrowser.
- [ ] **Android 15/16 (echtes Gerät), #273:** Hintergrund-Meldung messen; bisher nur im Android-16-Emulator gemessen.
- [ ] **#351 „App teilen“:** Satz mit Play-Store-Link landet in der Zwischenablage, kein Familien-, Raum- oder Einladungsdatum; kein System-Teilen-Menü (E-95).
- [ ] **#350 „App bewerten“:** Gerätetest.

## Screenreader (alle Plattformen)
- [ ] **#332:** eigene Chatnachricht „Nachricht von dir“ / „Message from you“ mit VoiceOver (iPhone, iPad, Mac), TalkBack, NVDA. Das Label ist im Widget-Test belegt, die Sprachausgabe nicht.
- [ ] **#326:** Screenreader-Nachtests der Textänderungen am Gerät.

## Browser, Docker und Server
- [ ] **#266 Web:** `tool/web_smoke.py` auf `main`, Soll 5/5.
- [ ] **#281:** Docker Desktop starten, `tool/synapse/up.sh`, danach `curl -fsk https://localhost:18448/_matrix/client/versions` liefert 200 (nie 502); einmal `tool/synapse/password_variants.sh`.
- [ ] **#142:** Identitätswechsel mit zwei Konten gegen den lokalen Synapse.
- [ ] **#259:** Anbieter-Adresse am Gerät mit dem Testserver.

## Play Console und Prüfkonto
- [ ] **#348:** Play-Store-Beschreibung für ASO (DE/EN).
- [ ] **#349:** Play-Store-Screenshots mit Funktions-Highlights.
- [ ] **#15:** Prüfkonto und Prüfanleitung auf neuem Build nachtesten.

## Entscheidungen und Merges
- [ ] **#326 E9:** Original-Befund nennen (Wortlaut Android-Berechtigungen, `privacy_sections_test.dart`); bis dahin zurückgestellt.
- [ ] **Merge:** PR #419 und PR #420.
- Spätere Sprints: #273/#381 (Push, Sprint 2), #311 Haushaltsbuch (Sprint 3), #119, #120, #121 (v1.4; #121 nicht ohne rechtliche Freigabe).
