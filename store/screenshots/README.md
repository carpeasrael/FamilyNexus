# Screenshots (Beispieldaten)

Alle Aufnahmen zeigen **erfundene Beispieldaten** (Fake-Server, siehe `tool/preview/`).

- `ios-6.9/` – iPhone 17 Pro Max (6,9″), 1320×2868: Heute, Kalender, Chat, Einzelchat, Einkauf, Familie (Flutter-Oberfläche ohne iOS-Statusleiste).
- `android-phone/` – Android-Emulator (Pixel 8), 1200×2400 (seitlich aufgefüllt, damit das Seitenverhältnis die Play-Grenze von 2:1 einhält).

Neu erzeugen: iOS `flutter test integration_test/store_screenshots_test.dart -d <Simulator>` (Dateien in `/tmp/fn_store_shots`);
Android: Vorschau-App bauen (`flutter build apk --debug -t tool/preview/preview_main.dart`), auf dem Emulator starten,
Tabs mit `adb shell input tap` wechseln und mit `adb exec-out screencap -p` aufnehmen.
Für 6,5″-iPhones und weitere Größen aus einem anderen Simulator aufnehmen oder in App Store Connect skalieren lassen.
