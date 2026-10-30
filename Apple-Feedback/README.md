# Apple-Feedback: Guideline 2.1 – Information Needed

Stand: 30.10.2026 · Quellstand: `e4180fb` · Repository-Version: **1.2.1 (21)**.

Dieses Paket beantwortet die sechs Punkte der bereitgestellten Apple-Rückmeldung. Die Funktionsbeschreibungen sind mit dem Repository abgeglichen. Der tatsächlich in App Store Connect ausgewählte Build, die Prüfkonten, die Länderfreigabe und die Geräteaufnahme sind hier **noch nicht bestätigt**. Es wurde nichts an Apple übermittelt.

## Unterlagen

| Datei | Verwendung |
|---|---|
| [01_Antwort_und_Review_Notes_EN.txt](01_Antwort_und_Review_Notes_EN.txt) | Gemeinsamer englischer Text für die Antwort an App Review **und** das Feld „App Review Information → Notes“; vor Verwendung vervollständigen |
| [02_Review_Guide_EN.md](02_Review_Guide_EN.md) | Ausführliche englische Anleitung für Einrichtung, Hauptfunktionen, Rollen und Kontolöschung; als ergänzende Anlage geeignet |
| [03_Video_und_Geraetepruefung_DE.md](03_Video_und_Geraetepruefung_DE.md) | Vorbereitung, Aufnahmedrehbuch, auszufüllendes Geräte- und QA-Protokoll |
| [04_Dienste_Regionen_Nachweise_DE.md](04_Dienste_Regionen_Nachweise_DE.md) | Beleggrundlage zu Diensten, regionalen Unterschieden, Lizenzen und noch zu bestätigenden Nachweisen |
| [sample-files/review-attachment.txt](sample-files/review-attachment.txt) | Optionale harmlose Beispieldatei für den Chat-Anhang |

## Noch zu ergänzen

Alle Angaben in `[...]` im Antworttext sind Platzhalter. Die Datei ist ein **Entwurf**, bis diese ersetzt und die Aussagen am eingereichten Build geprüft sind.

| Feld | Benötigte Angabe / Nachweis |
|---|---|
| `VERSION/BUILD`, `PLATFORM` | Tatsächlich eingereichte Version und Buildnummer sowie iOS oder macOS; bei beiden Plattformen getrennte Angaben |
| `VIDEO_URL`, `DEVICE`, `OS`, `DATE` | Erreichbares Video, physisches Gerätemodell, Betriebssystemversion und Aufnahmedatum |
| `QA_RESULT_AND_REPORT` | Wahrheitsgemäßes Ergebnis des Gerätetests einschließlich Report-Verweis und gegebenenfalls verbleibender Einschränkungen |
| `R1_KEY` | Notfall-Schlüssel des Moderator-Prüfkontos; dessen Benutzername und Passwort zusätzlich unter „Sign-in information“ eintragen |
| `R2_USER`, `R2_PASSWORD`, `R2_KEY` | Zugangsdaten und eigener Notfall-Schlüssel für das Mitglied-Prüfkonto |
| `STOREFRONTS` | Tatsächliche Länderfreigabe laut App Store Connect, insbesondere Entscheidung zu Frankreich |
| `RIGHTS_AND_EXPORT_STATUS` | Bestätigter Stand der Lizenzprüfung und der Verschlüsselungsunterlagen; nur tatsächlich vorhandene Anlagen oder Vorgänge nennen |

Die Vorlagen setzen wie der bestehende Verifikationsplan **matrix.org** für die Prüfkonten voraus. Bei einem anderen Anbieter Serveradresse, Anmeldeschritte, Registrierung, Löschung, Diensteübersicht und Video gemeinsam anpassen. Ein eigener Testserver mit Passwort-Anmeldung belegt den Browserablauf bei matrix.org nicht.

