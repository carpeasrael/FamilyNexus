# Testdaten und Vorprüfung (gilt für alle Testpläne)

Gilt für: `Testplan_Nutzeranlage.md`, `Testplan_Pruefanleitung.md`, `Testplan_Einladung_Zweiter_Nutzer.md`
Stand: 26.10.2026

Dieses Dokument ist die einzige Quelle für (1) die Vorprüfung vor jedem Testlauf, (2) die Stammdaten (Konten, Familien, Beispieldaten, Schlüssel) und (3) die Reihenfolge und das Aufräumen. Die Testpläne verweisen hierher, statt eigene Konten anzulegen.

## 1. Vorprüfung (vor **jedem** Testplan, Ergebnis im Report)

### TV-01 Ist die aktuellste Version installiert?

Soll-Version = `version:` in `pubspec.yaml` auf dem aktuellen `main` (Format `Version+Build`, derzeit `1.2.1+16` = „1.2.1 (16)“).

```sh
git fetch origin && git status -sb          # main muss auf origin/main stehen, sonst: git pull --ff-only
grep '^version:' pubspec.yaml               # Soll, z. B. 1.2.1+16
```

Ist-Version je Testgerät mit dem Soll vergleichen; **bei Abweichung zuerst neu bauen bzw. installieren, nicht testen**:

| Gerät | Ist-Version ablesen |
|---|---|
| Mac-App | `defaults read /Applications/FamilyNexus.app/Contents/Info CFBundleShortVersionString CFBundleVersion` (zwei Werte: Version, Build) |
| iPhone-Simulator | `xcrun simctl listapps booted \| grep -A12 -i familynexus` (`CFBundleShortVersionString`, `CFBundleVersion`) |
| iPhone/iPad (TestFlight) | App: Menü unten bzw. Einstellungen → „Über die App“ → „Version x.y.z (n)“; in TestFlight muss derselbe Build als neuester angezeigt werden |
| Jedes Gerät | zusätzlich in der App: Menü/„Über die App“ zeigt „Version …“ – muss dem Soll entsprechen |

Der Report nennt für jedes Gerät Soll, Ist und Ergebnis (✅ gleich / ❌ abweichend → nachinstalliert, dann erneut prüfen). Die Versionen in den Plänen (Kopfzeile) sind nur der Stand beim Schreiben; maßgeblich ist das Soll aus `pubspec.yaml`.

### TV-02 Server erreichbar, Registrierung offen

```sh
S=https://matrix-synapse-3ues.srv1348446.hstgr.cloud
curl -s $S/_matrix/client/versions                      # JSON mit "versions"
curl -s -X POST -H 'Content-Type: application/json' -d '{}' $S/_matrix/client/v3/register   # "flows" mit m.login.dummy
```

### TV-03 Benutzernamen sind frei (vor dem Anlegen)

Für **jeden** Benutzernamen, den der Lauf neu anlegt (Spalte „angelegt in“ in Abschnitt 2), vorher prüfen:

```sh
for u in fnt-MMTT-n1 fnt-MMTT-n12 fnt-MMTT-i2; do
  echo "$u: $(curl -s "$S/_matrix/client/v3/register/available?username=$u")"
done
```

- `{"available":true}` → frei, darf angelegt werden.
- `M_USER_IN_USE` (400) → **existiert schon**. Nicht anlegen. Datumsteil ändern (am selben Tag Buchstaben anhängen: `MMTT` → `1027b`), Stammdaten-Tabelle mit den neuen Namen führen und TV-03 wiederholen. Ein bewusst vorhandener Name (z. B. `n1` in TN-15 als Negativprobe) ist davon ausgenommen.
- Länge beachten: Benutzername höchstens 32 Zeichen.
- Alte Testkonten früherer Läufe (anderes Datum) werden hier nicht benutzt; sie gehören nicht zu den Stammdaten dieses Laufs.

Zusätzlich auf jedem Gerät: vor dem ersten Schritt prüfen, ob die App noch ein altes Konto/Daten enthält (Startbild „Willkommen“ = leer). Wenn nicht: Einstellungen → „Alle lokalen Daten löschen“, sofern der Plan nicht ausdrücklich ein bestehendes Konto aus den Stammdaten braucht.

## 2. Stammdaten-Register (pro Testlauf, `MMTT` = Datum des Laufs)

Jedes Konto, jede Familie und jedes Beispieldatum wird **einmal** angelegt und in den späteren Plänen wiederverwendet. Spalte „Zustand“ im Report mitführen (offen / angelegt / gelöscht).

### Konten

| Kürzel | Benutzername | Anzeigename | angelegt in | wiederverwendet in | gelöscht in |
|---|---|---|---|---|---|
| **N1** | `fnt-MMTT-n1` | Test N1 | `Testplan_Nutzeranlage` TN-09 | Prüfanleitung TC-04 ff., Einladung (Nutzer 1) | Einladung TI-27 (Schlussaufräumen) |
| **N2** | `fnt-MMTT-n12` | Test N2 | `Testplan_Nutzeranlage` TN-15 | Prüfanleitung TC-16 | Prüfanleitung TC-16 |
| **I2** | `fnt-MMTT-i2` | Test Nutzer 2 | `Testplan_Einladung` TI-10 (Anlage **über Einladungslink**, eigener Weg) | – | Einladung TI-25 |

