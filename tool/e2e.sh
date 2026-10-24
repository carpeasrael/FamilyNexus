#!/usr/bin/env bash
# Ende-zu-Ende-Tests gegen einen lokalen Synapse (Docker) mit echter vodozemac-Bibliothek.
# Voraussetzungen: Docker, Rust (cargo), Flutter. Räumt den Test-Homeserver am Ende auf.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"
VOD_SRC="$(ls -d "$HOME"/.pub-cache/hosted/pub.dev/flutter_vodozemac-*/rust | tail -1)"
export CARGO_TARGET_DIR=/tmp/vod-target
[ -f /tmp/vod-target/release/libvodozemac_bindings_dart.dylib ] || (cd "$VOD_SRC" && cargo build --release --locked)
tool/synapse/up.sh
trap 'tool/synapse/down.sh' EXIT
# OAuth-Teil der Gateway-Unit-Tests braucht vodozemac (PKCE); ohne Bibliothek wird er in `flutter test` übersprungen.
FN_VOD_LIB=/tmp/vod-target/release/ flutter test test/data/sdk_registration_test.dart
FN_E2E=1 FN_VOD_LIB=/tmp/vod-target/release/ flutter test test/e2e --concurrency=1 "$@"
