# The whole approach, in bullets

One page. Everything decided, everything recommended, and what's still open.

> **August 2026: `PRODUCT.md` is now the final word and outranks this index where they differ.**
> It closes the items below marked ⭐/❓ on imagery (line-icon glyphs), quantity placement
> (×N under the name), density (F row height stands), and the photo-ranking question (moot).

**Legend:** ✅ decided · ⭐ my recommendation, awaiting your call · ❓ genuinely open

---

## Product

- ✅ **A grocery list app for households.** Consumer, not B2C-for-brands
- ✅ **Cost is the differentiator** — prices, per-category subtotals, trip total. AnyList (14 years, 4.9★, ~$900k/yr) and OurGroceries (84K ratings) both lack it entirely
- ✅ **Aisle order is differentiator #2** — the list matches the walk
- ✅ **Position narrow, support broad** — named and marketed as groceries; nothing stops you making a hardware-store list. No list *types*, no modes, no to-do features
- ✅ **Five core features and nothing else in v1:** the list · household sharing · offline · aisle order · cost
- ⭐ **Ship honest prices, not precise ones** — `~` and grey for estimates, solid ink for observed, `≈` on totals. Never fake precision
- ❌ **No recipes. No meal planning. No cooking.** Not deferred — cut. AnyList has owned that for 14 years at 4.9★ and it is not the job this app does
- ✅ **No pantry either. The Shelf is cut from v1** *(Aug 2026)*. The reference is **Amazon Fresh's shopping list**: list-first, grouped by category, `COMPLETED` collapsed, a suggested-items grid. Cutting the Shelf removes the consumption-tracking problem that kills pantry apps, the shelf-life dataset we don't have, and a competitive set we never wanted

## Name and brand

- ⭐ **Bagged** — no app of that name in either store; the one live USPTO mark is apparel/bags, Class 18/25, not software
- ⭐ Fallback is **BagList**. **Dozen is out** — no trademark bar, but five unrelated apps own the store-search term including a grocery app, and ASO is the entire marketing budget
- ✅ Store title `Bagged: Shared Grocery List`, freeing the subtitle for fresh keywords
- ✅ Warm paper base (`#F6F4F1`), persimmon action (`#C9502C`), green **semantic only** (done/verified). The warm base is the real differentiator in a cool-toned category
- ⚠️ **Buy the domain and handles before anything else** — the only piece someone else can take while you deliberate
- ⚠️ **Then** the paid Class 9 + 42 search with phonetic variants. Commission nothing visual until it clears

## Platform

- ✅ **iOS native, Swift 6 + SwiftUI.** Six screens against five Tier-1 features that need Swift regardless — that ratio is backwards for React Native
- ✅ **No Android app, and specifically not a second native one.** Two native codebases is ~1.8× the work for a platform where this architecture doesn't run. **If both platforms ever become genuinely required, the answer is React Native — not Android Studio alongside Xcode**
- ✅ Minimum **iOS 18**. Foundation Models (iOS 26) is availability-gated, never a dependency
- ✅ **Three dependencies total** — GRDB, RevenueCat, supabase-swift. Everything else is a system framework. React Native would have needed ~12
- ✅ **App Group container shared by app, widget and intents.** Under React Native this was a cross-language contract; native, it's a shared Swift package

## Architecture

- ✅ **Local SQLite is the source of truth.** The server is a sync peer, never the read path
- ✅ **Op-log sync** — `add`/`check`/`uncheck`/`edit`/`delete`, client UUIDs, logical clock, last-write-wins per field, idempotent `add` on normalized name
- ✅ **Explicitly not a CRDT.** Yjs/Automerge duplicate items on ordered-list merges; a shopping list is a set, not a sequence
- ✅ **Prices are observations** on *(item, store, date, currency)* — never a column on the item
- ✅ **Category ≠ aisle order.** Aisle order belongs to *(store, household)*
- ⚠️ **Row Level Security is the whole security model.** Write the policies first, test with a second account before any UI. Get it wrong and lists leak between families
- ⚠️ **The op-log conflict test is the highest-value test in the project** — two devices, offline edits, reconnect, assert no duplicates and no losses

## AI and voice — the cost architecture

- ✅ **The rule: free tier → on-device only. Paid tier → cloud allowed, low-frequency only**
- ✅ **21 of 24 features never touch Claude.** All of v1.0 runs at zero marginal cost
- ✅ **Voice add is not an AI problem** — it's on-device transcription plus the resolver we already built. ~$0
- ✅ **Adopt the `reminders` App Schema domain** — Siri does the language understanding for add, check-off and aisle sections, plus store-arrival geofencing free
- ✅ **Claude's entire surface is two features:** receipt scan and handwriting. Both paid-tier, ~4×/month, off the critical path. *(Recipe import was the third — cut Aug 2026)*
- ✅ Receipt scanning costs **$0.22–$1.08 per subscriber per year** against $29.99 — at most 3.6%
- ❌ **Never put a high-frequency or free-tier action on the cloud.** 20 voice adds/week × 100k free users ≈ 1M calls/year on users who generate no revenue
- ❌ **Never sell "AI" as a headline.** Listonic put an AI badge on their lead screenshot; it's furniture now. Sell speed

## Data and imagery

