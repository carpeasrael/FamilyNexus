**Im Modus DESIGN:**
- Enthalten die Anforderungen ein Performance-Budget mit Datenmengen? Fehlt es bei datenintensiver Änderung → MAJOR.
- Ist die Laufzeit-/Speicherkomplexität je Hot Path bei den geforderten Datenmengen angegeben und tragfähig (mind. 10⁵ annehmen)?
- Sind Paginierung/Streaming/Batching, Limits, Timeouts, Nebenläufigkeitsgrenzen, Indizes vorgesehen?
- Gibt es einen Last-/Benchmark-Test mit realistischem Datengenerator, wenn ein Budget existiert?

**Im Modus CODE:**
Bezug: STD-PERF und das Performance-Budget in den Anforderungen.
- Werkzeuge: `npm run bench` falls vorhanden; sonst Analyse + Messvorschlag. Ergebnis gegen das Budget (Latenz, Durchsatz, Speicher) bewerten.
- Algorithmik: Laufzeit- und Speicherkomplexität jedes Hot Paths bei der geforderten Datenmenge (mind. 10⁵ Elemente annehmen, wenn nicht spezifiziert). Verschachtelte Schleifen über Sammlungen, wiederholte `find`/`includes` in Schleifen → Map/Set.
- Große Anfragen und Daten: Paginierung/Cursor, Streaming statt Vollladen, Batching, Größenlimits für Request-Bodies und Uploads, Backpressure bei Streams.
- Datenzugriff: keine N+1-Abfragen, passende Indizes für neue Filter/Sortierungen, Projektion statt `SELECT *`, Transaktionen kurz.
- Event-Loop: keine synchronen Datei-/Krypto-/Kompressionsaufrufe im Request-Pfad, kein `JSON.parse/stringify` sehr großer Objekte im Hot Path, CPU-lastige Arbeit in Worker Threads/Jobs.
- Nebenläufigkeit: begrenzte Parallelität (Pool/Limit), Timeouts, Retries mit Backoff und Jitter, keine unbegrenzten Queues.
- Ressourcen: Listener, Intervalle, Streams, DB-Verbindungen werden freigegeben; keine unbegrenzt wachsenden Caches (TTL/LRU).
- Frontend (falls betroffen): unnötige Re-Renders, Memoisierung, Virtualisierung langer Listen, Bundle-Größe/Code-Splitting, Lazy Loading.
- Fehlt ein Budget bei erkennbar datenintensiver Änderung → MAJOR (Anforderungslücke).