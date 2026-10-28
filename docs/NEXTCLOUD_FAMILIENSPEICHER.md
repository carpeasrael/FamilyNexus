# Familienspeicher auf Nextcloud (Feature-Beschreibung)

Stand: 2026-10-28 · Status: **abgestimmt, nicht umgesetzt** · Entscheidung: E-74 · Sicherheitsabweichung: SA-9

## 1. Ziel

FamilyNexus erhält einen **Familienspeicher** für Dateien (Dokumente, Fotos, Scans). Die Daten liegen auf einem
**Nextcloud-Server**, der frei wählbar ist – auch ein selbst betriebener. Es gibt zwei Bereiche:

| Bereich | Wer liest | Wer schreibt | Ort im Familienkonto |
|---|---|---|---|
| **Gemeinsamer Bereich** (Family Space) | alle beigetretenen Mitglieder und Moderatoren | alle beigetretenen Mitglieder und Moderatoren | `FamilyNexus/<familien-id>/shared` |
| **Privater Bereich** (je Person) | die Person selbst; bei Kindern **unter 14** zusätzlich die Moderatoren (Abschnitt 6) | nur die Person selbst | `FamilyNexus/<familien-id>/private/<personen-id>` |

Alle auf Nextcloud abgelegten Inhalte sind **Ende-zu-Ende-verschlüsselt**. Der Nextcloud-Server (und sein Betreiber)
sieht nur verschlüsselte Blöcke. Die Schlüssel des gemeinsamen Bereichs bekommen ausschließlich beigetretene
Familienmitglieder und Moderatoren – über die bestehende Matrix-E2EE der Familie.

Zusätzlich kann jede Person einstellen, ob ihre **Chat-Anhänge** auf dem Gerät oder im eigenen Bereich auf Nextcloud
liegen (Abschnitt 8).

## 2. Grundentscheidung: Nextcloud als „dummer“ verschlüsselter Speicher

- **Gewählt:** Verschlüsselung in FamilyNexus (clientseitig), Nextcloud dient nur als Ablage über **WebDAV**. Die
  Schlüssel werden über den Familienraum (Megolm) bzw. den privaten Raum (E-09) und den Matrix-Geheimspeicher (SSSS,
  Notfall-Schlüssel E-57) verteilt und gesichert.
- **Verworfen:** Nextclouds eigene Ende-zu-Ende-Verschlüsselung (App „end_to_end_encryption“): Schlüssel hängen an
  Nextcloud-Konten statt an Matrix-Identitäten, Rechte (E-10) müssten doppelt gepflegt werden, keine stabile
  Schnittstelle für Dritt-Apps, Vertrauen in die Server-PKI statt in die eigene Cross-Signing-Verifizierung.
- **Verworfen:** Nextcloud-Server-Side-Encryption – der Server hält die Schlüssel, keine E2EE.
- **Folge:** Nextcloud-Funktionen, die Klartext brauchen (Vorschaubilder, Volltextsuche, Online-Bearbeitung,
  Web-Oberfläche), funktionieren für diese Dateien **nicht**. Das ist gewollt.

## 3. Ein Nextcloud-Konto für die ganze Familie

### 3.1 Einrichtung
- Ein Moderator verbindet **ein** Nextcloud-Konto für die Familie („Familienkonto“) über **Login Flow v2** (Browser,
  wie OAuth in E-55). Die App erhält ein **App-Passwort**; das Kontopasswort berührt die App nie und bleibt beim
  Moderator bzw. Server-Betreiber.
- Die App legt `FamilyNexus/<familien-id>/` mit `shared/` und `private/` an.
- Zugangsdaten (`loginName`, App-Passwort, Generation) gehen als verschlüsseltes Raumereignis
  `de.inneso.familynexus.storage_credential` in den Familienraum – nur an cross-signierte Geräte
  (`ShareKeysWith.crossVerified`). Jedes Gerät legt sie im sicheren Schlüsselspeicher (`flutter_secure_storage`) ab,
  nie in Dateien oder Logs (`AppLog` redigiert sie).
- Mitglieder müssen nichts tun: Sobald Konfiguration, Zugangsdaten und Schlüssel angekommen sind, erscheint
  „Dateien“ in der App.
