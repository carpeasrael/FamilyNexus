# Testreport: Lauf 19, nur G1 (iPhone-17-Simulator), Build 23

Teillauf des Plans `Testplan_FamilyNexus.md` (TP-FN-001 v1.20) nur mit G1. Alle Schritte, die ein zweites Gerät brauchen, sind ⏳. Einzelergebnisse: `Ergebnisse.tsv`, Belege: `screenshots/`, `logs/`.

## 1. Festlegung (Abschnitt 2 des Plans)

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | iOS-Simulator | nicht vorhanden |
| Gerät | iPhone 17 (Simulator-ID 55FC5477-…) | – |
| Betriebssystem | iOS 27.2, Host macOS 27.2, Xcode 27.2 | – |
| Installationsquelle | `flutter build ios --simulator --debug` aus `main` (Commit 48e9299) | – |
| App-Version Soll / Ist | 1.2.2 (23) / 1.2.2 (23) | – |
| Sprache | Gerätesprache, Deutsch; keine Geräte-PIN | – |
| Screenshots | `xcrun simctl io <Gerät> screenshot` | – |
| Bedienung | `cliclick` auf dem Device-Hub-Fenster, Tastenereignisse (Anhang D) | – |
| Datum | 03.11.2026, ca. 22:45 bis 23:15 | – |

Abweichung vom Apple-Lauf (G1 = iPhone, G2 = Mac): G2 fehlt. Der Lauf ersetzt ihn nicht.

Konten: Präfix `1103b` (`fnt-1103-*` waren vergeben). Passwort und Notfall-Schlüssel nur in `secure/Lauf_1103b_G1.txt`.

## 2. Ergebnis

| Bereich | ✅ | ⚠️ | ⏳ |
|---|---|---|---|
| V (Vorbereitung) | 5 | 1 (V-06) | – |
| A (Kontoanlage) | 8 | 3 (A-06, A-08, A-10) | 3 (A-05a, A-07, A-08b) |
| B (Hauptfunktionen) | 8 | 11 | 4 (B-10, B-12a, B-17, B-24) |
| C, D, E | – | – | alle (brauchen G2) |
| F | 5 (F-03 bis F-07) | 1 (F-08) | 2 (F-01, F-02: N2 fehlt) |
| H | 3 (H-02 bis H-04) | – | übrige |

Zählung nach `Ergebnisse.tsv`; Schritte mit mehreren Zeilen (B-11, B-18 bis B-21, B-23) zählen mit der zuletzt eingetragenen Bewertung. Kein ❌.

## 3. Wichtigste Belege

- **Konto und Familie (A-09 bis A-12):** N1 `fnt-1103b-n1` angelegt, Notfall-Schlüssel (im Bild geschwärzt), Familie „Testfamilie 1103b“.
- **Kalender (B-03 bis B-11):** geteilter, privater und wiederkehrender Termin; Bearbeiten ändert Titel und Uhrzeit sofort; Verlauf zeigt die frühere Fassung; „Nur dieses“ löscht nur ein Vorkommen.
- **Chat, Einkauf, Aufgaben (B-12 bis B-15):** Termin-Karte im Chat, Einkauf mit Abhaken und Bearbeiten, Aufgabenliste mit Verlauf (Datum `3.11.2026`, 22:57).
- **Wiederherstellung (F-03 bis F-05):** nach „Alle lokalen Daten löschen“ und Neustart „Willkommen“; nach Anmeldung und Notfall-Schlüssel sind Termine (auch private), Chat, Einkauf und Aufgaben wieder da.
- **Kontolöschung (F-06, F-07):** Dialog ohne Moderator-Hinweis, danach „Willkommen“; `curl`-Login liefert `403 M_FORBIDDEN` (`logs/F-07_gegenprobe.txt`).
- **Verschlüsselung auf dem Gerät (H-02 bis H-04):** beide Datenbanken beginnen mit Zufallsbytes, `sqlite3` meldet „file is not a database“, keine Klartexttreffer für Chat-, Termin-, Einkaufs- und Aufgabentexte (`logs/H-02_bis_H-04.txt`).

## 4. Auffälligkeiten

