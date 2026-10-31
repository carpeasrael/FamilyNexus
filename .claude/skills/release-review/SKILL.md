---
name: release-review
description: Pflicht vor jedem Build-Release von FamilyNexus. Vier Agenten prüfen den App-Code auf Performance, Qualität und Coding Standards, Sicherheit und Konsistenz, ein Control-Agent prüft die Observations nach, bestätigte werden zu gh-Issues. Verwenden, wenn ein Build, Release, Tag, Upload oder eine neue Build-Nummer ansteht oder wenn nach dem Release-Review gefragt wird. Argument "voll" erzwingt die Prüfung des ganzen App-Codes.
---

# Release-Review

Prüft genau den Stand, der gebaut werden soll. Ohne Bericht zu diesem Stand bricht `.github/workflows/release.yml` ab (Prüfung: `tool/check_release_review.sh`).

Die Reihenfolge ist fest. Schlägt ein Schritt fehl, anhalten und das melden. Niemals einen Bericht für einen unvollständigen Lauf schreiben.

## 1. Stand festlegen

1. Prüfen, dass im App-Code nichts offen ist: `git status --porcelain -- lib android ios macos linux windows web flatpak pubspec.yaml pubspec.lock` muss leer sein. Sonst abbrechen: Geprüft wird der Commit, nicht der Arbeitsbaum. Andere fremde Änderungen im Arbeitsbaum bleiben unberührt.
2. `tool/check_release_review.sh --print` ausführen. Das liefert `Version` und `Fingerabdruck`.
3. Build-Nummer: Sie wird hier nicht geändert. Ist sie noch die des letzten Builds, die Person kurz darauf hinweisen und mit ihrem Stand weitermachen.
4. Stimmt der Fingerabdruck in `docs/release-reviews/<Version>.md` bereits, ist nichts zu tun: melden und beenden.

## 2. Umfang bestimmen

- Argument `voll` oder noch kein Bericht unter `docs/release-reviews/`: `VOLL`.
- Sonst: Basis ist `Geprüfter Commit` im jüngsten Bericht (`git log -1 --format= --name-only -- docs/release-reviews/`). Umfang sind die Dateien aus `git diff --name-only <Basis> HEAD -- lib android ios macos linux windows web flatpak pubspec.yaml pubspec.lock`, ohne `lib/l10n/gen/`.
- Ist die Liste leer, weil nur die Version anders ist, wird trotzdem die Änderung an `pubspec.yaml` geprüft.

Bestehende Issues als JSON holen:

```sh
gh issue list --state all --limit 500 --json number,state,stateReason,title,labels,body
```

Für die Agenten daraus einen Auszug bilden: Nummer, Zustand, Titel, und bei Issues mit Label `code-review` die Zeile `Review-Schlüssel`. Ganze Issue-Texte werden nicht weitergegeben.

## 3. Vier Reviewer parallel starten

In **einer** Nachricht vier `Agent`-Aufrufe: `review-performance`, `review-quality`, `review-security`, `review-consistency`. Jeder bekommt denselben Auftrag: geprüfter Commit, Umfang und Issue-Auszug. Keine eigene Einschätzung mitgeben.

Warten, bis alle vier fertig sind. Fehlt ein Ergebnis, ist es kein gültiges JSON oder steht unter `nicht_geprueft` ein wesentlicher Teil des Umfangs: diesen Reviewer einmal neu starten. Scheitert er erneut, abbrechen.

## 4. Control-Agent

Einen `review-control` mit frischem Kontext starten. Er bekommt alle Observations als JSON und den Issue-Auszug, sonst nichts. Sind es mehr als 30, Observations je Bereich auf eigene `review-control`-Läufe aufteilen und Dubletten über die Bereiche danach anhand der `schluessel` prüfen.

