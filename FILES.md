# File structure — the whole repository, present and planned

A single visual map. Everything that exists today, and every file the app will have.

**Legend:** `✅` exists now · `○` planned · `★` highest-value / highest-risk file

---

## 1. The repository today — 25 files

```
Shopping-List-App/
│
├── ✅ DECISIONS.md ................ every decision on one page — START HERE
│
├── Strategy & research
│   ├── ✅ RESEARCH.md ............. product + competitive research, the data model
│   ├── ✅ MARKET.md ............... sizing, segments, subscription unit economics
│   ├── ✅ FEATURES.md ............. the five core features · AI ladder · scope
│   ├── ✅ CAPABILITIES.md ......... every capability as a flat bullet list
│   ├── ✅ PLAN.md ................. plan of record — strategy, pricing, GTM, sequence
│   └── research/
│       ├── ✅ competitors.md ...... revenue & downloads dossier
│       └── ✅ store-teardown.md ... App Store listing teardowns
│
├── Brand
│   ├── ✅ BRAND.md ................ positioning, palette, voice, store presence
│   └── ✅ NAMING.md ............... naming evidence + §9 screening results
│
├── Engineering
│   ├── ✅ ENGINEERING.md .......... method per feature · on-device ladder · size
│   ├── ✅ STACK.md ................ Swift 6 + SwiftUI, the three dependencies
│   ├── ✅ ARCHITECTURE.md ......... pattern, concurrency, data flow, file plan
│   ├── ✅ INTERACTION.md .......... ADHD design, motion, haptics, sound
│   ├── ✅ SOURCING.md ............. catalog IP + imagery licensing
│   ├── ✅ OPS.md .................. platform argument, services, release path
│   └── ✅ FILES.md ................ this file
│
├── data/catalog/                    ← the built, working catalog
│   ├── ✅ README.md
│   ├── ✅ catalog.json ............ 414 items, 22 categories, 8 regions · 48 KB
│   ├── ✅ schema.sql .............. SQLite schema + indexes
│   ├── ✅ build.mjs ............... validates + compiles → catalog.db (200 KB)
│   ├── ✅ resolve.mjs ............. query resolver + 23 passing tests
│   └── ⛔ catalog.db .............. build artifact, gitignored
│
├── design/
│   ├── ✅ brand-sheet.html / .png
│   └── mockups/
│       └── ✅ list-screen.html / .png
│
└── ✅ .gitignore
```

---

## 2. The app — planned, ~80 files

