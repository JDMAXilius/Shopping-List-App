# TERMINAL_TICKET_FIGMA_CONCEPTS

**Port six existing visual directions into Figma, then design five new ones — all on one page.**

Read first: **`docs/DESIGN_HANDOFF.md`** (~10 min). It has the tokens, the fixed sample data, the
screen inventory, the hard constraints, and what the competition looks like. Everything below
assumes it.

**Tooling:** Figma MCP. Load the `/figma-use` skill before calling `use_figma` — it's mandatory.
You already know the file and page conventions for this project; keep everything on **one page**.

---

## Inputs — already in the repo, nothing to generate

| Direction | Screenshot | Source |
|---|---|---|
| A · Ledger | `design/concepts/a-ledger.png` | `a-ledger.html` |
| B · Stall | `design/concepts/b-stall.png` | `b-stall.html` |
| C · Standard | `design/concepts/c-standard.png` | `c-standard.html` |
| D · Bento | `design/concepts/d-bento.png` | `d-bento.html` |
| E · Halo | `design/concepts/e-halo.png` | `e-halo.html` |
| **F · Hybrid** ⭐ | `design/concepts/f-hybrid.png` | `f-hybrid.html` |

Each PNG is a sheet of **5 phone frames at 393×852**, rendered @2x. The HTML is self-contained —
open it to read exact hex values, spacing and type sizes rather than eyedropping the PNG.

Written analysis: `design/concepts/README.md` — has a "why it might be right / why it might be
wrong" for each.

---

## Part 1 — Port A–F into Figma

**Rebuild, don't paste.** Screenshots pinned to a canvas are worthless; these need to be editable
Figma frames.

- One **section per direction**, labelled `A · Ledger` … `F · Hybrid`, laid left to right in
  that order
- Inside each section, the frames it already has, at **393 × 852**, named
  `A/01 List`, `A/02 Add`, `A/03 Aisles`, `A/04 Household`, `A/05 Spend` etc.
- **Auto Layout on rows, groups and cards.** A list row must survive a longer item name
- **Local styles / variables for F only** (it's the chosen direction) — colour, type, spacing,
  radius, from `DESIGN_HANDOFF.md` §6. A–E can be raw
- **Components for F's repeated parts**: list row (with estimated / observed / unpriced / checked
  variants), aisle header, total bar, the input bar, the bottom nav pill
- **F gets a dark-mode duplicate** of `F/01 List` and `F/06 Spend`. A–E don't need one

## Part 2 — Five new directions, G–K

Same page, continuing left to right after F. **Minimum four frames each**: List, Add/input,
Aisles, Spend. Same sample data (`DESIGN_HANDOFF.md` §5) so they compare honestly.

### The brief

Five directions that are **genuinely different from A–F and from the competition** — not
recolours. Each needs:

1. A **different navigation model** from every other direction. Already used: bottom tear-strip
   (A), top rail + FAB (B), left vertical rail (C), split dock + orbital shortcuts (D), floating
   glass pill (E), bottom pill + one input bar (F). **Find six more between you.**
2. **One structural idea**, stated in a sentence, that the whole direction serves.
3. **A different answer to "where do prices live"** — that's the product's whole point, and it's
   the most interesting variable. Inline right-aligned (A, F), inside a tile (D), as a display
   figure (C) are taken.

### Candidate territories — pick five, or better ones

Unexplored after A–F:

- **Physical / tactile** — index cards, fridge magnets, string-tied paper tags, a cork board
- **Photographic** — real product photography as the primary visual. ⚠️ This one is genuinely
  useful to see: it's an open product decision (`SOURCING.md`) and a mockup would settle it
- **Data-first** — the *spend* is the primary object and the list is a view onto it; charts, not rows
- **Extreme minimal** — no chrome at all, one column, huge type, text-only, gestures for everything
- **High-density / pro** — spreadsheet-like, 25 items visible at once, for the big weekly shop
- **Neo-brutalist warm** — thick black borders, hard offset shadows, saturated blocks
- **Card deck / gesture-first** — one item at a time, swipe to check, built for the aisle
- **Per-store identity** — the whole UI takes on a colour identity per store you're shopping

**Do not** produce: a serif-display warm-paper direction (that's Tiimo's, see `DESIGN_HANDOFF.md`
§8), or anything that reads as a to-do app.

### Non-negotiables in all five

- Estimated vs observed vs unpriced must be distinguishable **by prefix, weight and colour**,
  never colour alone (`DESIGN_HANDOFF.md` §2)
- Totals built from estimates carry `≈`
- One item on the list has **no price** — show how the direction handles that gracefully
- Long item names truncate without pushing the price off-screen
- No streaks, badges or guilt mechanics

## Part 3 — A comparison frame

One wide frame at the end of the page, `00 · Compare`, holding **every direction's List screen
side by side at 50%**, labelled. That's the frame the decision actually gets made from.

---

## Done when

