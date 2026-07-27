# Design handoff — grocery list app

**Read time: ~10 minutes.** Everything needed to rebuild these directions in Figma and to invent
five more that don't collide with them.

Companion ticket: `docs/TERMINAL_TICKET_FIGMA_CONCEPTS.md`

---

## 1. What the app is, in five lines

- A **shared household grocery list** for iOS. Native Swift/SwiftUI. iOS 18+.
- The differentiator is **cost**: every item carries a price, aisles carry subtotals, the trip
  carries a total. **No competitor in the grocery category does this** — AnyList (14 years, 4.9★)
  and OurGroceries (84K ratings) both have no prices at all.
- Second differentiator: **aisle order** — the list is sorted to match your walk through *your*
  store.
- It works **fully offline** — supermarkets have no signal.
- Later: **receipt scanning builds a personal price book**, which enables cross-store comparison
  (`PRICE-INTELLIGENCE.md`).

## 2. The one rule the visual design must serve

> **Estimated prices and real prices must never be confusable.**

Three signals, always all three, never colour alone:

| | Estimated | Observed (from a receipt) | Not priced |
|---|---|---|---|
| Prefix | `~` | none | `—` |
| Weight | lighter | solid/bold | lighter |
| Colour | muted | full ink | faintest |

Totals built from any estimate carry **`≈`**. Estimates round hard: `$0.50` under $10, `$1` above
— never `$4.37`, always `~$4.50`. **The honesty of the number is the brand.** A design that makes
a guess look like a fact has failed no matter how it looks.

## 3. Hard constraints

- **393 × 852** (iPhone 16/17 Pro). All artboards this size.
- **Dark mode required** for every direction — not an afterthought.
- **Dynamic Type**: long item names must truncate gracefully, never push the price off-screen.
  This has already broken one mockup — a quantity chip on the name line caused
  `Free-range eg…`. Watch for it.
- **One-handed, in an aisle, in motion.** Check-off targets big; primary actions in the bottom
  third.
- **Never colour alone** for meaning (see §2).
- **Motion**: 150–250ms, spring, interruptible. Nothing moves that the user didn't cause.
- **No streaks, badges, or guilt mechanics.** Ever. See `INTERACTION.md` §2.

## 4. The screens

Six exist. Every direction should cover at least the first four.

| Screen | What it must show |
|---|---|
| **List** | Items grouped by aisle · quantity · per-item price · aisle subtotals · trip total · 2 checked, 5 unchecked · one item with **no** price |
| **Add / input** | Query `oat` → 4 matches with prices · an "add as typed" escape hatch for off-catalog items |
| **Aisles** | Drag-to-reorder categories for one store · a second store list |
| **Household** | 3 members · one shopping live · invite link, no account required |
| **Where to shop** *(new)* | Same list priced at 4 stores · **coverage stated per store** · a cheapest-split option that also states the extra stop |
| **Spend** | Month total · % from receipts vs estimated · breakdown by aisle and by store |

## 5. Fixed sample data — use this exact set

So directions are comparable rather than merely different.

```
List "Weekly shop" · Trader Joe's · Sun 26 Jul · 5 of 7 left · 2 shoppers

PRODUCE  ≈ 9.90
  ☐ Bananas        ×6   ~2.50   (estimated)
  ☐ Baby spinach        3.40    (observed)
  ☐ Avocados       ×3   ~4.00   (estimated)
DAIRY  ≈ 11.20
  ☐ Oat milk       ×2   ~5.00   (estimated)
  ☑ Free-range eggs     6.20    (observed, CHECKED)
  ☐ Greek yogurt        —       (NOT PRICED)
PANTRY  ≈ 9.00
  ☑ Olive oil           ~9.00   (estimated, CHECKED)

TOTAL  ≈ 30.10   ·  3 estimated · 1 not priced yet
```

Household: **Juan** (you, added 4 today) · **Mara** (shopping now, added 2) · **Sam** (yesterday).
Invite link `bagged.app/j/7K2M-QX41`.
Stores: **Walmart $78.20** (15/18 priced, 12 min) · **Costco $79.90** (11/18, 24 min) ·
**Target $81.40** (14/18, 9 min) · **Trader Joe's $84.00** (18/18, 6 min). Split: **$71.40**,
2 stops, saves $12.60. Spend: **$284.60** in July, ↓$18 vs June, 34% from receipts.

