# Figma file map

> ⚠️ **There are two files with overlapping A→P work.** Neither is a superset of the other.
>
> | | `joF6lVqRiHaWqc9v5q4kLg` · `Concepts A–K` | `Lpx5Pdgvy3Gx8l5ZSDS0JH` · `5 Directions` |
> |---|---|---|
> | Organisation | **18 proper Sections** | 174 loose frames, no sections |
> | Content | Round 3 only (A→P) | **Three rounds** (R1, R2, R3 A→P) |
> | Nodes | 4,128 frames | 7,236 frames |
> | Components / instances | 8 / **0** | 8 / **0** |
>
> **Declare one canonical and port the rest.** This document maps the second one — the one that
> was shared — because it holds Rounds 1 and 2, which exist nowhere else.

> ⚠️ **The shared file now has TWO pages.** `get_metadata` with no nodeId still lists only
> `0:1 · 5 Directions` — that listing is stale. The second page is `74:16 · Bagged · Screens`
> and it is **the real app spec**, not concept exploration. Mapped in the next section.

---

## `Lpx5Pdgvy3Gx8l5ZSDS0JH` · page `74:16` · **Bagged · Screens** — the app spec

**59 screens at 390×844, in nine lettered flows. 991 frames · 846 text · 323 instances across
119 components.**

> **The instances number is the headline.** The concepts page has **0**. This page is built on a
> real component system — `SectionHeader` ×47, `ToggleRow` ×31, `StoreAvatar` ×30, `ItemMark` ×26,
> `NavBar` ×15, `CaptureButton` ×15, `SourceTag` ×11, plus `StatTile`, `HeroNumberCard`,
> `TreemapTile`, `ShelfRow`, `ListRow`, `FactRow`. **This is the file to build from.**

| Flow | Screens |
|---|---|
| **A · Onboarding** | Splash · Value showcase · Name your kitchen · Add your first shop · First fill · Sign in / restore |
| **B · Shelf** | Shelf · Item detail · Add by hand · Edit item · **Eat me first** · Locations editor · Shelf empty |
| **C · Capture** | Capture sheet · Receipt camera · Receipt review · **Unmatched line resolver** · Barcode scanner · Enter by hand · Capture result |
| **D · List** | List · Item row detail · Add item · Aisle order editor · Shop switcher · **Cheaper elsewhere** · Empty / all done |
| **E · Prices** | Prices · Item price history · Trips · Month / spend · Trip detail · Category detail · **Store comparison** |
| **F · Kitchen** | Invite · Kitchen home · Member detail · Guest view |
| **G · Surfaces** | Lock screen · Places · Add/edit a shop · **Home screen widgets · Watch app · Siri & Shortcuts · CarPlay · Live Activity** |
| **H · Settings** | Setup · **Bagged Plus paywall** · Voice settings · Notifications · Data & privacy · About |
| **I · States** | Generic empty · Offline · Scan failed · Processing a receipt · Permission primers ×3 |

### What it got right, and it's a real advance on F

- **`NO PRICE YET` is promoted to the top of the list**, with *"tap to set what you paid"* on each
  row. That inverts the problem: unpriced items become **the action**, not an afterthought. It is
  the data-collection loop turned into the primary UI, and it's better than anything in A–P
- Finished aisles collapse to `✓ PRODUCE · done (2) · ≈ $11.40`
- `C4 · Unmatched line resolver` addresses the receipt-OCR risk in `PRICE-INTELLIGENCE.md` §7
- `D6 · Cheaper elsewhere` and `E7 · Store comparison` implement §4.3–4.4
- **Nine permission/empty/failure states designed** — the work nobody does and everybody needs

### New vocabulary, not yet in any doc

| Screen says | Our docs say |
|---|---|
| **kitchen** (*"Name your kitchen"*, *"Kitchen home"*) | household |
| **shelf** | pantry |
| **guessed** (*"3 estimated · 1 guessed"*) | *(no such tier)* — we have estimated / observed / unpriced |
| **Bagged Plus** | *(paywall unnamed)* |
| **glance** (*"The glance stays free"*) | *(new)* |

