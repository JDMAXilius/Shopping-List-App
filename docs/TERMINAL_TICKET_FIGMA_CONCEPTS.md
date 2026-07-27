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

- [ ] `docs/DESIGN_HANDOFF.md` read
- [ ] A–F rebuilt as editable Figma frames, one section each, correctly named
- [ ] Auto Layout on every list row, card and group
- [ ] F has local styles/variables and components with the four row variants
- [ ] F has a dark-mode duplicate of List and Spend
- [ ] G–K designed — five new directions, ≥4 frames each, five distinct navigation models
- [ ] Each of G–K has its one-sentence structural idea written in a text layer above its section
- [ ] All of it on **one page**, ordered A → K left to right
- [ ] `00 · Compare` frame built
- [ ] A `## Log` entry below with: the five directions chosen and why, anything from A–F that
      didn't survive contact with Figma, and a recommendation between G–K
- [ ] Figma file link added to the Log
- [ ] Pushed to `main`

## Notes

- **The fixed sample data is not decoration.** Directions that use different content can't be
  compared, and comparison is the entire purpose of this ticket.
- **F is the current favourite, not a decision.** If one of G–K beats it, say so plainly in the
  Log — that's a useful outcome, not a problem.
- Anything genuinely blocked (a font we don't have, a Figma limit) → leave the box unchecked and
  write the blocker in the Log. Blocked ≠ done.

## Log

<!-- append dated entries here -->
