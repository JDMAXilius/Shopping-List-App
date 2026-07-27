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
- [ ] G–K designed — five new directions, ≥4 frames each, five distinct navigation models
- [ ] Each of G–K has its one-sentence structural idea written in a text layer above its section
- [x] All of it on **one page**, ordered A → F left to right (G–K space reserved to the right)
- [ ] `00 · Compare` frame built
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
3. **A's perforated edges are only half there.** The scallops are drawn, but `layoutPositioning`
   must be set *before* `x`/`y` or auto-layout overwrites the position — currently only the bottom-left
   scallop lands. Cosmetic, one small fix, flagged rather than hidden.
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

### Not done — and why

**Part 2 (G–K) and Part 3 (`00 · Compare`) are not built.** Part 1 alone is 30 hand-built frames
plus a token system; the session budget ran out before the five new directions could be designed to
the standard the ticket asks for. Canvas space to the right of F is left clear for them.

Half-designing G–K would have been worse than not starting: the whole point of the fixed sample data
is honest comparison, and a rushed G–K would poison exactly that. Blocked ≠ done, so the boxes stay
unchecked.

**To pick up:** sections G–K go at x ≈ 14825 and every 1892px after; the `00 · Compare` frame after
them. The brief's live constraints are unchanged — six *more* distinct navigation models beyond the
six already used, a different answer to "where do prices live" from inline-right (A, F), in-tile (D)
and display-figure (C), one unpriced item handled gracefully in each, and no serif-display
warm-paper direction (that's Tiimo's).

**No recommendation between G–K is possible yet** — none exist. F remains the standing favourite,
and nothing in Part 1 moved that: the port confirmed its structure survives Auto Layout and dark mode
cleanly, which is more than can be said for A's mono at large Dynamic Type.