- Bevorzugt ein eigenes Konto nur für FamilyNexus (keine anderen Daten darin), ohne Administratorrechte.

### 3.2 Zuordnung von Dateien zu Personen
Auf Nextcloud lädt alles dasselbe Konto hoch – der Server weiß nicht, **wer** eine Datei abgelegt hat. Die Zuordnung
läuft deshalb über Matrix:
- Jede Änderung (hochladen, ersetzen, umbenennen, löschen) wird als verschlüsseltes Raumereignis
  `de.inneso.familynexus.storage_item` (`{ v: 1, area, fileId, version, hash, op }`) angekündigt.
  **Besitzer = Matrix-Absender**, wie bei Terminen (E-13/E-30).
- Ein Manifest-Eintrag gilt nur, wenn ein passendes `storage_item`-Ereignis eines berechtigten Absenders existiert
  (gleiche `fileId`, `version`, `hash`). Einträge ohne Beleg zeigt die App als „nicht bestätigt“ und nutzt sie nicht
  für Rechteprüfungen.
- Private Bereiche: Ereignisse über den privaten Raum der Person (E-09), nicht über den Familienraum.

### 3.3 Mitglied entfernen → Zugangsdaten erneuern
1. Moderator entfernt das Mitglied (bestehender Ablauf, E-10).
2. Die App des Moderators erneuert das App-Passwort (`POST /ocs/v2.php/core/apppassword/rotate`) und verteilt die
   neue Generation über `storage_credential` – die neue Megolm-Sitzung erreicht das entfernte Mitglied nicht mehr.
3. Bis die anderen Geräte die neue Generation empfangen haben, schlagen deren Zugriffe mit `401` fehl; die App wartet
   dann auf das nächste `storage_credential` und versucht es erneut (kein Fehlerdialog).
4. Danach Schlüsselwechsel (Abschnitt 5.4).

### 3.4 Grenzen des gemeinsamen Kontos (SA-9)
- Wer die Zugangsdaten hat, kann auf Nextcloud **jede** Datei löschen oder überschreiben, auch in fremden privaten
  Bereichen. **Lesen** kann er sie nicht (E2EE), **unbemerkt fälschen** auch nicht (AEAD + Hash im Manifest + Beleg
  per `storage_item`).
- Abhilfe: Papierkorb und Versionen von Nextcloud bleiben aktiv; die App erkennt fehlende oder veränderte Blobs und
  bietet „aus Version wiederherstellen“ an (`/remote.php/dav/versions/…`, `/remote.php/dav/trashbin/…`).
- Die Rechte aus Abschnitt 7 setzt nur die App durch, nicht der Nextcloud-Server.

## 4. Eigener Nextcloud-Server

- Eingabe der Server-URL beim Einrichten (Einstellungen → Familienspeicher). Vorbelegung ist **kein** Server –
  FamilyNexus empfiehlt keinen Anbieter.
- Prüfung (`NextcloudProbe`, analog `ServerProbe`):
  - nur `https://` (Network-Security-Config **und** `HttpsOnlyClient`, E-26); keine selbstsignierten Zertifikate,
  - `GET /status.php`: `installed`, `maintenance == false`, **Mindestversion 32.0.5**,
  - `GET /ocs/v2.php/cloud/capabilities`: WebDAV, Chunked Upload v2, Versionen, Papierkorb,
  - `PROPFIND` auf das Wurzelverzeichnis: `quota-available-bytes`, `quota-used-bytes` (Abschnitt 9).
- Server-URL, Pfad und Kontingent werden als verschlüsseltes Raumereignis `de.inneso.familynexus.storage_config`
  (`{ v: 1, url, root, quotaGb, minVersion: "32.0.5" }`) im Familienraum veröffentlicht. Nur Moderatoren dürfen es
  setzen (Prüfung in App **und** Power-Level 50 für den Ereignistyp).
- Ist der verbundene Server älter als 32.0.5 (z. B. nach einem Zurückspielen), sperrt die App Schreibzugriffe und
  zeigt einen Hinweis; Lesen bleibt möglich.
- Serverwechsel: neue Konfiguration + Umzug durch die App (herunterladen, unverändert verschlüsselt hochladen –
  Neuverschlüsselung nicht nötig). Späteres Ausbauziel.
