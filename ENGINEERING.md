# Engineering method, feature by feature — and what it costs in app size

Companion to `FEATURES.md` (what we build and why) and `PLAN.md` (when). This document answers
two questions only: **how is each feature actually built**, and **how big does the app get.**

---

## 1. The rule

> **If the phone can do it, the phone does it. Claude API is the fallback, never the default —
> and we try the on-device path first even when it's harder to build.**

The reason is not purity, it's unit economics. A cloud call is a recurring cost per user forever;
on-device work is a one-time engineering cost. At $29.99/yr, every recurring cost compounds
against the only revenue we have.

Two corollaries that decide real design questions:

- **On-device work can sit in the critical path. Cloud work never can.** Supermarkets have no
  signal, so any feature that *requires* a network is a feature that fails in the exact moment
  it's for. This alone disqualifies Claude from the entire core loop.
- **A cloud feature must degrade to something useful, not to an error.** If a Claude call fails,
  the user gets the on-device result plus a way to fix it by hand — never a spinner and an
  apology.

### The ladder every feature goes through

Ask these in order and stop at the first yes:

| # | Question | If yes |
|---|---|---|
| 1 | Can plain code do it? (parsing, matching, sorting, arithmetic) | **Do that.** No model of any kind |
| 2 | Is there a system framework for it? (Vision, Speech, App Intents) | **Use it.** Free, offline, no bundle cost |
| 3 | Can the on-device LLM do it? (Foundation Models) | **Use it,** feature-gated — never a dependency |
| 4 | Does it genuinely need a frontier model? | **Claude, paid tier only, low frequency** |

**Rung 1 is the one people skip, and it is where most of the wins are.** Our resolver is rung 1,
and it does work that most competitors would route to a model.

---

## 2. Every feature, and how it gets built

Legend for **Engine**: **code** = plain algorithms · **sys** = Apple system framework ·
**FM** = Foundation Models (on-device, gated) · **Claude** = API call.

### v1.0 — the wedge

| # | Feature | Engine | Method | If it fails |
|---|---|---|---|---|
| 1 | **Add item (typed)** | code | Existing resolver: normalize → singularize → strip qualifiers → exact → prefix on any word boundary → bounded edit distance. Backed by `lookup_term` (859 terms) | Falls through to #3 |
| 2 | **Autocomplete ranking** | code | Three-pass merge: personal history → household history → catalog, deduped, capped. Personal frequency is a counter on the local row, not a query | Catalog-only ordering |
| 3 | **Item not in catalog** | code | Store the raw string as a first-class item with `item_id = NULL`. It syncs, checks off and carries a price like any other. **Never block on "not found"** | n/a — this *is* the fallback |
| 4 | **Quantity** | code | Separate `qty` + `unit` columns on the list row, parsed out of the input by the same qualifier-stripper as #1. Not embedded in the name string | Quantity defaults to 1, name keeps the text |
| 5 | **Check off / undo / sink** | code | Optimistic local write, animation, op appended to the log. Undo is an inverse op, not a state rollback | n/a — local only |
| 6 | **Aisle grouping** | code | `category_id` from the catalog, grouped in the view layer. Category order is a per-*(store, household)* array, not a global constant | Ungrouped flat list |
| 7 | **Per-store profiles + drag to reorder** | code | The array in #6 becomes editable and persisted per store | Falls back to default category order |
| 8 | **Shared lists, join by link** | code | Invite token → household id. **No account required to join** — device identity is a generated UUID, upgraded to an account only if the user wants it | Single-device list, still fully usable |
| 9 | **Offline + sync** | code | Op-log (`add`/`check`/`uncheck`/`edit`/`delete`), client UUIDs, logical clock, last-write-wins per field, idempotent `add` on normalized name. Local SQLite is the source of truth; the server is a peer. **Explicitly not a CRDT** — see `RESEARCH.md` §5 | Works indefinitely offline; queue drains on reconnect |
| 10 | **Cost** | code | Prices are observations on *(item, store, date, currency)*, never a column on the item. `price_seed` supplies the estimate. Rounding enforced in the build (`$0.50` under $10, `$1` above) | Item shows `—`, total shows `≈` and a "not priced yet" count |
| 11 | **Dark mode** | sys | Semantic colours only; no hardcoded hex in views | n/a |
| 12 | **Widget with tappable checkboxes** | sys | WidgetKit + `AppIntent` for the tap. Reads a shared App Group container so the widget never waits on the app | Widget renders last-known state read-only |
| 13 | **Voice add** | sys + code | `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` → the string goes into #1. **No model call anywhere.** Mis-transcriptions behave like typos, which the resolver already handles | Keyboard. Never block on the speech model downloading |
| 14 | **Siri** | sys | Adopt the `reminders` App Schema domain: `createReminder`, `updateReminder`, `deleteReminders`, `createSection`/`updateSection`. Siri does the language understanding; we map parameters. **Adopt the whole cluster — Xcode fails the build on partial adoption** | App still opens and works normally |
| 15 | **Subscription** | sys | StoreKit 2, 7-day trial, `$2.99`/mo and `$29.99`/yr. Entitlement cached locally so the paywall state survives offline | Grace period, never lock a user out of their own list |

**Nothing in v1.0 touches Claude.** That is the point — the entire wedge runs at zero marginal
cost.

### v1.1 — close the honesty loop

