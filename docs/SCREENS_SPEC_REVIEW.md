# The app spec, read in full — `Bagged · Screens` (`74:16`)

All 59 screens, nine flows. Read from the frame copy, not summarised from titles.

> **This is the most important artifact in the project.** It is coherent, it is well written, and
> **it is a different product from the one our docs describe.** That difference is worth
> understanding before anything is built.

---

## 1. What the product actually is now

> **"Bagged — Knows what you have. Remembers what you paid."** *(A1, H6)*

Two halves. **Knows what you have** = the Shelf. **Remembers what you paid** = the price book.
Our docs say *"a shared grocery list where every item carries a price"* — the list is the product,
cost is the differentiator. **The spec inverts that.** The list is one tab of four, the Shelf is
first, and the entire onboarding is about filling the shelf.

### The core loop, and it's better than ours

```
scan a receipt → 14 things land on the shelf WITH prices
              → shelf depletes over time
              → what runs low becomes the list
              → shop → scan the receipt → repeat
```

**One photo does two jobs at once.** `PRICE-INTELLIGENCE.md` §3 called cold start "brutal" — you
know nothing until receipts exist. **This spec's answer is that the receipt scan *is* the
onboarding.** A2's first value prop, A5's whole screen, B7's empty state and C2 all repeat the
same concrete promise:

> **"One photo · every line · about 6 seconds"**

That solves the pantry cold start *and* the price-book cold start with one action. It is the
single best idea in the file and it isn't in any of our documents.

---

## 2. Five things it does that our docs never specified

**1. The receipt review flow (C3 → C4) is exceptional, and it's a learning catalog.**

C3: *"Nothing goes on the shelf until you say so."* Every line carries a confidence — `sure` /
`not sure` / `no match` — and *"2 lines still need you. They stay off the shelf."*

C4 then teaches the system: *"Match it once. Bagged remembers it next time."* → *"Next time
MILK 2% GAL lands on a receipt, Bagged matches it to Whole milk without asking."*

That directly answers the OCR-poisoning risk in `PRICE-INTELLIGENCE.md` §7 **and** it's how
`SOURCING.md`'s "grow the catalog from demand, not bulk import" actually happens in practice.

**2. Privacy is a load-bearing promise, repeated verbatim across four screens.**

> *"Location never leaves the phone. There is no server that knows where you shop."*
> — A4, D5, G2, H5
> *"Recognition runs on this phone. Nothing you say is sent anywhere."* — D3, H3

Our on-device architecture (`FEATURES.md` §10) made this *true*; **nobody had turned it into a
claim.** H5 lists every data class the app holds and where. This is a positioning pillar we don't
have in `BRAND.md` or `PLAN.md`, and against a category funded by retail media it is a strong one.

**3. Typed entry has equal standing with scanning.**

C6: *"Every line you type becomes a price observation, tagged `typed`. It counts the same as a
scan."* Works with no camera and no signal. `SourceTag · receipt` / `SourceTag · typed` are real
components.

**4. Per-member privacy inside the household.**

F3: `The list — Edit` · `Your shelf — Hidden` · `Prices and receipts — Never`. A guest sees the
list and nothing else. **Prices are treated as sensitive within a family**, which is right and
which we never considered.

**5. Widget installation is taught step by step.**

G1: *"Touch and hold the lock screen. The icons start to wobble. Tap Customize, then the +."*
Widget discovery is famously terrible; almost nobody does this.

---

## 3. The confidence vocabulary is now four tiers, and it's used consistently

| Tier | Renders | Seen in |
|---|---|---|
| **measured / observation** | `$4.49` solid | D2 *"becomes a new measured observation"* |
| **estimated** | `~$5.00` | D1, E2 *"12 observations, one estimated"* |
| **guessed** | *(counted separately)* | D1 *"3 estimated · 1 guessed"* |
| **no price yet** | `—` | D1, C4 |

`DESIGN_HANDOFF.md` §2 defines **three**. The spec uses **four**, and `guessed` is never visually
defined anywhere I can find — only counted. **Either define how `guessed` renders or fold it into
`estimated`.** The honesty rule is the brand; a tier that only exists in a footnote weakens it.

---

## 4. Six divergences that need deciding, not absorbing

