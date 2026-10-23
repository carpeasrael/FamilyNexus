#!/usr/bin/env bash
# Web-Version (E-53): Das Matrix-SDK speichert im Browser standardmäßig im unverschlüsselten IndexedDB
# (`indexeddb_box.dart`); dort lägen Zugangstoken und Schlüsselsicherungen im Klartext. Dieses Skript legt eine
# Kopie des SDKs an, in der auch der Browser den SQL-Speicher (`sqflite_box.dart`) nutzt – und damit unsere
# verschlüsselte Datenbank (SQLite3MultipleCiphers). Es ändert genau eine Importzeile und trägt die Kopie über
# `pubspec_overrides.yaml` ein; Android, iOS, macOS, Linux und Windows sind nicht betroffen.
#   tool/web_matrix_patch.sh          Kopie anlegen und eintragen
#   tool/web_matrix_patch.sh --undo   Eintrag und Kopie entfernen (pubspec.lock wird neu aufgelöst)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" = "--undo" ]; then
  rm -rf build/web_patched pubspec_overrides.yaml
  flutter pub get >/dev/null
  exit 0
fi

version=$(sed -n '/^  matrix:/,/^  [a-z_0-9]*:$/p' pubspec.lock | sed -n 's/^    version: "\(.*\)"/\1/p' | head -1)
[ "$version" = "14.2.0" ] || { echo "Das Skript ist auf matrix 14.2.0 geprüft, gefunden: $version" >&2; exit 1; }
src=$(flutter pub cache list 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['packages']['matrix']['$version']['location'])" 2>/dev/null || true)
[ -d "$src" ] || src="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/matrix-$version"
[ -d "$src" ] || { echo "matrix-$version nicht im Pub-Cache (erst flutter pub get)" >&2; exit 1; }

rm -rf build/web_patched && mkdir -p build/web_patched
cp -R "$src" build/web_patched/matrix
file=build/web_patched/matrix/lib/src/database/matrix_sdk_database.dart
old="import 'sqflite_box.dart' if (dart.library.js_interop) 'indexeddb_box.dart';"
grep -qF "$old" "$file" || { echo "Importzeile in $file nicht gefunden" >&2; exit 1; }
python3 - "$file" "$old" <<'PY'
import sys
p, old = sys.argv[1], sys.argv[2]
s = open(p).read()
s = s.replace(old, "// FamilyNexus (E-53): auch im Browser der SQL-Speicher statt unverschlüsseltem IndexedDB.\nimport 'sqflite_box.dart';", 1)
open(p, 'w').write(s)
PY
cat > pubspec_overrides.yaml <<YAML
dependency_overrides:
  matrix:
    path: build/web_patched/matrix
YAML
flutter pub get >/dev/null
echo "matrix $version gepatcht (build/web_patched/matrix)"
