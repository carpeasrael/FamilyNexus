# Concept Draft: Family Planner with Matrix Messenger

Oct 20, 2026 · @CarpeAsrael

> **Change Oct 21, 2026 (later):** Settings moved to the burger menu at the top right instead of the bottom bar; the neon accent color is freely selectable (E-46).
>
> **Change Oct 21, 2026:** Extended with online status of family members, direct chats between members (previously "optional") and a shared shopping list (previously under "Possible later"). Affected: feature scope, roles, Matrix model, threat model, main screens and privacy; rationale in `docs/ENTSCHEIDUNGEN.md` (E-38 to E-42).

## Vision & Goals

The app (working title "FamilyNexus") combines a family calendar, a messenger and a shared shopping list in one application whose data lives exclusively on the family's devices and travels only end-to-end encrypted via the Matrix protocol.

**Target audience:** Families and households who want to coordinate appointments without entrusting their data to a central provider.

**Guiding principles**

- **Local-first:** All data is stored encrypted on the device; the app also works offline.
- **E2EE by default:** No plaintext leaves the device, neither chat nor appointments.
- **Replaceable server:** A public Matrix server by default, optionally your own homeserver.
- **Data minimization:** No telemetry, no advertising, no analytics SDKs.
- **One codebase:** Android, Windows, Linux, macOS, iOS and iPadOS.
- **Bilingual:** German and English from the start.

## Feature Scope

Two roles govern the family: members use calendar and chat, moderators additionally manage the group.

### Roles and Permissions

| Function | Member | Moderator |
| --- | --- | --- |
| Create, edit, delete own appointments | Yes | Yes |
| Private appointments (visible only to oneself) | Yes | Yes |
| Shared appointments (visible to the family) | Yes | Yes |
| Read and write chat (family chat and direct chats) | Yes | Yes |
| View and edit the shopping list | Yes | Yes |
| See others' online status, share or hide own status | Yes | Yes |
| Invite new members | No | Yes |
| Promote a member to moderator | No | Yes |
| Remove a member | No | Yes |
| Configure server and family name | No | Yes |

### Appointments

- **Fields:** title, start and end, all-day, location, note, recurrence, participants, color, visibility.
- **Private:** The appointment stays on the user's own devices only, is never sent to Matrix and is not visible to others.
- **Shared:** The appointment is sent encrypted to the family room; members see it and can respond (accept, decline, maybe).
- **Recurrences:** daily, weekly, monthly, yearly, each with exceptions.
- **Views:** day, week, month, agenda; filter by person.

### Reminders

- One or more reminders per appointment (e.g. 10 minutes, 1 hour, 1 day before).
- Reminders are **local notifications** on the respective device. This way no push message reveals appointment contents to third parties.
- Default reminder configurable per person; shared appointments allow personal reminders per member.

### Messenger

- Family group chat and **direct chats** between joined members (one encrypted room per pair; the conversation ceases when a member is removed).
- Messages, images, files, replies, reactions.
- Appointments can be shared in the chat and accepted or declined directly.
- **Report and block:** Users can report a message to the operator of their homeserver (reason and optional text; the encrypted content is not sent) and block members locally, which hides their messages and direct chat on that device.

### Online Status

- The family sees who is online right now: **Online** (app in the foreground, heartbeat every 2 minutes), **Offline** (with "last online … ago") or **Status unknown**. Shown in the member list, in the chat (conversation bar, direct chat) and on "Today"; always as text and shape, never by color alone.
- The status is sent only as an end-to-end encrypted device message to devices of joined family members and is never stored. It can be turned off in the settings ("Share online status"); others then see you as offline.

### Shopping List

- One shared list per family: item (text, quantity), check off, edit, delete, "Remove completed". Every member may change every item; concurrent changes are merged deterministically (higher version, then later time, then sender ID).
- The list is transmitted encrypted in the family room like shared appointments, is stored encrypted on the device and works offline (queue). Limits: 300 active items, 1000 records.

### Invitations

- A moderator creates a time-limited invitation link or QR code and can share it by email, QR code or copy. Only moderators create links.
- Joining only after confirmation by any moderator (a link issued by one moderator can be checked by the others); additionally device verification by emoji comparison or QR scan.
- A moderator can also invite an existing Matrix account by ID. When that account signs in without a family, the app shows the invitation directly ("You have been invited – join <family>") instead of asking whether to create or join; one tap confirms.

## Architecture

Each family is an encrypted Matrix room: the devices hold the data, the server only relays.

&#91;embedded content: Architecture · two devices and one homeserver\]

Local database and Matrix layer live on each device; the homeserver forwards encrypted events and cannot read them.

### Matrix Model

