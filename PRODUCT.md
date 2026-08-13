# PRODUCT — the final word

**Decided August 2026. This document outranks every other doc in the repo.** Where an older file
disagrees with this one, this one wins (the deprecation table at the bottom says exactly where).
Next conversation is architecture; nothing here is open.

**What the app is:** **Bagged** — a shared grocery list that knows what things cost. iOS native,
list-first, shaped like Amazon Fresh's shopping list. Every item carries a price, every aisle a
subtotal, every trip a total — and the prices come from your own receipts, nobody else's data.

**The loop:**
`add to the list → shop → scan the receipt → prices get real → the list gets smarter`

**The one-line position:** *Know what the trip costs.*

---

## 1. Why this and not something else — the evidence

### What works (verified against shipped apps and store data)

| Verdict | Evidence |
|---|---|
| **A shared grocery list is a real, paying market** | AnyList: 14 yrs, 79K ratings, 4.9★, ~$840–960k/yr. OurGroceries: 84K ratings, ~$360k/yr. Listonic ~$5M/yr (ad-funded) |
| **Cost is the unclaimed wedge in the category** | No dedicated grocery app leads with prices. Prices are the most-requested missing feature in AnyList and OurGroceries reviews. MinimaList (a to-do app, 46K/4.8★) proves demand by shipping totals |
| **Every mechanic we ship exists in a successful app** | Woolworths: aisle tags + unit prices + `Est. Total` on one list. Instacart: `Est. total · est. savings` pinned to a grocery list. Amazon Fresh: `COMPLETED (n)` + suggested grid. Splitwise/GoPay: our receipt-review contract. All 28 screens have top-3 shipped references (`design/references/`) |
| **Our price is conservative, not aggressive** | Tiimo — iPhone App of the Year — charges $54/yr on the same 7-day trial: 1.8× our $29.99. Utilities have the highest first-renewal retention of any category (58.1%) |
| **Sharing is the growth loop, so joiners ride free** | Hard paywalls convert ~5× better (10.7% vs 2.1% D35) but kill invites. Resolution: **paywall the owner, never the joiner** |
| **ASO is the entire marketing budget** | 65–70% of downloads start at store search; top-3 for a term takes >50% of clicks; screenshot captions are OCR-indexed. Paid acquisition is dead at ~$30–40 LTV |
| **Calm is a defensible position, not a vibe** | Listonic is ~90% ad-funded — attention is their inventory. An app that treats attention as the user's is something an ad-funded competitor structurally cannot copy |

### What doesn't work (and we therefore don't do)

| Verdict | Evidence |
|---|---|
| **"Nobody shows prices" — false, banned from copy** | MinimaList ships per-item prices, category subtotals, `Total $65.97`. The honest claim: *no dedicated grocery app owns cost* |
| **Selling "AI" as a headline** | Listonic's gradient "With AI" badge sits on the category leader's first screenshot — it's furniture. Sell the outcome ("know what the trip costs"), never the technique |
| **Under-pricing** | OurGroceries: more iOS ratings than AnyList, $7.99/yr + $20 lifetime, less than half the revenue. No lifetime tier, ever |
| **Pantry / inventory tracking** | Needs consumption tracking nothing can supply; inventories drift within weeks. The Shelf (7 designed screens) is cut — never, unless that problem is solved |
| **Recipes and meal planning** | AnyList has owned it for 14 years at 4.9★. Cut, not deferred |
| **Streaks, badges, guilt** | People shop 1–2×/week — a streak punishes not shopping. Anything that can be *lost* is banned. Tiimo added streaks and it's a warning, not a model: calm aesthetics and calm mechanics are separable, and we keep both |
| **Fighting free giants on their turf** | Google Keep / Apple Reminders own "zero-friction free list." We differentiate on what they'll never build: prices, aisle order, receipt capture |
| **Crowdsourced / scraped price data** | Flipp (flyers), Basket (crowdsourced), GroceryChop (scraping) all fail identically: staleness + coverage gaps + legal exposure. Ours: your receipts only — 100% coverage of *your* stores, zero legal risk, and it compounds |
| **The moat is the history, not the feature** | Listonic already ships photo→list OCR; receipt scanning is weeks of work for them. What they can't copy is a year of *your* price book. Defensibility = accumulated personal data |

---

## 2. Style — final

