# Release-E2E: Beleg je Plattform und Build (E-103)

Vor jedem Plattform-Build und beim Veröffentlichen eines Releases muss für genau diesen Build ein **bestandener E2E-Test der Plattform mit Screenshots** belegt sein. `tool/check_release_e2e.sh` prüft das in jedem Build-Job von `release.yml` und bricht sonst ab.

| Build-Job | verlangte Abschnitte |
|---|---|
| `apk` (APK und AAB) | `android` |
| `flatpak`, `appimage` | `linux` |
| `windows` | `windows` |
| `apple` (DMG, iOS-IPA, macOS-pkg) | `ios` und `macos` |
| `web` | `web` |

## Datei

`docs/release-e2e/<Version>.md`, z. B. `1.2.3+30.md`. Der Fingerabdruck ist derselbe wie im Release-Review (`tool/check_release_review.sh --print`): Jede Änderung am App-Code, auch die Build-Nummer, verlangt einen neuen Lauf und einen neuen Bericht.

```markdown
# Release-E2E 1.2.3+30

- Version: 1.2.3+30
- Fingerabdruck: <Ausgabe von tool/check_release_review.sh --print>

## android
- Testlauf: 2026-11-16_32_Release-1.2.3_Android_Build30
- Ergebnis: bestanden
- Screenshot: screenshots/RT3-V-02_And.png
- Screenshot: screenshots/RT3-E-01_And.png
- Screenshot: screenshots/RT3-C-04_And.png
```

Regeln, die das Skript prüft:

- `Testlauf` ist ein Ordner unter `User E2E Test Report/` mit `Testreport.md`.
- `Ergebnis` ist genau `bestanden`. Offene (⏳) oder fehlgeschlagene Schritte gehören in den Testreport; ist die Abnahme der Plattform nicht erreicht, steht dort nicht `bestanden`.
- Mindestens drei Zeilen `Screenshot:` (png oder jpg, relativ zum Testlauf, nicht leer, keine `..`).
- Simulator und Emulator zählen für ihre Plattform (`ios`, `android`), sofern der Testreport das Gerät nennt. Was darin nicht ausführbar war, ist nicht `bestanden`.

Ausgenommen sind nur Neubauten alter Stände: `skip_e2e` bei `workflow_dispatch` (wie `skip_review`). Lokale Builds mit `tool/build_*.sh` prüft das Gate nicht.

## Abgrenzung

Der Code-Test eines Issues (`flutter analyze`, `flutter test`, Regressionstest) schließt das Issue, siehe `CLAUDE.md`. Was nur auf dem Gerät belegbar ist (Swift, C++, Systemdialoge), steht in der Plattform-Pflichtliste des Release-Tests und wird hier belegt, nicht mehr am Issue.
