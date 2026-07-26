# Positioning & Go-to-Market Plan

Built on `research/competitors.md` (scale and money), `research/store-teardown.md` (store
evidence), `MARKET.md` (economics), `BRAND.md` + `NAMING.md` (identity), `RESEARCH.md` (product).

This is the plan of record. Where it contradicts an earlier document, this wins.

---

## 1. The strategy in one page

**The bet.** AnyList earns ~$840k–960k/yr from a small team on a $9.99–14.99 subscription while
"not advertising actively," and has spent 14 years not shipping prices. OurGroceries holds 84K
ratings at 4.8★ and also has no prices, capped at ~$360k/yr by a $7.99 price and a $20 lifetime
tier. MinimaList — a *to-do* app — proved demand for cost tracking and took 46K ratings with it.

**So: own cost in the grocery category, price properly, and don't fight AnyList on recipes.**

| | Decision |
|---|---|
| **Category position** | The grocery list that knows what the trip costs |
| **Do not contest** | Recipes and meal planning (AnyList, 14 years, 4.9★) · deals and coupons (Listonic, Bring!) · cheapest-in-category (OurGroceries) |
| **Primary wedge** | Cost visibility — per-item, per-category subtotal, trip total, price history |
| **Secondary wedge** | Learned per-store aisle order |
| **Values, not headlines** | Ad-free · offline-first · data not sold |
| **Price** | **$24.99/yr household**, ~21-day trial, owner pays, joiners free forever, no lifetime tier |
| **Platform** | iOS-first (that's where the money and the ratings are) |
| **Target** | 35–54 parent coordinating a household |
| **Success** | 4.7★ minimum; break-even on one person's time by year 2 |

### Why "ad-free" is demoted

`BRAND.md` made ad-free the marketing wedge. The store data killed that: the ad-heavy
competitor (Listonic) has **10K US iOS ratings against AnyList's 79K**. On iOS you'd be shouting
about an opponent your buyer has never met. Ad-free stays a real commitment and a keyword —
it stops being the headline.

### Why no lifetime tier

`MARKET.md` suggested testing one. Retract that. OurGroceries' $20 lifetime is beloved *and* is
visibly holding them at half of AnyList's revenue on comparable ratings. In a business whose
whole model is stacked cohorts, selling a permanent seat for the price of one year is
self-harm.

---

## 2. Rebrand

### 2.1 Name — decide this first

Nothing else can be finalised until a name clears. From `NAMING.md`:

| Rank | Name | Case | ASO title |
|---|---|---|---|
| **1** | **Bagged** | Grocery-native *and* the check-off word — "bagged it." Reads as groceries with no subtitle help, which frees the subtitle entirely. No App Store collision found. | `Bagged: Shared Grocery List` |
| **2** | **Dozen** | Warmest and most sayable; grocery-native via "a dozen eggs." More ownable because less obvious. | `Dozen: Shared Grocery List` |
| 3 | **Sundry** | Most precisely apt ("sundries" = small goods). Some will hear "Sunday." | `Sundry: Shared Grocery List` |

**Recommendation: screen Bagged and Dozen simultaneously; ship whichever clears.** They cost the
same to check and either supports this positioning.

**Action, week 1, before any other spend:** USPTO **Class 9 and 42**, phonetic variants
included; common-law search; both app stores; `.com` and `.app`; social handles. Expect one to
fail. Do not commission a wordmark, buy a domain, or write store copy until one clears.

### 2.2 Positioning statement

> For the parent who runs a household's food, **[Name]** is the shared grocery list that shows
> what the trip costs and learns your store — the two things AnyList and OurGroceries have never
> built.

### 2.3 Messaging hierarchy

Every asset leads with one of these, in this order:

1. **"Know what the trip costs."** — per-item prices, category subtotals, trip total
2. **"Sorted the way your store is."** — learned aisle order per store
3. **"Everyone's list, one list."** — household sharing, no account to join
4. **"Works with no signal."** — offline-first
5. **"No ads. Not now, not later."** — the value, stated once, not led with

Banned from all copy: **"nobody does this"** (MinimaList does — `store-teardown.md` §10) ·
**"smart"** · **"AI"** as a headline claim (table stakes since Listonic put it on their lead
screenshot) · **share** and **family** as the subtitle's main keywords (three of five
competitors already own them).

### 2.4 Visual identity — confirmed and corrected

Keep from `BRAND.md`: warm paper base `#F6F4F1`, warm ink `#1B1A18`, persimmon `#C9502C` for
action, green `#1F7A4D` **semantic only** (done / verified price), category tints for group
pills, system type in-app, dark mode required.

Corrections from the evidence:

- **The paper base is the differentiator, not the accent.** Every competitor sits on a saturated
  field — mint, teal, magenta, blue, crimson. Persimmon is in the same family as Bring!'s and
  the teal app's corals.