**Direction F · Hybrid, exactly as built on Figma page `138:978 · Bagged · Screens app current`.
That page is the visual source of truth.** It won because it's the only direction scoring well on
all six criteria (cost-as-language, 40-item survival, thumbnail legibility, distinctiveness,
calm, one-person buildability) instead of spiking on one.

### Tokens — canonical set (the built `F · Tokens` collection)

```
paper      #F7F4EE     card    #FFFFFF     ink   #191713
muted      #8C857A     line    #E4DFD5
persimmon  #C9502C     ← the ONLY action colour
confirmed  #1F7A4D     ← semantic only: done / verified. Never decorative.

aisle tints: produce #B9CDA8 · dairy #F1DCA4 · bakery #EFC2B4
             frozen #B7CCDD · household #D0C4E0 · pantry #DDC5AA

type: system sans (SF Pro) everywhere EXCEPT prices —
      prices & totals are MONOSPACE, tabular numerals, always
```

`BRAND.md` §5's older token values are **deprecated**.

**One style for the entire app — decided (Aug 2026).** There are no appearance variants: no
light/dark modes, no themes. The warm-paper look above is the app's single appearance under
every system setting — the brand *is* the look, the way a printed receipt has one look. The two
dark frames on the Figma page are kept as exploration only; they are not product. (This also
deletes a whole class of work: every screen designed once, tested once, maintained once.)
**Grey estimate text must be contrast-verified at 4.5:1 — verified, not assumed — before build.**

- **Why warm paper wins:** the category is cool-toned (AnyList blue-grey, OurGroceries grey,
  Listonic green) and even the warm accents cluster in coral. The differentiator is the **paper
  base**, not the persimmon. Tiimo owns warm-paper-plus-lavender; warm-paper-plus-persimmon is open.
- **Green is a fact, grey is a guess.** Green never decorates — it marks done and measured only.
  That single rule ties the colour system to the honesty rule.
- **Prices are monospace, never serif.** Serif display was considered (Tiimo teardown) and
  rejected in-app: serif headers are Tiimo's territory, and the mono price column *is* the Ledger
  brand idea — the differentiator and the visual language are the same object. A display face may
  appear in marketing only.

### The four organs F carries (from the 16-direction exploration)

| From | Organ | Where it lives |
|---|---|---|
| A · Ledger | Mono prices, dotted leaders, double-ruled total | List + totals (built) |
| K · Slab | **Unit price** (`$1.70/100g`) | Item detail + price book at v1; density toggle → v1.1 |
| L · Route | "saves $6.20, adds 24 min and a stop" | Where-to-shop, v1.1 |
| P · Ticker | Δ vs *your own* average — ink and persimmon, never red/green | Month/spend (built) |

### Item imagery — FINAL: line-icon glyphs on aisle-tinted rounded tiles

The three-way conflict (emoji-on-tint vs line icons vs photos) is closed:

- **Photos — rejected.** H·Larder proved the cost: two items per row instead of seven. ~14–15 MB
  of bundle for 414 images. Legal sourcing burden. And our items are *generic* ("oat milk", not a
  SKU) — a photo of someone else's oat milk is a small lie; commerce apps use photos because they
  sell specific SKUs. We're a list app, not a store.
- **Line icons — adopted.** Legally clean (drawn, owned), ~0 MB, one coherent visual system,
  scales with Dynamic Type, and it's what's actually built into the F components. Tiimo proves
  the tinted-disc treatment reads premium; we keep the tint, swap emoji for our glyphs.
- **Emoji — the permanent fallback** for user-created items with no glyph yet. The text label is
  always primary; a missing tile must look intentional, never broken.
- Ship: 22 category glyphs at v1 (every item resolves to at least its category glyph) + the
  ~100 top-frequency item glyphs. Grow from unmatched search terms. Icon backlog starts with
  apple + barcode (currently stand-ins).

### Density — FINAL: F's row height stands

Judged from the real `01b List · full` frame (40 items): ~8 rows per screenful, in line with
Amazon Fresh and Woolworths. The list *shrinks as you shop* — finished aisles collapse, completed
items sink into `COMPLETED (n)` — so the crowded-list case solves itself. 44 pt touch targets and
ADHD load rules outrank raw density. K's compact mode + unit-price rows ships v1.1 as one toggle.

### Row anatomy — FINAL

