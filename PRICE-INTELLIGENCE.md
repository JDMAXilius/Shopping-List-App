# Price intelligence — the personal price book

The feature set that turns the cost wedge into a moat: **spend tracking → a personal price book →
store comparison → a cheapest-basket suggestion.**

---

## 1. The category already exists, and it has one shared weakness

| App | How it gets prices | Its failure mode |
|---|---|---|
| **Flipp** | Aggregates retailer weekly flyers | Shows what's **on sale**, not what's cheapest. Depends on retailers uploading. Local chains often absent |
| **Basket** (basketsavings.com) | **Crowdsourced**, gamified with gift-card incentives | Accuracy depends on whether someone near you scanned recently. *"Pasta shows $2.99, but if nobody scanned in two weeks it could be $3.49."* Thin outside cities |
| **GroceryChop** | Live prices scraped from 100+ US chains | Coverage is national chains only; no local or independent stores |

**All three depend on other people's data — flyers, crowds, or scraping — and all three fail the
same way: staleness and coverage gaps.** And the industry's own conclusion is the opening:

> **"There is no single winner — the cheapest store depends on your specific basket."**

That sentence is the whole feature. A generic comparison can't answer it. **A personal one can.**

## 2. Why ours is structurally different

**We use the user's own receipts.** Nobody else's data enters the price book.

| | Ours | Theirs |
|---|---|---|
| Accuracy | **What you actually paid.** Cannot be stale in the way a crowd feed is | Depends on strangers and flyer uploads |
| Coverage of *your* stores | **100% of stores you shop**, including the corner shop nobody scrapes | National chains only |
| Legal / technical exposure | **None** — no scraping, no retailer API, no ToS risk | Scraping and flyer licensing |
| Incentive problem | **None** — you scan for yourself | Must pay users to contribute |
| **Cold start** | ❌ **Brutal. You know nothing until receipts exist** | ✅ Useful on day one |
| Stores you've never visited | ❌ **Nothing** | ✅ Covered |

**The last two rows are the real cost, and the design has to solve them rather than hide them.**

## 3. Cold start — the honest answer

Three tiers, and the app must always say which one it's in:

| Stage | What exists | What we show |
|---|---|---|
| **Trip 1** | Seeded estimates only (`price_seed`, 414 items × 8 regions) | A total with `≈`. **No store comparison at all** — don't fake it |
| **Building** | 1 store, some receipts | Real prices replacing estimates at that store. Still no comparison |
| **Comparing** | **≥2 stores × ≥1 receipt each, and ≥60% basket coverage** | Store comparison, with the coverage stated on the face of it |

> **Rule: never show a comparison we can't back.** If 12 of 18 items have real prices at Walmart
> and 9 of 18 at Target, the screen says so. A confident wrong answer here destroys the one thing
> the brand is built on.

## 4. The four features

### 4.1 Spend, from estimates then corrected by receipts

Already specced (`FEATURES.md`). The addition: **every scanned receipt writes
`price_observation` rows and permanently replaces the estimate for that (item, store).** The
Spend screen shows the mix — *"34% from receipts, 66% estimated"* — so the user can see their own
data getting better, which is the loop that makes them keep scanning.

### 4.2 Store comparison — "this list, at your stores"

Take the current list. For each store with sufficient coverage, compute the basket total.

```
basket(S)   = Σ price(item, S) for items with an observation at S
coverage(S) = items priced at S / items on list
```

Rank by total, show coverage on every row, fall back to the seeded estimate for gaps **and mark
which lines are estimated**.

### 4.3 The cheapest split — "want me to build the cheapest version?"

For each item, find the cheapest store that has it. Sum the minimums. Then — and this is the part
the competition skips — **price the inconvenience:**

> **Cheapest split: $71.40 across 2 stores — saves $12.60 but adds a second stop.**
> **Cheapest single store: Walmart, $78.20 — saves $5.80, one trip.**

