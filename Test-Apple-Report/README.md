# Testreports FamilyNexus

Ein Ordner je Testlauf, chronologisch nach Beginn des Laufs benannt:

`<JJJJ-MM-TT>_<NN>_<G1>-<G2>_Build<NN>`

- `JJJJ-MM-TT`: Tag, an dem der Lauf begann
- `NN`: laufende Nummer über alle Läufe (01, 02, …)
- `<G1>-<G2>`: Plattformen von Gerät 1 und Gerät 2 (bei Teilplänen davor der Plan, z. B. `Pruefanleitung`)
- `Build<NN>`: getestete Build-Nummer der App

Im Ordner: `Testreport.md` (Kurzfassung), PDFs als `Testreport_<Ordner>_DE.pdf` bzw. `_EN.pdf`, Bilder in `screenshots/`, Konsolenausgaben in `logs/`, ggf. `Ergebnisse.md` und `results.json` (Rohdaten).

| Nr. | Ordner | Lauf | Plan | Build | G1 / G2 |
|---|---|---|---|---|---|
| 01 | `2026-10-26_01_Pruefanleitung_Android-Android_Build16` | 26.10.2026, 19:53–20:22 | `Testplan_Pruefanleitung.md` @ `fc7d72b` (abgelöst) | 1.2.1 (16) | Android-Emulator / Android-Emulator |
| 02 | `2026-10-26_02_Nutzeranlage_macOS_Build16` | 26.10.2026, 20:15–20:50 | `Testplan_Nutzeranlage.md` (abgelöst) | 1.2.1 (16) | macOS |
| 03 | `2026-10-26_03_iOS-macOS_Build16` | 26.10.2026, 21:15–22:15 (im Plan „Lauf 1“) | TP-FN-001 v1.0 @ `4abf400` | 1.2.1 (16) | iPhone-15-Simulator / macOS |
| 04 | `2026-10-26_04_Linux-Android_Build16` | 26./27.10.2026, 22:16–00:50 (im Plan „Lauf 3“) | TP-FN-001 v1.0 @ `4abf400` | 1.2.1 (16) | Linux-Flatpak / Android-Emulator |
| 05 | `2026-10-26_05_iOS-macOS_Build16` | 26./27.10.2026, 22:50–00:35 (im Plan „Lauf 2“) | TP-FN-001 v1.2 @ `d6cecbf` | 1.2.1 (16) | iPhone-15-Simulator / macOS |
| 06 | `2026-10-27_06_iOS-macOS_Build17` | 27.10.2026, 20:40–23:25, Nachlauf 28.10. | TP-FN-001 v1.5 @ `7159ddc` | 1.2.1 (17) | iPhone-15-Simulator / macOS |
| 07 | `2026-10-28_07_iOS-macOS_Build18` | 28.10.2026, 00:50–ca. 08:35 (zwei Läufe) | TP-FN-001 v1.5 | 1.2.1 (18) | iPhone-15-Simulator / macOS, dann getauscht |
| 08 | `2026-10-28_08_Android-Linux_Build18` | 28.10.2026, 06:49–08:34 | TP-FN-001 v1.5 @ `423a3db` | 1.2.1 (18) | Android-Emulator / Linux-Flatpak |
| 09 | `2026-10-28_09_Linux-Android_Build18` | 28.10.2026, 08:34–09:58 | TP-FN-001 v1.5 @ `423a3db` | 1.2.1 (18) | Linux-Flatpak / Android-Emulator |
| 10 | `2026-10-28_10_Windows-nur-G1_Build19` | 28.10.2026, ca. 22:10–00:10 (nur G1-Schritte) | TP-FN-001 v1.6 @ `f4c358c` | 1.2.1 (19), lokaler Build mit Startkorrektur | Windows 11 / – (G2 nicht verfügbar) |

Die Läufe 04 und 05 liefen parallel; die Nummer folgt dem Beginn. Die Bezeichnungen „Lauf 1/2/3“ im Testplan (Anhang E, Issue-Zuordnung) entsprechen den Nummern 03, 05 und 04.

Testpläne: `../Test-Apple/README.md`.
