# Sprintplan Release 1.2.2

Stand: 01.11.2026, `main` @ `3ccaf2c`. Milestone: „Release v1.2.2“, fällig am 20.11.2026.

## Ziel

Einträge des Einkaufszettels lassen sich gruppieren, zum Beispiel nach Geschäft (#211). Die Gruppen erscheinen auf allen Geräten der Familie, ohne dass bestehende Einträge oder ältere Apps kaputtgehen.

## Umfang

| Issue | Thema | Stand |
|---|---|---|
| #211 | Einkaufszettel: Einträge gruppieren | nicht begonnen |

Nicht im Sprint:

- Offene Issues aus Milestone v1.2.1. Sie folgen dem dortigen Ablauf.
- #142 (Identitätsvermerke). Das Issue liegt seit dem 01.11.2026 in Milestone v1.3.
- Eigene Gruppen-Datensätze, Sammel-Umbenennen, eigene Reihenfolge der Gruppen, mehrere Listen, Preise.

## Voraussetzungen

| Nr. | Voraussetzung | Grund |
|---|---|---|
| V1 | #140, #138 und #139 sind auf `main` | Der Sprint-Branch baut auf deren Änderungen an `ShoppingSync` und am Gateway auf |
| V2 | Stand von Release 1.2.1 ist eingefroren (Bericht in `docs/release-reviews/` passt) | Ein früherer Merge von #211 ändert den Fingerabdruck und erzwingt einen neuen Release-Review für 1.2.1 |
| V3 | Umfang von #211 ist freigegeben (siehe E1) | Das Ereignisformat ist schwer rückholbar (E-40) |
| V4 | Version und Tag von 1.2.1 sind entschieden (siehe E2) | Davon hängen Version und Build-Nummer von 1.2.2 ab |

## Entscheidungen

| Nr. | Frage | Annahme dieses Plans | Stand |
|---|---|---|---|
| E1 | Wie weit geht #211? | Freie Gruppennamen je Eintrag, alphabetisch sortiert, „Ohne Gruppe“ am Ende, Erledigtes ungruppiert | offen |
| E2 | Welche Version bekommt dieser Release? | 1.2.2+24, wenn 1.2.1 mit Build 23 erscheint | offen |

## Technischer Ansatz

Grundlage ist der gelesene Code. Die Lösung durchläuft noch die Prüfung durch zwei Agenten (Schritt 2 unten).

**Format**

- Neues optionales Feld `grp` im Ereignis `de.inneso.familynexus.shopping`. Das Schema bleibt `v: 1`.
- `ShoppingCodec.decode` verlangt `v == 1` und liest nur benannte Felder. Alte Apps ignorieren `grp` also. Eine `v: 2` würde auf alten Apps alle Einträge verwerfen.
- `encode` schreibt `grp` nur, wenn eine Gruppe gesetzt ist. Einträge ohne Gruppe bleiben unverändert.
- `decode`: Fehlt `grp`, ist die Gruppe leer. Ein Wert, der kein Text ist, macht den Eintrag ungültig. Die Längenprüfung vor dem Bauen des Objekts gilt auch für `grp`.

**Datenmodell und Ablage**

- Keine Migration: `SqlShoppingStore` legt das JSON des Codecs in der Spalte `data` ab.
- `ShoppingItem`: Feld `group`, Grenze `maxGroup = 30` wie bei der Menge, gleiche Zeichenprüfung (`_bad`).
- Mitzuziehen: `validate`, `copyWith`, `==`, `hashCode`, `ShoppingMerge._tie`.
- Löschmarken tragen keinen Inhalt: `_tombstone` leert `group`, `validate` lehnt eine Löschmarke mit Gruppe ab.

**Fachlogik**

- `ShoppingService.add` und `edit` bekommen den Parameter `group`, normalisiert über `_norm`.
- `ShoppingController` liefert die offenen Einträge nach Gruppen. Gleichheit gilt ohne Groß- und Kleinschreibung.
- Die angezeigte Schreibweise muss auf allen Geräten gleich sein, sie wird daher deterministisch aus den vorhandenen Schreibweisen bestimmt.

**Oberfläche**

- `shopping_screen.dart`: Überschrift je Gruppe mit Anzahl (`_Header`), Einträge wie bisher (`_ItemTile`).
- Eingabe und `_EditDialog`: Feld „Gruppe (optional)“ mit Vorschlägen aus den vorhandenen Gruppen.
- Der Abschnitt „Erledigt“ und „Erledigte entfernen“ bleiben unverändert.
- Neue Texte über l10n in de und en. Überschriften sind für Screenreader als solche erkennbar.

**Bekanntes Risiko**

Ein Datensatz gewinnt immer als Ganzes (E-40). Ändert eine ältere App einen Eintrag, verliert er seine Gruppe. Das bleibt so und kommt als „alle Geräte aktualisieren“ in die Release-Notes.

## Aufgaben

Der Ablauf folgt dem Standardablauf aus `CLAUDE.md`.

| Nr. | Aufgabe | Ergebnis | Abhängig von |
|---|---|---|---|
| 1 | Analyse und Lösungsvorschlag | Vorschlag mit Änderung je Datei | V3 |
| 2 | Prüfung durch zwei unabhängige Agenten, höchstens 5 Iterationen | Beide melden `OK` | 1 |
| 3 | Lösung als Kommentar in #211 | Kommentar im Issue | 2 |
| 4 | Modell, Codec, Merge und Service | Branch `feat/211-einkauf-gruppen` ab aktuellem `main` | 3, V1 |
| 5 | Controller und Oberfläche, l10n de und en | Gruppenansicht funktioniert | 4 |
| 6 | Dokumentation nachziehen | siehe Abschnitt „Dokumentation“ | 4, 5 |
| 7 | Testplan-Agent und getrennter Tester-Agent | Bericht je Schritt mit Beleg | 5, 6 |
| 8 | PR mit `Closes #211`, CI abwarten, Testergebnis im Issue | PR grün, Merge durch den Nutzer | 7, V2 |
| 9 | Skill `release-review` für 1.2.2 | Bericht unter `docs/release-reviews/` | 8 |
| 10 | Build, Tag und Upload | erst nach ausdrücklicher Freigabe | 9, V4 |

## Tests

Pflicht: `flutter analyze`, `flutter test` und E2E gegen den lokalen Synapse, weil sich ein Matrix-Ablauf ändert.

Regressionstests, ohne Fix rot und mit Fix grün:

- Codec: mit und ohne `grp`, falscher Typ, Überlänge, gesperrte Zeichen, ZWJ erlaubt.
- Ein Ereignis ohne `grp` im alten Format bleibt lesbar. Eintrag ohne Gruppe erzeugt keinen Schlüssel `grp`.
- Löschmarke: `_tombstone` leert die Gruppe, Löschmarke mit Gruppe wird abgelehnt.
- Merge: Einträge, die sich nur in der Gruppe unterscheiden, konvergieren in beiden Reihenfolgen gleich.
- `SqlShoppingStore`: Gruppe übersteht Speichern und Lesen, vorhandene Datensätze bleiben lesbar.
- `ShoppingSync` (`test/data/shopping_sync_test.dart`): Gruppe kommt beim anderen Mitglied an, Resync für neue Mitglieder enthält sie.
- Controller: Sortierung, „Ohne Gruppe“ am Ende, Groß- und Kleinschreibung, gleiche Anzeige bei abweichender Reihenfolge.
- Widget: Überschriften, Bearbeiten, Vorschläge, Enter-Verhalten (`test/ui/enter_submits_test.dart`).
- E2E (`test/e2e/gateway_phase6_e2e_test.dart`): zwei Mitglieder, Gruppe setzen, ändern, entfernen.

Nachtest außerhalb dieser Umgebung: Abnahme auf macOS, iOS und Windows. Was hier nicht lief, gilt als nicht getestet.

Hier möglich: Android-Emulator, Chromium und Flatpak unter Xvfb.

## Dokumentation

- `docs/ENTSCHEIDUNGEN.md`: Nachtrag zu E-40. Dort sind „Kategorien“ ausdrücklich verworfen.
- `User E2E Test/Testplan_FamilyNexus.md`: B-14 und E-22 ergänzen, Abdeckungstabelle nachziehen.
- `store/privacy/privacy-policy.de.md` Zeile 48 und die englische Fassung: Gruppen in der Datentabelle nennen. Die englische Fassung hängt an der Freigabe aus #147.
- Prüfen, ob das lokale Datenprotokoll die Gruppe zeigt (`lib/features/settings/data_report.dart`, `lib/data/db/sql_data_inventory.dart`).
- Release-Notes: „Alle Geräte aktualisieren“.

## Zeitplan

Vorschlag. Alle Schritte hängen an den Voraussetzungen oben.

| Spätestens | Meilenstein |
|---|---|
| 07.11.2026 | E1 entschieden, Aufgaben 1 bis 3 abgeschlossen |
| 13.11.2026 | Aufgaben 4 bis 7 abgeschlossen, PR offen und grün |
| 15.11.2026 | Fälligkeit Release 1.2.1, danach Merge möglich (V2) |
| 18.11.2026 | PR gemergt, Release-Review 1.2.2 abgeschlossen |
| 20.11.2026 | Build nach Freigabe |

## Risiken

| Risiko | Folge | Gegenmaßnahme |
|---|---|---|
| 1.2.1 verzögert sich | Merge blockiert, 20.11. nicht haltbar | PR bleibt offen, Termin früh neu festlegen |
| Der Stapel #140, #138, #139 verschiebt sich | Aufgabe 4 startet später | Aufgaben 1 bis 3 laufen unabhängig davon |
| Ältere Apps löschen Gruppen | Gruppe verschwindet nach einer Änderung auf altem Gerät | Release-Note, Grenze in E-40 festhalten |
| Tippfehler erzeugen doppelte Gruppen | Unübersichtliche Liste | Vorschläge im Eingabefeld, Vergleich ohne Groß- und Kleinschreibung |
| Format ist schwer rückholbar | Spätere eigene Gruppen-Datensätze brauchen Übergang | Entscheidung E1 vor der Umsetzung |

## Abnahme

- [ ] Eintrag lässt sich beim Anlegen und Bearbeiten einer Gruppe zuordnen, und die Gruppe lässt sich wieder entfernen.
- [ ] Offene Einträge erscheinen nach Gruppen, wie im Beispiel aus #211.
- [ ] Änderungen erscheinen beim anderen Mitglied, neue Mitglieder erhalten die Gruppen.
- [ ] Bestehende Einträge bleiben ohne Migration lesbar und stehen unter „Ohne Gruppe“.
- [ ] `flutter analyze`, `flutter test` und E2E sind grün, nicht ausgeführte Plattformen sind benannt.
- [ ] Texte liegen in de und en vor, Dokumentation und Testplan sind nachgezogen.
- [ ] Release-Review 1.2.2 passt zum Code, der Release ist freigegeben.
