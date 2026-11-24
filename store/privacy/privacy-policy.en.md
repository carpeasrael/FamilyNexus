# Privacy Policy for FamilyNexus

**This is a translation of the German original (`privacy-policy.de.md`). If the two versions differ, the German version prevails.**

**Last updated: 24 November 2026**

**Platform: native apps for iOS, macOS, Windows, Linux, Flatpak and Android as well as web app.**

FamilyNexus is a family calendar and messenger with shared shopping list and
task management. This policy describes the processing of personal
data on the platforms named. Differences are stated expressly.
Provider pages opened by the app (sign-in, account creation, account pages) are covered in
section 8.

## 1. Publisher, responsibility and contact

**Publisher and contact for the processing within his area of responsibility:**

- Name or company: **Alexander Ziemer**
- Postal address: **Nahestrasse 31 - 55593 Rüdesheim**
- Email for privacy enquiries: **mortisnexus@chaostribunal.de**

FamilyNexus is free software under the AGPL-3.0-or-later. Through the app, the
publisher receives no automatic usage reports and no copies of your
chat messages, events or files. Providing the software alone
does not give him access to your Matrix server or your local data.
If you contact him yourself, he processes your contact details and the content you
send him in order to handle your request.

The operator of the **Matrix homeserver** you have chosen is responsible for account
management, server operation and the processing carried out there. By default,
`https://matrix.org` is preset; you can use another compatible provider
or your own server. The provider is shown during setup in the
"Choose a provider" step and under "Advanced". In addition, its privacy notices apply, in particular regarding
operator details, logging, hosting, deletion periods and service providers. If
the publisher also operates your server, his responsibility also covers this
operation. A family moderator is not automatically the server operator.

## 2. Types of data, purposes and origin

The app processes your inputs as well as data that other members
share with you or that your provider supplies for synchronization.

| Data | Purpose and processing |
|---|---|
| Username, Matrix account ID, display name, provider address; when registering, where applicable email address, password and verification steps | Create an account and sign in, assign the profile and establish access to the provider. With providers that have their own sign-in page (e.g. matrix.org), the details are entered directly on their page. |
| Device identifiers and names, access token, where applicable refresh token, verification information and cryptographic keys | Keep the sign-in active, connect your own devices, encrypt and decrypt content, verify devices and restore keys. |
| Messages, replies, reactions and selected file attachments including file names | Family chat and direct chats between family members. |
| Shared and private events, titles, locations, notes, times, time zones, recurrences and acceptances or declines | Calendar, event coordination and local reminders. An event location you enter is not a capture of the device location. |
| Shopping items, quantities, groups and editing states | Shared shopping list. |
| Task lists, assignments, recurrence rules, completions, times and voluntary comments | Distribute tasks and display the completion history. The history is retained even after a periodic reset of the list. |
| Family and room names, memberships, roles, invitations and join requests | Manage the family and control access to shared content. |
| Online/offline status with time | Optionally show other family members your availability. |
| Read state (public read marker: up to which message a member has read, with time) | Optionally show “Sent” and “Read” or “Read by n” under your own messages. The marker is not end-to-end encrypted and is visible to the provider and to the provider of your chat partners. On by default, can be switched off under “Send read receipts”; markers already sent cannot be taken back. |
| Calendar themes (freely chosen name up to 30 characters, color) | Assign events to a theme and show them in color. Like events, themes are sent end-to-end encrypted to the family. |
| Birthdays and memorial days (freely chosen name up to 60 characters, date of birth and date of death, each with or without a year; including third parties and deceased people) | Show the family's birthdays and memorial days in the calendar and on “Today”, with age in years. Like events, the entries are sent end-to-end encrypted to the family. The advance notice of the display is a local setting. |
| Cash books (date, store, amount, currency, note, optionally a reduced-size photo of the receipt without camera data and location data) | Record household expenses together in one book. Each book is a separate room; entries and receipts are sent end-to-end encrypted to the members of the book (family moderators only). All members of a book see all entries and receipts, including the earlier history. The app is not bookkeeping software. |
| Choice of one of the twelve built-in avatars (only the identifier, no image, no text) | Show the avatar to other family members, including in the chat. The choice is kept as room state in the family room and is not end-to-end encrypted. |
| Avatar photo (optional; cropped square, small, without location data and camera data) | Show the photo to other family members, including in the chat. It is kept end-to-end encrypted as an event in the family room; the provider only sees size and time. Moderators can take it out of the display. For children, parents or guardians should consent. |
| Language, appearance, reminder, notification and security settings, locally blocked accounts, pending invitations and, only if “Reopen last conversation” is switched on, the ID of the conversation you last had open | Configure the app and continue processes already begun. |
| IP address, connection times, account, room and device identifiers as well as technical transmission data | Connection, delivery and operation at the server being contacted; its logging is governed by its privacy notices. |

