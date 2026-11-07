# Agent-Anweisung: Durchführung TP-FN-DEF-G1G2 (Sandbox, selbstständig)

Diese Anweisung richtet sich an den Agenten, der den Plan [Default_test_G1-G2.md](Default_test_G1-G2.md) ausführt. Der Plan ist die einzige Quelle für Schritte und Erwartete Ergebnisse; diese Datei regelt **wo** (Sandbox), **wie** (selbstständig, auch die Kontoanlage), wie belegt und wie berichtet wird.

**Startbefehl für den Nutzer** (in Claude Code):

> Führe den Test `User E2E Test/Default_test_G1-G2` nach `AGENT_ANWEISUNG.md` aus.

Werkzeuge im Ordner `sandbox/`:

| Datei | Zweck |
|---|---|
| `sandbox.sh` | Sandbox bauen (`apk`), starten (`up`), Bildschirmfoto (`shot`), Zustand (`status`), abbauen (`down`) |
| `ui.py` | App im Emulator bedienen: Elemente nach Beschriftung finden und tippen, Text eingeben, warten |
| `cdp.py` | Anbieter-Seite (matrix.org) in Chrome/Custom Tab bedienen: lesen, Felder füllen (auch aus `secure/`), Formulare absenden (`submit`), Bild |
| `mailcode.py` | Bestätigungscode aus dem Test-Postfach `app_test@inneso.de` per IMAP lesen (nur lesend) |
| `../make_report.py` | Bericht (AURORA-PDF), Prüfung der Ergebnisdatei, CLI-Ausgaben als Bild |

## 0. Grundregeln

1. **Zuerst fragen, dann handeln.** Erste Handlung ist die Startabfrage (Abschnitt 1). Vorher nichts bauen, starten oder anlegen.
2. **Nur in der Sandbox.** Der ganze Lauf findet in den Sandbox-Emulatoren `FN_E2E_G1` und `FN_E2E_G2` statt (Abschnitt 2). Nicht benutzen: das AVD `Pixel_8_API_36` des Nutzers, seine Flatpak-Sitzung (`~/.var/app/de.inneso.familynexus`), seinen Desktop-Browser, seine Geräte, den Testserver anderer Pläne.
3. **Der Agent legt die Testkonten selbst an und löscht sie selbst.** Er füllt die Seiten von matrix.org über `cdp.py` aus, holt den E-Mail-Code mit `mailcode.py` und bestätigt Zustimmung und Löschung selbst.
4. **Captchas nie lösen, umgehen oder automatisiert beantworten.** Läuft die Prüfung unsichtbar durch (z. B. Turnstile ohne Aufgabe), geht es weiter. Erscheint eine **sichtbare Captcha-Aufgabe**, hält der Agent an und bittet den Nutzer, sie im Emulatorfenster zu lösen (Abschnitt 4.3). Das ist der einzige vorgesehene Handgriff des Nutzers.
5. **matrix.org nur mit Freigabe je Lauf** (`CLAUDE.md`, „Grenzen ohne ausdrückliche Freigabe“). Die Freigabe gilt nur für den laufenden Lauf und nur für die zwei Wegwerfkonten dieses Laufs.
6. **Kein Code ändern.** Weder App-Code noch Plan während des Laufs; Planfehler werden Befunde.
7. **Nichts annehmen.** ✅ nur, wenn der Agent den Schritt ausgeführt, das Bild **selbst angesehen** (Read-Tool) und das Erwartete Ergebnis darauf gefunden hat. Nicht ausgeführt = ⏳ mit Grund.
8. **Geheimnisse:** Konto-Passwörter, Notfall-Schlüssel, Einladungslink und E-Mail-Codes nur unter `secure/` bzw. im Sandbox-Arbeitsordner (Rechte 600). Das Postfach-Passwort steht in `secure/Test-Email.md` und wird nur von `mailcode.py` zur Laufzeit gelesen. Werte nie in Befehlszeilen, Ausgaben, `results.json`, Bericht, Commit oder Issue: Eingaben über `cdp.py fillsecret`/`fillfile` und `ui.py typesecret`.
9. **Ende nie mit offenem Konto.** Wird abgebrochen, nachdem ein Konto angelegt wurde: erst das Konto in der noch laufenden Sandbox löschen (Abschnitt 4.4), dann abbauen und berichten.