- `docs/EIGENER_SERVER.md` erhält einen Abschnitt „Eigene Nextcloud“: TLS, eigenes Konto für FamilyNexus,
  Benutzerkontingent (bis 1024 GB), Upload-Grenzen des Reverse-Proxys, Papierkorb und Versionen aktiv lassen.

## 5. Verschlüsselung

### 5.1 Schlüsselhierarchie
```
Familienspeicher-Schlüssel FSK (256 Bit, je Epoche e)    Privater Speicher-Schlüssel PSK (256 Bit, je Person, je Epoche)
          │ verteilt über Familienraum (Megolm)                 │ verteilt über privaten Raum (E-09);
          │ gesichert im SSSS jedes Mitglieds                    │ unter 14 zusätzlich an Moderatoren (Abschnitt 6)
          ▼                                                      ▼
   Manifest des Bereichs, AEAD-verschlüsselt mit FSK_e bzw. PSK_e
          │ enthält je Datei: Name, Typ, Größe, Besitzer, Zeitstempel, Dateischlüssel DEK, Hash
          ▼
   Datei-Inhalt, verschlüsselt mit zufälligem DEK (je Datei, je Version neu)
```

- **Umschlagverschlüsselung:** Jede Datei hat einen eigenen zufälligen DEK, der nur im verschlüsselten Manifest
  steht. Bei einem Schlüsselwechsel muss nur das Manifest neu verschlüsselt werden, nicht jede Datei.
- **Algorithmen (Vorschlag):** AES-256-GCM für Manifest und Inhalte; Inhalte in Blöcken zu 64 KiB mit Blockzähler und
  „letzter Block“-Kennzeichen in den Zusatzdaten (Schutz gegen Umsortieren/Abschneiden), damit große Dateien
  gestreamt werden können. Die Bibliothek wird in `ABHAENGIGKEITEN.md` geprüft (Lizenz, Pflege, Plattformen inkl.
  Web); `vodozemac` bietet keine allgemeine Datei-AEAD.
- **Zusatzdaten (AAD):** Familien-ID, Bereich (`shared`/`private:<person>`/`attachments:<person>`), Datei-ID,
  Epoche, Formatversion. Eine Datei kann so nicht unbemerkt in einen anderen Bereich verschoben werden.

### 5.2 Ablageformat auf Nextcloud
```
FamilyNexus/<familien-id>/
  shared/manifest.fnx                     verschlüsseltes Verzeichnis (ETag-gesichert)
  shared/blobs/<zufalls-id>.fnx           verschlüsselte Inhalte
  private/<personen-id>/manifest.fnx
  private/<personen-id>/blobs/<zufalls-id>.fnx
  attachments/<personen-id>/<zufalls-id>.fnx   Chat-Anhänge (Abschnitt 8)
```
- `<personen-id>` ist ein zufälliger, pro Familie fester Bezeichner (nicht die Matrix-ID); die Zuordnung steht nur im
  verschlüsselten Familienraum.
- Kopf jeder `.fnx`-Datei: Magic `FNX1`, Formatversion, Bereich, Epoche bzw. Schlüssel-ID, Nonce-Präfix.
- **Dateinamen, Ordnerstruktur, Typen und Besitzer** stehen nur im verschlüsselten Manifest.
- Für den Server sichtbar bleiben: Anzahl der Dateien je Bereich, ungefähre Größen, Zeitpunkte. Optional: Auffüllen
  auf Größenklassen (Padding) – Kosten: Speicher und Kontingent.

### 5.3 Schlüsselverteilung gemeinsamer Bereich
- Erzeugung durch den Moderator, der den Speicher einrichtet: FSK Epoche 1.
- Verteilung als verschlüsseltes Raumereignis `de.inneso.familynexus.storage_key` (`{ v: 1, epoch, key, createdBy }`)
  im Familienraum, nur an cross-signierte Geräte – dieselbe Vertrauensgrenze wie für Chat und Kalender.
- **Neue Mitglieder:** Megolm gibt alte Sitzungen nicht an Neue weiter. Nach dem Beitritt sendet die App eines
  Moderators (Ersatz: eines beliebigen beigetretenen Mitglieds, wie der Einkaufszettel-Resync) Konfiguration,
  aktuelle Zugangsdaten und alle gültigen Epochen erneut.
