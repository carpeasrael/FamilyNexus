#!/usr/bin/env bash
# Baut das Linux-AppImage (x86_64) nach build/appimage/FamilyNexus-v<Version>-x86_64.AppImage (+ .sha256).
# Gedacht für Ubuntu 22.04 (glibc 2.35 als Untergrenze, CI-Job „appimage“). Braucht Flutter, Rust (vodozemac),
# clang, cmake, ninja, pkg-config, libgtk-3-dev, libsecret-1-dev und libssl-dev sowie Netzzugriff.
#
# Mitgeliefert wird nur SQLCipher (aus dem Quellcode, wie im Flatpak); GTK 3, libsecret und OpenSSL 3 kommen vom
# System. Der Ordner mit libsqlcipher.so enthält nur diese eine Datei, damit LD_LIBRARY_PATH aus AppRun an
# gestartete Programme (Browser über url_launcher) keine fremden Bibliotheken weiterreicht.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$PATH"

version=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' pubspec.yaml)
[ -n "$version" ] || { echo "Version in pubspec.yaml nicht gefunden" >&2; exit 1; }
out="build/appimage"
appdir="$out/AppDir"
image="$out/FamilyNexus-v$version-x86_64.AppImage"
mkdir -p "$out/tools"

# Lädt eine Datei einmal herunter und prüft die Prüfsumme.
fetch() { # <url> <ziel> <sha256>
  if [ ! -f "$2" ] || ! echo "$3  $2" | sha256sum -c --status; then
    curl -fsSL -o "$2" "$1"
  fi
  echo "$3  $2" | sha256sum -c --quiet
}

# SQLCipher wie in flatpak/de.inneso.familynexus.yml (Version, Flags, -Bsymbolic gegen das System-libsqlite3 von GTK).
fetch https://github.com/sqlcipher/sqlcipher/archive/refs/tags/v4.19.0.tar.gz "$out/tools/sqlcipher.tar.gz" \
  7075f96cbabe45b4ecfc2e6b1745a625f856f695b0827a5506ce9ed85b906aa0
rm -rf "$out/sqlcipher" && mkdir -p "$out/sqlcipher"
tar -xzf "$out/tools/sqlcipher.tar.gz" -C "$out/sqlcipher" --strip-components=1
(
  cd "$out/sqlcipher"
  ./configure --with-tempstore=yes --disable-readline --dll-basename=libsqlcipher \
    CFLAGS="-O2 -DSQLITE_HAS_CODEC -DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown" \
    LDFLAGS="-lcrypto -Wl,-Bsymbolic"
  make -j"$(nproc)" libsqlcipher.so
  readelf -d libsqlcipher.so | grep -q 'libcrypto'
)

fetch https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage \
  "$out/tools/appimagetool" ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
# Statische Laufzeit (type2-runtime): braucht kein libfuse2 auf dem Zielsystem.
fetch https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64 \
  "$out/tools/runtime-x86_64" 2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d
chmod +x "$out/tools/appimagetool"

flutter pub get
mkdir -p debug-info
flutter build linux --release --obfuscate --split-debug-info=debug-info

rm -rf "$appdir"
mkdir -p "$appdir/sqlcipher"
cp -a build/linux/x64/release/bundle "$appdir/familynexus"
install -m755 "$out/sqlcipher/libsqlcipher.so" "$appdir/sqlcipher/libsqlcipher.so"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
here="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$here/sqlcipher${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$here/familynexus/familynexus" "$@"
EOF
chmod +x "$appdir/AppRun"
install -m644 flatpak/de.inneso.familynexus.desktop "$appdir/de.inneso.familynexus.desktop"
install -m644 flatpak/icons/256x256/de.inneso.familynexus.png "$appdir/de.inneso.familynexus.png"
ln -s de.inneso.familynexus.png "$appdir/.DirIcon"
for n in 128 256 512; do
  install -Dm644 "flatpak/icons/${n}x${n}/de.inneso.familynexus.png" \
    "$appdir/usr/share/icons/hicolor/${n}x${n}/apps/de.inneso.familynexus.png"
done

rm -f "$image"
# Ohne FUSE (Container, CI): appimagetool entpackt sich selbst statt sich einzuhängen.
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 VERSION="$version" \
  "$out/tools/appimagetool" --runtime-file "$out/tools/runtime-x86_64" --no-appstream "$appdir" "$image"
(cd "$out" && sha256sum "$(basename "$image")" > "$(basename "$image").sha256")
echo "Fertig: $image"
