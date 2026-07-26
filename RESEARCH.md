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

1. **Price/spend tracking is missing from the grocery leaders.** OurGroceries users have
   requested it for years; AnyList doesn't do it; Listonic and Bring! don't market it.
   **Caveat:** MinimaList — a general-purpose to-do app with 46K ratings — *does* ship per-item
   prices, per-category subtotals and a trip total. So the feature exists in the market; what's
   unclaimed is a *grocery* app owning cost as its reason to exist. Never write "nobody does
   this." See `research/store-teardown.md` §10.
2. **Store-aware lists are half-built.** Aisle order is usually a manual, per-user chore
   rather than learned from behavior.
   **Unverified:** an earlier draft claimed "AnyList can't filter a list by store," sourced from
   a review roundup. Their own store screenshot shows per-item store tagging (`Salmon —
   Trader Joe's`), so the claim is unsafe. Test it in the app before using it anywhere.
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
- Price per item + running trip total + spend history, **with per-category subtotals**
  ("Produce $18, Meat $17.99") — this tells you *where* the money went, not just the total.
  Borrowed from MinimaList, which does it better than our first mockup did.
- Voice/natural-language batch add. **Note:** "AI" is now table stakes marketing, not a differentiator — Listonic leads its primary screenshot with a "With AI" badge. Ship the outcome, never the technique.
- Templates / recurring staples ("the usual").
- **Lock-screen and Home Screen widget** — glanceable list without unlocking, for pushing a
  cart with both hands. Same family as the offline requirement: both are about working in the
  aisle rather than on the sofa. (See `research/store-teardown.md` §8.)

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

### Data sources — decision

**No retailer API in v1.** Kroger's Products API means one chain, one country, a partnership
that can change terms, and a corporate dependency that cuts against the consumer positioning
in §6. Scraper feeds (Apify/Instacart-derived) cover more retailers but violate retailer ToS
and carry legal exposure. Neither is a foundation. Revisit only as a per-market integration
if users demand a specific chain.

Layered instead, each layer filling in more optional fields on the same row:

1. **v1 — bundled item catalog.** ~1,000 hand-curated generic grocery *items*, shipped in the
   app binary. No network call, works in a supermarket dead zone. Matters more than any API:
   it's what makes autocomplete feel instant on day one.
2. **v1.1 — barcode scan via Open Food Facts.** Free, open, global, no partnership. Covers the
   long tail the catalog misses; cache locally so each scan enriches the user's own data.
   ODbL-licensed — verify attribution/share-alike terms before building a paid feature on it.
3. **v2 — receipt scan.** Backfills real prices for a whole trip from one photo. Makes the
   price book *precise*; the seed estimates below make it *exist*.

### Data model — items, prices, and the catalog

**The catalog holds items, not products.** "Milk", "bananas", "sourdough bread" — the words
people write on lists. No brands, no SKUs, no `brand`/`product_variant` tables. That
normalization is the road back to a retail catalog, a data pipeline, and staleness.

```
item          id, canonical_name, category_id, emoji, default_unit, locale
item_synonym  item_id, term          -- cilantro/coriander, courgette/zucchini
category      id, name, emoji, default_aisle_order
```

- **Synonyms from day one.** They're the multi-market path — launching UK/AU becomes a data
  task, not a search-layer rewrite.
- **Category ≠ aisle.** Category ("Dairy") is a global property of the item. Aisle order is
  per-store and per-user. Separate tables, or the learned store layout can never be built.
- **The catalog is a fallback, not the source of truth.** Autocomplete ranks personal history
  first, then household, then catalog. Within weeks a real user's suggestions are mostly their
  own items. The catalog exists so week one isn't empty.
- **Every field optional.** A typed "mangoes" with no `item_id`, no emoji, no price is a valid
  item. Later layers fill fields in; nothing is a migration.

**Prices never live on the item row.** A price is a property of *(item, store, date,
currency)*, different for every user. Two separate tables:

```
price_observation  id, item_id (nullable), item_name, store_id, amount, currency,
                   unit, observed_at, source (manual|receipt|corrected), household_id
price_seed         item_id, base_amount, currency, region_multiplier_key,
                   compiled_year, seed_version
```

Current price = most recent observation for (item, store), falling back to the seed estimate.
History comes free, and history is the better insight ("milk is up 40¢ since March").

### Estimated prices — rules

Shipping seed estimates is correct, and fixes the cold start that otherwise leaves the trip
total empty until receipt scanning matures. Instacart and Woolworths both label their totals
"Est. total" — estimation is the category convention and users accept it. The failure mode is
not inaccuracy; it is **unlabeled** inaccuracy and **false precision**. Therefore:

- **Round hard.** Nearest $0.50 under $10, nearest dollar above. "$3.47" reads as a looked-up
  fact; "~$3.50" reads as a guess and is judged as one. Rounding is the honesty signal and
  costs nothing when the number is a guess anyway.
- **Never visually equivalent.** Estimates render grey with a `~` prefix; confirmed prices
  render in solid ink. Trip total reads "≈ $85 estimated" until enough items are confirmed.
