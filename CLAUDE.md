# FamilyNexus: Arbeitsregeln

## Standardablauf für GitHub-Issues

Dieser Ablauf gilt **immer und ohne Aufforderung**, sobald ein gh-Issue oder ein Milestone bearbeitet wird. Reihenfolge bei einem Milestone: erst alle offenen Issues sichten, dann Abhängigkeiten klären, dann Issue für Issue abarbeiten.

### 1. Analyse und Lösungsvorschlag

- Issue samt aller Kommentare lesen, betroffenen Code und `docs/ENTSCHEIDUNGEN.md` prüfen, Ursache belegen (Datei und Zeile), nicht vermuten.
- Lösungsvorschlag schreiben: Ursache, Änderung je Datei, Tests, Risiken, bewusst Ausgeschlossenes.
- Ist das Issue nicht von Agenten lösbar (Gerät, Konten, Apple, Testperson), keinen Vorschlag erzwingen: siehe „Nicht lösbar oder nicht testbar“.

### 2. Prüfung durch zwei unabhängige Agenten

- Zwei getrennte Agenten mit frischem Kontext prüfen den Vorschlag gegen Issue und Code. Keiner kennt das Urteil des anderen, keiner hat am Vorschlag mitgewirkt. Sie bekommen den Vorschlag, nicht die eigene Einschätzung dazu.
- Jeder meldet genau `OK` oder `NICHT OK` mit Begründung.
- `NICHT OK` von einem der beiden: Vorschlag überarbeiten, beide prüfen erneut (wieder frische Agenten).
- **Höchstens 5 Iterationen.** Danach anhalten, eskalieren und dem Nutzer konkrete Fragen zum weiteren Vorgehen stellen; das nächste Issue kann weiterlaufen, wenn es nicht davon abhängt.

### 3. Dokumentation im Issue

Erst wenn **beide** `OK` melden: Lösung als Kommentar ins Issue schreiben (Ursache, Lösung, Tests, Anzahl der Iterationen). Vorher nichts implementieren.

### 4. Implementierung

- Eigener Branch `fix/<nr>-<thema>` (bzw. `feat/`, `docs/`) ab aktuellem `main`.
- Regressionstest, der ohne den Fix rot und mit dem Fix grün ist. Nutzertexte über l10n (de und en).
- Nur die eigenen Dateien stagen (`git add <pfad>`), nie `git add -A`: Der Arbeitsbaum kann fremde Änderungen des Nutzers enthalten.
- Weichen Verhalten oder Datenmodell ab, `docs/ENTSCHEIDUNGEN.md` und den Testplan in `User E2E Test/` nachziehen.

### 5. Testplan und Test durch getrennte Agenten

- Ein **Testplan-Agent** (frischer Kontext) erstellt aus Issue und Diff einen Plan mit konkreten Schritten, Erwartungen und Abnahmekriterien, einschließlich Grenzfällen und Regressionen.
- Ein **separater Tester-Agent** führt ihn aus und meldet je Schritt bestanden oder fehlgeschlagen mit Beleg (Befehl, Ausgabe). Er ändert keinen Code. Er nimmt nichts als bestanden an, was er nicht ausgeführt hat.
- Pflichtteil immer: `flutter analyze`, `flutter test`; bei Änderungen an Matrix-Abläufen zusätzlich E2E gegen den lokalen Synapse.

### 6. Auswertung und Abschluss

- Ergebnis selbst analysieren, nicht nur das Fazit des Testers übernehmen.
- **Erfolgreich:** PR mit `Closes #<nr>` erstellen, CI abwarten, Testergebnis im Issue vermerken. Dann das nächste Issue. Der Merge ist die Review-Entscheidung des Nutzers, Agenten mergen nicht selbst; das Issue schließt sich beim Merge. Ein Issue nie von Hand schließen, solange der Fix nicht auf `main` ist. Baut das nächste Issue auf einem offenen PR auf, den Branch darauf stapeln und das im PR nennen.
- **Fehlgeschlagen:** Ursache klären, Fix nachbessern und ab Schritt 5 wiederholen. Ändert sich dabei die Lösung, ab Schritt 2. Auch hier höchstens 5 Iterationen, dann eskalieren.

### Nicht lösbar oder nicht testbar

- Ein Issue wird nur geschlossen, wenn der Test die Abnahme des Issues wirklich belegt. Was hier nicht ausführbar ist (macOS, iOS, echtes iPhone, Windows, matrix.org, Testperson), gilt als **nicht getestet**, nicht als bestanden.
- Ist der Code-Teil getestet, aber die Abnahme nur auf dem Zielgerät möglich: Fix mergen (PR mit `Refs #<nr>`, nicht `Closes`), Issue offen lassen und im Kommentar genau benennen, welcher Nachtest fehlt.
- Rein manuelle Punkte werden nicht bearbeitet: Stand im Issue kommentieren, weiter zum nächsten Issue und den Punkt am Ende melden.

### Grenzen ohne ausdrückliche Freigabe

- Kein Release: keine Tags, keine Änderung der Build-Nummer, kein Upload zu App Store, TestFlight oder Play.
- Keine echten Konten oder Registrierungen bei matrix.org, keine fremden Konten auf dem Testserver.
- Keine Geheimnisse (Notfall-Schlüssel, Passwörter, Signaturen) in Repository oder Issues.
- Bestehende Tests nicht abschwächen, um grün zu werden.

## Release-Review vor jedem Build

Vor jedem Build-Release läuft der Skill `release-review`: vier Agenten prüfen den App-Code, der Control-Agent prüft ihre Observations nach, bestätigte werden gh-Issues. Ohne passenden Bericht unter `docs/release-reviews/` bricht `release.yml` ab (E-75). Der Skill selbst ist kein Release: Er setzt keine Tags, ändert keine Build-Nummer und startet keinen Build. Bestätigte Issues folgen dem Standardablauf oben.

## Lokale Testumgebung

`flutter` liegt unter `/home/carpeasrael/tools/flutter/bin/flutter`. E2E: `tool/e2e.sh` (Docker, Synapse). Der Host hat kein clang, Desktop-Integrationstests laufen daher nicht.