## 1. Start: G1, G2 und Freigabe abfragen

Als **erste Handlung** mit `AskUserQuestion` in **einem** Aufruf:

| Frage | Kopf | Optionen |
|---|---|---|
| „Welches Gerät simuliert G1 (Konto N1, gründet die Familie und lädt ein)? Der Test läuft in der Sandbox (eigener Android-Emulator, bei jedem Lauf frisch).“ | G1 | Android-Telefon (Pixel 8, API 36) · Android-Tablet (Pixel Tablet, API 36) |
| „Welches Gerät simuliert G2 (Konto I2, wird eingeladen)?“ | G2 | dieselben Optionen |
| „Gibst du für diesen einen Lauf frei, dass der Agent zwei neue Konten bei matrix.org anlegt (E-Mail `app_test@inneso.de` bzw. `app_test+i2@inneso.de`) und am Ende wieder löscht? Du wirst nur gebraucht, falls eine sichtbare Captcha-Aufgabe erscheint.“ | matrix.org | Ja, für diesen Lauf freigegeben · Nein, nicht starten |

Wählt der Nutzer über „Other“ ein anderes System (iPhone, iPad, Mac, Windows, Linux-Flatpak, Web), **nicht** ausweichen, sondern erklären und neu fragen: In der Sandbox auf diesem Linux-Host lassen sich nur Android-Emulatoren abschotten und selbstständig bedienen. Die Web-App hat keine Anmeldung über die Anbieter-Seite (`lib/data/platform/oauth_redirect.dart`: Web → `OAuthFlow.none`) und kann daher kein matrix.org-Konto anlegen. Die Linux-Version öffnet die Anbieter-Seite im Desktop-Browser des Nutzers, also außerhalb der Sandbox. Apple-Geräte und Windows gibt es auf dem Host nicht. Ein solcher Lauf gehört zu `Release-Test_1.2.2_v01.md` bzw. `Testplan_FamilyNexus.md`.

Lehnt der Nutzer matrix.org ab: Lauf beenden, nichts anlegen.

Fest vorgegeben (nicht abfragen): Matrix-Server `matrix.org`; E-Mail N1 `app_test@inneso.de`; E-Mail I2 `app_test+i2@inneso.de` mit Rückfall laut Plan, Abschnitt 4; Postfach-Zugang `secure/Test-Email.md`.

## 2. Sandbox

**Was die Sandbox ist:** zwei eigene Android-Emulatoren (`FN_E2E_G1` auf `emulator-5560`, `FN_E2E_G2` auf `emulator-5562`), bei jedem `up` mit gelöschten Daten kalt gestartet (`-wipe-data -no-snapshot`). Nichts aus früheren Läufen bleibt, nichts aus dem Lauf geht in die Nutzerumgebung. Die App wird als Release-APK des getesteten Stands mit Debug-Signatur installiert (nur für die Sandbox, nie weitergeben). Chrome im Emulator ist über das DevTools-Protokoll erreichbar: G1 `127.0.0.1:9333`, G2 `127.0.0.1:9334`. Die Anbieter-Seite öffnet die App in einem Custom Tab dieses Chrome, deshalb kann `cdp.py` sie bedienen.

**Arbeitsordner:** `FN_SANDBOX_DIR=<Scratchpad>/fn-e2e-<JJMMTT>` (APK, Emulator-Logs, Code-Dateien). Nicht im Repository.

**Ablauf:**