- Das Urteil ist bindend. Abgelehntes wird nicht wiederbelebt, Bestätigtes nicht verworfen, Schwere nicht umgestuft.
- Fehlt zu einer Observation ein Urteil, einen neuen Lauf nur für diese Observations starten.
- `BESTÄTIGT` ohne Datei- und Zeilenangabe in der Begründung zählt als `UNKLAR`.
- Gibt es keine Observations, entfällt dieser Schritt.

## 5. Issues anlegen

Nur für `BESTÄTIGT`. Vorher die Labels sicherstellen (`gh label create <name> --force`): `code-review`, `review:performance`, `review:qualitaet`, `review:sicherheit`, `review:konsistenz`.

Abgleich über `Review-Schlüssel` in den bestehenden Issues:

- Offenes Issue mit gleichem Schlüssel: kein neues Issue, im Bericht vermerken.
- Geschlossen als `NOT_PLANNED`: kein neues Issue, im Bericht vermerken.
- Geschlossen als `COMPLETED`: neues Issue mit Hinweis „Regression von #n“.

```sh
gh issue create --title "[Review/<Bereich>] <titel>" --label code-review --label review:<bereich> --body-file <datei>
```

Text in `<datei>`, die im Scratchpad liegt:

```markdown
**Schwere:** <laut Control-Agent> · **Stand:** <Version>, `<Commit>`
**Stelle:** `<datei>:<zeile>`

## Befund
## Szenario
## Nachprüfung durch den Control-Agenten
## Vorschlag

Review-Schlüssel: `<schluessel>`
```

**Sicherheitsfunde der Schwere `hoch` oder `kritisch`:** Das Repository ist öffentlich. Das Issue nennt nur den betroffenen Bereich, die Fehlerklasse und die Schwere, dazu den Schlüssel. Datei, Zeile, Zitat, Szenario und Nachprüfung kommen nur nach `secure/release-reviews/<Version>.md` (nicht im Repository). Dasselbe gilt für den Bericht. Keine Geheimnisse in Issues oder Bericht.

Die Bearbeitung der Issues folgt dem Standardablauf für GitHub-Issues und ist nicht Teil dieses Skills.

## 6. Bericht schreiben

`docs/release-reviews/<Version>.md`. Gibt es die Datei schon, den Kopf aktualisieren und den neuen Lauf als weiteren Abschnitt anhängen.

```markdown
# Release-Review <Version>

- Version: <Version>
- Geprüfter Commit: <voller Hash>
- Fingerabdruck: <Fingerabdruck>

## Lauf <n> (<Datum>)

Umfang: VOLL | seit <Basis> (<Anzahl> Dateien)

| Bereich | Observations | Bestätigt | Abgelehnt | Unklar | Duplikat |
|---|---|---|---|---|---|

### Bestätigt
| ID | Schwere | Titel | Issue |

### Nicht bestätigt
| ID | Urteil | Titel | Begründung |
```

Bestehende `Nicht geprüft`-Angaben der Reviewer in den Lauf übernehmen.

Den Bericht danach auf einem eigenen Branch einreichen. Nur diese Datei stagen:

```sh
git switch -c docs/release-review-<Version-mit-Bindestrich>
git add docs/release-reviews/<Version>.md
git commit
git push -u origin HEAD
gh pr create
git switch -
```

Der Merge bleibt der Person überlassen. Erst danach läuft der Build durch, denn das Gate liest den Bericht aus dem Stand, der gebaut wird.

## 7. Abschluss

Melden: Zahlen je Bereich, Links zu neuen Issues, PR-Link und Empfehlung zum Release. Bei bestätigten `kritisch`-Funden klar sagen, dass nicht gebaut werden sollte. Das Gate blockiert bei offenen Issues nicht; das entscheidet die Person.

Ändert ein Fix danach App-Code, stimmt der Fingerabdruck nicht mehr. Dann läuft dieser Skill erneut und prüft nur den Unterschied zum letzten Bericht.

Kein Tag, keine Änderung der Build-Nummer und kein Start des Builds in diesem Skill.
