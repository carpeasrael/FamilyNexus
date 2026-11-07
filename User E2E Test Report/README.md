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
| 11 | `2026-10-28_11_Verifikation_Repo_Build19` | 28.10.2026, Teillauf ohne Gerät | TP-FN-VR-121 v1.0 @ `6275b3e` | 1.2.1 (19) | nur Repository/Code, Geräteschritte offen |
| 12 | `2026-10-28_12_Windows-nur-G1_Build19` | 28.10.2026, ca. 22:10–00:10 (nur G1-Schritte) | TP-FN-001 v1.6 @ `f4c358c` | 1.2.1 (19), lokaler Build mit Startkorrektur | Windows 11 / – (G2 nicht verfügbar) |
| 13 | `2026-10-29_13_macOS-iOS_Build20` | 29./30.10.2026, vollständiger Plan (V, A–G) | TP-FN-001 v1.7 | 1.2.1 (20) | macOS / iPhone-17-Simulator (iOS 27.0) |
| 14 | `2026-10-30_14_macOS-iOS_Build21` | 30.10.2026, vollständiger Plan (V, A–G) | TP-FN-001 v1.7 | 1.2.1 (21) | macOS / iPhone-17-Simulator (iOS 27.0) |
| 15 | `2026-10-30_15_macOS-iOS_Build22` | 30.10.2026, Nachtest #103 (Teilplan V-04, A-03) | TP-FN-001 v1.7 | 1.2.1 (22) | macOS / iPhone-17-Simulator (iOS 27.0) |
| 16 | `2026-10-30_16_macOS-iOS_Build22` | 30.10.2026, 17:35–19:25, vollständiger Plan (V, A–H); 108 ✅, 6 ⚠️, 7 ⏳, 2 n/a | TP-FN-001 v1.8 @ `dddf22d` | 1.2.1 (22) | macOS / iPhone-17-Simulator (iOS 27.0) |
| 17 | `2026-10-30_17_iOS-macOS_Build22` | 30.10.2026, 20:40–22:35, vollständiger Plan (V, A–H), Rollen getauscht; 107 ✅, 7 ⚠️, 1 ❌ (D-02), 7 ⏳, 1 n/a | TP-FN-001 v1.8 @ `dddf22d` | 1.2.1 (22) | iPhone-17-Simulator (iOS 27.0) / macOS |
| 18 | `2026-11-03_18_Windows-nur-G1_Build23` | 03.11.2026, ca. 21:15-22:02 (nur G1-Schritte) | TP-FN-001 v1.20 @ `48e9299` | 1.2.2 (23), lokaler Build mit Bildschirmschutz-Voreinstellung aus | Windows 11 / - (G2 nicht verfuegbar) |
| 19 | `2026-11-02_Linux-Android_Build23_1.2.2` (Name nach Vorgabe des Nutzers; AURORA-Bericht als `.html`/`.pdf` daneben) | 02.11.2026, 20:56–23:35, vollständiger Plan (V, A–H), begann vor Lauf 18 und wurde später eingetragen; 116 ✅, 6 ⚠️, 0 ❌, 4 ⏳, 5 n/a | TP-FN-001 v1.20 @ `48e9299` | 1.2.2 (23), lokal gebaut | Linux-Flatpak / Android-Emulator (API 36) |
| 20 | `2026-11-04_20_iPadOS-nur-G1_Build23` | 04.11.2026, ca. 19:00–20:00 (nur G1-Schritte, G2 nicht genutzt); 43 ✅, 9 ⚠️, 0 ❌, 15 ⏳ (nach `Ergebnisse.tsv`) | TP-FN-001 v1.23 @ `4b931a2` | 1.2.2 (23), `flutter build ios --simulator --debug` | iPad-Air-13-Simulator (iPadOS 27.2) / - (G2 nicht genutzt) |
| 21 | `2026-11-06_21_Release-1.2.2_iPad-Air-nur-G1_Build24` | 06.11.2026, ca. 01:00–01:40 (Release-Test 1.2.2, nur G1, G2 nicht genutzt); 38 ✅, 12 ⚠️, 0 ❌, 48 ⏳, 27 n/a (nach `Ergebnisse.tsv`) | TP-FN-REL-122 v01 @ `079faa1` | 1.2.2 (24), `flutter build ios --simulator --debug` | iPad-Air-13-Simulator (iPadOS 27.2) / - (G2 nicht genutzt) |
| 22 | `2026-11-07_22_iOS-macOS-Simulator_Build26` | 07.11.2026 (Apple-Nachtests #144, #254, #266, #268, #274; iPhone-Simulator, macOS nur Teilbeleg); 2 bestanden, 1 Teilbeleg, 21 Simulator bestanden, 2 teilweise, 1 Beobachtung, 1 Umgebung, 9 nicht getestet (nach `Ergebnisse.tsv`) | `Checkliste_Geraetenachtests.md` @ `c9c300d` | 1.2.2 (26), `flutter build ios --simulator --debug` / `flutter build macos --debug` (Bundle-ID `.e2e`) | iPhone-17-Simulator (iOS 26.4) / macOS (Mac-Schlüsselbund-Abfrage, App nicht bedienbar) |
| 23 | `2026-11-07_23_macOS-iOS-Simulator_Build26` (AURORA-Bericht als `.pdf`/`.html` im Ordner) | 07.11.2026, 07:38–ca. 11:50, vollständiger Plan (V, A–H, F, G); 106 ✅, 19 ⚠️, 0 ❌, 10 ⏳, 12 n/a (nach `Ergebnisse.tsv`); `flutter test` +1898, −1 (Linux-D-Bus-Test auf macOS) | TP-FN-001 v1.36 @ `0afeab8` | 1.2.2 (26), `flutter build macos --debug` (Bundle-ID `.e2e`, ad hoc) / `flutter build ios --simulator --debug` | macOS 27.2 / iPhone-18-Pro-Max-Simulator (iOS 27.2); Mac: keine lokalen Löschungen wegen geteiltem Schlüsselbund (V-04, F-03 bis F-06, H-18, H-19), Screenshots als JPEG (Qualität 85), Originale nur lokal |
| 24 | `2026-11-07_24_Windows-nur-G1_Build26` | 07.11.2026, ca. 20:20–21:35 (Windows-Nachtests #263, #144, #254, #274 sowie Windows-Anteile von #317 und #266; Eingaben per `SendInput`, keine physische Tastatur); alle sechs Punkte bestanden, offen: physische Tastatur (#263), Bildschirmaufnahme (#144), 200 % Schrift (#274); `flutter test` auf Windows +1657 ~108 −22 (alle Umgebung/Testannahmen) | `Checkliste_Geraetenachtests.md` @ `40863fd` | 1.2.2 (26), `flutter build windows --release` aus `main`, SQLCipher-DLLs aus v1.2.2 | Windows 11 (VM) / – (N2 als `matrix-js-sdk`-Hilfsclient) |

Die Läufe 04 und 05 liefen parallel; die Nummer folgt dem Beginn. Die Bezeichnungen „Lauf 1/2/3“ im Testplan (Anhang E, Issue-Zuordnung) entsprechen den Nummern 03, 05 und 04.

Testpläne: `../User E2E Test/README.md`.