| # | Feature | Engine | Method | If it fails |
|---|---|---|---|---|
| 16 | **Barcode scan** | sys + net | `VNBarcodeObservation` on-device for the scan; Open Food Facts for the lookup. **Not Claude** — this is a database query, not a reasoning task | Manual add |
| 17 | **Price editing + history** | code | A user edit writes a `price_observation` with `source = 'user'`. Estimates never overwrite observations; observations never overwrite each other, they accumulate | Estimate stands |
| 18 | **Learned aisle order** | code | Order categories by the median check-off position across recent trips at that store. **Plain statistics, no model** — and it must be visibly overridable, or it feels haunted | Manual order from #7 |
| 19 | **Recurring staples** | code | Interval between re-adds per *(household, item)*; suggest when overdue. Suggestion only, never auto-add | Nothing suggested |
| 20 | **Store-arrival reminder** | sys | `locationTrigger` from the `reminders` schema domain — the system does the geofencing. **Free, and we'd otherwise have built it** | No trigger; list still there |

### v1.2 — the moat

| # | Feature | Engine | Method | If it fails |
|---|---|---|---|---|
| 21 | **Photo of a printed list** | sys | Vision text recognition on-device → lines → resolver (#1). **Printed text needs no model** | Offer manual entry with the photo on screen |
| 22 | **Loose phrasing → items** | FM | Foundation Models, iOS 26+, gated behind availability check. "stuff for tacos" → item list → resolver | Resolver alone, which already handles qualifiers and typos |
| 23 | **Handwriting → items** | **Claude** | Vision first; if confidence is low, send the image. Paid tier only | Vision's best guess, editable |
| 24 | **Receipt → line items + prices** | **Claude** | Downsampled image + structured-output schema → `price_observation` rows. **Batch API** (50% off, receipts aren't latency-critical), **prompt caching** on the fixed schema prefix | Manual price entry (#17) |

### v2 — only if retention holds

Pantry loop, predictive restock and multi-store split are all **rung 1** — counters, intervals and
a set-cover over prices. Recipe import is the only one that reaches for Claude, and it is
deliberately late and unambitious.

---

## 3. The whole Claude surface is three features

**#23 handwriting, #24 receipts, and eventually recipe import.** Everything else — 21 of 24
features — is plain code or a system framework.

All three share the same shape, and it's the shape that makes the economics safe:

- **Paid tier only.** Free tier is on-device or nothing.
- **Low frequency.** Receipts run ~4×/month, not 20×/week.
- **Off the critical path.** Never between the user and their list.
- **Degrades to a working manual path**, never to an error.

At ~$0.0045–0.0225 per receipt (Haiku through Opus), four trips a month is **$0.22–$1.08 per
subscriber per year against $29.99 of revenue** — at most ~3.6%. See `FEATURES.md` §10.

---

## 4. App size

### What actually goes in the bundle

The critical fact: **the AI costs nothing in size.** Vision, Speech, App Intents and Foundation
Models are system frameworks — dynamically linked, and their models are owned and downloaded by
the OS, never shipped in our bundle. Calling Claude is plain HTTPS via `URLSession`; **do not
bundle an SDK for it**, there is nothing to bundle.

| Component | Size | Basis |
|---|---|---|
| SwiftUI app binary | 12–18 MB | typical native app, no third-party UI **[estimate]** |
| GRDB.swift (SQLite) | ~1.5 MB | **[estimate]** |
| **`catalog.db`** | **200 KB** (66 KB compressed) | **measured** — `data/catalog/build.mjs` |
| Widget extension | 1–2 MB | **[estimate]** |
| App icon, brand assets, launch | 1–2 MB | **[estimate]** |
| Vision · Speech · App Intents · Foundation Models · StoreKit 2 | **0** | system frameworks |
| Emoji item icons | **0** | system font |
| Claude integration | **0** | `URLSession` + JSON |
| **Total** | **≈ 16–24 MB** | **[estimate]** |

For scale: **OurGroceries ships 13.5 MB, AnyList 50.9 MB** (Android APKs — the closest public
figures). We land near OurGroceries and at roughly half of AnyList.

**The catalog is not the problem.** 414 items, 859 lookup terms, 22 categories, 8 price regions
and every seeded price fit in 200 KB — about 1% of the app, and less than one product photo.

### The one decision that actually moves the number

**Item imagery.** Currently open (`PLAN.md` §9), and it is the difference between a 20 MB app and
a 40 MB one.

| Option | Size added | Trade |
|---|---|---|
| **Emoji** (current) | **0 MB** | Weakest visually against AnyList and OurGroceries, both of which ship photos |
| **Bundle all 414 photos** | **~14–15 MB** **[estimate]** — 414 × ~35 KB HEIC at 480px | Roughly doubles the app. This is almost certainly why AnyList is 50 MB |
| **On-Demand Resources** | 0 MB initial | Apple hosts them, app fetches lazily — **but a photo that needs a network breaks the offline promise in a supermarket** |
| **Top 100 bundled, tail on demand** | **~3.5 MB** **[estimate]** | Covers the overwhelming majority of real list contents offline; the long tail degrades to emoji |

**Recommendation: emoji at v1.0; if photos are added later, ship the top 100 by frequency and let
the tail fall back to emoji.** It buys most of the visual gain for a quarter of the size and it
does not compromise offline-first, which is a core feature and not negotiable against a nicer
picture.

### Things that would quietly inflate it, and the rule for each

- **Third-party SDKs.** Analytics, crash reporting and paywall vendors carry 1–5 MB each and
  bring tracking obligations. Ship with **none**; add at most one after launch if a real question
  demands it.
- **Custom fonts.** A full weight range is 1–3 MB. Use the system face — it is also better at
  Dynamic Type, which matters more than the brand does at 7 pt.
- **Bundled photography.** Covered above. Never bundle a second resolution "just in case."
- **Bitcode/debug symbols.** Strip in release; verify the App Store thinned size rather than the
  archive size.

**Measure, don't assume.** The number that matters is the App Store Connect *download* size per
device class, not the `.xcarchive` on disk. Check it at first TestFlight build and treat **30 MB
as the ceiling** — past that, something got in that shouldn't have.
