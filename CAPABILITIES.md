# Everything the app does — the flat list

The complete capability list in plain bullets, so it can be read in one pass. Detail lives in
`FEATURES.md` (why), `ENGINEERING.md` (how), `STACK.md` (built with what).

**Legend:** ✅ v1.0 · 🔸 v1.1 · 🔹 v1.2 · ⬜ v2, only if retention holds · ❓ undecided

---

## The list

- ✅ Add an item by typing — ≤2 taps, ≤2 seconds
- ✅ Autocomplete ranked personal history → household history → catalog
- ✅ Add anything, even if it isn't in the catalog — free text is a first-class item
- ✅ Quantity and unit as real fields, not text glued into the name
- ✅ Per-item note ("Honeycrisp or Envy")
- ✅ Check off with one thumb
- ✅ Undo any action
- ✅ Checked items sink to the bottom, never disappear
- ✅ Delete by swipe
- ✅ Multiple lists
- 🔸 Recurring staples — suggested when overdue, never auto-added
- 🔸 Barcode scan to add

## Sharing

- ✅ Shared household lists
- ✅ Join by link with **no account required**
- ✅ Live sync between members
- ✅ See who added what
- ⬜ Assign an item to a person

## Offline

- ✅ Everything works with no signal — adding, checking, editing, prices
- ✅ Changes queue and sync on reconnect
- ✅ Conflict resolution that never duplicates or loses an item
- ✅ No account needed to use the app at all

## Aisle order

- ✅ Items grouped by category automatically
- ✅ Per-store aisle profiles
- ✅ Drag to reorder categories per store
- 🔸 Learned aisle order from your actual check-off sequence — always overridable
- 🔸 Store-arrival reminder (system geofence)

## Cost — the differentiator

- ✅ Estimated price on every item, from trip one
- ✅ Per-category subtotals
- ✅ Running trip total
- ✅ Visible honesty: `~` and grey for estimates, solid ink for real prices, `≈` on the total
- ✅ Count of unpriced items shown, never hidden
- 🔸 Edit any price — your correction becomes the truth for your store
- 🔸 Price history per item per store
- 🔹 **Receipt scan → prices filled in automatically**
- ⬜ Spend over time
- ⬜ Multi-store split — where this trip is cheapest

## Voice and capture

- ✅ Voice add, on-device, works offline, costs nothing
- ✅ "Hey Siri, add milk to my list" without opening the app
- 🔹 Photo of a printed list → items
- 🔹 Loose phrasing → items ("stuff for tacos")
- 🔹 Handwritten list → items
- ⬜ Recipe link → ingredients

## On the phone

- ✅ Lock-screen widget with tappable checkboxes
- ✅ Home-screen widget
- ✅ Dark mode
- ✅ Dynamic Type, VoiceOver, Reduce Motion
- ✅ Haptic feedback on every state change
- ✅ Optional sound
- ⬜ Apple Watch
- ⬜ iPad

## Money

- ✅ 7-day free trial
- ✅ $2.99/month or $29.99/year
- ✅ Free tier keeps the core list working forever
- ✅ No ads, ever
- ✅ People you invite are free forever

## Pantry — v2, and only maybe

- ⬜ What's already at home
- ⬜ Predictive restock

---

## ❓ The open question: only groceries, or any list?

**Decided position: groceries by name and by design, but the app does not refuse other lists.**

- ✅ You can make a hardware-store list, a packing list, a party list — nothing stops you
- ✅ Off-catalog items already make this work with no extra code
- ❌ **No** separate "list types", modes, or templates
- ❌ **No** to-do features — due dates, priorities, subtasks, reminders-as-tasks
- ❌ **No** projects, tags, or folders

The evidence for this is in `FEATURES.md` §11: AnyList is *named* AnyList, supports five list
types, and still titles itself `AnyList: Grocery Shopping List`. **Position narrow, support
broad.** Every feature that only makes sense for a non-grocery list is a feature we don't build.

## ❓ Still undecided

- Item imagery: emoji, licensed photos, or generated photos (see `SOURCING.md`)
- Store category at launch — Shopping or Productivity
- Opt-in anonymous price pooling between households
- Opt-in reporting of unmatched search terms, to grow the catalog