You decide which content you enter and share. Free text and files can
also contain information about other people or particularly sensitive information, such as on
health. Share such information only with the appropriate authorization
and with the intended recipients.

## 3. Local storage and protection on the platforms

The application and Matrix databases are stored on the device **encrypted with
SQLCipher**, in the web app instead with SQLite3MultipleCiphers.
They contain, among other things, synchronized content, settings and required
session data. For the database keys, the app uses the secure
storage solution of the respective platform, in the web app a password-protected
vault in the browser.

| Platform | Key storage and special features |
|---|---|
| Android | Storage protected by Android Keystore. The app disables the intended automatic Android app backups and excludes app data via backup rules. |
| iOS | Apple Keychain with device-bound accessibility after the first unlock. The key configuration used does not provide for transferring these keys to other devices. |
| macOS | Apple Keychain; the app does not enable iCloud synchronization for these keys. |
| Windows | Secure storage via `flutter_secure_storage` with protection by the Windows credential manager. The databases are located in the local user profile. |
| Linux | Secret Service via `libsecret`, for example the keyring of your desktop environment. The databases are located in the app data directory of the user account. |
| Flatpak | Storage within the sandbox via `libsecret` and the Secret portal; the app does not get access to the entire keyring of your desktop environment. The databases are located in the app data directory of the sandbox. |
| Web app | Vault in browser storage (`localStorage`), encrypted with AES-256-GCM. The key is derived from your browser password with PBKDF2-SHA256; this password is not stored anywhere and cannot be recovered. The databases are located in the browser storage (IndexedDB) of this web address. |

For display and editing, content is decrypted on the device. On
supported devices, the optional app lock uses device authentication,
for example Face ID, Touch ID or Windows Hello. The app receives the
authentication result, no biometric templates and no device PIN. On
Linux, in Flatpak and in the web app, this app lock is not available.

The app lock hides the user interface; it is not an additional key lock
tied to every decryption. Screen protection and protection against
recordings differ depending on the operating system and do not prevent every form
of recording. The web app offers no screen protection; do not use it on
third-party or shared computers. System, disk and manually
created backups may, depending on the platform and device settings, still
contain data. A general exclusion of all backups on all platforms is not
promised.

## 4. Encryption, recipients and visible metadata

Chat content, attachments, calendar, shopping, task and birthday data are protected before
transmission with the encryption methods of the Matrix protocol.
Messages use Olm/Megolm; attachments are encrypted before upload.
The connections to the provider are additionally protected with HTTPS/TLS.

- **Family room:** Shared messages, events, shopping lists, tasks
  including their history, and birthdays and memorial days are readable by authorized family members on their
  approved devices.
- **Cash book:** Each book is a separate encrypted room. Entries and receipt photos are readable by all
  members of the book, including those invited later (earlier history, including earlier versions of
  entries). The provider sees members, times and sizes of the events and, in plain text, that the room is
  a cash book of the family, but not the content.
- **Direct chat:** Content is shared between the two accounts involved.
- **Private events:** They are synchronized between your own devices via a separate
  encrypted room of your account. "Private" therefore does not mean
  "stored exclusively on this one device".
- **Invitations:** A direct Matrix invitation can already lead to the distribution of
  keys for new messages to verified devices of the invited account
  before the person expressly accepts the invitation. Invite only the
  persons actually intended.

End-to-end encryption does **not hide all metadata**. The provider
can process, among other things, account and device identifiers, profile details, room names,
memberships and roles, times, IP addresses as well as sizes and assignments of
encrypted events. This includes public read receipts (who has read up to which message, and when) as long as “Send read receipts” is on. In particular, room state and
account management are not end-to-end encrypted like message content. This includes
the choice of your avatar (one of the twelve built-in avatars): it is kept as room state
in the family room, is expressly not end-to-end encrypted and is visible to the provider
and to all family members. Your own photo as an avatar, however, is end-to-end encrypted; the
provider only sees the size and time of the events.

With communication across servers, the homeservers of other accounts involved
may also receive encrypted events and the metadata required for
delivery via Matrix federation. Your own homeserver changes
who operates your server; it does not remove metadata or possible federation.
Recipients can copy, export or pass on content they have read.

