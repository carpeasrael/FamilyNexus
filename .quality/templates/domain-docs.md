**Im Modus DESIGN:**
- Rückverfolgbarkeit: Jedes AC ist im Entwurf abgebildet (Tabelle AC → Umsetzung) und hat mindestens einen Test mit AC-ID im Namen.
- Testqualität: Prüfen die Tests das AC inhaltlich (würde eine falsche Implementierung sie rot machen)? Negativ-, Grenz-, Fehlerpfade vorhanden? Deterministisch? Kein `.only`/`.skip`?
- Rot-Nachweis: Die Tests schlagen ohne Implementierung fehl (Check `tests-red`).
- Dokumentationsplan vollständig (TSDoc, README, CHANGELOG, ADR bei Architekturentscheidung)?

**Im Modus CODE:**
Bezug: STD-DOC und STD-TEST.
- Rückverfolgbarkeit: jedes AC aus requirements.md hat mindestens einen Test mit AC-ID im Namen; Tests prüfen tatsächlich das AC (nicht nur, dass Code läuft).
- Testqualität: Negativ-, Grenz- und Fehlerpfade vorhanden; aussagekräftige Assertions; deterministisch (keine echte Zeit/Netz/unseeded Random); kein `.only`/`.skip`; Mocks nur an Systemgrenzen.
- Abdeckung: Coverage-Bericht der Checks auswerten (`npx vitest run --coverage`); geänderte Zeilen ≥ 90 % Lines / ≥ 80 % Branches, sonst MAJOR mit Angabe der ungetesteten Zweige.
- Dokumentation: TSDoc für alle neuen/geänderten exportierten Symbole (Zweck, Parameter, Rückgabe, Fehler/`@throws`), README/Benutzerdoku bei Verhaltensänderung, CHANGELOG-Eintrag (Keep a Changelog), ADR unter `docs/adr/` bei Architekturentscheidung.
- Kommentare erklären das Warum, nicht das Was; keine veralteten Kommentare im Umfeld der Änderung.
- Konsistenz: Doku, Anforderungen und Implementierung widersprechen sich nicht (Namen, Grenzwerte, Fehlercodes).