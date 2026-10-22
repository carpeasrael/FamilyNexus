#!/usr/bin/env bash
# Trägt die Export-Compliance-Angaben in die Info.plist von iOS und macOS ein (siehe docs/export-compliance/README.md).
#   tool/set_export_compliance.sh <Schlüsselwert>   Verschlüsselung angegeben, Schlüsselwert von App Store Connect
#   tool/set_export_compliance.sh --no-code          nur ITSAppUsesNonExemptEncryption=YES (ohne Schlüsselwert)
# Danach Buildnummer in pubspec.yaml erhöhen und neu bauen: Änderungen an der Info.plist gelten erst im nächsten Build.
set -euo pipefail
cd "$(dirname "$0")/.."
arg="${1:-}"
if [ -z "$arg" ]; then
  echo "Aufruf: tool/set_export_compliance.sh <Schlüsselwert> | --no-code" >&2; exit 2
fi
if [ "$arg" != "--no-code" ] && ! [[ "$arg" =~ ^[A-Za-z0-9._-]{8,200}$ ]]; then
  echo "FEHLER: Der Schlüsselwert enthält unerwartete Zeichen (erlaubt: Buchstaben, Ziffern, . _ -)." >&2; exit 1
fi
pb=/usr/libexec/PlistBuddy
for plist in ios/Runner/Info.plist macos/Runner/Info.plist; do
  "$pb" -c "Delete :ITSAppUsesNonExemptEncryption" "$plist" 2>/dev/null || true
  "$pb" -c "Delete :ITSEncryptionExportComplianceCode" "$plist" 2>/dev/null || true
  "$pb" -c "Add :ITSAppUsesNonExemptEncryption bool true" "$plist"
  if [ "$arg" != "--no-code" ]; then
    "$pb" -c "Add :ITSEncryptionExportComplianceCode string $arg" "$plist"
  fi
  plutil -lint "$plist" >/dev/null
  echo "$plist: ITSAppUsesNonExemptEncryption=true${arg:+, Schlüsselwert gesetzt}"
done
