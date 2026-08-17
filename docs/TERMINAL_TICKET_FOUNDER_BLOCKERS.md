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

---

## Log

<!-- Terminal: append what you discover that belongs on this list. -->
