#!/usr/bin/env bash
# Erzeugt den Google-Play-Upload-Schlüssel und android/key.properties. Passwörter werden abgefragt,
# nie in Dateien des Repositorys (außer der nicht eingecheckten key.properties) geschrieben.
# Die Schlüsseldatei SICHER und mehrfach sichern: Ohne sie sind Updates nur über den Play-Support möglich.
set -euo pipefail
cd "$(dirname "$0")/.."
store="${1:-$HOME/.familynexus/upload-keystore.jks}"
mkdir -p "$(dirname "$store")"
[ -e "$store" ] && { echo "Schlüsseldatei existiert bereits: $store"; exit 1; }
read -r -s -p "Passwort für den Schlüsselspeicher (mind. 12 Zeichen): " pw; echo
read -r -p "Name/Organisation für das Zertifikat (z. B. CN=FamilyNexus, O=Inneso): " dn
keytool -genkeypair -v -keystore "$store" -alias upload -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$pw" -keypass "$pw" -dname "$dn"
umask 077
cat > android/key.properties <<EOP
storeFile=$store
storePassword=$pw
keyAlias=upload
keyPassword=$pw
EOP
echo "Fertig: $store und android/key.properties (nicht einchecken – steht in .gitignore)."
