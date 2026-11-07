# Default-Test G1–G2: Konten bei matrix.org, Familie, Termin, Chat, Aufgabe, Löschung

**Planversion: v03** (06.11.2026) · Dokument-ID `TP-FN-DEF-G1G2` · Stand: `main` @ `7f15e8b` · Soll-Version der App: laut `pubspec.yaml` des getesteten Stands (zurzeit **1.2.2 (26)**)

Durchführung durch einen Agenten **selbstständig in einer Sandbox** (zwei eigene Android-Emulatoren, bei jedem Lauf frisch): [AGENT_ANWEISUNG.md](AGENT_ANWEISUNG.md), Werkzeuge in [sandbox/](sandbox/). Der Agent legt die Testkonten selbst an und löscht sie selbst. Bericht: [make_report.py](make_report.py) erzeugt aus diesem Plan und der Ergebnisdatei den PDF-Bericht im AURORA-Design.

## 1. Ziel und Ablauf

Ein vollständiger Durchlauf mit zwei **neu angelegten** Konten bei **matrix.org** auf zwei getrennten Geräten:

1. **G1** legt das Konto N1 an und gründet eine Familie.
2. G1 lädt ein Mitglied ein; auf **G2** legt die eingeladene Person das Konto I2 an, fragt den Beitritt an und wird von N1 bestätigt.
3. N1 legt einen **geteilten Termin** an und teilt ihn im Chat; I2 sieht ihn und sagt zu.
4. N1 und I2 schreiben sich im **Chat**.
5. N1 legt eine **Aufgabenliste** an, die I2 zugewiesen ist; I2 arbeitet sie ab, N1 sieht den Fortschritt.
6. **Beide Konten werden gelöscht** und es wird belegt, dass sie nicht mehr existieren.

Jeder Schritt hat ein **Erwartetes Ergebnis**. Im Bericht wird das **Beobachtete Ergebnis** dagegen geprüft und mit mindestens einem **Screenshot** belegt.

Nicht Inhalt: Blockieren und Entfernen von Mitgliedern, Einkauf, Meldungen, Tablet-Layouts (siehe `Testplan_FamilyNexus.md`, `Release-Test_1.2.2_v01.md`).

## 2. Freigabe matrix.org (Pflicht vor dem ersten Schritt)

`CLAUDE.md` erlaubt echte Konten bei matrix.org **nur mit ausdrücklicher Freigabe**. Dieser Plan legt zwei echte Konten an und löscht sie wieder. Vor dem Start muss der Nutzer daher

- die Kontoanlage bei matrix.org für **diesen einen Lauf** ausdrücklich freigeben,
- erreichbar sein für den Fall, dass matrix.org eine **sichtbare Captcha-Aufgabe** zeigt (die löst nur ein Mensch, nie der Agent; unsichtbare Prüfungen laufen ohne Zutun durch).

**Matrix-Server und E-Mail (fest für diesen Plan):**

| Angabe | Wert |
|---|---|
| Matrix-Server (Anbieter in der App) | `matrix.org` (Standard „matrix.org (empfohlen)“, nicht ändern) |
| Test-Postfach | `app_test@inneso.de` (IONOS) |
| Zugangsdaten des Postfachs | `secure/Test-Email.md` (Passwort, Webmail `https://id.ionos.de/`); nie kopieren, nie ausgeben |
| Abruf des Bestätigungscodes | IMAP `imap.ionos.de:993` (SSL) mit den Zugangsdaten aus `secure/Test-Email.md`; ersatzweise Webmail durch den Nutzer |

matrix.org verlangt bei der Kontoanlage einen Bestätigungscode per E-Mail. Den liest der Agent per IMAP aus dem Test-Postfach und gibt ihn auf der Anbieter-Seite ein; der Code erscheint nirgends im Bericht.

Ohne Freigabe: Lauf nicht starten, alle Schritte ⏳ „keine Freigabe matrix.org“.

## 3. Festlegung von G1 und G2 (beim Start abfragen)

Der Test läuft in einer **Sandbox**: zwei eigene Android-Emulatoren `FN_E2E_G1` (`emulator-5560`) und `FN_E2E_G2` (`emulator-5562`), die bei jedem Lauf mit gelöschten Daten kalt starten und am Ende samt Nutzerdaten gelöscht werden. Nutzerumgebung (eigene AVDs, Flatpak-Sitzung, Desktop-Browser, Geräte) bleibt unberührt. Abgefragt wird je Gerät nur das Profil: **Android-Telefon** (Pixel 8, API 36, Kürzel `And`) oder **Android-Tablet** (Pixel Tablet, API 36, Kürzel `AndT`).

