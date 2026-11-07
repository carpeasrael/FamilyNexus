#!/usr/bin/env bash
# Sandbox für TP-FN-DEF-G1G2: zwei eigene Android-Emulatoren (FN_E2E_G1, FN_E2E_G2), bei jedem Start mit
# gelöschten Daten, Chrome per DevTools-Protokoll erreichbar. Berührt weder das AVD des Nutzers
# (Pixel_8_API_36) noch seine Flatpak-Sitzung, seinen Desktop-Browser oder andere Emulatoren.
#
#   sandbox.sh apk                       Release-APK des aktuellen Stands bauen, mit Debug-Schlüssel signieren
#   sandbox.sh up [--no-window]          beide AVDs anlegen (falls nötig), kalt starten, Chrome vorbereiten,
#                                        APK installieren, DevTools auf 127.0.0.1:9333 (G1) / 9334 (G2)
#   sandbox.sh shot <G1|G2> <out.png>    Bildschirmfoto (Rückfall bei FLAG_SECURE: Emulator-Konsole)
#   sandbox.sh status
#   sandbox.sh down                      Emulatoren beenden, Umleitungen entfernen, Nutzerdaten der AVDs löschen
#
# Umgebung: FN_SANDBOX_DIR (Arbeitsordner, Vorgabe: $TMPDIR/fn-e2e-sandbox), FN_APK (APK-Pfad),
#           FN_DEVICE_G1 / FN_DEVICE_G2 (Geräteprofil: pixel_8 = Telefon, pixel_tablet = Tablet; Vorgabe pixel_8),
#           FN_EMU_RAM (Arbeitsspeicher je Emulator in MB, Vorgabe 4096; mit 2,5 GB beendete Android Chrome, Lauf 23).
set -euo pipefail

SDK="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
ADB="$SDK/platform-tools/adb"
EMU="$SDK/emulator/emulator"
AVDM="$SDK/cmdline-tools/latest/bin/avdmanager"
IMG="system-images;android-36;google_apis_playstore;x86_64"
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SBX="${FN_SANDBOX_DIR:-${TMPDIR:-/tmp}/fn-e2e-sandbox}"
APK="${FN_APK:-$SBX/FamilyNexus-e2e.apk}"
FLUTTER="${FLUTTER:-/home/carpeasrael/tools/flutter/bin/flutter}"
declare -A PORT=([G1]=5560 [G2]=5562) CDP=([G1]=9333 [G2]=9334)
PKG=de.inneso.familynexus

serial() { echo "emulator-${PORT[$1]}"; }
mkdir -p "$SBX"

case "${1:-}" in
apk)
  BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"
  (cd "$REPO" && "$FLUTTER" build apk --release --target-platform android-x64)
  "$BT/zipalign" -f -p 4 "$REPO/build/app/outputs/flutter-apk/app-release.apk" "$SBX/aligned.apk"
  "$BT/apksigner" sign --ks "$HOME/.android/debug.keystore" --ks-pass pass:android --key-pass pass:android \
    --ks-key-alias androiddebugkey --out "$APK" "$SBX/aligned.apk"
  rm -f "$SBX/aligned.apk"
  "$BT/aapt2" dump badging "$APK" | head -1
  echo "APK: $APK (Debug-Signatur, nur für die Sandbox)"
  ;;