**`guessed` is a genuine addition** — a fourth confidence tier below `estimated`. Worth adopting
or rejecting deliberately, because `DESIGN_HANDOFF.md` §2 defines exactly three.

### ⚠️ Three divergences from the plan of record

**1. The Shelf is the first tab.** Bottom nav is **Shelf · List · Prices · You**, and Shelf is
leftmost — the primary position. `CAPABILITIES.md` puts pantry at **v2, "only if retention
holds"**, and `PLAN.md` §3 lists it under *"optional, only if retention holds."*

`B1` shows *"62 things in · 4 running low · 2 to eat soon"* with per-item freshness
(`plenty`, `eat in 2d`, `~3 days`, `ripe now`) across FRIDGE / PRODUCE locations.

That is **a different product with a different job** — inventory management, not list-making. It
needs the user to log what they have *and* what they consume, and it needs shelf-life data we
don't have. It also puts us against NoWaste, Pantry Check and KitchenPal rather than AnyList and
OurGroceries. **Not wrong — but it is a strategy change, and it should be made on purpose.**

**2. The paywall is annual-only.** `$29.99/year · 7 days free · "about $2.50 a month"`. **No
monthly tier**, where `PLAN.md` §4 decided `$2.99/mo` *and* `$29.99/yr`.

**3. What's gated cuts across two of our own arguments.** Plus unlocks:
receipt scanning · price history · **more than one shop** · **Watch, Siri and CarPlay**.

- **"More than one shop" gates the price comparison entirely** — comparison needs ≥2 stores
  (`PRICE-INTELLIGENCE.md` §3). So the free tier can never see the differentiator, and free
  reduces to a list app with estimates. Defensible as monetisation; it just needs to be a
  decision rather than a side effect
- **Gating Siri contradicts `FEATURES.md` §10.** The whole cost architecture is *"free tier →
  on-device only"* — and Siri **is** on-device and free to run. Gating it saves nothing and
  removes the stickiest free feature. If the goal is a monetisation lever, gate Watch and CarPlay
  and leave Siri free

### Node reference — Screens page

| What | Node |
|---|---|
| Page | `74:16` |
| D1 List | `76:269` |
| B1 Shelf | `76:7` |
| H2 Bagged Plus paywall | `76:95` |
| E7 Store comparison | `81:837` |
| C4 Unmatched line resolver | `76:282` |

---

## `Lpx5Pdgvy3Gx8l5ZSDS0JH` · page `0:1` · `5 Directions` — the concept explorations

**File:** one page, `5 Directions` (`0:1`). Account: Juan Diego Lugo, pro tier.
**Scale:** 174 top-level frames · 7,236 frames · 5,368 text nodes · 8 components · **0 instances**.

Read in three horizontal bands stacked vertically. **Three complete rounds of work exist**, from
different sessions and with different design philosophies. They have not been reconciled with each
other.

---

## Round 1 — `y 0 … 4,844` · five directions, seven screens each

> *"Bagged — five visual directions · 7 screens each · List · Add · Item & price · Prices ·
> Stores · Household · Settings"*

`A · RECEIPT` · `B · LEDGER` · `C · MARKET` · `D · QUIET` · `E · AISLE` — 35 frames at **390×844**.

**The most complete IA of the three rounds** — it's the only one with a Settings screen and a
dedicated `Item & price` detail screen for every direction.

**What it looks like:** paper ground, letter-spaced `B A G G E D` wordmark, dotted rules,
uppercase aisle headers with subtotals right-aligned, `≈ $84.50` total over
`12 ITEMS · 3 CHECKED / 4 observed · 8 estimated`. The honesty rule is already fully implemented —
`~$3.00` light for estimates, `$4.49` solid for observed.

