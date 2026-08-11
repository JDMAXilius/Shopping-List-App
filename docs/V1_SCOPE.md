# v1 scope — settled

**Decided August 2026.** After cutting recipes and the pantry. This is the build spec: no
"contested", no "unspecified". Everything here ships; everything not here doesn't.

**What the app is:** a shared grocery list that knows what things cost. List-first, shaped like
Amazon Fresh's shopping list.

**The loop:** `add to the list → shop → scan the receipt → prices get real → the list gets smarter`

**Navigation: three tabs.** `List` · `Prices` · `You` — plus one `+` for capture.
*(Was four. The Shelf tab is gone.)*

---

# Features — 62 in v1

## 1. The list *(the product)*

- Add by typing
- Add by speaking — on-device, offline, free
- Autocomplete: your history → household history → catalog
- **See what you last paid inside the autocomplete**
- Add anything not in the catalog
- Quantity and unit per item
- Per-item note
- Tick off with one thumb
- Undo
- Swipe to delete
- Items grouped by aisle, automatically
- **Per-aisle subtotals**
- **Finished aisles collapse** — `✓ PRODUCE · done (2) · ≈ $11.40`
- **`COMPLETED (n)` collapsed at the bottom** *(from Amazon Fresh)*
- **Unpriced items promoted to the top**, each reading *"tap to set what you paid"*
- **Running trip total** with `≈` while any line is estimated
- **Total breaks itself down** — *"3 estimated · 1 no price yet"*
- **`SUGGESTED FOR YOU` grid** of tappable common items *(from Amazon Fresh)*
- **"Your usual" card** to start a list from
- Aisle order per shop, drag to reorder
- Switch which shop the list is for
- All-done state

## 2. Cost *(the differentiator)*

- Estimated price on every item from trip one — no input needed
- **Three tiers, never confusable:** `$4.49` measured · `~$5.00` estimated · `—` no price yet
- Estimates round hard — `~$4.50`, never `$4.37`
- Set what you paid, from the row
- A measured price permanently replaces the estimate
- Prices are observations on *(item, store, date)* — they accumulate, never overwrite
- **Observations older than 90 days revert to estimates**
- Your price book — items, receipts, stores
- **Full price history per item**, per store, dated, with deltas
- Monthly spend, against last month
- **Share of prices from receipts vs estimated** — you watch your own data get better
- Average spend per trip, per store

## 3. Capture *(the engine)*

- **Scan a receipt — every line at once**
- **Review every line before anything is saved.** Nothing commits unreviewed
- Per-line confidence: `sure` · `not sure` · `no match`
- **Match an unknown line once, remembered forever** — the catalog learns
- Create a new item from a receipt line
- Ignore a receipt line permanently
- Scan a barcode
- Type a receipt in by hand — works with no camera and no signal
- Typed lines count the same as scanned ones, tagged `typed`
- Summary after every capture
- Receipt photo kept with the trip

## 4. Sharing *(the growth loop)*

- Shared lists, live sync
- **Invite by link — guests need no account**
- QR code, Message, WhatsApp, anything
- A new link revokes the old one
- Roles: owner · guest
- Activity feed — who added what
- Remove anyone at any time
- Leave a list
- **People you invite are free forever**

## 5. Offline *(a property of all of the above)*

- Everything works with no signal
- Changes sync when you're back
- No duplicates, no lost edits, no conflict prompts
- Offline banner
- No account needed to use the app at all

## Places

- Add a shop by search or by dropping a pin
- Wake-up radius per shop
- **The list wakes up when you arrive**
- Manual prompt when location is off — *"At Trader Joe's? Yes / Not now"*
- Edit or delete a shop
- **Location never leaves the phone**

## On the phone

- **Lock-screen widget with tappable checkboxes**
- Home-screen widget
- **Siri** — add · what's left · read my list aloud
- Shortcuts, Action Button, Control Center *(all from the same App Intents)*
- Dark mode
- Dynamic Type, VoiceOver, Reduce Motion
- Haptics on every state change
- Sound on by default — two sounds, quiet, silent-switch respected

