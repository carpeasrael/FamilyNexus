# FamilyNexus – App Review guide

Prepared 30 October 2026 from repository version 1.2.1 (21). Before attaching this guide, confirm that it matches the submitted build and the completed Review Notes. The instructions below use the English interface and matrix.org accounts.

## Purpose and prerequisites

FamilyNexus combines a family calendar, local appointment reminders, encrypted family and direct messaging, a shared shopping list and assigned household tasks. Families can organize their day without spreading plans across several conversations and lists. It is intended for consumers; adults manage the family, and minors require guardian consent and moderator invitation.

Use an internet connection for account setup and synchronization. Previously synchronized data is stored locally in encrypted form. Calendar reminders require notification permission. Chat does not provide remote push notifications; open the app to synchronize messages. No subscription, purchase, sample import or additional Matrix client is required for the review flow.

The iOS project targets iPhone (minimum iOS 15). The submitted platform/build and physical test devices are identified in the completed Review Notes. If reviewing macOS, use the same navigation; click and hold a message where these instructions say long-press.

## Review accounts and initial access

Use R1, the moderator account in App Store Connect's **Sign-in information**. Its emergency key and the credentials/key for R2, the member account, are in **Notes**. Each account has its own key. Passwords alone do not unlock encrypted history on a new device.

1. Launch FamilyNexus and select **I already have an account**.
2. Leave the provider at **matrix.org** and select **Sign in at matrix.org**.
3. Complete sign-in in the browser with the selected review account. If another account is already selected, sign out of that browser session first.
4. Return to FamilyNexus. On **Unlock this device**, enter the emergency key for that account and select **Unlock**.
5. Wait for synchronization. The account should open the existing sample family, with the tabs **Today**, **Calendar**, **Chat**, **Shopping** and **Family**. Tasks are in the top-right menu.

If the app instead asks to create a new family, or the key does not unlock the sample data, the review account is not correctly prepared. The publisher must correct the account setup before submission. Do not substitute an empty family for the prepared review dataset.

## Main features

| Feature | Steps | Expected behavior |
|---|---|---|
| Daily overview | Open **Today** | Upcoming appointments and task overview; the notification permission hint can lead to permission/settings |
| Shared calendar | **Calendar → New event**; enter a title, future date/time and shared visibility; save | The appointment appears in the calendar and synchronizes with the family |
| Private appointments | Create another event with private visibility | It belongs to the account's own devices, not the family calendar of R2 |
| Views and recurrence | Change calendar view; open an event and edit its recurrence | Day/week/month/agenda views and recurring appointments can be inspected |
| Reminders | Allow notifications, create a near-future reminder and put the app in the background | A local reminder appears without the appointment title; this is separate from chat notification behavior |
| Family chat | **Chat**; type and send a harmless message | The family conversation displays the message; R2 can receive it while connected |
| Direct chat | **Family → member → Send message** | Opens a conversation between the two joined family members |
| Attachment | In Chat, use the attachment control to choose an ordinary text file or image; send; on the receiving device load the attachment | The file can be inspected after downloading. The supplied `review-attachment.txt` is optional |
| Shopping | **Shopping**; add `Milk`, set quantity, then check the item off | Family members share the list and can edit or remove entries |
| Tasks as moderator | Top-right menu → **Tasks → New task list**; enter title/items, assign R2 and select a repeat rule; save | The assigned list appears for both accounts |
| Tasks as member | Sign in as R2 and open **Tasks**; check off an assigned item, optionally add a comment; open its history | R2 can complete its assigned items; completion history is visible |
| Family administration | As R1, open **Family** and the invitation/member controls | Moderators invite, promote or remove members. R2 has ordinary member permissions |
| Invitation | As R1, generate a link/QR invitation; on another device open it and complete joining with a separate test account | The invitation identifies the family/provider; a moderator must be available to admit/confirm the request |
| Device security | Menu → **Settings**; inspect device authentication and **Emergency key and devices** | App lock and encryption/device verification controls are available |

The publisher should prepare at least one upcoming shared event, one recurring event, a private event for R1, messages from both accounts, open/completed shopping items, and a task assigned to R2. Keep dates relevant for the review period. Both roles must be independently accessible without a developer manually approving each login.

## Registration

On a clean app session, select **Start a new family**, enter a display name, and select **Create account at matrix.org**. Complete the provider's account creation in the browser, including any email verification, terms or CAPTCHA it requests. Return to the app, select **Create emergency key**, securely store the key, check **I have stored the emergency key safely.**, and select **Next**. Enter the family name and select **Create family**. Invitations can be added immediately or later through **Family**.

Provider-controlled browser labels and verification steps can change. The publisher must verify this exact path on the submitted build before supplying the recording.

## User-generated content: reporting and blocking

Users create chat messages and attachments, calendar entries, shopping items and task lists/comments within their family. There is no public content feed or entertainment catalog.

1. In Chat, long-press a message from another member and select **Report message**.
2. Select a reason, optionally enter explanatory text, and select **Report**. A successful request displays **Report sent.**
3. The report is sent to the selected Matrix server's operator. It includes identifiers, the reason and optional explanatory text. The operator can read that text but does not receive the decrypted message body through this report.
4. Select **Block sender**, or use the member's block action. Blocking hides the sender's messages and direct chat **on the current device**; it is not an account-wide or family-wide ban.
5. Restore access under **Settings → Blocked members → Unblock**. A moderator may separately remove a member through **Family**.

The implemented reporting control is a **chat-message** action. This guide does not claim there is a separate reporting action for every calendar, shopping or task item.

## Account deletion

Use a disposable account for this test so the permanent review accounts remain available.

1. Menu → **Settings → Account → Delete account**.
2. Review the warning. If the account is the only moderator of a family with other members, assign another moderator first to preserve family administration.
3. With matrix.org browser authentication, select **Open deletion page**, complete deletion on the provider's account page, then return to FamilyNexus. Select **Check deletion** if the app has not yet completed the check automatically.
4. After the provider session is no longer accepted, the app clears local data and returns to the welcome screen. Separately verify that the deleted account can no longer sign in at the provider; merely invalidating a session is not sufficient evidence of deletion.

On supported password-based Matrix servers, the app instead asks for the password and offers **Delete account permanently**, using the server's account-deactivation API with its erase option. OAuth providers must expose a supported account-management page; an arbitrary provider is not guaranteed to support deletion through this app.

**Delete all local data** only clears this device and does not delete the Matrix account. Previously delivered messages may remain with other members after account deletion.

## Optional sample attachment

The package includes `sample-files/review-attachment.txt`, containing only fictional review text. No file is required to sign in or use the main features. If testing file transfer, make this file available in Files on the device, select it with the chat attachment picker, send it and load it from the other account.
