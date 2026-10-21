# FamilyNexus

Family calendar and messenger for Android, iOS and macOS – **local-first**, end-to-end encrypted via the
[Matrix](https://matrix.org) protocol. Built with Flutter (Android; iOS verified in the simulator since phase 6; the
codebase is platform-neutral, platform code lives in clearly separated adapters under `lib/data/platform/`, `android/`
and `ios/`).

Primary source of requirements: [`Concept.md`](Concept.md). Decisions and their rationale:
[`docs/ENTSCHEIDUNGEN.md`](docs/ENTSCHEIDUNGEN.md).

> Note: `Concept.md`, the app UI texts and the documents under `docs/` are written in German.

## Features (status: phases 1–6 implemented)

- **Setup** in four steps: language → server (public default preselected, custom server possible) → sign-in with an
  existing account + mandatory key backup → create or join a family.
- **Family chat and direct chats** (encrypted): messages, replies, reactions, attachments (validated, never opened
  automatically), offline queue. Direct chats exist for every pair of joined members ("Send message" in the family view
  or via the conversation bar in the chat); invitations from strangers are ignored.
- **Online status:** Which family members are online is shown in the member list, in the chat and on "Today" (text and
  dot, "last online … ago"). The status is sent end-to-end encrypted to devices of family members only, is never stored
  and can be turned off under *Settings → Privacy → Share online status*.
- **Shopping list:** shared family list (item, quantity, check off, edit, delete, "Remove completed"), transmitted and
  stored encrypted, offline-capable, deterministic merge of concurrent changes.
- **Calendar** with day/week/month/agenda views, person filter, recurrences (including exceptions, daylight saving
  time), time zones, **private** (own devices only) and **shared** events (encrypted in the family room), accept/decline,
  share events as a card in the chat.
- **Local reminders** without the event name in the notification.
- **Family and roles:** member/moderator; invite via link/QR (single-use, time-limited) or Matrix ID, confirm join
  requests, promote, remove (key rotation).
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
| Docker (optional) | Local test homeserver for the end-to-end tests |

## Build and run

```sh
flutter pub get
flutter run                      # Debug on device/emulator
flutter build apk --debug        # Debug APK
flutter build macos --debug       # macOS (Apple Silicon), start: open build/macos/Build/Products/Debug/FamilyNexus.app
flutter build ios --simulator --debug   # iOS (simulator); needs Xcode, CocoaPods, Rust targets for iOS (see docs/OFFEN.md)
tool/build_release.sh            # Release with --obfuscate (unsigned without android/key.properties)
```

Release signing: `android/key.properties` (not checked in) with `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. Without this file the release APK intentionally stays unsigned (no fallback to the debug key).
Obfuscation debug symbols are written to `debug-info/` (not checked in) – keep them to read stack traces.

**Signed APK via GitHub Actions:** pushing a version tag (`git tag -a v1.0.2 -m … && git push origin v1.0.2`, tag must
match the `pubspec.yaml` version) runs `.github/workflows/release.yml`. It builds a signed, obfuscated release APK
(arm64 + armv7), attaches it with a SHA-256 file to the GitHub release and keeps the debug symbols as a private workflow
artifact. Required repository secrets: `ANDROID_KEYSTORE_BASE64` (`base64 -i upload-keystore.jks`),
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Without them the workflow fails early.

## Tests

```sh
flutter analyze                  # must pass without findings
flutter test                     # unit, widget, security and architecture tests (Matrix fake)
tool/e2e.sh                      # end-to-end against a local Synapse (Docker, TLS) with the real vodozemac library
tool/device_tests.sh             # integration tests on emulator/device (DB encryption, keystore, migration, reminders)
tool/check_permissions.sh        # checks the merged manifest permissions against the allowlist
```

Manual walkthrough tests with screenshots and delivered reminders: `integration_test/manual/`.

Coverage (lines, as of end of phase 5; phase 6 not re-measured): domain 96.6 %, UI (`features`) 86.3 %, design system
98.3 %; `SdkMatrixGateway` is covered 69.9 % by the end-to-end tests against Synapse (skipped in `flutter test`
without `FN_E2E`).

## Release

Preparation for Google Play and the App Store (versions, icons, store texts, privacy, build scripts, checklists):
[`docs/STORE.md`](docs/STORE.md); contents of the listings under `store/`. Release bundles:
`tool/build_release.sh aab`, `tool/build_ios_release.sh`.

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
