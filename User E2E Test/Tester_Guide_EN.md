# FamilyNexus tester guide

Use this guide to set up test accounts, create a test family and check FamilyNexus with two devices. FamilyNexus provides a shared calendar, encrypted messaging, shopping lists and household tasks. Use fictional names, messages and appointments throughout the test.

For a complete regression run, record results in a copy of the [full test plan](Testplan_FamilyNexus.md), version 1.8. This guide explains the setup in English; the full plan contains the individual checks and expected results.

## Before you start

- Install the build provided for testing on both devices. Record the actual app version and build number, installation source, device model, operating system, date and tester name. Include the build commit if supplied. Both devices should use the same build.
- Call your devices **G1** and **G2** in the report. For the Apple test run, the full plan specifies an iPhone or iOS simulator as G1 and a Mac as G2. Record other combinations explicitly; an App Review video requires a physical iPhone.
- Select **English** on the welcome screen. Have internet access, a password manager and a way to transfer an invitation link between devices. Set up a device passcode if you will test app lock.
- Start with a clean test session. If an earlier test account is still signed in, preserve its credentials and emergency key before using **Settings → Delete all local data**. This removes local app data but leaves the server account intact. Do not clear someone else's session. On Apple devices, uninstalling alone may leave keychain data behind.
- Keep both apps open and connected during synchronization and invitation checks. Allow notifications when testing calendar reminders. Chat has no remote push notifications; open the app to synchronize messages.

## Test Matrix server

| Setting | Value |
|---|---|
| Provider address to enter in the app | `matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| HTTPS endpoint | `https://matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| Domain shown in Matrix user IDs | `matrix.chaostribunal.de` |
| Example full user ID | `@fnt-1030-n1:matrix.chaostribunal.de` |
| Sign-in method | Short username and password inside FamilyNexus |
| Expected registration | Account creation inside the app, without browser sign-in or extra verification steps |

The app initially suggests **matrix.org**. For this test, open **Advanced → Use another provider** and enter the provider address above. Wait until the app displays **Your account is hosted at matrix-synapse-3ues.srv1348446.hstgr.cloud.** Do this whenever a fresh registration or sign-in screen defaults to matrix.org.

**Use the short username when signing in**, for example `fnt-1030-n1`. The full test plan identifies `matrix.chaostribunal.de` as unreachable as a connection address, even though it appears in account IDs. Use a full Matrix ID only in a control that explicitly asks for a user ID, such as **Invite by user ID**.

If the provider cannot be reached or registration is disabled, record the exact message and contact the test coordinator. Do not switch to matrix.org to complete this test. The server must have registration enabled for the planned account creation steps.

## Choose test usernames

Replace `MMDD` with the month and day of your run, for example `1030`. If another run already used that date, append a letter, such as `1030b`. Coordinate the prefix with other testers. These are naming examples, not supplied accounts or credentials.

| Account | Username pattern | Display name | Purpose |
|---|---|---|---|
| N1 | `fnt-MMDD-n1` | `Test N1` | Family creator and moderator on G1; also used on G2 for recovery tests |
| N2 | `fnt-MMDD-n12` | `Test N2` | Additional registration, family-code and deletion tests on G2 |
| I2 | `fnt-MMDD-i2` | `Test User 2` | Invited family member on G2 |

Choose a separate password of at least eight characters for each account and save it in your password manager. Each account also gets its own emergency key. Keep passwords and keys out of screenshots, shared recordings, bug reports and repository files. Repository users may store confidential test records in the Git-ignored `secure/` directory.

Deleted usernames remain taken on this server. If a name is unavailable, use a new run prefix; do not try to reuse or delete another tester's account.

## Create the first test user and family

1. On G1, choose **Start a new family**.
2. Open **Advanced → Use another provider** and set the test provider address. Wait for the provider confirmation.
3. Enter `Test N1` under **What is your name?** and your chosen `fnt-MMDD-n1` under **Your username**. Wait for **This username is available.**
4. Enter your test password and select **Create account**. The expected next screen is **Your emergency key**.
5. Select **Create emergency key**. Save the key together with N1's username and provider in your password manager, or use **Save as file** and keep the file securely. A saved key file is unencrypted; copying a key clears the clipboard after one minute.
6. Check **I have stored the emergency key safely.** and select **Next**. A password alone does not restore encrypted history on a new device.
7. Enter `Test family MMDD` as the family name and select **Create family**. Choose **Later** if you want to prepare sample data before inviting someone.
8. Confirm that the app opens the family and that N1 is a moderator. In the full plan, record N1's initial key as **KN1**.

If registration appears stuck for more than 30 seconds, note the screen and elapsed time. The account may already exist. Try signing in with the same short username and password before creating another account; record the problem rather than silently restarting the test.

