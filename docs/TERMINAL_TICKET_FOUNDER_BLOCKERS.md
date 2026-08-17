# TERMINAL_TICKET_FOUNDER_BLOCKERS — what no agent can do

> STATUS: open — written by cloud 2026-08-16. **This ticket is for the founder, not for an agent.**
> Terminal: do not try to execute these. Your job here is to (a) keep the list accurate as you
> discover more, and (b) never report something as verified when it is actually blocked on one of
> these.

Everything below needs an account, a card, a signature, a physical device, or a person talking to
another person. They are the real critical path — the code is further along than this list is.

---

## 1. Bagged has no Supabase project. This blocks the entire receipt feature.

**Discovered by the terminal, 2026-08-16.** The MCP-connected Supabase project belongs to a
different app (its functions are recipe-related). `scan-receipt` is deployed nowhere, and Bagged's
migrations have never been applied to any live database.

Consequence, stated plainly: **no live receipt scan has ever run, end to end, in this project's
history.** The whole capture flow — camera, upload, Claude, review, commit — has only ever been
exercised against scripted fakes. It is the app's differentiator and it is the least-proven thing
in it.

- [ ] Create a Supabase project for Bagged
- [ ] Apply `supabase/migrations/0001_schema.sql` then `0002_rls.sql`
- [ ] Deploy `scan-receipt`, `join-kitchen`, `revenuecat-webhook`
- [ ] Set the Anthropic API key in the **function environment** — it must never exist anywhere
      else, and never in the app
- [ ] Fill `Config/Secrets.xcconfig` on the Mac (gitignored; a template is committed)
- [ ] Then: one real receipt, photographed and scanned end to end, with the result in the Log

Until this exists, the build-time config check does its job — Debug warns, Release fails — so
nothing ships blind.

## 2. `bagged.app` is not owned

`DECISIONS.md` says buy the domain and handles before anything else, and it has not happened.

Two things already depend on it. The Open Food Facts `User-Agent` sends
`Bagged/1.0 (https://bagged.app)`, and they block reusers whose contact URL does not resolve — so
the barcode lookup is on borrowed time. And the App Store listing will need it.

- [ ] Buy `bagged.app` (and the handles)
- [ ] Confirm the name is clear for an App Store app in the grocery category

## 3. Apple paperwork

- [ ] Apple Developer Program membership, if not already active
- [ ] **Paid Apps Agreement** — required before wave 9's paywall can be tested at all, and it can
      take days to clear. Start it before the paywall is finished, not after
- [ ] App Store Connect record: bundle id `app.bagged`
- [ ] RevenueCat account, products configured, keys into the gitignored xcconfig
- [ ] Privacy nutrition labels. Two things leave the phone and must be declared honestly: **receipt
      photos** (to our function, for reading) and **barcode digits** (to Open Food Facts, if the
      setting is on). Locations and voice never leave the device — say so

## 4. A physical device

The simulator has carried the project a long way, but these are not simulator questions:

- [ ] The camera and the barcode scanner, in a real shop, in real light, on a real receipt
- [ ] Haptics — the whole check-off feel is unverified
- [ ] **Widget tap targets.** They are 20–26pt against a 44pt floor, forced by fitting three rows
      into a lock-screen tile. Whether that is fine or mis-taps constantly is a thing only a thumb
      can answer
- [ ] Sound behaviour against the silent switch and other audio

## 5. The two research gates that were always yours

Both predate the code and neither has been done. They gate quality, not compilation.

- [ ] **The ten validation conversations.** Ten people who buy groceries, before more UI effort
      goes in. The one question worth answering: does anyone actually want a price on a shopping
      list, or is that our idea?
- [ ] **The seed audit — 20 real receipts.** Measure real prices against the catalog's seeded
      estimates and record the error. Every `~` in this app rests on those seeds, and their
      accuracy has never been measured against reality. If the error is large, the honest response
      is fewer estimates, not better-looking ones

## 6. Things I would decide before launch, but they are yours

- [ ] **Region.** There is no region picker, so `ListCatalog` is hard-coded to `us-national`. A UK
      kitchen currently gets `—` for every estimate (honest, because a GBP kitchen refuses USD
      seeds rather than converting them) but that is a thin experience. Either ship US-only and
      say so, or add a picker
