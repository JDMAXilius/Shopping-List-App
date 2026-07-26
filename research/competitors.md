# Competitor dossier — features, scale, and money

Research date: July 2026. Companion to `research/store-teardown.md` (store listings).

> **On the numbers.** Apple and Google publish neither downloads nor revenue. Everything below
> is **third-party modelled estimate** — Sensor Tower, Apptopia, Trend Apps, Growjo,
> RocketReach — and they disagree with each other, sometimes badly. Treat magnitudes as
> meaningful and precise figures as not. Where a source is unreliable I say so rather than
> laundering it into a table.

---

## 1. The money, at a glance

| App | Est. downloads / mo | Est. revenue / mo | Implied / yr | Model | Source |
|---|---|---|---|---|---|
| **AnyList** | 30–40k | **$70–80k** | **~$840k–960k** | Subscription | Sensor Tower, Dec 2025 |
| **OurGroceries** | ~19k (10k iOS + 9k Android) | ~$30k ($10k iOS + $20k Android) | ~$360k | Subscription | Trend Apps |
| **Listonic** | not found | — | **~$5M/yr** | ~90% ads | Growjo, 2026 |
| **Bring!** | not found | — | see §5 | Retail media | — |

**Lifetime downloads:** OurGroceries ~2.9M (Apptopia). Listonic claims 15M+ users and 1M+
downloads in Poland alone.

### The single most important number here

**AnyList earns roughly $840k–960k/yr from a small team, on a $9.99–14.99 subscription, while
"not being advertised actively."** No ads, no retail media, no venture treadmill — a
subscription grocery list app supporting a business at close to seven figures.

That is the existence proof for the model this project has chosen. It also means my
`MARKET.md` §3 conclusion was too pessimistic — see §7.

---

## 2. AnyList — the one to beat

**Purple Cover, Inc.** (California) · 79K US iOS ratings, **4.9 ★** · #197 Productivity ·
launched 2012 · title `AnyList: Grocery Shopping List`, subtitle `Recipe Keeper & Meal Planner`

**Does:**
- Shared lists with real-time sync; the store page leads on *"Share Lists and Stay in Sync with
  Family & Friends"*
- **Recipe keeper + meal planner** — their actual differentiator, and it's in the subtitle
- Recipe provenance on items: `Sweet Potatoes (1 lb) — for Roasted Sweet Potatoes`
- **Per-item store tagging**: `Salmon — Trader Joe's`
- **Real product photography** per item, not emoji
- Category grouping with headers; `5 of 6 items remaining`
- Favourites, recents, filter, and an eye/hide toggle
- **`Order Pickup or Delivery`** — retailer handoff already shipped
- `Share, Email & Print List`
- Multiple list types: grocery, to-do, gift ideas, movies, packing
- Siri/voice input; web app (paid tier)

**Doesn't:**
- No prices, no trip total, no spend history — confirmed absent from marketing and from the
  long-standing feature complaints
- No pantry inventory or expiry tracking
- No receipt scanning
- No learned aisle order from behaviour (manual category ordering only)
- Paywalls the web app, meal planning, recipe scaling, photo attachments

**Read:** the strongest product and the strongest ratings in the category, monetising properly.
They own *recipes + meal planning*, not cost. Their weakness is that they've had 14 years to add
prices and haven't.

---

## 3. OurGroceries — the reliability play

**OurGroceries, Inc.** (headcode) · 84K US iOS ratings, **4.8 ★** · ~2.9M lifetime downloads ·
title `Our Groceries Shopping List`, subtitle `Share lists easily with family`

**Does:**
- Household sharing with instant cross-device sync — the entire pitch
- Category/aisle grouping, per-item notes (`apples — Honeycrisp or Envy`)
- **Photo attachments on items**
- Recipes with ingredient lists → add to list
- Light and dark mode, shown side by side in marketing
- Cheapest paid tier in the category: **$7.99/yr, ~$20 lifetime**

