#!/usr/bin/env bash
# Baut tool/web_selftest.dart als Web-App, öffnet sie in Chrome (headless) und prüft, dass der Selbsttest besteht:
# SQLite3MultipleCiphers, Tresor (WebCrypto), vodozemac (WebAssembly) und die Inhaltsrichtlinie aus web/index.html.
# Vorbedingung: web/sqlite3mc.wasm und web/pkg/ (tool/web_assets.sh), Chrome/Chromium. Fehlt der SDK-Patch
# (tool/web_matrix_patch.sh), legt das Skript ihn an; lokal danach `tool/web_matrix_patch.sh --undo`.
set -euo pipefail
cd "$(dirname "$0")/.."
chrome="${CHROME:-}"
if [ -z "$chrome" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then chrome="$c"; break; fi
  done
fi
[ -n "$chrome" ] || { echo "Chrome nicht gefunden (CHROME=… setzen)" >&2; exit 1; }
[ -f web/sqlite3mc.wasm ] && [ -d web/pkg ] || { echo "Erst tool/web_assets.sh ausführen" >&2; exit 1; }
# Die wasm-Datei muss zur Dart-Anbindung passen (#266): Prüfsumme aus tool/web_assets.sh.
mc_sha256=$(sed -n 's/^mc_sha256=\([0-9a-f]*\).*/\1/p' tool/web_assets.sh)
echo "$mc_sha256  web/sqlite3mc.wasm" | shasum -a 256 -c - >/dev/null 2>&1 || {
  echo "web/sqlite3mc.wasm passt nicht zu tool/web_assets.sh: tool/web_assets.sh ausführen (baut auch vodozemac neu)" >&2
  echo "oder nur die wasm-Datei holen: curl -fsSL -o web/sqlite3mc.wasm https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$(sed -n 's/^sqlite3_version=\([0-9.]*\).*/\1/p' tool/web_assets.sh)/sqlite3mc.wasm" >&2
  exit 1
}
# Wie im Release-Workflow: das Matrix-SDK speichert im Browser nur mit dem Patch in unserer Datenbank (E-53).
[ -f pubspec_overrides.yaml ] || { tool/web_matrix_patch.sh; patched=true; }

flutter build web --release --no-web-resources-cdn --base-href / -t tool/web_selftest.dart --output build/web_selftest
port=$((20000 + RANDOM % 20000))
python3 -m http.server "$port" --bind 127.0.0.1 --directory build/web_selftest >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT
sleep 1
profile=$(mktemp -d)
# Je Durchlauf startet Chrome mit demselben Profil; das Ergebnis steht in der Konsole (stderr).
run_page() {
  local query="$1" log="$profile/err-$2.log"
  "$chrome" --headless=new --disable-gpu --no-sandbox --user-data-dir="$profile/data" --enable-logging=stderr --v=0 \
    "http://127.0.0.1:$port/$query" 2>"$log" >/dev/null &
  browser=$!
  for _ in $(seq 1 120); do
    grep -q 'SELFTEST \(PASS\|FAIL\)' "$log" && break
    sleep 1
  done
  # localStorage schreibt Chrome verzögert auf die Platte; vor dem Beenden kurz warten.
  sleep 6
  kill $browser 2>/dev/null || true
  wait $browser 2>/dev/null || true
  grep -E 'SELFTEST|^ok |FAIL ' "$log" | sed 's/^.*CONSOLE:[0-9]*\] //' | head -40
  if ! grep -q 'SELFTEST PASS' "$log"; then
    echo "--- Browser-Konsole ($1) ---" >&2
    grep -i -E 'CONSOLE|csp|content security|refused' "$log" | head -30 >&2 || true
    rm -rf "$profile"; exit 1
  fi
}
trap 'kill $server 2>/dev/null || true' EXIT
# Zuerst der Start wie in der App, auf dem frischen Profil ohne vorherigen Datenbankzugriff (#266).
run_page "?phase=boot" boot
run_page "" all
run_page "?phase=write" write
run_page "?phase=read" read
rm -rf "$profile"
echo "Selbsttest bestanden."
[ "${patched:-false}" = true ] && echo "SDK-Patch wurde angelegt: lokal danach tool/web_matrix_patch.sh --undo" || true
