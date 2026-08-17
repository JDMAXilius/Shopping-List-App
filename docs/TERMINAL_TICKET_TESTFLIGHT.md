# TERMINAL_TICKET_TESTFLIGHT — get a build onto TestFlight internal testing

> STATUS: in-progress — terminal 2026-08-17
> STATUS: open — written by cloud 2026-08-17.
> Same operating mode and honesty laws as `TERMINAL_TICKET_GATE_AUTOPILOT.md`.
> **Founder has an Apple Developer account and the terminal has push access to the repo.**
> This ticket is deliberately split: **§A is the terminal's**, **§B needs the founder** (and most
> of §B can be done from a phone browser). Work §A to completion, then stop at each §B item, log
> the blocker, and carry on with whatever else in §A is still open.

---

## READ THIS FIRST — one blocker sits in front of everything

**An archive is a Release build, and our own preflight fails a Release build with no backend
config.** `project.yml`'s `Check scan config` script prints an *error* and `exit 1` when
`SCAN_RECEIPT_ENDPOINT`, `SUPABASE_URL` or `SUPABASE_ANON_KEY` is empty. That check is correct and
was added on purpose — a shipping build that blames the user's account for a missing key is the
failure it exists to prevent — but it means:

> **TestFlight is blocked on `TERMINAL_TICKET_FOUNDER_BLOCKERS` item 1: Bagged has no Supabase
> project.** Not on Apple, not on signing. On that.

Do **not** work around it by deleting or weakening the check. Two legitimate paths:

1. **Preferred:** the founder creates the Supabase project (blockers §1), fills
   `Config/Secrets.xcconfig`, and the archive just works.
2. **If that is days away and you want a build in hands now:** keep the check, and let it be
   satisfied by a *deliberately* configured no-backend build — set the three values to a marker
   the app can recognise, and make the app say plainly on the capture screen that this build has
   no reader. That is a code change with a design ruling in it, so **do not invent it — log the
   request and let cloud rule on it.**

Everything else below can be prepared while that is open.

---

## §A — Yours. Do all of it.

### A1. Signing and identity in the project

`project.yml` sets `CODE_SIGN_STYLE: Automatic` and **no team**, so an archive cannot be signed.

- [ ] Add `DEVELOPMENT_TEAM: <TEAM_ID>` to `settings.base` in `project.yml` (the founder supplies
      the ID — §B1). A Team ID is not a secret; it is fine committed.
- [ ] Xcode must be signed in with the Apple ID (Settings → Accounts). If it is not, say so in the
      Log — that is a §B item, not something to force.
- [x] Regenerate and confirm `xcodebuild -scheme Bagged -destination generic/platform=iOS archive`
      gets as far as a signing error rather than a configuration error. **Different errors, and the
      difference is the whole point of this step.**

### A2. Two Info.plist keys an upload needs and we do not have

Verified absent from `project.yml`:

- [x] **`CFBundleVersion`** — absent entirely. Every upload needs a build number *higher than the
      last*, and re-using one is rejected. Set it, and decide how it increments (a committed
      integer you bump, or `CURRENT_PROJECT_VERSION` — your call, but write the rule in the Log so
      the next person does not guess).
- [x] **`ITSAppUsesNonExemptEncryption: false`** — absent, so App Store Connect will ask about
      encryption on **every single upload** until it is declared.
      I checked the tree rather than assuming, and there IS one crypto call:
      `SignInScreen.AppleNonce.hashed` uses **CryptoKit `SHA256`** to hash the Sign-in-with-Apple
      nonce. That is a hash for authentication using the platform's own framework, which falls
      squarely inside the standard exemption — as does our HTTPS traffic. So `false` is the honest
      answer, but write it **knowing** that call is there: it is a legal declaration, not a
      checkbox, and "there is no crypto in this app" would have been wrong. If anything ever adds
      encryption of its own, this key has to be revisited.
- [x] `CFBundleShortVersionString` is `1.0` and fine.

### A3. The App IDs and the App Group must exist in the developer portal

We ship **two** bundle identifiers and one shared container:

- `app.bagged` — the app, entitlement `com.apple.security.application-groups` → `group.app.bagged`
- `app.bagged.widget` — the widget extension, same App Group
- `group.app.bagged` — the App Group itself

Automatic signing will register the App IDs on first archive, **but it does not create App
Groups.** An unregistered group is a signing failure with a confusing message.

- [x] Attempt the archive and record the exact error if the group is missing.
- [ ] The group's creation is §B2. Once it exists, re-archive and confirm both targets sign.
- [ ] **Verify on device afterwards** that app, widget and intents still open the *same* database.
      A mis-registered group is silent — it does not crash, it just gives each process its own
      empty file. `AppGroup` in `Packages/Data` is the one place the string lives.

