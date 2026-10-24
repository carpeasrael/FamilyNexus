#!/usr/bin/env bash
# Bildschirmfotos aller Einrichtungsschritte für die manuelle Prüfung (Testplan Onboarding, TP-MAN-*).
# Rendert auf dem Rechner mit den echten Schriften der App (Fake-Matrix, kein Gerät nötig).
# Ergebnis: build/onboarding_tour/NN-name.png (anderer Ordner: FN_SCREENSHOTS_DIR=…)
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")}"
export FLUTTER_ROOT
rm -rf "${FN_SCREENSHOTS_DIR:-build/onboarding_tour}"
FN_SCREENSHOTS=1 flutter test test/manual/onboarding_screens_test.dart "$@"
ls -1 "${FN_SCREENSHOTS_DIR:-build/onboarding_tour}"
