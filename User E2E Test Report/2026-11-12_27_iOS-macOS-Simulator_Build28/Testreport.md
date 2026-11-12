# Testreport Lauf 2026-11-12_27 (Benachrichtigungen, iOS-Simulator und macOS)

- **Plan:** `User E2E Test/Testplan_Benachrichtigungen_macOS-iOS.md`, TP-FN-NTF-381 v01 (81 Schritte N-01 bis N-81)
- **Stand:** `main` = `origin/main` = `778b949`, App 1.2.3 (Build 28), Wegwerf-Worktree (Test-Bundle-ID `de.inneso.familynexus.e2e` nur für macOS)
- **Datum:** 12.11.2026, 20:01 bis 22:08 (Zeitzone CET)
- **G1:** iPhone-18-Pro-Simulator (iOS 27.2, UDID 88D3AAB5-763B-4CBA-AC5A-767498D144D2), Deutsch, Darstellung hell, Bedienung per Device Hub, Konto `fnt-1112-n1`
- **G2:** macOS 27.3, ad hoc signierte Test-App 1.2.3 (28): **nicht bedienbar** (Schlüsselbund-Abfrage, Befund 1)
- **Sender (Ersatz für den Mac):** zweiter Wegwerf-Simulator `FNT-Sender-1112` (iPhone 18 Pro, iOS 27.2), Konto `fnt-1112-i2`, am Ende gelöscht
- **Server:** Projekt-Testserver `matrix-synapse-3ues.srv1348446.hstgr.cloud` (Homeserver-Name `matrix.chaostribunal.de`), kein matrix.org

## Zählung (nach `Ergebnisse.tsv`, 114 Zeilen)

| ✅ | ⚠️ | ❌ | ⏳ | n/a |
|---|---|---|---|---|
| 37 | 20 | 0 | 49 | 8 |

Je Gerät: G1 ✅ 31, ⚠️ 17, ⏳ 3, n/a 7; G2 (Mac) ✅ 1 (N-80), ⚠️ 1 (N-02), ⏳ 46, n/a 1; S (Ersatzsimulator) und "-": der Rest. Kein ❌.

**Einordnung gegen Abnahmekriterien (Plan Abschnitt 9):** Nicht abgenommen. Der Mac-Teil (Kriterium 4 für macOS, N-21, N-41, N-50, N-52, N-53 bis N-62, Teile von N-72 bis N-77) ist ⏳, weil die Test-App das Schlüsselbund-Passwort verlangt. Für den iOS-Simulator sind die Pflichtschritte N-01 bis N-10 (N-04 und N-05 ⚠️ wegen Ersatzsender), N-13 bis N-16, N-19, N-25 bis N-28, N-35 bis N-38, N-47, N-49, N-72 bis N-75, N-77, N-78 ausgeführt, ohne ❌.

## Erinnerung bei beendeter App

| Gerät | Zustand | Meldung? | Zeit |
|---|---|---|---|
| iOS-Simulator (G1) | App beendet 20:57:53 (`launchctl`: kein Prozess), Termin "Ntf Beendet" Vorlauf 5 min, Soll 21:00:00 | **Ja**, "Erinnerung / Termin in 5 Minuten", ohne Titel | Banner im Bild ab 21:00:00 (+0 s) bis 21:00:08 |
| iOS-Simulator (G1) | App beendet 21:09:21, Termin "Ntf Start beendet", Zur Startzeit, Soll 21:10:00 | **Ja**, "Erinnerung / Der Termin beginnt jetzt", ohne Titel | Banner ab 21:10:00 (+0 s) |
| macOS (G2) | Cmd+Q, Termin Vorlauf 5 min | **nicht geprüft (⏳)** | Schlüsselbund-Abfrage, siehe Befund 1 |

