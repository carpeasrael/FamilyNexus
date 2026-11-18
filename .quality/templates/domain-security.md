**Im Modus DESIGN:**
- Sind alle Vertrauensgrenzen benannt und je Eingabe eine Schema-Validierung vorgesehen?
- Autorisierung: an welchen Punkten, je Objekt (IDOR)? Deny-by-default?
- Bedrohungen je Vertrauensgrenze (STRIDE) adressiert – bei Komplexität high Pflicht.
- Geheimnisse, Kryptografie, neue Abhängigkeiten (Lieferkette) begründet und sicher gewählt?
- Fehlerverhalten fail-closed, keine Interna nach außen, Sicherheitslogging vorgesehen?
- Gibt es Tests für Missbrauchsfälle (fehlende Rechte, Injection-Muster, Übergrößen)?

**Im Modus CODE:**
Bezug: STD-SEC (OWASP Top 10:2025, OWASP ASVS 5.0 Level 2, CWE Top 25).
- Werkzeuge ausführen: `semgrep scan --config p/owasp-top-ten --config p/typescript --error --metrics=off <Dateien>`, `gitleaks protect --staged --redact --no-banner`, `npm audit --audit-level=high --omit=dev` (bei geänderten Abhängigkeiten).
- Vertrauensgrenzen identifizieren: jede Eingabe aus Request, Datei, Umgebung, Drittsystem, LLM-Ausgabe ist untrusted.
- A01 Zugriffskontrolle: serverseitige Autorisierung je Objekt (IDOR), Deny-by-default, SSRF (Ziel-Allowlist, keine internen Adressen), Pfad-Traversal.
- A02 Fehlkonfiguration: Security-Header/CSP, CORS restriktiv, Cookies `HttpOnly; Secure; SameSite`, Debug aus.
- A03 Lieferkette: neue Abhängigkeiten begründet, gepflegt, Lizenz passend, keine install-Skripte unbekannter Pakete, Lockfile konsistent.
- A04 Kryptografie: nur etablierte Verfahren (Argon2id/bcrypt für Passwörter, AES-GCM, SHA-256+), `crypto.randomUUID`/`getRandomValues` statt `Math.random` für Sicherheitszwecke, keine eigenen Krypto-Bauteile.
- A05 Injection: parametrisierte Abfragen, kein `eval`/`new Function`/`child_process` mit Eingaben, XSS (kein `innerHTML`/`dangerouslySetInnerHTML` mit Eingaben), Template-/Header-/Log-Injection, ReDoS-anfällige Regex, Prototype Pollution (`__proto__`, Merge-Funktionen).
- A06 Unsicheres Design: Missbrauchsfälle, Rate-Limits, Größenlimits (Body, Upload, Array-Längen), Idempotenz.
- A07 Authentifizierung: Session-Handling, Token-Validierung (Signatur, Ablauf, Audience), kein Credential im Log/URL.
- A08 Integrität: keine unsichere Deserialisierung, Signaturprüfung von Updates/Artefakten.
- A09 Logging & Alarmierung: sicherheitsrelevante Ereignisse protokolliert, ohne Secrets/personenbezogene Daten.
- A10 Ausnahmebehandlung: Fehlerpfade fail-closed, keine Stacktraces/Interna nach außen, keine Zustandsinkonsistenz nach Fehlern.
- Geheimnisse: nichts im Code, in Tests, Fixtures, Kommentaren oder Logs.