- **Gerätewiederherstellung:** Jedes Gerät legt bekannte FSK-Epochen zusätzlich im SSSS ab (Geheimnis
  `de.inneso.familynexus.storage_keys`). Mit dem Notfall-Schlüssel (E-57) ist der Speicher auf einem neuen Gerät
  sofort wieder lesbar.
- Annahme eines Schlüssels nur, wenn verschlüsselt angekommen (E-27), Absender beigetretenes Mitglied, Epoche neu
  bzw. identisch mit bekanntem Wert. Abweichender Schlüssel für eine bekannte Epoche → Warnung, nicht übernehmen.

### 5.4 Entfernen eines Mitglieds (Schlüsselwechsel)
1. Zugangsdaten erneuern (3.3) → das entfernte Mitglied kommt nicht mehr an die verschlüsselten Dateien.
2. Neue Epoche `e+1`: neuer FSK an die verbleibenden Mitglieder; Manifest mit `FSK_{e+1}` neu verschlüsselt. Neue
   Dateien und neue Versionen erhalten neue DEKs.
3. Bekannte Grenze: Was das entfernte Mitglied vorher geöffnet oder heruntergeladen hat (inkl. DEKs alter Dateien),
   kann es behalten. „Neu verschlüsseln“ einzelner Dateien (neuer DEK, neues Blob, altes löschen) ist möglich; die App
   erklärt das, statt mehr zu versprechen.

### 5.5 Privater Bereich
- PSK entsteht beim ersten Öffnen von „Privat“, liegt im SSSS des Kontos und wird über den privaten Raum (E-09) an
  eigene, verifizierte Geräte verteilt. **Nie** im Familienraum.
- Durchsetzung wie bei privaten Terminen: getrennte Typen (`SharedStorageItem` / `PrivateStorageItem`), getrennte
  Sendewege; ein Test belegt, dass PSK und private Manifeste den Familienraum nie erreichen.
- Ausnahme Kinder unter 14: Abschnitt 6.

## 6. Kinder unter 14 Jahren

- **Regel:** Unter 14 Jahren ist der private Bereich für die **Moderatoren lesbar** (nicht schreibbar). Ab 14 ist er
  vollständig privat.
- **Angabe:** Ein Moderator setzt für ein Mitglied „privat ab“ (Datum des 14. Geburtstags) – kein Geburtsdatum.
  Verschlüsseltes Raumereignis `de.inneso.familynexus.member_privacy` (`{ v: 1, userId, privateFrom }`), nur von
  Moderatoren angenommen. Ohne Angabe gilt das Mitglied als 14 oder älter (privat).
- **Schlüssel:** Solange `privateFrom` in der Zukunft liegt, sendet die App des Kindes jede PSK-Epoche zusätzlich als
  Olm-verschlüsselte Gerätenachricht an die verifizierten Geräte der beigetretenen Moderatoren; diese legen sie in
  ihrem SSSS ab. Andere Mitglieder erhalten den PSK nie.
- **Übergang mit 14:** Am Stichtag erzeugt die App des Kindes eine neue PSK-Epoche, die **nur** an eigene Geräte geht,
  und verschlüsselt im Hintergrund **alle** bestehenden privaten Dateien neu (neue DEKs, neue Blobs, alte löschen) –
  so sind auch früher hochgeladene Inhalte danach nicht mehr mit den Schlüsseln der Moderatoren lesbar. Fortschritt
  sichtbar, fortsetzbar nach Abbruch. Gilt auch für Anhänge (Abschnitt 8).
- **Nicht umkehrbar:** Ist ein Mitglied einmal privat, ignoriert seine App spätere `member_privacy`-Ereignisse, die
  `privateFrom` in die Zukunft verlegen. Eine Angabe für ein Mitglied, das schon Dateien als „privat“ hat, wird
  ebenfalls ignoriert.
- **Transparenz:** Das Kind sieht in „Privat“ dauerhaft den Hinweis „Bis <Datum> können die Moderatoren deiner Familie
  diesen Bereich lesen.“ Ab dem Stichtag: „Nur du kannst diesen Bereich lesen.“