Andere Plattformen sind in der Sandbox nicht möglich: Die Web-App hat keine Anmeldung über die Anbieter-Seite (`OAuthFlow.none`) und kann kein matrix.org-Konto anlegen; die Linux-Version öffnet die Anbieter-Seite im Desktop-Browser des Nutzers; Apple-Geräte und Windows gibt es auf dem Host nicht.

| Angabe | G1 (N1, Moderator) | G2 (I2, eingeladen) |
|---|---|---|
| Profil (Telefon/Tablet) und Kürzel | | |
| Emulator (AVD, Seriennummer) | `FN_E2E_G1`, `emulator-5560` | `FN_E2E_G2`, `emulator-5562` |
| Android-Version | | |
| Installationsquelle | Release-APK des getesteten Stands, Debug-Signatur (nur Sandbox) | dito |
| App-Version Soll / Ist | | |
| Bedienung | Agent (`ui.py`, `cdp.py`) | Agent |
| Methode für Screenshots | `sandbox.sh shot` (Rückfall Emulator-Konsole bei FLAG_SECURE), `cdp.py shot` für Anbieter-Seiten | dito |

## 4. Testdaten

`JJMMTT` = Datum des Laufs, `RRRR` = vier Zufallsziffern je Lauf. Bei matrix.org bleiben gelöschte Benutzernamen dauerhaft gesperrt; deshalb nie einen Namen wiederverwenden.

| Rolle | Anzeigename | Benutzername | Matrix-ID | Passwort | E-Mail | Notfall-Schlüssel | Gerät |
|---|---|---|---|---|---|---|---|
| N1 (Gründer, Moderator) | `Test N1` | `fnx-e2e-JJMMTT-n1-RRRR` | `@fnx-e2e-JJMMTT-n1-RRRR:matrix.org` | `PW-N1` | `app_test@inneso.de` | `KN1` | G1 |
| I2 (eingeladen) | `Test I2` | `fnx-e2e-JJMMTT-i2-RRRR` | `@fnx-e2e-JJMMTT-i2-RRRR:matrix.org` | `PW-I2` | `app_test+i2@inneso.de` (Rückfall siehe unten) | `KI2` | G2 |

| Weitere Daten | Wert |
|---|---|
| Familienname | `E2E Familie MMTT` |
| Termin | `E2E Termin MMTT`, morgen 18:00–19:00, Ort `Küche`, Sichtbarkeit **Geteilt** |
| Chat | G1: `Hallo von G1 MMTT`, G2: `Hallo zurück von G2 MMTT` |
| Aufgabenliste | Titel `E2E Aufgabe MMTT`, zugewiesen an `Test I2`, Wiederholung **Täglich**, Punkte `Müll rausbringen` und `Spülmaschine ausräumen` |

**E-Mail für I2:** Zuerst `app_test+i2@inneso.de` (Unteradresse, landet im selben Postfach). Lehnt matrix.org die Adresse ab oder kommt binnen 5 Minuten keine Mail im Postfach an, ein zweiter Versuch mit `app_test@inneso.de` selbst (falls matrix.org eine Adresse für zwei Konten zulässt). Scheitert auch das: anhalten und den Nutzer nach einer zweiten Adresse fragen. Die tatsächlich verwendete Adresse im Bericht nennen.

**Geheimnisse:** Konto-Passwörter (mindestens 12 Zeichen, je Konto verschieden, zufällig), das Postfach-Passwort, E-Mail-Codes, Notfall-Schlüssel und Einladungslink stehen **nur** unter `secure/` (Konten: `secure/Default_test_G1-G2_<JJMMTT>.md`; Postfach: `secure/Test-Email.md`) (von Git ignoriert, Rechte 600). Im Bericht steht nur „in `secure/…` hinterlegt“. Auf jedem Screenshot werden sie **geschwärzt**, bevor er abgelegt wird. Matrix-IDs der Wegwerfkonten und die Adresse `app_test@inneso.de` (samt Unteradresse) dürfen sichtbar bleiben.

**Eingabe per Skript:** Umlaute können über `adb shell input text` nicht getippt werden; dann Ersatzschreibung (`Kueche`, `Muell rausbringen`, `Spuelmaschine ausraeumen`) und im Bericht vermerken.

## 5. Belege