Ausgefüllte Kopien mit Zugangsdaten nur im bereits von Git ausgeschlossenen Verzeichnis `secure/` oder im Passwortmanager speichern. Keine echten Passwörter oder Notfall-Schlüssel in diese Dokumente committen. R1 und R2 müssen während der gesamten Review verfügbar bleiben; nur ein separates Wegwerfkonto im Video löschen.

## Stand der Nachweise

- Der [jüngste im Index erfasste Testlauf](../Test-Apple-Report/2026-10-29_13_macOS-iOS_Build20/Testreport.md) betrifft Build 20, macOS und einen iPhone-Simulator. Er enthält offene Schritte und Befunde. Er belegt keinen vollständigen Test von Build 21 auf einem physischen iPhone.
- [TP-FN-VR-121](../Test-Apple/verification_1.2.1/Testplan_Verifikation_App_Review.md) enthält bereits die detaillierten Prüfungen für die sechs Apple-Punkte. Das vorliegende Paket liefert die dazugehörigen Antwortunterlagen und ersetzt den Testplan nicht.
- [Bekannte Einschränkungen](../docs/OFFEN.md) nennen insbesondere den noch ausstehenden Gerätenachweis für die OAuth-Kontolöschung bei matrix.org. Diesen Ablauf vor der Rückmeldung vollständig prüfen.
- Die [Exportunterlagen](../docs/export-compliance/README.md) sind vorbereitete Entwürfe für einen älteren Build; eine behördliche oder Apple-Genehmigung ist daraus nicht ableitbar.

## Vor dem Absenden

1. Tatsächlichen Build festhalten; R1 als Moderator und R2 als Mitglied derselben Beispielfamilie vorbereiten. Beide Anmeldungen einschließlich Entschlüsselung auf einem frisch eingerichteten Gerät prüfen.
2. Den eingereichten Build gemäß [Gesamtplan](../Test-Apple/Testplan_FamilyNexus.md) auf den unterstützten physischen Geräteplattformen testen. Aufnahme auf einem physischen Gerät mit dem neuesten veröffentlichten Betriebssystem erstellen. Ergebnisse in Dokument 03 eintragen.
3. Video-Link ohne Anmeldung/Freigabeanfrage prüfen. Registrierung, Anmeldung, echte Kontolöschung, Nutzerinhalte, Melden und Blockieren müssen erkennbar sein.
4. Platzhalter ersetzen; regionale Verfügbarkeit, Altersfreigabe, Support-/Datenschutzangaben und Lizenz-/Exportstatus mit App Store Connect abgleichen. Die Datenschutzvorlagen im Repository enthalten noch Herausgeber-Platzhalter; veröffentlichte Angaben gesondert prüfen.
5. Den vervollständigten Text aus Dokument 01 sowohl in die Antwort als auch in „Notes“ übernehmen. R1 unter „Sign-in information“, R2 samt Schlüssel in „Notes“ angeben. Auf beiden Plattformen separat hinterlegen, falls beide eingereicht werden.
6. Gespeicherte Notizen wieder öffnen und auf Vollständigkeit prüfen. Alte Kurznotizen nicht zusätzlich anhängen; sie würden Inhalt doppeln und könnten widersprüchlich sein. Video und ergänzende Anleitung zuordnen.

Apple begrenzt „Notes“ auf **4.000 Bytes** und sieht zusätzliche Prüfkonten in diesem Feld vor. Nach Ersetzen der Platzhalter deshalb die UTF-8-Bytezahl prüfen, beispielsweise mit `wc -c secure/apple-review-notes.txt`. Alle sechs Antworten und beide Kontozugänge müssen erhalten bleiben. Quelle: [Apple – App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/#app-review-information).

Die abschließende Kontrolle umfasst außerdem tatsächliche App-Screenshots, funktionierende Links, unveränderte Erreichbarkeit der Prüfkonten und den öffentlich nutzbaren Familien-Anwendungsfall. Die App enthält laut Code keine In-App-Käufe; bei einer späteren Änderung muss dieser Abschnitt erneut geprüft werden. Grundlage: die bereitgestellte Rückmeldung und [Apples App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