Gilt nur für den Simulator, nicht für ein echtes iPhone (Plan Abschnitt 12, #381 bleibt offen: `Refs #381`).

## Meldungen im Hintergrund und bei beendeter App (E-88/#273)

| Gerät | Zustand | Chat | Einkauf |
|---|---|---|---|
| G1 | Hintergrund (Home), N-47: Chat 20:46:40 und 20:46:51, Einkauf 20:47:07 | **nein** (Bildfolge bis 20:47:21, Zentrale 20:47:56, 20:49:46, 20:50:45: nur Erinnerung) | **nein** (gleiche Prüfpunkte, 180 s) |
| G1 | Rückkehr in den Vordergrund (N-48, 20:52) | Banner "Neue Nachrichten" **nachträglich** (Befund 6) | Banner "Neue Einträge auf dem Einkaufszettel" **nachträglich** |
| G1 | App beendet, N-49: Einkauf 20:58:23, Chat 20:58:39 | **nein** (60 s und 180 s, Zentrale 21:01:33) | **nein** |
| G1 | Start 21:01:44 | keine nachträgliche Meldung (8 s und 36 s danach) | keine |
| G2 (Mac) | minimiert, ausgeblendet, Cmd+Q | ⏳ | ⏳ |

Ausbleiben im Hintergrund und bei beendeter App ist laut E-88/#273 kein Fehler; auf dem Simulator belegt es nichts für das Gerät.

## Zusammenstellung der Meldungstexte (N-75, iOS-Simulator, Mitteilungszentrale und Banner)

| Meldung | Titel | Text | Beleg |
|---|---|---|---|
| Erinnerung 5 min | Erinnerung | Termin in 5 Minuten | N-14-G1_a, N-14-G1_b, N-19-G1_b |
| Erinnerung 10 min | Erinnerung | Termin in 10 Minuten | N-67-G1_b_Zentrale |
| Erinnerung Start | Erinnerung | Der Termin beginnt jetzt | N-16-G1, N-23-G1 |
| Chat | FamilyNexus | Neue Nachrichten | N-25-G1, N-26-G1, N-29-G1 |
| Einkauf | FamilyNexus | Neue Einträge auf dem Einkaufszettel | N-35-G1, N-38-G1_a, N-36-G1 |
| Englisch | FamilyNexus / Reminder | New messages / New items on the shopping list / The event starts now | N-69-G1_a bis _c |

Weder Titel (`Ntf Geheim Zahnarzt`), Ort (`Ntf Geheimort`), Notiz (`Ntf Geheimnotiz`), Absender (Test Nutzer 2, Test N1), Gesprächsname noch Nachrichteninhalt (`Ntf …`) in einer Meldung. Datenschutz hart: eingehalten (iOS-Simulator).

## Befunde (Details in `Befunde.md`)

1. hoch (Umgebung): Mac-Test-App verlangt Schlüsselbund-Passwort, Mac-Schritte nicht ausführbar.
2. Hinweis: Ersatz-Simulator S als Sender, dort auch die Berechtigungsfälle.
3. Hinweis/Planfehler: iOS-Mitteilungsfreigabe überlebt Deinstallation und `privacy reset`.
4. niedrig: `settingsActivityBadgeApple` steht immer (Code `settings_notify_parts.dart:82-86`), Plan erwartet Ausblenden bei erteilter Freigabe.
5. niedrig: Chat-Meldung blieb in N-30 in der Zentrale stehen.
6. mittel: nachträgliche Banner nach Rückkehr in den Vordergrund (N-48) gegen Plan-Erwartung.
7. Hinweis: Banner bei N-17 nicht im Bild, Zustellung belegt.
8. Hinweis: Tipp auf Meldung nicht automatisierbar (N-33 ⏳).
9. Hinweis: Simulatorhänger, Bedienfehler (N-67, N-71, N-74, N-36).
10. Hinweis: Terminzeiten und Vorlauf weichen vom Plan ab (14 min statt 7; 10 min Standard).
11. Hinweis: Servername `matrix.chaostribunal.de`.
12. Hinweis: Device-Hub-Fenster des Nutzers (iPhone Duo) kurz umgewidmet, wiederhergestellt.

## Nicht getestet / ⏳

- **Alle macOS-Schritte (G2)** wegen Schlüsselbund-Abfrage (nur der Nutzer kann sie bestätigen): N-06 bis N-10, N-12, N-13 bis N-16, N-18, N-21 bis N-24, N-41, N-42, N-44 bis N-46, N-50 bis N-62, N-63, N-65, N-66 bis N-78 (G2), N-72 G2.
- N-33 (Tipp auf Meldung, Werkzeuggrenze), N-68 (Verweigerungsfall, G1 nie verweigert), N-76 (Sperrbildschirm, Simulator ohne Gerätecode), Abschnitt 12 des Plans (echtes iPhone, signierter Mac, Ruhezustand, Neustart).
- N-36 (Text ändern), N-67 (Chat-Teil), N-74 (Zwischenzeit) nur teilweise (⚠️).

## Tabelle N-78 (Verhalten gegen Text, iOS)

| Beobachtung | Text | Übereinstimmung |
|---|---|---|
| Chat/Einkauf im Hintergrund und bei beendeter App bleiben aus (N-47, N-49) | `settingsActivityHint`: "nur solange die App geöffnet ist … können ausbleiben" | ja |
| Meldungen kommen nach Rückkehr in den Vordergrund (N-48) | "solange die App geöffnet ist" | ja, Plan-Erwartung "nicht nachträglich" aber nicht erfüllt (Befund 6) |
| Erinnerung bei beendeter App kommt (N-19, N-23, Simulator) | `privacy5Body`: nur "Termin in …"/"Der Termin beginnt jetzt", nichts zu beendeter App | ja (kein Mehrversprechen) |
| macOS | `privacy6DesktopNote` | ⏳ |

## Grenzen des Simulators

Kein Gerätecode (`private` nicht prüfbar), keine Einfrierung im Hintergrund, Mitteilungsfreigabe überlebt Neuinstallation, Mac ad hoc signiert (Schlüsselbund-Abfrage).

## Offene Nachtests (Plan Abschnitt 12)

Echtes iPhone (Hintergrund, beendete App, Sperrbildschirm, Kennzeichen iOS 15), signierter Mac (TestFlight), Mac im Ruhezustand, Neustart; sowie der gesamte macOS-Teil dieses Plans.

## Aufräumstand

Beide Testkonten in der App gelöscht (`M_USER_IN_USE`, Login 403), Zugangsdatei vernichtet, Worktree entfernt, Sender-Simulator gelöscht, G1 deinstalliert und heruntergefahren, `caffeinate` beendet, Nutzer-App `/Applications/FamilyNexus.app` nicht gestartet. Siehe `logs/N-79.txt`, `N-80.txt`, `N-81.txt`.
