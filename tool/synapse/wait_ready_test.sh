#!/usr/bin/env bash
# Regressionstest zu #281 (ohne Docker): wait_ready.sh darf HTTP-Fehler nicht als „bereit“ werten.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"; PID=""
cleanup() { [ -n "$PID" ] && kill "$PID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
FAIL=0
check() { if [ "$2" = "$3" ]; then echo "OK      $1"; else echo "FEHLER  $1 (erwartet $3, war $2)"; FAIL=1; fi; }

# Server: die ersten $1 Anfragen 502, danach 200; Zähler in $TMP/count; Port in $TMP/port.
start_server() {
  rm -f "$TMP/port" "$TMP/count"; echo 0 > "$TMP/count"
  python3 -I - "$1" "$TMP" <<'PY' &
import sys, http.server
n, tmp = int(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        c = int(open(tmp + "/count").read()) + 1
        open(tmp + "/count", "w").write(str(c))
        code = 502 if c <= n else 200
        body = b'{"versions":[]}'
        self.send_response(code); self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close"); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
open(tmp + "/port", "w").write(str(s.server_address[1]))
s.serve_forever()
PY
  PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$TMP/port" ] && break; sleep 0.1; done
  PORT="$(cat "$TMP/port")"
}
stop_server() { kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; PID=""; }
run() { FN_WAIT_TRIES=5 FN_WAIT_SLEEP=0.1 "$HERE/wait_ready.sh" "http://127.0.0.1:$PORT" Test >"$TMP/out" 2>&1; echo $?; }

# (a) zweimal 502, dann 200: kehrt erst nach dem 200 zurück
start_server 2; rc=$(run); n=$(cat "$TMP/count")
check "a: 502, 502, 200 -> Exit 0" "$rc" 0
check "a: Server sah mindestens 3 Anfragen" "$([ "$n" -ge 3 ] && echo ja || echo nein)" ja
stop_server

# (b) dauerhaft 502: Exit 1 und Meldung, genau FN_WAIT_TRIES Anfragen
start_server 1000; rc=$(run); n=$(cat "$TMP/count")
check "b: dauerhaft 502 -> Exit 1" "$rc" 1
check "b: Meldung \"nicht erreichbar\"" "$(grep -c 'nicht erreichbar' "$TMP/out")" 1
check "b: 5 Anfragen" "$n" 5
stop_server

# (c) geschlossener Port (eben noch vom Test belegt): Exit 1
rc=$(run)
check "c: geschlossener Port -> Exit 1" "$rc" 1

[ "$FAIL" = 0 ] && echo "Alle Fälle bestanden" || echo "Es gibt Fehler"
exit "$FAIL"
