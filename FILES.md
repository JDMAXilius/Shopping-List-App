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
│   │   │   ├── Shop.swift             # Shop, AisleOrder — no coordinate, ever
│   │   │   ├── Money.swift            # Money, rounding — ~$4.50 never $4.37
│   │   │   ├── PriceObservation.swift # measured vs estimate, 90-day decay
│   │   │   ├── Operation.swift        # add/check/uncheck/edit/delete/price/shop/alias/name
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
│   │   │   ├── PriceSeed.swift        # 461 items × 8 regions, hard rounding
│   │   │   └── Resources/catalog.db   # 220 KB, built by data/catalog/build.mjs
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
│   │   │       ├── SyncEngine.swift   # actor — kitchen-scoped drain, retry, backoff
│   │   │       ├── SyncTransport.swift# the protocol
│   │   │       ├── SupabaseTransport.swift  # push_ops + PostgREST, cursor-ordered
│   │   │       └── DeviceIdentity.swift
│   │   └── Tests/DataTests/
│   │       ├── MigrationTests · RepositoryTests · SyncEngineTests (fake transport)
│   │
│   └── DesignKit/                     # tokens + shared components · zero feature code
│       ├── Sources/DesignKit/
│       │   ├── Palette.swift          # paper, ink, persimmon, confirmed, aisle tints
│       │   │                          #   + Surface: which ground a component sits on
│       │   ├── Emphasis.swift         # muted vs attention — the persimmon-contrast rule,
│       │   │                          #   one home for SectionLabel · Chip · Notice
│       │   ├── Typography.swift       # system sans; prices = mono tabular
│       │   ├── Motion.swift           # 150–250ms, spring, interruptible, Reduce Motion
│       │   │                          #   + undoDwell: how long an undo offer stands
│       │   ├── Haptics.swift          # event → pattern map
│       │   ├── Sound.swift            # the two sounds, ambient session, silent switch
│       │   ├── Glyphs.swift           # line-icon set: 22 categories + top items
│       │   ├── Components/            # ItemRow · PriceLabel · AisleHeader · TotalBar
│       │   │                          #   · InputBar · TabPill · EmptyState
│       │   │                          #   · SectionLabel · UndoBar
│       │   │                          #   · Chip · Notice · Field (+ OptionalFocus)
│       │   │                          #   · PaidTotal — money PAID, not prices summed
│       │   └── Resources/             # check.wav · complete.wav (generated, spec-tested)
│       └── Tests/DesignKitTests/
│           └── SnapshotTests          # ONE style · default + largest Dynamic Type
│
├── App/
│   ├── BaggedApp.swift                # @main + AppSession: joining a kitchen rebuilds
│   │                                  #   every store, so they cannot be `let`s
│   ├── RootView.swift                 # TabView: List · Prices · You, + capture button
│   ├── Route.swift · Sheet.swift      # the two navigation enums — all of navigation
│   ├── Environment+.swift             # @Entry keys for every store
│   │
│   ├── Features/
│   │   ├── List/                      # tab 1 — the product
│   │   │   ├── ListScreen.swift       # aisles, subtotals, NO PRICE YET, COMPLETED(n)
│   │   │   ├── ListStore.swift      ★ # the core store
│   │   │   ├── ListDerivation.swift   # rows, sections, inline suggestions
│   │   │   ├── ItemDetailSheet.swift  # qty, note, set-what-you-paid
│   │   │   ├── AisleOrderEditor.swift # drag to reorder, per shop
│   │   │   └── ShopSwitcherSheet.swift
│   │   │
│   │   ├── Capture/                   # the + — the engine
│   │   │   ├── CaptureSession.swift   # per-flow @Observable · the ONLY writer
│   │   │   ├── CaptureDerivation.swift     # lines, matches, money-off, the result
│   │   │   ├── CaptureChooserSheet.swift
│   │   │   ├── ReceiptCamera.swift         # AVFoundation, the shutter itself
│   │   │   ├── ReceiptCameraScreen.swift
│   │   │   ├── ReceiptReviewScreen.swift   # nothing commits unreviewed
│   │   │   ├── LineResolverScreen.swift    # matched once, remembered forever
│   │   │   ├── CaptureShopPicker.swift     # returns a choice; never re-points the list
│   │   │   ├── CaptureResultScreen.swift   # "6 prices are now real"
│   │   │   ├── EnterByHandScreen.swift     # no camera, no signal
│   │   │   ├── BarcodeScanScreen.swift     # a key the kitchen teaches once, not a lookup
│   │   │   └── FirstReceiptSheet.swift     # the aha, once
│   │   │
│   │   ├── Prices/                    # tab 2 — the differentiator
│   │   │   ├── PricesScreen.swift     # the price book
│   │   │   ├── PriceStore.swift · PriceDerivation.swift
│   │   │   ├── PriceHistoryScreen.swift    # per store, dated, deltas
│   │   │   └── MonthSpendScreen.swift      # from RECEIPTS, not observations
│   │   │
│   │   ├── Kitchen/                   # sharing — the growth loop
│   │   │   ├── KitchenStore.swift     # the store · KitchenScreen.swift
│   │   │   ├── KitchenClient.swift    # RPC + PostgREST · KitchenAuth.swift  sessions
│   │   │   ├── KitchenServices.swift  # nil when this build has no SupabaseURL
│   │   │   ├── KitchenLink.swift      # parses a token out of anything a person pastes
│   │   │   ├── SyncCoordinator.swift  # poll on foreground + kick after a write
│   │   │   ├── InviteSheet.swift      # link + QR; a new link revokes the old
│   │   │   ├── JoinScreen.swift       # guests: no account, ever
│   │   │   ├── NameKitchenSheet.swift # contextual — at first invite
│   │   │   └── SignInScreen.swift     # owners only
│   │   │
│   │   ├── Places/                    # a coordinate is never an op
│   │   │   ├── Place.swift            # pin + radius, LOCAL FILE, not the App Group
│   │   │   ├── PlaceStore.swift       # 20-region cap, deterministic choice
│   │   │   ├── PlacesScreen.swift · ShopEditorScreen.swift · FirstShopSheet.swift
│   │   │
│   │   └── You/                       # tab 3 — Setup is the root, not a push
│   │       ├── SetupScreen.swift      # + SetupSettings: sound/haptics, applied at launch
│   │       ├── DataPrivacyScreen.swift# what leaves, what doesn't · the barcode switch
│   │       ├── AboutScreen.swift      # credits only what ships · WhyItWorksThisWay.swift
│   │       ├── PaywallScreen.swift    # $2.99/mo · $29.99/yr · zero dark patterns
│   │       ├── SubscriptionStore.swift# a joiner is never paywalled
│   │       └── ScreensPanel.swift     # TEMPORARY testing scaffolding, behind
│   │                                  # BAGGED_SCREENS_PANEL. Owns no Route/Sheet case;
│   │                                  # drop the flag from project.yml's Release line and
│   │                                  # it leaves the binary (BLOCKERS §10)
│   │
│   └── Services/                      # thin wrappers returning plain values
│       ├── VisionService.swift        # barcode + printed text
│       ├── LocationService.swift      # CLMonitor; never logs a coordinate
│       ├── ScanClient.swift           # calls scan-receipt — NO AI key in the app
│       ├── ProductLookup.swift        # Open Food Facts: a NAME, never an image, never stored
│       ├── ScriptedScanBackend.swift  # DEBUG only — how the receipt path is UI-tested
│       └── CSVExporter.swift          # money as minor units, never a formatted string
│
├── Widget/                            # own process — reads db, NEVER migrates it
│   ├── BaggedWidget.swift · ListWidgetView.swift
│   ├── WidgetProvider.swift           # timeline; resolves the shop where the repo exists
│   └── ToggleItemIntent.swift         # the lock-screen checkbox → op-log, or refuses
│
├── Intents/                           # Siri · Shortcuts · Action Button · Control Center
│   ├── Entities/                      # ListItemEntity · ShopEntity
│   ├── AddItemIntent.swift            # "add milk at Trader Joe's" — moves the list there
│   ├── CheckOffIntent.swift · RemoveItemIntent.swift   # remove confirms; voice > touch risk
│   ├── WhatsLeftIntent.swift          # the one the .reminders schema could not do
│   ├── ReadListIntent.swift           # in aisle order — the order you hear it in
│   ├── IntentContext.swift            # ONE schema check; refuses rather than writing
│   ├── BaggedShortcuts.swift
│   └── Schema27/                      # Apple's .reminders cluster — PARKED, in no target
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

**183 source files** — 78 in `Packages/`, 65 under `App/`, 7 widget, 10 intents (+ 12 parked),
plus the backend. All nine waves are built. States (empty · offline · scan failed · primers) are
view states inside their screens, not files.

Four things are NOT here and are deliberate: `SpeechService` (the mic stays off until it exists —
an affordance must not promise voice one screen before a sheet denies it),
`FoundationModelsService`, `AisleOrderEditor`'s duplicate in Places, and Apple's `.reminders`
cluster, parked in `Intents/Schema27/` for an OS that can run it.

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
