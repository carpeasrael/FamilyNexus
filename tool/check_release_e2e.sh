#!/usr/bin/env bash
# Prüft vor einem Plattform-Build, ob für genau diesen Build ein E2E-Test dieser Plattform mit Screenshots belegt ist
# (E-103). Gegenstück zu tool/check_release_review.sh und mit demselben Fingerabdruck des App-Codes: Jede Änderung am
# App-Code, auch die Build-Nummer, verlangt einen neuen Lauf.
#
# Der Bericht docs/release-e2e/<Version>.md hat je Plattform einen Abschnitt:
#
#   ## android
#   - Testlauf: 2026-11-15_31_Release-1.2.3_main-531981a      (Ordner unter "User E2E Test Report/")
#   - Ergebnis: bestanden
#   - Screenshot: screenshots/RT3-V-02_And.png                (relativ zum Testlauf, mindestens 3 Zeilen)
#
# Aufruf:  tool/check_release_e2e.sh android            (eine oder mehrere Plattformen)
#          Plattformen: android ios macos linux windows web
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

min_screens=3
reports_dir="User E2E Test Report"

if [ "$#" -eq 0 ]; then
  echo "Aufruf: tool/check_release_e2e.sh <android|ios|macos|linux|windows|web>..." >&2
  exit 2
fi

eval "$(tool/check_release_review.sh --print | sed -n 's/^Version: */version=/p; s/^Fingerabdruck: */fingerprint=/p')"
report="docs/release-e2e/$version.md"
if [ ! -f "$report" ]; then
  echo "::error::Kein E2E-Beleg für $version ($report fehlt). E2E je Plattform mit Screenshots ausführen, Bericht ablegen und mergen." >&2
  exit 1
fi

reviewed=$(sed -n 's/^- Fingerabdruck: *//p' "$report" | head -n 1 | tr -d '\r')
if [ "$reviewed" != "$fingerprint" ]; then
  echo "::error::E2E-Beleg für $version passt nicht zum Code (Bericht: ${reviewed:-keiner}, Stand: $fingerprint). E2E für diesen Stand wiederholen." >&2
  exit 1
fi

fail=0
for platform in "$@"; do
  case "$platform" in
    android|ios|macos|linux|windows|web) ;;
    *) echo "::error::Unbekannte Plattform: $platform" >&2; exit 2 ;;
  esac

  # Abschnitt "## <platform>" bis zum nächsten "## ".
  section=$(awk -v p="## $platform" '
    { sub(/\r$/, "") }
    $0 == p { on = 1; next }
    /^## / { on = 0 }
    on { print }
  ' "$report")
  if [ -z "$section" ]; then
    echo "::error::$report: Abschnitt \"## $platform\" fehlt." >&2
    fail=1
    continue
  fi

  result=$(printf '%s\n' "$section" | sed -n 's/^- Ergebnis: *//p' | head -n 1)
  if [ "$result" != "bestanden" ]; then
    echo "::error::$platform: Ergebnis ist \"${result:-leer}\", verlangt ist \"bestanden\"." >&2
    fail=1
    continue
  fi

  run=$(printf '%s\n' "$section" | sed -n 's/^- Testlauf: *//p' | head -n 1)
  case "$run" in
    ""|*/*|*..*) echo "::error::$platform: Testlauf fehlt oder ist kein Ordnername." >&2; fail=1; continue ;;
  esac
  dir="$reports_dir/$run"
  if [ ! -f "$dir/Testreport.md" ]; then
    echo "::error::$platform: $dir/Testreport.md fehlt." >&2
    fail=1
    continue
  fi

  count=0
  missing=0
  while IFS= read -r shot; do
    [ -z "$shot" ] && continue
    case "$shot" in
      /*|*..*) echo "::error::$platform: Screenshot-Pfad nicht erlaubt: $shot" >&2; missing=1; continue ;;
    esac
    case "$shot" in
      *.png|*.PNG|*.jpg|*.jpeg|*.JPG|*.JPEG) ;;
      *) echo "::error::$platform: kein Bild: $shot" >&2; missing=1; continue ;;
    esac
    if [ -s "$dir/$shot" ]; then
      count=$((count + 1))
    else
      echo "::error::$platform: Screenshot fehlt oder ist leer: $dir/$shot" >&2
      missing=1
    fi
  done < <(printf '%s\n' "$section" | sed -n 's/^- Screenshot: *//p' | tr -d '\r')

  if [ "$missing" -ne 0 ]; then
    fail=1
    continue
  fi
  if [ "$count" -lt "$min_screens" ]; then
    echo "::error::$platform: $count Screenshots belegt, verlangt sind mindestens $min_screens." >&2
    fail=1
    continue
  fi
  echo "E2E $platform für $version belegt: $run, $count Screenshots."
done

[ "$fail" -eq 0 ] || exit 1
echo "E2E-Beleg für $version passt zum Code-Stand ($fingerprint)."
