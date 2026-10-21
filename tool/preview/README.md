# Vorschau mit Beispieldaten

`preview_main.dart` startet die App gegen einen **Fake-Matrix-Server** mit erfundenen Daten (Anna, Ben, Clara,
Beispieltermine, Einkaufsliste). Nur für Store-Screenshots und Demos; es gibt keine Netzwerkverbindung.

```sh
# iOS-Simulator (Screenshots: xcrun simctl io <Gerät> screenshot datei.png)
flutter run -t tool/preview/preview_main.dart -d <Simulator-ID>
# Android
flutter run -t tool/preview/preview_main.dart -d <Emulator-ID>
```
