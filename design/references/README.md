# Mobbin references, per screen

Top-3 shipped-app references for each of our 28 surfaces (`docs/V1_SCOPE.md`), paired with our
own screen render in `design/app/` — same numbering, so `design/references/01-list/` answers to
`design/app/01-list.png`.

**⚠️ Internal design reference only.** These are screenshots of other companies' apps, captured
via Mobbin. Study them; never ship, publish or trace them.

**Coverage: 28 of 28 screens, 3 references each — complete** (2026-08-12, terminal, as Part 3
of `docs/TERMINAL_TICKET_V1_SCREENS.md`).

---

## 01 · List — `design/references/01-list/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Woolworths — list with aisle tags](https://mobbin.com/screens/922e06ed-4f48-410e-a077-9ea26daeefd2) | The only shipped list carrying **aisle location tags, per-item prices, unit prices** (`$1.70 per 100g`) **and `Est. Total $43.75`** at once — the closest existing screen to our whole product |
| 2 | [Amazon Fresh — manage list](https://mobbin.com/flows/c5dd5b81-9a19-46f4-ae13-557b5f4da25e) | Our named shape. **`COMPLETED (5)` collapsed + `SUGGESTED FOR YOU` grid** in one screen — the two patterns V1_SCOPE borrows by name |
| 3 | [Instacart — est. total](https://mobbin.com/screens/7b40d92a-4c38-4a42-bb2c-7b12fbda1d0e) | **`$10.98 Est. total · $4.50 est. savings` pinned to the bottom** — the existence proof for our running `≈` total |

## 02 · Item detail + set price — `design/references/02-item-detail/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Shipt — item detail](https://mobbin.com/screens/ae3327da-42c7-4ffa-a5f1-3bd9494107ef) | Single sheet combines price, quantity stepper, and an editable note — the exact trio the job needs, with "saved to your list" confirmation |
| 2 | [Instacart — estimated price](https://mobbin.com/screens/f83452f7-62d3-4e9c-b7c4-79c3b0abb7ca) | Shows "$0.20 each (est.)" framing plus per-unit pricing and add-a-note — the estimated-vs-actual price moment Bagged hinges on |
| 3 | [Bevel — edit details](https://mobbin.com/screens/59d02871-20ac-4a0a-98eb-0ecb59ecab73) | Edit-details sheet with quantity control, editable line rows, and Save/Remove — clean structure for an editable detail sheet |

## 03 · Aisle order editor — `design/references/03-aisle-order/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Beli — reorder list](https://mobbin.com/screens/e9c035fc-58e0-4747-9e92-57e1e1940ada) | Purest match: numbered rows, right-side drag handles, Cancel/Save chrome — exactly a section-order editor |
| 2 | [Numo — reorder subtasks](https://mobbin.com/screens/3c07deee-ea17-40ff-93ca-397983cd9b90) | Drag handles per row plus add/remove inline — good model if aisles are editable while reordering |
| 3 | [Minna Bank — drag reorder](https://mobbin.com/screens/26f9f654-d59d-4672-877e-d9d0b5599277) | Captures the mid-drag state (lifted row, dimmed siblings, disabled confirm) — useful for the interaction spec, not just layout |

## 04 · Receipt review — `design/references/04-receipt-review/`

| # | Reference | Why |
|---|---|---|
| 1 | [GoPay — receipt scanned, confirm](https://mobbin.com/screens/465e2773-660b-4a11-b7af-fb9747fef87e) | Receipt thumbnail + **Rescan** + line items + *"Make sure this amount is correct"* flagged in amber — a per-line confidence warning, shipped |
| 2 | [Splitwise — confirm items](https://mobbin.com/screens/9a5af576-4e42-476a-b512-75855c6baef9) | *"Add, delete, or modify"* — receipt thumb, editable line list, `+ Add item`, totals. Our review contract exactly |
| 3 | [Airwallex — line items](https://mobbin.com/screens/8d42e55a-4139-4967-b70d-fb5f3f88e4aa) | Line items + view-receipt link as a quiet reference layout |

## 05 · Unmatched line resolver — `design/references/05-line-resolver/`

| # | Reference | Why |
|---|---|---|
| 1 | [MyFitnessPal — "Do these matches look right?"](https://mobbin.com/screens/8b313dbe-0360-45ae-8219-6f260f49d83b) | Raw scanned text quoted *under* the matched catalog name (`"Cottage cheese"` → *Cottage cheese, reduced fat*) — precisely our resolver's job |
| 2 | [Yuka — unknown product](https://mobbin.com/screens/0809f49a-2a01-465a-b7bb-4d9af26c0ae3) | *"Unknown product → Fill in the information"* — the create-new-item-from-unknown path |
| 3 | [Splitwise — confirm items](https://mobbin.com/screens/bab6fc0a-6b74-4cb8-bd12-5d416fba63eb) | Post-scan "Confirm items" list with receipt thumbnail, per-line prices, swipe-to-delete and add-item — the confirm/correct-scanned-lines job |

## 06 · Capture result — `design/references/06-capture-result/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Splitwise — confirm items](https://mobbin.com/screens/ba220c78-9ede-4bd0-ba41-16c6476716fa) | Post-scan summary with receipt thumbnail, item count ("3 items"), line prices, totals, one primary Next — the whole job on one screen |
| 2 | [GoPay — receipt summary](https://mobbin.com/screens/465e2773-660b-4a11-b7af-fb9747fef87e) | "Receipt scanned" state with parsed lines, totals reconciliation, a flagged uncertain amount, and single Confirm — models trust-building after OCR |
| 3 | [MyFitnessPal — matched items](https://mobbin.com/screens/fbfb02de-2388-4354-a88c-e761069da0b3) | "Do these matches look right?" — every scanned line became a structured record, with per-line remove before finishing |

## 07 · Enter by hand — `design/references/07-enter-by-hand/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Airwallex — line items](https://mobbin.com/screens/8b2befc5-22f7-4fa0-81a8-1a8f6c7ddad6) | Name + amount per row, "Add line item", running total with difference check — the manual receipt form almost verbatim |
| 2 | [Brex — itemize expenses](https://mobbin.com/screens/bcf3ad77-20e0-42cb-a6a1-cc11a800d67b) | Itemize-a-total flow with repeating amount rows, add/remove, and count in the CTA ("Itemize 2 expenses") |
| 3 | [Grab — items to purchase](https://mobbin.com/screens/6ca8c70d-db45-4546-941e-f43ea8dddfce) | Grocery-flavored: item name + qty rows, "Add more items", estimated price field — simple enough to work offline with no camera |

## 08 · Prices — `design/references/08-prices/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Woolworths — unit prices](https://mobbin.com/screens/922e06ed-4f48-410e-a077-9ea26daeefd2) | Item list with price, per-100g unit price, aisle tags, and a "Compare lower unit price" action — closest living example of a price-book list |
| 2 | [Rappi — store compare](https://mobbin.com/screens/326e69b8-a405-4b36-99c5-9be58694f126) | Same basket priced per store with store cards up top — the "per store" dimension of the price book home |
| 3 | [Klarna — price history](https://mobbin.com/screens/4afebb15-6c7c-4694-963c-33e1aa139b2a) | "Prices are typical right now" verdict over a price-over-time chart — the drill-in destination from a price-book row |

## 09 · Item price history — `design/references/09-price-history/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Klarna — price tracking](https://mobbin.com/screens/4afebb15-6c7c-4694-963c-33e1aa139b2a) | Actual product price tracking: current price vs typical range, dated line chart, plain-language verdict — closest to per-item grocery price history |
| 2 | [alias — price delta](https://mobbin.com/screens/553aee7a-5064-4eea-9c51-eed0099d4e52) | Leads with the delta ("-$11, 6.01%"), time-range tabs, and all-time high/low rows — the deltas-over-time part of the job |
| 3 | [eBay — price index](https://mobbin.com/screens/0f5dae24-c954-45c8-adcb-b1a2f381c97c) | One item's dated value chart with a "based on N observations" provenance line — matches showing where price data comes from |

## 10 · Month / spend — `design/references/10-month-spend/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Wise — month spend](https://mobbin.com/screens/e48a261e-ef6f-475e-9769-23f742453fc1) | Month selector bars plus "avg monthly spend" vs "spent this month" side by side, then category rows with % share — the whole job on one screen |
| 2 | [N26 — monthly insights](https://mobbin.com/screens/9551a340-6ac1-477d-ad92-826b63c22fc5) | Month-over-month bar overview with current month total and category breakdown below — clean this-month-vs-history structure |
| 3 | [Revolut — category share](https://mobbin.com/screens/56d80261-ebab-49c4-aa2c-de9e23c41abb) | Total with per-category percentage shares and period toggle — good model for the receipts-vs-estimated and per-aisle share rows |

## 11 · Kitchen — `design/references/11-kitchen/`

| # | Reference | Why |
|---|---|---|
| 1 | [Instacart — Family cart](https://mobbin.com/screens/d5a5c097-9786-4570-9e33-d40c347c921b) | *"Items you added · Items Maria added"* — per-member attribution plus invite avatars, our exact members-and-activity job |
| 2 | [Telegram — group checklist](https://mobbin.com/screens/6a478604-82a6-441a-8688-2b68e118d3c3) | *"You marked 'Go to groceries' as done"* — check-off attribution as a feed, the model for our activity list |
| 3 | [TimeTree — shared list + members](https://mobbin.com/screens/a0573db7-640e-478c-a59b-364800552a46) | List content and member roster on one screen without tabs |

## 12 · Places — `design/references/12-places/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Todoist — location reminder](https://mobbin.com/screens/34b823a4-c3fd-4877-a0e8-2bd2574edf00) | Saved place with Arriving/Leaving toggle and visible radius circle on the map — literally "list wakes up when you arrive" |
| 2 | [Transit — saved locations](https://mobbin.com/screens/1fd77bfc-86df-4d56-bee6-2be62621f1f3) | Saved-places list (Work, home, "Add location…") — the "your shops" list shape with per-place edit affordances |
| 3 | [Google Maps — save list](https://mobbin.com/screens/190bf67c-8830-4923-a7cf-924e9e613599) | Saving a place into named lists with per-place notes — pattern for organizing saved shops, weaker on radius |

## 13 · Add / edit a shop — `design/references/13-add-shop/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [SmartThings — geofence radius](https://mobbin.com/screens/dcb05838-d2de-4dc4-8ecd-5f47f987f531) | Search bar + map pin + radius slider (250m) for automating on enter/exit — the exact add-one-shop geofence flow |
| 2 | [Abode — add pin](https://mobbin.com/screens/3612d444-049d-4ddb-a2b8-84418ea24bc7) | Drop a pin, name it, save — the lightweight "add this shop" half of the job |
| 3 | [komoot — radius dial](https://mobbin.com/screens/9be9a6db-212d-460a-82a5-1e14e36eae71) | Pinch-to-set radius circle with live readout over the map — the radius-selection interaction on its own |

## 14 · Setup — `design/references/14-setup/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Ahead — settings banner](https://mobbin.com/screens/a4745676-f82f-465f-aa3a-7cb8e358c58f) | Banner on top plus flat grouped rows including Manage subscription, notifications, privacy — same row inventory as Bagged's settings root |
| 2 | [Mammoth — subscription card](https://mobbin.com/screens/307ef16c-a0ca-4b77-a864-5167ef2292d8) | Subscription status/upgrade card as the first block, iOS grouped rows beneath — the "subscription banner at top" anatomy |
| 3 | [GoPro Quik — sub banner](https://mobbin.com/screens/6cc7d281-d06b-461a-8e4a-fd8af1a54d3c) | Minimal version: promo subscription banner over four grouped rows (Preferences, About, Support) — good floor for how simple this can be |

## 15 · Data & privacy — `design/references/15-data-privacy/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Finch — data inventory](https://mobbin.com/screens/07d41300-f0eb-4082-8bbd-aa305eac4155) | The only screen that shows *where data lives* (cloud backup vs on-device manual backup) plus export and delete — the exact "inventory + location" job |
| 2 | [MacroFactor — export & delete](https://mobbin.com/screens/0e630434-59e2-4b4d-aa86-db68d8abaf43) | Plain-language spreadsheet export (CSV-analog) with honest caveats, delete separated clearly — model for Bagged's export tone |
| 3 | [Zalando — request data file](https://mobbin.com/screens/b44aa19b-0c87-44f3-b90a-a3ca27e9a927) | Describes in prose exactly what the data report contains — the "full inventory of everything we hold" copy pattern |

## 16 · About — `design/references/16-about/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Truecaller — about info](https://mobbin.com/screens/f20bffbb-4c55-4493-ad1e-8b9df469067c) | Version + IDs up top, grouped link sections below — the full about-screen inventory in plain grouped rows |
| 2 | [IMDb — about legal](https://mobbin.com/screens/d47783f9-3620-4342-b607-304be743df08) | APP / HELP / FEEDBACK / LEGAL section grouping — the cleanest information architecture for an about screen |
| 3 | [Calm Sleep — about minimal](https://mobbin.com/screens/b0b8c11f-7343-4781-aa62-5448a5578f17) | Icon + version + two legal links, nothing else — the floor for how small this screen can be |

## 17 · Name your kitchen — `design/references/17-name-kitchen/`

| # | Reference | Why |
|---|---|---|
| 1 | [Tiimo — single-question step](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | One question, one Continue — the onboarding grammar our three steps use |
| 2 | [Tiimo — sign-up name field](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | Pre-filled text field as the entire screen |
| 3 | [Todoist — team name question](https://mobbin.com/screens/8428e71d-549c-4cc5-baee-8e156e0218b9) | "What's the name of your company or team?" — one question, one field, one Next; naming a shared group is the exact analogue of naming your kitchen |

## 18 · Add your first shop — `design/references/18-first-shop/`

| # | Reference | Why |
|---|---|---|
| 1 | [Tiimo — select source step](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | Pick-your-source onboarding step with skip — same job as choosing a shop |
| 2 | [Target — go-to store](https://mobbin.com/screens/02684c06-dc1d-496a-a7bb-1cc7a6dffe6e) | "What's your go-to Target?" onboarding step with nearby-stores + ZIP search paths — the same pick-your-home-store job, grocery-retail context |
| 3 | [Beli — default city](https://mobbin.com/screens/ba90b22c-379d-426c-be95-c3f2f4e0b087) | Onboarding default-location picker framed as low-stakes ("don't worry, you can change anywhere") — good model for a skippable first-shop step |

## 19 · Sign in / restore — `design/references/19-sign-in/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [DAZN — restore purchase](https://mobbin.com/screens/0fcd7743-c5a0-4093-9e51-e05d96e872f3) | Only result with all three job pieces on one screen: email field, Continue with Apple, and a Restore purchase link |
| 2 | [Etsy — guest skip](https://mobbin.com/screens/0fe3b35a-4979-412f-8106-1443cf022e31) | "Continue as guest" under Apple/email — the "guests skip it entirely, not a wall" half of the job |
| 3 | [Tempo — calm sign-in](https://mobbin.com/screens/990d5619-c1aa-433c-9ff1-cb035f11dfe4) | Just two quiet buttons (email, Apple) on a full-bleed screen — the calm, optional register Bagged wants |

## 20 · Capture chooser — `design/references/20-capture-chooser/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Whatnot — add media sheet](https://mobbin.com/screens/daca0ada-b898-4266-8e3c-5ee610004e98) | Bottom sheet offering upload / take photos / scan-a-barcode — the closest three-way camera/barcode/manual triad |
| 2 | [Qonto — upload receipt](https://mobbin.com/screens/900ca044-1399-4ca7-b041-84b6133360d9) | Receipt-specific chooser sheet layered over the add flow — matches Bagged's receipt-camera entry point |
| 3 | [Notion — insert media](https://mobbin.com/screens/2f99a08e-bb58-450d-87d3-b4c7a4073e82) | Canonical compact iOS action sheet with icon-labeled capture modes incl. scan — the minimal + pattern |

## 21 · Receipt camera — `design/references/21-receipt-camera/`

| # | Reference | Why |
|---|---|---|
| 1 | [Brex — scan receipt](https://mobbin.com/screens/fd01b9e0-474a-44d5-a88f-62b18f3a8548) | Minimal scan chrome; **Done carries a count badge** for multi-receipt capture |
| 2 | [GoPay — lighting tip](https://mobbin.com/screens/02c2c4f6-6fb3-4aaf-a0d3-7a2d2ef53e09) | In-viewfinder coaching (*"make sure the receipt is readable"*) — better than failing after the shot |
| 3 | [Bevel — photo or describe](https://mobbin.com/screens/cd1fedb9-7c53-4b03-af89-51793c7ea557) | **Import** and **Describe** flank the shutter — the same alternates as our *Choose a photo / Enter by hand* |

## 22 · Barcode scanner — `design/references/22-barcode-scanner/`

| # | Reference | Why |
|---|---|---|
| 1 | [Walmart — scanner result card](https://mobbin.com/screens/4c4569e1-f276-4336-92e8-13ebed48d275) | Result rises as a card over the live viewfinder, price first, one primary action |
| 2 | [alias — scan result card](https://mobbin.com/screens/0867a5a8-d909-439a-92c6-391eaeb3c27c) | Barcode viewfinder with a result sheet rising from the bottom showing product image, name, and price + action button — the exact scan-to-price interaction |
| 3 | [Yuka — scan score card](https://mobbin.com/screens/eee5a97d-2edb-440a-b8d7-85b477b27da1) | Live viewfinder with corner brackets and a compact item card overlaid at the bottom — clean minimal version of the result-over-camera pattern |

## 23 · Add item (sheet) — `design/references/23-add-item/`

| # | Reference | Why |
|---|---|---|
| 1 | [Tiimo — quick add with Speak](https://mobbin.com/screens/e151c051-959a-4110-b01b-5c99bff12580) | Type-first sheet with a **Speak** button riding the keyboard — our exact add-item shape, from the iPhone App of the Year |
| 2 | [DeepSeek — Hold to speak](https://mobbin.com/screens/6ed73bb9-6aae-4140-86ee-0d44f6cfe551) | The **hold-to-speak** bar treatment our sheet uses |
| 3 | [Grok — Ask + Speak pill](https://mobbin.com/screens/1973a1eb-de26-4507-99d5-2e0608a6e744) | Voice as a first-class equal to typing in one input row |

## 24 · Shop switcher — `design/references/24-shop-switcher/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Instacart — select a store](https://mobbin.com/screens/0ba060f0-c481-4006-8f97-7c9f4e23560c) | Grocery-native bottom sheet: logo-led store list you tap to re-point the current session — the exact job |
| 2 | [Uber Eats — store locations](https://mobbin.com/screens/7ee73fc6-b426-4180-897b-0abd6597e802) | Radio-select sheet whose copy says context follows the store ("carts are unique to each location") — mirrors per-shop aisle order following the switch |
| 3 | [UNIQLO — select store](https://mobbin.com/screens/91d8e9ef-93c4-464f-b4e1-6a517ff05274) | Sheet that explains why the store choice changes what you see downstream, with search + distance |

## 25 · Invite (sheet) — `design/references/25-invite/`

| # | Reference | Why |
|---|---|---|
| 1 | [Instacart — Family cart invite](https://mobbin.com/screens/d5a5c097-9786-4570-9e33-d40c347c921b) | *"Up to 3 people can shop with you"* + `Invite now` slots — value stated before the mechanics |
| 2 | [Numo — invite friends](https://mobbin.com/screens/101adff5-23bd-49bb-96cd-e5ab007657dc) | Member count as the headline, one CTA |
| 3 | [Tiimo — bring your friends](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723) | Warm illustrated invite step; benefit-led copy |

## 26 · Paywall — `design/references/26-paywall/`

| # | Reference | Why this one |
|---|---|---|
| 1 | [Tide Guide — plan compare](https://mobbin.com/screens/5b34dc0f-7bf4-4ba1-ac0f-1780eb282738) | Monthly and yearly both visible with a free/pro feature table and 1-week trial, plus a Skip — calm indie-app paywall closest to Bagged Plus |
| 2 | [The New Yorker — trial plans](https://mobbin.com/screens/46cdf1b1-f3d5-40f1-8c01-992344508a96) | Both annual and monthly as equal buttons, week-free trial, renewal terms in plain sight — zero dark patterns |
| 3 | [The Outsiders — plan cards](https://mobbin.com/screens/65112b07-4e73-4a48-a3f5-0a83e895108e) | Side-by-side monthly/annual price cards with "Start 1 week Free Trial" + "Cancel Anytime" CTA stack |

## 27 · First receipt — `design/references/27-first-receipt/`

| # | Reference | Why |
|---|---|---|
| 1 | [Me+ — task done](https://mobbin.com/screens/26396b82-cb5c-4323-9cff-0aa6cc5d117f) | Literally a "Buy groceries — Done" completion: one big warm word, light sprinkle, zero badges/streaks — closest tone match for the first-receipt moment |
| 2 | [Alan — warm completion](https://mobbin.com/screens/693ebda2-c8d7-4915-b9c0-418cd8c94aeb) | "You did it" with a friendly character and no confetti at all — proof warmth works without particle effects |
| 3 | [Withings Health Mate — missions complete](https://mobbin.com/screens/c52f7e0f-41e5-4e12-96d9-84b1b420f7f9) | Restrained congratulations: static illustration, one label, one CTA back home — celebration without gamification |

## 28 · Widget — `design/references/28-widget/`

| # | Reference | Why |
|---|---|---|
| 1 | [Yazio — meal check widget](https://mobbin.com/screens/4bc38d1d-5a05-4e0a-8939-352891988c19) | Lock-screen widget with four tappable check circles + per-item values — the direct model for checkboxes-plus-running-total |
| 2 | [Runbuds — stats widget](https://mobbin.com/screens/8ebcad43-ccca-4a8e-81c2-70a0496a0393) | Glanceable live-number layout (big primary figure + two secondary stats) — maps to items-remaining / running-total hierarchy |
| 3 | [FocusFlight — progress widget](https://mobbin.com/screens/a54b9f44-7450-44dd-8748-06bd13bd2c3f) | Progress-with-time-remaining lock-screen widget — good pattern for "how far through the trip/list am I" at a glance |

---

## How this folder works

- `design/app/NN-slug.png` — our screen, rendered from the Figma spec page `74:16`
  (`Bagged · Screens`, file `Lpx5Pdgvy3Gx8l5ZSDS0JH`). Note: renders predate the Shelf cut —
  several still show shelf copy and a 4-tab bar; the layouts are what's referenced
- `design/references/NN-slug/1..3-app-pattern.webp` — top-3 Mobbin references for that screen,
  ranked, named `rank-app-pattern`