- [ ] **Open Food Facts attribution.** The barcode lookup shows their name inline. If you want the
      About screen to carry the ODbL notice too, that is a wave-9 line of copy

## 7. Two App Review blockers found while building wave 9

Both are structural, not cosmetic, and both will fail submission rather than merely look bad.

- [ ] **In-app account deletion.** Once sign-in ships, **App Review 5.1.1(v) requires an account
      to be deletable from inside the app.** `Repository` has no wipe API and there is no
      account-deletion call on the server, so `DataPrivacyScreen` states the truth today —
      deleting the app takes the database, the photos and the pins; a shared kitchen is a support
      email. That is honest and it is not sufficient for review. Needs a `Repository` wipe **and**
      a server-side delete; it is a packet, not a checkbox, and it is on the critical path to
      submission rather than to launch.
      **What deletion means is no longer an open question** — `DECISIONS.md` → "Deleting an
      account" settles it (the person leaves, the household keeps its list, ownership passes to the
      longest-standing member, `scan_audit` goes because it is the one table holding a `user_id`).
      **The server half is built and proven** — W10-P3, `supabase/migrations/0003_delete_account.sql`
      plus `supabase/functions/delete-account/`, 20 RLS sections and 117 asserts, three mutation
      tests. What remains is below.
- [ ] **Deploying the migration WITHOUT the edge function leaves deletion silently incomplete.**
      `auth.users` is owned by `supabase_auth_admin`, not by the role that owns the function, and a
      refusal there can be silent — a delete that matches zero rows raises nothing. The SQL deletes
      the person's data; only the edge function's Admin API call deletes their **login**. Deploy
      both or the person can sign back in to an empty account, and App Review 5.1.1(v) is not
      satisfied. The function reports `auth_user_deleted` from the row count rather than from
      optimism, so this is detectable — but only if someone looks.
- [ ] **A deleted user's access token still works until it expires** (Supabase tokens are
      stateless; the Admin API revokes refresh tokens and sessions, so no *new* token can be minted,
      but the one in hand lives out its TTL — an hour by default). Within that window a call could
      re-create membership or an entitlement row. And with no time bound at all: a late or replayed
      RevenueCat webhook re-creates an `entitlement` row for a deleted user, because
      `apply_entitlement_event` is an unconditional upsert. **Both were proven by execution, not
      argued.** The app must sign out as part of deleting; the server-side fix is an
      `exists (select 1 from auth.users …)` guard, which changes contracts two other packets own.
- [ ] **The local half** — a `Repository` wipe (database, receipt photos, pins, defaults), the
      confirm screen naming the heir *before* the confirm using the same rule the server uses
      (`order by joined_at, user_id` among the others, and only when the leaver was the sole
      owner), and handling the endpoint's three answers: retry-safe, `auth_user_not_deleted` means
      retry and never show success, `upstream` means nothing was deleted.

      One fact for whoever builds it: `op.kitchen_id` has **no `on delete cascade`**, so deleting a
      kitchen fails on a foreign key while its ops exist. A mutation test in W10-P3 confirms it by
      removing the ordered delete and watching the constraint fire.
- [ ] **A paywall must carry Terms and Privacy links.** `SupportURL`, `PrivacyPolicyURL` and
      `TermsURL` are read from Info.plist the way the scan endpoint is, and none of the three is
      declared — because the domain is not owned (item 2). About says so plainly rather than
      showing dead rows, but a paywall without those links is rejected. **The domain blocks the
      paywall, not just the branding.**

## 8. RevenueCat is not in the binary

`SubscriptionStore.purchase`/`restore` are seamed and always answer `.unavailable`; the paywall
renders its honest not-on-sale state and **cannot sell anything**. That is correct for today — no
key is committed and none should be — but it means the entire purchase path is unexercised. Adding
the dependency is a deliberate act (`project.yml` `packages:`), and it should happen at the same
time as the account and the products, not before.

