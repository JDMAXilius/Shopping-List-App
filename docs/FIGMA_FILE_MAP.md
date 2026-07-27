# Figma file map — `Lpx5Pdgvy3Gx8l5ZSDS0JH`

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

**2. ⚠️ No variables, despite the label saying otherwise.**

The section header reads *"plus the light/dark variable collection"*. `get_variable_defs` returns
`{}` on `F/01 List` **and** on `F/01 List — dark`. Colours are raw hex throughout. Either build the
collection or correct the label.

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
