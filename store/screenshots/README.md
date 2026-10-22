# Screenshots (Beispieldaten)

Alle Aufnahmen zeigen **erfundene Beispieldaten** (Fake-Server, siehe `tool/preview/`).

- `ios-6.9/` – iPhone 17 Pro Max (6,9″), 1320×2868: Heute, Kalender, Chat, Einzelchat, Einkauf, Familie (Flutter-Oberfläche ohne iOS-Statusleiste).
- `ios-6.5/` – iPhone 6,5″, 1284×2778: aus `ios-6.9/` skaliert (Breite 1284, oben 12 px leerer Rand abgeschnitten, nicht verzerrt).
- `android-phone/` – Android-Emulator (Pixel 8), 1200×2400 (seitlich aufgefüllt, damit das Seitenverhältnis die Play-Grenze von 2:1 einhält).

- `macos-2560x1600/` – Mac App Store (2560×1600): dieselben Motive, Kalender in der Agenda-Ansicht (die Monatsansicht streckt sich auf der breiten Fläche). Reine Flutter-Oberfläche ohne Fensterrahmen.

Neu erzeugen macOS: `flutter test integration_test/store_screenshots_test.dart -d macos > log.txt`; der Test gibt die PNGs als Zeilen
`PNG <name> <base64>` aus (die Sandbox der App ist von außen nicht lesbar, Bildschirmaufnahme-Recht ist nicht nötig).

Neu erzeugen: iOS `flutter test integration_test/store_screenshots_test.dart -d <Simulator>` (Dateien in `/tmp/fn_store_shots`);
Android: Vorschau-App bauen (`flutter build apk --debug -t tool/preview/preview_main.dart`), auf dem Emulator starten,
Tabs mit `adb shell input tap` wechseln und mit `adb exec-out screencap -p` aufnehmen.
Weitere iPhone-Größen aus einem anderen Simulator aufnehmen oder in App Store Connect skalieren lassen.
