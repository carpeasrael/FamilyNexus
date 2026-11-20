# Hilfsfunktionen Lauf 36
export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
R="/Users/carpeasrael/NextCloud_int/mac_project_2/FamilyNexus/User E2E Test Report/2026-11-18_36_macOS-Android_Build31"
SP=/private/tmp/claude-501/-Users-carpeasrael-NextCloud-int-mac-project-2-FamilyNexus/597a9302-f278-415f-853b-8e7356bc67c1/scratchpad
WX=445; WY=33
front1(){ osascript -e 'tell application "System Events"' -e 'tell (first process whose bundle identifier is "de.inneso.familynexus.e2e")' -e 'set frontmost to true' -e "set position of window 1 to {$WX,$WY}" -e 'set size of window 1 to {800,800}' -e 'end tell' -e 'end tell'; }
s1(){ screencapture -x -R$WX,$WY,800,800 "$R/screenshots/$1-G1.png"; sips -Z 900 "$R/screenshots/$1-G1.png" --out $SP/v1.png >/dev/null; }
c1(){ cliclick c:$((WX+$1)),$((WY+$2)); }   # Koordinaten relativ zum Fenster (inkl. Titelleiste)
t1(){ cliclick w:100 t:"$1"; }
s2(){ adb -s emulator-5570 emu screenrecord screenshot $SP/_s2.png >/dev/null; sleep 0.8; cp $SP/_s2.png "$R/screenshots/$1-G2.png"; sips -Z 900 $SP/_s2.png --out $SP/v2.png >/dev/null; }
u2(){ python3 $SP/ui.py G2 "$@"; }
row(){ python3 $SP/row.py "$@"; }
p1(){ cliclick c:$((WX+$1*8/9)),$((WY+$2*8/9)); }   # Pixelkoord. aus v1.png (900px)
sc1(){ cliclick m:$((WX+400)),$((WY+500)); osascript -l JavaScript $SP/scroll.js ${1:--20}; sleep 0.8; }   # negativ = nach unten
clr1(){ cliclick kd:cmd t:a ku:cmd w:100 kp:delete; }
SEC=/Users/carpeasrael/NextCloud_int/mac_project_2/FamilyNexus/secure/Lauf_1118_G1.txt
sval(){ grep "^$1=" $SEC | head -1 | cut -d= -f2-; }
pw1(){ sval "$1" | tr -d '\n' | pbcopy; cliclick kd:cmd t:v ku:cmd; sleep 0.3; printf '' | pbcopy; }   # Wert aus Geheimnisdatei per Zwischenablage einfuegen
pwp(){ sval "$1" | tr -d "
" | cut -c1-$2 | pbcopy; cliclick kd:cmd t:v ku:cmd; sleep 0.3; printf "" | pbcopy; }
ent1(){ osascript -e "tell application \"System Events\" to key code 36"; }
rd(){ python3 $SP/redact.py "$@"; }
esc1(){ osascript -e "tell application \"System Events\" to key code 53"; }
bs1(){ for i in $(seq 1 ${1:-1}); do osascript -e "tell application \"System Events\" to key code 51"; done; }
cb(){ printf "%s" "$1" | pbcopy; cliclick kd:cmd t:v ku:cmd; sleep 0.5; printf "" | pbcopy; }