Tick circle · tinted glyph tile · **name** (truncates, never pushes the price) · `×N` quantity
as a subtitle **under** the name (never a chip on the name line — that's the known truncation
bug) · dotted leader · mono price right-aligned. Three price renders, never confusable:
`$4.49` solid ink · `~$5.00` lighter + muted · `—` none. `≈` on any total containing an estimate.

### Motion, haptics, sound (the full ruleset is `INTERACTION.md` — unchanged and final)

- Motion: 150–250 ms state changes, spring, **interruptible always**, one thing at a time,
  `Reduce Motion` = cross-fade path. Nothing moves that the user didn't cause.
- Haptics are the primary channel: `impactLight` on check-off (fires 40×/trip — must stay light),
  `notificationSuccess` only when the whole list completes. Never on scroll, never from sync.
- **Sound on by default.** Two sounds total: a sub-120 ms tick and a completion tone. Inaudible
  past a metre, must survive 40 repetitions, `ambient` category, never ducks audio, never plays
  from widget or intent, silent switch always respected.
- **The completion moment is arrival, not celebration:** the `≈` resolves to a real figure,
  one success haptic, the tone, one quiet line — *"That's everything — 23 items, $84."*
  No confetti, no score, no share prompt, no rating ask.

### The ADHD stance (design for it, never market a treatment)

Banned outright: streaks, badges, red dots, variable rewards, surprise animations, re-engagement
notifications, mascots, idle motion, rating prompts at completion. The seven accommodations —
open into the list, total always visible, externalized memory (widget + arrival trigger), aisle
grouping as attention relief, defaults everywhere, checked items sink never vanish, no guilt —
are the product's spine. ADHD is named on one in-app "why it works this way" page and nowhere in
store copy. Store subtitle says what it does, not who it's for.

---

## 3. Features — final

**The complete itemized list is `docs/V1_SCOPE.md` — 85 feature commitments in 9 groups**
(the header previously said 62; the honest count of its own bullets is 85). Summary:

| Group | Count | The one that matters most |
|---|---|---|
| The list (the product) | 22 | Unpriced items promoted to top: *"tap to set what you paid"* — data collection as the primary UI |
| Cost (the differentiator) | 12 | Three tiers never confusable; observations on *(item, store, date)*; >90 days reverts to estimate |
| Capture (the engine) | 11 | Nothing commits unreviewed; match an unknown line once, remembered forever |
| Sharing (the growth loop) | 9 | Invite by link, guests need no account, **free forever** |
| Offline (a property) | 5 | Everything works with no signal; no conflict prompts |
| Places | 6 | The list wakes when you arrive; location never leaves the phone |
| On the phone | 8 | Lock-screen widget with tappable checkboxes; Siri add/what's-left/read-aloud |
| Settings & trust | 5 | Full inventory of everything the app holds, and where |
| Money | 7 | 3 free receipt scans before the paywall — the loop has to run once |

**The cost architecture is a feature:** every v1.0 feature runs on plain code or a system
framework — zero marginal cost. Claude's entire surface is two paid-tier features (receipts now,
handwriting at v1.2) at ~$0.22–1.08/subscriber/year (≤3.6% of the subscription; Batch API and
prompt caching cut it further). Free tier → on-device only, forever. Voice add is on-device
transcription + our resolver: $0, and a mis-transcription behaves exactly like a typo.

**Cut and staying cut:** Shelf (never, unless consumption tracking is solved) · recipes (never) ·
cheaper-elsewhere + store comparison + trips + learned aisle order + recurring staples +
K-density toggle (v1.1) · handwriting + printed-list photo (v1.2) · member permissions, Watch,
CarPlay, Live Activity (v2 — Live Activity first among them; a shopping trip is exactly a
session) · budgets (v2 or never; they report, they never scold) · multiple lists (one list is
the job).

---

## 4. Screens — final

**31 frames on Figma page `138:978`, the canonical set** — same numbering as `design/app/` and
`design/references/`:

- **19 navigable:** List (+ `01b` at 40 items) · Item detail/set price · Aisle order editor ·
  Receipt review · Unmatched line resolver · Capture result · Enter by hand · Prices · Item
  price history · Month/spend · Kitchen · Places · Add/edit shop · Setup · Data & privacy ·
  About · Name your kitchen · Add your first shop · Sign in/restore
- **8 sheets:** Capture chooser · Receipt camera · Barcode scanner · Add item · Shop switcher ·
  Invite · Paywall · First receipt
- **7 states:** Empty list · All done · Offline · Scan failed · Processing · Camera primer ·
  Location primer
