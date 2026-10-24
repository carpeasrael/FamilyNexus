# FamilyNexus

Family calendar and messenger for Android, iOS, macOS and Linux – **local-first**, end-to-end encrypted via the
[Matrix](https://matrix.org) protocol. Built with Flutter (Android; iOS verified in the simulator since phase 6; the
codebase is platform-neutral, platform code lives in clearly separated adapters under `lib/data/platform/`, `android/`
and `ios/`).

Primary source of requirements: [`Concept.md`](Concept.md). Decisions and their rationale:
[`docs/ENTSCHEIDUNGEN.md`](docs/ENTSCHEIDUNGEN.md).

> Note: `Concept.md`, the app UI texts and the documents under `docs/` are written in German.

## Features (status: phases 1–6 implemented)

- **Setup without technical terms** (E-55–E-57): three entry points – *start a new family*, *I was invited*, *I already
  have an account*. Accounts are created in the app (username suggested from your name, availability checked live; terms,
  email confirmation, invitation codes and captchas are guided) or, on providers with browser sign-in such as matrix.org,
  on the provider's page with an automatic return to the app. The provider is preselected and checked automatically;
  changing it is under *Advanced*. An invitation link takes newcomers straight to *create account* at the inviter's
  provider and then to a join card with names instead of IDs. The mandatory key backup is the **emergency key** (copy with
  auto-clearing clipboard, or save as a printable file).
- **Family chat and direct chats** (encrypted): messages, replies, reactions, attachments (validated, never opened
  automatically), offline queue. Direct chats exist for every pair of joined members ("Send message" in the family view
  or via the conversation bar in the chat); invitations from strangers are ignored.
- **Report and block:** report a message to the operator of your homeserver (reason + optional text; the encrypted content is
  never sent) and block members locally on your device (messages and direct chat are hidden, undo under *Settings → Blocked
  members*).
- **Online status:** Which family members are online is shown in the member list, in the chat and on "Today" (text and
  dot, "last online … ago"). The status is sent end-to-end encrypted to devices of family members only, is never stored
  and can be turned off under *Settings → Privacy → Share online status*.
- **Shopping list:** shared family list (item, quantity, check off, edit, delete, "Remove completed"), transmitted and
  stored encrypted, offline-capable, deterministic merge of concurrent changes.
- **Task lists:** moderators create lists with items and assign them to a family member; they repeat daily, weekly or
  monthly and start over automatically at the period boundary (midnight, Monday, 1st of the month, in the list's time
  zone). Only the assigned person ticks items off (optional comment); date and time are logged in a history that is kept
  across resets. Transmitted and stored encrypted, offline-capable.
- **Calendar** with day/week/month/agenda views, person filter, recurrences (including exceptions, daylight saving
  time), time zones, **private** (own devices only) and **shared** events (encrypted in the family room), accept/decline,
  share events as a card in the chat.
- **Local reminders** without the event name in the notification.
- **Family and roles:** member/moderator; invite via link (share by email, QR code or copy; single-use, time-limited) or
  Matrix ID, confirm join requests (any moderator can check and confirm a link issued by another), promote, remove (key
  rotation). An invited account sees the invitation right after sign-in instead of the create/join question.
- **Security:** encrypted local database (SQLCipher, key in the Android Keystore), app lock via device authentication,
  screen protection, device verification by emoji comparison, identity verification of members.
- German/English, light/dark (glass/neon look based on the AURORA colors) with a **selectable neon accent color**
  (settings in the burger menu at the top right), "Reduce effects" option, WCAG AA contrast.

Not included / known limitations: see [`docs/OFFEN.md`](docs/OFFEN.md).

## Requirements

| Tool | Purpose |
|---|---|
| Flutter 3.47.x (Dart 3.13) | Build and tests |
| JDK 17, Android SDK (platform 35/36, build tools, NDK via Gradle) | Android build |
| Rust (`rustup`, Android targets) | `vodozemac` (cryptography) is built from source during the Android build |
| Linux: clang, CMake, Ninja, GTK 3, libsecret, SQLCipher (`libsqlcipher.so`) | Linux build, and `flutter test` on Linux hosts |
| `flatpak`, `flatpak-builder` (optional) | Linux Flatpak bundle (`tool/build_flatpak.sh`) |
| Windows: Visual Studio (C++ desktop), vcpkg (`sqlcipher:x64-windows`) | Windows build; the release workflow builds it on GitHub (no local script) |
| Web: Rust nightly + `wasm32-unknown-unknown`, `wasm-pack`, `wasm-bindgen-cli` 0.2.100, `flutter_rust_bridge_codegen` 2.13.0, Chrome | Web build (`tool/build_web.sh`, tests `tool/web_selftest.sh`, `tool/web_smoke.py`) |
| Docker (optional) | Local test homeserver for the end-to-end tests |

## Build and run

```sh
flutter pub get
flutter run                      # Debug on device/emulator
flutter build apk --debug        # Debug APK
flutter build macos --debug       # macOS (Apple Silicon), start: open build/macos/Build/Products/Debug/FamilyNexus.app
flutter build ios --simulator --debug   # iOS (simulator); needs Xcode, CocoaPods, Rust targets for iOS (see docs/OFFEN.md)
flutter build linux --debug       # Linux (x86_64), start: build/linux/x64/debug/bundle/familynexus
tool/build_flatpak.sh --install   # Linux release as Flatpak bundle (build/flatpak/), installs it for the current user
tool/build_appimage.sh            # Linux release as AppImage (build/appimage/); best run on Ubuntu 22.04 (glibc baseline)
tool/build_release.sh            # Release with --obfuscate (unsigned without android/key.properties)
```