```bash
S="User E2E Test/Default_test_G1-G2/sandbox"
export FN_SANDBOX_DIR=<Scratchpad>/fn-e2e-<JJMMTT>
export FN_DEVICE_G1=pixel_8        # oder pixel_tablet, laut Startabfrage
export FN_DEVICE_G2=pixel_8
export FN_SECRET_FILE=secure/Default_test_G1-G2_<JJMMTT>.md
"$S/sandbox.sh" apk                # baut 1.2.2+<Build> aus dem aktuellen Stand (ca. 3 Min.)
"$S/sandbox.sh" up                 # ca. 1 Min., beide Emulatoren sichtbar (für den Captcha-Fall)
"$S/sandbox.sh" status
```

- Vor `apk`: `git status` prüfen. Der Build läuft auf dem aktuellen Arbeitsbaum; fremde Änderungen des Nutzers im Bericht nennen. Commit und Version (`aapt2`-Ausgabe von `apk`) in `run.commit`/`run.build`.
- `up` bricht ab, wenn ein Sandbox-Emulator schon läuft (alter Lauf): dann `down` und neu.
- **Speicher:** Jeder Emulator startet mit 4 GB (`FN_EMU_RAM`, Vorgabe 4096). Mit 2,5 GB hat Android in Lauf 23 Chrome samt Anbieter-Seite beendet. `up` gibt den tatsächlichen Speicher aus; im Bericht unter `run.notes` vermerken. Weniger als 4 GB nur, wenn der Host nicht genug freien Speicher hat (`free -h`, Bedarf ca. 9 GB für beide), und dann im Bericht begründen.
- **Am Ende immer** `"$S/sandbox.sh" down` (auch nach Abbruch, aber erst nach dem Löschen angelegter Konten). `down` beendet die Emulatoren, entfernt die Umleitungen und löscht die Nutzerdaten der Sandbox-AVDs (App-Daten, Sitzungen, Schlüssel). Reagiert ein Emulator nicht auf `emu kill` (Lauf 23), beendet `down` gezielt dessen qemu-Prozess (nur `-avd FN_E2E_G1/G2`, nie andere Emulatoren) und meldet „hart beendet“. `down` endet mit Fehler, wenn danach noch ein Sandbox-Emulator läuft; dann nicht weitermachen, sondern den Nutzer fragen.

**Bedienung der App** (`ui.py`):
- `ui.py G1 list` zeigt alle Elemente mit Beschriftung und Mittelpunkt; `ui.py G1 tap "Neue Familie gründen"`; `ui.py G1 wait "Dein Notfall-Schlüssel" 60`.
- Text: Feld antippen, dann `ui.py G1 type "Test N1"`. Umlaute werden zu ae/oe/ue/ss (`adb input` kann keine Umlaute); im `comment` vermerken.
- Geheimnisse: `ui.py G1 typesecret N1_PASSWORD` (Wert aus `FN_SECRET_FILE`).
- Lange Werte (Einladungslink von G1 nach G2): auf G1 „Kopieren“, dann den Link aus der G1-Ansicht lesen (`ui.py G1 list` bzw. Zwischenablage über `adb shell cmd clipboard` falls verfügbar), in `secure/…` als `INVITE_LINK` ablegen und auf G2 mit `ui.py G2 typesecret INVITE_LINK` einfügen oder per `adb -s emulator-5562 shell am start -a android.intent.action.VIEW -d '<Link>'` öffnen (Link vorher nur in eine Variable aus der Datei lesen, nicht ausgeben). Vor dem Absenden per Bild prüfen.

**Bildschirmfotos:**
- App: `sandbox.sh shot G1 <Datei>`. Die App setzt FLAG_SECURE; `shot` erkennt das schwarze Bild und nimmt dann über die Emulator-Konsole auf. Stürzt der Emulator dabei ab (bekannt seit 02.11.2026): Lauf nicht fortsetzen wie bisher, sondern Abschnitt 7.
- Anbieter-Seite: zusätzlich `cdp.py 9333 shot <Datei>` (nur Seiteninhalt, gut lesbar). Für den Beleg das Bild nehmen, auf dem das Erwartete Ergebnis zu sehen ist.