```
Bagged/
│
├── ○ Bagged.xcodeproj
│
├── Packages/ ─────────────────── layer-first: all three targets link these
│   │
│   ├── Core/ ───────────────── pure logic · imports nothing · no UI, no I/O
│   │   ├── Sources/Core/
│   │   │   ├── ○ Item.swift ................... Item, ListItem, quantity + unit
│   │   │   ├── ○ Household.swift .............. Household, Member, InviteToken
│   │   │   ├── ○ Store.swift .................. Store, AisleOrder
│   │   │   ├── ○ Money.swift .................. Money, Currency, rounding rules
│   │   │   ├── ○ PriceObservation.swift ....... observation vs estimate, provenance
│   │   │   ├── ○ Operation.swift .............. the op-log enum + payloads
│   │   │   ├── ○ LogicalClock.swift ........... per-device counter
│   │   │   ├── ★ Merge.swift .................. last-write-wins per field, idempotent add
│   │   │   └── ○ Identifiers.swift ............ typed UUID wrappers
│   │   └── Tests/CoreTests/
│   │       ├── ○ MergeTests.swift
│   │       ├── ★ ConflictHarnessTests.swift ... two devices, offline edits, reconnect
│   │       ├── ○ LogicalClockTests.swift
│   │       └── ○ MoneyTests.swift
│   │
│   ├── Catalog/ ────────────── the resolver · pure · heavily tested
│   │   ├── Sources/Catalog/
│   │   │   ├── ○ CatalogDatabase.swift ........ read-only open of catalog.db
│   │   │   ├── ★ Resolver.swift ............... query → item, the ranked cascade
│   │   │   ├── ○ Normalizer.swift ............. case, articles, plurals, qualifiers
│   │   │   ├── ○ QuantityParser.swift ......... "2 lb chicken" → qty, unit, name
│   │   │   ├── ○ EditDistance.swift ........... bounded, for typos
│   │   │   ├── ○ PriceSeed.swift .............. region multiplier + rounding
│   │   │   └── Resources/
│   │   │       └── ○ catalog.db ............... 200 KB, from data/catalog/
│   │   └── Tests/CatalogTests/
│   │       ├── ★ ResolverTests.swift .......... the existing 23 cases, ported
│   │       ├── ○ QuantityParserTests.swift
│   │       ├── ○ NormalizerTests.swift
│   │       └── ○ PriceSeedTests.swift ......... asserts $0.50 / $1 rounding
│   │
│   ├── Data/ ───────────────── GRDB · App Group · sync
│   │   ├── Sources/Data/
│   │   │   ├── ★ AppDatabase.swift ............ DatabasePool, App Group URL, WAL
│   │   │   ├── ○ Migrations.swift ............. forward-only, versioned
│   │   │   ├── ○ Observed.swift ............... ValueObservation → @Observable (~40 lines)
│   │   │   ├── ★ Repository.swift ............. the ONLY read/write surface above SQL
│   │   │   ├── Records/
│   │   │   │   ├── ○ ListRecord.swift
│   │   │   │   ├── ○ ListItemRecord.swift
│   │   │   │   ├── ○ HouseholdRecord.swift
│   │   │   │   ├── ○ StoreRecord.swift
│   │   │   │   ├── ○ PriceRecord.swift
│   │   │   │   └── ○ OpRecord.swift
│   │   │   └── Sync/
│   │   │       ├── ★ SyncEngine.swift ......... actor: drain, retry, backoff
│   │   │       ├── ○ SyncTransport.swift ...... protocol + SupabaseTransport
│   │   │       └── ○ DeviceIdentity.swift ..... anonymous UUID, upgradeable
│   │   └── Tests/DataTests/
│   │       ├── ○ MigrationTests.swift ......... each against a prior-release fixture
│   │       ├── ○ RepositoryTests.swift
│   │       └── ○ SyncEngineTests.swift ........ against a fake transport
│   │
│   └── DesignKit/ ──────────── tokens + primitives · zero feature code
│       ├── Sources/DesignKit/
│       │   ├── ○ Palette.swift ................ paper, card, ink, muted, line, persimmon
│       │   ├── ○ Typography.swift ............. scale + Dynamic Type mapping
│       │   ├── ○ Motion.swift ................. durations, springs, Reduce Motion paths
│       │   ├── ○ Haptics.swift ................ the event → pattern map
│       │   ├── ○ Sound.swift .................. two sounds, ambient session, silent switch
│       │   ├── Components/
│       │   │   ├── ★ ItemRow.swift ............ the most-seen view in the app
│       │   │   ├── ○ QuantityChip.swift ....... ⚠ placement still undecided
│       │   │   ├── ○ PriceLabel.swift ......... estimate vs observed rendering
│       │   │   ├── ○ SectionHeader.swift
│       │   │   ├── ○ TotalBar.swift
│       │   │   └── ○ EmptyState.swift
│       │   └── Resources/
│       │       ├── ○ Sounds/check.caf ......... must survive 40 repetitions
│       │       ├── ○ Sounds/complete.caf
│       │       └── ○ Colors.xcassets
│       └── Tests/DesignKitTests/
│           └── ○ SnapshotTests.swift .......... light, dark, largest Dynamic Type
│
├── App/ ──────────────────────── feature-first: change is local to a screen
│   ├── ○ BaggedApp.swift .................. @main, environment wiring, bootstrap
│   ├── ○ RootView.swift
│   ├── ○ Route.swift ...................... the navigation enum
│   ├── ○ Sheet.swift ...................... the sheet enum — never loose booleans
│   ├── ○ EnvironmentValues+.swift ......... @Entry keys for the stores
│   │
│   ├── Features/List/
│   │   ├── ★ ListScreen.swift ............. the app, essentially
│   │   ├── ★ ListStore.swift .............. the core @Observable store
│   │   ├── ★ AddField.swift ............... the ≤2-tap add path
│   │   ├── ○ AutocompleteResults.swift .... personal → household → catalog
│   │   ├── ○ ItemDetailSheet.swift ........ quantity, note, price
│   │   └── ○ CheckOffAnimation.swift ...... strike, desaturate, sink
│   │
│   ├── Features/Stores/
│   │   ├── ○ StorePickerScreen.swift
│   │   └── ○ AisleOrderEditor.swift ....... drag to reorder, per store
│   │
│   ├── Features/Household/
│   │   ├── ○ ShareListSheet.swift ......... invite link generation
│   │   ├── ○ JoinListScreen.swift ......... no-account join
│   │   └── ○ MembersScreen.swift
│   │
│   ├── Features/Prices/
│   │   ├── ○ PriceEditorSheet.swift
│   │   └── ○ PriceHistoryScreen.swift
│   │
│   ├── Features/Capture/
│   │   ├── ○ VoiceAddButton.swift ......... on-device, $0
│   │   ├── ○ BarcodeScanScreen.swift
│   │   ├── ○ PhotoImportScreen.swift ...... Vision first, Claude fallback
│   │   └── ○ ReceiptScanScreen.swift ...... the one real Claude feature
│   │
│   ├── Features/Paywall/
│   │   ├── ○ PaywallScreen.swift .......... price, period, trial visible — not behind a link
│   │   └── ○ SubscriptionStore.swift
│   │
│   ├── Features/Settings/
│   │   ├── ○ SettingsScreen.swift
│   │   ├── ○ SoundHapticsSettings.swift
│   │   └── ○ WhyItWorksThisWay.swift ...... the ADHD page — rationale, no health claims
│   │
│   └── Services/
│       ├── ○ SpeechService.swift .......... SFSpeechRecognizer, on-device flag
│       ├── ○ VisionService.swift .......... text + barcode recognition
│       ├── ○ FoundationModelsService.swift  availability-gated, iOS 26+
│       └── ○ AIClient.swift ............... protocol + ClaudeClient, URLSession, no SDK
│
├── Widget/ ───────────────────── separate process · cannot run app code
│   ├── ○ BaggedWidget.swift ............... @main widget bundle
│   ├── ○ ListWidgetView.swift ............. lock screen + home screen
│   ├── ○ WidgetProvider.swift ............. timeline, reads Repository directly
│   └── ★ ToggleItemIntent.swift ........... the tappable checkbox
│
└── Intents/ ──────────────────── the `reminders` App Schema cluster
    ├── Entities/
    │   ├── ○ ListEntity.swift ............. @AppEntity(schema: .reminders.list)
    │   ├── ○ ItemEntity.swift ............. @AppEntity(schema: .reminders.reminder)
    │   └── ○ SectionEntity.swift .......... @AppEntity(schema: .reminders.section)
    ├── ○ CreateListIntent.swift
    ├── ★ CreateReminderIntent.swift ....... "Hey Siri, add milk"
    ├── ○ UpdateReminderIntent.swift ....... check off, edit
    ├── ○ DeleteRemindersIntent.swift
    ├── ○ SectionIntents.swift ............. create + update — the aisle groups
    └── ○ BaggedShortcuts.swift ............ AppShortcutsProvider
```

