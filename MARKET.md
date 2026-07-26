# Market Research — Consumer Shopping List App

Research date: July 2026. Companion to `RESEARCH.md` (competitive/product) — this document
covers sizing, segments, unit economics, pricing, and acquisition.

Figures cited from sources are marked as such. Figures I derived are labelled **[model]** and
depend on stated assumptions — treat them as planning arithmetic, not measured data.

---

## 1. Market sizing

### The addressable universe

The relevant population is *not* online grocery buyers — everyone who buys groceries is a
candidate for a list app, including people who never shop online. Online grocery numbers are
useful as a proxy for **digital grocery behaviour**, which is what predicts app adoption.

| Layer | Figure | Source |
|---|---|---|
| US smartphone users regularly using shopping apps (2025) | 76.5% — ~164M people | ElectroIQ |
| US adults who bought groceries online (2025) | 51.8% — 148.4M | Capital One Shopping |
| US households that bought groceries online | 61% — ~81M homes | Capital One Shopping |
| Americans ordering groceries online (2026, projected) | 157.5M | Capital One Shopping |
| Global monthly online grocery consumers | ~1.4B | Mordor Intelligence |

**TAM** (global households with a smartphone that buy groceries): effectively the whole
smartphone-owning world — not a useful constraint. The binding constraint is distribution,
not market size.

**SAM** — English-speaking, digitally-active grocery households, US + UK + CA + AU:
**~100M households** **[model]**, anchored on the 81M US online-grocery households plus
comparable penetration in the other three.

> **Corrected by store evidence — `research/store-teardown.md` §11.** Listonic is *not* the
> volume leader on iOS in the US. App Store ratings: **OurGroceries 84K**, **AnyList 79K**,
> MinimaList 46K, Komorebi 29K, **Listonic 10K**. Listonic's 13M/20M figures are global and
> Android-weighted. For an iOS launch the competitors that matter are AnyList and OurGroceries,
> both of which lead on sharing and reliability rather than ads — which **demotes "ad-free" as
> the primary wedge on iOS** and promotes cost + aisle intelligence. Every app in the set rates
> **4.6–4.9**, so 4.7+ is a shipping gate, not an aspiration.

**SOM** — the honest one. Observed scale of actual competitors:

| App | Scale | Note |
|---|---|---|
| Listonic | 13M downloads, 20M+ claimed users, 50+ countries | Category volume leader, ad-funded |
| Bring! | ~3.6M MAU in DACH; 21M consumers incl. Profital | Regional leader, ~100 staff, VC-backed |
| AnyList | Not disclosed | 14 years old, small team, subscription |
| OurGroceries | Not disclosed | Long-running, subscription |

A well-executed new entrant with no paid acquisition should plan for **50k–250k downloads in
year one** **[model]**, reaching low-single-digit millions only with several years of
compounding ASO and word of mouth. Nothing in this category has gone viral quickly; the two
leaders took 10+ years to reach their current size.

**Conclusion: this is not a venture-scale market for a new entrant.** It is a credible
small-business or lifestyle-business market with a long compounding curve. Size the plan to
that reality.

---

## 2. Segments

Ranked by fit, from the demographic data:

### Primary — families with children under 18
- **168% more likely** to shop online than households without children; ~43% of parents
  regularly use digital grocery platforms (Martech Zone).
- Structurally the best segment: multiple people, one list. Sharing is a *need*, not a
  feature — which makes them the engine of the invite loop.
- Highest grocery spend: family of four averages ~$920/month (~$11k/yr).

### Primary — ages 35–54
- **41% of monthly online grocery shoppers** (Martech Zone). Overlaps heavily with the above.
- Peak household formation, peak grocery spend, peak willingness to pay for time savings.

### Secondary — couples and roommate households
- Two-person coordination, ~$580/month spend. Sharing still matters; urgency is lower.

### Watch, don't target — Gen Z (15–24)
- 83% mobile grocery adoption, but only ~26% bought groceries online in the past 30 days,
  and low grocery spend and low willingness to pay for utilities.
- Good for organic growth and word of mouth; bad for revenue. Don't build the paywall for them.

### Ignore — 55+
- Only ~12% bought groceries online in the past 30 days. Lowest digital adoption in the data.
  Not worth optimising for at MVP.

Skew slightly female (women shop for groceries online slightly more than men), and adoption
rises steeply with education (10% of those without a high-school diploma vs 26% with advanced
degrees).

**Targeting conclusion:** build for a 35–54 parent coordinating a household. Every design
decision — sharing, aisle order, trip total — serves that person.

---

## 3. Unit economics — the uncomfortable part

This is the most decision-relevant section, and it partially challenges the pricing in
`RESEARCH.md`.

### Benchmarks