**One thing must land in the same change as the SDK, or it is a live bug about someone's money.**
`purchase()` sets `isPlus` locally the instant StoreKit succeeds, but the server's `is_plus` only
moves when the RevenueCat webhook fires — so an entitlement read in that window would revoke Plus
from someone who paid seconds ago. A 15-minute local-purchase grace period holds that door shut
today. **The ruling for when the SDK arrives: `isPlus` belongs to RevenueCat's customer info —
StoreKit-backed, works offline — and the server read is reduced to the quota (`scans_used`), which
is the only half the server owns.** That dissolves the race instead of timing it. Do it as part of
adding the dependency, not afterwards.

## 9. Entitlement reaches a device ONLY by scanning on it

Found by W9-P7 arguing against its own work, and it is a correctness gap that has to close
before anything is sold.

The server's `is_plus` rides on the scan response and nothing else. So:

- A subscriber who buys Plus on their **iPhone** and opens Bagged on their **iPad** is not
  entitled on the iPad until they scan a receipt there. Until then Setup shows the sales card and
  the switcher offers to sell them a second shop they already own.
- A **joiner** in a household whose owner pays is told "more than one shop is part of Plus, yours
  stays free" for a feature the kitchen has already bought.
- A **fresh device** says "3 free scans left" before it has ever asked the server — the app being
  more generous than the server, for exactly one scan.

The fix is an entitlement read that does not require a scan: either a `GET` on the `entitlement`
row (RLS already scopes it to the user) called on launch and on foreground, or RevenueCat's own
customer-info sync once the SDK is in the binary. **Do not ship a purchase without one of them** —
someone who has paid being shown a sales card is the worst version of this app's honesty problem,
because it is about their money.

- [x] **An entitlement refresh that works without scanning** — W10-P2, 2026-08-17. `GET
      /rest/v1/entitlement` behind the existing `KitchenBackend` seam, read on launch, on every
      foreground and after a join. Three answers, not two: a found row, an absent row (a user who
      has never scanned has none, and the server would grant them three), and unavailable — which
      writes nothing, because a network fact is never an entitlement fact.
- [ ] **Still open, and it is the second bullet above: a guest in a household whose owner pays.**
      Entitlement is keyed on `user_id`, so a guest reads their own absent row no matter what the
      owner bought. Closing it needs an entitlement lookup **through kitchen membership** on the
      server — and first a product ruling on whether Plus is a person or a household, which is now
      in `DECISIONS.md` → "Still genuinely open".
- [ ] **Verify it on a device.** Nothing proves the wiring: every build in this repo has no
      `SupabaseURL`, so the reader is nil and the refresh is a no-op, and no unit test can reach
      `scenePhase`. The check is three steps and belongs on TestFlight — buy on device one,
      foreground device two signed in as the same account, watch the sales card go.

Two limits of that fix, both deliberate and both written into the code rather than left to be
rediscovered: it only works **between devices signed in as the same user** (an anonymous session
has its own user id, so entitlement genuinely cannot travel for a device that has never signed in),
and **`isPlus` will belong to RevenueCat, not to this read, the moment the SDK lands** — the server
owns the quota, StoreKit owns whether someone paid. Until then a local purchase wins for 15 minutes
so that a foreground read cannot revoke Plus from someone who paid seconds ago while the webhook is
still in flight.

## 10. The screens panel must leave the binary before submission

Written down here because it is the only category of thing that gets forgotten: a temporary panel
that works fine.

`App/Features/You/ScreensPanel.swift` opens ~25 screens directly for testing, reached from
About → "Open a screen directly". It is deliberately in **Release** builds, because TestFlight is a
Release build and testers are the point of it. Two locks stand between it and the App Store — the
runtime one shows it only for a `sandboxReceipt`, and `BAGGED_SCREENS_PANEL` decides whether it is
compiled at all — and the second is the one to use.

- [ ] Before any App Store submission, **delete `BAGGED_SCREENS_PANEL` from the Release line in
      `project.yml`** and regenerate. That is the whole removal: the panel, its row in About and its
      tests all vanish from the binary. Confirm by grepping the built product's strings for
      "Open a screen directly" — absent is the pass.

The founder asked for the panel as scaffolding and said so at the time — *"we wanted to actually
make it properly later"*. The real navigation decision (where account, join and the budget screen
belong) is still open and unmade; five mockups exist and none has been chosen. **The panel is not
that decision and must not become it.**

---

## Log

<!-- Terminal: append what you discover that belongs on this list. -->
