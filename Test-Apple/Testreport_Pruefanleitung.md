# Testreport Prüfanleitung (Maßnahme 6)

Plan: `Testplan_Pruefanleitung.md` · Build: FamilyNexus 1.2.1 (Build 14), Commit `9315067` · Durchgeführt: 25.10.2026

## 1. Zusammenfassung

**Gesamtergebnis: nicht freigabefähig.** Die automatisch prüfbaren Teile bestehen, aber:

- Alle Schritte, die ein **physisches Gerät** und das **Prüfkonto** brauchen, sind ⏳ offen. Sie wurden nicht durchgeführt, ein Gerät und ein Prüfkonto standen in dieser Sitzung nicht zur Verfügung.
- Die Review-Notizen weichen an zwei Stellen von der App ab (B-1, B-2), und ein Prüfpunkt von Apple ist nicht erfüllt (B-4).

Die Bildschirmfotos stammen **nicht vom Gerät**. Sie sind gerendert (Fake-Matrix, Beispieldaten, 390 × 844 dp) bzw. aus den Store-Bildern übernommen. Sie belegen Texte und Reihenfolge, nicht das Verhalten auf einem Gerät. Als Nachweis für Apple taugen sie nicht.

## 2. Ergebnisse je Testfall

| ID | Ergebnis | Befund / Beleg | Screenshot |
|---|---|---|---|
| TC-01 Start mit drei Wegen | ✅ (R) · ⏳ (G) | Drei Wege „Neue Familie gründen / Ich wurde eingeladen / Ich habe schon ein Konto“ vorhanden. **Kein Schritt „Sprache“ in dieser Form**, siehe B-1 | `screenshots/onboarding/01-start.png` |
| TC-02 Englisch | ✅ (R) · ⏳ (G) | Umschaltung vorhanden | `onboarding/24-start-englisch.png` |
| TC-03 Anmelden-Maske | ✅ (R) · ⏳ (G) | „Schritt 1 von 3“, Benutzername, Passwort mit Auge, „Dein Konto liegt bei …“ (automatisch geprüft), „Erweitert“ | `onboarding/20-anmelden.png` |
| TC-04 Anmeldung Prüfkonto | ⏳ | Prüfkonto fehlt (B-3) | – |
| TC-05 Browser-Anmeldung (OAuth) | ✅ (R) · ⏳ (G) | Masken „Konto erstellen“ und „Warten auf Browser“ vorhanden; Rücksprung nur auf Gerät prüfbar | `onboarding/22-oauth-konto-erstellen.png`, `23-oauth-wartet-auf-browser.png` |
| TC-06 Gerät freischalten | ✅ (R) · ⏳ (G) | „Dieses Gerät freischalten“, „Schritt 2 von 3“, Feld „Notfall-Schlüssel“, Knopf „Freischalten“ | `onboarding/21-geraet-freischalten.png` |
| TC-07 Heute | ✅ (S) · ⏳ (G) | Nächste Termine, Erinnerungen, „Wer ist online“, Einkaufszettel, Leiste Heute/Kalender/Chat/Einkauf/Familie | `hauptfunktionen/1-heute.png` |
| TC-08 Kalender | ✅ (S) · ⏳ (G) | Ansicht vorhanden | `hauptfunktionen/2-kalender.png` |
| TC-09 Chat/Einzelchat | ✅ (S) · ⏳ (G) | Ansicht vorhanden | `hauptfunktionen/3-chat.png`, `4-einzelchat.png` |
| TC-10 Einkauf | ✅ (S) · ⏳ (G) | Ansicht vorhanden | `hauptfunktionen/5-einkauf.png` |
| TC-11 Melden/Blockieren | ⚠️ (T) · ⏳ (G) | Texte „Nachricht melden“, „{name} blockieren“, „Absender blockieren“ vorhanden (`app_de.arb`); Weg stimmt mit Notizen überein; Ausführung auf Gerät offen | `hauptfunktionen/6-familie.png` |
| TC-12 Konto in der App anlegen | ✅ (R) · ⏳ (G) | Weg vorhanden (Benutzername, Passwort, Notfall-Schlüssel, Familie benennen, Einladen); **in den Notizen nicht erwähnt oder widersprochen**, siehe B-2 | `onboarding/02`–`19` |
| TC-13 Kontolöschung | ❌ | Nur „Alle lokalen Daten löschen“; Konto beim Server bleibt bestehen (`app_de.arb` `deleteDataBody`, `docs/OFFEN.md`). Siehe B-4 | – |
| TC-14 Person ohne Vorwissen | ⏳ | Nicht durchgeführt; setzt Prüfkonto und Gerät voraus | – |
| TC-15 Konsistenz Notizen ↔ App | ❌ | B-1, B-2 | – |
| TC-16 Testsuite | ✅ | `flutter test`: 699 bestanden, 41 übersprungen, 0 Fehler. Bildschirmfoto-Lauf: 4 Tests bestanden, 24 Bilder erzeugt | – |