### A4. What we are NOT configuring, and why that is correct

Say this in the Log so nobody "fixes" it later:

- **No push notifications.** Nothing in the tree calls `UNUserNotificationCenter`. PRODUCT bans
  re-engagement nags, so there is no capability to enable.
- **No Associated Domains.** Invite links (`https://bagged.app/j/<token>`) cannot open the app
  because the domain is not owned (blockers §2). `RootView.onOpenURL` is therefore unreachable in
  this build — **expected, not a bug.** The paste path in Kitchen → "I have an invite link" is the
  working route and testers should be told to use it.
- **No Sign in with Apple capability yet** — `KitchenAuth.signInWithApple` refuses on an anonymous
  session by design; email is the shipping path.

### A4b. One thing IS in this build on purpose: the screens panel

`BAGGED_SCREENS_PANEL` is set in Release (`project.yml`), so the archive carries the testing panel at
About → "Open a screen directly". That is deliberate — a TestFlight build is a Release build, and it
is how a tester reaches a screen that would otherwise cost a real receipt.

- [ ] Confirm it appears in the installed TestFlight build, and that it is the sandbox-receipt path
      doing it rather than a Debug accident.
- [ ] Tell testers what it is in the same note as the two missing features below.
- [ ] **It comes out before submission, and the removal is one line** — see
      `TERMINAL_TICKET_FOUNDER_BLOCKERS` §10.

### A5. Build, archive, export

- [ ] `xcodebuild -scheme Bagged -destination 'generic/platform=iOS' -configuration Release archive`
      with an `-archivePath`.
- [ ] `xcodebuild -exportArchive` with an `ExportOptions.plist` (`method: app-store-connect`).
      Commit the plist — it is configuration, not a secret.
- [ ] Confirm the `.ipa` contains **both** the app and the `.appex`, and that the entitlements in
      the built product carry `group.app.bagged`. `codesign -d --entitlements :- <path>` shows it.

### A6. Upload

The modern non-interactive path is an **App Store Connect API key** — Issuer ID, Key ID, and a
`.p8` private key:

