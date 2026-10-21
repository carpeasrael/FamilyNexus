#!/usr/bin/env bash
# Release-Build mit Dart-Obfuskierung. Debug-Symbole liegen außerhalb des Pakets
# (debug-info/, nicht eingecheckt). Signatur nur über android/key.properties.
#
#   tool/build_release.sh          APK (zum direkten Verteilen/Testen)
#   tool/build_release.sh aab      Android App Bundle (Google Play)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p debug-info
kind="${1:-apk}"; shift || true
case "$kind" in
  apk) flutter build apk --release --obfuscate --split-debug-info=debug-info "$@" ;;
  aab) flutter build appbundle --release --obfuscate --split-debug-info=debug-info "$@" ;;
  *) echo "Aufruf: tool/build_release.sh [apk|aab]"; exit 2 ;;
esac
if [ ! -f android/key.properties ]; then
  echo "HINWEIS: android/key.properties fehlt – das Paket ist UNSIGNIERT und nicht für Google Play geeignet (siehe docs/STORE.md)." >&2
fi