## 3. Vorbereitung des Laufs

1. Stand: `git rev-parse --short HEAD`, Version aus `pubspec.yaml`.
2. **Lauf-Ordner nach `User E2E Test Report/README.md`**: `User E2E Test Report/<JJJJ-MM-TT>_<NN>_Default-G1-G2_<G1>-<G2>_Build<NN>/`
   - `<JJJJ-MM-TT>` Tag des Beginns, `<NN>` nächste freie laufende Nummer (höchste Nummer in der README-Tabelle + 1),
   - `Default-G1-G2` Plan (Teilplan steht vor den Plattformen),
   - `<G1>-<G2>` Plattformkürzel, hier `And-And`, `And-AndT`, `AndT-And` oder `AndT-AndT`,
   - `Build<NN>` Build-Nummer der getesteten App.
   Beispiel: `2026-11-07_23_Default-G1-G2_And-And_Build26`.
3. `python3 "User E2E Test/Default_test_G1-G2/make_report.py" skeleton "<Lauf-Ordner>"` (legt `screenshots/`, `logs/`, `results.json` an). `run.*` ausfüllen: Geräte aus `sandbox.sh up`, `operation` = „Agent in der Sandbox (Emulator FN_E2E_…)“, `install` = „Release-APK aus `<Commit>`, Debug-Signatur (Sandbox)“, `matrix_org_release` mit Uhrzeit der Freigabe.
4. Testdaten in `secure/Default_test_G1-G2_<JJMMTT>.md` (Rechte 600) mit genau diesen Schlüsseln anlegen (Werte zufällig, `RRRR` = `shuf -i 1000-9999 -n1`, Passwörter mit `openssl rand -base64 18`):

```
N1_USER = fnx-e2e-<JJMMTT>-n1-<RRRR>
N1_MXID = @fnx-e2e-<JJMMTT>-n1-<RRRR>:matrix.org
N1_PASSWORD = <zufällig, ≥ 16 Zeichen>
N1_EMAIL = app_test@inneso.de
I2_USER = fnx-e2e-<JJMMTT>-i2-<RRRR>
I2_MXID = @fnx-e2e-<JJMMTT>-i2-<RRRR>:matrix.org
I2_PASSWORD = <zufällig>
I2_EMAIL = app_test+i2@inneso.de
N1_KEY =
I2_KEY =
INVITE_LINK =
STATUS = angelegt <Datum Uhrzeit>
```

5. Ist `secure/Test-Email.md` für andere lesbar (`644`), den Nutzer darauf hinweisen (`chmod 600` empfehlen), nicht selbst ändern.
6. Vor der Kontoanlage prüfen, dass die Namen frei sind: `curl -s https://matrix-client.matrix.org/_matrix/client/v3/profile/<N1_MXID>` muss `404` mit `"No row found (profiles)"` liefern (so am 06.11.2026 für nicht vorhandene Namen beobachtet); sonst neue `RRRR`.
7. Sandbox aufbauen (Abschnitt 2), dann Vorbedingungen P-1 bis P-5 des Plans prüfen und in `run.notes` vermerken.

## 4. Ausführung

### 4.1 Je Schritt

Strikt in der Reihenfolge des Plans (V, A, B, C, D, E, F, N). Für **jeden** Schritt:

1. Aktion ausführen (App mit `ui.py`, Anbieter-Seite mit `cdp.py`, CLI auf dem Host).
2. Warten, bis der erwartete Zustand sichtbar sein kann (`ui.py … wait`, `cdp.py … wait`; Planangaben „bis 60 s“; Dauer notieren).
3. Bild nach `screenshots/<Schritt-ID><Buchstabe>-<Gerät>.png` wie in der Spalte „Screenshot“ des Plans. CLI-Schritte: Ausgabe nach `logs/<ID>.txt`, dann `make_report.py textshot logs/<ID>.txt screenshots/<ID>-CLI.png`.
4. Schwärzen (Abschnitt 5), dann das Bild mit dem Read-Tool **ansehen**.
5. Abgleich: Erwartetes Ergebnis Satz für Satz gegen das Bild. Sichtbare Texte wörtlich übernehmen.
6. Eintrag in `results.json → steps["<ID>"]`:

```json
{
  "status": "passed | passed_with_issue | failed | pending | na",
  "time": "21:34",
  "observed": "Was auf dem Bild zu sehen ist, sichtbare Texte wörtlich in „…“.",
  "comparison": "Je Teil des Erwarteten Ergebnisses: erfüllt / abweichend (wie).",
  "comment": "Grund bei pending/na, Ersatzschreibung, Wartezeit, Captcha-Hilfe des Nutzers.",
  "evidence": ["screenshots/DT-A-02a-G1.png", "screenshots/DT-A-02b-G1.png"]
}
```

7. Abweichung → `passed_with_issue` oder `failed` und ein Eintrag in `findings` (`id`, `step`, `severity` = kritisch/hoch/mittel/gering, `text`, `issue` = bestehendes Issue oder „neu“). Keine Issues ohne Auftrag anlegen.
8. Nach jedem Abschnitt `make_report.py report "<Lauf-Ordner>" --check`; Prüfhinweise sofort beheben.

Bei `failed`: weiter, sofern spätere Schritte nicht davon abhängen; sonst ⏳ „abhängig von <ID>“. **Abschnitt F und N für jedes angelegte Konto trotzdem ausführen.**

### 4.2 Konto anlegen (DT-A-02 bis DT-A-04, DT-B-04 bis DT-B-05)

Port: G1 = 9333, G2 = 9334. Schlüsselpräfix: N1 für G1, I2 für G2. Die Seiten von matrix.org (MAS) ändern sich; Selektoren **zur Laufzeit** mit `cdp.py <port> fields` bestimmen, nicht aus dieser Anweisung übernehmen. `fields` zeigt Passwort- und versteckte Felder nie mit Wert (nur „<gesetzt, verborgen>“).

**Absenden (verbindlich, Lehre aus Lauf 23):** Skript-Klicks (`cdp.py click`) schicken Formulare von matrix.org nicht ab. Deshalb jede Schaltfläche, die etwas absendet oder bestätigt („Continue“, „Delete account“ …), so auslösen:

1. `cdp.py <port> submit "text:<Beschriftung>" account.matrix.org` (Formular per `requestSubmit`, wartet bis 10 s auf eine Änderung der Seite).
2. Danach **immer** den erwarteten Folgezustand prüfen (`cdp.py <port> wait "<erwarteter Text>" 15 account.matrix.org` bzw. die URL), nicht nur „Seite hat reagiert“: In Lauf 23 schloss `requestSubmit` den Löschdialog, ohne das Konto zu löschen.
3. Rückgabe 5 („keine Änderung“) oder Folgezustand fehlt: per Fingertipp wiederholen, `ui.py G<n> tap "<Beschriftung>"` (scrollt die Schaltfläche selbst in den sichtbaren Bereich), dann erneut Schritt 2. In Lauf 23 halfen Fingertipps im Löschdialog; auf der Zustimmungsseite halfen weder `requestSubmit` noch der Fingertipp (DT-A-04, Befund L23-1).
4. Hilft beides nicht: Bild aufnehmen, Schritt ❌, Befund mit URL und sichtbarem Text. Nicht beliebig oft wiederholen (höchstens je zweimal).
5. Chromes eigene Hinweise über der Seite (z. B. „Chrome notifications make things easier“, „Save password?“) liegen nicht im DOM und blockieren Fingertipps: mit `ui.py G<n> tap "No thanks"` bzw. „Not now“/„Never“ schließen, **nie** „Save“ oder „Continue“ dieses Hinweises.
6. `cdp.py click` nur für Links und Schaltflächen ohne Formular (z. B. „Continue with email address“, „Delete account“ zum Öffnen des Dialogs).