| Nr. | Schritt | Befund | Bewertung |
|---|---|---|---|
| 1 | B-22 | Unter „Konto“ steht Server `matrix.chaostribunal.de`, der Plan erwartet die Anbieter-Adresse `matrix-synapse-3ues…`. | **Kein App-Fehler, Plantext veraltet.** `settings_screen.dart:295` zeigt `gateway.server?.host`; das ist `_client?.homeserver` (`sdk_matrix_gateway.dart:223`), also die nach `.well-known` aufgelöste Basis-URL. Der Testserver liefert `/.well-known/matrix/client` mit `base_url: https://matrix.chaostribunal.de/`, und dieser Host antwortet am 03.11.2026 mit HTTP 200 auf `/_matrix/client/versions`. Auch A-05 zeigt „Betreiber: matrix.chaostribunal.de“. Zugleich ist die Aussage im Plan (Abschnitt 3, „`matrix.chaostribunal.de` ist nicht erreichbar“) heute nicht mehr zutreffend; abhängig vom Netz des Testers. Vorschlag: B-22 auf „Server = aufgelöster Homeserver (laut `.well-known`)“ ändern und Abschnitt 3 prüfen (eigenes Issue, Plan-Änderung nach Standardablauf). |
| 2 | B-06 | Ganztägiger Termin `Test Serie` entstand zweitägig (5. und 6. November). | **Ursache im Code belegt, kleiner Randfall.** `event_editor_screen.dart:113-120`: Die Voreinstellung ist „nächste volle Stunde“. Um 22:xx Uhr (hier 22:52) ist das 23:00, das Ende 00:00 und `_endDate` wird auf den Folgetag gesetzt (Zeile 120). Neuer Beginn per Datumswahl: `_moveStart` (Zeile 166 ff.) behält die Dauer, das Ende bleibt einen Tag später. Beim Einschalten von „Ganztägig“ übernimmt der Zweig `_allDay` (Zeile 171 ff.) die Spanne `days = _endDate - _startDate` = 1. Der Termin ist dann zweitägig, obwohl der Nutzer nie ein Ende gewählt hat. Nur zwischen 22:00 und 22:59 Ortszeit (und bei Start 23:00) reproduzierbar; sonst Ende = Beginn. Plan B-06 erwartet drei Vorkommen im Wochenabstand, das traf zu (nur die Dauer je Vorkommen ist zwei Tage). Vorschlag: Beim Einschalten von „Ganztägig“ das Ende auf den Beginn setzen, solange das Ende nicht vom Nutzer geändert wurde; eigenes Issue mit Regressionstest, kein Release-Blocker. |
| 3 | B-14 | Enter im Dialog „Eintrag bearbeiten“ springt zum nächsten Feld statt zu speichern. | **Gewollt, kein Befund.** `shopping_screen.dart:419-422`: Kommentar „Desktop: Enter speichert (#68); mobil springt „Weiter“ zur Menge“; `textInputAction: next`, `onSubmitted` nur bei `PlatformInfo.enterSubmits` (Desktop). Der Plan nennt für mobil den Knopf „Speichern“, wie ausgeführt. |
| 4 | A-10, F-05 | Zwischenablage-Einsetzen (Menü Bearbeiten) blieb im Simulator wirkungslos, Notfall-Schlüssel wurde per Tasten eingegeben. | Werkzeug-Einschränkung, kein App-Befund. |

## 5. Nicht getestet (Gründe)

- C, D, E, F-01, F-02: zweites Gerät fehlt.
- B-10 (Erinnerung): 12 Minuten Wartezeit und Systembenachrichtigung nicht automatisiert beobachtet.
- B-12a: Netz im Simulator nicht getrennt.
- B-17: keine Geräte-PIN eingerichtet (V-07 offen).
- B-23: nur der Fall „aktuelles Passwort falsch“; Passwort blieb unverändert.
- B-24, A-05a, A-07, A-08b: nicht ausgeführt.
- H-01 bis H-20 außer H-02 bis H-04: nicht ausgeführt.
- Unterlassene Teilprüfungen innerhalb von ⚠️ stehen in `Ergebnisse.tsv`.

## 6. Zustand am Ende (F-08)

- Gelöscht: `fnt-1103b-n1`.
- Nie angelegt: `fnt-1103b-n12`, `fnt-1103b-i2`.
- Simulator: App ohne Daten, „Willkommen“ (Sprache zurück auf „Gerätesprache“).
- Lokal: Zugangsdaten in `secure/Lauf_1103b_G1.txt` (mit Vermerk „N1 gelöscht“), unversioniert.

## 7. Abnahme

Die Abnahme des Gesamtplans ist **nicht** erfüllt (G2-Schritte offen). Für G1 gilt: keine ❌; ein Plantext-Fehler (B-22), ein kleiner Code-Randfall (B-06, Issue-Kandidat) und ein gewolltes Verhalten (B-14).
