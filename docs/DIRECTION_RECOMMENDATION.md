# Which direction to ship — the top five, ranked

Judged on what actually decides whether the app succeeds, not on which looks nicest:

| # | Criterion | Why it decides success |
|---|---|---|
| 1 | **Does it make cost the visual language?** | Cost is the only thing AnyList and OurGroceries don't have. If the design doesn't carry it, we have no wedge |
| 2 | **Does it survive a 40-item shop?** | The weekly shop is 30–40 items. A design that looks great at 7 and collapses at 40 fails in the only session that matters |
| 3 | **Does it read at thumbnail size in App Store search?** | ASO is the entire marketing budget. 65–70% of downloads start with search and the decision is made on a 200px-tall screenshot |
| 4 | **Is it unlike all six competitors?** | AnyList, OurGroceries, Bring!, Listonic, MinimaList, Tiimo |
| 5 | **Is it calm?** | `INTERACTION.md` — anti-guilt, no pressure, one-handed in an aisle |
| 6 | **Can one person build it in SwiftUI?** | Every unbuildable flourish is a week not spent on sync |

---

## The five

### 1. F · Hybrid ⭐ — **ship this**

**Scores: cost ●●●●● · density ●●○○○ · thumbnail ●●●●○ · distinct ●●●●● · calm ●●●●● · buildable ●●●●●**

Warm paper, rounded cards, aisle-tinted tiles, and **monospace tabular prices with dotted leaders**
running to the right edge. The one input bar carries typing, voice and capture together.

**Why it wins:** it's the only direction that scores well on *all six* criteria instead of
spiking on one. The warm-paper-plus-persimmon ground is genuinely unclaimed — the category is
cool-toned (AnyList blue-grey, OurGroceries grey, Listonic green) and Tiimo has taken
warm-paper-plus-lavender-plus-serif. And per the terminal session's own note, **it survived Auto
Layout, dark mode, a token system and a component set without a structural change** — that means
it's buildable, which is not a small claim.

**Its one real weakness: density.** Seven items fill the screen. See #3.

### 2. A · Ledger — **the brand idea, and it's the strongest one here**

**Scores: cost ●●●●● · density ●●●○○ · thumbnail ●●●●● · distinct ●●●●● · calm ●●●●○ · buildable ●●●○○**

The app *is* a receipt. Perforated edges, monospace throughout, dotted leaders, ruled aisle
subtotals, a double-ruled total.

**Why it's #2 and not #1:** as a *brand idea* it's the best in the set — **the differentiator and
the visual language are the same object**, which is the rarest thing in branding and almost never
available. At thumbnail size in a search result, a receipt is recognisable in a way a card list
never is.

**Why not ship it whole:** monospace at the largest Dynamic Type sizes is a genuine accessibility
problem, and "receipt" carries a whiff of bookkeeping — it risks reading as an expenses app rather
than something you open in an aisle.

**What to do instead: F already contains A's typography.** That was the point of the hybrid.
Push it further — the perforated top edge and the double-ruled total are cheap to add to F and
they're the two details that make the receipt idea land.

### 3. K · Slab — **not a direction, a mode F needs**

**Scores: cost ●●●●● · density ●●●●● · thumbnail ●●●○○ · distinct ●●●●○ · calm ●●○○○ · buildable ●●●●●**

A real table — `ITEM · QTY · PRICE` header, aisle subtotals in the band, a right-edge aisle index,
**and unit price under every row** (`~$0.42/ea`, `$1.70/100g`, `$0.50/l`).

**Why it matters more than its looks suggest:** it shows **eleven items where F shows seven**, and
it's the only direction that admits the weekly shop is a spreadsheet. It also ships **unit price —
which no competitor displays at all**, and which is the single most useful number in a supermarket
because it's the only one that makes two package sizes comparable.

**But it's cold.** It reads as a pro tool, and it's the furthest of the five from the calm brief.

**What to do: make it F's density mode, not a rival.** Same tokens, same nav, tighter rows and unit
price revealed. One toggle. That gets F from ●●○○○ to ●●●●● on the criterion it currently fails,
without spending the warmth.

### 4. L · Route — **for the Where-to-shop screen**

**Scores: cost ●●●●○ · density ●●○○○ · thumbnail ●●●○○ · distinct ●●●●● · calm ●●●●○ · buildable ●●●○○**

A ribbon of stops; **the price accrues as you walk**, each item showing what it adds.

**Why it's here:** it's the only direction that makes `PRICE-INTELLIGENCE.md`'s hardest idea
legible — *pricing the extra stop*. **Apple Maps already taught everyone this pattern** with
"adds 5 min", so "saves $6.20, adds 24 min and a second stop" needs no explanation.

**Not as the whole app** — a list isn't a route until you're already shopping. **Steal the framing
into F's `Where to shop` screen** regardless of whether L ever ships.

### 5. P · Ticker — **for the Spend screen only, and de-fanged**

**Scores: cost ●●●●● · density ●●●●○ · thumbnail ●●●●● · distinct ●●●●● · calm ●○○○○ · buildable ●●●○○**

Per-item 4-week sparklines and **Δ against your own average**, aisle-level deltas, dark ground.

**Why it's on the list:** it is the **only direction expressing a claim no competitor can copy.**
Flipp, Basket and GroceryChop can all tell you a price. **None of them can tell you it's up 8% on
what *you* usually pay**, because none of them have your history. That's the price book made
visible, and it's the most defensible thing in the whole product.

> ⚠️ **And it's the one I'd be most careful with.** Red arrows on your groceries, every week, is a
> stock ticker for food. For a budget-conscious user — and for the ADHD audience `INTERACTION.md`
> is written for — that's an anxiety machine, and it directly contradicts the anti-guilt stance.
>
> **Take the idea, drop the affect.** Δ-vs-your-usual belongs on **Spend**, shown monthly, in ink
> and persimmon rather than red and green, phrased as information rather than alarm.

---

## The honest answer: it isn't one of five

**Ship F as the shell, and take one organ from each of the others:**

| From | Take | Into |
|---|---|---|
| **A · Ledger** | Perforated top edge, double-ruled total, mono prices | F's chrome *(mostly done)* |
| **K · Slab** | Density mode + **unit price** | F, as a toggle |
| **L · Route** | "saves $6.20, adds 24 min and a stop" | F's `Where to shop` |
| **P · Ticker** | Δ vs your own average, calmly styled | F's `Spend` |

That's one app with a coherent identity that scores ●●●●○ or better on every criterion — rather
than five directions each brilliant at one thing.

## What I'd drop, and why

- **E · Halo** — the most current-looking and the fastest to date. Contrast on live translucency is
  a real accessibility fight, and iOS style moves again in two years
- **C · Standard** — the most striking, the least calm. Directly fights the brief
- **I · Meter** — price-as-bar-length is the purest expression of the wedge and it makes the list
  harder to *skim as a list*. `PLAN.md` §7 puts add-speed at ≤2s. Steal the bars for Spend
- **H · Larder** — its job was answering the photography question, and it did: **two items per row
  instead of seven.** Photography buys recognition and spends the density K proves matters.
  That trade is now visible rather than argued — and combined with two sessions independently
  landing on line icons, **the imagery answer is line-icon glyphs, not photographs**
- **G, J, M, N, O** — memorable, impractical, or they hide the total the app exists to show

## The one thing to test before committing

**F has never been seen at 40 items.** Every judgement above about density is inference from a
7-item mockup. Build one frame — F's list screen with a real weekly shop — before this is final.
If it holds, ship F. If it doesn't, K's density mode stops being an option and becomes the default.
