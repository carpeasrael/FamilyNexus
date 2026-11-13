# Vorschau mit Beispieldaten

`preview_main.dart` startet die App gegen einen **Fake-Matrix-Server** mit erfundenen Daten (Anna, Ben, Clara,
Beispieltermine, Einkaufsliste). Nur für Store-Screenshots und Demos; es gibt keine Netzwerkverbindung.

```sh
# iOS-Simulator (Screenshots: xcrun simctl io <Gerät> screenshot datei.png)
flutter run -t tool/preview/preview_main.dart -d <Simulator-ID>
# Android
flutter run -t tool/preview/preview_main.dart -d <Emulator-ID>
```

Der Chat-Tab beginnt mit der Gesprächsliste (#423, E-100). `integration_test/store_screenshots_test.dart` öffnet daher
für „3-chat“ zuerst die Zeile des Familienchats und für „4-einzelchat“ nach dem Zurück-Pfeil die Zeile von Ben. Nach
Änderungen am Chat die Aufnahmen und die Komposition (`compose_store_images.py`) einmal ansehen.
