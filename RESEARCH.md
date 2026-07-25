# Shopping List App — Market & Product Research

Research date: July 2026. Sources listed at the bottom.

---

## 1. Why this category is worth building in

The shopping list is one of the few genuinely daily-use utilities left that people still
open by hand. The surrounding market is large and still growing:

| Metric | Value |
|---|---|
| Online grocery market (2026) | ~$1.06T, projected $1.74T by 2031 (10.5% CAGR) |
| Americans buying groceries online (2026) | ~157.5M |
| Global online grocery consumers (monthly) | ~1.4B |
| Recipe app market | $1.41B (2025) → $1.6B (2026), 13.4% CAGR |
| AI meal-planning app market | $0.83B (2025) → $1.03B (2026), **24.6% CAGR** |

The interesting signal: the *list* category is mature and commoditized, but the
**AI meal-planning / pantry-aware** adjacency is the fastest-growing slice. That's where
new entrants are actually winning.

---

## 2. Competitive landscape

### The incumbents

| App | Position | Pricing | Strength | Weakness |
|---|---|---|---|---|
| **AnyList** | Feature leader, since 2012 | $9.99/yr solo, $14.99/yr household | Best recipe import + meal planning; frictionless sharing; polished | Paywall covers web app, meal planning, recipe scaling; no per-store list filtering |
| **Bring!** | Europe leader (Zurich, ~100 staff, founded 2015) | Free, ad/retail-media funded | Icon-led visual UI, store deals, ~3.6M MAU in DACH; 21M consumers with Profital | Icon metaphor breaks down on long/unusual lists; Europe-centric |
| **OurGroceries** | Cheapest reliable option | $7.99/yr, ~$20 lifetime | Rock-solid sync, aisle ordering, long reliability track record | Deliberately no-frills; **users have asked for price tracking for 3+ years with no movement** |
| **Listonic** | Volume/ads play | Free + ad-free premium | 13M+ downloads, 20M+ claimed users, 50+ countries, profitable, ~50% YoY growth | ~90% of revenue is banner ads → the free experience is ad-heavy |
| **Google Keep** | Default/zero-friction | Free | Already installed, instant sharing | Not a grocery tool: no aisles, no quantities, no recipe/pantry |

### The new wave (AI-native, 2024–2026)

Grocery AI, Recipy, ListAIse, Groceries Tracker, Pantryfy, GroceryBudget. Common feature set:

- **Voice capture** — natural-language batch add ("add 2 pounds of chicken breast"), hands-free
  during a fridge scan. Grocery AI's "Voice Add 2.0" captures a whole grocery run.
- **Receipt scanning** with item-level extraction (what, how much, which category).
- **Pantry inventory + expiry alerts**, feeding back into the list ("you already have this").
- **Recipe → list** with matching against what's already in the pantry.
- **Price comparison** across local stores.

The consensus in the review coverage: the biggest real dollar savings come from
**waste prevention via pantry-aware planning**, not from coupon/price chasing.

---

## 3. Where the gaps are (the build opportunity)

These are the repeated, unaddressed complaints across incumbents:

1. **Price/spend tracking is missing from the leaders.** OurGroceries users have requested
   it for years. AnyList doesn't do it. Nobody in the "simple list" tier answers
   *"what did this trip cost, and is that more than last month?"*
2. **Store-aware lists are half-built.** AnyList can't filter a list by store. Aisle order
   is usually a manual, per-user chore rather than learned from behavior.
3. **Sharing friction.** Most apps require every household member to create an account
   before they can see a list. The zero-account, link-based join is a real wedge —
   it's exactly why Google Keep still holds ground.