| Element | Implementation |
| --- | --- |
| Family | One private, encrypted Matrix room; joining by invitation only |
| Chat | Regular Matrix messages in the family room; direct chats as separate encrypted rooms per member pair (`is_direct`, only with current members; invitations from strangers are ignored) |
| Online status | Encrypted device message (Olm) `de.inneso.familynexus.presence` to the devices of joined members; in memory only, valid for 5 minutes, can be turned off |
| Shopping list | Dedicated encrypted event type `de.inneso.familynexus.shopping` in the family room with item ID, version, timestamp and deletion marker; stored encrypted locally |
| Shared appointment | Dedicated encrypted event type in the room with appointment ID, version and response status |
| Private appointment | Stored locally only; synchronized between own devices via a private room known only to the own account |
| Roles | Matrix power levels: member 0, moderator 50; the right to change roles is also at 50 |
| Invitations | Matrix invitation, additionally link or QR code with expiry time |
| Conflicts | Version counter per appointment; on concurrent changes the newer version wins, the older one stays in the history |
| Offline | Local queue, sent as soon as a connection exists |

### Server Choice

- During initial setup a public Matrix server is preselected; the URL can be replaced by your own homeserver.
- The app checks the server's reachability and protocol version and shows its operator.
- A later server change requires a migration of the family (new room, new invitations); this flow needs to be planned.

## Security & Privacy

Security takes precedence over convenience: encryption cannot be turned off, and plaintext exists only in the memory of the running app.

### Storage on the Device

- Local database (SQLite) with full encryption, e.g. SQLCipher with AES-256.
- The database key is stored in the operating system's key store: Keychain (macOS, iOS, iPadOS), Keystore (Android), Credential Manager or DPAPI (Windows), Secret Service (Linux).
- Optional app lock via PIN, password or biometrics; automatic lock after inactivity.
- Attachments and media are stored separately encrypted in the file system.
- No plaintext previews in notifications, task switcher or backups (screenshot protection on request).

### End-to-End Encryption

- Matrix E2EE with Olm (1:1) and Megolm (rooms) for chat **and** appointments; the server cannot read the content of events, but it sees metadata (including room and profile names).
- Appointments are transmitted as encrypted room events in the family room.
- Device verification via cross-signing; unverified devices receive no keys.
- When a member is removed, the room keys are rotated so that departed persons cannot read new content.
- Key backup only with a personal recovery phrase; the server stores only encrypted backups.

### Threat Model and Limits

| Risk | Countermeasure | Residual risk |
| --- | --- | --- |
| Eavesdropping on the server | E2EE, server sees only ciphertext | Metadata (who, when, room size, room and profile names, rhythm of status messages) remains visible |
| Forged online status | Only encrypted messages received from current family members count; format strictly validated | A member can only misreport their own status |
| Loss or theft of the device | Database encryption, app lock, remote sign-out of the session | A weak PIN weakens the protection |
| Foreign device in the family | Verification, moderator can block devices | Users skip verification |
| Compromised public server | Own homeserver possible; E2EE protects contents | Server can deny service |
| Malicious code via attachments | No automatic execution, type check, size limit | Zero-day in the operating system |
| Supply chain (dependencies) | Pinned versions, SBOM, regular audits | New vulnerabilities in libraries |

### Privacy (GDPR)

- Data minimization: only what the function needs is stored and transmitted. The online status leaves the device only encrypted, is never stored and can be turned off.
- Deletion: a member can completely delete their account, appointments and local data; deletion of messages on other devices cannot be technically enforced and is declared accordingly.
- Children: accounts of minors go through invitation and approval by a moderator; a notice on the consent of legal guardians needs to be planned.
- Transparency: privacy policy in both languages, notice on the chosen server and its operator during setup.
- Before release: independent security review and penetration test.

## Technology Stack & Platforms

Recommendation: Flutter with the Matrix library of the Matrix Dart SDK, because one codebase covers all six target platforms and the glass/neon look can be implemented pixel-perfectly with its own rendering engine. The assessment of the maturity and feature scope of the libraries is to be verified before project start.

### Framework Options

| Option | Platforms | Strengths | Weaknesses |
| --- | --- | --- | --- |
| Flutter (Dart) + Matrix Dart SDK | Android, iOS, iPadOS, Windows, Linux, macOS | One codebase, own rendering engine for glass/neon effects, existing Matrix SDK with E2EE | Native specifics (notifications, background operation) need plugins |
| Kotlin Multiplatform + Compose | Android, iOS, desktop | Native integration, Matrix Rust SDK usable | Lower desktop maturity and Linux support, glass effects more costly |
| Tauri + web UI + Matrix Rust SDK | Desktop good, mobile newer | Rust core with proven E2EE, lightweight | Mobile support less mature |
| Native per platform | all | Best system integration | Six codebases, high maintenance effort |

### Architecture Building Blocks

- **Presentation:** Flutter UI with a central design system (colors, glass, neon as tokens).
- **Domain:** Calendar logic (recurrences, time zones, reminders), testable independently of the UI.
- **Data:** Encrypted local database as the single source of truth; synchronization via Matrix.
- **Matrix layer:** Sign-in, rooms, E2EE, events; server URL configurable.
- **Localization:** ARB files for German and English, date and time formats according to the device language.
- **Notifications:** Locally scheduled reminders; push for new chat messages via UnifiedPush or APNs with an empty payload.