| Metric | Benchmark | Source |
|---|---|---|
| Freemium Day-35 trial-to-paid conversion | **2.1% median** | RevenueCat / Adapty |
| Hard-paywall Day-35 trial-to-paid | **10.7% median** | RevenueCat / Adapty |
| Hard paywall LTV vs soft | +21% | RevenueCat |
| Soft paywall conversion-rate advantage | ~+50% on rate alone | RevenueCat |
| Onboarding paywall w/ trial, market average | 1.35% | Adapty |
| **Utilities first-renewal retention** | **58.1% — highest of all categories** | RevenueCat |
| Long trials (17–32 days) trial-to-paid | ~42.5% vs 25.5% for <4-day trials | Business of Apps |
| Productivity Day-30 retention, top quartile | 12–18% | UXCam / industry |
| All-category retention | ~26% D1, ~13% D7, ~7% D30 | Industry composite |

### What that means at the $9.99/yr price in `RESEARCH.md` **[model]**

Assuming 100,000 downloads, freemium (free sharing, no forced trial), Apple/Google small-business
rate of 15%:

| Line | Value |
|---|---|
| Downloads | 100,000 |
| Paying at 2.1% freemium conversion | ~2,100 |
| Gross at $9.99 | ~$21,000/yr |
| Net after 15% store fee | **~$17,800/yr** |

> **Corrected — see `research/competitors.md` §7.** This model is **single-cohort, and that is
> the error.** Subscriptions stack: year 3 revenue comes from the year 1, 2 and 3 cohorts minus
> churn. Re-modelled at 100k downloads/yr sustained, 3% conversion, $24.99 and 58% renewal, it
> reaches ~$64k net in year 1 and ~$140k by year 5 for one person. And the real-world check:
> **AnyList earns an estimated $840k–960k/yr from a small team on a $9.99–14.99 subscription
> while not advertising actively.** The conclusion below is too pessimistic — this is a credible
> one-to-two-person business with a 3–5 year ramp, not a side project.

That is not a business. It's a side project. **This is precisely why Listonic sells banners
and Bring! sells retail media** — at category-normal conversion rates, a cheap subscription
does not clear meaningful revenue until you have millions of users, and those two took a
decade to get there.

### The three levers

**1. Price.** $9.99/yr is anchored to competitors, not to value. Consider the value frame:
the average US household spends **$5,750–6,240/yr on groceries** and wastes
**$1,500–2,900/yr in food** (BLS; EPA; ReFED). A $24.99/yr subscription is **0.4% of grocery
spend** and needs to prevent roughly *one bag of spoiled produce per year* to pay for itself.
The category has trained users to expect $8–15, but the category is also underpriced relative
to what it touches.

At $24.99 and the same 2.1%: ~$52,500 gross, ~$44,600 net **[model]**. Still small, but 2.5×.

**2. Paywall model.** Hard paywall converts ~5× better (10.7% vs 2.1%). But a hard paywall
kills the invite loop, which is the entire growth engine in a *shared* list app — this is the
central strategic tension.

**Resolution: paywall the list owner, never the joiner.** The person who creates and owns
lists hits a trial and then a paywall; anyone invited to a list is free forever, with no
account required. This preserves the viral loop exactly (invitees are the viral surface, and
they cost nothing) while putting the household's decision-maker — the 35–54 parent, the one
who actually values it — on the converting path. Pair it with a **long trial (17–32 days)**,
which benchmarks at ~42.5% trial-to-paid versus 25.5% for short trials, and which conveniently
spans 3–4 grocery trips — enough for the habit to form.

**3. Retention is the one thing working in your favour.** Utilities lead every category in
first-renewal retention at **58.1%**, and a grocery list is tied to a real weekly recurring
behaviour rather than a New Year's resolution. If you can beat the 12–18% top-quartile
productivity D30 retention — and a weekly-habit app should — LTV compounds unusually well here.

### Revised recommendation

Move from "$9.99/yr freemium" to:

- ~~$19.99–24.99/yr household~~ — **superseded, see `PLAN.md` §4. Decided: $2.99/mo or
  $14.99/yr**, subscription only. The value-framing argument below is sound in theory, but
  AnyList earns ~$900k/yr at $9.99–14.99 while OurGroceries earns ~$360k at $7.99 on *more*
  ratings — so small pricing works, and the top of the small band is where to sit.
  A **~21-day free trial** on the owner path still applies.
- **Free forever for invited members**, no account required.
- ~~Optional lifetime tier (~$59)~~ — **retracted, see `PLAN.md` §1.** OurGroceries' $20
  lifetime is beloved *and* visibly caps them at ~$360k/yr against AnyList's ~$900k on
  comparable ratings. In a business whose whole model is stacked cohorts, selling a permanent
  seat for one year's price is self-harm.

This keeps the consumer positioning from `RESEARCH.md` intact — no ads, no brand data sales —
while acknowledging that a $9.99 freemium plan mathematically cannot fund the product.

---

## 4. Acquisition

Paid acquisition is not viable: with a sub-$25 annual price and ~58% first-renewal retention,
LTV is roughly $30–40 **[model]** — below realistic install costs for a competitive consumer
utility keyword. **Organic search is the only channel that works at this price point.**

The data supports it: **65–70% of app downloads begin with a store search**, and apps in the
**top 3 for a high-volume keyword capture over 50% of all clicks** for that term (ASO industry
sources, 2026).