## 5. Online status, blocks and reports

The online status is sent as an end-to-end encrypted device message to devices of
joined family members. The app keeps the received status
only in working memory and does not build a permanent history from it. For
delivery, the server may temporarily hold encrypted device messages. You can switch off
sharing under **Settings → Privacy →
Share online status**. The provider can still
see connection times. The read receipt (“Read” under your own messages) is a public read marker and not end-to-end encrypted content. It is on by default and can be switched off under **Settings → Privacy → Send read receipts**; you then only send private read markers and do not see who has read your messages either. Public markers already sent cannot be taken back.

Blocks are stored locally in the encrypted database. They
hide content on your device; they do not automatically remove the person concerned
from the family and do not withdraw content they have already received.

If you report a message, your homeserver receives the room and
message identifier, the selected report reason and your optional free text.
Because the request is made while signed in, the report can be attributed to your account. This
report data is readable by the operator. The app does not transmit a
decrypted copy of the reported message. If you yourself quote content in the
report text, it becomes part of the readable report.

## 6. Permissions, local reminders and notifications

The app requires network access for account functions, server checks and
synchronization. Content already available locally can also be used
offline; pending changes are transmitted when the connection is
restored.

Reminders are scheduled locally and contain no event title, location or
note text, but a general notice such as "Event in …". For new chat
messages and new items on the shopping list, the app shows a general notification
("New messages" or "New items on the shopping list") without sender, conversation or
content, and only while the app is open (on mobile devices they may not arrive in the background); both notifications can be switched off in the
settings. The number of unread messages may appear on the app icon; it is calculated
on the device from data already retrieved. FamilyNexus
does not integrate its own remote push service and no chat push transmission via
Firebase Cloud Messaging or Apple Push Notification Service.

| Access | Use |
|---|---|
| Notifications | Local event reminders and general notifications about new messages and shopping items; depending on the operating system with prior approval. On Apple devices the app also requests approval for the number on the app icon ("badge"). |
| Exact alarms and reboot events on Android | Trigger reminders on time and reschedule them after a device restart. |
| Device authentication on supported platforms | Approval of the optional app lock. |
| System dialogs for files | Read in files you have selected or save exports you have initiated. |
| Clipboard | Copying triggered by you, for example of invitations, data overviews or the emergency key. |

On Windows, Linux and in Flatpak, reminders and notifications are triggered by the running
app; the app asks for no permission for this. The web app offers no reminders and notifications. The app
does not request access to contacts, device location, camera or microphone. A
QR code can be read with an external camera app; this does not give FamilyNexus
camera access. You can revoke permissions there, as far as the system supports it;
affected functions may then no longer be available.

## 7. Key backup, files and data overviews

During setup, an encrypted Matrix key backup is set up.
It is used for restoration on additional or new devices. The provider
stores encrypted key data in the process. Keep your **emergency key**
safe and do not pass it on to support staff or other people.

When you expressly save attachments, data overviews or the
emergency key, **unencrypted files are created outside the protected
app databases**. The chosen folder may be synchronized with a cloud storage service.
In that case its access and privacy terms additionally apply.
Selected original files remain in their previous storage location; when
reading them in, the app tries to remove temporary selection copies.

When copying the emergency key or a data overview, the app tries to
remove the corresponding clipboard entry after one minute. Background restrictions
and clipboard histories may prevent complete removal.
Other apps or system services may process copied content depending on the platform.

In the settings you can display, copy or save overviews of the locally or online
stored data. They contain, among other things, storage locations,
account information and data holdings, but no key values or access tokens.
They may nevertheless contain personal details and are not a complete
disclosure of all server logs or backups of your provider.

## 8. External pages, stores and other providers

With providers that have their own sign-in page, the app shows the page provided by the
chosen provider for sign-in, account creation, account deletion and password change
as well as for terms and CAPTCHA. On iOS, macOS and Android the app shows it in an
embedded view (WebView) inside the app; the page then runs in the process of the
app, not in a browser. The app shows the host and path of the page but no
certificate details, and does not allow the page access to the camera, the
microphone or the location. The app deletes the cookies, cache and local storage of
this view before loading and when closing it, on iOS and macOS additionally, as far as WebKit
allows, the entire website data store (including IndexedDB and service workers) and there also when
the app is fully reset. The data store of the view is not ephemeral: if you quit the app while the
page is open, a remainder stays until the next embedded page (on iOS and macOS also until the full
reset) and cannot be deleted completely until then. On Android, complete deletion is not
confirmed on the device. In case of an error you can
continue the page in the browser; the app then opens it in a sign-in sheet of the
system (iOS and macOS, ASWebAuthenticationSession; in its standard implementation
without shared browser data) or, on Android, usually in a Custom Tab of the default
browser if that browser offers Custom Tabs (with the cookies of this browser),
otherwise in the default browser itself; on Linux and Windows the app always opens
the page in the browser. Further services for sign-in, email confirmation or CAPTCHA
may be involved in the view and in the browser; a CAPTCHA loads scripts of a third
party into the view of the app. This processing is governed by the notices of the
respective provider.