## 6. Brand tokens (direction F — the current favourite)

Other directions deliberately break these. F is the baseline.

```
paper      #F7F4EE     card       #FFFFFF     ink        #191713
muted      #8C857A     line       #E4DFD5
persimmon  #C9502C     ← the only action colour
confirmed  #1F7A4D     ← semantic ONLY: done / verified. Never decorative.

aisle tints:  produce #B9CDA8   dairy #F1DCA4   bakery #EFC2B4
              frozen  #B7CCDD   household #D0C4E0  pantry #DDC5AA

type:  system sans for everything EXCEPT prices
       prices/totals = monospace, tabular numerals  ← the Ledger idea
```

**The warm paper base is the real differentiator.** The category is overwhelmingly cool-toned
(AnyList blue-grey, OurGroceries grey, Listonic green). Tiimo owns warm-paper-plus-lavender.
Warm paper plus **persimmon** is open.

## 7. The six existing directions

Screenshots: `design/concepts/{a-ledger,b-stall,c-standard,d-bento,e-halo,f-hybrid}.png`
Source: the matching `.html` files, self-contained, no dependencies.

| | Name | Navigation | Core idea | Verdict |
|---|---|---|---|---|
| **A** | **Ledger** | Bottom tear-strip, mono labels, active inverted | The app *is* a thermal receipt — perforated edges, dotted leaders, ruled subtotals | Most **ownable**. Mono struggles at large Dynamic Type |
| **B** | **Stall** | Top chalk rail + amber FAB + bottom pill | Market blackboard. Slate, chalk, amber | Best **compromise**. Dark-only is a real constraint |
| **C** | **Standard** | **Left vertical rail**, numbered 01–04 | Swiss brutalism. Black/white, acid lime, zero radii, huge numerals | Most **striking**, least **calm** |
| **D** | **Bento** | Split dock + orbital shortcuts | Tiles sized by spend; quick-pick grid | Most **usable** for ADHD (recognition > recall). Tiles cost vertical space |
| **E** | **Halo** | Floating glass pill + detached action | iOS 26 aurora and frosted glass | Most **current**. Contrast on glass is a fight |
| **F** | **Hybrid** ⭐ | Bottom pill + **one input bar** | **A's price typography inside D's structure.** Warm paper, rounded cards, emoji-on-tint, mono prices | **The chosen direction** |

### What F resolved, and must be preserved in anything new

1. **Capture is not permanent chrome.** Barcode / photo / receipt collapse into a second row
   *inside* the input bar. One tap away, invisible otherwise.
2. **AI has no tab. It is the same input field.** Type `milk` → adds. Say *"stuff for tacos"* →
   expands into droppable items. One input, three interpretations. Every assistant app has
   converged on this (ChatGPT, Gemini, Grok, DeepSeek, Notion, Meta AI: one bottom bar, mode
   chips, a mic).
3. **Price comparison states its own coverage** — "15 of 18 priced" on every row — and the
   cheapest split **prices the extra stop**, rather than pretending time is free.

## 8. What the competition looks like — do not land here

| App | Look |
|---|---|
| **Tiimo** (iPhone App of the Year 2025) | Warm paper, **large serif display**, lavender, pastel emoji discs, floating tab bar |
| **AnyList** | White, real product photos, dense rows, standard iOS |
| **OurGroceries** | Utility grey, plain, no prices |
| **Bring!** | Colourful icon-tile grid |
| **Listonic** | Green, ad-heavy |
| **MinimaList** | White minimal — and it *does* show prices and a total |

**Serif display headers are Tiimo's.** Avoid unless deliberately arguing for it.

## 9. Rendering the existing HTML

Self-contained, no build step:

```bash
npm i playwright-core          # in a scratch dir
node scratchpad/shot.mjs       # 393×852 @2x per frame, 5 frames per sheet
```
