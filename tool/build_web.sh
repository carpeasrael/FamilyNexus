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
[ -f pubspec_overrides.yaml ] || tool/web_matrix_patch.sh
flutter build web --release --no-web-resources-cdn --base-href "${BASE_HREF:-/}" --output build/web_app
echo "Web-Version: build/web_app (Basispfad ${BASE_HREF:-/})"
