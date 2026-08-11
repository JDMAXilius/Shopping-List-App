# Everything the app does — read from the 59-screen spec

> **Rewritten from `Bagged · Screens` (`74:16`), July 2026.** The previous version described a
> list-first app with pantry deferred to v2. **The spec is a different product** — see
> `docs/SCREENS_SPEC_REVIEW.md`. This document now matches the screens.

**Legend:** ✅ in the spec · 🔒 behind Bagged Plus · ❓ shown but unspecified · ⚠️ contested

---

## The full list

**Capture**
- Scan a receipt — every line at once
- Review every line before anything is saved
- Per-line confidence: sure · not sure · no match
- Match an unknown line once, remembered forever
- Create a new item from a receipt line
- Ignore a receipt line permanently
- Scan a barcode
- Type a receipt in by hand
- Dictate items instead of typing
- Summary after every capture
- Receipt photo kept with the trip

**Shelf**
- See everything in your kitchen
- Counts: things in · running low · to eat soon
- Grouped by location — fridge, produce, cupboard, freezer
- Create, rename and reorder your own locations
- How much of an item is left
- Days until it runs out
- Expiry date per item
- Automatic expiry guess
- Eat me first — what's turning soonest
- Add an item by hand
- Edit quantity, location, expiry, category
- Cook with what's turning
- Empty state that fills from one receipt

**List**
- Add by typing
- Add by speaking
- Autocomplete from your catalog
- See what you've paid inside the autocomplete
- Add anything that isn't in the catalog
- Quantity per item
- Tick off with one thumb
- Grouped by aisle
- Per-aisle subtotals
- Finished aisles collapse
- Unpriced items promoted to the top
- Tap to set what you paid
- Running trip total
- Breakdown of estimated vs guessed
- Aisle order per shop, drag to reorder
- Switch which shop the list is for
- Cheaper elsewhere — same basket at another shop
- All-done state with a runs-out preview

**Prices**
- Your price book — items, receipts, stores
- Overall price trend since a given month
- Price change per item
- Full price history per item
- Every observation dated and attributed to a store
- Change between observations
- Trips list
- Budget per trip
- Over / under budget
- Monthly spend
- Month against last month
- Share of prices from receipts vs estimated
- Average spend per trip, per store
- Trip detail with every line
- Category detail
- Store comparison across shops
- Coverage stated per store
- Cheapest store per item
- "Your usual" baseline

**Kitchen**
- Shared lists
- Invite by link
- QR code invite
- Share via Message, WhatsApp or anything else
- A new link revokes the old one
- Guests need no account
- Roles — owner, guest, invited
- Activity feed of who did what
- Per-member permissions
- Hide your shelf from a member
- Never share prices with a member
- Guest view
- Remove anyone at any time
- Leave a list

**Offline**
- Everything works with no signal
- Changes sync when you're back
- Offline banner
- Typing works with no camera and no signal

**Surfaces**
- Lock-screen widget with tappable boxes
- Home-screen widgets — small, medium, large
- Widget previews using your real data
- Step-by-step widget setup
- Live Activity on the lock screen
- Dynamic Island
- Apple Watch app
- Siri phrases — add, what's left, read aloud, start a shop
- Shortcuts
- CarPlay, read only

**Places**
- Add a shop by search or by dropping a pin
- Wake-up radius per shop
- The list wakes when you arrive
- Manual arrival prompt when location is off
- Learns shops from where you stop
- Edit or delete a shop
- Location never leaves the phone

**Onboarding**
- Name your kitchen
- Add your first shop
- Fill your shelf from one receipt
- Sign in and restore purchases
- Camera, location and notification primers
- Every primer says what happens if you decline

**Settings**
- On-device voice, with language choice
- Notification toggles, each on its own
- Full inventory of everything the app holds
- CSV export
- About and version

**Money**
- Bagged Plus — $29.99 a year
- 7 days free
- Free tier stays free
- No ads
- Restore purchases

---

## The product in one line

> **Bagged — knows what you have, remembers what you paid.**

## The loop everything serves

```
scan a receipt  →  every line lands on the shelf, with its price
                →  the shelf runs down over time
                →  what's running low becomes the list
                →  shop  →  scan the receipt  →  repeat
```

**One photo does two jobs**: it fills the pantry *and* records the prices. That single action is
why the app has no cold-start problem — *"One photo · every line · about 6 seconds."*

---

# The five core features

## 1. Capture — the engine

Everything downstream is fed by this. Four ways in, all producing the same thing: **priced items**.