Passwörter erzeugt der Tester beim Anlegen (mind. 8 Zeichen, Passwortmanager), nicht in Pläne oder Reports schreiben (maskiert).

### Notfall-Schlüssel

| Kürzel | Gehört zu | Entsteht in | Gültig bis |
|---|---|---|---|
| **KN1** | N1, erster Schlüssel | TN-10 | Erneuerung in Prüfanleitung TC-12 |
| **KN1b** | N1, nach Erneuerung | Prüfanleitung TC-12 | bis zum Ende (Einladung nutzt den **aktuell gültigen** Schlüssel von N1: KN1b, falls TC-12 gelaufen ist, sonst KN1) |
| **KN2** | N2 | TN-15 | bis zur Löschung |
| **KI2** | I2 | TI-11 | bis zur Löschung |

### Familien

| Kürzel | Name | Moderator / Mitglieder | angelegt in | wiederverwendet in |
|---|---|---|---|---|
| **F1** | Testfamilie MMTT | N1 (Moderator); später I2 | TN-11 | Prüfanleitung TC-06 ff., Einladung TI-05 ff. |
| **F2** | Löschtest MMTT | N2 (allein, Moderator) | TN-15 | Prüfanleitung TC-16 |

### Beispieldaten in F1

| Daten | angelegt in | wiederverwendet in |
|---|---|---|
| Geteilter Termin „Test geteilt“ (morgen 10:00) | Prüfanleitung TC-08 | Einladung TI-17 (bei I2 sichtbar) |
| Privater Termin „Test privat“ | Prüfanleitung TC-08 | Einladung TI-17 (bei I2 **nicht** sichtbar) |
| Chat „Hallo Testfamilie“ | Prüfanleitung TC-09 | Prüfanleitung TC-13 (auf G2 lesbar) |
| Einkauf „Milch“ | Prüfanleitung TC-10 | Einladung TI-18 (nur Einblick) |

Läuft ein Plan ohne den vorherigen (z. B. nur Einladung), legt er die fehlenden Stammdaten **an der dort angegebenen Stelle** an, trägt sie ins Register ein und führt die Nachholung im Report auf.

## 3. Regeln zur Wiederverwendung

1. **Vor jedem Anlegen** (Konto, Familie, Termin, Eintrag) das Register prüfen: Gibt es das Objekt aus einem früheren Testfall dieses Laufs, wird es **verwendet, nicht neu angelegt**. Die zugehörige Anlage wurde dort bereits getestet.
2. **Jeder Weg wird einmal getestet:** Kontoanlage in der App (TN), Kontoanlage über Einladungslink (TI-10), Notfall-Schlüssel beim neuen Konto (TN-10; bei I2 ergänzend TI-11, weil anderer Einstieg), Schlüssel erneuern (TC-12), Löschen mit falschem/richtigem Passwort (TC-16), Löschen als einziger Moderator mit Hinweis (TI-24), Löschen eines Mitglieds mit Austragen (TI-25).
3. **Anmeldung statt Neuanlage:** Braucht ein Testfall ein Konto auf einem anderen Gerät, wird mit Benutzername (kurz), Passwort und Notfall-Schlüssel angemeldet („Dieses Gerät freischalten“), nicht neu angelegt.
4. **Aufräumen am Ende des gesamten Laufs** (Abschnitt 4), nicht am Ende jedes einzelnen Plans.

## 4. Reihenfolge und Aufräumen

| Schritt | Plan / Fälle | Zustand danach |
|---|---|---|
| 0 | TV-01 bis TV-03 | Version stimmt, Server offen, Namen frei, Geräte leer |
| 1 | `Testplan_Nutzeranlage` (TN-00 bis TN-19) | N1 + F1 (auf G angemeldet), N2 + F2 (auf G2 abgemeldet) |
| 2 | `Testplan_Pruefanleitung` (TC-00 bis TC-18) | KN1b gültig, Beispieldaten in F1, N2 gelöscht |
| 3 | `Testplan_Einladung_Zweiter_Nutzer` (TI-01 bis TI-27) | I2 und N1 gelöscht |

**Schlussaufräumen:** Nach dem letzten Plan sind alle Konten der Tabelle gelöscht. Wurde ein Plan weggelassen oder abgebrochen, jedes noch bestehende Konto der Tabelle (N1, N2, I2) in der App löschen (Einstellungen → Konto → „Konto löschen“ mit Passwort) und die Anmeldung mit dem Benutzernamen als gescheitert gegenprüfen. Ist ein Passwort verloren, mit TV-03 prüfen: `M_USER_IN_USE` bedeutet, das Konto besteht noch → dem Serverbetreiber zur Deaktivierung melden. Im Report „Zustand der Stammdaten am Ende“ angeben.
