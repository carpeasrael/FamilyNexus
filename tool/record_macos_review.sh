#!/usr/bin/env bash
# Nimmt das Review-Video der macOS-App auf (Apple-Punkt 1, Testplan TP-FN-VR-121, Abschnitt 4, K-09).
# Die Aufnahme beginnt vor dem Start der App und läuft bis zur Eingabetaste; der Ablauf (Drehbuch S-01 bis S-14) wird
# von Hand durchgespielt; am Ende (Eingabetaste) zeigt das Video die macOS-Version. Ausgabe: Test-Apple/verification_1.2.1/FamilyNexus_<Version>_<Build>_Mac.mov
#
# Vorab: Terminal braucht „Bildschirmaufnahme“ (Systemeinstellungen → Datenschutz & Sicherheit). Lokale Daten
# leeren (Einstellungen → „Alle lokalen Daten löschen“), Fokus „Nicht stören“ an, Schreibtisch ohne persönliche
# Inhalte, Systemsprache Englisch, Mikrofon wird nicht aufgenommen.
# Aufruf: tool/record_macos_review.sh [App-Pfad]   (Standard: das Release-Build in build/macos)
set -euo pipefail
cd "$(dirname "$0")/.."

app="${1:-build/macos/Build/Products/Release/FamilyNexus.app}"
[ -d "$app" ] || { echo "App nicht gefunden: $app (tool/build_macos_release.sh)" >&2; exit 1; }

plist="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$plist")
build=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$plist")
soll=$(sed -n 's/^version: \([0-9.]*\)+\(.*\)/\1 \2/p' pubspec.yaml)
[ "$soll" = "$version $build" ] || echo "Warnung: App $version ($build), pubspec.yaml $soll" >&2

if pgrep -x FamilyNexus >/dev/null; then
  echo "FamilyNexus läuft noch. Bitte beenden (⌘Q), die Aufnahme muss mit dem Kaltstart beginnen." >&2
  exit 1
fi

dir="Test-Apple/verification_1.2.1"
mkdir -p "$dir"
out="$dir/FamilyNexus_${version}_${build}_Mac.mov"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(sysctl -n hw.model), App $version ($build)"

# -v Video, -C Mauszeiger mitaufnehmen; ohne Ton.
screencapture -v -C "$out" &
rec=$!
trap 'kill -INT "$rec" 2>/dev/null || true; wait "$rec" 2>/dev/null || true' EXIT INT

sleep 3
open "$app"   # S-01: Start der App im Video sichtbar
echo "Aufnahme läuft. Drehbuch durchspielen; zum Beenden hier im Terminal die Eingabetaste drücken (S-15)."
read -r _

# S-16: Terminal nach vorn, nur die Systemversion zeigen (kein Rechnername, keine Seriennummer), dann beenden.
open -a Terminal
sleep 2
clear
printf '\n  macOS %s (%s)\n  %s\n\n' "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" "$(sw_vers -productName)"
sleep 8
kill -INT "$rec" 2>/dev/null || true
wait "$rec" 2>/dev/null || true

echo "Gespeichert: $out ($(du -h "$out" | cut -f1)), SHA-256: $(shasum -a 256 "$out" | cut -d' ' -f1)"