4. **The free tier is either ad-polluted (Listonic) or crippled (AnyList's web app is paid).**
5. **Pantry ↔ list is a one-way street.** Checking off an item should update the pantry;
   almost nothing closes that loop well.

**Sharpest positioning available:** *the fast, ad-free shared list that quietly learns your
store layout and tells you what the trip cost.* Aisle intelligence + spend tracking + no
signup to join a list — all three are things at least one incumbent refuses to build.

---

## 4. Feature tiers

### Tier 0 — table stakes (nothing ships without these)
- Add item in under 2 seconds; autocomplete from personal history first, then a catalog
  (Baymard: ≤10 suggestions, generous touch targets, ranked by relevance/usage).
- Check off with one thumb; checked items sink, undo available.
- Quantities + units, free-text notes.
- Real-time shared lists across devices; multiple named lists.
- Works fully offline; syncs on reconnect (this is a *supermarket* app — signal is bad by design).
- Category/aisle grouping.

### Tier 1 — competitive
- Store profiles with custom aisle order, and **learned** aisle order from check-off sequence.
- Recipe → list (paste a URL, get ingredients).
- Barcode scan to add.
- Price per item + running trip total + spend history.
- Voice/natural-language batch add.
- Templates / recurring staples ("the usual").

### Tier 2 — differentiators
- Pantry inventory closed loop: check off → into pantry; consumed/expired → back onto list.
- Receipt scan → auto-fill actual prices → build a personal price book.
- Predictive restock ("you buy milk every 6 days; it's day 6").
- Multi-store split: one list, auto-partitioned by where each item is cheapest/available.
- Household roles and light assignment ("Dad grabs the produce").

---

## 5. Technical architecture recommendation

The single hardest engineering requirement is **offline-first sync with concurrent editors**
(two people in two stores, one on airplane-mode-grade signal).

### Sync strategy
The literature is consistent: **don't reach for a CRDT library unless you have collaborative
*text* editing.** Yjs/Automerge merges produce surprising results on ordered lists (documented
case: a Yjs-backed task list duplicated items after two users reordered). A shopping list is a
*set* of items, not a sequence — so:

- Model items as an append-only log of operations (`add`, `check`, `uncheck`, `edit`, `delete`)
  with a stable client-generated UUID per item.
- Last-write-wins per field, with a logical clock — sufficient for ~99% of real conflicts.
- Idempotent `add` keyed on normalized item name per list so "milk" added twice on two phones
  collapses to one row.
- Local queue that batches writes offline and replays on reconnect.

That's a well-understood three-layer pattern: **local store → sync queue → conflict rule.**

### Stack options

| Option | Stack | Trade-off |
|---|---|---|
| **A. Pragmatic (recommended)** | Expo / React Native + SQLite (expo-sqlite) locally + Supabase (Postgres + Realtime + Auth) | One codebase for iOS/Android/web, mature offline story, cheap to run, easy to hire for. Write your own thin sync queue. |
| **B. Managed sync** | Expo + **PowerSync** + Supabase, or ElectricSQL | Sync is solved for you; you pay per-seat/vendor lock-in. Fastest path to bulletproof offline. |
| **C. Local-first purist** | SQLite + `sqlite-sync` (CRDT) or Automerge, any backend | Best conflict semantics, most complexity, largest bundle. Overkill for a list. |

Recommendation: **A, structured so B can be dropped in.** Keep all reads/writes behind a
repository layer so the sync engine is swappable.

### Data
- **Open Food Facts** — free, open barcode/UPC → product data. Start here.
- **Kroger Products API** — real product + price data (13-digit product ID; drop the barcode
  check digit). Good US pilot for price features.
- Instacart/Walmart-derived scraper APIs (Apify et al.) exist for cross-retailer pricing but
  are third-party and carry ToS/cost risk — don't build the MVP on them.
- Seed a hand-curated ~1,000-item catalog with categories/aisles. This matters more than any
  API: it's what makes autocomplete feel instant on day one.

---

## 6. Monetization

Three proven models in this exact category:

1. **Cheap annual subscription** — AnyList ($10–15/yr), OurGroceries ($8/yr + $20 lifetime).
   Low friction, no ads, aligns incentives with the user. Best for a quality-first product.
2. **Ads / retail media** — Listonic (~90% of revenue from banners, profitable, 50% YoY growth),
   Bring! (native FMCG ad formats + a full commerce media platform). Enormous ceiling but
   requires scale (millions of MAU) and degrades the product until you get there.
3. **Affiliate / delivery handoff** — "send this list to Instacart/Kroger." Small but clean.

Recommendation for a new entrant: **freemium subscription, no ads.** "Ad-free" is a concrete,
marketable wedge against the two highest-volume competitors. Free tier must include unlimited
shared lists and offline sync — paywalling sharing kills the viral loop. Paywall pantry
tracking, receipt scanning, price history, and unlimited store profiles.

Price anchor: $9.99/yr household is under the leader's price and above the floor.

---

## 7. Suggested MVP (v0.1)

Ship this, nothing more:

1. Create/rename/delete lists; **join a list by link with no account required**.
2. Fast add with history-ranked autocomplete + seeded catalog.
3. Check off, undo, auto-sort checked items to bottom.
4. Auto-categorization into aisles; drag to reorder categories per store.
5. Full offline; real-time sync when online.
6. Recurring staples list ("add the usual").

Explicitly deferred: recipes, pantry, receipts, AI, price comparison. Every one of those is
worth building *after* the core loop is faster than AnyList's.

**Success bar before adding anything:** adding an item takes ≤2 taps and ≤2 seconds, and a
shared list update lands on the other phone in under a second on a normal connection.

---

## Sources

- [Best shopping list apps in 2026 comparison — BuyBye!](https://getbuybye.com/blog/best-shopping-list-apps/)
- [Best Grocery List Apps 2026: AnyList vs OurGroceries vs LystBot](https://lystbot.com/blog/best-grocery-list-apps/)
- [7 Best Grocery List Apps in 2026 (Tested & Compared)](https://groceriestracker.com/blog/best-grocery-list-apps-2026)
- [I tried Listonic, Bring, AnyList, and OurGroceries — SmartCart Family](https://smartcartfamily.com/en/blog/grocery-apps-comparison)
- [OurGroceries alternatives & user feedback — AlternativeTo](https://alternativeto.net/software/ourgroceries)
- [Online Grocery Market Size, Share & 2031 Trends — Mordor Intelligence](https://www.mordorintelligence.com/industry-reports/online-grocery-market)
- [Online Grocery Shopping Statistics (2026) — Capital One Shopping](https://capitaloneshopping.com/research/online-grocery-shopping-statistics/)
- [AI Driven Meal Planning Apps Market Report 2026 — The Business Research Company](https://www.thebusinessresearchcompany.com/report/ai-driven-meal-planning-apps-global-market-report)
- [Recipe App Market Trends and Growth Report 2026–2035](https://www.thebusinessresearchcompany.com/report/recipe-app-global-market-report)
- [90% of Ad Revenue of Listonic is acquired from banners — Appodeal](https://appodeal.com/case-studies/listonic/)
- [Listonic case study: monetizing unsold ad space — Appodeal](https://blog.appodeal.com/listonic-unsold-ad-space/)
- [Bring! Labs advertising platform](https://www.bringlabs.com/en/platform)
- [Bring! Labs trend barometer 2026](https://www.bringlabs.com/en/trend-barometer-2026)
- [Best AI Apps to Save Money on Groceries in 2026 — Recipy](https://recipyapp.com/blog/best-ai-apps-save-money-groceries-2026)
- [Best Pantry Tracking Apps 2026 — Recipy](https://recipyapp.com/blog/best-pantry-tracking-apps-2026)
- [Grocery AI — Google Play](https://play.google.com/store/apps/details?id=com.pocketlabs.groceryking2)
- [Local-First Architecture: CRDTs & Sync Engines — AppScale](https://appscale.blog/en/blog/local-first-architecture-crdts-sync-engines-offline-first-2026)
- [The Architecture of Local-First Web Development — Smashing Magazine](https://www.smashingmagazine.com/2026/05/architecture-local-first-web-development/)
- [Offline-First Apps Made Simple: Supabase + PowerSync](https://powersync.com/blog/offline-first-apps-made-simple-supabase-powersync)
- [Local-first architecture with Expo — Expo Docs](https://docs.expo.dev/guides/local-first/)
- [sqliteai/sqlite-sync — CRDT-based offline-first sync for SQLite](https://github.com/sqliteai/sqlite-sync/)
- [Yjs — shared data types for collaborative software](https://github.com/yjs/yjs)
- [Kroger Products API — Kroger Developers](https://developer-ce.kroger.com/api-products/api/product-api-public)
- [Top Grocery Price APIs — Actowiz](https://www.actowizsolutions.com/top-grocery-price-apis-live-grocery-price-tracking.php)
- [9 UX Best Practice Design Patterns for Autocomplete Suggestions — Baymard](https://baymard.com/blog/autocomplete-design)
- [Autocomplete suggestions: benefits & UX best practices — Fresh Consulting](https://www.freshconsulting.com/insights/blog/autocomplete-benefits-ux-best-practices/)