## 3. Befunde

| # | Schwere | Befund | Empfohlene Maßnahme |
|---|---|---|---|
| B-1 | mittel | Notizen nennen den Ablauf „Sprache → Server (matrix.org belassen) → Anmeldung → Gerät verifizieren → Hauptansicht“. Die App zeigt zuerst „Willkommen“ mit drei Wegen. Der Server wird automatisch geprüft („Dein Konto liegt bei …“), ein eigener Server-Schritt entfällt; er liegt unter „Erweitert“. Die Anmeldung läuft als „Schritt 1 von 3“ | Ablauf in `store/metadata/{ios,macos}/review_notes.txt` neu nummeriert an den echten Bildschirmen ausrichten |
| B-2 | **hoch** | Notizen behaupten „Es werden keine Konten in der App angelegt.“ Die App legt Konten an („Neue Familie gründen“, „Noch kein Konto? Jetzt erstellen“). Apple prüft darauf | Aussage streichen, Kontoerstellung beschreiben; dasselbe in `docs/STORE.md` Punkt 7 korrigieren |
| B-3 | hoch | Kein Prüfkonto mit Wiederherstellungsschlüssel und Beispieldaten nachweisbar hinterlegt (`docs/STORE.md`, Punkt 1.6 offen) | Konto auf matrix.org anlegen, Familie mit Beispieldaten und zweitem Mitglied einrichten, Zugangsdaten und Schlüssel in App Store Connect hinterlegen |
| B-4 | **hoch** | Keine Kontolöschung in der App. Apple 5.1.1 (v) verlangt sie, sobald Konten in der App angelegt werden können. `docs/STORE.md` begründet „nicht anwendbar“ mit der inzwischen überholten Aussage aus B-2 | Entscheidung: Kontolöschung (Matrix `deactivate`) umsetzen oder bei Kontoanlage über den Anbieter im Browser auf dessen Löschfunktion verweisen und mit Apple begründen; danach TC-13 wiederholen |
| B-5 | niedrig | Der Testplan-Schritt „Person ohne Vorwissen“ ist ohne Prüfkonto nicht ausführbar | nach B-3 durchführen |

## 4. Noch durchzuführen (auf Gerät, mit Prüfkonto)

TC-01 bis TC-14 auf iPhone und Mac mit aktueller Betriebssystemversion, mit eigenen Bildschirmfotos vom Gerät unter `screenshots/geraet/`. Dabei Gerät, Betriebssystem, Version und Build eintragen:

| Gerät | OS-Version | Version/Build | Datum | Tester |
|---|---|---|---|---|
| ⏳ | ⏳ | 1.2.1 (14) | ⏳ | ⏳ |

## 5. Ablage

- `Testplan_Pruefanleitung.md`, `Testreport_Pruefanleitung.md`
- `screenshots/onboarding/` – 24 gerenderte Bilder der Einrichtung (`tool/onboarding_screens.sh`)
- `screenshots/hauptfunktionen/` – 6 Store-Bilder (iPhone 6,9″, Beispieldaten)