- **Item imagery is an open decision, not settled.** AnyList and OurGroceries both use real
  product photography. Emoji ships v1; treat a commissioned icon set as a funded upgrade once
  revenue exists, and never let a tile carry meaning the text label doesn't.
- **Mascot: still no** — but knowingly. Listonic's caped broccoli is Apple-featured at 4.7★.
  We decline because the brand's credibility rests on being straight about money.

### 2.5 What "rebrand" concretely means here

Nothing is shipped yet, so this is a *first* brand, not a repair. The work:

- [ ] Name cleared (§2.1) — **blocks everything below**
- [ ] Wordmark + app icon (persimmon field, single ink mark, no text/gradient/photo)
- [ ] `design/brand-sheet.html` re-rendered off the placeholder "Errand"
- [ ] Colour tokens and type scale committed as code, not a document
- [ ] One-page voice guide from `BRAND.md` §4 for microcopy review

---

## 3. Product plan

Sequenced so the differentiator is real at launch rather than promised.

### v1.0 — the wedge, complete

Non-negotiable, because the positioning depends on it:

- Fast add: ≤2 taps, ≤2s, autocomplete ranked personal → household → catalog (built:
  `data/catalog/`, 414 items, resolver passing 23 cases)
- One-thumb check-off, undo, checked items sink
- Aisle grouping; per-store profiles with drag-to-reorder
- Shared lists, **join by link with no account**
- Full offline, sync on reconnect
- **Cost: per-item price, per-category subtotal, trip total** — seeded estimates so it works on
  trip one, grey `~` for estimates vs solid ink for observed, `≈` on the total
- Quantity as a first-class field
- Dark mode
- Lock-screen + Home Screen widget with **tappable checkboxes** (Komorebi ships this; it's table
  stakes, not a differentiator)

### v1.1 — close the honesty loop
Barcode scan via Open Food Facts · price editing and history · learned aisle order from
check-off sequence · recurring staples

### v1.2 — the moat
**Receipt scan → price book.** Turns estimates into observed prices in one photo. Timeline risk:
Listonic already ships handwriting→list OCR, the same pipeline. The defensibility is the
accumulated history, not the capability — so start accumulating early.

### v2 — optional, only if retention holds
Pantry loop · predictive restock · multi-store split · recipe import (late and deliberately
unambitious — do not fight AnyList here)

### Explicitly not building
Coupons or deals · retailer/brand dashboards · calories or wellness scoring · assignees, due
dates, workspaces · a retailer price API integration (`RESEARCH.md` §5)

---

## 4. Pricing

| | |
|---|---|
| Free forever | Unlimited lists, unlimited household members, offline sync, aisle grouping, **seeded price estimates** |
| Paid — **$24.99/yr** | Observed price history, receipt scan, multiple store profiles, spend trends, recipe import |
| Trial | **21 days** on the owner path (17–32 day trials benchmark 42.5% trial-to-paid vs 25.5% for short ones) — and 21 days spans 3–4 grocery trips, long enough for the habit |
| Joiners | **Free forever, no account.** The invite loop is the growth engine; taxing it kills growth |
| No lifetime tier | See §1 |

Value framing for the paywall copy: a household spends **$5,750–6,240/yr** on groceries and
wastes **$1,500–2,900/yr** in food. $24.99 is **0.4% of grocery spend**.

Justification for pricing above the $8–15 category anchor: nobody else sells cost visibility.
You are not a cheaper AnyList; you are a different product.

---

## 5. Go-to-market

Organic only. LTV is ~$30–40; no consumer-utility keyword clears that on paid.

### 5.1 ASO — the whole marketing budget