**Doesn't:**
- **No price or spend tracking** — users have asked for years; the single most-cited gap
- No meal planning, no pantry, no receipt scan, no learned aisle order
- Deliberately minimal feature surface

**Read:** ~$360k/yr on the cheapest price point in the category and 84K ratings — the volume
leader on iOS ratings but the weakest monetiser per user. Their $20 lifetime tier is loved and
is a structural drag on revenue. **The clearest demonstration that under-pricing caps a good
product.**

---

## 4. Listonic — the ad machine

**Listonic sp. z o.o.**, Łódź, Poland · 15+ years old · 10K US iOS ratings, 4.7 ★ ·
distributed via **MWM** (`spark.mwm.ai`), a French app publisher — worth verifying whether
that's a publishing deal or an acquisition

**Scale and money:** ~**$5M/yr**, **profitable for many years**, ~**50% YoY growth** (Growjo).
15M+ users; #1 shopping list on Android in **46 countries**; 1M+ downloads and 300k+ MAU in
Poland alone. **~90% of revenue from banner ads.**

**Does:**
- Free shared lists, aisle grouping, quantities and notes
- **"With AI"** as its headline claim
- **Handwriting/photo → list** OCR ("Turn any photo into a list")
- Voice input; 40+ languages
- **Apple "This Week's Favourites — Apps We Love 2026"** editorial feature

**Doesn't:**
- No prices or totals in marketing
- No pantry, no receipt scan, no per-store aisle learning
- Free tier is ad-heavy by design

