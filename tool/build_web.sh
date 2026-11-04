#!/usr/bin/env bash
# Baut die Web-Version (E-53) nach build/web_app: WebAssembly-Dateien holen bzw. bauen (tool/web_assets.sh), das
# Matrix-SDK für den verschlüsselten Browser-Speicher patchen (tool/web_matrix_patch.sh) und `flutter build web`.
#   tool/build_web.sh                           Basispfad /
#   BASE_HREF=/FamilyNexus/ tool/build_web.sh  für GitHub Pages unter einem Unterpfad
# Danach prüfen: tool/web_selftest.sh (Datenbank, Tresor, vodozemac) und tool/web_smoke.py (Start, Tresor, Entsperren).
# Lokal danach `tool/web_matrix_patch.sh --undo`, damit pubspec.lock wieder das unveränderte SDK beschreibt.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f web/sqlite3mc.wasm ] && [ -d web/pkg ] || tool/web_assets.sh
# Die wasm-Datei muss zur Dart-Anbindung passen (#266): Prüfsumme aus tool/web_assets.sh.
mc_sha256=$(sed -n 's/^mc_sha256=\([0-9a-f]*\).*/\1/p' tool/web_assets.sh)
echo "$mc_sha256  web/sqlite3mc.wasm" | shasum -a 256 -c - >/dev/null 2>&1 || {
  echo "web/sqlite3mc.wasm passt nicht zu tool/web_assets.sh: tool/web_assets.sh ausführen (baut auch vodozemac neu)" >&2
  echo "oder nur die wasm-Datei holen: curl -fsSL -o web/sqlite3mc.wasm https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$(sed -n 's/^sqlite3_version=\([0-9.]*\).*/\1/p' tool/web_assets.sh)/sqlite3mc.wasm" >&2
  exit 1
}
[ -f pubspec_overrides.yaml ] || tool/web_matrix_patch.sh
flutter build web --release --no-web-resources-cdn --base-href "${BASE_HREF:-/}" --output build/web_app
echo "Web-Version: build/web_app (Basispfad ${BASE_HREF:-/})"