**Always show the single-store answer alongside the split.** Most people will take one stop, and
an app that only optimises money is quietly telling them they're doing it wrong.

### 4.4 The nudge — "some of these are cheaper elsewhere"

When a list is assigned to a store, quietly surface what that costs:

> *"4 of these are cheaper at Costco — about $6.20 less. See them?"*

**Rules that keep this from becoming nagging** (`INTERACTION.md` §2):

- **One line, never a modal.** Inline, dismissible, and it does not come back for that list
- **Only when the saving clears a floor** — under ~$3 or under ~5%, say nothing
- **Never implies a mistake.** *"Cheaper at Costco"*, never *"you're overpaying"*
- **A setting turns it off permanently**, and turning it off is not punished

## 5. Data model — mostly already there

`price_observation(item_id, item_name, store_id, amount, currency, unit, observed_at, source,
household_id)` already supports all of this. Three additions:

```sql
ALTER TABLE store ADD COLUMN chain_id TEXT;   -- 'walmart' vs "Walmart #2371"
ALTER TABLE store ADD COLUMN travel_minutes INTEGER;  -- for pricing the second stop

CREATE VIEW current_price AS                  -- latest observation per (item, store)
  SELECT item_id, store_id, amount, currency, observed_at,
         COUNT(*) OVER (PARTITION BY item_id, store_id) AS n_obs
  FROM price_observation …;
```

**Confidence per price** = freshness × observation count:

| Age | Treatment |
|---|---|
| < 30 days | Solid ink. Trusted |
| 30–90 days | Solid, with the date on the detail screen |
| > 90 days | **Reverts to `~` grey.** Old data is an estimate again |

This matters more than it looks: **grocery prices moved enough in 2025–26 that a six-month-old
observation is not a fact.** Treating stale observations as estimates keeps the honesty promise
mechanically true instead of aspirationally true.

## 6. Where AI fits — and it's smaller than it looks

Almost all of this is **arithmetic and SQL, not a model.** Ranking baskets, finding minimums,
computing coverage — plain code, instant, offline, free.

Claude does exactly one job here: **turning a receipt photo into line items with prices.** That's
the input to everything above, and it's already specced and costed at ~$0.22–1.08/subscriber/year.

**Say it in the interface accordingly.** "Your prices, from your receipts" is a stronger claim
than "AI-powered savings", it's true, and it doesn't invite comparison to apps with a hundred
scraped chains.

## 7. Risks

1. **⚠️ Cold start makes the flagship feature invisible for weeks.** Somebody who shops one store
   never sees a comparison at all. **Mitigation:** the value ladder must stand on its own at every
   rung — trip totals are useful before any comparison exists
2. **⚠️ Same-item matching across stores is harder than it sounds.** "Oat milk" at Trader Joe's is
   not the same SKU as at Costco, and sizes differ. **Mitigation:** compare at the **generic
   catalog item** level and **normalise to unit price** where the unit is known. Say "per litre"
   on the face of it, or the comparison is a lie
2. **Receipt OCR errors poison the price book.** A misread `$18.99` for `$1.89` corrupts a
   comparison. **Mitigation:** show the parsed receipt for confirmation before committing, and
   flag any line more than 3× the seeded estimate
3. **Scope.** This is v1.2–v2 territory, not v1.0. It depends on receipt scanning, which depends
   on the subscription, which depends on shipping the list first
4. **Basket already does this** with crowdsourced data and has for years. We are not first — we
   are **personal and accurate instead of broad and stale.** That's the pitch, and it should be
   tested in the ten conversations (`VALIDATION.md`) before it's built

## Sources

- [Basket vs Flipp vs GroceryChop](https://grocerychop.com/blog/basket-vs-flipp-vs-grocerychop)
- [Basket Savings](https://basketsavings.com/)
- [Best grocery price tracking apps 2026](https://savingsgrove.com/blogs/guides/best-grocery-price-tracking-apps)
- [Grocery store price comparison 2026](https://grocerychop.com/blog/grocery-store-price-comparison/)
