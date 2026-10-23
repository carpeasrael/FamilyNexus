#!/usr/bin/env bash
# Holt die beiden WebAssembly-Dateien, die die Web-Version (E-53) neben dem Dart-Code braucht, nach web/:
#   web/sqlite3mc.wasm   SQLite3MultipleCiphers (Verschlüsselung der lokalen Datenbank), Release von sqlite3.dart,
#                        Prüfsumme fest eingetragen
#   web/pkg/             vodozemac (Olm/Megolm) – aus dem Quellcode der passenden Version gebaut (Rust nightly,
#                        wasm-pack, flutter_rust_bridge_codegen), kein heruntergeladenes Binary
# Die Dateien werden nicht eingecheckt (.gitignore). Vorbedingung: curl, git, cargo/rustup, wasm-pack,
# flutter_rust_bridge_codegen 2.13.0 (siehe release.yml, Job `web`).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

sqlite3_version=3.5.2   # = Version des Pakets `sqlite3` in pubspec.lock
mc_sha256=62a34ec725631c0438e4255ce0c6059099bf8e7fb331e7d4d91a38e075f43a19
vodozemac_version=0.9.0 # = Version des Pakets `vodozemac` in pubspec.lock

grep -q "version: \"$sqlite3_version\"" <(grep -A8 '^  sqlite3:' pubspec.lock) || { echo "sqlite3 in pubspec.lock ist nicht $sqlite3_version" >&2; exit 1; }
grep -q "version: \"$vodozemac_version\"" <(grep -A8 '^  vodozemac:' pubspec.lock) || { echo "vodozemac in pubspec.lock ist nicht $vodozemac_version" >&2; exit 1; }

curl -fsSL -o web/sqlite3mc.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqlite3_version/sqlite3mc.wasm"
echo "$mc_sha256  web/sqlite3mc.wasm" | shasum -a 256 -c -

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
git clone -q --depth 1 -b "$vodozemac_version" https://github.com/famedly/dart-vodozemac.git "$work/vz"
# WASM_RUSTUP_TOOLCHAIN: Rust-Nightly (der Build braucht `-Z build-std`), im CI auf ein festes Datum gesetzt.
(cd "$work/vz" && flutter_rust_bridge_codegen build-web --dart-root dart --rust-root "$(pwd)/rust" --release \
  --wasm-pack-rustup-toolchain "${WASM_RUSTUP_TOOLCHAIN:-nightly}")
rm -rf web/pkg
mv "$work/vz/dart/web/pkg" web/pkg
ls -l web/pkg
