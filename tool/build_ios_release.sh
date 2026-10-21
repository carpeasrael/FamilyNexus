#!/usr/bin/env bash
# iOS-Release für App Store Connect (IPA, obfuskiert). Voraussetzungen: Apple-Entwicklerkonto, in Xcode
# angemeldet; Team-ID in ios/ExportOptions.plist eingetragen (siehe docs/STORE.md).
#   tool/build_ios_release.sh            IPA bauen und signieren
#   tool/build_ios_release.sh --check    nur Übersetzbarkeit prüfen (ohne Signatur, kein Upload möglich)
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"
mkdir -p debug-info
if [ "${1:-}" = "--check" ]; then
  flutter build ios --release --no-codesign --obfuscate --split-debug-info=debug-info
  exit 0
fi
if grep -q HIER_TEAM_ID_EINTRAGEN ios/ExportOptions.plist; then
  echo "FEHLER: Team-ID in ios/ExportOptions.plist eintragen." >&2; exit 1
fi
flutter build ipa --release --obfuscate --split-debug-info=debug-info --export-options-plist=ios/ExportOptions.plist
echo "IPA: build/ios/ipa/ – Hochladen mit Xcode „Transporter“ oder: xcrun altool --upload-app -f <ipa> -t ios (siehe docs/STORE.md)"
