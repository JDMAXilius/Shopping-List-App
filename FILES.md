# The app, as files — final visual layout

Matches `ARCHITECTURE.md` (final). Every file has one job; anything not here is a **no** until
argued for. `★` = highest-risk, build first.

```
Bagged/
│
├── Packages/                          # layer-first — app, widget AND intents link these
│   │
│   ├── Core/                          # pure logic · imports nothing · tests run on CLI
│   │   ├── Sources/Core/
│   │   │   ├── Item.swift             # Item, ListItem, quantity + unit
│   │   │   ├── Kitchen.swift          # Kitchen, Member, InviteToken
│   │   │   ├── Shop.swift             # Shop, AisleOrder
│   │   │   ├── Money.swift            # Money, rounding — ~$4.50 never $4.37
│   │   │   ├── PriceObservation.swift # measured vs estimate, 90-day decay
│   │   │   ├── Operation.swift        # the op enum: add/check/uncheck/edit/delete/price/shop
│   │   │   ├── LogicalClock.swift     # per-device counter
│   │   │   ├── Merge.swift          ★ # LWW per field, idempotent add — the sync brain
│   │   │   └── Identifiers.swift      # typed UUID wrappers
│   │   └── Tests/CoreTests/
│   │       ├── ConflictHarnessTests ★ # two devices, offline edits, reconnect — test #1
│   │       ├── MergeTests · LogicalClockTests · MoneyTests
│   │
│   ├── Catalog/                       # the owned IP
│   │   ├── Sources/Catalog/
│   │   │   ├── CatalogDatabase.swift  # read-only open of the bundled db
│   │   │   ├── Resolver.swift         # query → item, ranked cascade
│   │   │   ├── Normalizer.swift       # case, articles, singularise, qualifiers
│   │   │   ├── QuantityParser.swift   # "2 lb chicken" → qty, unit, name
│   │   │   ├── EditDistance.swift     # typos = mis-transcriptions, same fix
│   │   │   ├── PriceSeed.swift        # 414 × 8 regions, hard rounding
│   │   │   └── Resources/catalog.db   # 200 KB, built by data/catalog/build.mjs
│   │   └── Tests/CatalogTests/
│   │       ├── ResolverTests          # the 23 golden cases, ported
│   │       ├── QuantityParserTests · NormalizerTests · PriceSeedTests
│   │
│   ├── Data/                          # persistence + sync
│   │   ├── Sources/Data/
│   │   │   ├── AppDatabase.swift      # DatabasePool, App Group URL, WAL
│   │   │   ├── Migrations.swift       # forward-only, versioned
│   │   │   ├── Observed.swift         # ValueObservation → @Observable, ~40 lines
│   │   │   ├── Repository.swift     ★ # the ONLY file that writes SQL
│   │   │   ├── Records/               # ListItem · Kitchen · Shop · Price · Receipt · Op
│   │   │   └── Sync/
│   │   │       ├── SyncEngine.swift   # actor — drain, retry, backoff
│   │   │       ├── SyncTransport.swift# protocol + SupabaseTransport
│   │   │       └── DeviceIdentity.swift
│   │   └── Tests/DataTests/
│   │       ├── MigrationTests · RepositoryTests · SyncEngineTests (fake transport)
│   │
│   └── DesignKit/                     # tokens + shared components · zero feature code
│       ├── Sources/DesignKit/
│       │   ├── Palette.swift          # paper, ink, persimmon, confirmed, aisle tints
│       │   ├── Typography.swift       # system sans; prices = mono tabular
│       │   ├── Motion.swift           # 150–250ms, spring, interruptible, Reduce Motion
│       │   ├── Haptics.swift          # event → pattern map
│       │   ├── Sound.swift            # the two sounds, ambient session, silent switch
│       │   ├── Glyphs.swift           # line-icon set: 22 categories + top items
│       │   ├── Components/            # ItemRow · PriceLabel · AisleHeader · TotalBar
│       │   │                          #   · InputBar · TabPill · EmptyState
│       │   └── Resources/             # check.caf · complete.caf · Glyphs · Colors
│       └── Tests/DesignKitTests/
│           └── SnapshotTests          # ONE style · default + largest Dynamic Type
│
├── App/
│   ├── BaggedApp.swift                # @main, environment wiring, db bootstrap
│   ├── RootView.swift                 # TabView: List · Prices · You, + capture button
│   ├── Route.swift · Sheet.swift      # the two navigation enums — all of navigation
│   ├── Environment+.swift             # @Entry keys for the three stores
│   │
│   ├── Features/
│   │   ├── List/                      # tab 1 — the product
│   │   │   ├── ListScreen.swift       # aisles, subtotals, NO PRICE YET, COMPLETED(n)
│   │   │   ├── ListStore.swift      ★ # the core store
│   │   │   ├── AddItemSheet.swift     # autocomplete + hold-to-speak
│   │   │   ├── ItemDetailSheet.swift  # qty, note, set-what-you-paid
│   │   │   ├── AisleOrderEditor.swift # drag to reorder, per shop
│   │   │   └── ShopSwitcherSheet.swift
│   │   │
│   │   ├── Capture/                   # the + — the engine
│   │   │   ├── CaptureSession.swift   # per-flow @Observable
│   │   │   ├── CaptureChooserSheet.swift
│   │   │   ├── ReceiptCameraScreen.swift
│   │   │   ├── ReceiptReviewScreen.swift   # nothing commits unreviewed
│   │   │   ├── LineResolverScreen.swift    # matched once, remembered forever
│   │   │   ├── CaptureResultScreen.swift   # "6 prices are now real"
│   │   │   ├── EnterByHandScreen.swift     # no camera, no signal
│   │   │   ├── BarcodeScanScreen.swift
│   │   │   └── FirstReceiptSheet.swift     # the aha, once
│   │   │
│   │   ├── Prices/                    # tab 2 — the differentiator
│   │   │   ├── PricesScreen.swift     # the price book
│   │   │   ├── PriceStore.swift
│   │   │   ├── PriceHistoryScreen.swift    # per store, dated, deltas
│   │   │   └── MonthSpendScreen.swift      # Δ vs your usual, ink never red
│   │   │
│   │   ├── Kitchen/                   # sharing — the growth loop
│   │   │   ├── KitchenScreen.swift    # members + activity
│   │   │   ├── InviteSheet.swift      # link + QR; new link revokes old
│   │   │   ├── JoinScreen.swift       # guests: no account, ever
│   │   │   ├── NameKitchenSheet.swift # contextual — appears at first invite
│   │   │   └── SignInScreen.swift     # owners only
│   │   │
│   │   ├── Places/
│   │   │   ├── PlacesScreen.swift     # shops, wake-up radius
│   │   │   ├── ShopEditorScreen.swift # pin + radius + aisle order
│   │   │   └── FirstShopSheet.swift   # contextual — first switcher use
│   │   │
│   │   └── You/                       # tab 3
│   │       ├── SetupScreen.swift
│   │       ├── DataPrivacyScreen.swift# everything held, and where · CSV export
│   │       ├── AboutScreen.swift
│   │       ├── WhyItWorksThisWay.swift# the ADHD page — rationale, no health claims
│   │       ├── PaywallScreen.swift    # $2.99/mo · $29.99/yr · zero dark patterns
│   │       └── SubscriptionStore.swift
│   │
│   └── Services/                      # thin wrappers returning plain values
│       ├── SpeechService.swift        # on-device only, requiresOnDeviceRecognition
│       ├── VisionService.swift        # barcode + printed text
│       ├── LocationService.swift      # geofences, on-device, never uploaded
│       ├── ScanClient.swift           # calls scan-receipt Edge Function — NO AI key in app
│       ├── FoundationModelsService.swift  # iOS 26+, availability-gated
│       └── CSVExporter.swift
│
├── Widget/                            # own process — reads db, never stores
│   ├── BaggedWidget.swift · ListWidgetView.swift
│   ├── WidgetProvider.swift           # timeline via Repository
│   └── ToggleItemIntent.swift         # the tappable lock-screen checkbox → op-log
│
├── Intents/                           # Siri · Shortcuts · Action Button · Control Center
│   ├── Entities/                      # ListEntity · ItemEntity · SectionEntity
│   ├── CreateReminderIntent.swift     # "add milk"        (.reminders schema)
│   ├── UpdateReminderIntent.swift     # check off, edit
│   ├── DeleteRemindersIntent.swift
│   ├── SectionIntents.swift           # aisle groups
│   └── BaggedShortcuts.swift          # ⚠️ whole cluster or Xcode fails the build
│
└── supabase/                          # the entire backend
    ├── migrations/
    │   ├── 0001_schema.sql            # kitchen · member · invite · op · entitlement
    │   └── 0002_rls.sql             ★ # membership isolation — THE security model
    ├── functions/
    │   ├── scan-receipt/index.ts      # entitlement + quota → Claude → line items
    │   ├── join-kitchen/index.ts      # invite token → anonymous member
    │   └── revenuecat-webhook/index.ts
    └── tests/rls.test.sql             # kitchen A cannot read kitchen B — proven
```

