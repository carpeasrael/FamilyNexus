#!/usr/bin/env bash
# iOS-Release für App Store Connect (IPA, obfuskiert). Voraussetzungen: Apple-Entwicklerkonto, in Xcode
# angemeldet; Team-ID in ios/ExportOptions.plist eingetragen (siehe docs/STORE.md).
#   tool/build_ios_release.sh            IPA bauen und signieren
#   tool/build_ios_release.sh --check    nur Übersetzbarkeit prüfen (ohne Signatur, kein Upload möglich)
#
# Das Archiv wird bewusst UNSIGNIERT gebaut und erst beim Export mit der Distribution-Signatur versehen.
# Grund: `flutter build ipa` und ein signiertes `xcodebuild archive` verlangen ein Entwicklungsprofil und damit
# ein beim Team registriertes Gerät; für den App Store ist beides nicht nötig.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"
mkdir -p debug-info
# Setzt auch Obfuskierung und Symbolordner für den anschließenden xcodebuild-Lauf.
flutter build ios --release --no-codesign --obfuscate --split-debug-info=debug-info
if [ "${1:-}" = "--check" ]; then
  exit 0
fi
team=$(sed -n '/<key>teamID<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' ios/ExportOptions.plist)
if [ -z "$team" ] || [ "$team" = "HIER_TEAM_ID_EINTRAGEN" ]; then
  echo "FEHLER: Team-ID in ios/ExportOptions.plist eintragen." >&2; exit 1
fi
archive=build/ios/FamilyNexus.xcarchive
rm -rf "$archive" build/ios/ipa
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$archive" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="$team" archive
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/ipa -allowProvisioningUpdates
echo "IPA: build/ios/ipa/ – Hochladen mit Xcode „Transporter“ oder: xcrun altool --upload-app -f <ipa> -t ios (siehe docs/STORE.md)"
