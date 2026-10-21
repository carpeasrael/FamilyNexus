#!/usr/bin/env bash
# Prüft die Berechtigungen des fertigen (zusammengeführten) APK gegen die Freigabeliste.
# Aufruf: tool/check_permissions.sh [apk]
set -euo pipefail
apk="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
sdk="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
aapt2="$(ls "$sdk"/build-tools/*/aapt2 | tail -1)"
allowed=(
  android.permission.INTERNET
  android.permission.POST_NOTIFICATIONS
  android.permission.VIBRATE
  android.permission.USE_EXACT_ALARM
  android.permission.SCHEDULE_EXACT_ALARM
  android.permission.RECEIVE_BOOT_COMPLETED
  android.permission.USE_BIOMETRIC
  android.permission.CAMERA
  de.inneso.familynexus.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
)
bad=0
while read -r p; do
  ok=0
  for a in "${allowed[@]}"; do [ "$p" = "$a" ] && ok=1; done
  if [ $ok -eq 0 ]; then echo "NICHT FREIGEGEBEN: $p"; bad=1; fi
done < <("$aapt2" dump permissions "$apk" | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p")
[ $bad -eq 0 ] && echo "Berechtigungen OK" || exit 1