| Field | Value | Notes |
|---|---|---|
| Title | `Bagged: Shared Grocery List` | 27/30. Brand + two head terms |
| Subtitle | `Aisle order & trip totals` | 25/30. **Fresh keywords** — no reuse of title words, and deliberately avoids *share*/*family* |
| Keywords | `price,budget,spending,receipt,pantry,checklist,offline,supermarket,store,household,no ads,cost` | ≤100 chars, zero overlap with title/subtitle |

Head terms ("grocery list", "shopping list") are unwinnable at launch. Target the long tail that
maps to the gaps: **grocery list with prices** · **grocery budget list** · **grocery list no
ads** · **shared grocery list** · **grocery spending tracker**.

Top-3 for a keyword takes >50% of its clicks. Long tail first, head terms in year 2.

### 5.2 Screenshots

Captions are OCR-indexed by Apple, so they're ranking signal and conversion copy at once. Caption
first, UI second — seven seconds of attention.

1. **"Know what the trip costs."** — list with subtotals + total
2. **"Sorted the way your store is."** — aisle-grouped
3. **"Everyone's list, one list."** — household avatars, attribution
4. **"Works with no signal."** — offline
5. **"Your prices, not a guess."** — observed vs estimated
6. **"No ads. Not now, not later."**

Test with Apple PPO, one variable at a time. Never rewrite title, subtitle and screenshots
together — you learn nothing.

### 5.3 Store category

Genuinely split: AnyList and MinimaList in **Productivity** (#197, #198 — adjacent, so that
chart neighbourhood is visible and winnable); OurGroceries, Komorebi, Opulogic in **Shopping**.

Launch in **Shopping** (thinner, easier to chart), then test Productivity once ratings are
established. This is a reversible setting — treat it as an experiment, not a decision.

### 5.4 Editorial featuring — the only free distribution at scale

Apple featured Listonic in 2026, so the category is live for editorial. Design to be featurable:
- Ship widgets, Dynamic Type, VoiceOver, dark mode — Apple features apps that use platform APIs
- Privacy nutrition labels as a *selling point*, filled honestly and prominently
- Pitch App Store editorial at launch and at each significant release

### 5.5 The invite loop

The only compounding channel. Every shared list is a distribution event.
- Join by link, no account, no app-store detour before seeing the list
- Invite screen framed warmly — Instacart's "Family cart" is the model
- Measure **invites sent per owner** and **join-to-active rate** as primary growth metrics

### 5.6 Content
A small set of pages targeting grocery-budget queries, each ending in the app. Low cost, slow
compounding, aligned with the cost positioning.

---

## 6. Sequence

| Phase | Work | Gate to pass |
|---|---|---|
| **0 — Clear the name** | USPTO 9/42, common-law, stores, domains, handles | One name clears |
| **1 — Foundations** | Expo + SQLite + Supabase behind a repository layer; catalog integrated; sync queue | Add→check→sync works offline, two devices |
| **2 — The wedge** | Prices, subtotals, trip total, estimate rendering; aisle grouping and store profiles | Trip total is credible on trip one with zero user input |
| **3 — Brand + store** | Wordmark, icon, 6 screenshots, listing copy, privacy labels | Passes the 40px/greyscale/next-to-Instacart icon test |
| **4 — Soft launch** | One market, invite-loop instrumentation, crash and rating watch | **4.7★ sustained** over 100+ ratings |
| **5 — Scale** | Long-tail ASO, PPO tests, editorial pitch, v1.1 | Organic downloads growing without spend |

**Kill criteria, set now while it's cheap to be honest:** if after 6 months of phase 5 the
rating sits below 4.5, or trial-to-paid is under 5%, or organic downloads are flat — stop and
reassess rather than adding features. The competitors' 4.6–4.9 ratings mean a mediocre app has
no room here.

---

## 7. Numbers to steer by

From `research/competitors.md` §7 **[model]**: 100k downloads/yr, 3% conversion, $24.99, 58%
renewal → ~$64k net year 1, ~$122k year 3, ~$140k year 5, one person. AnyList's actuals say the
ceiling is 5–6× that.

| Metric | Target | Why |
|---|---|---|
| Rating | **≥4.7** | Category runs 4.6–4.9 |
| Add-item time | ≤2s, ≤2 taps | The core loop; everything else is decoration |
| Trial → paid | ≥5% | Below the 10.7% hard-paywall median, above freemium's 2.1% |
| First renewal | ≥50% | Utilities benchmark is 58.1% |
| Invites per owner | ≥1.5 | The growth engine |
| Households with a price entered by trip 3 | ≥40% | If this fails, the wedge isn't landing |

---

## 8. Risks, ranked

1. **The name doesn't clear.** Most likely single point of failure. Mitigate by screening two in
   parallel and refusing to spend before clearance.
2. **AnyList ships prices.** They've had 14 years and haven't — but a 4.9★ team with revenue
   could do it in a quarter. Mitigation is the accumulated price book, which they'd start from
   zero on, and speed.
3. **Cost tracking doesn't retain.** Users may not enter prices even with seeded estimates.
   This is why "households with a price by trip 3" is a headline metric — it's the falsification
   test for the whole strategy.
4. **$24.99 rejected** by a category trained on $8–15. Test $19.99 against $24.99 early.
5. **Receipt-scan window closes** — Listonic's existing OCR pipeline makes this a quarter's work
   for them.
6. **One-person bandwidth.** Six phases is 12–18 months solo. Scope is already cut to the wedge;
   cut v2 entirely before cutting v1's cost features.

---

## 9. Decide these to unblock

1. **Bagged or Dozen** — screen both, but state a preference now
2. **iOS-only or Expo cross-platform** — the open architecture fork; iOS-only is faster to
   4.7★, Expo is cheaper to reach Android where Listonic is strong
3. **$19.99 or $24.99**
4. **Store category at launch** — Shopping recommended
5. **Is this a one-person business or a funded one** — the numbers only support the former