- Lauf-Ordner nach der Struktur von `User E2E Test Report/README.md`: `User E2E Test Report/<JJJJ-MM-TT>_<NN>_Default-G1-G2_<G1>-<G2>_Build<NN>/` (Plan vor den Plattformen, `NN` = nächste laufende Nummer), z. B. `2026-11-07_23_Default-G1-G2_And-And_Build26`.
- Darin: `Testreport.md` (Kurzfassung), `Testreport_<Ordner>_DE.pdf` und `.html` (AURORA), `results.json` (Ergebnisse, Schema siehe `AGENT_ANWEISUNG.md`), `screenshots/`, `logs/`. Zusätzlich eine Zeile in `User E2E Test Report/README.md`.
- Dateiname je Bild: `<Schritt-ID>-<Gerät>.png`, bei mehreren Zuständen ein Buchstabe: `DT-B-07a-G1.png`.
- Server-Prüfungen (`curl`): Befehl und Ausgabe in `logs/<Schritt-ID>.txt`, zusätzlich als Bild `screenshots/<Schritt-ID>-CLI.png` (`make_report.py textshot`), damit **jeder** Schritt ein Bild hat.
- Screenshot erst aufnehmen, wenn der erwartete Zustand sichtbar ist; Hinweise und Toasts (ca. 4–8 s) sofort.
- Bewertung: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ nicht durchgeführt (mit Grund) · n/a (mit Grund). **✅ nur, wenn das Erwartete Ergebnis am Beleg nachweisbar ist.** Was nicht ausgeführt wurde, ist ⏳, nie ✅.

## 6. Vorbedingungen

| ID | Prüfung |
|---|---|
| P-1 | Freigabe matrix.org liegt vor (Abschnitt 2). `secure/Test-Email.md` ist lesbar; IMAP-Anmeldung am Test-Postfach gelingt (DT-V-05). |
| P-2 | G1 und G2 sind festgelegt (Abschnitt 3), beide haben Internet und denselben Build. |
| P-3 | Sandbox frisch aufgebaut (`sandbox.sh up`): beide Emulatoren mit gelöschten Daten, App frisch installiert, DevTools auf 9333/9334 erreichbar. Kein anderer Sandbox-Emulator läuft. |
| P-4 | Screenshots: `sandbox.sh shot` erkennt FLAG_SECURE (schwarzes Bild) und nimmt über die Emulator-Konsole auf; der Bildschirmschutz der App bleibt an (Werkseinstellung). |
| P-5 | Der Einladungslink geht nur über `secure/…` (`INVITE_LINK`) von G1 nach G2, nie über Ausgaben oder Dateien außerhalb von `secure/`. |

## 7. Testschritte

Spalte **Gerät**: wo gehandelt und wo der Screenshot aufgenommen wird; `CLI` = Prüfung auf dem Entwicklungsrechner. App-Sprache: **Deutsch**. Texte in „…“ sind die Soll-Texte der App (`lib/l10n/app_de.arb`); Texte der matrix.org-Seiten können abweichen und werden wörtlich notiert.

### V. Vorbereitung

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-V-01 | CLI | `curl -s -o /dev/null -w '%{http_code}' https://matrix-client.matrix.org/_matrix/client/versions` und `curl -s https://matrix-client.matrix.org/_matrix/client/v1/auth_metadata` | `200`; die Metadaten nennen einen `issuer` und einen `registration_endpoint` bzw. `account_management_uri` (Kontoverwaltung über die Anbieter-Seite). | DT-V-01-CLI |
| DT-V-02 | G1 | App auf G1 frisch starten, Sprache Deutsch wählen. | Willkommensseite „Willkommen bei FamilyNexus“ mit „Neue Familie gründen“, „Ich wurde eingeladen“ und „Ich habe schon ein Konto“. Kein Fehler, keine fremde Sitzung. | DT-V-02-G1 |
| DT-V-03 | G2 | App auf G2 frisch starten, Sprache Deutsch wählen. | Wie DT-V-02 auf G2. | DT-V-03-G2 |
| DT-V-04 | G1, G2 | App-Version auf beiden Geräten ablesen (Einstellungen → Über die App, sobald erreichbar, sonst Installationsquelle/Paketinfo). | Beide Geräte zeigen dieselbe Soll-Version und Build-Nummer. | DT-V-04-G1, DT-V-04-G2 |
| DT-V-05 | CLI | IMAP-Anmeldung an `imap.ionos.de:993` mit den Zugangsdaten aus `secure/Test-Email.md`, Posteingang zählen (keine Inhalte ausgeben). | Anmeldung `OK`, Anzahl der Nachrichten wird angezeigt; im Beleg kein Passwort. | DT-V-05-CLI |