## Settings & trust

- **Full inventory of everything the app holds, and where**
- CSV export
- Voice: on-device, language
- Notification toggles
- About, version

## Money

- **Bagged Plus — $2.99/month or $29.99/year**
- 7-day free trial
- **Free tier: the list, prices, estimates, one shop, Siri, widget — forever**
- **Plus: receipt scanning, price history, more than one shop**
- ✅ **3 free receipt scans before the paywall** — the loop has to run once
- **Siri and the widget stay free.** They cost nothing to run and gating them saves nothing
- No ads, ever

---

# Screens — 27 surfaces + 7 states

## Navigable screens — 19

| | Screen | Notes |
|---|---|---|
| 1 | **List** | The app |
| 2 | Item detail + set price | Where a price becomes measured |
| 3 | Aisle order editor | Per shop |
| 4 | **Receipt review** | Nothing commits unreviewed |
| 5 | **Unmatched line resolver** | Where the catalog learns |
| 6 | Capture result | Closes the loop |
| 7 | Enter by hand | No camera, no signal |
| 8 | **Prices** | The price book |
| 9 | Item price history | Per store, dated |
| 10 | Month / spend | One spend screen, not four |
| 11 | Kitchen | Members + activity |
| 12 | Places | Your shops |
| 13 | Add / edit a shop | Pin + radius + aisle order |
| 14 | Setup | — |
| 15 | Data & privacy | The positioning pillar, and cheap |
| 16 | About | — |
| 17 | Name your kitchen | Onboarding |
| 18 | Add your first shop | Onboarding |
| 19 | Sign in / restore | Owner only; guests skip it |

## Sheets & modals — 8

Capture chooser · Receipt camera · Barcode scanner · Add item · Shop switcher · Invite ·
Paywall · First receipt

## States — 7

Empty list · All done · Offline · Scan failed · Processing a receipt · Camera primer ·
Location primer

## Other targets — 1

Widget extension *(lock screen + home screen, one target)*

---

# Cut from v1 — designed, kept, not shipping

| Cut | Why | When |
|---|---|---|
| **The whole Shelf flow** *(7 screens)* | Needs consumption tracking nothing specifies; inventories drift within weeks | **Never, unless the tracking problem is solved** |
| Recipes, meal planning, "Opens in Otto" | Not the job. AnyList owns it at 4.9★ | **Never** |
| **Cheaper elsewhere** | Needs ≥2 shops × receipts | v1.1 |
| **Store comparison** | Same | v1.1 |
| Trips · Trip detail · Category detail | Month/spend covers the need at v1 | v1.1 |
| Learned aisle order | Manual reorder proves the idea | v1.1 |
| Recurring staples | Real value, not identity | v1.1 |
| Handwriting → items | The second Claude feature | v1.2 |
| Photo of a printed list | On-device Vision | v1.2 |
| Member detail · per-member permissions · guest view | Elegant; nobody is asking | v2 |
| Watch · CarPlay · Live Activity | Three targets, tiny audience | v2 |
| Budgets | Unspecified, and risks scolding | v2 or never |
| Multiple lists | One list is the job | — |

---

# Two rules that override everything

> **1. Estimated and measured prices must never be confusable.** `~` prefix *and* lighter weight
> *and* muted colour. `≈` on any total containing an estimate. **The honesty of the number is the
> brand.**

> **2. No streaks, badges, or guilt mechanics.** Ever.

---

# What still needs a decision

1. **`guessed`** — the spec's fourth confidence tier. **Recommendation: drop it.** Three tiers are
   already the hard part; a fourth that's only ever counted weakens the rule
2. **Item imagery** — line-icon glyphs is the standing recommendation. Two sessions arrived at it
   independently, and it's the only option that's legally clean, weightless and scales with
   Dynamic Type
3. **F at 40 items** — every density judgement is still inference from a 7-item mockup
