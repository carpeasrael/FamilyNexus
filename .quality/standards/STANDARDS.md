# Coding-Standards (Quality-Gate)

Stabile Regel-IDs für Prüfbefunde. MUSS-Regeln → Verstoß mindestens MINOR; mit **[M]** markierte Regeln → mindestens MAJOR.
Projektspezifische Ergänzungen in einem eigenen Abschnitt am Ende pflegen (IDs nie wiederverwenden).

## STD-CODE – Codequalität (TypeScript/JavaScript)
- **STD-CODE-01 [M]** TypeScript `strict: true`; kein `any`, keine `as`-Casts ohne Typprüfung; `unknown` + Narrowing.
- **STD-CODE-02 [M]** ESLint (Flat Config, `typescript-eslint` strictTypeChecked + stylisticTypeChecked) ohne Warnungen; Prettier-formatiert.
- **STD-CODE-03 [M]** Keine Unterdrückungen (`eslint-disable`, `@ts-ignore`, `@ts-expect-error`) ohne genehmigte Ausnahme im ADR.
- **STD-CODE-04** Funktionen einzweckig; kognitive Komplexität ≤ 15; Parameter ≤ 4 (sonst Objektparameter).
- **STD-CODE-05** Sprechende Namen; keine Abkürzungen außer Domänenbegriffen; Booleans als `is/has/can…`.
- **STD-CODE-06 [M]** Fehlerbehandlung: keine leeren `catch`; Fehler mit Ursache (`cause`) weiterreichen; keine verschluckten Promises (`no-floating-promises`).
- **STD-CODE-07** Unveränderlichkeit bevorzugen (`const`, `readonly`, keine Mutation von Parametern).
- **STD-CODE-08** Kein toter, auskommentierter oder duplizierter Code; keine Debug-Reste (`console.log`, `debugger`).
- **STD-CODE-09** Schichtgrenzen und bestehende Muster einhalten; keine zyklischen Abhängigkeiten.
- **STD-CODE-10** Öffentliche API minimal; Breaking Changes nur mit Versionierung und CHANGELOG.

## STD-SEC – Sicherheit (OWASP Top 10:2025, ASVS 5.0 L2, CWE Top 25)
- **STD-SEC-01 [M]** Jede Eingabe an einer Vertrauensgrenze wird schema-validiert (Typ, Länge, Format, Wertebereich), Allowlist vor Denylist.
- **STD-SEC-02 [M]** Autorisierung serverseitig je Zugriff und Objekt (kein IDOR); Deny-by-default.
- **STD-SEC-03 [M]** Keine Injection: parametrisierte Abfragen, kein `eval`/`new Function`, keine Shell-Aufrufe mit Eingaben, kontextgerechte Ausgabekodierung (XSS).
- **STD-SEC-04 [M]** Keine Geheimnisse in Code, Tests, Logs, Fehlermeldungen oder URLs; Konfiguration über Umgebung/Secret-Store.
- **STD-SEC-05 [M]** Kryptografie nur über etablierte Bibliotheken/Web Crypto; Passwörter Argon2id/bcrypt; sichere Zufallszahlen.
- **STD-SEC-06** Größen-, Raten- und Zeitlimits für alle extern auslösbaren Operationen (DoS-Schutz).
- **STD-SEC-07 [M]** SSRF- und Pfad-Traversal-Schutz bei URL/Pfad aus Eingaben (Allowlist, Normalisierung, Basisverzeichnis-Prüfung).
- **STD-SEC-08** Sichere Defaults: Security-Header, CSP, restriktives CORS, Cookie-Flags `HttpOnly; Secure; SameSite`.
- **STD-SEC-09 [M]** Lieferkette: neue Abhängigkeit nur mit Begründung, aktiver Pflege, passender Lizenz, ohne bekannte High/Critical-CVE.
- **STD-SEC-10 [M]** Fehlerbehandlung fail-closed; keine Stacktraces oder Interna nach außen (A10:2025).
- **STD-SEC-11** Sicherheitsrelevante Ereignisse werden protokolliert, ohne personenbezogene Daten oder Secrets (A09:2025).
- **STD-SEC-12 [M]** Keine unsichere Deserialisierung; Schutz vor Prototype Pollution und ReDoS.

## STD-PERF – Performance und Skalierung
- **STD-PERF-01 [M]** Datenintensive Änderungen haben ein Performance-Budget in den Anforderungen (Datenmenge, Latenz p95, Speicher).
- **STD-PERF-02 [M]** Hot Paths ohne quadratische Laufzeit über unbegrenzte Sammlungen; Lookups über Map/Set.
- **STD-PERF-03 [M]** Große Datenmengen: Paginierung/Cursor, Streaming oder Batching statt Vollladen.
- **STD-PERF-04 [M]** Keine N+1-Zugriffe; Indizes für neue Filter/Sortierungen.
- **STD-PERF-05** Kein Blockieren des Event-Loops (synchrone I/O, große JSON-Operationen, CPU-Last) im Request-Pfad.
- **STD-PERF-06** Begrenzte Parallelität, Timeouts, Retries mit Backoff und Jitter; keine unbegrenzten Queues/Caches.
- **STD-PERF-07** Ressourcen (Streams, Listener, Timer, Verbindungen) werden zuverlässig freigegeben.
- **STD-PERF-08** Frontend: keine unnötigen Re-Renders, lange Listen virtualisiert, Code-Splitting für große Module.

## STD-TEST – Tests
- **STD-TEST-01 [M]** Jedes Abnahmekriterium hat mindestens einen Test mit der AC-ID im Testnamen.
- **STD-TEST-02 [M]** Tests entstehen vor der Implementierung (test-first) und schlagen ohne Implementierung fehl.
- **STD-TEST-03 [M]** Negativ-, Grenz- und Fehlerfälle sind abgedeckt.
- **STD-TEST-04 [M]** Deterministisch: keine echte Zeit, kein Netzwerk, kein ungeseedeter Zufall; kein `.only`/`.skip`.
- **STD-TEST-05** Coverage geänderter Zeilen ≥ 90 % Lines, ≥ 80 % Branches.
- **STD-TEST-06** Mocks nur an Systemgrenzen; Assertions prüfen Verhalten, nicht Implementierungsdetails.
- **STD-TEST-07** Lasttest/Benchmark, wenn ein Performance-Budget existiert.

## STD-DOC – Dokumentation
- **STD-DOC-01 [M]** TSDoc für alle exportierten Symbole (Zweck, Parameter, Rückgabe, `@throws`).
- **STD-DOC-02 [M]** README/Benutzerdoku bei Verhaltensänderung aktualisiert.
- **STD-DOC-03** CHANGELOG-Eintrag (Keep a Changelog), Commit nach Conventional Commits.
- **STD-DOC-04** ADR (`docs/adr/NNNN-titel.md`) für Architektur- oder Sicherheitsentscheidungen.
- **STD-DOC-05** Kommentare erklären das Warum; keine veralteten Kommentare.

## STD-DI – Datenintegrität (immer anwenden, bei GxP-Kontext verschärft)
- **STD-DI-01 [M]** Änderungen an fachlichen Daten sind zuordenbar (wer, wann, was, warum) – ALCOA+.
- **STD-DI-02 [M]** Audit-Trail-Einträge sind unveränderbar und werden nicht durch Fehlerpfade übersprungen.
- **STD-DI-03** Zeitstempel in UTC, serverseitig erzeugt.