- ✅ **Receipt photo → every line** *(C2)* — *"14 lines found · 12 matched to your catalog"* 🔒
- ✅ **Review before commit** *(C3)* — *"Nothing goes on the shelf until you say so."* Per-line
  confidence: `sure` · `not sure` · `no match`. *"2 lines still need you. They stay off the shelf."*
- ✅ **Teach it once** *(C4)* — match an unrecognised line, and *"next time MILK 2% GAL lands on a
  receipt, Bagged matches it to Whole milk without asking."* Or create a new item, or ignore the
  line forever
- ✅ **Barcode scan** *(C5)* — one thing at a time, with a quantity stepper
- ✅ **Type it in** *(C6)* — works with no camera and no signal. *"Every line you type becomes a
  price observation, tagged `typed`. It counts the same as a scan."*
- ✅ **Result summary** *(C7)* — *"12 things went on the shelf · Trader Joe's · 26 Jul · $67.31"*

## 2. The Shelf — what you have

- ✅ **Everything in the kitchen, grouped by location** *(B1)* — *"62 things in · 4 running low ·
  2 to eat soon"*
- ✅ **Freshness per item** — `plenty` · `9 left` · `2 weeks` · `~3 days` · `eat in 2d` · `ripe now`
- ✅ **Eat me first** *(B5)* — *"5 things turning, soonest first"*
- ✅ **How much is left** *(B2)* — *"About 72% left · runs out in ~5 days"* ⚠️ **see §Unanswered**
- ✅ **Locations you define** *(B6)* — Fridge, Produce, Cupboard, Freezer. Drag to reorder;
  renaming keeps the contents
- ✅ **Add by hand** *(B3)* — type or dictate, with quantity, location, category and expiry.
  *"Expiry — ~ Guess it for me"* ❓
- ✅ **Edit anything** *(B4)*
- ✅ **Empty state that teaches the loop** *(B7)* — *"One receipt fills it"*
- ✅ **Cook with what's turning** *(B5)* → *"Opens in Otto"* ⚠️ external app

## 3. The List — what to buy

- ✅ **Unpriced items promoted to the top** *(D1)* — *"tap to set what you paid"*. The gap is the
  action, not an afterthought
- ✅ **Grouped by aisle, with subtotals**, finished aisles collapsing to `✓ PRODUCE · done (2)`
- ✅ **Running total with its own honesty** — `≈ $30.40 · 3 estimated · 1 guessed`
- ✅ **Add by typing or speaking** *(D1, D3)* — one bar. *"Recognition runs on this phone. Nothing
  you say is sent anywhere"*
- ✅ **Autocomplete shows what you've paid** *(D3)* — `12 observations · $4.99`
- ✅ **Add anything not in the catalog** — *"Add 'oat m' as a new thing"*
- ✅ **Aisle order per shop** *(D4)* — *"saved for Trader Joe's only. Costco keeps its own"*
- ✅ **Switch which shop the list is for** *(D5)* — prices, aisle order and the wake-up all follow
- ✅ **Cheaper elsewhere** *(D6)* 🔒 — same basket at both shops, per-item deltas, and it states
  its own gaps: *"Three things have no Costco receipt yet, so they are not in this number"*
- ✅ **Done state that closes the loop** *(D7)* — *"3 of those prices were estimates. Scan the
  receipt and they become measured"*, plus a preview of what runs out next

## 4. Prices — what you paid

- ✅ **Your whole price book** *(E1)* — `212 items · 38 receipts · 3 stores`, `▲ +8.1% since May`,
  per-item trend
- ✅ **Item history** *(E2)* 🔒 — every observation, oldest → newest, per store, with deltas.
  *"12 observations, one estimated"*
- ✅ **Trips** *(E3)* — `38 trips · $2,940 tracked`, **per-trip budget**, `under` / `over` ❓
- ✅ **Month** *(E4)* — vs last month, `FROM RECEIPTS 34% / ESTIMATED 66%`, per-store average, and
  *"Same basket at Costco would have run about $31 less across July"*
- ✅ **Trip detail** *(E5)* — every line, vs budget, with the receipt facsimile kept
- ✅ **Category detail** *(E6)* — per category per month, item breakdown, vs last month
- ✅ **Store comparison** *(E7)* 🔒 — *"Your 8 staples, priced at 3 stores"*, with **coverage stated
  per store** (`8 of 8 priced`), a `your usual` baseline, and per-item cheapest

## 5. The Kitchen — shared

- ✅ **Invite by link** *(F1)* — *"They just tap the link."* Copy · QR · Message · WhatsApp.
  **New link revokes the old one**
