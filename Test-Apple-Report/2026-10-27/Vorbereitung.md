# Lauf 2026-10-27 – Vorbereitung (TP-FN-001 v1.5 @ 7159ddc)

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | iOS-Simulator (iPhone 15 Test, DeviceHub) | macOS 27.2 |
| Soll-Version (V-01) | 1.2.1+17 | 1.2.1+17 |
| Ist-Version (V-02) | 1.2.1 (17) | /Applications: 1.2.1 (16) -> Abweichung |
| V-03 | nicht nötig | `flutter build macos --release` -> build/macos/.../FamilyNexus.app = 1.2.1 (17); Start von dort (nicht nach /Applications kopiert) |
| V-05 Server | OK: versions + register flows m.login.dummy |
| V-06 Namen | 1027 frei für n1, n12, i2, n9 -> Datumsteil `1027` |

Offen: V-04 (lokale Daten löschen), V-07, A bis H.