---

## 3. How to read this shape

**Packages are layer-first; `App/Features/` is feature-first.** That looks inconsistent and isn't.
All three targets link the packages, so a feature-first package would mean the widget importing a
feature module just to read a row. Inside the app, change is local to a screen, so features win.

**Four boundaries carry all the weight:**

| Boundary | Rule | What breaks if ignored |
|---|---|---|
| `Core` / `Catalog` import nothing | Pure Swift, runs on the command line | The expensive-to-get-wrong logic becomes untestable without a simulator |
| `Repository` is the only SQL | One file writes queries | Sync bugs spread across the codebase |
| `Widget` links packages, never `App` | Separate process | Build failures, or worse, a widget that needs the app running |
| `DesignKit` has no feature code | Tokens only | `INTERACTION.md` has nowhere single to land |

**The App Group is the load-bearing detail.** All three targets open the *same* SQLite file, so:
only the app runs migrations; the widget checks the schema version and renders last-known state on
mismatch; every intent write goes through `Repository` so it produces a valid op-log entry.

---

## 4. Counts

| | Files |
|---|---|
| Repository today | **25** |
| `Packages/` planned | ~48 |
| `App/` planned | ~28 |
| `Widget/` + `Intents/` planned | ~14 |
| **App total, planned** | **~90** |

Roughly a third is tests, and that ratio is deliberate — `Core`, `Catalog` and `Data` hold the
logic where a bug costs a household their list.

---

## 5. Build order

1. **`Core` + `Catalog`** — the resolver's 23 cases and the conflict harness. **No Xcode signing,
   no simulator, no Apple approvals. Can start today.**
2. **`Data` + App Group** — forces the shared-database decision while it's cheap
3. **RLS policies + `SyncEngine`**, tested with two accounts, before any screen exists
4. **`DesignKit`**, then `Features/List`
5. **`Widget/`** — proves the App Group layout in practice
6. **`Services/`** speech and Vision — small, off the critical path
7. **`Intents/`** — the largest native piece; Xcode enforces cluster completeness
8. **`Features/Paywall`** — after the Paid Applications Agreement clears
9. **Foundation Models** — availability-gated, genuinely optional
