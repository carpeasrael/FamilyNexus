**Im Modus DESIGN:**
- Passt der Entwurf zu Architektur, Schichtgrenzen und bestehenden Mustern? Werden vorhandene Komponenten wiederverwendet?
- Sind Schnittstellen (Signaturen, Typen) typsicher und minimal entworfen; Breaking Changes erkannt und versioniert?
- Ist die Fehlerbehandlung als Konzept beschrieben (Fehlerklassen, Weitergabe mit Ursache)?
- Tests: folgen sie den Projektkonventionen; ESLint/Prettier-konform (`npx eslint <Testdateien>`, `npx prettier --check <Testdateien>`)?

**Im Modus CODE:**
Bezug: STD-CODE in `.quality/standards/STANDARDS.md`.
- Werkzeuge ausführen: `npx eslint <geänderte Dateien> --max-warnings=0`, `npx tsc --noEmit`, `npx prettier --check <Dateien>`; WebStorm-Inspektionen über `mcp__ide__getDiagnostics` je geänderter Datei.
- Typsicherheit: kein `any`/unsichere Casts, `strict`-konforme Nullbehandlung, exhaustive `switch` über Unions.
- Lesbarkeit: sprechende Namen, Funktionen klein und einzweckig (kognitive Komplexität ≤ 15), keine Duplikate, kein toter oder auskommentierter Code.
- Fehlerbehandlung: keine leeren `catch`, Fehler mit Kontext, `Promise`s immer behandelt (kein floating promise), Ressourcen in `finally` freigegeben.
- Unterdrückungen: jede neue `eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `.skip`/`.only` ist ein MAJOR.
- Architektur: Schichtgrenzen und bestehende Muster eingehalten, keine zyklischen Importe, öffentliche API minimal.
- Konsistenz mit Projektkonventionen (Ordnerstruktur, Benennung, Logging-Helfer, i18n falls vorhanden).
- Commit-Hygiene im Diff: keine fremden Änderungen, keine Debug-Reste (`console.log`, `debugger`).