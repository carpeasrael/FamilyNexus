# Testreport FamilyNexus – 28.10.2026

Plan: TP-FN-001 v1.5 · Commit `bb7f347` (main) · Build 1.2.1 (18) · Server `matrix-synapse-3ues.srv1348446.hstgr.cloud`
Details je Schritt: `Ergebnisse.md`; Screenshots: `screenshots/` (Lauf 1), `screenshots-lauf2/` (Lauf 2); Protokolle: `logs/`.
Notfall-Schlüssel sind in Bildern geschwärzt; Schlüssel und Passwörter liegen nur im Sitzungsverzeichnis (Rechte 600).

## 1. Läufe
| Lauf | G1 | G2 | Datumsteil | Ergebnis |
|---|---|---|---|---|
| 1 | iPhone-Simulator (iPhone 15, iOS 27.0) | MacBook (macOS 27.2, Release-Build) | `1028` | A–F vollständig |
| 2 | MacBook | iPhone-Simulator | `1028c` (`1028b-n1` war fremd belegt) | A–F vollständig |

Plattformgrenzen: Kein physisches iPhone (Simulator). Mac-Benachrichtigungen blockiert, Mac-App-Sperre verlangt Systempasswort (nicht eingebbar), Web/Linux/Android nicht Teil.

## 2. Zusammenfassung
Alle Abschnitte A–F wurden in beiden Läufen durchgeführt. Keine ❌. Befunde (⚠️) unten. Alle Testkonten (`fnt-1028-*`, `fnt-1028c-*`) wurden gelöscht (403 bei Anmeldung); die Registrierung blieb offen. Automatische Tests: `flutter analyze` ohne Befund, `flutter test` 749 bestanden / 44 übersprungen.

## 3. Befunde
| # | Schwere | Lauf/Schritt | Befund |
|---|---|---|---|
| 1 | ⚠️ | 1 / A-07 (iOS-Simulator) | `Anna` wird stillschweigend zu `anna` und als „frei“ gewertet statt Fehler. Auf dem Mac (Lauf 2) korrekt abgelehnt → plattform-/eingabeabhängig, ggf. Simulator-Tastatur (Auto-Kleinschreibung); gegenprüfen |
| 2 | ⚠️ | 1 / B-05 (iOS-Simulator) | Neuer Termin: Ende blieb = Beginn (01:47–01:47) und wurde gespeichert. Auf dem Mac wandert das Ende mit (21:00–22:00) |
| 3 | ⚠️ | 2 / B-02, B-10 (Mac) | „Erlauben“ löst keinen Systemdialog aus, Erinnerungen kommen nicht an (Berechtigung blockiert, ad-hoc signierter Build) – nicht abschließend prüfbar |
| 4 | ⚠️ | 2 / B-17 (Mac) | App-Sperre einschalten verlangt Systemauthentifizierung; Abbruch → „Die Bestätigung war nicht erfolgreich.“ (korrekt), Sperre selbst nicht testbar |
| 5 | ⚠️ | 2 / D-02 | Ablehnung erreicht Gerät erst nach 2–4 Min. (Plan: bis 3 Min.) |
| 6 | ⚠️ | 1 / E-07 (Mac) | Web-Seite „App öffnen“ startet die installierte Release-App aus /Applications statt der getesteten Fassung (Test-Setup); `familynexus://join?…` funktioniert, `familynexus://join#…` ergibt „unvollständig oder beschädigt“ |
| 7 | ⚠️ | 2 / F-05 | Anmeldeassistent steht nach Datenlöschung wieder auf matrix.org (erwartet, Hinweis) |
| 8 | ⚠️ | 2 / Ende | Notfall-Schlüssel KN2d entstand durch Bedienfehler im Test (kein App-Fehler) |
| 9 | Info | 1+2 / E-32 | Nach Kontolöschung von I2 zeigt G1 deren Nachrichten mit Benutzer-ID statt Anzeigename |
| 10 | Info | Lauf 1 / V-04 | Schlüsselbund-Altlast `fn.key.db.app` (Vortag) blockierte Mac-Start; Nutzer musste Schlüsselbund freigeben |
| 11 | Info | iOS-Simulator | Großbuchstaben gehen beim Tippen teilweise verloren (Titel „Test serie“, „Termin i2“) – Testwerkzeug, kein App-Befund |

## 4. Abschnitts-Übersicht (Plan Abschnitt 2/6)
| Abschnitt | Lauf 1 | Lauf 2 |
|---|---|---|
| V (Vorbereitung) | ✅ | ✅ (Server geprüft, Namen frei) |
| A Start/Kontoanlage | ✅ (A-07 ⚠️) | ✅ |
| B Hauptfunktionen | ✅ (B-05 ⚠️) | ✅ (B-02/B-10/B-17 ⚠️, B-18 n/a) |
| C Zweites Gerät | ✅ | ✅ |
| D Weitere Wege | ✅ (D-07 n/a) | ✅ (D-02 ⚠️, D-07 n/a) |
| E Zwei Nutzer | ✅ (E-05 Mail ⏳) | ✅ |
| F Löschen/Aufräumen | ✅ | ✅ |
| G Automatik | ✅ G-01..03, G-05 | gilt aus Lauf 1 |
