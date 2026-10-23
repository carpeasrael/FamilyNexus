#!/usr/bin/env bash
# Läuft innerhalb von flatpak-builder (Modul „familynexus“, siehe de.inneso.familynexus.yml) in der SDK-Umgebung.
# Baut Flutter-Release (obfuskiert) und installiert nach /app. Symbole landen in der Debug-Erweiterung.
set -euo pipefail
root="$PWD"
export HOME="$root/.home"
export PUB_CACHE="$root/.pub-cache"
export CARGO_HOME="$root/.cargo"
export RUSTUP_HOME="$root/.rustup"
export PATH="$root/.flutter-sdk/bin:$CARGO_HOME/bin:$PATH"
export CI=true
mkdir -p "$HOME"

# Rust (für vodozemac): rustup-init wurde mit Prüfsumme als Quelle geladen.
chmod +x rustup-init
./rustup-init -y --profile minimal --default-toolchain stable --no-modify-path

flutter config --no-analytics --no-cli-animations >/dev/null
flutter --version
flutter pub get
debug_dir="/app/lib/debug/share/familynexus-symbols"
mkdir -p "$debug_dir"
flutter build linux --release --obfuscate --split-debug-info="$debug_dir"

bundle="build/linux/x64/release/bundle"
mkdir -p /app/bin /app/familynexus
cp -a "$bundle"/. /app/familynexus/
ln -sf /app/familynexus/familynexus /app/bin/familynexus

install -Dm644 flatpak/de.inneso.familynexus.desktop /app/share/applications/de.inneso.familynexus.desktop
install -Dm644 flatpak/de.inneso.familynexus.metainfo.xml /app/share/metainfo/de.inneso.familynexus.metainfo.xml
for n in 128 256 512; do
  install -Dm644 "flatpak/icons/${n}x${n}/de.inneso.familynexus.png" \
    "/app/share/icons/hicolor/${n}x${n}/apps/de.inneso.familynexus.png"
done
