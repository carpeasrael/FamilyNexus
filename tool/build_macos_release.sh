#!/usr/bin/env bash
# macOS-Release für App Store Connect (Archiv + signiertes Paket, obfuskiert). Voraussetzungen: Apple-Entwicklerkonto,
# in Xcode angemeldet; Team-ID in macos/ExportOptions.plist eingetragen (siehe docs/STORE.md).
#   tool/build_macos_release.sh            Archiv bauen, signieren und als Paket exportieren
#   tool/build_macos_release.sh --check    nur Übersetzbarkeit prüfen (ohne Signatur, kein Upload möglich)
#   tool/build_macos_release.sh --xcode    Archiv bauen und in Xcode öffnen (Organizer: Distribute App)
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"
mkdir -p debug-info
flutter build macos --release --obfuscate --split-debug-info=debug-info
if [ "${1:-}" = "--check" ]; then
  exit 0
fi
team=$(sed -n '/<key>teamID<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' macos/ExportOptions.plist)
if [ -z "$team" ] || [ "$team" = "HIER_TEAM_ID_EINTRAGEN" ]; then
  echo "FEHLER: Team-ID in macos/ExportOptions.plist eintragen." >&2; exit 1
fi
archive=build/macos/FamilyNexus.xcarchive
rm -rf "$archive"
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$archive" -allowProvisioningUpdates DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" archive
if [ "${1:-}" = "--xcode" ]; then
  open "$archive"; exit 0
fi
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist macos/ExportOptions.plist \
  -exportPath build/macos/export -allowProvisioningUpdates
echo "Paket: build/macos/export/ – Hochladen mit Xcode „Transporter“ oder Organizer (siehe docs/STORE.md)"