> **Finding worth carrying forward: it uses custom line-icon glyphs, not emoji and not photos.**
> That's a **third answer to the imagery question** in `SOURCING.md`, and nobody had proposed it.
> Line icons are legally clean, weigh nothing, scale to any Dynamic Type size, and give a
> coherent visual system without 414 photographs. **Add it to the options before that decision is
> made.**

## Round 2 — `y 5,300 … 10,244` · five *products*, not five skins

> *"Round 2 — five different products, not five skins. Different information architecture,
> different bottom-bar menus, different features."*

| | Direction | Screens |
|---|---|---|
| **F** | `CART MODE` | Plan · Shop mode · Aisle walk · Trips · Add · Me |
| **G** | `SHELF` | Shelf · Shelf item · List · Cook · Restock scan · Me |
| **H** | `RECEIPT` | Scan · Review receipt · Prices · Store compare · List · Item history |
| **I** | `TOGETHER` | Household · List · Asks · Split · Member · Invite |
| **J** | `GLANCE` | Now · Hands-free · Lock screen · Other surfaces · Places · Setup |

Visually a different lineage from Round 1 — iOS-standard, SF Pro, **teal** accent, card stacks.

> **⚠️ `H · RECEIPT` is the entire price-intelligence product, and it predates
> `PRICE-INTELLIGENCE.md`.** Its `Store compare` screen reads *"Where this basket is cheapest —
> your 8 staples, priced from your own receipts"*, ranks Trader Joe's / Safeway / Costco with
> `+$4.17` deltas, and has a `WHERE THE GAP IS` section showing per-item differences. Two sessions
> arrived at the same product independently.
>
> **One genuine difference to reconcile:** it uses **receipt count** ("12 receipts", "3 receipts ·
> bulk sizes") as the confidence signal. `PRICE-INTELLIGENCE.md` §4.2 uses **coverage** ("15 of 18
> priced"). **Receipt count answers "how much do I trust this store's data"; coverage answers "how
> much of this basket is actually priced".** They're different questions and the screen probably
> needs both.

## Round 3 — `y 10,604 … 27,670` · the A→P set *(this is our ticket, executed)*

> *"Round 3 — the A→P concept set. Sixteen…"*

**Delivered beyond the brief.** `TERMINAL_TICKET_FIGMA_CONCEPTS.md` asked for A–F ported plus five
new. It produced **sixteen** directions at the correct **393×852**, each with a distinct navigation
model *and* a distinct answer to where the price lives:

| | Direction | Navigation | Where the price lives |
|---|---|---|---|
| A | Ledger | bottom tear-strip | inline · dotted leader |
| B | Stall | top rail + FAB | inline right |
| C | Standard | left vertical rail | display figure |
| D | Bento | split dock + orbitals | inside the tile |
| E | Halo | floating glass pill | inline right |
| **F** | **Hybrid ⭐** | bottom pill + one bar | inline · dotted leader |
| G | Index | card-box divider tabs | stamped paper tag |
| H | Larder | draggable bottom sheet | chip over the photo |
| I | Meter | the row **is** the bar | line scrubber |
| J | Aisle | edge pull tabs | floating band |
| K | Slab | tile dropdown + index | table column + unit price |
| L | Route | node ribbon of stops | accrues along the walk |
| M | Board | board name + paging columns | column footer subtotal |
| N | Thread | thread chips | a receipt message |
| O | Dial | the ring itself | centre of the ring |
| P | Ticker | ticker tape | Δ vs your usual |

Plus: `F/01 List — dark` and `F/05 Spend — dark`, and a **`00 · Compare`** frame (3516×676)
holding all sixteen List screens at 50% with their nav model and price treatment labelled.

**`H · Larder` puts the price as a chip over a photograph** — that's the photographic direction the
ticket asked for, and it's the mockup that should settle the imagery question.

---

## Two real gaps

**1. ⚠️ `instances: 0`. The components exist but nothing uses them.**

Eight components are built — `State=Estimated` / `Observed` / `Unpriced` / `Checked` (a proper
variant set, and the four states are correct), plus `F/Aisle header`, `F/Total bar`,
`F/Input bar`, `F/Bottom nav pill`. **Every one of the 96 screens is drawn from raw frames and
text instead.** Editing a component changes nothing on the canvas.

Either wire F's screens to instances, or delete the set — **an unused component library is a
false claim about the file's state**, and the next person will trust it.

**2. ⚠️ Nothing on either canvas is bound to a variable.**

The section header reads *"plus the light/dark variable collection"*, and the ticket log describes
it in detail — 14 colour variables, light and dark modes. **It may well exist as a collection.**
But `get_variable_defs` returns `{}` on `F/01 List` and `F/01 List — dark` here, *and* on
`F/01 List` in the sectioned file. Four nodes, two files, nothing bound.

Functionally that's the same problem as having none: the frames carry raw hex, so switching modes
moves nothing.

**Not verifiable from here:** Auto Layout. `get_metadata` doesn't expose layout mode, so the
ticket's *"Auto Layout on every list row, card and group"* box can't be confirmed or denied
remotely — it needs someone with the file open.

---

## What to do with this

1. **Decide from `00 · Compare` (`37:7339`)** — that's the frame built for it, and it works.
2. **Reconcile the two price-comparison designs** — Round 2 `H4 · Store compare` (`23:309`) vs
   Round 3 `F/03 Where to shop` (`37:2813`). Take receipt-count *and* coverage.
3. **Add line-icon glyphs to the imagery options** in `SOURCING.md`, alongside emoji, licensed
   photos and generated photos. Round 1 shows it works.
4. **Fix or remove the component set and the variable claim** before anyone builds on this file.
5. **Round 1's Settings and Item-detail screens are the only ones that exist** — whichever
   direction wins will need those two screens designed, and Round 1 is the reference.

## Node reference

| What | Node |
|---|---|
| Page | `0:1` |
| `00 · Compare` | `37:7339` |
| Round 3 · F/01 List | `37:2551` · dark `37:3111` |
| Round 3 · F/03 Where to shop | `37:2813` |
| Round 3 · H/01 List (photographic) | `37:3692` |
| Round 2 · H4 Store compare | `23:309` |
| Round 1 · A1 List | `10:2` |
| Components | `37:9319`–`37:9389` |

---

## `Lpx5Pdgvy3Gx8l5ZSDS0JH` · page `138:978` · **Bagged · Screens app current** — the v1 build *(2026-08-12)*

**The settled v1, built.** 31 frames at 393×852 in nine sections: `F · Components` +
Onboarding · List · Capture · Prices · Kitchen · Places · You · Widget. All 28 surfaces from
`V1_SCOPE.md` plus `01b List · full` (40 items) and dark duplicates of 01 and 10.
Three-tab nav (`List · Prices · You` + persimmon `+`), F · Hybrid system, no Shelf anywhere.

**Both gaps flagged above are fixed on this page:**

1. **Instances: 187** — every screen is composed from the `F/List row` variant set (`146:1331`),
   `F/Aisle header` (`147:10`), `F/Total bar` (`147:19`), `F/Input bar` (`147:1313`),
   `F/Tab bar` (`147:1325`) and 12 `F/Icon/*` components.
2. **Variables bound and mode-proven** — new collection `F · Tokens`
   (`VariableCollectionId:144:2`), 17 colours × light (`144:0`) / dark (`144:1`).
   `01 List — dark` (`162:834`) and `10 Month / spend — dark` (`155:2149`) are clones driven by
   `setExplicitVariableModeForCollection`, not repaints.

Note: `74:16` still binds to the older light-only `Bagged color` collection — the two
collections coexist deliberately; do not migrate `74:16`.

Full build + QA log: `docs/TERMINAL_TICKET_V1_SCREENS.md`. Handoff summary:
`docs/TICKET_SESSION_HANDOFF.md`.
