#!/usr/bin/env bash
# Führt Integrationstests auf einem verbundenen Android-Gerät/Emulator aus.
# Hintergrund: Auf dieser Toolchain startet der Dart Development Service nicht
# zuverlässig; mit --no-dds meldet `flutter test` zusätzlich einen harmlosen
# „loading [E]“-Fehler (Golden-Comparator-Stream). Wir zählen nur echte
# Testfehler. Aufruf: tool/device_tests.sh [Gerät] [Testdateien…]
set -u
device="${1:-emulator-5554}"; shift || true
files=("$@")
# Standard: automatische Gerätetests. Manuelle Läufe (Rundreise, Zustellung) liegen in integration_test/manual/.
[ ${#files[@]} -eq 0 ] && files=(
  integration_test/db_security_test.dart
  integration_test/event_store_test.dart
  integration_test/matrix_sdk_smoke_test.dart
  integration_test/reminders_device_test.dart
)
log="$(mktemp)"
fail=0
for f in "${files[@]}"; do
  # Der VM-Service-Handshake ist gelegentlich flüchtig: bis zu 3 Versuche.
  for attempt in 1 2 3; do
    timeout 600 flutter test "$f" -d "$device" --no-dds >"$log" 2>&1
    grep -qE "VmServiceDisappeared" "$log" || break
    echo "Hinweis: VM-Service getrennt, Versuch $attempt wiederholt"; sleep 5
  done
  grep -E "^[0-9:]+ \+[0-9]+" "$log" | tail -1
  if ! grep -q "(tearDownAll)" "$log"; then echo "FEHLER: Lauf von $f nicht abgeschlossen"; tail -20 "$log"; fail=1; continue; fi
  if grep -E "\[E\]" "$log" | grep -vq "loading "; then
    echo "FEHLER: Testfehler in $f"; grep -E "\[E\]|Expected|Actual|Exception" "$log" | head -20; fail=1
  fi
done
rm -f "$log"
exit $fail