### A. Konto N1 und Familie auf G1

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-A-01 | G1 | „Neue Familie gründen“ wählen. Anbieter **nicht** ändern. | Anbieter-Auswahl zeigt „matrix.org (empfohlen)“; Hinweis „Bei matrix.org legst du dein Konto auf der Seite des Anbieters an. Danach kommst du automatisch hierher zurück.“ und die Schaltfläche „Konto bei matrix.org erstellen“. | DT-A-01-G1 |
| DT-A-02 | G1 | „Konto bei matrix.org erstellen“ antippen. | Die Seite von matrix.org öffnet sich (iOS/Mac: Fenster der App-Sitzung; Android: Custom Tab; Win/Lin/Web: externer Browser). Die App zeigt „Bitte auf der Seite von matrix.org fortfahren … Danach geht es hier automatisch weiter.“ | DT-A-02a-G1 (App), DT-A-02b-G1 (Anbieter-Seite) |
| DT-A-03 | G1 (Agent; Nutzer nur bei sichtbarem Captcha) | Auf der matrix.org-Seite im Custom Tab (per `cdp.py`) Benutzername `fnx-e2e-…-n1-RRRR`, E-Mail `app_test@inneso.de` und `PW-N1` eingeben, Nutzungsbedingungen annehmen; eine **sichtbare** Captcha-Aufgabe löst der Nutzer im Emulatorfenster (unsichtbare Prüfung: kein Handgriff). Danach holt der Agent den Bestätigungscode per IMAP aus dem Test-Postfach (nur Mails ab Beginn des Schritts, Absender matrix.org) und gibt ihn ein; FamilyNexus den Zugriff erlauben. | Eine Bestätigungsmail von matrix.org an `app_test@inneso.de` kommt binnen 5 Minuten an; der Code wird angenommen; matrix.org legt das Konto an und fragt nach der Zustimmung für FamilyNexus; danach Rückleitung zur App. Kein Fehler „Benutzername vergeben“. | DT-A-03a-G1 (Formular, Passwort geschwärzt), DT-A-03b-CLI (Eingang der Mail: Absender, Betreff, Zeit, Code geschwärzt), DT-A-03c-G1 (Zustimmung) |
| DT-A-04 | G1 | Rückkehr in die App abwarten (höchstens 60 s). | Die App kehrt **ohne Zutun** zurück und zeigt „Dein Notfall-Schlüssel“ mit „Notfall-Schlüssel erstellen“. Nicht: „Die Anmeldung beim Anbieter wurde nicht abgeschlossen. …“ | DT-A-04-G1 |
| DT-A-05 | G1 | „Notfall-Schlüssel erstellen“, Schlüssel `KN1` per „Kopieren“ in die `secure/`-Datei übernehmen, „Ich habe den Notfall-Schlüssel sicher aufbewahrt.“ ankreuzen, „Weiter“. | Schlüssel wird einmal angezeigt (im Bild geschwärzt); „Weiter“ ist erst nach dem Haken aktiv; danach folgt der Familienschritt. | DT-A-05a-G1 (vor Haken), DT-A-05b-G1 (nach Haken) |
| DT-A-06 | G1 | Familienname `E2E Familie MMTT` eingeben, „Familie gründen“. Eine Frage nach Einladen mit „Später“ beantworten. | Die Hauptansicht öffnet sich (Reiter „Heute“). Unter „Familie“ steht `E2E Familie MMTT`, „Mitglieder“ listet `Test N1` als Moderator. | DT-A-06a-G1 (Eingabe), DT-A-06b-G1 (Reiter „Familie“) |
| DT-A-07 | G1 | Einstellungen → Konto ansehen. | Matrix-ID `@fnx-e2e-…-n1-RRRR:matrix.org`, Server `matrix.org`. | DT-A-07-G1 |

