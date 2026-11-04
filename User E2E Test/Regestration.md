# Test plan: registration, invitation, blocking, removal and account deletion

Scope: create user N1 and a family, invite a second user I2 on a separate device (G2), block I2, remove I2 from the family, then delete both accounts. Every step is documented with a screenshot and a short description of what was done.

Related documents: [Tester_Guide_EN.md](Tester_Guide_EN.md), [Testplan_FamilyNexus.md](Testplan_FamilyNexus.md) (sections B, D, E-25 to E-32, F). This plan is a focused extract and does not replace the full plan.

## 1. Test environment

| Item | Value |
|---|---|
| Test server (enter in the app) | `matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| HTTPS endpoint | `https://matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| Domain in Matrix IDs | `matrix.chaostribunal.de` (not reachable as connection address) |
| App language | English (select on the welcome screen) |
| G1 | Device of N1 (iPhone / iOS simulator or Mac) |
| G2 | Separate device of I2 (a different device than G1; record model and OS) |
| Build under test | Record version, build number, commit, signature (`codesign -dvv` on macOS) |
| Tester / date | Record |

Never use matrix.org. If the server is unreachable or registration is disabled, record the exact message and stop.

## 2. Test data

`MMDD` is the month and day of the run (for example `1103`); append a letter (`1103b`) if the name was already used. Deleted usernames stay taken on this server.

| Account | Display name | Username | Full Matrix ID | Password | Emergency key | Device |
|---|---|---|---|---|---|---|
| N1 (family creator, moderator) | `Test N1` | `fnt-MMDD-n1` | `@fnt-MMDD-n1:matrix.chaostribunal.de` | `PW-N1` (see below) | `KN1` | G1 |
| I2 (invited member) | `Test User 2` | `fnt-MMDD-i2` | `@fnt-MMDD-i2:matrix.chaostribunal.de` | `PW-I2` (see below) | `KI2` | G2 |

| Other data | Value |
|---|---|
| Family name | `Test family MMDD` |
| Invitation link | Created in step T-04, single use, never stored |

**Passwords and emergency keys.** Both accounts are disposable. Use a different password of at least 8 characters per account (suggested pattern: `Fnt-MMDD-<role>-<4 random digits>`, for example `Fnt-1103-n1-7294`). The project rules forbid passwords and emergency keys in the repository or in issues. Therefore:

1. Fill in the actual values only in a copy of this table under the Git-ignored `secure/` directory (for example `secure/Regestration_credentials_MMDD.md`).
2. In the report, write only "stored in `secure/...`".
3. Hide passwords, emergency keys and the invitation link in every screenshot (crop or blur before saving).

## 3. Evidence rules

- Screenshot folder: `User E2E Test Report/<YYYY-MM-DD>_Registration/` (create it first).
- Naming: `<step-id>-<device>.png`, for example `T-04-G1.png`. If a step has several states, add a letter: `T-04a-G1.png`.
- Every step in the report records: what was done (one or two sentences), the expected result, the observed result, the screenshot file name and a status (passed, passed with issue, failed, pending with reason, n/a with reason).
- A step that was not executed is "pending", never "passed".
- Take the screenshot after the expected state has appeared, not before; for error messages and toasts take it before they disappear (about 8 s).
- Where the verification is on the server (`curl`), save the command and output in `<step-id>.txt` next to the screenshots, with secrets removed.

## 4. Preconditions

| ID | Check |
|---|---|
| P-1 | Both devices run the same build and have internet access. |
| P-2 | Neither device holds a session of another tester. If one does, do not touch it; use another device or use **Settings → Delete all local data** only for your own old test session. On Apple devices a plain uninstall may leave keychain data behind. |
| P-3 | The usernames in section 2 are free. |
| P-4 | The server accepts registration: `curl -s "https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/v3/register/available?username=fnt-MMDD-n1"` returns `{"available":true}`. |
| P-5 | A private way exists to transfer the invitation link from G1 to G2. |

## 5. Test steps

Device column: where the action happens and where the screenshot is taken.

### A. Create user N1 and the family (G1)

