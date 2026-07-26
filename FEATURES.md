# Core Feature Definition

What the app **is**. Derived from `PLAN.md` §1 positioning: *the shared grocery list that shows
what the trip costs and knows your store.*

The test for "core": **remove it and this becomes a different product, or an indistinguishable
one.** Everything that survives that test is below. Everything else is in §7 and is not v1.

---

## The five

| # | Feature | Why it's core | If removed |
|---|---|---|---|
| 1 | **The list** | The thing people open 3× a week | No product |
| 2 | **Household sharing** | The reason families choose a list app over Notes; also the entire growth loop | A single-player app with no distribution |
| 3 | **Works offline** | Supermarkets have no signal. This is a property of all four others, not a feature beside them | Fails in the exact moment it's for |
| 4 | **Aisle order** | Differentiator #2 — the list matches the walk | A generic list |
| 5 | **Cost** | Differentiator #1 — the unclaimed territory in the grocery category | Indistinguishable from AnyList and OurGroceries, who are bigger, older and better funded |

Anything not serving one of these five does not go in v1.

---

## 1. The list

The core loop is **add → check off**. It runs hundreds of times per household per month, and it
is the only thing that must be perfect.

**Add**
- Inline field, always reachable, one thumb. Placeholder: `I need…` (borrowed from Bring! — beats
  "Add an item")
- Autocomplete ranked **personal history → household history → seeded catalog**. Max 10
  suggestions, generous touch targets
- Resolution handles qualifiers, plurals, typos, and regional synonyms before declaring a miss
  — built and tested: `data/catalog/`, 414 items, 859 lookup terms, 23 cases passing
- An unrecognised item is **still a valid item** — no `item_id`, no emoji, no price, lands in
  "Other", one tap to file forever
- Never a blocking prompt. No "which milk?" modal — the autocomplete list *is* the disambiguation

**Quantity** — first-class, on the name line, not buried in metadata. Handles both counted (`×6`)
and measured (`2 L`, `250 g`). Optional; absent renders as nothing, not `×1`.

**Check off**
- One tap, thumb-reachable, no confirmation
- Checked items sink into a "In the cart" section, struck through, still visible
- Undo available
- Check-off is the signal that teaches aisle order (§4) and pantry later — never a throwaway event

**Acceptance**
- Cold launch → item on list: **≤2 taps, ≤2 seconds**
- Autocomplete first paint: **<100ms**, from local data, no network
- If either fails, nothing else in this document matters

## 2. Household sharing

**Join by link, no account.** The invitee taps a link and sees the list — no signup wall, no
app-store detour before they understand what they've been sent. This is the single biggest
friction point in the category and the reason Google Keep still holds ground.

- Real-time sync across all members
- **Attribution as a caption**, never an assignment UI: "Maria added", "Ariel got this".
  No owners, no assignees, no due dates, no roles, no permissions matrix
- Member avatars in the header — initials at v1, photos later
- Multiple named lists per household
- **Free forever for members.** Only the list *owner* ever meets a paywall (`PLAN.md` §4).
  Taxing the invite loop kills growth

**Acceptance**
- Invited member sees list contents **≤3 seconds** from tapping the link, with no account
- Two members editing simultaneously: no lost writes, no duplicate rows

## 3. Works offline

Not a feature — a property of features 1, 2, 4 and 5. Every operation succeeds locally and
reconciles later.

- Local SQLite is the source of truth; the server is a sync peer, not an authority
- Op-log: `add` / `check` / `uncheck` / `edit` / `delete`, client-generated UUIDs, logical clock,
  last-write-wins per field
- `add` is **idempotent on normalized name per list** — "milk" added on two phones in two aisles
  collapses to one row
- Queue batches offline writes, replays on reconnect
- No CRDT library. A shopping list is a set, not a sequence (`RESEARCH.md` §5)

**Acceptance**
- Full session in airplane mode: add, check, edit, reorder — all succeed
- On reconnect: no duplicates, no lost edits, no user-visible conflict prompt
- Copy is honest and calm: "Offline — everything's saved, it'll sync"

## 4. Aisle order

**Automatic on add, correctable in one gesture, learned over time.**

- Every item lands in a category with **zero user input**, via the catalog
- Categories render as coloured pills with counts
- **Per-store profiles.** Category order is a property of *(store, household)*, not of the item —
  Dairy is aisle 3 at one store and the back wall at another
- Drag to reorder categories; persists per store
- **Learned order** from check-off sequence — the order you actually walk it (v1.1; v1 ships
  manual reorder)