### B. Einladung und Beitritt (G1 → G2)

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-B-01 | G1 | Reiter „Familie“ → „Mitglied einladen“. „Konto-Server für Neue“ leer lassen (= matrix.org). | Ein Einladungslink wird angezeigt mit dem Hinweis „Der Link ist … gültig und nur einmal verwendbar. Ein Moderator bestätigt die Anfrage, …“. Der Link enthält den Familiennamen nicht im Klartext. | DT-B-01-G1 (Link geschwärzt) |
| DT-B-02 | G1 → G2 | Link kopieren und privat auf G2 übertragen (P-5). G1 bleibt geöffnet und online. | Hinweis „Kopiert“ bzw. Link liegt auf G2 in der Zwischenablage; Link wurde nirgends öffentlich abgelegt. | DT-B-02-G1 |
| DT-B-03 | G2 | „Ich wurde eingeladen“ → Link einfügen (oder Link direkt öffnen). | Die Einladung wird erkannt („Du wurdest eingeladen“ bzw. Einladungs-Karte); als Anbieter ist matrix.org vorbelegt; kein Hinweis „ungültiger Link“. | DT-B-03-G2 |
| DT-B-04 | G2 | Konto anlegen: „Konto bei matrix.org erstellen“. | Wie DT-A-02 auf G2: Anbieter-Seite öffnet sich, App zeigt „Bitte auf der Seite von matrix.org fortfahren …“. | DT-B-04a-G2 (App), DT-B-04b-G2 (Anbieter-Seite) |
| DT-B-05 | G2 (Agent; Nutzer nur bei sichtbarem Captcha) | Wie DT-A-03 mit `fnx-e2e-…-i2-RRRR`, E-Mail `app_test+i2@inneso.de` (Rückfall Abschnitt 4), `PW-I2`; Code per IMAP. | Bestätigungsmail an die verwendete Adresse kommt im Test-Postfach an; Konto angelegt, Zustimmung erteilt, Rückleitung zur App. Wird die Unteradresse abgelehnt: Meldung wörtlich, ⚠️, Rückfall verwenden. | DT-B-05a-G2, DT-B-05b-CLI (Mail), DT-B-05c-G2 |
| DT-B-06 | G2 | Notfall-Schlüssel `KI2` erstellen und sichern, Haken setzen, „Weiter“. | Wie DT-A-05; danach die Beitrittskarte „Du trittst der Familie „E2E Familie MMTT“ bei. Eingeladen hat dich Test N1 (Konto bei matrix.org).“ mit dem Hinweis „… Ein Moderator muss deine Anfrage bestätigen, bevor du aufgenommen wirst.“ | DT-B-06a-G2 (Schlüssel geschwärzt), DT-B-06b-G2 (Beitrittskarte) |
| DT-B-07 | G2 | „Beitritt anfragen“. 60 s warten. | „Fast geschafft! Test N1 muss dich noch bestätigen. Sag kurz Bescheid – du kannst die App so lange schließen.“ **G2 wird nicht von selbst aufgenommen.** | DT-B-07-G2 |
| DT-B-08 | G1 | Reiter „Familie“ öffnen. | Reiter heißt „Familie – 1 offene Anfragen“; die Anfrage von `Test I2` nennt den gültigen Einladungslink und bietet „Bestätigen“ und „Ablehnen“. | DT-B-08-G1 |
| DT-B-09 | G1 | „Bestätigen“ → Rückfrage bestätigen. | Rückfrage „Test I2 in die Familie aufnehmen? Der Einladungslink wird dabei verbraucht.“; danach steht `Test I2` als „Mitglied“ in „Mitglieder“, die Anfrage ist verschwunden. | DT-B-09a-G1 (Rückfrage), DT-B-09b-G1 (Mitgliederliste) |
| DT-B-10 | G2 | G2 beobachten (bis 60 s, danach einmal App neu starten). | G2 öffnet die Hauptansicht von `E2E Familie MMTT`; unter „Familie“ stehen beide Mitglieder, I2 ohne Verwaltungsaktionen. Dauer ab „Bestätigen“ notieren. | DT-B-10-G2 |

### C. Termin teilen

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-C-01 | G1 | Reiter „Kalender“ → „Neuer Termin“: Titel `E2E Termin MMTT`, Beginn morgen 18:00, Ende 19:00, Ort `Küche`, Sichtbarkeit „Geteilt“. Speichern. | Bei „Geteilt“ steht „Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.“; der Termin erscheint morgen 18:00–19:00 im Kalender, Datum mit führender Null. | DT-C-01a-G1 (Editor), DT-C-01b-G1 (Kalender) |
| DT-C-02 | G1 | Termin öffnen → „Im Chat teilen“. | Bestätigung „Im Chat geteilt“; im Chat von G1 erscheint die Terminkarte. | DT-C-02-G1 |
| DT-C-03 | G2 | Reiter „Kalender“ auf G2, morgigen Tag öffnen. | `E2E Termin MMTT` steht dort mit 18:00–19:00, Ort `Küche`, „Von Test N1“. | DT-C-03-G2 |
| DT-C-04 | G2 | Reiter „Chat“ auf G2. | Die geteilte Terminkarte von Test N1 ist lesbar; keine Meldung „Nachricht kann nicht entschlüsselt werden“. | DT-C-04-G2 |
| DT-C-05 | G2 | Termin öffnen → bei „Antwort“ „Zusagen“. | Die Zusage ist gespeichert und im Termin als eigene Antwort sichtbar. | DT-C-05-G2 |
| DT-C-06 | G1 | Termin auf G1 öffnen (bis 60 s warten). | Bei „Teilnehmer“ bzw. „Antwort“ steht für `Test I2` die Zusage. | DT-C-06-G1 |