### Platform Notes

- **iOS/iPadOS/macOS:** Distribution via the App Store; observe background limits.
- **Android:** Reliable reminders via exact alarms; consider manufacturers' battery optimization.
- **Windows/Linux:** Packaging as MSIX or Flatpak/AppImage; tray icon for reminders.
- **iPad and large displays:** Adaptive two-column view (calendar plus chat).

## UX & Design

The interface combines glass (glassmorphism) with neon accents on a dark background; the AURORA palette (teal #0f766e and #2dd4bf) serves as the color base, complemented by neon signal colors.

### Design Language

- **Glass:** Semi-transparent surfaces with background blur, fine light edges, soft shadows.
- **Neon:** Glowing accents for selection, focus, current time and reminders; teal as primary color, magenta and violet as secondary accents.
- **Typography:** Space Grotesk for headings, IBM Plex Sans for text, IBM Plex Mono for times and codes.
- **Selectable accent color:** In the settings each user chooses their neon contrast color (turquoise as default, also magenta, violet, sky blue, lime, orange, rosé, green); it colors buttons, selection and highlights in the light and dark theme and meets WCAG AA everywhere (one glowing and one darkened variant per color).
- **Color per person:** Each family member gets a neon color for their appointments.
- **Modes:** Dark as default, light variant with muted glass surfaces.

### Main Screens

| Screen | Content |
| --- | --- |
| Today | Next appointments, upcoming reminders, who is online, open shopping items, unread messages |
| Calendar | Day, week, month and agenda view, filter by person |
| Appointment | Create and edit, Private/Shared switch, reminders, participants |
| Chat | Family room and direct chats (conversation bar with online status and unread), appointments as cards in the history |
| Shopping | Shared shopping list: open and completed items, quantity, edit, "Remove completed" |
| Family | Member list with online status and "Send message", roles, invitations, device verification (moderator) |
| Settings | Language, server, lock, share online status, notifications, backup, design incl. accent color; reachable via the burger menu at the top right (not in the bottom navigation bar) |

### Accessibility and Language

- Contrast per WCAG 2.2 AA: glass surfaces get a minimum contrast to the text, neon is never the sole carrier of information.
- "Reduce effects" option (less blur and glow), support for screen readers and dynamic font sizes.
- German and English switchable; default follows the device language, texts are fully in translation files.
- Initial setup in four steps: language, server (default or own), account, create or join a family.

## Roadmap, Risks and Open Questions

Implementation proceeds in four phases; each ends at a release criterion that puts security before feature scope.

&#91;embedded content: Roadmap · 4 phases, 4 release criteria\]

The schedule depends on team size and framework decision and will be added after alignment.

### Improvement Suggestions

- **Third visibility level "Busy":** Private appointments can appear as busy time without title and details, so that appointments can be coordinated better.
- **At least two moderators:** During setup the app recommends a second moderator so that the family stays able to act if a device is lost.
- **Encrypted backup and export:** Export of appointments as an ICS file and of a complete backup archive, protected with a separate password. ICS imports are treated as untrusted and validated.
- **Template for your own server:** A short guide including a configuration template for your own Matrix homeserver, so that the option is actually usable.
- **Make security status visible:** A display in the settings shows which devices are verified and whether the key backup is set up.
- **Possible later:** Further shared lists (tasks) and a restricted mode for children. The shopping list is implemented (Oct 21, 2026).

### Risks

| Risk | Impact | Countermeasure |
| --- | --- | --- |
| Maturity of the Matrix library per platform | E2EE features are missing or behave differently | Early prototype in phase 1, keep the Rust SDK alternative open |
| Reliability of local reminders | Appointments are missed without warning, especially on Android and iOS | System-specific tests, rescheduling after restart, notice on missing permission |
| Public default server | Outage, registration rules or rate limiting | Notice during setup, easy switch to your own server |
| Loss of all devices of a member | Keys and private appointments gone | Key backup with recovery phrase, encrypted export archive |
| Metadata on the server | Inferences about family structure and activity | Transparency in the privacy policy, own server as an option |
| Effort for six platforms | Delays, inconsistent quality | One codebase, shared tests, release platforms one after another |

### Open Questions

- [ ] **Design:** I combined the AURORA color world with glass and neon. Should the app carry the inneso branding (name, logo) or stay neutral?
- [ ] **Private appointments:** Should they be synchronized between a member's own devices (assumption: yes, via a private room)?
- [ ] **Moderator rights:** May moderators change or delete other people's shared appointments, or only remove members?
- [ ] **Accounts:** Does the app create new Matrix accounts, or do users sign in with existing accounts?
- [ ] **Minors:** Should children be able to be members, and does that require a separate restriction?
- [ ] **Distribution:** Open source or closed, release via the app stores or also direct download?
- [ ] **Matrix default server:** Which public server should be preselected?