- Bezug: ergänzt E-11 (Minderjährige); Hinweis zur Einwilligung der Sorgeberechtigten im Datenschutztext ergänzen.

## 7. Rechte

| Aktion | Mitglied | Moderator |
|---|---|---|
| Gemeinsamen Bereich lesen, herunterladen | ✔ | ✔ |
| Datei hochladen, Ordner anlegen | ✔ | ✔ |
| Eigene Datei umbenennen, ersetzen, löschen | ✔ | ✔ |
| Fremde Datei im gemeinsamen Bereich löschen / umbenennen | ✘ | ✔ (landet im Nextcloud-Papierkorb) |
| Speicher einrichten, Server/Kontingent ändern, Zugangsdaten und Schlüssel erneuern | ✘ | ✔ |
| „Privat ab“ für ein Mitglied setzen | ✘ | ✔ |
| Privaten Bereich eines Kindes unter 14 lesen | ✘ | ✔ (nur lesen) |
| Privaten Bereich anderer ab 14 lesen | ✘ | ✘ |

- Neue Regeln in `domain/permissions.dart`: `canConfigureStorage`, `canDeleteStorageItem(owner, me, isModerator)`,
  `canReadPrivateArea(target, me, today)`.
- Anders als bei Terminen (E-10) dürfen Moderatoren fremde Dateien löschen – sonst ließe sich der Speicher nicht
  aufräumen. Der Besitz (3.2) bleibt im Manifest erhalten; die Löschung wird mit Absender protokolliert.

## 8. Chat-Anhänge: Gerät oder Nextcloud (Einstellung je Person)

Einstellungen → Chat → „Anhänge speichern“: **Auf dem Gerät** (Standard) oder **In meinem Nextcloud-Bereich**.
Die Einstellung liegt in `AppSettings` (lokal, je Gerät; über den privaten Raum auf die eigenen Geräte gespiegelt).
Ohne eingerichteten Familienspeicher ist nur „Auf dem Gerät“ wählbar.

| | Auf dem Gerät | In meinem Nextcloud-Bereich |
|---|---|---|
| Eigene gesendete Anhänge | wie heute (E-19): verschlüsselt über den Matrix-Server, Kopie im verschlüsselten Cache | verschlüsselt nach `attachments/<personen-id>/`; die Nachricht enthält Verweis + DEK + Hash (Megolm) statt Matrix-Medien |
| Empfangene Anhänge | Cache in der verschlüsselten Datenbank (Gerätespeicher) | nach dem Öffnen nicht im Gerätespeicher behalten, sondern bei Bedarf erneut laden; ausdrücklich „behalten“ legt eine neu verschlüsselte Kopie im eigenen Anhangs-Bereich ab |

- Empfänger können Nextcloud-Anhänge immer lesen, unabhängig von **ihrer** Einstellung – alle Geräte der Familie haben
  die Zugangsdaten (3.1), der DEK steht in der Nachricht.
- Nachrichtenformat: `msgtype` wie bisher, zusätzlich `de.inneso.familynexus.nc_file: { v: 1, path, key, iv, hash,
  size, mime }`. Ältere App-Versionen zeigen den Text-Fallback „Anhang im Familienspeicher – bitte App aktualisieren“.
- Regeln aus E-19 gelten unverändert in beiden Varianten (Allowlist, 25 MB, bereinigter Dateiname, keine
  automatische Ausführung). Nextcloud-Anhänge zählen gegen das Familienkontingent.
- Wechsel der Einstellung wirkt nur für **neue** Anhänge; bestehende bleiben, wo sie sind. Optional später:
  „vorhandene Anhänge verschieben“.
- Löscht eine Person ihre Anhänge oder ihr Konto (E-73), sind Verweise in alten Nachrichten nicht mehr ladbar; die App
  zeigt „Anhang nicht mehr verfügbar“.
- Datenschutz: Bei „Nextcloud“ liegen Anhänge nicht mehr auf dem Matrix-Server, sondern verschlüsselt auf dem
  Nextcloud-Server der Familie.

## 9. Kontingent (bis 1024 GB, in Server und App)

- **Moderator** legt das Familienkontingent fest: 1 GB bis **1024 GB** (Schieberegler/Eingabe in GB, Standard 10 GB).
  Wert in `storage_config.quotaGb`; jederzeit änderbar (vergrößern und verkleinern).