**~120 files total** — ~95 Swift sources, 12 test files, 5 resource bundles, 6 backend files —
covering 28 surfaces, the widget, the full Siri cluster, and the backend. States (empty ·
offline · scan failed · primers) are view states inside their screens, not files.

## Where a change lands

| Change | Touches |
|---|---|
| New synonym / catalog item | `data/catalog/` (repo) → rebuilt `catalog.db` |
| A sync bug | `Core/Merge.swift` or `Data/Sync/` — nowhere else |
| A new screen | Its feature folder + `Route.swift` |
| Anything visual | `DesignKit` only — widget inherits it free |
| Price rules | `Core/Money.swift` + `Catalog/PriceSeed.swift` |
| Paywall / gating | `SubscriptionStore` + `supabase/functions/` |

## The repo around it (planning corpus, already built)

```
Shopping-List-App/
├── PRODUCT.md ★ the final word     ├── data/catalog/   414 items + resolver, 23 tests ✓
├── ARCHITECTURE.md  this plan      ├── design/app/     29 final screen renders
├── DECISIONS.md · docs/V1_SCOPE.md ├── design/references/  28 × top-3 Mobbin refs
├── STACK · ENGINEERING · OPS       ├── design/concepts/    6 HTML directions
├── INTERACTION · BRAND · NAMING    ├── research/       competitors · store · tiimo
└── PLAN · MARKET · VALIDATION      └── Figma 138:978   the canonical 31 frames
```