**Acceptance**
- A fresh list of 10 common items is correctly grouped with no user configuration
- Reordering categories once persists for that store forever

## 5. Cost

The differentiator, and the one that must not ship half-built.

- **Per-item price**, **per-category subtotal**, **trip total** — the subtotal is borrowed from
  MinimaList and is the best idea in the category: "Produce $18, Meat $17.99" tells you *where*
  the money went
- **Seeded estimates so it works on trip one, with zero input.** Without this the feature is an
  empty promise until receipt scanning ships
- **Estimated and observed must never look alike.** Grey with `~` prefix for estimates, solid ink
  for prices actually paid, `≈` on the total while any line is estimated
- **Round estimates hard** — nearest $0.50 under $10, nearest $1 above. Enforced by the catalog
  build, not by review. `$3.47` implies a lookup; `~$3.50` reads as a guess
- Any observation **permanently overrides** the estimate for that household
- Prices live in their own table as *observations*, never as a column on the item
- **Unpriced is a valid state** — renders as `—`, not a fake zero. The total simply doesn't
  appear until at least one line has a price

**Acceptance**
- A brand-new user with a 10-item list sees a credible trip total having entered **nothing**
- No user can mistake an estimate for a price they paid
- **Falsification test:** ≥40% of households have entered or confirmed at least one real price by
  trip 3. If this fails, the strategy is wrong and no amount of polish fixes it

---

## 6. The shape of the app

**One screen matters.** The list *is* the app. Store profiles, household settings and price
history are secondary screens you visit rarely. No tab bar competing for attention at v1.

Required for launch but not core to identity:

- **Dark mode** — used in dim stores and at night. Non-negotiable, but table stakes
- **Lock-screen + Home Screen widget with tappable checkboxes** — the right answer to pushing a
  cart with both hands. Komorebi ships this at 29K ratings, so it's catching up, not
  differentiating
- **Accessibility** — Dynamic Type, VoiceOver, `prefers-reduced-motion`. Also the price of
  Apple editorial featuring, which is the only free distribution at scale here

---

## 7. Explicitly not core

Deferred, with the reason:

| Not in v1 | When | Why not now |
|---|---|---|
| Barcode scan (Open Food Facts) | v1.1 | Long-tail nicety; the catalog covers the common case |
| Price editing + history UI | v1.1 | v1 needs entry and display, not analytics |
| Learned aisle order | v1.1 | Manual reorder is enough to prove the idea |
| Recurring staples / "the usual" | v1.1 | Real value, not identity |
| **Receipt scan → price book** | v1.2 | The moat, but the moat is *accumulated history*, not the capability. Start accumulating in v1 |
| Voice / natural-language add | v1.2 | "AI" is table stakes marketing now, not a differentiator |
| Pantry inventory + expiry | v2, maybe | A second product. Would double scope and split positioning |
| Recipe import | v2, late, unambitious | **AnyList has owned this for 14 years at 4.9★.** Do not fight there |

**Never building:**

- Coupons, deals, circulars — that's Listonic's and Bring!'s business, and it makes brands the customer
- Retailer or brand dashboards, brand analytics, shopping data sold to FMCG
- Retailer price APIs — one chain, one country, terms risk (`RESEARCH.md` §5)
- Calories, macros, wellness scoring — judging a cart loses the household
- Assignees, due dates, workspaces, roles, permissions — the work-tool failure mode
- A mascot — declined knowingly; see `research/store-teardown.md` §7

---

## 8. Build order

Each phase ends in something demonstrable.

1. **List + offline** — add, check, quantity, local SQLite, op-log. One device
2. **Catalog integration** — autocomplete and auto-categorization from `data/catalog/`
3. **Sync + sharing** — two devices, join by link, no account
4. **Aisle order** — grouping, per-store profiles, manual reorder
5. **Cost** — seeded estimates, subtotals, trip total, estimated-vs-observed rendering
6. **Polish for launch** — dark mode, widget, accessibility, empty states

Phases 1–3 are a functioning shared list. **Phases 4–5 are what make it worth choosing** over
apps with a 14-year head start, so they are not optional and must not be cut under pressure.

## 9. Still open

- **Platform** — iOS-native vs Expo cross-platform. Doesn't change this definition; changes the
  build estimate and Android reach
- **Item imagery** — emoji at v1 versus commissioned art. AnyList and OurGroceries both use real
  product photography, so this is a known gap rather than a settled choice
