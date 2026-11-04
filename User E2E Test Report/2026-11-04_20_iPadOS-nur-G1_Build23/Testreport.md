# Testreport: Lauf 20, nur G1 (iPad-Air-13-Simulator), Build 23

Teillauf des Plans `Testplan_FamilyNexus.md` (TP-FN-001 v1.23, Commit `4b931a2`) nur mit G1. G2 wurde auf Vorgabe nicht genutzt; alle Schritte, die ein zweites Gerät brauchen, sind ⏳. Einzelergebnisse: `Ergebnisse.tsv`, Belege: `screenshots/` (Notfall-Schlüssel geschwärzt), `logs/`.

## 1. Festlegung (Abschnitt 2 des Plans)

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | iPadOS-Simulator | nicht genutzt |
| Gerät | iPad Air 13-inch (M4), Simulator-ID 537A7F28-… | – |
| Betriebssystem | iPadOS 27.2, Host macOS 27.2 | – |
| Installationsquelle | `flutter build ios --simulator --debug` aus `main`-Stand `4b931a2` | – |
| App-Version Soll / Ist | 1.2.2 (23) / 1.2.2 (23) | – |
| Sprache | Gerätesprache Deutsch; Geräte-PIN gesetzt, Code unbekannt (B-17) | – |
| Screenshots | `xcrun simctl io <Gerät> screenshot` | – |
| Bedienung | `cliclick` und AppleScript auf dem Device-Hub-Fenster (Anhang D) | – |
| Datum | 04.11.2026, ca. 19:00 bis 20:00 | – |

Abweichung vom Apple-Lauf (G1 = iPhone, G2 = Mac): iPad statt iPhone, G2 fehlt. Der Lauf ersetzt ihn nicht.

Konto: `fnt-1104-n1` (Familie „Testfamilie 1104“), inzwischen gelöscht (F-06, F-07). Passwort und Notfall-Schlüssel nur in `secure/Lauf_1104_G1.txt` (von Git ignoriert).

## 2. Ergebnis

| Bereich | ✅ | ⚠️ | ⏳ |
|---|---|---|---|
| V | 6 | – | – |
| A | 11 | 2 (A-08, A-08b) | 1 (A-05a) |
| B | 15 | 5 (B-02, B-06, B-15, B-18, B-22) | 6 (B-10, B-12a, B-17, B-23 teils, B-24, …) |
| C, D, E | – | – | alle (brauchen G2) |
| F | 5 (F-03 bis F-07) | 1 (F-08) | 2 (F-01, F-02) |
| G | 2 (G-01, G-03) | 1 (G-02) | 3 (G-04, G-06, G-07) |
| H | 4 (H-01 bis H-04) | – | übrige |

Genaue Zählung nach `Ergebnisse.tsv`. Kein ❌.

## 3. Wichtigste Belege

- **Kontoanlage (A-09 bis A-12):** N1 angelegt (`M_USER_IN_USE`, `logs/A-09_konto_angelegt.txt`), Notfall-Schlüssel bleibt stehen, „Gespeichert“-Hinweis, Familie eingerichtet.
- **Kalender, Chat, Einkauf, Aufgaben (B-03 bis B-15):** geteilter, privater und wiederkehrender Termin; Bearbeiten ändert Titel und Uhrzeit sofort, Verlauf zeigt Version 1; „Nur dieses“ löscht ein Vorkommen; Einkauf mit Gruppen; Aufgabenliste.
- **Wiederherstellung (F-03 bis F-05):** nach „Alle lokalen Daten löschen“ und Neustart „Willkommen“; nach Anmeldung und Notfall-Schlüssel sind Termine (auch private), Chat und Einkauf wieder da.
- **Kontolöschung (F-06, F-07):** Dialog ohne Moderator-Hinweis, danach „Willkommen“; Login liefert `403 M_FORBIDDEN` (`logs/F-07_gegenprobe.txt`).
- **Verschlüsselung auf dem Gerät (H-02 bis H-04):** genau zwei Datenbanken, beide mit Zufallsbytes im Kopf, `sqlite3` meldet „file is not a database“, 0 Treffer für acht Suchbegriffe in beiden Datenbanken und im ganzen App-Container (`logs/H-02_bis_H-04.txt`).
- **Automatische Tests:** `flutter analyze` ohne Befund; `flutter test`: 1657 bestanden, 125 übersprungen, 1 fehlgeschlagen.

## 4. Auffälligkeiten

| Nr. | Schritt | Befund | Bewertung |
|---|---|---|---|
| 1 | G-02 | `test/data/app_badge_test.dart` (#254, „Linux sendet LauncherEntry.Update …“) läuft in ein Timeout nach 30 s (`DBusClient._openSocket`). | **Umgebung, kein App-Fehler:** Der Test öffnet einen D-Bus-Socket, den es auf dem macOS-Host nicht gibt. Auf dem Linux-Host prüfen; Plan könnte den Test auf Linux beschränken (eigenes Issue nach Standardablauf). |
| 2 | B-22 | Server zeigt `matrix.chaostribunal.de`, Plan erwartet die Anbieter-Adresse. | Wie Lauf 19: Plantext veraltet. |
| 3 | A-01 ff. | Auf dem iPad läuft die App als schmales Hochformat-Fenster (ca. 40 % Breite) mit Hintergrund daneben; die Fensterbreite war zeitweise veränderbar. | Beobachtung, nicht weiter untersucht. Prüfen, ob die App iPad-Vollbild unterstützen soll (Info.plist / Orientierungen). |
| 4 | B-17 | iPad-Code verlangt, Code nicht bekannt; Bestätigung scheiterte („Die Bestätigung war nicht erfolgreich.“), Schalter blieb aus. | Werkzeug-Grenze, ⏳. |
| 5 | A-08, A-10, B-15, F-05 | Tastenereignisse verlieren Zeichen; Zwischenablage-Einfügen und Zeilenumbruch kamen nicht an. Passwort deshalb `ipuf1104x7`; Notfall-Schlüssel und Zeilenumbruch per AppleScript. | Werkzeug-Einschränkung (Anhang D), kein App-Befund. |
| 6 | Lauf | Eigene Fehlbedienung: roter Fensterknopf schob die App in den Hintergrund, `simctl` hing einmal, Gerät per Neustart behoben, Daten blieben erhalten. | Kein App-Befund. |

## 5. Nicht getestet (Gründe)

- C, D, E, F-01, F-02, H-10 bis H-20: zweites Gerät (G2) nicht genutzt.
- B-10 (Erinnerung, 12 Minuten Wartezeit), B-12a (Netz nicht getrennt), B-17 (Geräte-Code unbekannt), B-23 (c) bis (e), B-24 (Emoji-Eingabe), A-05a (präparierter Server), G-04, G-06, G-07.
- H-05 bis H-09: Schlüsselspeicher des Simulators nicht einsehbar bzw. weitere Werkzeuge nötig.
- Teile von B-14 (Querformat), B-16 (Neustart-Persistenz), B-18 (App-Umschalter) nicht einzeln belegt.