### ⚠️ 4.1 Scope — this is not a v1

59 screens covering shelf, expiry, locations, budgets, trips, category detail, store comparison,
five extra surfaces, guest views and per-member permissions. `PLAN.md` §3 defines v1.0 as **five
core features**, with pantry at **v2 "only if retention holds."**

For one person in Swift this is a multi-quarter build. **The spec is a destination, not a first
release** — and it should be labelled that way in the file so nobody treats it as a build queue.

### ⚠️ 4.2 The Shelf needs consumption tracking, and it isn't designed

B2 shows *"About 72% left · runs out in ~5 days."* Nothing in 59 screens explains **how the app
knows.** Two possibilities and both have problems:

- **The user logs consumption** — historically the exact rock every pantry app founders on
- **It's inferred from purchase cadence** — plausible, needs history, and can't work on trip one

**This is the single largest unanswered question in the spec**, and the Shelf is the first tab.

### ⚠️ 4.3 Expiry guesses need shelf-life data we don't have

B3: `Expiry · ~ Guess it for me`. B1 shows `eat in 2d`, `~3 days`, `ripe now`, `2 weeks`.
`data/catalog/` has **no shelf-life field** — 414 items, no perishability model. That's a new
dataset to build, seed and regionalise.

### ⚠️ 4.4 Sign-in is now required for the owner

A6: *"Your kitchen needs an account so the shelf…"* Our docs promise **no account required**
(`CAPABILITIES.md`). F1/F2/F4 do preserve **guest, no account** for invitees — *"Sara Ruiz ·
Guest · no account"* — so the invite loop survives. But the owner path changed.

### ⚠️ 4.5 Budgets appear, unspecified anywhere

E3 shows `budget $80.00`, `4 of 12 over budget`, `under` / `over` per trip. Budgets are in **no**
document. They're a natural fit — but "over budget" is exactly the kind of judgement
`INTERACTION.md` §2 refuses. **If budgets ship, they report; they never scold.**

### ⚠️ 4.6 `"Opens in Otto"` — a cross-app dependency

B5 · Eat me first → *"Cook something with this — Opens in Otto."* That hands a core flow to a
separate app. Fine as a portfolio play, but it's a dependency, a partnership assumption, and a
dead end for anyone who doesn't have Otto. **Needs a fallback.**

---

## 5. The gating problem, restated with the full picture

H2 gates: receipt scan · price history · **more than one shop** · Watch/Siri/CarPlay.

Now that the whole spec is visible, the gating is **worse than I said last turn**:

- **The receipt scan is gated — and the receipt scan is the onboarding.** A5 "First fill" and B7
  "One receipt fills it" are both the free user's first experience of the product, and both lead
  to a paywall. The free tier can't fill its shelf, so the Shelf tab is empty, so the first tab of
  the app is a dead room.
- **"More than one shop" gates store comparison**, which needs ≥2 stores.
- **Siri is gated** though it's on-device and free to run — gating it saves nothing
  (`FEATURES.md` §10).

*"The glance stays free for everyone. Plus is what pays for it."* is a clean line. But **"the
glance" is a list with estimates and an empty shelf** — that may be too thin to retain anyone long
enough to convert.

**The cheapest fix: give the free tier a small number of receipt scans** (3–5 lifetime, or one a
month). It lets the loop run, proves the magic, fills the shelf, and makes the paywall an obvious
upgrade rather than a locked door.

---

## 6. What to do

1. **Label the file** — `Bagged · Screens` is the **destination**, and mark which screens are v1.0
2. **Answer 4.2** — how does the shelf know something is running out? Nothing else in the Shelf
   works until that's decided
3. **Reconcile the docs** — `README.md`, `CAPABILITIES.md` and `PLAN.md` all describe a
   list-first app. Either the spec changes or the docs do; right now they contradict
4. **Define or delete `guessed`**
5. **Add the privacy claim to `BRAND.md`** — it's the best positioning line in the whole project
   and it came from the screens, not the strategy
6. **Reconsider gating the receipt scan** — a few free scans probably converts better than none
7. **Adopt the C3/C4 review-and-learn flow into `PRICE-INTELLIGENCE.md`** — it solves a risk that
   spec only flagged