### D. Chat

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-D-01 | G1 | Chat: `Hallo von G1 MMTT` eingeben, „Senden“. | Nachricht erscheint im Verlauf von G1 als gesendet, ohne „Senden fehlgeschlagen – tippen zum Wiederholen“. | DT-D-01-G1 |
| DT-D-02 | G2 | Chat auf G2 öffnen. | `Hallo von G1 MMTT` von `Test N1` ist lesbar (bis 30 s). | DT-D-02-G2 |
| DT-D-03 | G2 | `Hallo zurück von G2 MMTT` senden. | Nachricht erscheint auf G2 als gesendet. | DT-D-03-G2 |
| DT-D-04 | G1 | Chat auf G1 ansehen. | `Hallo zurück von G2 MMTT` von `Test I2` ist lesbar; Reihenfolge der vier Einträge (Terminkarte, zwei Nachrichten) stimmt auf beiden Geräten überein. | DT-D-04-G1 |

### E. Aufgabe zuweisen und abarbeiten

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-E-01 | G1 | Menü → „Aufgaben“ → „Neue Aufgabenliste“: Titel `E2E Aufgabe MMTT`, „Zugewiesen an“ `Test I2`, „Wiederholung“ „Täglich“, „Punkte (einer pro Zeile)“ `Müll rausbringen` / `Spülmaschine ausräumen`. Speichern. | Die Liste steht unter „Weitere Listen“ mit „Zugewiesen an Test I2“ und „0 von 2 erledigt“; Hinweis „Startet jeden Tag um Mitternacht neu“. | DT-E-01a-G1 (Editor), DT-E-01b-G1 (Liste) |
| DT-E-02 | G1 | Versuchen, `Müll rausbringen` auf G1 abzuhaken. | Nicht möglich: Abhaken kann nur die zugewiesene Person („Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.“); Fortschritt bleibt „0 von 2 erledigt“. | DT-E-02-G1 |
| DT-E-03 | G2 | Reiter „Heute“ auf G2, dann „Aufgaben“. | „Heute“ zeigt die Karte „Aufgaben“ mit offenen Aufgaben; unter „Mir zugewiesen“ steht `E2E Aufgabe MMTT` mit „0 von 2 erledigt“. | DT-E-03a-G2 (Heute), DT-E-03b-G2 (Aufgaben) |
| DT-E-04 | G2 | `Müll rausbringen` abhaken, im Dialog „Erledigt“ Kommentar `erledigt per E2E` eintragen, „Erledigt“. | Punkt ist abgehakt mit „Erledigt am TT.MM.JJJJ um HH:MM“; Fortschritt „1 von 2 erledigt“. | DT-E-04a-G2 (Dialog), DT-E-04b-G2 (Liste) |
| DT-E-05 | G2 | `Spülmaschine ausräumen` abhaken, „Erledigt“ ohne Kommentar. | Fortschritt „2 von 2 erledigt“; „Heute“ zeigt keine offenen Aufgaben mehr. | DT-E-05a-G2, DT-E-05b-G2 |
| DT-E-06 | G1 | Aufgabenliste auf G1 öffnen (bis 60 s warten). | „2 von 2 erledigt“; beide Punkte mit Erledigt-Zeit; der Kommentar `erledigt per E2E` ist sichtbar (Verlauf/Details). | DT-E-06-G1 |

### F. Konten löschen

