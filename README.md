# Bagged — a shared grocery list that knows what things cost

*Working name — not yet trademark-cleared (`NAMING.md` §9).*

A household grocery list for iOS. **Every item carries a price, every aisle a subtotal, every trip
a total.** No competitor in the category does this.

**Status: planning complete, zero lines of app code.** 71 files, ~8,400 lines of research,
strategy, architecture and design. The catalog and resolver are built and tested.

---

## The bet, in three lines

1. **AnyList** (14 years, 4.9★, ~$900k/yr) and **OurGroceries** (84K ratings) have **no prices at
   all.** MinimaList — a to-do app — proves people want them.
2. Receipts build a **personal price book**, which makes cross-store comparison possible from
   *your* data instead of stale crowdsourced feeds.
3. That price book compounds. It's the only thing here a competitor can't copy by shipping a
   feature.

⚠️ **This bet is unvalidated.** See `VALIDATION.md` — ten conversations, ~8 hours, before six
months of building.

## Read in this order

| | Doc | What it answers |
|---|---|---|
| **1** | **`DECISIONS.md`** | **Everything decided, on one page. Start here** |
| 2 | `CAPABILITIES.md` | Every feature as a flat list |
| 3 | `PLAN.md` | Plan of record — strategy, pricing, GTM, risks |
| 4 | `ARCHITECTURE.md` | The pattern, concurrency, and every file the app will have |
| 5 | `FILES.md` | Visual map of the repo and the planned app |

### Reference

**Product** — `FEATURES.md` (the five core features · the on-device AI ladder) ·
`PRICE-INTELLIGENCE.md` (the price book and store comparison) · `RESEARCH.md` (data model) ·
`MARKET.md` (sizing and unit economics)

**Build** — `STACK.md` (Swift 6, three dependencies) · `ENGINEERING.md` (method per feature, app
size) · `SOURCING.md` (catalog IP and imagery licensing) · `OPS.md` (services, accounts, release
path)

**Design** — `INTERACTION.md` (ADHD-informed motion, haptics, sound) · `BRAND.md` ·
`NAMING.md` · `docs/DIRECTION_RECOMMENDATION.md` (which of the 16 to ship) ·
`docs/FIGMA_FILE_MAP.md`

**Competitive** — `research/competitors.md` · `research/store-teardown.md` ·
`research/tiimo-teardown.md` (the iPhone App of the Year 2025)

## What's decided

- **iOS native, Swift 6 + SwiftUI, minimum iOS 18. No Android.** Not a second native app either —
  if both platforms ever become required, the answer is React Native
- **Three dependencies:** GRDB, RevenueCat, supabase-swift. Everything else is a system framework
- **Local SQLite is the source of truth.** Op-log sync, last-write-wins per field, **not a CRDT** —
  a shopping list is a set, not a sequence
- **Prices are observations** on *(item, store, date)*, never a column on the item
- **Model–View with three `@Observable` stores**, not MVVM per screen
- **$2.99/mo · $29.99/yr · 7-day trial.** No ads, no lifetime tier, people you invite are free forever
- **Design direction F · Hybrid**, taking one organ each from A (receipt typography), K (density +
  unit price), L (shop mode), P (Δ vs your usual)
- **22 of 24 features never touch the cloud.** Claude does exactly two things — receipts and
  handwriting — at ~$0.22–1.08 per subscriber per year. **No recipes**

## Two rules everything else serves

> **1. Estimated prices and real prices must never be confusable.**
> `~` prefix *and* lighter weight *and* muted colour. Totals built from estimates carry `≈`.
> Estimates round hard — `~$4.50`, never `$4.37`. **The honesty of the number is the brand.**

> **2. No streaks, badges, or guilt mechanics. Ever.**
> The variable-reward loops that make apps "engaging" are the ones ADHD brains are most vulnerable
> to. An app that treats attention as the user's is something an ad-funded competitor structurally
> cannot copy.

## What's built

```
data/catalog/     414 items · 859 lookup terms · 22 categories · 8 price regions · 200 KB
                  build.mjs validates + compiles to SQLite
                  resolve.mjs — the query resolver, 23 passing tests
design/concepts/  6 directions as self-contained HTML + rendered PNGs
Figma             16 directions across two files — see docs/FIGMA_FILE_MAP.md
```

## Next, in order

1. **Ten conversations** (`VALIDATION.md`) — the cost wedge is the whole strategy and it's untested
2. **Paid Applications Agreement** + banking/tax — longest lead time, zero work, and in-app
   purchases don't function until it clears
3. **Buy `bagged.app`** and the handles, then the Class 9/42 trademark search
4. **Build `Core` + `Catalog`** — port the resolver, write the op-log conflict harness. **No Xcode
   signing, no simulator, no Apple approvals. Can start today**
5. **RLS policies**, tested with two accounts, before any UI exists

## ⚠️ Known issues

- **`.claude/skills/otto-lead/` targets a different app.** It says *"you are the design+build lead
  for Otto (Expo RN recipe app, this repo)"* — false here, and it references a TypeScript/Expo
  stack we decided against. `engine-porter`, `verifier` and `ui-systems` assume the same. Retarget
  or remove before anyone invokes them
- **Two Figma files** hold overlapping A→P work and neither is a superset. Declare one canonical
- **`instances: 0`** in both Figma files — the components exist and nothing references them
- **F has never been seen at 40 items.** Every density judgement is inference from a 7-item mockup
