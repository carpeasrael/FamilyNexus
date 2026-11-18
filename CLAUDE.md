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
- **Erfolgreich (Code-Test positiv):** PR mit `Closes #<nr>` erstellen, CI abwarten, Testergebnis im Issue vermerken. Dann das nächste Issue. Der Merge ist die Review-Entscheidung des Nutzers, Agenten mergen nicht selbst; das Issue schließt sich beim Merge. Ein Issue nie von Hand schließen, solange der Fix nicht auf `main` ist. Baut das nächste Issue auf einem offenen PR auf, den Branch darauf stapeln und das im PR nennen.
- **Fehlgeschlagen:** Ursache klären, Fix nachbessern und ab Schritt 5 wiederholen. Ändert sich dabei die Lösung, ab Schritt 2. Auch hier höchstens 5 Iterationen, dann eskalieren.

### Abnahme und Schließen (Code-Test), nicht Code-testbar (E-103)

- **Code-Test positiv = Issue darf schließen.** Maßgeblich ist der Code-Testplan des Issues (Kommentar im Issue, Sammelplan `User E2E Test/Codetestplan_Offene_Issues.md`): Regressionstest rot ohne und grün mit dem Fix, `flutter analyze`, `flutter test`, bei Matrix-Abläufen `tool/e2e.sh`. Sind diese Schritte vom Tester-Agenten belegt und die CI grün, kommt der PR mit `Closes #<nr>` und das Issue schließt sich beim Merge. Eine Geräteabnahme ist **keine** Bedingung zum Schließen mehr.
- **Gerätenachtest wandert ins Release-Gate:** Was nur auf dem Zielgerät belegbar ist (Swift, C++, Systemdialoge, Schriftgrößen, echtes iPhone, Windows, matrix.org), nennt der Kommentar als „Plattform-Pflichtschritt“ und der Release-Test führt ihn je Plattform mit Screenshots. Ohne bestandenen E2E-Beleg mit Screenshots für die Plattform und den Build (`docs/release-e2e/<Version>.md`, `tool/check_release_e2e.sh`) bricht `release.yml` ab. Ein offener Plattform-Pflichtschritt hält also das Release auf, nicht das Issue.
- Was hier nicht ausführbar ist, gilt weiter als **nicht getestet**, nicht als bestanden: im Code-Testplan als nicht ausführbar vermerken, nie als Beleg zählen. Hat ein Issue **keinen** Code-Test (nur Gerät, Konto, Apple, Testperson), bleibt es offen: PR mit `Refs #<nr>`, Kommentar nennt den fehlenden Beleg.
- Ein Issue nie von Hand schließen, solange der Fix nicht auf `main` ist. Code-Test und Merge genügen; ein Test, der das Verhalten nicht prüft (nur „läuft ohne Fehler“), zählt nicht.
- Rein manuelle Punkte werden nicht bearbeitet: Stand im Issue kommentieren, weiter zum nächsten Issue und den Punkt am Ende melden.

### Grenzen ohne ausdrückliche Freigabe

- Kein Release: keine Tags, keine Änderung der Build-Nummer, kein Upload zu App Store, TestFlight oder Play.
- Keine echten Konten oder Registrierungen bei matrix.org, keine fremden Konten auf dem Testserver.
- Keine Geheimnisse (Notfall-Schlüssel, Passwörter, Signaturen) in Repository oder Issues.
- Bestehende Tests nicht abschwächen, um grün zu werden.

## Release-Review vor jedem Build und am Sprint-Ende

Vor jedem Build-Release **und am Ende jedes Sprints** (Milestone abgeschlossen) läuft der Skill `release-review`: fünf Agenten (Performance, Qualität, Coding Standards, Sicherheit, Konsistenz) prüfen den App-Code, der Control-Agent prüft ihre Observations nach, bestätigte werden gh-Issues. Ohne passenden Bericht unter `docs/release-reviews/` bricht `release.yml` ab (E-75). Der Skill selbst ist kein Release: Er setzt keine Tags, ändert keine Build-Nummer und startet keinen Build. Bestätigte Issues folgen dem Standardablauf oben.

## E2E-Beleg je Plattform vor jedem Plattform-Build und beim Veröffentlichen

Für **jeden** Build und jedes veröffentlichte Release gehört zu jeder gebauten Plattform ein bestandener E2E-Test mit Screenshots, ausgeführt auf genau diesem Code-Stand (Android, iOS, macOS, Linux, Windows, Web; iOS und macOS zusammen für den Apple-Job). Der Beleg liegt als `docs/release-e2e/<Version>.md` (Format: `docs/release-e2e/README.md`), verweist auf den Testlauf unter `User E2E Test Report/` und nennt mindestens drei Screenshots je Plattform. `tool/check_release_e2e.sh` prüft ihn in jedem Build-Job von `release.yml`; die Build-Nummer gehört zum Fingerabdruck, jeder neue Build braucht einen neuen Lauf. Wer ein Release veröffentlicht, prüft vorher, dass alle Plattformen belegt sind. Das Skript selbst ist kein Release. `skip_e2e` ist nur für den Neubau alter Stände da.

## Lokale Testumgebung

`flutter` liegt unter `/home/carpeasrael/tools/flutter/bin/flutter`. E2E: `tool/e2e.sh` (Docker, Synapse). Der Host hat kein clang, Desktop-Integrationstests laufen daher nicht.

## Quality-Gate (verbindlich)

Gilt für Sitzungen mit `claude --agent qg-orchestrator`. Der Standardablauf für GitHub-Issues oben bleibt bis zu einer Entscheidung des Menschen unverändert.

- Code-Änderungen (Feature, Fix, Refactoring) laufen ausschließlich über den Orchestrator: `claude --agent qg-orchestrator`.
- Jeder Agent wird durch einen unabhängigen zweiten Agenten gegengeprüft. Implementierung erst nach dem Design-Gate (Freigabe zur Implementierung), Commit erst nach dem Code-Gate. Hooks und git-pre-commit erzwingen das.
- Nach 5 Iterationen ohne einheitliches Ergebnis kann, nach 8 muss Modell + Aufwand eine Stufe hochgesetzt werden (`qg escalate`); nach 11 entscheidet der Mensch.
- Regelkatalog: `.quality/standards/STANDARDS.md` (IDs STD-CODE, STD-SEC, STD-PERF, STD-TEST, STD-DOC, STD-DI).
- `.quality/`, `.claude/`, `.githooks/`, `.idea/` sowie Lint-/Test-/Build-Konfiguration werden nicht von Agenten geändert.
- Änderungen an Agenten/Modellen nur über `.quality/config.json` bzw. `.quality/templates/` und anschließend `QG_ADMIN=1 node .quality/bin/qg.mjs gen-agents` (Mensch, Vier-Augen-Review des Diffs).