- [x] `docs/DESIGN_HANDOFF.md` read
- [x] A–F rebuilt as editable Figma frames, one section each, correctly named
- [x] Auto Layout on every list row, card and group
- [x] F has local styles/variables and components with the four row variants
- [x] F has a dark-mode duplicate of List and Spend
- [x] G–K designed — five new directions, ≥4 frames each, five distinct navigation models
- [x] Each of G–K has its one-sentence structural idea written in a text layer above its section
- [x] All of it on **one page**, ordered A → K left to right
- [x] `00 · Compare` frame built
- [x] A `## Log` entry below with: anything from A–F that didn't survive contact with Figma
- [x] Figma file link added to the Log
- [x] Pushed to `main`

## Notes

- **The fixed sample data is not decoration.** Directions that use different content can't be
  compared, and comparison is the entire purpose of this ticket.
- **F is the current favourite, not a decision.** If one of G–K beats it, say so plainly in the
  Log — that's a useful outcome, not a problem.
- Anything genuinely blocked (a font we don't have, a Figma limit) → leave the box unchecked and
  write the blocker in the Log. Blocked ≠ done.

## Log

### 2026-07-26 — Part 1 done, Part 2 and 3 outstanding

**File:** https://www.figma.com/design/joF6lVqRiHaWqc9v5q4kLg — page `Concepts A–K`, one page, left to right.

**Built:** six sections `A · Ledger` → `F · Hybrid ⭐ (chosen)`, 30 frames at 393×852, named
`A/01 List` … `F/05 Spend`. Rows, cards, crates, tiles and groups are Auto Layout throughout, so a
longer item name reflows rather than pushing the price off-screen.

**F's system**, in `F · Components & tokens` below the F section:
- Variable collection `F · Tokens` with **Light and Dark modes** — 14 colour variables (paper, card,
  ink, muted, line, persimmon, confirmed, unpriced + six aisle tints) and 6 float variables
  (radius, spacing).
- 7 text styles: `F/Display`, `F/Item name`, `F/Meta`, `F/Section label`,
  `F/Price · observed`, `F/Price · estimated`, `F/Total`.
- 5 components: **`F/List row` with the four variants** `State=Estimated | Observed | Unpriced |
  Checked`, plus `F/Aisle header`, `F/Total bar`, `F/Input bar`, `F/Bottom nav pill`.
- Dark duplicates `F/01 List — dark` and `F/05 Spend — dark`.

### What didn't survive contact with Figma

1. **Emoji tiles are not usable.** `🍌`-style tiles are load-bearing in D and F. Figma renders them
   through `Noto Color Emoji`, and new emoji text nodes rasterise **blank** — verified across five
   isolation tests (plain frame, auto-layout child, fills cleared, one glyph per node). One early
   batch rendered; nothing created afterwards did. Replaced with a **purpose-built monoline SVG icon
   set** (banana, leaf, avocado, milk, egg, jar, bottle, bread, cheese, meat, frozen, roll, coffee,
   butter, apple, store, pin…) drawn on a 24×24 grid and recoloured per direction. This is arguably
   the better answer anyway — `SOURCING.md` §2 argues for generating to one specification rather than
   sourcing 414 mismatched photos — but it is a **deviation from the HTML** and should be a
   deliberate decision, not one inherited from a tooling limit.
2. **Two fonts aren't in Figma.** B specifies Avenir Next, D specifies SF Pro Rounded. Both fall back
   to **Inter**. B loses a little of its hand-lettered warmth; D loses the roundness that carries a
   lot of its friendliness. If D or B advance, the type has to be re-picked from what actually ships.
3. ~~**A's perforated edges are only half there.**~~ **Fixed.** `layoutPositioning` has to be set
   *before* `x`/`y` or auto-layout overwrites the position. A now has proper thermal-paper scallops
   top and bottom on all five frames.
4. **E's glass is an approximation.** `backdrop-filter: blur(30px)` maps to Figma `BACKGROUND_BLUR`
   plus a 7.5% white fill and a 0.5px 15% white stroke; the aurora is three `LAYER_BLUR` ellipses.
   It reads correctly, but E's real accessibility question — contrast of muted text on live
   translucency — **cannot be judged from this mockup**. It needs a device build.
5. **C's vertical rail** uses rotated text nodes; Figma has no vertical writing mode. Visually
   identical, but the labels are rotated objects rather than text flow, which will matter if anyone
   tries to make the rail responsive.
6. **Default frame fills bite.** `createAutoLayout` returns an opaque white frame, so every unstyled
   layout wrapper paints white. Caught it on the dark directions where it was visible; worth knowing
   for anyone extending this file.

### Part 2 — the five new directions, and why these five

Each is 4 frames (List · Add · Aisles · Spend), same fixed sample data, one unpriced item handled
explicitly, and its one-line structural idea set above the section.

| | Name | Navigation (all new) | Where the price lives | Territory |
|---|---|---|---|---|
| **G** | **Index** | Card-box **divider tabs** — the active tab is pulled forward | A **stamped paper tag**, rotated, at the card edge | Physical / tactile |
| **H** | **Larder** | **Draggable bottom sheet** with a handle; nav in the sheet header | A **chip laid over the photograph** | Photographic |
| **I** | **Meter** | **Time scrubber** across the top — the scale you pick is the view | **The row *is* the price** — bar length is cost | Data-first |
| **J** | **Aisle** | **Edge-pull tab** on the right rim; nothing in the thumb zone | A **full-bleed band** across the foot of the card | Card deck / gesture |
| **K** | **Slab** | **The title is the dropdown**, plus a right-edge aisle index | A **real table column** with unit price beneath | High-density / pro |

Chosen to attack the parts A–F left alone. **H exists to settle an open product decision** —
`SOURCING.md` and the AnyList teardown both leave "emoji or real photography" unresolved, and it is
much easier to judge from a mockup than an argument. **I is the only direction where the cost wedge
is the interface** rather than a column in it. **K is the only one that admits a 40-item shop is a
spreadsheet** — every other direction here, including F, gets thin above ~15 items. **J is the only
one designed for the hand that is actually pushing a trolley.** **G is the tactile hedge**: it is the
furthest from software convention and the most likely to be remembered.

Deliberately avoided: a serif-display warm-paper direction (Tiimo owns it), and anything that reads
as a to-do app.

### Part 3 — `00 · Compare`

One frame at the end of the page holding **all eleven List screens at 50%**, each labelled with its
navigation model and its price treatment. Eleven navigation models, eleven answers to "where does the
price live", none a recolour of another.

### Recommendation

**F still wins, but it now has a real challenger in K, and H should be built as a test rather than a
direction.**

- **F remains the pick.** It is the only one that survived Auto Layout, dark mode, a token system and
  a component set without a structural change. That is not a small thing — it means it is buildable.
- **K · Slab is the one to take seriously against it.** Put F and K side by side in `00 · Compare` and
  F visibly runs out of room: seven items fill the screen. K shows eleven with unit prices and still
  has a total bar. The weekly shop the app is *for* is 30–40 items, and F has not been tested at that
  size. The cheapest resolution is a **density variant of F**, not a new direction.
- **H should be run as an experiment, not a candidate.** Its value is answering the photography
  question. The mockup already shows the cost: two items per row instead of seven, so photography buys
  recognition and spends the density that K proves matters. That is a real trade, and it is now
  visible rather than argued.
- **I is the most interesting and the least safe.** Encoding price as bar length is genuinely the
  strongest expression of the wedge, but it makes the list harder to skim as a *list*, and `PLAN.md` §7
  puts add-item speed at ≤2s. Worth stealing the bar treatment for the Spend screen; not worth
  adopting wholesale.
- **G and J are honourable no's.** G is memorable and completely impractical to maintain as it grows;
  J is right for the aisle and wrong for the sofa, and the same app has to do both.

---

### 2026-07-26 (later) — round three, L–P, beyond the ticket

Asked for after the ticket closed: five more, researched against Mobbin rather than invented.

| | Name | Navigation | Where the price lives | Mobbin reference |
|---|---|---|---|---|
| **L** | **Route** | **Route ribbon** of stop pips you tap to jump | **Accrues along the walk**; each item shows what it adds | Apple Maps' add-a-stop sheet ("adds 5 min"), Slopes, Placify |
| **M** | **Board** | **Board name as switcher**, columns page sideways | **Column footer subtotal** — cost belongs to the aisle | Trello, Asana, Notion board views |
| **N** | **Thread** | **Thread chips** across the top | **A running receipt message** that rewrites itself | inDrive, Gojek quick-chat, Beside, Truecaller |
| **O** | **Dial** | **The ring itself** — tap a segment, no bar at all | **The centre of the ring**, one focused number at a time | Zero, Streaks, Tiimo focus, stoic. |
| **P** | **Ticker** | **Ticker tape** along the foot | **Price + Δ against your own average**, with a sparkline | market/finance boards; Strava's stat rows |

Two of these are more than styling exercises:

- **L · Route** is the only direction that makes `PRICE-INTELLIGENCE.md`'s hardest idea legible —
  *pricing the extra stop*. Apple Maps already teaches the pattern with "adds 5 min", and L reuses it
  for "saves $6.20, adds 24 min and a second stop". That framing is worth stealing into **F**
  regardless of whether L ever ships.
- **P · Ticker** is the only direction that treats **grocery inflation as the story**. Δ-against-your-
  own-average is a genuinely different claim from a raw price, it is only possible once the price book
  exists, and no competitor can copy it without the same history. Also worth stealing into F's Spend
  screen.

**N · Thread** is the most interesting failure. A household list *is* a conversation, and the thread
handles attribution and the assistant with no new surface — but a chat log is a poor place to scan
seven things in an aisle, and scrolling back to find an item is worse than any list here.

**M** and **O** are no's. M's columns hide the total the app exists to show, and O looks superb at
seven items and collapses at forty.

**Nothing here displaces F.** The recommendation stands: ship F, steal L's cost-of-detour framing and
P's Δ-vs-your-average, and test F at 40 items against K's density.

Same file, now **sixteen sections A → P, 74 frames**, `00 · Compare` rebuilt to hold all sixteen List
screens at 50%. Page normalised — 40px gutters, 120px section gaps, every frame at the same y.
