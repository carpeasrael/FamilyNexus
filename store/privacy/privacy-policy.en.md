# Privacy Policy FamilyNexus

This policy matches the text in the app (Settings → Privacy policy). **Complete before publishing:** controller with postal address and contact (legal notice), date. The page must be publicly reachable under a stable URL (store requirement).

**Verantwortlicher / Controller:** `<NAME UND ANSCHRIFT DES HERAUSGEBERS>` · `<KONTAKT-E-MAIL>`

## Who processes your data?

FamilyNexus is free software (AGPL-3.0). The app sends no data to its developers and contains no telemetry, advertising or analytics. The operator of the Matrix server you choose is responsible for processing on the server; it is shown during setup.

## What data exists?

Chat messages, files, shared and private events, responses, the shopping list, family members and your settings. Events and messages are stored encrypted (SQLCipher) on your device. The key is held in the Android keystore and never in a file.

## What does the server see?

Messages, files and shared events are end-to-end encrypted (Matrix, Olm/Megolm). The server only sees encrypted events. Metadata such as account ID, timestamps, room size and devices remains visible to the operator. Use your own server to avoid that.

## Private events

Private events are never sent to the family. Between your own devices they are synchronised through a private, encrypted room that only your account belongs to.

## Reminders and notifications

Reminders are local notifications. They never show title, location or note, only “Event in …”. There is no third-party push service.

## Permissions

Internet (connection to the server), notifications and exact alarms (reminders), boot notification (re-schedule reminders) and device credentials (app lock). No contacts, location, camera or microphone are needed.

## Backup and deletion

Android backups are switched off. If you deliberately save an attachment with “Save”, the decrypted file lies outside the app in the folder you chose. “Delete all local data” removes all data, keys and reminders from this device. “Delete account” (Settings → Account) permanently deletes your account at the provider and then all data on this device; with providers that use browser sign-in (e.g. matrix.org) you confirm the deletion on their page. Messages on other members' devices cannot technically be force-deleted. Your recovery key is the only way to rescue messages after losing all devices – keep it safe.

## Children

Children can be family members. This requires the consent of their legal guardians; accounts of minors go through invitation and confirmation by a moderator.

## Your rights

You can request access, correction and deletion at any time. You manage local data in this app and delete your account under Settings → Account → “Delete account”; other server data with your server's operator.

## Online status, direct chats, shopping list

The online status ("online" or "offline" with a time) is only sent as an end-to-end encrypted device message to devices of joined family members and is never stored; you can switch it off in the settings. Direct chats are encrypted rooms between two family members. The shopping list is transferred encrypted in the family room like shared events and is stored encrypted on your device; all family members can change it. The server only sees metadata such as timing and size.