| ID | Dev. | Action (what is done) | Expected result | Screenshot |
|---|---|---|---|---|
| T-01 | G1 | Launch the app on G1. On the welcome screen select **English**. | Welcome screen in English with **Start a new family** and **I already have an account**. | T-01-G1 |
| T-02 | G1 | Select **Start a new family**. Open **Advanced → Use another provider**, enter `matrix-synapse-3ues.srv1348446.hstgr.cloud`. | The app shows **Your account is hosted at matrix-synapse-3ues.srv1348446.hstgr.cloud.** | T-02-G1 |
| T-03 | G1 | Enter `Test N1` under **What is your name?** and `fnt-MMDD-n1` under **Your username**; enter `PW-N1` twice; select **Create account**. | **This username is available.** appears first; afterwards the **Your emergency key** screen opens. | T-03a-G1 (form, password hidden), T-03b-G1 (result) |
| T-04 | G1 | Select **Create emergency key**, store `KN1` (password manager or **Save as file** into `secure/`), tick **I have stored the emergency key safely.**, select **Next**. | The key is shown once (crop it in the screenshot); the checkbox enables **Next**. | T-04a-G1 (before ticking, key hidden), T-04b-G1 (after) |
| T-05 | G1 | Enter `Test family MMDD`, select **Create family**; choose **Later** if asked to invite. | The family opens; N1 is listed as moderator under the **Family** tab. | T-05a-G1 (family name entered), T-05b-G1 (Family tab with N1) |
| T-06 | – | Server check for N1 (optional but recommended): log in with `curl -s -X POST .../_matrix/client/v3/login` with the password of N1. | HTTP 200 and an `access_token` (do not store the token). | T-06.txt |

### B. Invite the second user (G1 → G2)

| ID | Dev. | Action (what is done) | Expected result | Screenshot |
|---|---|---|---|---|
| T-10 | G1 | Open **Family → Invite someone**; in the dialog open **Advanced**, set **Account server for newcomers** to `matrix-synapse-3ues.srv1348446.hstgr.cloud`, select **Create new link**. | A link is shown; the server field shows the test server. | T-10-G1 (link hidden) |
| T-11 | G1 | Select **Copy link** and transfer the link privately to G2. Keep G1 open and online. | Toast **Link copied.** | T-11-G1 |
| T-12 | G2 | Launch the app on G2, choose English. Open the link (or **I was invited** → paste the link). If a web page opens, select **Open app**. | The registration screen shows the test server as provider. | T-12a-G2 (welcome / paste), T-12b-G2 (provider) |
| T-13 | G2 | Enter `Test User 2`, username `fnt-MMDD-i2`, `PW-I2` twice; select **Create account**. | **This username is available.**; the **Your emergency key** screen opens. | T-13a-G2, T-13b-G2 |
| T-14 | G2 | Create the emergency key, store `KI2`, tick the confirmation, select **Next**. | The join card shows the family `Test family MMDD` and the inviter N1. | T-14a-G2 (key step, key hidden), T-14b-G2 (join card) |
| T-15 | G2 | Select **Request to join**. Wait; record the waiting time. | G2 keeps waiting. **Nothing may happen by itself**: I2 is not admitted without moderator approval. | T-15-G2 |
| T-16 | G1 | Open the **Family** tab, select **Approve** on the request of Test User 2 and confirm the question. | The confirmation dialog names Test User 2; after confirming, I2 appears in the member list as ordinary member. | T-16a-G1 (request), T-16b-G1 (confirmation), T-16c-G1 (member list) |
| T-17 | G2 | Observe G2 after approval. | G2 opens the same family; I2 is an ordinary member, the Family tab shows no management actions ("Only moderators manage the family."). | T-17-G2 |
| T-18 | G1, G2 | Send `Hello from N1` on G1 and `Hello from I2` on G2 in the family chat. | Both messages appear on both devices (this also proves keys are shared before block/remove). | T-18a-G1, T-18b-G2 |

### C. Block I2 (G1)

| ID | Dev. | Action (what is done) | Expected result | Screenshot |
|---|---|---|---|---|
| T-20 | G1 | In the chat long-press (mac: hold the mouse button for about 1 s) the message `Hello from I2` and select **Block Test User 2**. | Dialog **Block Test User 2?** with the text that messages are hidden on this device, I2 is not told and stays a member. | T-20-G1 |
| T-21 | G1 | Select **Block**. | Toast **Test User 2 is blocked.**; messages of I2 are hidden on G1; the member list shows the badge **Blocked** next to Test User 2. | T-21a-G1 (toast), T-21b-G1 (chat), T-21c-G1 (badge) |
| T-22 | G1 | Open **Settings → Blocked members**. | Test User 2 is listed with **Unblock**. | T-22-G1 |
| T-23 | G2 | On G2 send `Still there?`. | G2 shows no error and does not learn about the block. | T-23-G2 |
| T-24 | G1 | Check the chat on G1. | `Still there?` is not visible on G1. | T-24-G1 |

### D. Remove I2 from the family (G1)

Removing a blocked member must work; the block stays a local setting of G1.

