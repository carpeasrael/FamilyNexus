# Testreport Lauf 22: Default-Test G1–G2 (abgebrochen)

| Angabe | Wert |
|---|---|
| Plan | `TP-FN-DEF-G1G2` v02 (`User E2E Test/Default_test_G1-G2/`) |
| Stand / Build | `main` @ `7f15e8b`, FamilyNexus 1.2.2 (26) |
| G1 | Linux-Flatpak auf eigenem X-Server (Xvfb :99), Agent per XTEST; Anbieter-Seite im Desktop-Browser des Nutzers |
| G2 | Android-Emulator `Pixel_8_API_36` (nicht mehr erreicht) |
| Zeit | 06.11.2026, 22:19–22:31 |
| Ergebnis | **Abgebrochen auf Wunsch des Nutzers** während DT-A-03 (Kontoanlage bei matrix.org) |
| PDF | [Testreport_2026-11-06_22_Default-G1-G2_Lin-And_Build26_DE.pdf](Testreport_2026-11-06_22_Default-G1-G2_Lin-And_Build26_DE.pdf) |

## Zählung

4 ✅ (DT-V-01, DT-V-02, DT-V-05, DT-A-01) · 1 ⚠️ (DT-A-02: Bild der Anbieter-Seite fehlt) · 0 ❌ · 47 ⏳ (abgebrochen) · 0 n/a

## Abnahmekriterien

AK-1 bis AK-8: ⏳ nicht belegt (Lauf abgebrochen).

## Konten bei matrix.org

Keine angelegt: Bis 22:28 keine Bestätigungsmail bei `app_test@inneso.de` (INBOX und Spam); um 22:32 lieferte die Profilabfrage für beide geplanten Matrix-IDs `404` „No row found (profiles)“. Nichts zu löschen.

## Folgerung

Die Anbieter-Seite öffnet unter Linux im Desktop-Browser des Nutzers und lässt sich dort nicht selbstständig bedienen. Plan v03 führt den Test deshalb in einer Sandbox aus zwei eigenen Android-Emulatoren durch; der Agent legt die Konten dort selbst an.