Zuerst I2 (G2), dann N1 (G1): N1 ist danach allein und einziger Moderator.

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-F-01 | G2 | Einstellungen → Konto → „Konto löschen“. Dialog lesen. | „Konto löschen?“ mit „Dein Konto @fnx-e2e-…-i2-RRRR:matrix.org wird bei matrix.org dauerhaft gelöscht. …“; **kein** Hinweis „Du bist der einzige Moderator …“; „Die Löschung bestätigst du auf der Kontoseite deines Anbieters.“ und „Zur Löschseite“. | DT-F-01-G2 |
| DT-F-02 | G2 | „Zur Löschseite“. | Kontoseite von matrix.org öffnet sich; App zeigt „Bestätige die Löschung auf der Seite des Anbieters, schließe sie … und kehre dann hierher zurück.“ | DT-F-02a-G2 (App), DT-F-02b-G2 (Kontoseite) |
| DT-F-03 | G2 | Vor der Bestätigung auf der Seite: zurück in die App, „Löschung prüfen“. | Negativprobe: „Das Konto besteht noch. Schließe die Löschung auf der Seite des Anbieters ab.“; nichts wird lokal gelöscht. | DT-F-03-G2 |
| DT-F-04 | G2 (Agent) | Auf der Kontoseite im Custom Tab (per `cdp.py`) das Konto deaktivieren/löschen und bestätigen (ggf. `PW-I2` bzw. Benutzername eingeben), Seite schließen. | matrix.org bestätigt die Deaktivierung bzw. meldet ab. | DT-F-04-G2 |
| DT-F-05 | G2 | In der App „Löschung prüfen“. | Die App löscht die lokalen Daten und zeigt direkt die Willkommensseite (nicht „Anmelden“). | DT-F-05-G2 |
| DT-F-06 | G1 | Reiter „Familie“ und „Chat“ auf G1 (bis 60 s warten). | `Test I2` ist nicht mehr Mitglied; die früheren Nachrichten von I2 bleiben sichtbar, Absender „Test I2“ oder „Ehemaliges Mitglied“, nie die rohe Matrix-ID. | DT-F-06a-G1 (Familie), DT-F-06b-G1 (Chat) |
| DT-F-07 | G1 | Einstellungen → Konto → „Konto löschen“. Dialog lesen. | Text nennt `@fnx-e2e-…-n1-RRRR:matrix.org` und matrix.org; kein Hinweis „Du bist der einzige Moderator …“ (N1 ist allein). Erscheint er doch: wörtlich notieren, ⚠️. | DT-F-07-G1 |
| DT-F-08 | G1 (Agent) | „Zur Löschseite“, Konto auf der Seite (per `cdp.py`) löschen, Seite schließen, „Löschung prüfen“. | Die App zeigt die Willkommensseite. | DT-F-08a-G1 (Kontoseite), DT-F-08b-G1 (Willkommen) |

### N. Nachweis: Konten existieren nicht mehr

| ID | Gerät | Aktion | Erwartetes Ergebnis | Screenshot |
|---|---|---|---|---|
| DT-N-01 | G1 | „Ich habe schon ein Konto“ → „Bei matrix.org anmelden“ → auf der Seite mit `fnx-e2e-…-n1-RRRR` und dem **richtigen** `PW-N1` anmelden. | matrix.org verweigert die Anmeldung (Konto deaktiviert bzw. Anmeldedaten ungültig; Text wörtlich notieren). Nach Schließen zeigt die App „Die Anmeldung beim Anbieter wurde nicht abgeschlossen. Bitte versuche es noch einmal.“ | DT-N-01a-G1 (Anbieter), DT-N-01b-G1 (App) |
| DT-N-02 | G2 | Wie DT-N-01 mit I2 und `PW-I2`. | Wie DT-N-01. | DT-N-02a-G2, DT-N-02b-G2 |
| DT-N-03 | CLI | `curl -s -w '\n%{http_code}' https://matrix-client.matrix.org/_matrix/client/v3/profile/@fnx-e2e-…-n1-RRRR:matrix.org` und dasselbe für I2. | Je `404` mit `M_NOT_FOUND` oder ein leeres Profil ohne Anzeigenamen. Liefert der Server `401`/`403` (Profilabfrage nur angemeldet), Ausgabe wörtlich festhalten; dann ist dieser Schritt n/a und nur DT-N-01/02 zählen. | DT-N-03-CLI |
| DT-N-04 | CLI | `curl -s 'https://matrix-client.matrix.org/_matrix/client/v3/register/available?username=fnx-e2e-…-n1-RRRR'` (ebenso I2). | `M_USER_IN_USE` oder ein Hinweis, dass Registrierung nur über den Anbieter läuft: Der Name bleibt gesperrt. Das widerspricht der Löschung nicht und wird nur festgehalten. | DT-N-04-CLI |
| DT-N-05 | G1, G2 | Beide Apps beenden und neu starten. | Beide zeigen die Willkommensseite; keine Familie, keine Nachrichten, kein Konto. | DT-N-05-G1, DT-N-05-G2 |
| DT-N-06 | CLI | `secure/Default_test_G1-G2_<JJMMTT>.md` mit „Konten gelöscht am …“ versehen; `git status --ignored` und `grep` über Bericht und Lauf-Ordner nach Konto-Passwörtern, Postfach-Passwort, E-Mail-Codes, Schlüsseln und Link. | Kein Geheimnis außerhalb von `secure/`; `grep` findet nichts. | DT-N-06-CLI |

## 8. Abnahmekriterien

Der Test gilt nur als bestanden, wenn jedes Kriterium durch die genannten Schritte mit Beleg erfüllt ist (✅ oder ⚠️ ohne Bezug zum Kriterium).

