# Screenshots (Beispieldaten)

Alle Aufnahmen zeigen **erfundene Beispieldaten** (Fake-Server, siehe `tool/preview/`).

- `ios-6.9/` – iPhone 17 Pro Max (6,9″), 1320×2868: Heute, Kalender, Chat, Einzelchat, Einkauf, Familie (Flutter-Oberfläche ohne iOS-Statusleiste).
- `ios/` – **fertiges App-Store-Bilderpaket** (Bildunterschrift + Screenshot auf Markenhintergrund, PNG ohne Alpha, 6 Bilder je Sprache und Größe):
  `ios/de-DE/` und `ios/en-US/`, je `1206x2622/` (6,1″/6,3″, Pflichtgröße) und `1320x2868/` (6,9″). Beispieldaten und Oberfläche sind je Sprache übersetzt.
  Reihenfolge nach Apple-Hinweisen (stärkste Funktion zuerst, kurze Texte, Motiv mittig, keine Preise/URLs/Auszeichnungen).
  Neu erzeugen: Rohaufnahmen je Größe/Sprache mit `flutter test integration_test/store_screenshots_test.dart -d <Simulator> --dart-define=SHOTS_LANG=de|en`
  (Dateien in `/tmp/fn_store_shots_<sprache>`) nach `<roh>/<breite>-<sprache>/` kopieren, dann `python3 tool/preview/compose_store_images.py <roh> store/screenshots/ios`.
- `ios-6.3/` – iPhone 17 Pro (6,3″, gilt auch für 6,1″), 1206×2622: nativ im Simulator aufgenommen (App Store Connect erlaubt für 6,1″/6,3″ 1179×2556 oder 1206×2622; App-Vorschauvideos 1920×886 bzw. 886×1920).
- `android/` – **fertiges Google-Play-Bilderpaket und das hochzuladende Paket** (#349): `android/de-DE/phoneScreenshots/` und `android/en-US/phoneScreenshots/`, je 7 Bilder
  `01-kalender.png`, `02-chat.png`, `03-einkauf.png`, `04-datenschutz.png`, `05-heute.png`, `06-einzelchat.png`, `07-familie.png` (Reihenfolge: die vier Funktionen aus dem Issue zuerst).
  Format: 1080×1920 (9:16), PNG RGB 8 Bit ohne Alpha, je Datei unter 1 MB. Jedes Bild hat eine kurze Überschrift (Optik wie `ios/`) über der Aufnahme der Android-Emulator-Oberfläche
  (Pixel 8, API 35, nur Flutter-Fläche, ohne Statusleiste), nur erfundene Beispieldaten (Anna, Ben, Clara, „Familie Berger“ / „Berger Family“, Server `fake.test`).
  Das Datenschutz-Bild zeigt die Android-Fassung der Datenschutzerklärung (Schlüsselspeicher „Android Keystore“) ab dem zweiten Abschnitt, damit nicht der Beispiel-Anbieter-Absatz am Seitenanfang im Bild steht.
  Überschriften, Reihenfolge und Zuordnung der Rohaufnahmen: `tool/preview/play_captions.json`. Der Verzeichnisname `phoneScreenshots` ist ein Muster dieses Repos und nicht 1:1 das Fastlane-Layout (`…/images/phoneScreenshots`); in der Play Console werden die Dateien von Hand hochgeladen.
  Die Play-Vorgaben (PNG/JPEG, 24 Bit ohne Alpha, höchstens 8 MB, Seiten 320–3840 px, längere Seite höchstens doppelt so lang wie die kürzere, 2–8 Telefonbilder) stammen aus dem Kenntnisstand und sind **nicht gegen die Play Console geprüft**.
  Das Aufnahmedatum ist das Tagesdatum der Aufnahme (Kalender, „heute“); die Termine entstehen aus `DateTime.now()`.
  Neu erzeugen (Emulator-Aufnahme; der iOS-Simulator ist kein Ersatz, dort zeigt die Datenschutzerklärung „Schlüsselbund“):
  1. Emulator **in einem eigenen Aufruf** starten (nicht zusammen mit dem Testlauf und nicht mit `nohup … &` im selben Aufruf, sonst stirbt er mitten im Test), z. B. im Hintergrund:
     `$ANDROID_HOME/emulator/emulator -avd Pixel8_API35 -no-window -no-audio -no-snapshot` (ANDROID_HOME/ANDROID_SDK_ROOT: `/opt/homebrew/share/android-commandlinetools`).
     Warten, bis `adb devices` `emulator-5554 device` zeigt und `adb shell getprop sys.boot_completed` `1` ergibt (rund 20 s).
  2. Je Sprache aufnehmen, Ausgabe ins Log (Dateiname enthält die Sprache):
     `flutter test integration_test/store_screenshots_test.dart -d emulator-5554 --no-dds --dart-define=SHOTS_LANG=de > /tmp/shots_de.log` (und `=en` nach `shots_en.log`).
     Der Lauf endet mit `+1 -1`: Der Test selbst ist grün, der Fehler ist ein Werkzeugfehler (`streamListen … VmServiceProxyGoldenFileComparator`). Maßgeblich sind die Zeilen `PNG <name> <base64>` im Log (7 je Sprache).
  3. Rohaufnahmen dekodieren (nicht einchecken, nur unter `/tmp`): `python3 tool/preview/decode_shots.py /tmp/shots_de.log /tmp/fn_roh` und dasselbe für `shots_en.log` → `/tmp/fn_roh/<de|en>/<nr>-<motiv>.png`.
  4. Komponieren: `python3 tool/preview/compose_store_images.py --play /tmp/fn_roh` (Ausgabe `store/screenshots/android/`; Überschriften höchstens 2 Zeilen). Gleiche Rohbilder ergeben dieselben Dateien.
  5. Emulator beenden (`adb emu kill`), alle 14 Bilder ansehen (nur Demodaten, Überschrift lesbar, nichts abgeschnitten, DE deutsch, EN englisch), `flutter test test/store/play_screenshots_test.dart`.
- `android-phone/` – **Rohbestand**, wird **nicht** hochgeladen (hochzuladen ist `android/`): Android-Emulator (Pixel 8), 1200×2400 (seitlich aufgefüllt), nur eine Sprache, ohne Überschriften.

- `macos-2560x1600/` – Mac App Store (2560×1600): dieselben Motive, Kalender in der Agenda-Ansicht (die Monatsansicht streckt sich auf der breiten Fläche). Reine Flutter-Oberfläche ohne Fensterrahmen.

**Hinweis macOS:** Das neue Motiv `7-datenschutz` (Menü → Datenschutzerklärung) ist auf macOS nicht geprüft; es zeigt dort den Text mit dem Schlüsselbund statt der Android-Variante und gehört nicht in das Play-Paket.

Neu erzeugen macOS: `flutter test integration_test/store_screenshots_test.dart -d macos > log.txt`; der Test gibt die PNGs als Zeilen
`PNG <name> <base64>` aus (die Sandbox der App ist von außen nicht lesbar, Bildschirmaufnahme-Recht ist nicht nötig).

Neu erzeugen: iOS `flutter test integration_test/store_screenshots_test.dart -d <Simulator>` (Dateien in `/tmp/fn_store_shots_<sprache>`);
Android (Rohbestand `android-phone/`): Vorschau-App bauen (`flutter build apk --debug -t tool/preview/preview_main.dart`), auf dem Emulator starten,
Tabs mit `adb shell input tap` wechseln und mit `adb exec-out screencap -p` aufnehmen.
Weitere iPhone-Größen aus einem anderen Simulator aufnehmen oder in App Store Connect skalieren lassen.
