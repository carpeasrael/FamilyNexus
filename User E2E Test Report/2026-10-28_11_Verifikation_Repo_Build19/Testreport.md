# Testreport Verifikation App Review 1.2.1 (Teillauf ohne Gerät)

Plan: TP-FN-VR-121 v1.0 @ `6275b3e` · Soll-Build 1.2.1 (19) · Datum 28.10.2026 · Ausführung: Claude Code (Dateisystem, Shell, `flutter test`)

## Zusammenfassung

**Gesamtergebnis: nicht bestanden – Lauf unvollständig (⏳).** Der Plan verlangt ein physisches iPhone (TestFlight), App Store Connect, Browser-Konten bei matrix.org, ein zweites Gerät und eine ungeschnittene Bildschirmaufnahme. Das lässt sich aus der Entwicklungsumgebung nicht ausführen. Geprüft wurden alle Schritte, die nur Repository, Code und Testsuite brauchen. Alles andere ist offen und muss vom Herausgeber/Tester ausgeführt werden. Die Antwort an App Review darf erst nach Abschluss der offenen Schritte abgeschickt werden (Plan Abschnitt 9).

| Ergebnis | Anzahl | Schritte |
|---|---|---|
| ✅ bestanden | 8 | V-01, F-03, T-01, T-06, T-09, P-03 (Stichprobe en-US 6,3″), P-04, H-05 |
| ⚠️ Befund | 3 | H-01, T-08, T-10 |
| ⏳ offen (Gerät/ASC/Konten nötig) | alle übrigen | V-02–V-14, S-01–S-15, K-01–K-09, F-01, F-02, F-04–F-06, T-02, T-03, T-04, T-05, T-07, P-01, P-02, P-05, H-02–H-04, H-06 |

## Abschnitt 2 – Festlegung

| Angabe | Wert |
|---|---|
| G1/G2/G3, iOS-/macOS-Version, Plattformen in ASC, Build in ASC, TestFlight, Prüfkonten, W1 | ⏳ nicht festlegbar ohne Geräte/ASC (Tester) |
| Soll-Build | 1.2.1+19 (V-01) |
| Tester / Datum | Claude Code, 28.10.2026, nur Repo-Prüfungen |

## Abschnitt 3 – Vorbereitung

| ID | Beobachtet | Nachweis | Erg. |
|---|---|---|---|
| V-01 | `main` = `origin/main`, Commit `6275b3e`, sauber. `pubspec.yaml`: `1.2.1+19`; `app_version.dart`: `appVersion = '1.2.1'`, `appBuild = '19'` → stimmen überein | `logs/V-01.log` | ✅ |
| V-02 bis V-14 | Benötigen App Store Connect, physisches iPhone, zweites Gerät, matrix.org-Konten, Test-Postfach. Nicht ausführbar | – | ⏳ |

## Abschnitt 4 – Bildschirmaufnahme

S-01 bis S-15 und K-01 bis K-09: ⏳ Es gibt keine Aufnahme. Ein Video vom Simulator wäre laut Plan unzulässig (physisches Gerät, K-04) und hätte Passwörter/Konten des Herausgebers gebraucht. Das Drehbuch (Plan 4.1) ist unverändert gültig.

## Abschnitt 5 – Funktionsprüfung

| ID | Beobachtet | Nachweis | Erg. |
|---|---|---|---|
| F-01 | Gesamtplan TP-FN-001 braucht physisches iPhone + Mac. Letzter Lauf Nr. 10 (Build 19, Simulator) ist kein Ersatz | – | ⏳ |
| F-02 | Review-Notizen am Gerät mit dem Text aus ASC: nicht ausführbar | – | ⏳ |
| F-03 | `flutter test test/store/review_notes_test.dart`: 4 Tests, „All tests passed!“ (ios und macos: Beschriftungen stehen in der App; keine überholten Aussagen; Grenze eingehalten) | `logs/F-03.log` | ✅ |
| F-04, F-05, F-06 | TestFlight/Organizer, Flugmodus, Gerätesprachen: Gerät nötig | – | ⏳ |

## Abschnitt 6 – Antworttexte