**Read:** the counter-model. $5M/yr and profitable, but built on 15M users and advertising —
brands are the customer. Note the asymmetry: **strong on Android globally, weak on iOS US
(10K ratings vs AnyList's 79K).** They are not the competitor to fear on an iOS launch.

---

## 5. Bring! — strategically owned, not a P&L

**Bring! Labs AG**, Zurich (+ Basel, Berlin) · founded 2015 · ~100 employees ·
raised €3.8M in 2020 · **acquired by Swiss Post on 15 September 2021**

**Scale:** ~3.6M MAU in DACH; 21M consumers across Bring! and its offers app Profital.

**Does:** icon-tile visual lists, household sharing with photo avatars, store deals, recipe
inspiration, light/dark mode, and a full **retail media / commerce ad platform** sold to FMCG
brands and retailers.

**Doesn't:** no prices or totals for the user, no pantry, no receipt scan. Europe-centric.

> **A revenue figure to distrust:** RocketReach lists ~$2M for 2025. A ~100-person Zurich company
> cannot run on $2M — Swiss payroll alone would exceed it several times over. Either the figure
> is wrong or it captures one entity of several. **Don't cite it.** The meaningful fact is the
> ownership: Bring! is a strategic asset of a state-owned postal operator, so it doesn't need to
> clear a standalone P&L and can't be out-competed on burn.

---

## 6. The rest of the field

| App | Ratings | Score | Store category | Notable |
|---|---|---|---|---|
| **MinimaList** (InnerGrow) | 46K | 4.8 | Productivity #198 | **Per-item prices, per-category subtotals, `Total $65.97`.** A to-do app that beat every grocery app to cost |
| **Shopping List — Grocery & ToDo** (Komorebi) | 29K | 4.8 | Shopping | **Interactive lock-screen widget** — tap the checkbox without opening the app; inline autocomplete |
| **Shopping List — Simple & Easy** (Opulogic) | 1.4K | 4.6 | Shopping | Screenshots still show a "Carrier" status bar — pre-iOS 11 assets, still rating 4.6 |
| **Google Keep** | — | — | — | The real default. Zero-friction sharing, no grocery features |

---

## 7. What the money means — correcting `MARKET.md` §3

`MARKET.md` modelled 100k downloads × 2.1% freemium conversion × $9.99 = **~$17.8k/yr net** and
concluded "not a business, a side project."

**That model was single-cohort, and that's the error.** Subscriptions stack: year 3 revenue comes
from years 1, 2 and 3 cohorts minus churn. AnyList has been compounding for 14 years, which is
how a small team reaches ~$900k/yr on a $10–15 price.

Re-modelled, 100k downloads/yr sustained, 3% conversion at $24.99, 58% renewal
(the utilities benchmark) **[model]**:

| Year | New subs | Retained | Active | Gross | Net after 15% |
|---|---|---|---|---|---|
| 1 | 3,000 | — | 3,000 | $75k | $64k |
| 2 | 3,000 | 1,740 | 4,740 | $118k | $101k |
| 3 | 3,000 | 2,749 | 5,749 | $144k | $122k |
| 5 | 3,000 | ~3,600 | ~6,600 | $165k | $140k |

**~$140k/yr net by year 5 for one person** — and that's on conservative assumptions with no
paid acquisition. AnyList's actual numbers say the ceiling is 5–6× that.

Revised conclusion: **a credible one-to-two-person business with a 3–5 year ramp, not a side
project and not venture-scale.** The pessimism in `MARKET.md` §3 came from modelling one cohort
instead of a subscription base.

---

## 8. The competitive opening, stated precisely

Combining everything:

1. **Cost is open in the grocery category.** AnyList (14 years, 4.9★, ~$900k/yr) and
   OurGroceries (84K ratings) both lack prices entirely. MinimaList proves users want it. No
   grocery app has claimed it.
2. **OurGroceries proves under-pricing caps you.** $7.99/yr and a $20 lifetime tier on 84K
   ratings yields ~$360k/yr — less than half of AnyList's on comparable ratings. Price at
   $24.99.
3. **AnyList is beatable only on a different axis.** Do not fight them on recipes and meal
   planning; they've owned that for 14 years and execute at 4.9★.
4. **Listonic is not the iOS threat.** 10K US iOS ratings versus AnyList's 79K. Which means the
   **"ad-free" wedge is aimed at the wrong opponent on iOS** — keep it as a value, drop it as
   the headline.
5. **Bring! can't be beaten on money** — state-owned parent — but it is Europe-centric and
   sells to brands.
6. **Editorial featuring is live.** Apple featured Listonic in 2026. That's the only free
   distribution at scale in this category.

## 9. Gaps in this dossier

- No download or revenue estimate found for Listonic or Bring! at app level
- AnyList lifetime downloads unknown
- The MWM–Listonic relationship (publisher vs acquirer) is unverified
- No churn or LTV data for any competitor — the retention benchmarks in `MARKET.md` are
  category averages, not these apps
- Revenue splits between iOS and Android are only available for OurGroceries

## Sources

- [AnyList — Sensor Tower app profile](https://sensortower.com/ios/us/purple-cover-inc/app/anylist-grocery-shopping-list/522167641)
- [Our Groceries Shopping List — Apptopia](https://apptopia.com/ios/app/325851015/about)
- [Our Groceries iOS revenue — Trend Apps](https://trendapps.dev/app/ios/325851015/)
- [Our Groceries Android revenue — Trend Apps](https://trendapps.dev/app/android/com-headcode-ourgroceries/)
- [Listonic revenue & competitors — Growjo](https://growjo.com/company/Listonic_-_The_Smart_Shopping_List)
- [Listonic — About us](https://listonic.com/about-us)
- [Grocery List Listonic — MWM Spark](https://spark.mwm.ai/us/apps/grocery-list-listonic/331302745)
- [Bring! Labs — About us](https://www.bringlabs.com/en/about-us)
- [Bring! Labs — PitchBook profile (Swiss Post acquisition)](https://pitchbook.com/profiles/company/113466-97)
- [Bring! raises €3.8M — EU-Startups](https://www.eu-startups.com/2020/05/bring-the-grocery-shopping-app-snaps-up-e3-8-million/)
- [AnyList paywall teardown — Adapty](https://adapty.io/paywall-library/anylist/)
- [OurGroceries paywall teardown — Adapty](https://adapty.io/paywall-library/our-groceries-shopping-list/)
