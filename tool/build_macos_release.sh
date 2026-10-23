#!/usr/bin/env bash
# macOS-Release für App Store Connect (Archiv + signiertes Paket, obfuskiert). Voraussetzungen: Apple-Entwicklerkonto,
# in Xcode angemeldet; Team-ID in macos/ExportOptions.plist eingetragen (siehe docs/STORE.md).
#   tool/build_macos_release.sh            Archiv bauen, signieren und als Paket exportieren
#   tool/build_macos_release.sh --check    nur Übersetzbarkeit prüfen (ohne Signatur, kein Upload möglich)
#   tool/build_macos_release.sh --xcode    Archiv bauen und in Xcode öffnen (Organizer: Distribute App)
#
# Das Archiv wird bewusst nur ad hoc signiert (`-`) und erst beim Export mit der Distribution-Signatur versehen.
# Grund: ein mit Team-Zertifikat signiertes `xcodebuild archive` verlangt ein Entwicklungsprofil und damit ein beim
# Team registriertes Gerät; für den Mac App Store ist das nicht nötig (wie bei tool/build_ios_release.sh).
# Ganz ohne Signatur (CODE_SIGNING_ALLOWED=NO) gingen die Sandbox-Berechtigungen aus Release.entitlements verloren;
# die Ad-hoc-Signatur behält sie, der Export übernimmt sie in die Distribution-Signatur.
# In der CI (ohne Xcode-Anmeldung) signiert ein App-Store-Connect-API-Schlüssel: ASC_KEY_PATH (.p8), ASC_KEY_ID und
# ASC_ISSUER_ID setzen; Xcode legt Zertifikat und Profil dann selbst an (cloudverwaltete Signatur).
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
auth=()
if [ -n "${ASC_KEY_PATH:-}" ]; then
  auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
archive=build/macos/FamilyNexus.xcarchive
rm -rf "$archive" build/macos/export
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$archive" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" PROVISIONING_PROFILE_SPECIFIER="" DEVELOPMENT_TEAM="$team" archive
if [ "${1:-}" = "--xcode" ]; then
  open "$archive"; exit 0
fi
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist macos/ExportOptions.plist \
  -exportPath build/macos/export -allowProvisioningUpdates ${auth[@]+"${auth[@]}"}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pkgutil --expand-full build/macos/export/FamilyNexus.pkg "$tmp/x"
app=$(find "$tmp/x" -maxdepth 4 -name FamilyNexus.app | head -1)
codesign -d --entitlements - "$app" 2>&1 | grep -q 'com.apple.security.app-sandbox' \
  || { echo "FEHLER: App-Sandbox fehlt im exportierten Paket." >&2; exit 1; }
codesign --verify --strict --deep "$app"
echo "Paket: build/macos/export/ – Hochladen mit Xcode „Transporter“ oder Organizer (siehe docs/STORE.md)"
