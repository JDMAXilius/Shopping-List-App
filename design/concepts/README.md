# Five visual directions

Five complete, deliberately incompatible design languages. Each has the same five screens with
the same data, so they can be compared honestly: **List · Add · Aisles · Household · Spend.**

**Every one uses a different navigation model** — that was a constraint, not an accident. Nav
patterns were referenced from Mobbin (Hypelist, Fixtured, Superpower, Orbit, Cosmos, Wabi,
ElevenLabs, Apple Fitness): floating pills, detached action circles, split docks, top rails.

**None of them look like the competition.** Not Tiimo's warm-paper-and-serif, not AnyList's
photo rows, not OurGroceries' utility grey, not Bring!'s icon grid, not Listonic's green.

| | Direction | Navigation | The idea | Feature it adds |
|---|---|---|---|---|
| **A** | **Ledger** | Bottom tear-strip, 4 mono labels, active inverted | The app *is* the receipt | Per-aisle subtotals inline, double-ruled total |
| **B** | **Stall** | Top chalk rail + floating amber FAB + bottom pill | Market blackboard, dark-first | Live "shopping now" presence, learned-order toggle |
| **C** | **Standard** | **Left vertical rail**, numbered 01–04 | Swiss editorial brutalism | Numbered rows, input-mode segmented bar |
| **D** | **Bento** | Split dock — left pill + detached ink circle + orbital shortcuts | Tiles sized by spend | Quick-pick grid, tile area ∝ money |
| **E** | **Halo** | Floating glass pill + detached mint action | iOS 26 depth and light | Gradient totals, glow states |

---

## A — Ledger

**Thermal receipt as an interface.** Off-white paper with perforated edges, monospace throughout,
dotted leader lines from item to price, subtotals ruled under each aisle, and a double-ruled total
box. Nav is a dashed tear-strip of four mono labels; the active one inverts to a solid block.

**Why it might be right:** the cost wedge *is* the product, and this is the only direction where
the visual language and the differentiator are the same thing. Nobody in the category looks
remotely like this.

**Why it might be wrong:** monospace is hard at small Dynamic Type sizes, and "receipt" carries a
whiff of admin. It could read as a bookkeeping app rather than something you open in an aisle.

## B — Stall

**A market blackboard.** Slate ground, chalk text, amber as the single accent, sage for done.
Items live in bordered "crates" per aisle. Nav is a top rail with an amber underline plus a bottom
pill, and an amber FAB floats clear of the total board.

**Why it might be right:** dark-first is genuinely rare in this category, it's kind on the eyes
under supermarket lighting, and the amber-on-slate is warm rather than techy.

**Why it might be wrong:** dark mode as the *only* mode is a real constraint, and warm dark
palettes can go muddy at low brightness.

## C — Standard

**Swiss editorial, no compromises.** Pure black on pure white, acid lime as the one accent, zero
border radius anywhere, hairline rules, huge tabular numerals. Rows are numbered 01–07. Nav is a
**left vertical rail** with rotated labels — no bottom bar at all.

**Why it might be right:** the loudest, most confident, most screenshot-able of the five, and the
price figures carry real typographic weight. The vertical rail frees the entire bottom edge.

**Why it might be wrong:** it's cold. It's the furthest from the ADHD-calm brief, and a left rail
is unusual enough on iOS that it needs to be taught.

## D — Bento

**The list as a dashboard of tiles**, sized by importance and spend, colour-coded by aisle. On the
Spend screen, **tile area is proportional to money** — you see where it went before reading a
number. Nav is a split dock: a pill on the left, a detached ink circle on the right, with orbital
shortcuts (mic, camera, barcode) arcing above it.

**Why it might be right:** the most immediately legible at a glance, the friendliest, and the
quick-pick grid solves the blank-list problem with **recognition instead of recall** — the
strongest ADHD argument of any direction here.

**Why it might be wrong:** tiles cost vertical space, so fewer items fit per screen — a real
problem for a 40-item shop. Closest of the five to Bring!'s icon grid.

## E — Halo

**iOS 26 depth.** Aurora gradients behind frosted translucent cards, hairline light borders,
gradient-filled totals, a mint glow on completed items. Nav is a floating glass pill with a
detached mint action button.

**Why it might be right:** the most contemporary and the most native-feeling; it would look
current in a 2026 App Store listing, and none of the competitors are anywhere near it.

**Why it might be wrong:** translucency plus gradients is the hardest to keep accessible —
contrast on glass is a genuine fight — and it's the most likely to date when the platform style
moves again.

---

## Honest read

- **A (Ledger)** is the most *ownable* — it can't be confused with anything else in the category
- **D (Bento)** is the most *usable* for the ADHD brief, on the recognition-over-recall argument
- **E (Halo)** is the most *current* and the most likely to get editorial attention
- **C (Standard)** is the most *striking* and the least *calm*
- **B (Stall)** is the best *compromise* — distinctive, warm, and it doesn't fight the brief

**A hybrid is probably the answer**, and the most promising is **Ledger's typographic treatment of
price inside Stall's or Bento's structure** — the receipt idea is the strongest concept here, but
it doesn't have to own the whole interface to do its work.

## Rebuilding

`design/concepts/*.html` are self-contained. Render with:

```
node scratchpad/shot.mjs      # Playwright, 393×852 @2x per frame
```