- **Server:** Das Nextcloud-Benutzerkontingent des Familienkontos setzt der Server-Betreiber (Anleitung in
  `EIGENER_SERVER.md`); die App liest es per `PROPFIND` (`quota-available-bytes`, `quota-used-bytes`).
- **App:** Wirksam ist das **kleinere** von App-Kontingent und Server-Kontingent. Vor jedem Upload prüft die App
  `belegt + Dateigröße (verschlüsselt) ≤ wirksames Kontingent`; reicht der Platz nicht, wird nicht hochgeladen
  („Familienspeicher voll – Moderator kann das Kontingent erhöhen“). Eine eigene Grenze je Datei gibt es nicht; große
  Dateien gehen über **Chunked Upload v2**.
- Ist das Server-Kontingent kleiner als das eingestellte App-Kontingent, sehen Moderatoren den Hinweis „Server erlaubt
  nur X GB“.
- Anzeige: belegt/frei gesamt sowie je Bereich (gemeinsam, privat je Person, Anhänge je Person) aus den Manifesten.
- Verkleinern unter die aktuelle Belegung löscht nichts; nur neue Uploads werden gesperrt, bis Platz frei ist.

## 10. Gleichzeitiges Arbeiten

- Manifest-Änderungen mit **optimistischem Sperren**: `PUT` mit `If-Match: <ETag>`. Bei `412` lädt die App das
  Manifest neu, führt die Änderung erneut zusammen (Einträge mit IDs und Versionen wie Termine/Einkaufszettel) und
  versucht es erneut (begrenzt, mit Rückoff).
- Blobs werden **vor** dem Manifest-Eintrag hochgeladen; verwaiste Blobs (ohne Manifest-Eintrag, älter als 24 h)
  räumt ein Moderator-Gerät auf.
- Andere Geräte erfahren Änderungen über die `storage_item`-Ereignisse (3.2), nicht über Abfragen in festen
  Abständen.

## 11. Lokale Speicherung und Plattformen

- Kein Klartext im Dateisystem (E-19): Vorschau nur im Arbeitsspeicher; Zwischenspeicher nur verschlüsselt (Blobs wie
  vom Server) bzw. in der SQLCipher-Datenbank (Manifest-Kopie). Ausnahme wie SA-3: bewusstes „Datei speichern/öffnen
  mit…“ durch den Nutzer, mit Hinweis.
- Dateien im Familienspeicher: Allowlist und Namensbereinigung aus `AttachmentPolicy`, Größe nur durch das Kontingent
  begrenzt, keine automatische Ausführung.
- Upload/Download im Hintergrund mit Fortschritt, Abbruch und Wiederaufnahme (Chunked Upload).
- **Web-Version (E-53):** Nextcloud sendet für WebDAV standardmäßig keine CORS-Header. Ohne Anpassung am Server (oder
  Proxy) ist der Familienspeicher im Browser nicht nutzbar → OFFEN.md, Hinweis in der App; Anhänge fallen dort auf
  „Auf dem Gerät“ zurück.

## 12. Architektur (Einordnung)

```
domain/storage/            StorageItem (shared/private/attachment), Manifest + Codec (Format v1), Zusammenführung,
                           StorageKeyRing (Epochen), PrivacyRule (unter 14), Quota, Pfad-/Namensregeln
data/storage/              NextcloudProbe, NextcloudAuth (Login Flow v2, App-Passwort-Rotation), WebDavClient
                           (über HttpsOnlyClient), StorageCrypto (AEAD, Blockformat), SqlStorageCache
data/sync/StorageSync      Manifest ↔ Dienst; storage_config/credential/key/item, member_privacy ↔ MatrixGateway
data/matrix/               MatrixGateway: sendStorageEvent / storageEvents, Gerätenachrichten an Moderatoren,
                           SSSS-Geheimnisse lesen/schreiben, Anhänge mit nc_file senden/lesen
features/storage/          Ansicht „Dateien“ (Tabs Gemeinsam / Privat), Einrichtung, Kontingent, Fortschritt
features/settings/         „Anhänge speichern“, „Familienspeicher“
```
- Schichtenregeln gelten unverändert (Architekturtest): `features` kennt kein WebDAV und keine Kryptobibliothek.
- `FakeNextcloud` in `test/support` (WebDAV, Kontingent, Versionen, App-Passwort-Rotation im Speicher).

