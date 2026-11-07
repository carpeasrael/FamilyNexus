# Testreport Lauf 23: Default-Test G1–G2 in der Sandbox (gestoppt)

| Angabe | Wert |
|---|---|
| Plan | `TP-FN-DEF-G1G2` v03 (`User E2E Test/Default_test_G1-G2/`) |
| Stand / Build | `main` @ `7f15e8b`, FamilyNexus 1.2.2 (26), Release-APK mit Debug-Signatur |
| G1 | Sandbox-AVD `FN_E2E_G1`, Android-Telefon (Pixel 8, API 36) |
| G2 | Sandbox-AVD `FN_E2E_G2`, Android-Tablet (Pixel Tablet, API 36) |
| Zeit | 06.11.2026, 22:53–23:20 |
| Ergebnis | **Gestoppt auf Wunsch des Nutzers** nach DT-A-04 (App kehrt nach der Zustimmung bei matrix.org nicht zurück) |
| PDF | [Testreport_2026-11-06_23_Default-G1-G2_And-AndT_Build26_DE.pdf](Testreport_2026-11-06_23_Default-G1-G2_And-AndT_Build26_DE.pdf) |

## Zählung

6 ✅ (DT-V-01, DT-V-02, DT-V-03, DT-V-05, DT-A-01, DT-A-02) · 2 ⚠️ (DT-A-03, DT-N-01) · 2 ❌ (DT-A-04, DT-N-03) · 42 ⏳ (davon DT-F-08 mit Belegen der Aufräum-Löschung) · 0 n/a

## Abnahmekriterien

AK-1: ❌ (DT-A-04). AK-2 bis AK-8: ⏳ nicht belegt.

## Konten bei matrix.org

- N1 `@fnx-e2e-261106-n1-3996:matrix.org`: angelegt 23:09 (Captcha durch den Nutzer, Code per IMAP), **gelöscht 23:14** über die Kontoseite; neue Anmeldung mit richtigem Passwort um 23:17 abgewiesen („Account deleted“).
- I2 `@fnx-e2e-261106-i2-3996:matrix.org`: nie angelegt (Profil 404).

## Befunde

| ID | Schritt | Schwere | Beschreibung |
|---|---|---|---|
| L23-1 | DT-A-04 | hoch (Ursache offen) | Nach „Continue to FamilyNexus?“ kehrt die App nicht zurück; Custom Tab bleibt auf der Zustimmungsseite. Auf echtem Android-Gerät nachstellen, bevor ein Issue entsteht. |
| L23-2 | DT-A-03 | gering (Umgebung) | Chrome im Sandbox-Emulator (2,5 GB RAM) nach dem Captcha beendet. |
| L23-3 | DT-A-03 | mittel (Werkzeug, behoben) | `cdp.py fields` gab Passwortwerte aus; behoben, Passwort vor der Kontoanlage ersetzt. |
| L23-4 | DT-V-02 | gering (Werkzeug, behoben) | `sandbox.sh shot` scheiterte an Leerzeichen im Pfad; behoben. |
| L23-5 | DT-A-03 | gering (Werkzeug) | Skript-Klicks schicken Formulare von matrix.org nicht ab; `requestSubmit()` bzw. Fingertipp nötig. |
| L23-6 | DT-N-03 | gering (Planfehler) | Profil eines gelöschten matrix.org-Kontos bleibt lesbar; DT-N-03 als Nachweis ungeeignet. |

## Sandbox

Nach dem Lauf beendet, Nutzerdaten der AVDs und Arbeitsordner gelöscht; Nutzerumgebung unberührt. Geheimnisprüfung über den Lauf-Ordner: 0 Treffer.
