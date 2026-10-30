#!/usr/bin/env bash
# Baut das Linux-Bundle (Flatpak, x86_64) nach build/flatpak/FamilyNexus-v<Version>.flatpak (+ .sha256).
# Braucht flatpak sowie Netzzugriff (Flathub-Laufzeit, pub, crates, Flutter-Engine). flatpak-builder wird vom
# System genommen; fehlt es, das Flatpak org.flatpak.Builder von Flathub (wird bei Bedarf installiert).
#
#   tool/build_flatpak.sh              Bundle bauen
#   tool/build_flatpak.sh --install    zusätzlich für den aktuellen Benutzer installieren
set -euo pipefail
cd "$(dirname "$0")/.."

install=false
case "${1:-}" in
  "") ;;
  --install) install=true ;;
  *) echo "Aufruf: tool/build_flatpak.sh [--install]"; exit 2 ;;
esac

app_id=de.inneso.familynexus
runtime_version=51
version=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' pubspec.yaml)
[ -n "$version" ] || { echo "Version in pubspec.yaml nicht gefunden" >&2; exit 1; }
out="build/flatpak"
bundle="$out/FamilyNexus-v$version.flatpak"

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive --or-update flathub \
  "org.gnome.Platform//$runtime_version" "org.gnome.Sdk//$runtime_version"

if command -v flatpak-builder >/dev/null 2>&1; then
  builder=(flatpak-builder)
else
  flatpak info --user org.flatpak.Builder >/dev/null 2>&1 || flatpak info --system org.flatpak.Builder >/dev/null 2>&1 ||
    flatpak install --user --noninteractive flathub org.flatpak.Builder
  builder=(flatpak run org.flatpak.Builder)
fi

mkdir -p "$out"
"${builder[@]}" --user --force-clean --disable-rofiles-fuse \
  --state-dir="$out/state" --repo="$out/repo" "$out/build" flatpak/$app_id.yml
flatpak build-bundle "$out/repo" "$bundle" "$app_id"
(cd "$out" && sha256sum "$(basename "$bundle")" > "$(basename "$bundle").sha256")
echo "Fertig: $bundle"

if $install; then
  flatpak install --user --noninteractive --reinstall "$bundle"
  echo "Installiert. Start: flatpak run $app_id"
fi