- ✅ **Keep the hand-built catalog** — 414 items, 859 lookup terms, 22 categories, 8 price regions, 200 KB. Clean IP, wholly owned, and the right shape
- ❌ **Never bulk-import Open Food Facts.** ODbL is share-alike for databases — deriving from it risks having to publish our catalog under ODbL
- ✅ **Open Food Facts is a runtime barcode lookup only**, with attribution. Querying is use; importing is derivation
- ✅ USDA FoodData Central is public domain but the wrong shape — nutrition data, no aisles, no shopping synonyms
- ⭐ **Generate item photos to one specification** rather than sourcing them. 414 found photos = 414 backgrounds and angles, which looks worse than emoji. Consistency is the value
- ✅ **Emoji is the permanent fallback**, never a blank. `image_status` / `image_ref` / `image_source` on every item, swapped in progressively
- ⭐ **Bundle the top 100 by frequency** (~3.5 MB). Bundling all 414 puts us past AnyList's download size
- ❌ **No On-Demand Resources for photos** — a photo that needs a network breaks offline-first in a supermarket
- ✅ **Grow the catalog from unmatched search terms**, not bulk imports

## Interaction and the ADHD angle

- ✅ **Design for ADHD. Do not market a treatment for ADHD.** Apple and the FDA judge by totality of presentation, not disclaimers
- ✅ Keep ADHD out of the store title and claims; put it on a *"why it works this way"* page
- ✅ **Open directly into the list.** No home screen, no dashboard, no onboarding wizard — task initiation is the whole battle
- ✅ **Never make the user hold state in their head** — total visible, remaining count visible, checked items sink but stay readable
- ✅ **The widget and store-arrival trigger are externalised memory** — the most valuable accommodation we ship, and it's free
- ✅ **Defaults everywhere**, all overridable, none required
- ❌ **No streaks, no badges, no surprise animations, no re-engagement notifications.** The same variable-reward loops that make apps engaging are what ADHD brains are most vulnerable to
- ✅ **Haptics are the primary channel** — they work in a noisy shop and on silent. `impactLight` on check-off because it fires 40× a trip
- ✅ **Sound on by default. Two sounds total.** Because it's used in public, they must be quiet enough that nobody minds — inaudible past a metre, and designed to survive 40 repetitions. Silent switch always respected; never ducks other audio; never fires from the widget or an intent
- ✅ **Motion 150–250 ms, spring, interruptible, one thing at a time.** Every animation has a defined `Reduce Motion` equivalent
- ✅ **The completion moment is arrival, not celebration.** The `≈` resolves to a real total. No confetti — it's anti-calm and a variable reward in costume
- ✅ **An app that treats attention as the user's is something an ad-funded competitor structurally cannot copy**

## Pricing

- ✅ **$2.99/month, $29.99/year, 7-day trial.** No lifetime tier
- ✅ **People you invite are free forever** — sharing is the growth loop, don't tax it
- ✅ Free tier keeps the core list working indefinitely
- ✅ **No ads, ever** — but demote "ad-free" as the headline; on iOS the ad-funded competitor isn't the threat
- ✅ OurGroceries proves under-pricing caps you: $7.99/yr and a $20 lifetime tier on 84K ratings yields ~$360k/yr, less than half of AnyList's
- ⭐ If monthly churn disappoints, **raise monthly to $3.99** rather than discounting annual

## Services and accounts

- ✅ **Supabase** for sync — free tier → $25/mo
- ✅ **RevenueCat** for subscriptions — free to $2,500/mo tracked revenue, then 1%. ~$750/yr in year 1
- ✅ **Google Workspace** for `support@` on the app's domain — must be monitored, Apple checks it at review
- ✅ Own website — only two hard dependencies: **privacy policy URL and support URL, both live before submission**
- ✅ Privacy policy must cover **LGPD** as well as GDPR/CCPA if the operating entity is Brazilian
- ⚠️ **Accept the Paid Applications Agreement and complete banking/tax now.** In-app purchases don't work — even in sandbox — until it clears, and tax forms take days
- ⚠️ **Register Google Play as an *organization*, not personal.** Personal accounts post-Nov-2023 need 12 opted-in testers for 14 days before they can apply for production. Organizations are exempt. Needs a D-U-N-S number
- ✅ TestFlight internal first (100 people, no review, minutes), then external (10,000, Beta App Review)
- ❌ No analytics SDK, no crash reporter, no UI kit, no i18n at launch

## Go to market

- ✅ **ASO is the entire marketing budget** — 65–70% of downloads start with store search, top-3 takes >50% of clicks
- ✅ Screenshot captions are OCR-indexed — write them as keywords, not decoration
- ✅ **Lead the screenshots with the price total.** It's the one thing no grocery competitor shows
- ✅ Store category: **Shopping**
- ✅ **Editorial featuring is the only free distribution at scale** — Apple featured Listonic in 2026
- ⚠️ **Never say "nobody shows prices."** MinimaList (46K ratings, 4.8★) leads with per-item prices and a `Total $65.97`. The claim is false and it's checkable

## What to do next, in order

~~1. Confirm the platform~~ — ✅ **decided: iOS native**

1. **Accept the Paid Applications Agreement**, complete banking and tax. Longest lead time, zero work
2. **Buy `bagged.app` and the social handles**
3. **Run the paid Class 9 + 42 trademark search** on BAGGED
4. **Stand up `support@`** and publish the privacy policy
5. **Build `Core` + `Catalog`** — port the resolver, write the op-log and its conflict harness. No UI, no device, no signing
6. **Write the RLS policies**, tested with two accounts, before any UI
7. **Write the image specification**, rank the catalog by frequency, generate the top 100
8. **Then** the UI layer and the screen architecture

*Google Play registration drops off the list — no Android app. If that ever changes, register as
an organization (`OPS.md` §3).*

## Still genuinely open

- ❓ **Quantity placement in the list row** — the chip truncates long names, and it collides with the Dynamic Type requirement
- ❓ **Which 100 items get photos first** — the frequency ranking doesn't exist yet
- ❓ Opt-in anonymous price pooling between households
- ❓ Opt-in reporting of unmatched search terms
- ❓ Whether the operating entity is Brazilian, which decides the privacy-policy scope