- ✅ **No account for the people you invite** *(A6, F2)* — *"Sara Ruiz · Guest · no account"*
- ✅ **Roles** — owner · guest · invited
- ✅ **Activity feed** *(F2)* — *"Sara added Oat milk · 2h"*, *"Mateo ticked off Eggs · yesterday"*
- ✅ **Per-member privacy** *(F3)* — `The list: Edit` · `Your shelf: Hidden` ·
  **`Prices and receipts: Never`**. Prices are private *inside* the household
- ✅ **Guest view** *(F4)* — the list only, with a *"Get Bagged"* upsell and *"Leave this list"*
- ✅ **Remove anyone at any time**

---

# Everything else

## Offline — a property of all five, not a feature beside them

- ✅ Everyone edits the same list, offline or on *(I2)*
- ✅ Changes sync when you're back
- ✅ Typing works with no camera and no signal *(C6)*

## Surfaces

- ✅ **Lock-screen widget with tappable boxes** *(G1)* — plus step-by-step install instructions
- ✅ **Home-screen widgets, three sizes** *(G4)* — previewed with your real data
- ✅ **Live Activity** *(G8)* — lock screen + Dynamic Island. *"Starts when you arrive"*
- ✅ **Apple Watch** *(G5)* 🔒 — tick items, see the total
- ✅ **Siri & Shortcuts** *(G6)* 🔒 — four phrases: add · what's left · read my list aloud · start a
  shop. On-device recognition ⚠️ *gating this saves nothing — see `FEATURES.md` §10*
- ✅ **CarPlay** *(G7)* 🔒 — read only

## Places

- ✅ **The list wakes up where you shop** *(G2)* — geofence with a wake-up radius *(G3)*
- ✅ **Works with location off** — *"At Trader Joe's? Yes / Not now"* *(A4, G2)*
- ✅ **Learns your shops** — *"or let it learn from where you stop"*
- ✅ **Location never leaves the phone** — no server knows where you shop

## Onboarding

- ✅ Name your kitchen *(A3)* · add your first shop *(A4)* · fill your shelf from one receipt *(A5)*
- ✅ Permission primers for camera, location and notifications, each stating what happens if you
  decline *(I5, I5b, I5c)*

## Settings

- ✅ Voice — on-device, language *(H3)* · Notifications, individually switchable *(H4)*
- ✅ **Data & privacy** *(H5)* — every data class the app holds, where it lives, and **CSV export**
- ✅ About, version *(H6)*

## Money

- ✅ **Bagged Plus — $29.99/year, 7 days free** *(H2)* ⚠️ *annual only; `PLAN.md` decided monthly too*
- 🔒 Gated: receipt scan · price history · more than one shop · Watch, Siri, CarPlay
- ✅ *"The glance stays free for everyone. Plus is what pays for it."*
- ✅ No ads

## States designed

- ✅ Generic empty *(I1)* · Offline *(I2)* · Scan failed *(I3)* · Processing a receipt *(I4)* ·
  three permission primers *(I5–I5c)* · Shelf empty *(B7)* · List all-done *(D7)*

---

# The honesty rules, as the screens use them

| Tier | Renders | Meaning |
|---|---|---|
| **measured** | `$4.49` solid | from a receipt or typed in |
| **estimated** | `~$5.00` | from the seeded catalog |
| **guessed** | *counted only* ❓ | **never visually defined — define it or fold it into estimated** |
| **no price yet** | `—` | nothing known |

Totals carry `≈` and break themselves down: *"3 estimated · 1 guessed"*. Comparisons state their
own coverage: *"8 of 8 priced"*, *"Three things have no Costco receipt yet."*

---

# ⚠️ Unanswered in the spec

1. **How does the shelf know something is running out?** *"About 72% left"* implies consumption
   tracking. Nothing in 59 screens says whether the user logs it or the app infers it. **The Shelf
   is the first tab and this is undecided**
2. **Where do expiry guesses come from?** The catalog has no shelf-life field
3. **Budgets** — shown in E3/E5, specified nowhere. If they ship: they report, they never scold
4. **`guessed`** — a fourth tier that only ever appears in a footnote

# What our old docs had that the spec drops

- **Monthly subscription** — spec is annual-only
- **Recurring staples suggested when overdue** — replaced by the shelf running down, which is
  better
- **Multiple lists** — only one "Weekly shop" appears anywhere
- **Recipe import** — replaced by *"Opens in Otto"*
- **Multi-store split basket** ("shop A for these, B for those") — E7 compares, it doesn't split