- **Observations always override**, permanently, for that household.
- **Region via multiplier.** One base price per item plus a per-region multiplier — a few dozen
  numbers, not thousands of regional rows.
- **Stamp and version the seed.** A 2026 price seed is embarrassing by 2029. Refresh with app
  releases or apply an annual adjustment; ranges age better than point values.
- **Separate table, always.** Same data on the item row would blur estimated and observed
  together in the code within six months — which is how unlabeled estimates actually happen.

**Open question (deliberate, not drifted into):** pooling anonymized observations across users
at the same store would eliminate the cold start entirely, but means shipping shopping data to
a server — cutting against both local-first and "your data isn't the product," even though the
beneficiary is other shoppers rather than brands. If done, explicitly opt-in.

---

## 6. Positioning: consumer app, not a brand platform

**Decision: this is a direct-to-consumer household app. The shopper is the customer.**

That rules one model out on purpose. Bring! and Listonic are, commercially, advertising
businesses — Bring! Labs sells native FMCG ad formats and a commerce media platform to brands
and retailers; Listonic draws ~90% of revenue from banners. In both, the paying customer is a
brand and the shopper is the inventory being sold. That model has an enormous ceiling, but it
inverts who the product serves, and it only pays at millions of MAU — meaning years of a
degraded free experience before the revenue arrives.

Consequences of choosing consumer:

- No ads, no sponsored items, no "recommended brand" slots in the list. Ever — this is the
  marketing wedge, and it's only credible if it's unconditional.
- No B2B surface: no retailer dashboards, no brand analytics, no team/workspace/permissions
  model. Household sharing means *named people*, not roles and seats.
- Data stays the user's. No selling shopping behavior to FMCG brands — the thing the two
  highest-volume competitors are built to do.

### Monetization

**Freemium subscription at ~$9.99/yr household.** Under AnyList's $14.99 household tier and
above OurGroceries' $7.99 floor. A lifetime option (~$25) is worth testing — OurGroceries'
$20 lifetime is one of its most-cited draws.

- **Free forever:** unlimited lists, unlimited shared members, offline sync, aisle grouping.
  Paywalling sharing kills the viral loop — the whole growth model is one household member
  inviting the others.
- **Paid:** pantry tracking, receipt scanning, price history, multiple store profiles,
  recipe import.

Secondary, non-conflicting: affiliate handoff ("send this list to Instacart/Kroger"). Small
revenue, but it serves the shopper rather than monetizing their attention, so it's compatible
with the positioning.

---

## 7. Design direction

Reference apps are consumer utilities, not retail or work tools. The e-commerce apps
(Amazon Fresh, Instacart's store) and the work trackers (Trello, Notion, monday.com) both
solve a different problem and should not drive the layout.

**Item rendering — follow Tiimo.** One rounded card per item, emoji/illustration tile on the
left, large tappable circle on the right, colored group-header pills with counts. It stays
legible at arm's length while pushing a cart, which Todoist/Trello-grade density does not.
Confetti or similar on completion — this is a chore app, small delight matters.

**Quick add.** Inline "type to begin" field with a voice button as a visual *peer* of the
keyboard, not a buried icon (Tiimo). Add is a persistent full-width button or inline field —
no floating action button; none of the consumer references use one.

**Sharing.** Sell it warmly and put it in the way. Instacart's "Family cart" invite screen is
the model: illustrated preview of "Items you added / Items Maria added," colored initial
avatars, big invite slots, copy like "everyone pitches in." TimeTree shows the same idea in a
plain "Me / Member List" split with photo avatars.

**Attribution.** A small caption under the row — Telegram's group checklist ("Alex Smith Lee"
under a completed item, "2 of 3 completed" footer). Never an assignment UI with owners and
due dates; that's the work-tool failure mode.

**Spend.** A running trip total pinned to the bottom of the list, with per-item unit price
(Woolworths, Instacart both do this well). This is the feature AnyList and OurGroceries
don't have.

---

## 8. Suggested MVP (v0.1)

---

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

### UI references (Mobbin)

- [Tiimo — grouped list, card rows, colored group pills](https://mobbin.com/screens/6a638201-90d4-4373-817c-03aced9c0744)
- [Tiimo — quick add with voice as a peer to typing](https://mobbin.com/screens/e151c051-959a-4110-b01b-5c99bff12580)
- [Instacart — "Family cart" household invite](https://mobbin.com/screens/d5a5c097-9786-4570-9e33-d40c347c921b)
- [TimeTree — shared memo with Me / Member List](https://mobbin.com/screens/a0573db7-640e-478c-a59b-364800552a46)
- [Telegram — group checklist with per-item attribution](https://mobbin.com/screens/6a478604-82a6-441a-8688-2b68e118d3c3)
- [Woolworths — aisle grouping, unit price, running trip total](https://mobbin.com/screens/922e06ed-4f48-410e-a077-9ea26daeefd2)
- [Todoist — dense grouped list (counter-example: too dense for in-store)](https://mobbin.com/screens/72a63d08-af72-40e9-a73e-52e222379894)