1. App: Name eintragen, „Konto bei matrix.org erstellen“ tippen. Bild der App (`…a-G<n>`).
2. `cdp.py <port> wait "Create an account" 30 account.matrix.org` (bzw. deutsche Beschriftung). Bild der Seite (`…b-G<n>`).
3. Stand 06.11.2026: `account.matrix.org/register` zeigt das Feld „Username“ und „Continue with email address“ (daneben Anmeldung über Google, Apple … — **nie** benutzen). Benutzername: `cdp.py <port> fillsecret '<Selektor Username>' N1_USER account.matrix.org`, dann `cdp.py <port> click "text:Continue with email address" account.matrix.org`.
4. Folgeseite(n): `fields` lesen; E-Mail (`fillsecret … N1_EMAIL`), Passwort und Wiederholung (`fillsecret … N1_PASSWORD`), Zustimmung zu den Bedingungen (`check`). `text` lesen und die Bedingungen in `observed` nennen (Titel, Link).
5. **Captcha prüfen:** `cdp.py <port> text` meldet „Captcha-Element auf der Seite erkannt“, `wait` endet mit `CAPTCHA` (Rückgabe 4). Dann 20 s warten und erneut prüfen (unsichtbare Prüfungen lösen sich selbst). Bleibt eine sichtbare Aufgabe: Abschnitt 4.3.
6. Bild vor dem Absenden (`…a`, Passwort maskiert). Zeitpunkt `T0=$(date +%s)` merken, absenden nach „Absenden“ oben (`submit "text:Continue"`); Folgezustand: Text „Verify your email“ bzw. URL mit `/verify-email`.
7. Code holen: `python3 -I "$S/mailcode.py" wait $T0 <N1_EMAIL> "$FN_SANDBOX_DIR/code_n1.txt" 300 > "<Lauf-Ordner>/logs/DT-A-03b.txt"` (gibt Absender, Empfänger, Betreff, Datum aus, Code als `******`), dann `textshot` → `DT-A-03b-CLI.png`. Ohne Mail nach 300 s: einmal „Code erneut senden“ auf der Seite, noch einmal 300 s; dann ❌.
8. Code eingeben: `cdp.py <port> fillfile 'input[name="code"]' "$FN_SANDBOX_DIR/code_n1.txt" account.matrix.org`, absenden (`submit "text:Continue"`; Folgezustand: „Choose your display name“ bzw. Zustimmungsseite). Code-Datei sofort löschen.
8a. Anzeigename (Stand 06.11.2026 gefragt): `cdp.py <port> fill 'input[name="display_name"]' "Test N1" account.matrix.org`, absenden; Folgezustand: „Continue to FamilyNexus?“.
9. Zustimmungsseite für FamilyNexus: Text lesen und wörtlich in `observed`; Bild (`…c`); absenden (`submit "text:Continue"`, nur die Zustimmung für FamilyNexus, nichts anderes). Folgezustand ist die Rückkehr in die App (Schritt 10), nicht eine weitere Seite.
10. App: `ui.py G<n> wait "Dein Notfall-Schlüssel" 60` → DT-A-04 bzw. weiter mit DT-B-06.
11. I2: wie oben mit `I2_*`, Rückfall der E-Mail-Adresse laut Plan, Abschnitt 4 (abgelehnte Unteradresse = ⚠️, Meldung wörtlich).

Notfall-Schlüssel: „Kopieren“ tippen; den Schlüssel aus `ui.py G<n> list` lesen und nur in `secure/…` als `N1_KEY`/`I2_KEY` speichern (Ausgabe des Befehls in eine Datei umleiten, nicht in den Verlauf). Bild schwärzen.