Release signing: `android/key.properties` (not checked in) with `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. Without this file the release APK intentionally stays unsigned (no fallback to the debug key).
Obfuscation debug symbols are written to `debug-info/` (not checked in) – keep them to read stack traces.

**Signed APK and App Bundle via GitHub Actions:** pushing a version tag (`git tag -a v1.0.2 -m … && git push origin v1.0.2`, tag must
match the `pubspec.yaml` version) runs `.github/workflows/release.yml`. It builds a signed, obfuscated release APK (arm64 + armv7)
and a signed App Bundle (`.aab`, all ABIs, for Google Play), attaches both with SHA-256 files to the GitHub release and keeps the
debug symbols as a private workflow artifact. Running the workflow by hand (*Run workflow*, choose `aab`) rebuilds only the bundle for an
existing tag and leaves the APK asset untouched. Required repository secrets: `ANDROID_KEYSTORE_BASE64` (`base64 -i upload-keystore.jks`),
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Without them the workflow fails early.
The same workflow then builds the Linux Flatpak bundle (`FamilyNexus-v<version>.flatpak`, x86_64, needs no secrets) with
`tool/build_flatpak.sh` and attaches it as well; *Run workflow* with `flatpak` rebuilds only that bundle. Install with
`flatpak install --user FamilyNexus-v<version>.flatpak` (the GNOME runtime comes from Flathub).
An AppImage (`FamilyNexus-v<version>-x86_64.AppImage`, built by `tool/build_appimage.sh` on Ubuntu 22.04) is attached too: `chmod +x` and run it;
it brings SQLCipher and needs GTK 3, libsecret and OpenSSL 3 from the system (E-54). *Run workflow* with `appimage` rebuilds only that file.
A third job builds the Windows zip (`FamilyNexus-v<version>-windows-x64.zip`: unzip and run `familynexus.exe`; unsigned, so SmartScreen
warns on first start); *Run workflow* with `windows` rebuilds only that zip, and the optional `ref` input builds from a branch while attaching
the file to the tag's release.
The web app (`tool/build_web.sh`; zip `FamilyNexus-v<version>-web.zip` for self-hosting at the root of a domain; for another path edit `<base href>` in its `index.html`) is built, tested in headless Chrome and published on
GitHub Pages (`https://carpeasrael.github.io/FamilyNexus/`) by the last two jobs; *Run workflow* with `web` redeploys only the web app.
Your data stays in the browser, encrypted and protected by a password you choose; see `docs/ENTSCHEIDUNGEN.md` (E-53) for the limits.

## Tests

```sh
flutter analyze                  # must pass without findings
flutter test                     # unit, widget, security and architecture tests (Matrix fake)
tool/e2e.sh                      # end-to-end against a local Synapse (Docker, TLS) with the real vodozemac library
tool/device_tests.sh             # integration tests on emulator/device (DB encryption, keystore, migration, reminders)
tool/check_permissions.sh        # checks the merged manifest permissions against the allowlist
```

Manual walkthrough tests with screenshots and delivered reminders: `integration_test/manual/`. Screenshots of every setup
step (rendered on the host with the app's fonts): `tool/onboarding_screens.sh` → `build/onboarding_tour/`. Test plan for
registration, family setup, invitation and joining: `docs/TESTPLAN_ONBOARDING.md`.

Coverage (lines, as of end of phase 5; phase 6 not re-measured): domain 96.6 %, UI (`features`) 86.3 %, design system
98.3 %; `SdkMatrixGateway` is covered 69.9 % by the end-to-end tests against Synapse (skipped in `flutter test`
without `FN_E2E`).

## Release

Preparation for Google Play and the App Store (versions, icons, store texts, privacy, build scripts, checklists):
[`docs/STORE.md`](docs/STORE.md); contents of the listings under `store/`. Release bundles:
`tool/build_release.sh aab`, `tool/build_ios_release.sh`, `tool/build_flatpak.sh` (Linux).

## Own server, privacy

- Run your own homeserver: [`docs/EIGENER_SERVER.md`](docs/EIGENER_SERVER.md).
- Privacy text: in the app under *Settings → Privacy*; "Delete all local data" is also there.
- Dependencies, licenses, SBOM: [`docs/ABHAENGIGKEITEN.md`](docs/ABHAENGIGKEITEN.md) (`python3 tool/sbom.py`).
- Architecture: [`docs/ARCHITEKTUR.md`](docs/ARCHITEKTUR.md); planning and acceptance: [`docs/PLAN.md`](docs/PLAN.md);
  reviews: [`docs/REVIEW.md`](docs/REVIEW.md).

## Security principles (non-negotiable)

No telemetry, no advertising/analytics SDKs; no custom cryptography (Matrix SDK + vodozemac); E2EE cannot be
disabled; no plaintext content in notifications, logs or backups (`allowBackup=false`); TLS only; inputs and imports
are treated as untrusted; dependencies are pinned exactly. Deviations are marked as "Sicherheitsabweichung" (security
deviation) in `docs/ENTSCHEIDUNGEN.md`.

## License

AGPL-3.0-or-later (see [`LICENSE`](LICENSE)); the Matrix SDK and vodozemac dependencies are licensed under AGPL
(decision E-02).