- **1 target:** Widget extension (lock + home screen)

*(The page also holds two dark-variant frames — exploration only. One style ships; see §2.)*

**Navigation: three tabs + one action.** `List · Prices · You`, persimmon `+` for capture.
Every screen has its top-3 shipped-app references in `design/references/` (28/28 complete).

---

## 5. Onboarding and the entire workflow — final

### First run: no wizard. The app IS the onboarding.

Setup cost must be proportional to session length — a planner earns a setup ritual; a list app
has ninety seconds. So:

1. **App opens directly into the List.** No splash carousel, no account wall, no permission
   asks, no name-your-kitchen. Empty state shows the `SUGGESTED FOR YOU` grid (tap = added) and
   the input bar — *"I need…"* (Bring!'s placeholder, stolen deliberately) with the mic.
   **First item on the list inside 10 seconds, ≤2 taps.**
2. Every added item lands with a seeded estimate (`~$4.50`) — the total starts working on trip
   one with zero input. The `≈` teaches itself.
3. **Contextual steps replace the wizard** — each screen appears at the moment it's needed:
   - *Add your first shop* (18) → first time they open the shop switcher or aisle order.
     Location permission asked **only** if they enable "wake when you arrive" (primer first).
   - *Name your kitchen* (17) → first invite. Until then it's just "your kitchen."
   - *Sign in* (19) → only when inviting (the owner needs an account so the kitchen survives a
     lost phone) or restoring. **Guests never see it.**
   - Camera permission → first capture, primer first.
   - Notifications → only when they enable arrival wake-ups.
4. **The real onboarding is the first receipt scan** — *"One photo · every line · about 6
   seconds."* The First-receipt sheet (27) is the aha: *"9 prices are now real."* Warm, one
   line, zero badges (tone reference: Me+ / Alan). This is why 3 scans are free — the loop must
   run before the paywall makes sense.

### The weekly workflow, screen by screen

**ADD (all week, 10-second sessions):** type or hold-to-speak in the input bar → autocomplete
ranks your history → household history → catalog, showing what you last paid inline → item lands
in its aisle with quantity `×1` default, estimate attached, total updates with a ~200 ms digit
roll. Or: Siri / lock-screen widget / Shortcuts — same App Intents, no app open.

**PLAN (before the trip):** list is grouped in the walk order of the chosen shop (switcher: 24).
Unpriced items sit at top under `NO PRICE YET` — each one a tap from being fixed. The total reads
`≈ $84.50 · 3 estimated · 1 no price yet` — it breaks itself down, always honest.

**SHOP (in the aisle):** arrive → the list wakes (geofence; or the manual *"At Trader Joe's?"*
prompt if location is off). One-thumb ticks: light haptic + sub-120 ms tick sound, strikethrough
draws, row sinks. Finished aisles collapse to `✓ PRODUCE · done (2) · ≈ $11.40`. Partner adds
"parmesan" from home → soft tint on the new row, no toast, no buzz. Last item: the `≈` resolves
to the real figure, success haptic, completion tone, *"That's everything — 23 items, $84."*
The screen goes calm. Nothing else appears.

**CAPTURE (at the car, ~30 seconds):** `+` → capture chooser (20) → receipt camera (21, lighting
tip in-viewfinder) → processing state → **review (04): nothing commits unreviewed.** Per-line
confidence `sure · not sure · no match`; any line >3× its estimate is flagged. Unknown lines →
resolver (05): *"TJ ORG BABY SPNC"* → match to *Baby spinach* **once, remembered forever** — the
catalog learns your receipts. → Capture result (06): *"14 lines · 12 matched · every line became
a price."* No camera or signal? Enter by hand (07) — typed lines count the same, tagged `typed`.

**LEARN (compounds forever):** Prices tab (08) — the price book: every item, measured vs
estimated share ("you watch your own data get better"), per-store history with dated deltas (09),
Month/spend vs last month with Δ-vs-your-usual in ink, never red (10). Observations accumulate,
never overwrite; >90 days old they demote themselves back to `~`. Next week's autocomplete shows
real prices. The list got smarter.

**SHARE (the growth loop):** Kitchen (11) → Invite (25): one link — QR, Message, WhatsApp.
*"They just tap the link… no account, no download wall, free for them forever."* New link
revokes the old. Activity feed shows who added what. Guests get the full list experience free,
forever — they're the channel (targets: ≥1.5 invites/owner).

**PAY (only when the loop has proven itself):** after the 3 free scans, the paywall (26):
*"The list is free forever. Plus makes the prices real."* $2.99/mo · $29.99/yr (2 months free)
· 7-day trial on annual · "You've used 3 free receipt scans" · Restore/Terms/Privacy in plain
sight, zero dark patterns (references: Tide Guide, The New Yorker). Free forever: list, sharing,
estimates, one shop, Siri, widget. Plus: receipt scanning, price history, more than one shop.

---

## 6. Money — final

- **$2.99/month · $29.99/year** ($19.99 launch-window annual intro), 7-day trial on annual only
  (21-day trials don't exist on the App Store; 7 days = exactly one shopping trip, which the free
  scans make count). No lifetime, no ads, joiners free forever.
- **Decision rules, set now:** watch trial→paid for the first 500 households — holds ≥5% → end
  the $19.99 intro; drops <3% → the category anchor won, price ceiling is $14.99–19.99. If
  monthly churn disappoints: raise monthly to $3.99 or drop monthly — **never discount annual**.
- **Targets:** rating ≥4.7 · add-item ≤2 s/≤2 taps · trial→paid ≥5% · first renewal ≥50% ·
  invites/owner ≥1.5 · **≥40% of households enter or confirm a real price by trip 3** — the
  falsification line for the whole strategy.
- **Kill criteria:** 6 months post-launch with rating <4.5, or trial→paid <5%, or flat organic
  downloads → stop and reassess, don't add features.
- Store listing: title `Bagged: Shared Grocery List` (the long-tail search phrase itself),
  subtitle `Aisle order, prices, no ads` (fresh keywords; *share/family* are contested by three
  competitors and banned from our subtitle). Six screenshots, captions written as OCR'd keywords,
  #1 = the price total. Category: Shopping (thinner chart; Productivity is a reversible test).

---

## 7. What happens before architecture — three gates, in order

1. **The ten conversations** (`VALIDATION.md`) — ~8 hours against a 4–6 month build. Scoring is
   pre-committed: ≥5/10 know their last total AND ≥3 show a live tracking workaround → build.
   The ambiguous middle ("people like the idea, nobody has a workaround") demotes cost from
   positioning to feature. **This is the only remaining test of the premise itself.**
2. **Seed audit** — validate the 414×8 price seeds against 20 real receipts across 3 regions.
   Median error >~15% → ship observed prices only (an estimate 30% off is worse than no number).
3. **The unblockable admin** (parallel, zero engineering): Paid Applications Agreement + banking;
   buy `bagged.app` + handles; Class 9/42 trademark search with phonetic variants; stand up
   `support@` + privacy policy. Meanwhile `Core` + `Catalog` (resolver port, op-log + conflict
   harness) can start today — no Xcode signing, no design dependency.

---

## 8. Deprecations — where this document overrides the repo

| Superseded | By |
|---|---|
| `BRAND.md` §5 token values (paper `#F6F4F1`, ink `#1B1A18`, cool aisle tints) | §2 tokens (the built `F · Tokens` collection) |
| `BRAND.md` §5 / `ENGINEERING.md` §4 "emoji at v1, photos later"; `SOURCING.md` photo options; Tiimo-teardown "reconsider for emoji" | §2 imagery: **line-icon glyphs on tint, emoji fallback only** |
| Tiimo-teardown take #1 "serif for totals" | §2: prices are monospace; serif never in-app |
| `docs/V1_SCOPE.md` header "62 features" | §3: the honest count is **85** |
| `DECISIONS.md` open items: quantity placement, which-100-photos | §2 row anatomy (×N under name); photos rejected → moot |
| `RESEARCH.md` §6 $9.99/yr; `MARKET.md` early $14.99/yr and ~$59 lifetime musings | §6 pricing |
| `docs/DESIGN_HANDOFF.md` §1 "no competitor does this" | §1: banned claim; narrow to *no dedicated grocery app owns cost* |
| Old Figma pages `74:16` (59-screen spec) and `0:1` (concepts) as working surfaces | Page `138:978` is canonical; the others are quarries |

**Genuinely still human-owned (the only things not decided here):** whether the operating entity
is Brazilian (decides privacy-policy scope — policy will cover LGPD+GDPR+CCPA either way), and
executing the trademark/domain purchases. Everything else is closed.