### 4.3 Sichtbare Captcha-Aufgabe (einziger Handgriff des Nutzers)

`AskUserQuestion`: „Auf G<n> (Emulatorfenster ‚FN_E2E_G<n>‘) zeigt matrix.org eine Captcha-Aufgabe. Bitte dort lösen, nichts anderes ändern, dann ‚Gelöst‘ wählen.“ Optionen: „Gelöst“ · „Nicht lösbar / Abbruch“. Danach selbst weiter ab 4.2 Schritt 6. Im `comment` vermerken: „Captcha durch Nutzer gelöst (<Uhrzeit>)“. Läuft die Sandbox mit `--no-window`, ist das nicht möglich: dann `down` und mit Fenster neu starten, bevor ein Konto angelegt wurde.

### 4.4 Konto löschen (DT-F-01 bis DT-F-08) und Nachweis (DT-N-01 bis DT-N-04)

1. App: Einstellungen → Konto → „Konto löschen“; Dialog lesen und belegen. „Zur Löschseite“ öffnet die Kontoseite (`account.matrix.org/account/…`) im Custom Tab.
2. DT-F-03 (Negativprobe) **vor** der Löschung: zurück in die App (`ui.py G<n> key BACK`, falls nötig), „Löschung prüfen“ → „Das Konto besteht noch …“. Danach „Seite erneut öffnen“.
3. Auf der Kontoseite mit `fields`/`text` den Bereich zum Deaktivieren bzw. Löschen finden („Deactivate account“, „Delete account“ o. ä.), öffnen (`click "text:Delete account"`) und bestätigen. Stand 06.11.2026: Dialog „Delete this account?“ mit Passwortfeld „Enter your password to continue“ und roter Schaltfläche „Delete account“. Passwort per **Fingertipp** eingeben (Feld antippen, `ui.py G<n> typesecret N1_PASSWORD`; `fillsecret` allein reichte in Lauf 23 nicht), dann rote Schaltfläche per `ui.py G<n> tap` (bei zwei Treffern die im Dialog, ggf. `tap "Delete account" 2`). Folgezustand: „Account deleted“. Bestätigungsseite belegen (`cdp.py … shot` und `sandbox.sh shot`).
4. Custom Tab schließen (`ui.py G<n> key BACK`), in der App „Löschung prüfen“ → Willkommensseite.
5. Nachweis DT-N-01/02: „Ich habe schon ein Konto“ → „Bei matrix.org anmelden“ → auf der Seite Benutzername und **richtiges** Passwort (`fillsecret`) → Fehlermeldung wörtlich festhalten und belegen; Tab schließen, Meldung der App belegen.
6. DT-N-03: `curl -s -w '\n%{http_code}' https://matrix-client.matrix.org/_matrix/client/v3/profile/<MXID>` für beide; Ausgabe wörtlich. DT-N-04 wie im Plan.
7. In `secure/…`: `STATUS = Konten gelöscht <Datum Uhrzeit>`.

## 5. Schwärzen

Vor dem Ansehen und vor jeder Ablage: Passwortfelder (auch mit Punkten, falls „anzeigen“ aktiv war), Notfall-Schlüssel, Einladungslink, E-Mail-Codes. Mit Pillow ein gefülltes Rechteck über die Fläche legen (Koordinaten aus `ui.py … list` bzw. `cdp.py … fields`/Bildprüfung), das Original **überschreiben**. Im `comment` „geschwärzt: <was>“. Sichtbar bleiben dürfen: Matrix-IDs der Wegwerfkonten, `app_test@inneso.de` samt Unteradresse.

## 6. Nach dem Lauf: Abbau, Bericht, Ablage