| ID | Prüfung / Beobachtet | Erg. |
|---|---|---|
| T-01 | `description.txt` (en-US) nennt: Kalender, Chat, Einkaufsliste, Sicherheit, Familie. Anhang A nennt dieselben Funktionen plus „recurring task lists“. Im `lib` kein Treffer für „nextcloud“ → kein Familienspeicher angekündigt oder vorhanden. Aufgabenlisten sind in `review_notes` (Menü → Tasks) und im Drehbuch (S-06) belegt; im Build-Test (F-01) noch zu bestätigen | ✅ |
| T-02 | Altersfreigabe-Wert steht nur in App Store Connect (`docs/STORE.md` Z. 66 nennt nur den Fragebogen). Abgleich mit ASC und Hinweistext in der App offen | ⏳ |
| T-03, T-04, T-05 | Setzt F-02, S-09, V-07, V-09 voraus. Inhaltlich stimmen die Schritte in Anhang A mit `review_notes.txt` (en) überein; Beschriftungen prüft F-03 maschinell | ⏳ |
| T-06 | Abhängigkeiten: nur Matrix-SDK, Vodozemac, SQLCipher, lokale Mitteilungen, Keychain, `local_auth`, `url_launcher`, `http` – keine Push-, Analyse-, Werbe-, Zahlungs-, KI-Pakete. URLs in `lib`: `carpeasrael.github.io/FamilyNexus/` (+ `/join/`), `element.io/download`, `matrix.org`. Suchtreffer (6) sind ausschließlich Texte der Art „no telemetry, no ads, no analytics“ in den Übersetzungen, kein Code. Liste in Anhang A (Matrix-Server inkl. account.matrix.org, GitHub Pages, Apple-Systemdienste) ist vollständig. Hinweis: „Element-Downloadseite“ fehlt in Anhang A (nur Verweis, Plan T-06 nennt sie) → ergänzen | ✅ (mit Ergänzung) |
| T-07 | Netzwerkgegenprobe braucht Gerät/Proxy | ⏳ |
| T-08 | Frankreich: `docs/export-compliance/README.md` hat Entscheidung A/B (Frankreich aus Verfügbarkeit nehmen oder französische Erklärung abgeben). Welche Option umgesetzt ist, steht nur in ASC → der Platzhalter `<IF APPLICABLE …>` in Anhang A kann noch nicht entschieden werden. F-06 offen | ⚠️ |
| T-09 | Kein Gesundheits-, Finanz-, Glücksspiel-, Behörden-Bezug; keine Musik/Videos/Marken Dritter in Beschreibung und Screenshots; Entwurf sagt das ausdrücklich; Verweis auf Exportunterlagen (`docs/export-compliance/`) und AGPL-3.0 vorhanden. Kinder-Kategorie: nicht gewählt laut Beschreibung (in ASC gegenprüfen) | ✅ |
| T-10 | `docs/OFFEN.md` Z. 103: AGPL-3.0 ↔ App-Store-Bedingungen „rechtlich zu klären“ (ggf. Ausnahme der Rechteinhaber oder Vertrieb nur außerhalb App Store). **Keine dokumentierte Entscheidung des Herausgebers.** Anhang A behauptet „free software under AGPL-3.0“ – das passt, die Frage der Vereinbarkeit bleibt aber offen | ⚠️ |

## Abschnitt 7 – Prevent Common Issues

| ID | Beobachtet | Nachweis | Erg. |
|---|---|---|---|
| P-01, P-02, P-05 | Echtgerät, ASC-Zugangsdaten, Vertriebsweg: nicht prüfbar | – | ⏳ |
| P-03 | Stichprobe `store/screenshots/ios/en-US/1206x2622` (6,3″): Kalender, Heute, Chat, Einkauf, Familie zeigen die App im Gebrauch; kein Titelbild/Startbildschirm/Anmeldeseite; Tabs Today/Calendar/Chat/Shopping/Family entsprechen den Review-Notizen. Nicht geprüft: 6,9″, de-DE, `04-einzelchat`, Abgleich mit dem tatsächlichen Build (Simulatorstand, laut `docs/OFFEN.md` Beispieldaten) | `screenshots/P-03_en-US_uebersicht.png` | ✅ (Stichprobe) |
| P-04 | `grep 'in_app_purchase\|StoreKit' lib ios macos pubspec.yaml`: 0 Treffer. Preis in ASC offen (Notiz) | `logs/P-04.log` | ✅ |

## Abschnitt 8 – Hinterlegen

| ID | Beobachtet | Erg. |
|---|---|---|
| H-01 | `review_notes.txt` (DE+EN) = 3519 Zeichen; englischer Teil allein 2074. Anhang A (vollständig) hat 3175 Zeichen. **EN-Notizen + vollständiger Anhang A = ca. 5250 > 4000.** Lösung: Kurzfassung (1358 Zeichen, `Notizen_Kurzfassung_Anhang_A.txt`) und zusammengeführter Text `Notizen_ASC_einsatzfertig.txt` (3431 Zeichen mit Platzhaltern; mit echten Zugangsdaten, Schlüsseln und Build-Nummer geschätzt unter 3700). Endgültige Zählung mit `wc -m` nach dem Einsetzen offen | ⚠️ |
| H-05 | `review_notes_test` grün (F-03); Platzhalter `<EMERGENCY KEY OF THE REVIEW ACCOUNT>` steht im Repository | ✅ |
| H-02, H-03, H-04, H-06 | ASC, Video, Checkliste: nicht ausführbar | ⏳ |

## Befunde und nächste Schritte

1. **Hauptsache offen:** Video auf iPhone (Abschnitt 4), F-01/F-02/F-04–F-06 und alle Konten-/ASC-Schritte brauchen den Herausgeber. Reihenfolge: V-02–V-14 → S-01–S-15 → K-01–K-09 → F-* → T-02/T-03/T-04/T-07 → P-01/P-02/P-05 → H-*.
2. **H-01:** erledigt: Kurzfassung und zusammengeführter Notizentext liegen vor; Platzhalter (Build, R2-Zugang, Notfall-Schlüssel, Länder) lokal ersetzen, dann `wc -m` ≤ 4000.
3. **T-06:** erledigt: Element-Downloadseite in Anhang A (Testplan) und Kurzfassung ergänzt.
4. **T-08/T-10:** Entscheidung zu Frankreich und zur AGPL/App-Store-Vereinbarkeit dokumentieren, dann Platzhalter in Anhang A füllen.
5. **Nicht verändert:** Testplan, Review-Notizen und Code wurden nicht angepasst.

## Anlagen

- `logs/V-01.log`, `logs/F-03.log`, `logs/T-06.log`, `logs/P-04.log`, `logs/H-01.log`
- `screenshots/P-03_en-US_uebersicht.png` (Stichprobe Store-Screenshots)
- `Notizen_Kurzfassung_Anhang_A.txt`, `Notizen_ASC_einsatzfertig.txt` (Notizenfeld, mit Platzhaltern, ohne Geheimnisse)
- `Antwort_App_Review.md`: nicht erstellt, da die Antwort noch nicht abgeschickt werden darf.