| ID | Kriterium | Schritte |
|---|---|---|
| AK-1 | N1 wird auf G1 neu bei matrix.org angelegt und gründet eine Familie; die App kehrt nach der Anbieter-Seite selbst zurück. | DT-A-02, DT-A-04, DT-A-06, DT-A-07 |
| AK-2 | I2 wird auf G2 über den Einladungslink neu angelegt und erst nach Bestätigung durch N1 aufgenommen. | DT-B-03, DT-B-06, DT-B-07, DT-B-09, DT-B-10 |
| AK-3 | Der geteilte Termin erscheint auf G2 mit richtigen Daten, die Zusage kommt auf G1 an. | DT-C-01, DT-C-03, DT-C-05, DT-C-06 |
| AK-4 | Chat-Nachrichten kommen in beide Richtungen lesbar an. | DT-C-04, DT-D-02, DT-D-04 |
| AK-5 | Die Aufgabe ist I2 zugewiesen, nur I2 kann abhaken, der Fortschritt kommt auf G1 an. | DT-E-01, DT-E-02, DT-E-04, DT-E-05, DT-E-06 |
| AK-6 | Beide Konten werden über die App gelöscht, die App zeigt jeweils die Willkommensseite. | DT-F-01, DT-F-05, DT-F-07, DT-F-08 |
| AK-7 | Beide Konten existieren nicht mehr: Anmeldung mit richtigem Passwort scheitert. | DT-N-01, DT-N-02 |
| AK-8 | Kein Passwort (Konten und Postfach), kein E-Mail-Code, kein Notfall-Schlüssel und kein Einladungslink in Screenshots, Bericht oder Repository. | DT-N-06 |

## 9. Grenzfälle und bekannte Stolpersteine

- **Captcha:** Eine sichtbare Aufgabe löst immer der Mensch im Emulatorfenster; der Agent wartet. **E-Mail-Code:** holt der Agent per IMAP (`sandbox/mailcode.py`); scheitert IMAP, liest der Nutzer ihn im Webmail.
- **Bestätigungsmail bleibt aus:** Spam-Ordner per IMAP mit prüfen; nach 5 Minuten auf der Anbieter-Seite einmal „Code erneut senden“; danach ❌ mit Uhrzeit. Bleibt die Seite hängen, Zeit und Bild festhalten; nicht mehrfach Konten anlegen. Ein halb angelegtes Konto ist vor einem neuen Versuch zu löschen bzw. zu notieren.
- **Rückkehr bleibt aus** (DT-A-04, DT-B-05): 60 s warten, dann Seite schließen; zeigt die App „Die Anmeldung beim Anbieter wurde nicht abgeschlossen …“, ist das ❌ mit Plattform und Browser.
- **Einladungslink abgelaufen oder verbraucht:** neuen Link erzeugen, Ereignis im Bericht nennen.
- **Emulator stürzt beim Bild über die Emulator-Konsole ab** (bekannt): angelegte Konten feststellen und vor dem Abbau löschen (`AGENT_ANWEISUNG.md`, Abschnitt 7).
- **Kontolöschung schlägt fehl** oder kommt nicht zurück: Konto **nicht** aufgeben, sondern in der noch laufenden Sandbox über `https://account.matrix.org/account/` (Chrome im Emulator, `cdp.py`) löschen, das als ⚠️/❌ vermerken und erst danach DT-N ausführen. Ein Lauf endet nie mit einem bestehenden Wegwerfkonto.

## Versionshistorie

| Version | Datum | Änderung |
|---|---|---|
| v01 | 06.11.2026 | Erstfassung |
| v02 | 06.11.2026 | Server fest `matrix.org`, Test-Postfach `app_test@inneso.de` (Zugang in `secure/Test-Email.md`), Code-Abruf per IMAP durch den Agenten, neuer Schritt DT-V-05, Belege der Bestätigungsmail in DT-A-03/DT-B-05, Rückfall für die zweite Adresse |
| v03 | 06.11.2026 | Durchführung selbstständig in einer Sandbox (zwei eigene Android-Emulatoren `FN_E2E_G1`/`FN_E2E_G2`, frisch je Lauf); Agent legt Konten selbst an und löscht sie (`cdp.py`), Nutzer nur bei sichtbarem Captcha; Werkzeuge in `sandbox/`; Lauf-Ordner nach der Struktur von `User E2E Test Report/README.md` (`…_Default-G1-G2_<G1>-<G2>_Build<NN>`) |
| v03a | 06.11.2026 | Nach Lauf 23, ohne Änderung der Schritte: Sandbox-Emulatoren mit 4 GB, robuster Abbau, Absenden auf matrix.org per `cdp.py submit` mit Prüfung des Folgezustands und Fingertipp als Rückfall (`AGENT_ANWEISUNG.md`, `sandbox/`) |
