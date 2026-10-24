#!/usr/bin/env bash
# macOS-DMG für den Download außerhalb des App Stores (obfuskiert, Developer-ID-signiert, von Apple notarisiert).
# Voraussetzungen: Apple-Entwicklerkonto; Team-ID in macos/ExportOptions-DeveloperID.plist.
#   tool/build_macos_dmg.sh            Archiv bauen, mit Developer ID exportieren, DMG erzeugen, notarisieren
#   tool/build_macos_dmg.sh --unsigned DMG nur mit Ad-hoc-Signatur (zum Testen; Gatekeeper blockiert das Öffnen)
#
# Signatur und Notarisierung laufen über einen App-Store-Connect-API-Schlüssel: ASC_KEY_PATH (.p8), ASC_KEY_ID und
# ASC_ISSUER_ID setzen (Rolle Admin; Xcode legt das Developer-ID-Zertifikat cloudverwaltet an). Lokal ohne Schlüssel
# signiert Xcode mit dem angemeldeten Konto, die Notarisierung entfällt dann mit Hinweis.
# Wie bei tool/build_macos_release.sh wird das Archiv nur ad hoc signiert; die Sandbox-Berechtigungen bleiben so
# erhalten. Hardened Runtime ist Pflicht für die Notarisierung und wird hier für das Archiv eingeschaltet.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"
version=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' pubspec.yaml)
mkdir -p debug-info build/macos/dmg
flutter build macos --release --obfuscate --split-debug-info=debug-info
team=$(sed -n '/<key>teamID<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' macos/ExportOptions-DeveloperID.plist)
archive=build/macos/FamilyNexus-DeveloperID.xcarchive
export_dir=build/macos/export-developer-id
rm -rf "$archive" "$export_dir"
# Hardened Runtime schaltet die Bibliotheksvalidierung ein: Frameworks müssen dann vom selben Team signiert sein. Beim
# Developer-ID-Export signiert Xcode alles mit demselben Team neu. Das unsignierte Test-DMG hat nur Ad-hoc-Signaturen
# ohne Team, dort bräche dyld beim Start mit „Library not loaded: FMDB.framework … different Team IDs“ ab (E-62).
runtime=YES
[ "${1:-}" = "--unsigned" ] && runtime=NO
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release -archivePath "$archive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" PROVISIONING_PROFILE_SPECIFIER="" DEVELOPMENT_TEAM="$team" \
  ENABLE_HARDENED_RUNTIME=$runtime archive
if [ "${1:-}" = "--unsigned" ]; then
  app="$archive/Products/Applications/FamilyNexus.app"
  dmg="build/macos/dmg/FamilyNexus-v${version}-macos-unsigned.dmg"
  # Ohne Hardened Runtime, sonst startet die App nicht (siehe oben); Fehler früh statt beim Nutzer.
  details=$(codesign -d -vv "$app" 2>&1)
  ! grep -q 'flags=.*runtime' <<<"$details" \
    || { echo "FEHLER: Das unsignierte DMG darf keine Hardened Runtime tragen (App startet sonst nicht)." >&2; exit 1; }
else
  auth=()
  if [ -n "${ASC_KEY_PATH:-}" ]; then
    auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
  fi
  xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist macos/ExportOptions-DeveloperID.plist \
    -exportPath "$export_dir" -allowProvisioningUpdates ${auth[@]+"${auth[@]}"}
  app="$export_dir/FamilyNexus.app"
  dmg="build/macos/dmg/FamilyNexus-v${version}-macos.dmg"
  codesign --verify --strict --deep "$app"
  # Ausgabe zuerst einlesen: `grep -q` in einer Pipe beendet codesign vorzeitig (SIGPIPE) und lässt pipefail fehlschlagen.
  entitlements=$(codesign -d --entitlements - "$app" 2>&1)
  grep -q 'com.apple.security.app-sandbox' <<<"$entitlements" \
    || { echo "FEHLER: App-Sandbox fehlt in der exportierten App." >&2; exit 1; }
  details=$(codesign -d -vv "$app" 2>&1)
  grep -q 'flags=.*runtime' <<<"$details" \
    || { echo "FEHLER: Hardened Runtime fehlt (Notarisierung würde abgelehnt)." >&2; exit 1; }
fi
# DMG mit App und Verknüpfung auf /Programme zum Hineinziehen.
staging=$(mktemp -d); trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "FamilyNexus ${version}" -srcfolder "$staging" -fs HFS+ -format UDZO "$dmg"
if [ "${1:-}" != "--unsigned" ]; then
  if [ -n "${ASC_KEY_PATH:-}" ]; then
    xcrun notarytool submit "$dmg" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
  else
    echo "HINWEIS: ohne ASC_KEY_PATH nicht notarisiert – vor der Weitergabe notarisieren (xcrun notarytool)." >&2
  fi
fi
(cd build/macos/dmg && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")
echo "DMG: $dmg"