| ID | Dev. | Action (what is done) | Expected result | Screenshot |
|---|---|---|---|---|
| T-30 | G1 | **Family** tab → open the menu of Test User 2 → **Remove**. | Dialog **Really remove Test User 2 from the family? Room keys are renewed; Test User 2 can no longer read new content.** | T-30-G1 |
| T-31 | G1 | Confirm the removal. | I2 disappears from the member list. Record what **Settings → Blocked members** shows afterwards (entry kept or removed). | T-31a-G1 (member list), T-31b-G1 (blocked list) |
| T-32 | G1 | Send `After removal` in the family chat. | Message sent without error. | T-32-G1 |
| T-33 | G2 | Observe G2 (wait up to 60 s, then restart the app once if nothing changes). | I2 no longer has access to the family. `After removal` is **not** readable on G2 (new content is not decryptable). Record the exact screen and text G2 shows. | T-33a-G2, T-33b-G2 |
| T-34 | G1 | Verify old messages: scroll through the chat. | Earlier messages of I2 remain visible with the name "Test User 2" or "Former member", never with the Matrix ID (#60). | T-34-G1 |

### E. Delete both users

I2 is no longer a member, so its account is deleted first (G2); N1 is then the only moderator and member and is deleted last (G1).

| ID | Dev. | Action (what is done) | Expected result | Screenshot |
|---|---|---|---|---|
| T-40 | G2 | **Settings → Account → Delete account**. Read the dialog. | Dialog names `@fnt-MMDD-i2:matrix.chaostribunal.de` and the server, states the account is deleted permanently and sent messages stay visible to others. No "only moderator" warning. | T-40-G2 |
| T-41 | G2 | Enter a **wrong** password, select **Delete account permanently**. | Error message (password wrong); the account is not deleted. | T-41-G2 |
| T-42 | G2 | Enter the correct `PW-I2`, select **Delete account permanently**. | The app returns to the **Welcome** screen (not "Sign in"). | T-42-G2 |
| T-43 | – | Server check: log in as `fnt-MMDD-i2` with `PW-I2` (app or `curl`). | `403 M_FORBIDDEN` / "Username or password is wrong." | T-43.txt or T-43-G2 |
| T-44 | G1 | Open the chat and the **Family** tab on G1. | I2 is not a member; earlier messages show "Test User 2" or "Former member". | T-44-G1 |
| T-45 | G1 | **Settings → Account → Delete account**. Read the dialog. | No "only moderator" hint, because N1 is alone. | T-45-G1 |
| T-46 | G1 | Enter the correct `PW-N1`, select **Delete account permanently**. | The app returns to the **Welcome** screen. | T-46-G1 |
| T-47 | – | Server check: log in as `fnt-MMDD-n1`. | `403 M_FORBIDDEN` / "Username or password is wrong." | T-47.txt or T-47-G1 |
| T-48 | G1, G2 | Optional clean-up: **Settings → Delete all local data** is not needed (the welcome screen is already shown). Restart both apps. | Both devices show **Welcome**; no data of the test remains. | T-48a-G1, T-48b-G2 |

### F. Final state

| ID | Check | Expected result |
|---|---|---|
| T-50 | Accounts of this run | Both `fnt-MMDD-n1` and `fnt-MMDD-i2` are deleted and cannot log in (T-43, T-47). Note that `register/available` still reports `M_USER_IN_USE` for deleted names; the failed login is authoritative. |
| T-51 | Credentials | The credentials copy under `secure/` is marked "deleted on <date>" or removed; no secret is in the repository or in the report. |
| T-52 | Report | Summary with build, devices, result per step, list of deviations and the screenshot folder. |

## 6. Acceptance criteria

The test is passed only if all of the following hold, each backed by a screenshot:

1. N1 and the family are created on the test server without using matrix.org (T-03, T-05).
2. I2 registers through the invitation link on a separate device and is admitted only after the moderator confirms (T-15 to T-17).
3. Blocking hides I2's messages on G1 only, with no error on G2 (T-21 to T-24).
4. Removal takes effect: I2 loses the family and cannot read new content (T-31, T-33).
5. Both accounts are deleted, the app shows the Welcome screen each time, and login fails with `M_FORBIDDEN` (T-42, T-43, T-46, T-47).
6. No password, emergency key or invitation link appears in a screenshot, the report or the repository.

## 7. Edge cases to note (not required for the pass)

- Registration stuck for more than 30 s: the account may already exist. Try to sign in with the same short username before creating another; record the elapsed time and screen.
- Use the **short username** for sign-in, a full Matrix ID only in controls that ask for a user ID.
- Invitation links expire and work once; create a new link if G2 shows an invalid-link message and record it.
- If G2 shows "Unknown error." after sign-in although it succeeded (issue #28), restart the app and unlock with the emergency key; mark the step "passed with issue".
- Wrong password on deletion (T-41) must never delete the account.

## 8. Execution record (copy per run)

| Field | Value |
|---|---|
| Date / tester | |
| Build / commit | |
| G1 (model, OS) | |
| G2 (model, OS) | |
| Run prefix `MMDD` | |
| Screenshot folder | |
| Result | |
| Deviations / issues | |