- **Head terms** — "shopping list", "grocery list". Highest volume, and where incumbents are
  entrenched. Not winnable at launch, but the long-term prize.
- **Long-tail is the 2026 opening.** ASO guidance is explicit that longer, specific phrases
  face less competition and convert better. The gaps found in `RESEARCH.md` map directly onto
  long-tail terms nobody owns: **"shared grocery list"**, **"grocery list with prices"**,
  **"family shopping list app"**, **"grocery list no ads"**, **"grocery budget list"**.
- The "no ads" angle is both a positioning wedge *and* a keyword — Listonic's banner-heavy free
  tier has created active search demand for alternatives.

Secondary channels: the invite loop itself (every shared list is a distribution event — treat
the invite screen as an acquisition surface, per Instacart's "Family cart"), and content/SEO
against grocery-budgeting queries feeding the app.

---

## 5. Risks

1. **Commodity category.** The core feature is trivially cloneable and there are dozens of
   free options including Google Keep and Apple Reminders. Defensibility comes only from
   accumulated personal data — your price book, your store aisle order, your household. Build
   the data moat early or there isn't one.
2. **Incumbent inertia.** AnyList (14 years) and OurGroceries have deeply habituated users
   with years of list history. Switching costs are real and they run against you.
3. **Price ceiling set by competitors.** The $8–15/yr anchor is established. Charging $25
   requires visibly more value — which is why the spend-tracking and pantry features aren't
   optional extras but the justification for the price.
4. **The math may simply not clear.** At realistic year-one scale (50–250k downloads
   **[model]**) even the revised pricing yields roughly $20k–110k/yr net **[model]**. Viable
   for one or two people; not for a funded team. Decide up front which this is.
5. **Retailer/API dependency** — already ruled out in `RESEARCH.md`; re-flagged because live
   price data is the feature most likely to tempt you back into a corporate dependency.

---

## 6. Read

The market is real, growing, and structurally underserved on two specific axes (spend
visibility, genuinely ad-free sharing). The segment is identifiable and reachable through
organic search. Retention economics in this category are the best of any app vertical.

But it is a **slow-compounding, small-revenue market with commodity dynamics**, and the two
highest-volume players monetise in a way you've decided not to. Build it as a
craft/lifestyle product with a decade-long horizon, priced honestly at $20–25/yr, monetising
the household's organiser rather than everyone in it — or don't build it.

---

## Sources

- [Shopping Application Statistics by User Demographics (2025) — ElectroIQ](https://electroiq.com/stats/shopping-application-statistics/)
- [The Online Grocery Shopper in 2025: A Demographic Deep Dive — Martech Zone](https://martech.zone/demographics-online-grocery-shopper/)
- [Grocery Shopping Statistics (2026): Behavior & Demographics — Capital One Shopping](https://capitaloneshopping.com/research/grocery-shopping-statistics/)
- [Online Grocery Shopping Statistics (2026) — Capital One Shopping](https://capitaloneshopping.com/research/online-grocery-shopping-statistics/)
- [Online Grocery Market Size & 2031 Trends — Mordor Intelligence](https://www.mordorintelligence.com/industry-reports/online-grocery-market)
- [State of Subscription Apps 2026 — RevenueCat](https://www.revenuecat.com/state-of-subscription-apps)
- [Subscription app trends and benchmarks for 2026 — RevenueCat](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)
- [In-app subscription benchmarks for Utilities apps 2026 — Adapty](https://adapty.io/blog/utilities-app-subscription-benchmarks/)
- [App Subscription Trial Benchmarks (2026) — Business of Apps](https://www.businessofapps.com/data/app-subscription-trial-benchmarks/)
- [Mobile App Retention Benchmarks by Industry (2026) — UXCam](https://uxcam.com/blog/mobile-app-retention-benchmarks/)
- [Mobile App Retention in 2026 — Userpilot](https://userpilot.com/blog/mobile-app-retention/)
- [App Store keyword research for ASO: 2026 guide — AppTweak](https://www.apptweak.com/en/aso-blog/app-store-keyword-research-aso)
- [App Store Optimization in 2026: Strategy, Trends, Best Practices — ASOMobile](https://asomobile.net/en/blog/aso-in-2026-the-complete-guide-to-app-optimization/)
- [Average Grocery Spending in America (2026) — Wealthvieu](https://wealthvieu.com/personal-finance/cost-of-living/average-grocery-spending/)
- [Average Grocery Cost per Month: The 2026 Breakdown — Instacart](https://www.instacart.com/company/ideas/average-grocery-cost-per-month)
- [Estimating the Cost of Food Waste to American Consumers — US EPA (PDF)](https://www.epa.gov/system/files/documents/2025-04/costoffoodwastereport_508.pdf)
- [ReFED US Food Waste Report 2026](https://refed.org/food-waste/refed-us-food-waste-report-2026/)
- [Food Waste in America in 2026 — RTS](https://www.rts.com/resources/guides/food-waste-america/)