## 13. Abnahmekriterien

1. Ein Moderator bindet einen beliebigen Nextcloud-Server ≥ 32.0.5 mit gültigem TLS ein; ältere Versionen,
   `http://` und selbstsignierte Zertifikate werden abgelehnt.
2. Jedes beigetretene Mitglied und jeder Moderator liest und beschreibt den gemeinsamen Bereich, ohne selbst
   Zugangsdaten oder Schlüssel einzugeben.
3. Private Bereiche ab 14 kann niemand außer der Person lesen (Test: PSK/Manifest nie im Familienraum, nie an
   Moderatoren).
4. Private Bereiche unter 14 können Moderatoren lesen, aber nicht ändern; andere Mitglieder nicht. Nach dem Stichtag
   sind alle privaten Dateien neu verschlüsselt und mit den Schlüsseln der Moderatoren nicht mehr lesbar (Test).
5. Auf dem Server liegen nur `.fnx`-Dateien mit zufälligen Namen; keine Klartext-Dateinamen, -Inhalte oder -Typen
   (Test gegen echten Nextcloud-Container 32.0.5).
6. Ein entferntes Mitglied: altes App-Passwort ungültig, keine neuen Schlüssel; danach hochgeladene Dateien sind für
   es nicht entschlüsselbar.
7. Ein neues Gerät desselben Kontos liest nach Eingabe des Notfall-Schlüssels alle berechtigten Bereiche.
8. Manipulierte, vertauschte oder abgeschnittene Blobs werden erkannt, nicht angezeigt, und Wiederherstellung aus
   Nextcloud-Versionen wird angeboten.
9. Upload über das wirksame Kontingent (min. von App und Server, höchstens 1024 GB) wird abgelehnt, bevor Daten
   übertragen werden.
10. „Anhänge in Nextcloud“: gesendeter Anhang liegt verschlüsselt unter `attachments/`, nicht auf dem Matrix-Server;
    Empfänger mit Einstellung „Gerät“ können ihn öffnen.
11. Zwei gleichzeitige Uploads verlieren keinen Manifest-Eintrag.
12. Keine Zugangsdaten, URLs mit Token oder Dateinamen im Log.

## 14. Umsetzung in Phasen

| Phase | Inhalt |
|---|---|
| **S1** | Domäne (Manifest, Codec, Schlüsselring, Rechte, Kontingent, Regel unter 14), `StorageCrypto` mit Testvektoren, `FakeNextcloud` |
| **S2** | Einrichtung durch Moderator: Probe (≥ 32.0.5), Login Flow v2, `storage_config`/`storage_credential`/`storage_key`, gemeinsamer Bereich, Ansicht „Gemeinsam“, Kontingent |
| **S3** | Private Bereiche inkl. Regel unter 14 (Gerätenachrichten an Moderatoren, Übergang mit Neuverschlüsselung), Ansicht „Privat“ |
| **S4** | Mitgliederwechsel: Resync für Neue, App-Passwort-Rotation, Epochenwechsel, Aufräumen, Wiederherstellung aus Versionen |
| **S5** | Chat-Anhänge in Nextcloud (Einstellung, `nc_file`), Chunked Upload, Hintergrundübertragung, `EIGENER_SERVER.md`, E2E-Tests gegen Nextcloud-Container in `tool/e2e.sh` |
| später | Serverumzug, vorhandene Anhänge verschieben, Padding, Web-Version mit CORS-Anleitung |

## 15. Entscheidungen der Abstimmung (2026-10-28)

| Frage | Entscheidung |
|---|---|
| Moderatoren dürfen fremde Dateien löschen? | Ja |
| Nextcloud-Konten | Ein Konto für die ganze Familie |
| Mindestversion Nextcloud | 32.0.5 |
| Größe | Kontingent skalierbar bis 1024 GB, durchgesetzt in Server und App |
| Chat-Anhänge | Einstellung je Person: Gerätespeicher oder eigener Nextcloud-Bereich |
| Privater Bereich Minderjähriger | Unter 14: Moderatoren können lesen; ab 14: vollständig privat |