```bash
xcrun altool --upload-app -f Bagged.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

- [ ] **The `.p8` is a credential. It is never committed.** Put it where `Config/Secrets.xcconfig`
      lives — gitignored — and add its path to the ignore file explicitly. Apple issues each `.p8`
      **once**; if it is lost it cannot be re-downloaded, only revoked and replaced.
- [ ] Confirm the ignore rule works by running `git status` after placing the file. Do not take it
      on trust.
- [ ] Record the exact command that worked, with the secrets elided, in the Log.

An app-specific password also works and is simpler, but it is tied to the founder's Apple ID
rather than to a revocable key. **Prefer the API key.**

### A7. Verify what actually arrived

- [ ] The build appears in App Store Connect → TestFlight, and processing finishes.
- [ ] **Install it and walk the app.** A build that uploads is not a build that runs: check the
      App Group actually works on device (A3), that the widget appears in the gallery, that Siri
      finds the shortcuts, and that the capture screen says something true about having no reader.
- [ ] Paste the TestFlight build number and what you found into the Log.

---

## §B — Founder only. Most of it works from a phone browser.

Terminal: **do not attempt these.** Log which one you are stopped on and move to the next §A item.

- [ ] **B1 — The Team ID.** `developer.apple.com` → Membership. Ten characters. Not a secret; hand
      it over and the terminal commits it. *(Phone: yes.)*
- [ ] **B2 — Register the App Group `group.app.bagged`.** Certificates, Identifiers & Profiles →
      Identifiers → App Groups. Automatic signing creates App IDs but **not** groups, and without
      it the widget cannot see the list. *(Phone: awkward but possible.)*
- [ ] **B3 — Create the App Store Connect app record**, bundle id `app.bagged`, and reserve the
      name. I could not verify from here whether the App Store Connect API can create an app
      record — my understanding is it cannot, and it must be done in the web UI. **Terminal: try
      it once via the API and record the answer, because it settles this for good.** *(Phone: yes,
      the web UI works, though the name/primary-language step is fiddly.)*
- [ ] **B4 — An App Store Connect API key.** Users and Access → Integrations → App Store Connect
      API → generate a key with **App Manager** role. Download the `.p8` **immediately** — it is
      offered once. Hand over the Key ID and Issuer ID; put the `.p8` on the Mac. *(Phone: you can
      generate it, but the `.p8` download needs somewhere to put it — probably the Mac.)*
- [ ] **B5 — Add yourself as an internal tester.** TestFlight → Internal Testing → a group → add
      your App Store Connect user. Internal testers get builds without review. *(Phone: yes.)*
- [ ] **B6 — The Supabase project** (blockers §1). This is the actual critical path — see the top
      of this ticket. *(Phone: the Supabase dashboard works on mobile; deploying functions does
      not, that needs the Mac.)*

**Not needed for internal testing, so do not spend time on it:** screenshots, the full App Store
description, the age rating, or a privacy-policy URL. Internal TestFlight skips review. **Do not
start external testing** — that needs review, a privacy policy URL, and the domain we do not own.

The **Paid Apps Agreement** (blockers §3) is not needed to *install* a build, but it is needed
before a purchase can be tested, and it can take days to clear. Start it now rather than when the
paywall is otherwise ready.

---

## What this ticket is not

It is not "ship it". Internal TestFlight is how the app gets onto a real phone in a real shop,
which is where six things on `TERMINAL_TICKET_FOUNDER_BLOCKERS` §4 finally get answered — the
camera on a real receipt, haptics, the widget's undersized tap targets, and the silent switch.
Those are the point of doing this.

Two things will be visibly missing in that build and both are expected: **receipt scanning does
nothing** without the Supabase project, and **invite links do not open the app** without the
domain. Tell testers both, in writing, before they find them. An honest note beats a bug report.

## Log

<!-- Append dated entries. Never rewrite above this line. -->

## Log

**2026-08-17 · terminal · §A worked as far as the founder-shaped wall. A2 done, A1/A3 recorded.**

**A2 — both missing keys added, in both targets.**
- **`CFBundleVersion`** now reads `$(CURRENT_PROJECT_VERSION)`, and that integer lives in
  `project.yml` under `settings.base`, currently **1**. **The rule, written down so nobody
  guesses: bump it by one for every upload to App Store Connect.** It is committed rather than
  derived from git so the number that shipped is reviewable in the diff. Found and fixed while
  doing it: `Widget/Info.plist` had a hard-coded `CFBundleVersion 1` / `CFBundleShortVersionString
  1.0` of its own — an extension whose version differs from its host is rejected on upload, so the
  widget now reads the same two values from the same place.
- **`ITSAppUsesNonExemptEncryption: false`**, declared knowing what is in the tree, not as a
  checkbox: the one crypto call is `CryptoKit SHA256` in `SignInScreen.AppleNonce.hashed`, hashing
  the Sign-in-with-Apple nonce. A platform-framework hash used for authentication, inside the
  standard exemption, as is our HTTPS. The reasoning is in a comment beside the key so the next
  person inherits the reasoning and not just the value. **If anything ever adds encryption of its
  own, this must be revisited.**

**A1/A3 — the archive now fails exactly where the ticket says it should, and the difference matters.**
```
xcodebuild -scheme Bagged -destination generic/platform=iOS -configuration Release archive
error: Signing for "Bagged" requires a development team. Select a development team in the
       Signing & Capabilities editor. (in target 'Bagged' from project 'Bagged')
error: Signing for "BaggedWidget" requires a development team. ...
** ARCHIVE FAILED **
```
That is a **signing** error, not a configuration one — the project is otherwise archive-ready.
Worth knowing about the ordering: signing is evaluated before build phases, so this error comes
*before* the `Check scan config` preflight. Once `DEVELOPMENT_TEAM` is set, the next failure will
be the backend-config one, and that is the real blocker (FOUNDER_BLOCKERS item 1). Two walls, in
that order. The App Group error cannot be reached yet — signing fails first — so A3's "record the
exact error if the group is missing" is not answerable until §B1 lands.
> HANDOFF → founder: §B1 (Team ID) unblocks the next step; §B2 (create App Group
  `group.app.bagged` in the portal) unblocks the one after.

**A5 — `ExportOptions.plist` written and committed** (`method: app-store-connect`,
automatic signing, `uploadSymbols` true, `stripSwiftSymbols` false so a first tester crash report
is readable). `teamID` is deliberately absent: it belongs in `project.yml`, from which the archive
already carries it. The export command is in a comment at the top of the file.

**A4 — recorded so nobody "fixes" it later:** no push notifications (nothing calls
`UNUserNotificationCenter`, and PRODUCT bans re-engagement nags, so there is no capability to
enable); no Associated Domains (the domain is not owned, so `RootView.onOpenURL` is unreachable in
this build — expected, and the paste path in Kitchen → "I have an invite link" is the working
route testers should be told to use); no Sign in with Apple capability yet — email is the
shipping path.
