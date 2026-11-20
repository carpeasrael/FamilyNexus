# Testreport Lauf 36: macOS (G1) / Android-Emulator (G2), Plan 1.55, Build 1.2.3 (31)

**Datum:** 18.11.2026, ca. 11:20 bis 17:00 · **Plan:** TP-FN-001 v1.55 @ `c6d2ef0` (= `origin/main` `b85ce9d` + PR #546 + Plan 1.55)
**G1:** macOS 27.3, `flutter build macos --debug` im Worktree, Bundle-ID `de.inneso.familynexus.e2e` (nur im Worktree), ad hoc signiert
**G2:** Android 15 (API 35), eigenes AVD `FN_E2E_L36` (arm64, 4 GB, Datenpartition 6 GB), Debug-APK arm64; AVD nach dem Lauf gelöscht, `Pixel8_API35` des Nutzers unberührt
**Server:** matrix-synapse-3ues.srv1348446.hstgr.cloud, Konten `fnt-1118-n1`, `-n12`, `-i2` (alle gelöscht, `M_USER_IN_USE`), `-n9` nie angelegt
**Tester:** Tester-Agenten (V/A/B, C/D, E/H, F); kein App- oder Plan-Code geändert, nichts committet

## Zählung (nach `Ergebnisse.tsv`, 155 Zeilen; Teilzeilen zählen einzeln)
✅ 117 · ⚠️ 23 · ❌ 0 · ⏳ 11 · n/a 4

## Neu in diesem Lauf bestanden
- **#545/#546 Anbieter-Schritt:** „Schritt 1 von 4“, matrix.org vorgewählt, „Anderer Anbieter“ mit Adresse, Anmeldung auf G2 (A-03 bis A-05, C-01).
- **B-27 / E-19c Geburts- und Gedenktage (#539):** Alter, Todestag, 29.02., Heute-Karte, Löschen mit Rückfrage; Zwei-Konten-Teil.
- **E-18d Zustellstatus (#526):** Haken, „Gelesen von 1“, Namensblatt, Schalter.
- **H (Verschlüsselung):** 0 Klartexttreffer in beiden Datenbanken, Server nur `m.room.encrypted`, TLS 1.3, keine Geheimnisse in Protokollen.
- **Kontolöschung (F-01, F-02, F-06, F-07, E-32):** Konten gelöscht, Gegenprobe 403, `M_USER_IN_USE`.

## Befunde an der App (Issue noch nicht angelegt)
1. **B-25 (Android, Querformat mit Tastatur):** „BOTTOM OVERFLOWED BY 31 PIXELS“ am Chat-Eingabefeld (`screenshots/B-25-G2-quer-chat-tastatur-G2.png`). Der Plan verlangt keinen Überlauf.
2. **B-17 (Android):** Wird die Gerätesperre vor „App lock“ entfernt, lässt sich „App lock“ nicht mehr abschalten („The confirmation was not successful.“). Klärung per Issue.
3. **B-27:** Geburtstagsliste weder chronologisch noch alphabetisch (`B-27q-G1.png`).
4. **E-32:** Nach Löschung von I2 zeigt der Chat „?“ statt des Anfangsbuchstabens (Plan E-101), Text „Ehemaliges Mitglied“ (#326) nicht geprüft.
5. **D-02a:** Diagnosedialog zeigt Schlüssel auf Deutsch bei englischer App.
6. **B-18:** „Screen protection“ steht ab Werk AN (Plan Abschnitt 2 erwartet AUS).
7. **A-01 (macOS):** Kaltstart zeigt ca. 0,15 s schwarzes Fenster (`A-01b-G1.png`).
8. **H-10:** Einzelchat in der Online-Datenübersicht mit Raum-ID statt Name.
9. **F-06c (G1):** Nach serverseitiger Kontolöschung zeigt die Mac-App „Anmelden“ statt „Willkommen“.
10. Nach „Sign out“ steht der Anbieter wieder auf matrix.org (muss erneut gewählt werden).

## Befunde am Plan
- A-09: „Schritt 2 von 3“ ist veraltet, die App zeigt „Schritt 3 von 4“ (seit #545).
- A-12: Einführungstour (3 Stufen) im Plan nicht beschrieben.
- B-27: Knopf heißt „Person anlegen“ statt „Person hinzufügen“.
- F-05: Gültiger Notfall-Schlüssel war KN1c (H-07 erzeugt einen neuen); der Plan nennt KN1b.

## Nicht getestet (⏳, gilt nicht als bestanden)
- **Mac, ad hoc signiert:** Systemdialog und Systembenachrichtigung (B-02, B-10, Plattform-Pflichtschritt Release-Gate); App-Sperre (B-17 macOS, Passwortabfrage).
- **Mac, lokale Daten löschen** (F-03, F-04, F-05a, H-18, H-19, V-04): bewusst nicht, der Schlüsselbund ist mit der App des Nutzers geteilt.
- Tablet, iPad, Systemschrift 200 %/AX5, TalkBack-Ansagen (B-07, B-25, C-02, E-18d).
- Teile von E-16, E-18c, E-19b, B-12b; „Ehemaliges Mitglied“ (#326), Ladekreis #272 (Zwischenzustände nicht als Bild belegt).
- A-05a (präparierter Testserver), D-07 (Server-Admin).
- `tool/e2e.sh` und `flutter test` wurden in diesem Lauf nicht ausgeführt (Code-Test ist Aufgabe der Issue-PRs, #546 mit grüner CI).

## Tester-Missgeschicke (keine App-Befunde)
- `D-05a-G2.png` versehentlich gelöscht; Beleg nur als Text in `Ergebnisse.tsv`.
- B-12: zusätzliche Chatnachricht „Hallo Testfamilie / zweite Zeile“.
- Ein Hilfsbefehl gab einen Notfall-Schlüssel (gelöschtes Konto) in die Tool-Ausgabe, nicht in den Report.
- Emulator einmal abgestürzt (qemu, 12:36), mit denselben Daten neu gestartet.

## Zustand am Ende
Alle Konten dieses Laufs gelöscht, Mac-App beendet (Container `de.inneso.familynexus.e2e` bleibt, vom Nutzer entfernbar), Android-Emulator beendet und AVD entfernt. Einladungslink und Notfalldateien nur unter `secure/` (git-ignoriert).