1. Beide Konten gelöscht und Nachweis erbracht (DT-N-01/02)? Sonst zuerst 4.4.
2. `"$S/sandbox.sh" down`. Arbeitsordner `$FN_SANDBOX_DIR` löschen (APK, Logs, Code-Dateien). `adb devices` darf keinen Sandbox-Emulator mehr zeigen.
3. DT-N-06: `grep -rIlF` mit jedem Geheimnis aus `secure/…` und dem Postfach-Passwort über den Lauf-Ordner, `git status --ignored`; Ergebnis als „0 Treffer“ in `logs/DT-N-06.txt` (ohne die Werte).
4. `run.end` setzen, Bericht erzeugen: `python3 "User E2E Test/Default_test_G1-G2/make_report.py" report "<Lauf-Ordner>"` → `Testreport_<Ordner>_DE.pdf` (und `.html`) im Lauf-Ordner, AURORA-Design, Schriften eingebettet. Prüfhinweise müssen 0 sein.
5. **Kontrolle durch einen frischen Agenten:** ohne Kenntnis der eigenen Bewertung prüft er für jeden Schritt mit ✅/⚠️ das Bild gegen das Erwartete Ergebnis im Plan. Gemeldete Abweichungen selbst nachprüfen, `results.json` korrigieren, Bericht neu erzeugen.
6. **Ablage nach der Struktur von `User E2E Test Report/README.md`:**

```
User E2E Test Report/<JJJJ-MM-TT>_<NN>_Default-G1-G2_<G1>-<G2>_Build<NN>/
├── Testreport.md                               Kurzfassung (siehe unten)
├── Testreport_<Ordner>_DE.pdf                  AURORA-Bericht (make_report.py)
├── Testreport_<Ordner>_DE.html                 Quelle des PDF
├── results.json                                Rohdaten je Schritt
├── screenshots/<Schritt-ID>-<Gerät>.png         Belege
└── logs/<Schritt-ID>.txt                       CLI-Ausgaben (ohne Geheimnisse)
```

   `Testreport.md` enthält: Kopf (Plan `TP-FN-DEF-G1G2 <Version>`, Commit, Build, G1/G2, Beginn/Ende, Sandbox), Zählung je Status, Tabelle der Abnahmekriterien AK-1 bis AK-8 mit Ergebnis, Befunde, ⏳-Schritte mit Grund, Verweis auf das PDF.

   In `User E2E Test Report/README.md` eine Zeile anhängen: `| <NN> | \`<Ordner>\` | <Datum>, <Uhrzeit von–bis>, Default-Test G1–G2 (Sandbox); <Zählung ✅/⚠️/❌/⏳/n/a> | TP-FN-DEF-G1G2 <Version> @ \`<Commit>\` | <Version> (<Build>), Release-APK Debug-Signatur | <G1> / <G2> |`.

7. Dem Nutzer melden: Gesamtergebnis, Abnahmekriterien, Befunde, ⏳-Schritte mit Grund, Pfad zum PDF. Nichts committen und keine Issues anlegen ohne Auftrag.

## 7. Abbruchregeln

- Emulator stürzt ab oder reagiert 3 Versuche lang nicht: angelegte Konten feststellen (`curl …/profile/<MXID>`). Bestehen welche, Sandbox neu aufbauen (`down`, `up`), mit „Ich habe schon ein Konto“ anmelden (Notfall-Schlüssel aus `secure/…`) und das Konto nach 4.4 löschen. Dann den Lauf als abgebrochen berichten.
- matrix.org lehnt die Kontoanlage ab (Rate-Limit, Name vergeben, Sperre): Meldung wörtlich, **kein** weiterer Versuch mit neuem Namen ohne Rückfrage.
- Sichtbares Captcha und der Nutzer antwortet „Nicht lösbar“: angelegte Konten wie oben löschen, abbrechen.
- Der Nutzer bricht ab: angelegte Konten löschen, dann `down`, Bericht mit allen bisherigen Ergebnissen und ⏳ „abgebrochen auf Wunsch des Nutzers“ erzeugen und ablegen.
