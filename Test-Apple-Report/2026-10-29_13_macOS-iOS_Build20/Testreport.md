# Testreport TP-FN-001 v1.7 @ 5469f8d – Lauf 13 – Build 1.2.1 (20) – Teilplan Nachtest

**Datum:** 29.10.2026, Beginn: ____ Uhr. **Tester:** ____. Datumsteil der Konten: ____ (nach V-06 frei).
**Umfang:** Nachtest der Schritte E-18 (#77), E-23 (#76), D-02 (#75), E-07/E-12 (#59), B-02/B-10 (#57) gegen den Testserver. Die übrigen Schritte des Plans sind nicht Teil dieses Laufs. Konten und Familie entstehen nach Plan (A-09, A-11, D-01, E-09) und werden am Ende nach F aufgeräumt.

## Abschnitt 2: Plattform und System

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | | |
| Gerät oder Simulator | | |
| Betriebssystem und Version | | |
| Installationsquelle | TestFlight (Mac: Distribution-Signatur, V-02) | |
| App-Version Soll / Ist | 1.2.1 (20) / 1.2.1 (20) (Mac, vorab geprüft) | 1.2.1 (20) / |
| Gerätesprache, Bildschirmsperre | | |
| Methode für Screenshots | | |

Vorab geprüft (29.10.2026): `/Applications/FamilyNexus.app` ist Version 1.2.1 (20), Signatur „TestFlight Beta Distribution“, Team `LWGTDX5B34`.

## Vorbereitung

| ID | Ergebnis | Beobachtet |
|---|---|---|
| V-01 Soll-Version | ✅ | `main` @ 5469f8d, `pubspec.yaml` 1.2.1+20 |
| V-02 Ist-Version G1 (Mac) | ✅ | 1.2.1 (20), TestFlight-Signatur |
| V-02 Ist-Version G2 | ⏳ | |
| V-04 Lokale Daten gelöscht | ⏳ | |
| V-05 Server erreichbar, Registrierung offen | ⏳ | |
| V-06 Benutzernamen frei | ⏳ | |

## Testschritte

Beim Eintragen die Spalten „Beobachtet“, „Screenshot“, „Erg.“ füllen. Ergebnisse: ✅ bestanden · ⚠️ mit Befund · ❌ fehlgeschlagen · ⏳ offen (mit Grund) · n/a.

| ID | Gerät | Schritt (Kurzform, Wortlaut im Plan v1.7) | Erwartet | Beobachtet | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| B-02 | G1 (Mac) | Hinweis „Benachrichtigungen sind blockiert“ → „Erlauben“ | Mit Distribution-Signatur erscheint der Systemdialog; nach „Erlauben“ ist der Hinweis weg. Ohne Dialog: „Einstellungen öffnen“ (#57). Signatur im Report nennen. | | B-02a-G1, B-02b-G1 | |
| B-10 | G1 (Mac) | Termin in 12 Minuten, Standard-Erinnerung 10 Minuten, App im Hintergrund | Nach ca. 2 Minuten Systembenachrichtigung „Termin in 10 Minuten“, ohne Titel und Ort (#57) | | B-10-G1 | |
| D-02 | G1, G2 | Familien-Code kopieren, G2 tritt per Code bei, G1 lehnt ab | G2 zeigt „Deine Anfrage wurde abgelehnt. …“ spätestens nach ca. 20 s. **Dauer in Sekunden notieren**; länger = ⚠️ (#75). | Dauer: ____ s | D-02a-G1 … D-02d-G2 | |
| E-07 | G2 | Vollständigen Einladungslink einfügen und über das System öffnen (`open '<Link>'` bzw. `xcrun simctl openurl booted '<Link>'`); zusätzlich Variante `familynexus://join#…` | Beitrittskarte „Details“ mit der richtigen Familie; Link mit `#` wird angenommen, nicht „unvollständig oder beschädigt“ (#59) | | E-07a-G2, E-07b-G2 | |
| E-12 | G2 | Verbrauchten Link über das System öffnen (Mac: `open -a FamilyNexus 'https://carpeasrael.github.io/FamilyNexus/join/#…'`) | Der Link erreicht die App; Meldung „Du bist bereits in einer Familie.“ (#59) | | E-12-G2 | |
| E-18 | G1, G2 | G1: „Nachricht schreiben“ bei Test Nutzer 2, `Nur für dich` senden; G2 öffnet den Reiter „Test N1“ | Die Nachricht steht sofort (nach wenigen Sekunden) im Einzelchat, **ohne Reiterwechsel**; zeigt er zuerst „Keine Nachricht“ → ⚠️ (#77). Zeitpunkt notieren. | | E-18a-G1, E-18b-G2 | |
| E-23 | G1, G2 | `Müll rausbringen` für Test Nutzer 2, „Täglich“ → „Montag bis Freitag (ohne Wochenende)“; **Auswahl vor dem Speichern aufnehmen** | Liste zeigt „Mo–Fr“ und die Regel „Montag bis Freitag“, nicht „Täglich“ (#76); G2 hakt ab, Verlauf `TT.MM.JJJJ` | | E-23a-G1 … E-23c-G1 | |

Reihenfolge nach Plan: B-02/B-10 (A bis B), D-02, E-07 bis E-12, E-18, E-23. Das Konto I2 entsteht in E-09; E-12 braucht den in E-05 erzeugten, in E-11 verbrauchten Link.

## Zusammenfassung

Schritte gesamt: 7 · ✅ 0, ⚠️ 0, ❌ 0, ⏳ 7

## Befunde

| Nr. | Schwere | Schritt | Beschreibung |
|---|---|---|---|
| | | | |

## Zuordnung zu Issues

| Issue | Schritt | Folge bei ✅ | Folge bei ⚠️/❌ |
|---|---|---|---|
| #57 | B-02, B-10 | dokumentieren und schließen | Beobachtung (Dialog, Signatur) am Issue, offen |
| #59 | E-07, E-12 | dokumentieren und schließen | Fehlermeldung wörtlich am Issue, offen |
| #75 | D-02 | dokumentieren und schließen | Dauer und, falls möglich, Log aus einem `flutter run`-Build am Issue, offen |
| #76 | E-23 | dokumentieren und schließen | Aufnahme der Auswahl und Anzeige am Issue, offen |
| #77 | E-18 | dokumentieren und schließen | Ablauf und Zeitpunkt am Issue, offen |