## Sign in on another device

Choose **I already have an account**, select the test provider under **Advanced**, and enter the account's short username and password. On **Unlock this device**, enter that account's emergency key and select **Unlock**. Wait for the existing family and data to appear.

Use N1 on both devices for the recovery checks in section C of the full plan. After testing **Create new emergency key**, save the replacement as **KN1b**: the original KN1 should stop working. Sign out of N1 on G2 before creating the other test accounts. Signing out does not delete the account.

## Create the additional registration test user

For section D of the full plan, use G2 and select **No account yet? Create one**. Select the test provider, enter `Test N2`, and deliberately enter N1's existing username. The app should report that it is taken and suggest an alternative, normally `fnt-MMDD-n12` when that name is free.

Accept the available suggestion, record the actual username, choose a separate password and complete account creation. Save N2's emergency key as **KN2**. Follow section D to test joining by family code, rejection and creating N2's separate deletion-test family. Sign out afterwards so G2 is ready for the invitation test. Keep N2's account until the cleanup section.

## Create an invited test user

1. On G1, signed in as N1, open **Family → Invite someone**.
2. In the invitation dialog, open **Advanced**. Set **Account server for newcomers** to `matrix-synapse-3ues.srv1348446.hstgr.cloud`, then select **Create new link**. This is essential because the server's account-ID domain differs from its connection address.
3. Use **Copy link** and transfer it privately to G2. Links expire and are valid for one use. Keep G1 open and online.
4. On G2, open the link, or select **I was invited** and paste it. If a web page opens, select **Open app**. Check that the registration provider is the test server.
5. Create I2 with display name `Test User 2`, username `fnt-MMDD-i2` and a separate password. Create and securely store its emergency key as **KI2**, check the confirmation and continue.
6. Check the family and inviter on the join card, then select **Request to join**. With automatic admission enabled, G1 admits the request while online. If **Confirm requests yourself** is enabled, approve the request on G1. Record the waiting time and any unexpected manual confirmation.
7. Confirm that G2 opens the same family as G1. N1 is the moderator and I2 is an ordinary member.

## What to check together

| Area | Suggested check and expected result |
|---|---|
| Shared calendar | Create `Test shared` for tomorrow, 10:00–11:00, with location `Kitchen` and family visibility. Confirm it appears on both accounts. Check editing and recurrence. |
| Private calendar | Create a private event as N1. Check it on N1's other device during the same-account test; it should not appear for I2. |
| Reminders | Set a near-future reminder and allow notifications. Check that the local notification appears without the event title. |
| Chat | Send messages from both accounts, reply and send a harmless image or text attachment. Confirm that the other account can receive and open it. |
| Shopping | Add `Milk`, change its quantity and check it off from the other account. Confirm synchronization. |
| Tasks | As N1, open **Tasks** from the top-right menu, create a list and assign I2. As I2, complete an item and inspect its history. |
| Roles and invitations | Check moderator controls and ordinary-member permissions. Test family codes and membership changes using the full plan. |
| Reporting and blocking | Report a test message, block its sender, then unblock under **Settings → Blocked members**. Blocking affects the current device. |
| Security and offline use | Check app lock where supported, emergency-key recovery and offline changes after reconnecting. Follow section H for the detailed encryption checks. |

For the full run, keep the order **A → B → C → D → E → H → F**, with H-01 through H-17 before F, H-18 after F-04 and H-19 after F-05. Complete the multi-user checks before deleting accounts. Section E-32 deletes I2 only after its preceding checks; section F handles the remaining cleanup. Developer checks in section G are separate from the ordinary tester walkthrough.

## Report problems and clean up

For each check, record the action, expected result, actual result and status: passed, passed with an issue, failed, pending with a reason, or not applicable with a reason. Include the device, app build, account role, exact error text, waiting time and a screenshot when useful. Hide passwords, emergency keys and active invitation links. If a test cannot be completed, report it as pending rather than passed.

Delete only your disposable accounts, at the point specified in the test plan. On this password-based server, use **Settings → Account → Delete account**, enter the account password and select **Delete account permanently**. If other members must retain the family, assign another moderator before deleting its only moderator. Verify that the app returns to the welcome screen and that the deleted account can no longer sign in.

**Delete all local data** does not delete the server account. Previously delivered messages may remain on other members' devices. At the end, record which accounts were deleted and which remain, including accounts from an interrupted run. Keep any separately assigned App Review accounts available for the review team.

References: [full test plan](Testplan_FamilyNexus.md), [first-time tester exercise](G-07_Testperson/Anleitung_Testperson.md), [test report folders](../User%20E2E%20Test%20Report/README.md).