Invitation links can open the GitHub Pages page
`https://carpeasrael.github.io/FamilyNexus/join/`. When the page is retrieved,
technically necessary connection data such as IP address and browser information are transmitted to
the hosting provider. The invitation data generated by the app are located
in the URL fragment after `#`; this part is not sent to the web server during the usual HTTP page
retrieval, but is processed in the browser and may appear in the browser history.
The page passes the link on to the app upon your action.

The web app is provided at `https://carpeasrael.github.io/FamilyNexus/` via GitHub Pages
and can also be self-hosted. When the page is retrieved, technically
necessary connection data such as IP address and browser information are transmitted to the respective
hosting provider. The page does not load anything from third parties.

The public project page also serves as the OAuth client web page. Optionally,
the app can refer to Element as an external Matrix client. When sharing by
email or opening other external programs, these receive the data
you pass to them. For hosting, browsers, email services and external programs,
their respective privacy notices apply.

Download, installation and updates via an app store or a download platform
may trigger account, device and retrieval data there. FamilyNexus contains no
advertising, analytics SDKs, telemetry or automatic transmission of
crash reports to the publisher. Technical errors may be logged
locally; the app masks sensitive identifiers and secrets in the process. Independent
operating system diagnostics are governed by your system settings.

## 9. Places of processing and possible third-country transfers

Local app data is processed on your devices. Where server data is located
depends on your homeserver, its hosting and, where applicable, the servers of other
parties involved. The app does not enforce an exclusive storage location within
Germany, the EU or the European Economic Area.

Processing outside this area may also take place when external websites are accessed or with
cloud exports you choose yourself. The respective responsible
provider must provide information about specific recipients, countries and relevant safeguards.
Where the GDPR applies, third-country transfers must meet the requirements
of Art. 44 et seq., such as a relevant adequacy decision or
appropriate safeguards. Encryption alone does not replace these requirements.

## 10. Purposes and legal bases

The technical processing serves the communication,
organization and security functions you have chosen. Which legal basis applies to it in
an individual case depends on the controller actually responsible and on the
usage relationship. Using free software is not a blanket consent
to arbitrary data processing.

- Processing necessary for an agreed account and communication service
  may be based on **Art. 6 (1) point (b) GDPR**. The server provider names the
  basis applicable to its service.
- Where processing is based on your consent, **Art. 6 (1)
  point (a) GDPR** applies. It can be withdrawn with effect for the future. An
  operating system permission alone does not automatically replace
  consent under data protection law.
- For a support request initiated by you, the publisher processes your
  details in order to handle it. Where a contract is involved, **Art. 6 (1) point (b) GDPR** applies,
  otherwise **Art. 6 (1) point (f) GDPR**; the legitimate interest is
  answering the request and resolving reported problems.
- For server-side security logs and abuse reports, the
  operator must explain its specific legal basis and, where applicable, its legitimate
  interests in its own notices.