up)
  WIN=(); [ "${2:-}" = "--no-window" ] && WIN=(-no-window)
  [ -f "$APK" ] || { echo "APK fehlt: $APK (zuerst: sandbox.sh apk)"; exit 1; }
  for g in G1 G2; do
    dev_var="FN_DEVICE_$g"; want="${!dev_var:-pixel_8}"
    cfg="$HOME/.android/avd/FN_E2E_$g.avd/config.ini"
    if ! "$EMU" -list-avds | grep -qx "FN_E2E_$g" || ! grep -q "^hw.device.name *= *$want\$" "$cfg" 2>/dev/null; then
      echo no | "$AVDM" create avd -n "FN_E2E_$g" -k "$IMG" -d "$want" --force >/dev/null
    fi
    if "$ADB" devices | grep -q "^$(serial $g)"; then echo "$g läuft bereits ($(serial $g))"; exit 1; fi
    nohup "$EMU" -avd "FN_E2E_$g" -port "${PORT[$g]}" -memory "${FN_EMU_RAM:-4096}" -wipe-data -no-snapshot -no-audio -no-boot-anim "${WIN[@]}" \
      >"$SBX/emulator-$g.log" 2>&1 &
  done
  for g in G1 G2; do
    s=$(serial $g)
    "$ADB" -s "$s" wait-for-device
    for _ in $(seq 1 100); do
      [ "$("$ADB" -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break; sleep 3
    done
    echo "$g: RAM $("$ADB" -s "$s" shell grep MemTotal /proc/meminfo | awk '{printf "%.1f GB", $2/1048576}')"
    "$ADB" -s "$s" shell settings put global window_animation_scale 0
    "$ADB" -s "$s" shell settings put global transition_animation_scale 0
    "$ADB" -s "$s" shell settings put global animator_duration_scale 0
    "$ADB" -s "$s" shell 'echo "_ --disable-fre --no-default-browser-check --no-first-run" > /data/local/tmp/chrome-command-line'
    "$ADB" -s "$s" shell am set-debug-app --persistent com.android.chrome
    "$ADB" -s "$s" install -r "$APK" >/dev/null
    "$ADB" -s "$s" shell am start -a android.intent.action.VIEW -d about:blank com.android.chrome >/dev/null
    sleep 4
    "$ADB" -s "$s" forward "tcp:${CDP[$g]}" localabstract:chrome_devtools_remote >/dev/null
    v=$("$ADB" -s "$s" shell dumpsys package $PKG | grep -m1 versionName | tr -d ' \r')
    echo "$g: $s ($(grep '^hw.device.name' "$HOME/.android/avd/FN_E2E_$g.avd/config.ini" | cut -d= -f2 | tr -d ' ')), Android $("$ADB" -s "$s" shell getprop ro.build.version.release | tr -d '\r'), $v, DevTools 127.0.0.1:${CDP[$g]}"
  done
  ;;
shot)
  g="$2"; out="$3"; s=$(serial "$g")
  "$ADB" -s "$s" exec-out screencap -p >"$out"
  if python3 -I - "$out" <<'EOF'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('L')
w, h = im.size
# Inhaltsbereich ohne Status- und Navigationsleiste: bei FLAG_SECURE ganz schwarz
sys.exit(0 if im.crop((0, int(h * 0.08), w, int(h * 0.92))).getextrema()[1] < 8 else 1)
EOF
  then
    # FLAG_SECURE: Bild schwarz -> Emulator-Konsole (umgeht FLAG_SECURE; selten Absturz, dann neu starten)
    # Die Konsole verträgt keine Leerzeichen im Pfad: über eine Zwischendatei im Arbeitsordner.
    tmp="$SBX/shot-$g-$$.png"; rm -f "$tmp"
    "$ADB" -s "$s" emu screenrecord screenshot "$tmp" >/dev/null
    for _ in $(seq 1 20); do [ -s "$tmp" ] && break; sleep 0.25; done
    [ -s "$tmp" ] || { echo "FEHLER: kein Bild über die Emulator-Konsole ($g)"; exit 1; }
    mv -f "$tmp" "$out"
    echo "shot $out (Emulator-Konsole, FLAG_SECURE)"
  else
    echo "shot $out"
  fi
  ;;
status)
  "$ADB" devices
  "$ADB" forward --list
  ;;
down)
  for g in G1 G2; do
    s=$(serial $g)
    "$ADB" -s "$s" forward --remove "tcp:${CDP[$g]}" 2>/dev/null || true
    "$ADB" -s "$s" emu kill 2>/dev/null || true
  done
  # Warten, bis die Emulatoren weg sind; sonst gezielt den qemu-Prozess des Sandbox-AVDs beenden (Lauf 23:
  # "emu kill" ohne Wirkung). Nur Prozesse mit "-avd FN_E2E_G1/G2", nie andere Emulatoren.
  for g in G1 G2; do
    pat="^[^ ]*qemu-system-x86_64 .*-avd FN_E2E_$g( |$)"   # am Programmnamen verankert: trifft keine Shell
    for _ in $(seq 1 20); do pgrep -f "$pat" >/dev/null || break; sleep 1; done
    if pgrep -f "$pat" >/dev/null; then
      pkill -TERM -f "$pat" || true; sleep 5
      pgrep -f "$pat" >/dev/null && { pkill -KILL -f "$pat" || true; sleep 2; }
      echo "$g: Emulator hart beendet"
    fi
    pgrep -f "$pat" >/dev/null && { echo "FEHLER: FN_E2E_$g läuft noch"; exit 1; }
  done
  for g in G1 G2; do
    d="$HOME/.android/avd/FN_E2E_$g.avd"
    [ -d "$d" ] && rm -f "$d"/userdata-qemu.img* "$d"/cache.img* "$d"/encryptionkey.img* "$d"/multiinstance.lock
  done
  for _ in $(seq 1 10); do "$ADB" devices | grep -qE "^emulator-(5560|5562)" || break; sleep 1; done
  if "$ADB" devices | grep -qE "^emulator-(5560|5562)"; then echo "FEHLER: Sandbox-Emulator noch in adb sichtbar"; exit 1; fi
  echo "Sandbox beendet, Nutzerdaten der AVDs FN_E2E_G1/G2 gelöscht."
  ;;
*)
  sed -n '2,15p' "$0"; exit 2 ;;
esac
