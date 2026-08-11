# Mobbin references, per screen

Top-3 shipped-app references for each of our 28 surfaces (`docs/V1_SCOPE.md`), paired with our
own screen render in `design/app/` — same numbering, so `design/references/01-list/` answers to
`design/app/01-list.png`.

**⚠️ Internal design reference only.** These are screenshots of other companies' apps, captured
via Mobbin. Study them; never ship, publish or trace them.

**⚠️ Coverage is partial — 6 of 28 screens have their references on disk.** The Mobbin
connector reconnected mid-session and now every call returns *"requires approval"*, which only
you can grant (approve the Mobbin MCP tool when prompted in the session UI, or re-add the
connector). The six folders below were assembled from Mobbin searches already cached in this
session. Every remaining screen has its search already written — column 3 — so filling them is
mechanical once the connector is approved.

---

## Filled — top 3 on disk

### 01 · List — `design/references/01-list/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Woolworths — list with aisle tags](https://mobbin.com/screens/922e06ed-4f48-410e-a077-9ea26daeefd2) | The only shipped list carrying **aisle location tags, per-item prices, unit prices** (`$1.70 per 100g`) **and `Est. Total $43.75`** at once — the closest existing screen to our whole product |
| 2 | [Amazon Fresh — manage list](https://mobbin.com/flows/c5dd5b81-9a19-46f4-ae13-557b5f4da25e) | Our named shape. **`COMPLETED (5)` collapsed + `SUGGESTED FOR YOU` grid** in one screen — the two patterns V1_SCOPE borrows by name |
| 3 | [Instacart — est. total](https://mobbin.com/screens/7b40d92a-4c38-4a42-bb2c-7b12fbda1d0e) | **`$10.98 Est. total · $4.50 est. savings` pinned to the bottom** — the existence proof for our running `≈` total |

### 11 · Kitchen — `design/references/11-kitchen/`

| # | Reference | Why |
|---|---|---|
| 1 | [Instacart — Family cart](https://mobbin.com/screens/d5a5c097-9786-4570-9e33-d40c347c921b) | *"Items you added · Items Maria added"* — per-member attribution plus invite avatars, our exact members-and-activity job |
| 2 | [Telegram — group checklist](https://mobbin.com/screens/6a478604-82a6-441a-8688-2b68e118d3c3) | *"You marked 'Go to groceries' as done"* — check-off attribution as a feed, the model for our activity list |
| 3 | [TimeTree — shared list + members](https://mobbin.com/screens/a0573db7-640e-478c-a59b-364800552a46) | List content and member roster on one screen without tabs |

### 23 · Add item (sheet) — `design/references/23-add-item/`

| # | Reference | Why |
|---|---|---|
| 1 | [Tiimo — quick add with Speak](https://mobbin.com/screens/e151c051-959a-4110-b01b-5c99bff12580) | Type-first sheet with a **Speak** button riding the keyboard — our exact add-item shape, from the iPhone App of the Year |
| 2 | [DeepSeek — Hold to speak](https://mobbin.com/screens/6ed73bb9-6aae-4140-86ee-0d44f6cfe551) | The **hold-to-speak** bar treatment our sheet uses |
| 3 | [Grok — Ask + Speak pill](https://mobbin.com/screens/1973a1eb-de26-4507-99d5-2e0608a6e744) | Voice as a first-class equal to typing in one input row |

### 25 · Invite (sheet) — `design/references/25-invite/`

| # | Reference | Why |
|---|---|---|
| 1 | [Instacart — Family cart invite](https://mobbin.com/screens/d5a5c097-9786-4570-9e33-d40c347c921b) | *"Up to 3 people can shop with you"* + `Invite now` slots — value stated before the mechanics |
| 2 | [Numo — invite friends](https://mobbin.com/screens/101adff5-23bd-49bb-96cd-e5ab007657dc) | Member count as the headline, one CTA |
| 3 | [Tiimo — bring your friends](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | Warm illustrated invite step; benefit-led copy |

### 17 · Name your kitchen — `design/references/17-name-kitchen/` *(2 of 3)*

| # | Reference | Why |
|---|---|---|
| 1 | [Tiimo — single-question step](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | One question, one Continue — the onboarding grammar our three steps use |
| 2 | [Tiimo — sign-up name field](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | Pre-filled text field as the entire screen |

### 18 · Add your first shop — `design/references/18-first-shop/` *(1 of 3)*

| # | Reference | Why |
|---|---|---|
| 1 | [Tiimo — select source step](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | Pick-your-source onboarding step with skip — same job as choosing a shop |

---

## Pending — searches written, connector approval needed

Queries are ready to paste into `search_screens` (platform `ios`). Expected strong sources are a
prediction, not a result — replace them with what the search actually returns.

| Screen | Query to run | Expect strong results from |
|---|---|---|
| 02 Item detail + set price | `grocery or pantry item detail screen with editable price quantity and notes` | Instacart, Flink, Getir |
| 03 Aisle order editor | `reorderable list editor with drag handles to change section order` | Todoist, Things, Notion |
| 04 Receipt review | `receipt scan review screen listing extracted line items to confirm` | YNAB, Expensify, Fudget |
| 05 Line resolver | `match unrecognized scanned product to a catalog item suggestion list` | Yuka, MyFitnessPal |
| 06 Capture result | `success summary screen after scanning showing what was added` | Yuka, Flashfood |
| 07 Enter by hand | `manual expense entry form with line items and amounts` | YNAB, Money Manager |
| 08 Prices | `personal price tracking screen showing what you paid per item over time` | Flipp, Basket |
| 09 Item price history | `price history chart for one product with dated entries` | CamelCamelCamel-likes, Flipp |
| 10 Month / spend | `monthly spending summary with total versus last month and per-store breakdown` | Copilot, YNAB, Monarch |
| 12 Places | `saved store locations list with geofence or arrival reminders` | Reminders-style, Flink |
| 13 Add / edit a shop | `add a place with map pin and radius selection` | Find My, Reminders |
| 14 Setup | `settings screen with grouped rows and a subscription banner at top` | Any top-grossing utility |
| 15 Data & privacy | `privacy settings screen showing what data is stored and export options` | Signal, WhatsApp |
| 16 About | `about screen with version support links and legal` | — any |
| 19 Sign in / restore | `sign in screen with Continue with Apple and email and restore purchases` | Tiimo, Bear, Flighty |
| 20 Capture chooser | `bottom sheet choosing between camera scan barcode and manual entry` | Yuka, MyFitnessPal |
| 21 Receipt camera | `receipt scanning camera screen capturing a paper receipt` | Expensify, YNAB |
| 22 Barcode scanner | `barcode scanner camera screen with result card` | Yuka, Amazon |
| 24 Shop switcher | `bottom sheet picking which store you are shopping at` | Flink, Instacart |
| 26 Paywall | `subscription paywall with annual and monthly plans and a 7 day free trial` | Tiimo, Flighty, Bear |
| 27 First receipt | `first time success moment after completing the core action` | Duolingo-likes, Flighty |
| 28 Widget | `lock screen widget with checklist or glanceable total` | Flighty, Things, Fitness |

**Also already in the cache, unused:** a "distinctive bottom navigation" pool (Apple Fitness,
Hypelist, Orbit, Wabi…) — global chrome reference, kept in the session scratchpad, promote if
useful.

---

## How this folder works

- `design/app/NN-slug.png` — our screen, rendered from the Figma spec page `74:16`
  (`Bagged · Screens`, file `Lpx5Pdgvy3Gx8l5ZSDS0JH`). Note: renders predate the Shelf cut —
  several still show shelf copy and a 4-tab bar; the layouts are what's referenced
- `design/references/NN-slug/1..3-app-pattern.webp` — top-3 Mobbin references for that screen,
  ranked, named `rank-app-pattern`
- Screens without a folder here have no honest reference yet — see the pending table
