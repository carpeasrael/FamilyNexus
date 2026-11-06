# Testreport: Lauf 21, Release-Test 1.2.2 (v01), nur G1 (iPad-Air-13-Simulator), Build 24

Teillauf des Plans `Release-Test_1.2.2_v01.md` (TP-FN-REL-122) nur mit G1. G2 wurde nicht genutzt; alle Schritte, die ein zweites Gerät brauchen, sind ⏳. Einzelergebnisse: `Ergebnisse.tsv`, Belege: `screenshots/` (auf 1100 Pixel Höhe verkleinert), `logs/`.

## 1. Festlegung (Abschnitt 2 des Plans)

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | iPadOS-Simulator | nicht genutzt |
| Gerät | iPad Air 13-inch (M4), Simulator-ID 537A7F28-0DBD-415D-A050-B85CA00694CD | – |
| Betriebssystem | iPadOS 27.2, Host macOS 27.2 | – |
| Installationsquelle | `flutter build ios --simulator --debug` auf Commit `079faa1` (Tag `v1.2.2`, App-Code identisch). **Nicht** die IPA aus der CI (Geräte-Build, im Simulator nicht lauffähig) | – |
| App-Version Soll / Ist | 1.2.2 (24) / 1.2.2 (24) (RT-V-01, RT-V-02) | – |
| Sprache, Uhrzeit | Gerätesprache Deutsch, 24-Stunden | – |
| Screenshots | `xcrun simctl io <Gerät> screenshot` | – |
| Bedienung | `cliclick` und AppleScript auf dem Device-Hub-Fenster; Text mit Großbuchstaben, Emojis und lange Texte über „Send Clipboard“ und „Einsetzen“ (Anhang D des Gesamtplans) | – |
| Server | lokaler Synapse (`tool/synapse/up.sh`) für die automatischen Tests; die App-Schritte liefen gegen den Testserver `matrix-synapse-3ues.srv1348446.hstgr.cloud` (Matrix-ID-Servername `matrix.chaostribunal.de`) | – |
| Datum | 06.11.2026, ca. 01:00 bis 01:40 | – |

Konto: `fnt-1106-n1` (Familie „Testfamilie 1106“), am Ende gelöscht (RT-O-01, RT-O-02). Passwort und Notfall-Schlüssel nur in `secure/Lauf_1106_G1.txt` (von Git ignoriert).

Abweichung von der empfohlenen Mindestabdeckung: nur iPad-Simulator, kein iPhone, Mac, Android, Windows, Linux, Web. Der Lauf ersetzt den Release-Test auf diesen Systemen nicht.

## 2. Ergebnis

| | ✅ | ⚠️ | ❌ | ⏳ | n/a |
|---|---|---|---|---|---|
| 125 Schritte | 38 | 12 | 0 | 48 | 27 |

Kein ❌. Die Zählung folgt `Ergebnisse.tsv`.

Je Abschnitt (✅ / ⚠️ / ⏳ / n/a, nach `Ergebnisse.tsv`):

| Abschnitt | ✅ | ⚠️ | ⏳ | n/a | Anmerkung |
|---|---|---|---|---|---|
| V | 2 | 0 | 1 | 0 | RT-V-03 nicht ausgeführt |
| A | 5 | 0 | 1 | 0 | RT-A-06 braucht G2 |
| B | 5 | 1 | 0 | 2 | RT-B-03 ⚠️; RT-B-07, B-08 n/a |
| C | 0 | 2 | 8 | 0 | RT-C-01, C-10 ⚠️; übrige brauchen G2 oder unterbrochenes Netz |
| D | 1 | 0 | 6 | 2 | RT-D-01 ✅; RT-D-02 ⏳ (Simulator), RT-D-03 bis D-07 G2 |
| E | 0 | 0 | 7 | 0 | alle G2 |
| F | 7 | 0 | 6 | 0 | RT-F-01 bis F-07 ✅; RT-F-08 bis F-13 ⏳ |
| G | 4 | 1 | 1 | 0 | RT-G-01 bis G-04 ✅, RT-G-06 ⚠️, RT-G-05 ⏳ (Web-Schritt) |
| H | 1 | 2 | 3 | 2 | RT-H-05 ✅; RT-H-01, H-08 ⚠️ |
| I | 0 | 0 | 6 | 0 | G2 bzw. Netzumgebung |
| J | 2 | 1 | 2 | 5 | RT-J-01, J-10 ✅; RT-J-02 ⚠️ |
| K | 0 | 0 | 0 | 8 | Web |
| L | 2 | 3 | 2 | 7 | RT-L-02, L-09 ✅; RT-L-01, L-03, L-10 ⚠️; RT-L-04, L-14 ⏳ |
| M | 2 | 1 | 2 | 0 | RT-M-01, M-02 ✅; RT-M-03 ⚠️ |
| N | 0 | 0 | 2 | 1 | Temp-Ordner nicht ausgeführt |
| O | 3 | 0 | 0 | 0 | |
| T (Abschnitt 12) | 4 | 1 | 1 | 0 | RT-T-02 ⚠️ (Umgebung), RT-T-06 nicht abgehakt |

