#!/usr/bin/env bash
# Prüft, dass jedes ABI-Verzeichnis im APK die Flutter-Bibliotheken enthält (#32). Liefern Plugins
# Bibliotheken für ein ABI, das Flutter nicht gebaut hat, installiert Android das APK trotzdem und die
# App stürzt beim Start ab (`libflutter.so … is for EM_AARCH64`).
# Aufruf: tool/check_apk_abis.sh [apk]
set -euo pipefail
apk="${1:-build/app/outputs/flutter-apk/app-release.apk}"
abis=$(unzip -Z1 "$apk" 'lib/*' | cut -d/ -f2 | sort -u)
[ -n "$abis" ] || { echo "Keine nativen Bibliotheken in $apk"; exit 1; }
fail=0
for abi in $abis; do
  for so in libflutter.so libapp.so; do
    if ! unzip -Z1 "$apk" "lib/$abi/$so" >/dev/null 2>&1; then
      echo "::error::lib/$abi/$so fehlt in $apk"
      fail=1
    fi
  done
done
[ "$fail" = 0 ] && echo "ABIs vollständig: $(echo $abis | tr '\n' ' ')"
exit "$fail"