For strictly necessary local storage and access for providing
app functions you have expressly requested, **§ 25 (2)
No. 2 TDDDG** is decisive in Germany, to the extent this provision applies. No
additional storage access for advertising or analytics purposes is used.
Legal texts:
[GDPR](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX%3A32016R0679) and
[§ 25 TDDDG](https://www.gesetze-im-internet.de/ttdsg/__25.html).

Account and connection data are required for sign-in and synchronization.
Without them, the online functions cannot be used. You determine content, attachments, comments and
the sharing of the online status yourself; your provider may require certain registration
details. FamilyNexus does not carry out profiling or
automated decisions with legal or similarly significant
effect concerning you.

## 11. Retention period and deletion

**On your device:** Data remains stored for as long as it is
kept available for use and you do not remove it via the provided functions. There is
no general automatic deletion period for messages, events or
task histories. In the web app, the browser may also delete website data on its own,
for example when storage is short; if the browser password is forgotten, the
local data can only be deleted. Under **Settings → Privacy → Delete all local
data**, the app and Matrix databases, the associated locally
stored keys and the reminders and notifications managed by the app are removed.

**Signing out:** When you sign out under **Settings → Account → Sign out**, the
app removes the events (including private ones), shopping lists, tasks, birthdays and memorial days, avatar photos and cash books of this account from the device
and cancels scheduled reminders, removes notifications and resets the number on the app icon.
This also applies if the session ends in another
way, for example because the device was signed out from another device.
The remembered ID of the conversation you last had open is deleted. App settings such as language and appearance are retained. Content already sent
is synchronized again after the next sign-in; changes not yet
sent are lost.

**On the server:** Local deletion is not account deletion. After signing in again,
server data that still exists can be synchronized again. Retention periods
for account, content, connection and report data as well as backups are determined by the
respective operator. The app sets no uniform period for third-party servers.

**Delete account:** Under **Settings → Account → Delete account** you can
initiate deletion at the provider. With classic Matrix sign-in, the app
requests an account deactivation with a deletion request (`erase`). With account management
on the provider's page, confirmation takes place on the provider's page. After confirmed
completion, the local account data is cleaned up. Which server data is actually
deleted or retained further depends on the provider and
any statutory obligations. The choice of your avatar (one value out of twelve) stays
in the family room as room state even after you are removed from the family or your
account is deleted; the app hides it for people who are no longer members.
An avatar photo stays encrypted in the room history, with the members who already have it; you can
remove it beforehand in the app (“Remove photo first”). When you change or remove it, earlier
copies are only redacted at the provider on a best-effort basis; anyone who already received the
photo keeps it, including members who have left. Birthdays and memorial days you created remain
for the family (shared family data, every member may change them). Entries and receipts you created in cash
books remain encrypted in the book with the members, including earlier versions; deleting or changing an
entry creates a new event, earlier versions remain in the history, and only your own receipt file is
redacted on a best-effort basis. The creator cannot leave a book by hand; if they switch families, their
device leaves the book automatically, after which nobody can invite or remove anyone. If someone leaves
the family, they can stay in the book and see new entries until the reconciliation on the creator's device
(online, itself in the family) removes them; this also applies if they are no longer a moderator.

**Remaining copies:** Neither local deletion nor account deletion guarantees
the removal of content already delivered on other people's devices, federated
servers or in their backups. Files you exported yourself, printouts,
clipboard histories and external backups are not deleted by the app.
Uninstalling also does not replace targeted account deletion.

**Requests to the publisher:** Details from privacy or support requests
are retained only for as long as necessary for handling them and, where applicable, for
fulfilling statutory obligations or for the establishment, exercise or
defense of legal claims; afterwards they are deleted.

## 12. Children and young people

FamilyNexus can also be used by children within a family.
Legal guardians should accompany the setup, observe the terms of the chosen
account provider and discuss with the child who can see shared content.

Where consent under Art. 6 (1) point (a) GDPR is required for an online service
offered directly to children, the requirements of
**Art. 8 GDPR** apply. In Germany, for persons under 16 this generally requires the
consent or approval of the legal guardians; other countries
may provide for other age limits within the legal framework. Confirmation by
a family moderator is not an automatic check of age, guardianship
or legally effective consent.

## 13. Your data protection rights

Where the statutory requirements are met, you have in particular the
following rights against the respective controller:

- **Access** to your personal data (Art. 15 GDPR).
- **Rectification** of inaccurate and completion of incomplete details
  (Art. 16 GDPR).
- **Erasure** and **restriction of processing** (Art. 17 and 18 GDPR).
- **Data portability** for the processing operations intended for it (Art. 20 GDPR).
- **Objection** on grounds relating to your particular situation to processing based on
  Art. 6 (1) point (e) or (f) GDPR (Art. 21 GDPR).
- **Withdrawal of consent** with effect for the future; the lawfulness
  of the processing up to the withdrawal remains unaffected (Art. 7 (3) GDPR).
- **Complaint to a data protection supervisory authority**, in particular at the place of your
  habitual residence, your place of work or the place of the alleged infringement
  (Art. 77 GDPR).

For processing by the publisher, use the contact in section 1; for account
and server data, contact your provider. The publisher cannot delete or decrypt data on
third-party servers himself. Never send your password, access token or your emergency key
with a request. The rights arise from the
[General Data Protection Regulation](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX%3A32016R0679).

## 14. Changes to this policy

This policy is adjusted when the actual processing or the
legal requirements change. The date above shows which version it
refers to. New processing purposes or functions requiring consent are
not permitted merely by a change to this text.