## 3. Befunde und Auffälligkeiten

| Nr. | Schritt | Befund | Bewertung |
|---|---|---|---|
| 1 | RT-L-01 | Im Layout `expanded` (iPad Air 13", Hochformat 1032 pt und Querformat) steht der senkrechte Trenner (`home_shell.dart:219`, `Offstage(offstage: !twoPane, …)`) auf **allen** Tabs, auch auf Heute, Einkauf, Familie. Dort läuft eine feine Linie quer über die einspaltigen Karten. Der Plan (RT-L-02) erwartet den Trenner nur im Zweispalter Kalender/Chat. | **Neuer Befund (kosmetisch).** Noch kein Issue. Vorschlag: Issue nach Standardablauf; `twoPane` müsste mit dem aktiven Tab (Kalender oder Chat) verknüpft werden. |
| 2 | RT-H-08 | Zeitwähler auf dem iPad mit Hardware-Tastatur: Antippen des Stunden- oder Minutenfelds markiert den Wert nicht. Bei vollem Zwei-Ziffern-Feld werden getippte Ziffern verworfen; nach zweimal Löschen nimmt das Feld sie an (01:12 eingegeben). | Entspricht der in E-20 dokumentierten Grenze, die Planerwartung („Eingabe nimmt die Ziffern an“) ist ungenau. Plan anpassen. |
| 3 | RT-B-03 | Der erwartete Hinweis „Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.“ steht nicht in der Übersicht „Erinnerungen“, sondern in Einstellungen und im Termin-Editor. | Planerwartung ungenau. |
| 4 | RT-H-01 | Termin-Editor und Termin zeigen das Datum als „3. Nov. 2026“ (kurzer Monatsname, ohne führende Null). Das numerische Datum mit Null („03.11.2026“, #260) betrifft die Schlüsseldatei (Speichern-Dialog im Simulator nicht bedienbar). | Planerwartung ungenau für Editor und Detailansicht. |
| 5 | RT-C-10 | Das Chat-Limit liegt im Code bei 8000 Zeichen (`ChatMessage.maxBody`), der Plan nennt 4000. Gesendet wurden 4190 Zeichen mit Familien-Emoji (vollständig, keine Fehlermeldung) und 8100 eingefügte Zeichen (keine Fehlermeldung); ob auf 8000 begrenzt wurde, ist am Bild nicht nachweisbar. | Plan anpassen (8000); Begrenzung bei 8000 gesondert belegen. |
| 6 | RT-M-03 | Termin mit zusammengesetztem Emoji wird abgelehnt (E-33), aber nur mit „Der Termin konnte nicht gespeichert werden.“ ohne Hinweis auf das Emoji. | Planerwartung „mit Hinweis“ nur teilweise erfüllt. Ob ein genauerer Hinweis gewollt ist, entscheidet der Herausgeber. |
| 7 | RT-L-10 | Mit Systemschrift „Bedienungshilfen groß“ (nicht exakt 200 %): kein Layoutüberlauf. Kosmetisch: „Agenda“ im Kalender-Umschalter bricht zu „Agend/a“ um, „Datenschutzerklärung“ im Menü bricht um. | Beobachtung. Sperrbildschirm nicht prüfbar (Geräte-PIN fehlt). |
| 8 | RT-D-02 | Die Berechtigungsabfrage für Benachrichtigungen erscheint im Simulator nicht, weil die Entscheidung für `de.inneso.familynexus` aus früheren Läufen bleibt (`simctl privacy reset` ändert das nicht). | ⏳, nur auf einem frischen Gerät oder echtem iPhone prüfbar. |
| 9 | RT-T-02 | `test/data/app_badge_test.dart` scheitert auf macOS (D-Bus-Socket), sonst alles grün. | Bekannte Umgebung, kein App-Fehler. |
| 10 | Lauf | Der Screenshot `RT-F-03_iPad.png` zeigt beide Passwörter im Klartext (Augensymbol) und wurde deshalb **nicht** in den Report übernommen. Der Notfall-Schlüssel wurde nie als Bild abgelegt. | Nur Hinweis. |
| 11 | RT-L-01 | Auf dem iPad läuft die App zunächst als schmales Fenster im Stage-Manager-Stil (ca. 40 % Breite). Erst nach dem grünen Fensterknopf füllt sie den Bildschirm (1032 × 1376 im Hochformat). | Beobachtung wie in Lauf 20 (Befund 3). Prüfen, ob das gewollt ist. |

## 4. Wichtigste Belege

- **Version (RT-V-01, V-02):** `pubspec.yaml` 1.2.2+24 auf Stand `079faa1`; Menüfuß und „Über die App“ zeigen „Version 1.2.2 (24)“.
- **Konto und Passwörter (RT-F-01 bis F-07):** Meldungen „Die Passwörter stimmen nicht überein.“, „Das Passwort braucht mindestens 8 Zeichen.“, „Das aktuelle Passwort stimmt nicht.“, „Das neue Passwort muss sich vom aktuellen unterscheiden.“, „Passwort geändert.“ wie erwartet.
- **Anbieter-Adresse (RT-G-01 bis G-04):** Server, Speicherorte, „Konto löschen?“ nennen die eingegebene Anbieter-Adresse; der aufgelöste Homeserver steht nur im lokalen Protokoll, dort auch „Anzeigename: Test N1“.
- **Einkauf (RT-A-01 bis A-05):** Gruppen „Baumarkt“, „Supermarkt“, „Ohne Gruppe“, Vorschläge, Abhaken, Gruppe ändern.
- **Erinnerungen (RT-B-01 bis B-06):** 3 Termine auf „Heute“, Systemmeldung „Erinnerung / Termin in 0 Minuten“ ohne Titel und Ort (App im Hintergrund), Zähler fällig und geplant, Bestätigen, Fälligkeit bleibt nach hartem Beenden und Neustart.
- **Tablet (RT-L-02, L-03, L-09):** Rail plus Zweispalter Kalender/Chat in allen vier Ausrichtungen, Auswahl bleibt erhalten, Bildschirmtastatur kippt das Layout nicht.
- **Emojis (RT-M-01, M-02):** Einkaufstitel und Aufgabenpunkt mit zusammengesetztem Emoji gespeichert und vollständig angezeigt.
- **Aufräumen (RT-O-01, O-02):** Konto gelöscht, danach direkt „Willkommen“; API-Login mit dem Konto liefert `403 M_FORBIDDEN` (`logs/RT-O-02_login.txt`).
- **Automatisch (RT-T):** `flutter analyze` ohne Befund; `flutter test` 1853 bestanden, 1 Umgebungsfehler; Synapse bereit (200); `tool/e2e.sh` 104 bestanden; `wait_ready_test.sh` alle Fälle bestanden.

## 5. Nicht getestet (Gründe)

- **G2-Schritte (Chat, Beitritt, Meldungen, Familienwechsel):** RT-A-06, RT-C-02 bis C-09, RT-D-03 bis D-07, RT-E-01 bis E-07, RT-F-07 (Teil G2), RT-I-01 bis I-05. Dafür wäre ein zweiter Simulator oder ein Mac als G2 nötig.
- **matrix.org (RT-F-10 bis F-13):** nur mit ausdrücklicher Freigabe und eigenem Konto.
- **Geräte-PIN, Hardware-Tastatur, App-Umschalter, Split View, Slide Over, Stage Manager:** im Device Hub nicht bedienbar (RT-J-02 Teil „App-Umschalter“, RT-L-04). Auch **kein Test für B-17** und kein Test für #294 und #298 (App-Sperre).
- **Store-Screenshots (RT-L-14):** eigener Auftrag mit sauberen Daten (`docs/OFFEN.md`).
- **Übrige Plattformen:** Web (RT-K), Android, iPhone, Mac, Windows, Linux sind n/a oder ⏳ in diesem Lauf.
- **RT-V-03, RT-N-01 und RT-N-02, RT-T-06:** nicht ausgeführt bzw. nicht abgehakt (Gründe in `Ergebnisse.tsv`).

## 6. Freigabekriterien (Abschnitt 13 des Plans)

- Kein ❌ in A bis K, M, N: **erfüllt** (nur für die ausgeführten Schritte).
- Alle ⚠️ begründet und verlinkt: **erfüllt** (Verweise in Abschnitt 3); #273 (RT-D-08) betrifft Android und wurde hier nicht geprüft.
- Abschnitt L auf iPad (RT-L-01 bis L-04) bestanden: **nicht erfüllt.** RT-L-01 und RT-L-03 sind ⚠️ (Befund 1), RT-L-04 ⏳. **#274 bleibt offen**, auch weil kein Android-Tablet geprüft wurde.
- Pflichtteil Abschnitt 12 grün bis auf die Umgebungsausnahme: **erfüllt**.
- **Gesamt:** Der Lauf belegt die geprüften iPad-Schritte, ist aber **keine Freigabe** des Release-Tests (G2, Android, Windows, Linux, Web, iPhone und Mac fehlen).
