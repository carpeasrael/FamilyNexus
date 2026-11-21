# Sprintplan Release 1.3

Stand: 21.11.2026, `main` @ `6562801` (Version 1.2.3+31). Milestone „Release v1.3“, fällig am 31.12.2026. Dieser Plan ist ein **Vorschlag**: Umfang und Entscheidungen E1 bis E10 liegen beim Eigentümer.

## Ziel

Release 1.3 schließt die offenen Punkte aus 1.2.2 und 1.2.3 ab und liefert die kleineren Funktionen aus dem Milestone (Termine durch Moderatoren, Meldungen auf Android, Avatar-Foto, verschlüsselte Exporte). Die großen Funktionen (Kontakte, Familienspeicher, WhatsApp, Haushaltsbuch) werden in diesem Release nur vorbereitet, nicht ausgeliefert (Begründung unter „Umfang“).

## Stand

- Offen: **20 Issues**, davon 11 im Milestone v1.2.3 und 9 im Milestone v1.3. Der Milestone v1.2.2 ist geschlossen und hat keine offenen Issues; seine Reste liegen in v1.2.3 (z. B. #254 „enhancement features 1.2.2“).
- Gemergt seit dem Release-Stand 1.2.3+31: #574, #575, #578, #579 (PRs #584 bis #587). `lib/` hat sich dadurch geändert: Review-Bericht und Android-E2E-Beleg gelten nur für den alten Stand, das Release v1.2.3 trägt die Dateien von Build 31 ohne die Fixes #574, #575 und #579 (#578 ändert nur die README).
- Größenangaben (S, M, L) sind **Schätzungen** nach den Konzeptdokumenten und dem Standardablauf aus `CLAUDE.md`: S bis etwa 1 Tag, M 2 bis 4 Tage, L über eine Woche, jeweils einschließlich der zwei Prüfungen und der getrennten Tests.

## Umfang

### Block A: Reste aus 1.2.2 und 1.2.3

| Issue | Thema | Größe | Stand | Was zum Schließen fehlt | Plan |
|---|---|---|---|---|---|
| #576 | App-Sperre entsperrt ohne Abfrage unter Windows (Review-Fund, niedrig) | S | Vorschlag steht im Issue | Entscheidung E3, Code-Test, Windows-Gerät für `UserConsentVerifier` | Sprint 1 |
| #563 | Backups und Exporte verschlüsseln | S bis M | nicht analysiert | Analyse: welche Exporte gibt es (Entscheidung E8) | Sprint 1 Analyse, Sprint 2 Umsetzung |
| #507 | Einführungstour erscheint nach erneuter Anmeldung wieder | S | Regressionstest auf `main` (`intro_tour_relogin_test.dart`), Ursache nicht belegt | Gerätebeleg RT3-H-06 und Entscheidung „gewollt oder Fehler“ | manuell |
| #554 | macOS Kaltstart: schwarzes Fenster | S | Fix auf `main` (PR #572), nur Textcheck | Mac-Kaltstart A-01b mit Montage, hell und dunkel | manuell |
| #317 | Karte „Berechtigung fehlt“ auf macOS, Linux, Windows | S | Fix auf `main`, Windows belegt (Lauf 24) | Release-E2E macOS und iOS (Sichtkontrolle) | Release-Gate |
| #325 | Tests auf Windows-Host: Pfadtrenner und CRLF | S | `text_norm_test.dart` auf `main` | Testlauf auf einem Windows-Host | Release-Gate |
| #330 | Windows: Taskleisten-Overlay „9+“ am Rand | S | Fix auf `main` (PR #342) | Release-E2E Windows bei 100, 125, 150, 200 % | Release-Gate |
| #254 | Sammel-Issue Meldungen und Chat (aus 1.2.2) | S | Windows belegt, Android hängt an #273 | Belege iPhone und Mac, Entscheidung zu #273 | folgt #273 |
| #268 | Registrierung über matrix.org | S | Fix auf `main` | TP-OAUTH-11 und -12 mit echtem Konto (nur mit Freigabe E5) | manuell |
| #528 | Anmeldung ohne Browser (macOS, Linux, Windows) | – | macOS durch #441, Linux und Windows laut E-102 nicht umgesetzt | Entscheidung E4 | Entscheidung |
| #15 | Prüfkonto vorbereiten (Apple, Testperson) | – | rein manuell | Apple, echte Konten, Testperson | manuell |

### Block B: Entwicklung in 1.3

| Issue | Thema | Größe | Stand | Plan |
|---|---|---|---|---|
| #273 | Android: keine Meldungen im Hintergrund | M | Variante (a) „ehrlicher Text“ umgesetzt (PR #420); offen sind (b) kurzer Vordergrunddienst und (c) Push (Entscheidung E2) | Sprint 1 Entscheidung, Sprint 2 Umsetzung |
| #431 | Geteilte Termine durch Moderatoren bearbeiten, mit Änderungsprotokoll | M bis L | Analyse mit sechs belegten Mängeln im Issue; Ereignisformat schwer rückholbar (E-13, E-30), kehrt E-10 um | Sprint 1 neuer Vorschlag, Sprint 2 Umsetzung (Entscheidung E6) |
| #434 | Avatar: eigenes Foto hochladen | M | fünf Fragen offen (Verschlüsselung, Bildverarbeitung, Moderation) | Sprint 1 Entscheidung E7, Sprint 2 Umsetzung nur bei Entscheidung |
| #568 | CI: GitHub Actions auf Commit-SHA festnageln (36 Stellen) | S | nicht analysiert | Sprint 1, nur mit Freigabe E9 |
| #569 | Python-Hilfsskripte: `subprocess` mit Umgebungswert (2 Stellen) | S | vermutlich Fehlalarm, nicht belegt | Sprint 1 Analyse |

### Block C: große Funktionen (Vorbereitung, nicht Auslieferung)

| Issue | Thema | Größe | Stand | Vorschlag für 1.3 |
|---|---|---|---|---|
| #119 | Kontakte und Gruppen | L bis XL | Konzept `docs/KONTAKTE.md`, Phasen K0 (S), K1 (M), K2 (L), K3 (L), K4 (M), K5 (S), K6 (M); das Konzept nennt als Ziel **Release 1.4.0**; Entscheidungen aus Abschnitt 15 offen | nur K0 (Vorprüfung gegen Synapse und matrix.org) und K1 (Härtung ohne neue Funktion); Rest nach 1.4 |
| #120 | Familienspeicher auf Nextcloud | XL | abgestimmt (E-74, SA-9), Phasen S1 bis S5, nicht umgesetzt | verschieben nach 1.4; optional S1 (Domäne, `StorageCrypto` mit Testvektoren) |
| #121 | WhatsApp-Kontakte | – | rechtliche Freigabe (G0) fehlt, laut Entwurf „nach V1.4“ | verschieben, nicht planbar |
| #311 | Haushaltsbuch und Tankrechnungen | XL | nur Anforderungstext, kein Konzept | in 1.3 höchstens ein Konzeptdokument; Umsetzung nach 1.4 |

Warum nicht alles in 1.3: Bis zum 31.12. bleiben fünf Arbeitswochen, davon etwa eine für das Release-Gate. #119, #120 und #311 sind je mehrere Phasen mit schwer rückholbaren Formaten und eigenem Pen-Test, #121 hängt an einer rechtlichen Freigabe. Eine Auslieferung würde den Release-Review, den E2E-Beleg je Plattform und die Store-Angaben (Datenschutz, Altersfreigabe) mehrfach erzwingen.

## Voraussetzungen

| Nr. | Voraussetzung | Grund |
|---|---|---|
| V1 | Entscheidungen E1 bis E5 bis spätestens 27.11. | Sprint 1 kann sonst nur analysieren, nicht umsetzen |
| V2 | `main` ist die Basis aller Branches; die vier Fixes #574, #575, #578, #579 sind drin | sonst entstehen Konflikte in `calendar_screen.dart` und `family_screen.dart` |
| V3 | Android-Werkzeuge auf dem Mac neu einrichten (JDK 17, Android SDK, Emulator, Rust) | Android-E2E im Release-Gate lief zuletzt auf dem Emulator; die Werkzeuge wurden am 21.11. entfernt |
| V4 | Docker Desktop läuft | `tool/e2e.sh` ist bei jeder Matrix-Änderung Pflicht (#431, #119 K1) |
| V5 | Testpersonen und Geräte für iPhone, Mac, Windows, Linux benannt | Release-Gate verlangt je Plattform einen E2E-Beleg mit Screenshots (E-103) |

## Entscheidungen

| Nr. | Frage | Annahme dieses Plans | Stand |
|---|---|---|---|
| E1 | Welche großen Funktionen kommen in 1.3? | #119 nur K0 und K1, #120, #121, #311 nicht; Milestone von #121 und #311 auf einen späteren Release | offen |
| E2 | #273: (b) Vordergrunddienst, (c) Push oder Verbleib bei (a)? | (b) prüfen; (c) bräuchte einen Push-Dienst, die Datenschutzerklärung sagt aber, dass der Herausgeber keinen Server betreibt (`docs/STORE.md`) | offen |
| E3 | #576: unter Windows nur `NotConfiguredForUser` als „keine Sperre“ werten oder den #549-Ausweg auf Android und iOS beschränken? | Ausweg auf Android und iOS beschränken (einfacher, kein neuer Kanal im Windows-Runner) | offen |
| E4 | #528: Anmeldung auf Linux und Windows endgültig im externen Browser (E-102)? | ja, Issue mit Verweis auf E-102 schließen oder auf den Teil macOS beschränken | offen |
| E5 | Freigabe eines echten matrix.org-Kontos für TP-OAUTH-11 und -12 (#268)? | nein, bis ausdrücklich erteilt | offen |
| E6 | #431: dürfen Moderatoren fremde Termine **ändern** (nicht löschen), mit Änderungsprotokoll im Termin? | ja, wie im Analysekommentar (optionales Feld `editor`, `v` bleibt 1) | offen |
| E7 | #434: Foto als Ende-zu-Ende-verschlüsselter Anhang im Familienraum oder als Matrix-Profilbild? | Anhang im Familienraum, nie im Klartext im Raumzustand (E-83, E-101) | offen |
| E8 | #563: welche Backups und Exporte sind gemeint (Notfall-Schlüssel als Datei, lokales Datenprotokoll, Datenbanksicherung)? | erst Analyse, dann Umfang | offen |
| E9 | Dürfen Agenten `.github/workflows/*` ändern (#568)? | nur mit ausdrücklicher Freigabe; Workflows gelten als Build-Konfiguration | offen |
| E10 | Version und Build-Nummer von 1.3 | `1.3.0+32`, Änderung der Build-Nummer erst mit der Release-Freigabe | offen |

## Aufgaben

Jedes Issue läuft nach dem Standardablauf aus `CLAUDE.md` (Analyse, zwei unabhängige Prüfer mit höchstens 5 Iterationen, Kommentar im Issue, Branch und Regressionstest, getrennte Testplan- und Tester-Agenten, PR mit `Closes`). Bei Änderungen am Ereignisformat (E-13, E-30) gilt zusätzlich `tool/e2e.sh`; Rot- und Grün-Beleg stehen im Issue, Testplan und Entscheidungen werden nachgezogen.

| Nr. | Sprint | Aufgabe | Abhängig von |
|---|---|---|---|
| 1 | vorab | Entscheidungen E1 bis E10 einholen, Milestone-Zuschnitt (Block C) anpassen | – |
| 2 | 1 | #576, #569, #568 (nach E9), #563 Analyse: Vorschläge, Prüfung, Umsetzung | E3, E8, E9 |
| 3 | 1 | #273 und #434: Analyse und Vorschlag, Prüfung, Entscheidung | E2, E7 |
| 4 | 1 | #431: Vorschlag überarbeiten (sechs Mängel aus dem Analysekommentar), Prüfung | E6 |
| 5 | 1 | #119 K0: Vorprüfung gegen Synapse und matrix.org (nur wenn E1 es einschließt) | E1 |
| 6 | 2 | #431 umsetzen, E2E gegen Synapse mit zwei Konten (`tool/e2e.sh`) | 4 |
| 7 | 2 | #273 (b) und #434 umsetzen | 3 |
| 8 | 2 | #563 umsetzen; #119 K1 (Härtung) nur wenn E1 es einschließt | 2 |
| 9 | Hardening | Code-Freeze, Release-Review für den Endstand, Testplan 1.3 erstellen | 6 bis 8 |
| 10 | Hardening | E2E je Plattform mit Screenshots, `docs/release-e2e/1.3.0+32.md`, Build und Freigabe | 9, V3, V5 |

## Zeitplan

Vorschlag. Die Tage vom 24. bis 26.12. sind Puffer (Feiertage).

| Spätestens | Meilenstein |
|---|---|
| 27.11.2026 | Entscheidungen E1 bis E5 und E10 getroffen (V1) |
| 04.12.2026 | Sprint 1 abgeschlossen: Block A mit Code erledigt, alle Vorschläge für Block B geprüft und dokumentiert |
| 18.12.2026 | Sprint 2 abgeschlossen, **Code-Freeze**, alle PRs gemergt |
| 21.12.2026 | Release-Review für den Endstand, Testplan 1.3 |
| 23.12.2026 | E2E Android, Web und Linux (hier ausführbar nach V3) |
| 29.12.2026 | E2E iOS, macOS und Windows (Geräte, V5), Block-A-Belege eingetragen |
| 30.12.2026 | Build und Freigabe durch den Eigentümer |
| 31.12.2026 | Fälligkeit; Puffer |

## Release-Gate (E-103)

Ohne bestandenen E2E-Beleg je gebauter Plattform und ohne passenden Release-Review bricht `release.yml` ab. Jede spätere Codeänderung nach dem Freeze verlangt beides neu. Die manuellen Punkte aus Block A (Geräte, Konten, Testperson) fließen in den Release-Test: `User E2E Test/Release_1.2.3_v01/` ist die Vorlage, das Plattform-Pflichtprogramm steht in `User E2E Test/Sprint1_manuelle_Punkte.md` und `Checkliste_Geraetenachtests.md`.

## Risiken

| Risiko | Folge | Gegenmaßnahme |
|---|---|---|
| Entscheidungen E2, E6, E7 kommen zu spät | Sprint 2 hat nichts umzusetzen oder startet spät | Fristen unter „Zeitplan“; Umsetzung nur bei vorliegender Entscheidung, sonst verschieben |
| #431 braucht ein neues, schwer rückholbares Feld im Ereignisformat | Fehler lassen sich nach dem Release nicht zurücknehmen | zwei Prüfrunden, Konvergenztests in beiden Empfangsreihenfolgen, `tool/e2e.sh` Pflicht |
| Geräte und Testpersonen für iPhone, Mac, Windows fehlen in den Feiertagen | Release-Gate nicht erfüllbar, 31.12. nicht haltbar | Termine für die Gerätetests früh festlegen (V5); sonst Release nur für Plattformen mit Beleg |
| Code nach dem Freeze ändert den Fingerabdruck | Review und E2E-Belege wieder ungültig (am 21.11. erlebt, #572) | Merge-Stopp ab Freeze, nur Fixes für belegte Fehler |
| Android-Werkzeuge fehlen | Android-E2E (Emulator) nicht möglich | V3 in Sprint 1 erledigen |
| Review-Check `verify` (Quality-Gate-Nachweise) bleibt rot | PRs lassen sich nicht regulär mergen, falls er Pflicht wird | Richtlinienfrage klären, `.quality/` wird von Agenten nicht geändert |
| #273 (b) scheitert an Play-Richtlinien für Vordergrunddienste | Hintergrundmeldungen bleiben aus | Entscheidung E2 mit Plan B (Verbleib bei (a), Text ehrlich) |

## Abnahme

- [ ] Block A: für jedes Issue ist entweder der Code-Test belegt und das Issue geschlossen oder der fehlende Plattformbeleg im Release-Test geführt.
- [ ] Block B: jedes umgesetzte Issue hat Regressionstest (rot ohne, grün mit Fix), Prüfung durch zwei Agenten und getrennten Test; nicht umgesetzte Issues sind mit Grund in den nächsten Milestone verschoben.
- [ ] Block C: Konzept und Phasenplan für 1.4 sind festgehalten, Milestones stimmen mit E1 überein.
- [ ] `flutter analyze` (0 Fehler, 0 Warnungen), `flutter test` und `tool/e2e.sh` sind grün; nicht ausgeführte Plattformen sind benannt.
- [ ] Release-Review und E2E-Beleg passen zum Endstand (`tool/check_release_review.sh`, `tool/check_release_e2e.sh <plattform>`).
- [ ] Texte liegen in de und en vor; Datenschutzerklärung, Store-Texte, `docs/ENTSCHEIDUNGEN.md` und Testplan sind nachgezogen.
- [ ] Release-Notes nennen Änderungen mit Auswirkung auf bestehende Nutzer (Standardwerte, Ereignisformat, „alle Geräte aktualisieren“).
