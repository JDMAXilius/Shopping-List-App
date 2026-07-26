# Architecture — SwiftUI, Swift 6, and the complete file plan

The structural decisions and every file that will exist. No code yet.

**The constraint that shapes all of this:** three surfaces — **app, widget, App Intents** — read
and write the same data, and **two of them cannot run app code.** A widget renders in its own
process. An App Intent fires from a locked screen with the app never launched. Any architecture
that assumes "the app is running" is wrong before it starts.

---

## 1. The pattern: Model–View, not MVVM-per-screen

The 2026 consensus advice is *MVVM + Coordinators + DI*. **That advice is written for rotating
teams on large apps, and following it here would be cargo cult.**

The reasoning is specific rather than contrarian:

- `@Observable` (iOS 17+) already gives precise, access-tracked invalidation. It **modernised**
  MVVM's plumbing, and in doing so removed most of the reason a ViewModel existed in SwiftUI
- Our screens are thin. The logic lives in `Core`, `Catalog` and `Data` — where it's testable
  without a simulator. A ViewModel per screen would mostly forward calls
- Six screens do not need coordinators. Coordinators solve navigation reuse across dozens of
  screens; we have a `NavigationStack` and an enum

**What we do instead: `@Observable` stores scoped to a *domain*, not to a screen.**

| Store | Owns | Lives |
|---|---|---|
| `ListStore` | The active list, add/check/edit intents, sync status | App-lifetime, `@Environment` |
| `SubscriptionStore` | Entitlement state, paywall presentation | App-lifetime, `@Environment` |
| `CaptureStore` | Voice/scan/photo session state | Created per flow |

**Three observable objects, not eight view models.** Views use `@State` for genuinely local UI —
is the sheet open, what's in the text field — and read stores from the environment.

Where a screen has real async coordination that isn't domain state (the receipt-scan flow), it
gets a local `@Observable` created with `@State` in that view. That is a ViewModel in all but
name, used where it earns its place rather than by default.

### Rules that keep this from rotting

- **A View never touches `AppDatabase` or `SyncEngine` directly.** It goes through a store or
  through `Repository`
- **Stores hold no business logic.** They coordinate; `Core` and `Catalog` decide
- **No store is created inside a view body**
- **If a store exceeds ~200 lines, the logic belongs in a package**, not in a bigger store

---

## 2. Concurrency: Swift 6 strict, and the one sharp edge

Strict concurrency on from day one. Retrofitting it onto a codebase with a widget, background
sync and a shared database is far worse than paying at the start.

| Layer | Isolation | Why |
|---|---|---|
| `Core`, `Catalog` | `nonisolated`, all `Sendable` value types | Pure logic, callable from anywhere, testable on the command line |
| `Repository` | `nonisolated`, backed by GRDB's thread-safe `DatabasePool` | GRDB already handles serialisation; wrapping it in an actor would add a hop for nothing |
| `SyncEngine` | **`actor`** | Genuinely concurrent — network, retries, backoff, a drain loop |
| Stores, views | `@MainActor` | UI |
| `ClaudeClient`, `SpeechService`, `VisionService` | `actor` or `@MainActor` per framework requirement | Speech has main-thread requirements; Vision does not |

> ⚠️ **The sharp edge, found in research rather than assumed.** Under Swift 6,
> `withObservationTracking` requires `@Sendable` closures, which blocks capturing non-`Sendable`
> state — and it fires **once**, needing re-registration. So **observing `@Observable` outside a
> SwiftUI view is awkward on purpose.**
>
> **This is why we don't try.** The widget and App Intents don't observe stores; they read the
> database directly through `Repository`. One less mechanism, and it happens to be the one the
> language is pushing us toward.

---

## 3. Data flow — one direction, one mechanism

```
        ┌──────────── SQLite (App Group container) ────────────┐
        │                                                       │
   Repository ──ValueObservation──► Observed<T> ──► Store ──► View
        ▲                                                       │
        └───────────── write op ◄── Store ◄── user action ◄─────┘
                            │
                            ▼
                     op_log table
                            │
                     SyncEngine (actor)
                            │
                     Supabase (peer, never the read path)
```

- **The database is the single source of truth.** Not a store, not a cache, not the server
- **Every user action writes an op**, and the op-log write is what updates the UI — via
  `ValueObservation`, not by the store mutating its own state. **The UI shows what's in the
  database, always**
- **`Observed<T>` is ~40 lines we own**, bridging `ValueObservation` to `@Observable`. Not
  `GRDBQuery` — a hand-rolled bridge serves all three surfaces with one mechanism, and the widget
  needs plain reads anyway
- **Sync is invisible.** No spinners, no error alerts. A quiet `SyncStatus` for the rare case
  where something is genuinely stuck

---

## 4. Navigation and dependencies — deliberately boring

- **One `Route` enum**, one `NavigationStack`, one `navigationDestination`. No coordinator, no
  router object
- **Sheets are an `activeSheet: Sheet?` enum in `@State`** — never a pile of booleans
- **DI is `@Environment` with the `@Entry` macro** (iOS 18). No container, no resolver, no
  service locator
- **Protocols only where we actually swap an implementation** — `SyncTransport` and `AIClient`,
  because both need a fake in tests. Nothing else gets a protocol "for testability"

---

## 5. The file plan

~80 files. Every one has a reason; anything that isn't here is a `no` until argued for.

### Packages — layer-first, because all three surfaces link them

```
Packages/Core/Sources/Core/
  Item.swift                  Item, ListItem, quantity + unit
  Household.swift             Household, Member, InviteToken
  Store.swift                 Store, AisleOrder
  Money.swift                 Money, Currency, rounding rules
  PriceObservation.swift      observation vs estimate, provenance
  Operation.swift             the op-log enum + payloads
  LogicalClock.swift          per-device counter
  Merge.swift                 last-write-wins per field, idempotent add
  Identifiers.swift           typed UUID wrappers — no bare UUIDs crossing APIs

Packages/Core/Tests/CoreTests/
  MergeTests.swift
  ConflictHarnessTests.swift  ★ two devices, offline edits, reconnect
  LogicalClockTests.swift
  MoneyTests.swift
```

```
Packages/Catalog/Sources/Catalog/
  CatalogDatabase.swift       read-only open of the bundled catalog.db
  Resolver.swift              query → item, the ranked cascade
  Normalizer.swift            case, articles, singularisation, qualifiers
  QuantityParser.swift        "2 lb chicken breast" → qty, unit, name
  EditDistance.swift          bounded, for typos and mis-transcriptions
  PriceSeed.swift             region multiplier + the rounding rules
  Resources/catalog.db        200 KB, built by data/catalog/build.mjs

Packages/Catalog/Tests/CatalogTests/
  ResolverTests.swift         the existing 23 cases, ported
  QuantityParserTests.swift
  NormalizerTests.swift
  PriceSeedTests.swift        asserts the $0.50 / $1 rounding
```

```
Packages/Data/Sources/Data/
  AppDatabase.swift           DatabasePool, App Group URL, WAL, pragmas
  Migrations.swift            DatabaseMigrator, forward-only, versioned
  Observed.swift              ValueObservation → @Observable bridge
  Repository.swift            the ONLY read/write surface above SQL
  Records/ListRecord.swift
  Records/ListItemRecord.swift
  Records/HouseholdRecord.swift
  Records/StoreRecord.swift
  Records/PriceRecord.swift
  Records/OpRecord.swift
  Sync/SyncEngine.swift       actor: drain, retry, backoff
  Sync/SyncTransport.swift    protocol + SupabaseTransport
  Sync/DeviceIdentity.swift   anonymous UUID, upgradeable to an account

Packages/Data/Tests/DataTests/
  MigrationTests.swift        each migration against a prior-release fixture
  RepositoryTests.swift
  SyncEngineTests.swift       against a fake transport
```

```
Packages/DesignKit/Sources/DesignKit/
  Palette.swift               paper, card, ink, muted, line, persimmon, confirmed
  Typography.swift            scale, Dynamic Type mapping
  Motion.swift                durations, springs, Reduce Motion equivalents
  Haptics.swift               the event → pattern map
  Sound.swift                 the two sounds, audio session, silent switch
  Components/ItemRow.swift
  Components/QuantityChip.swift
  Components/PriceLabel.swift     estimate vs observed rendering
  Components/SectionHeader.swift
  Components/TotalBar.swift
  Components/EmptyState.swift
  Resources/Sounds/check.caf
  Resources/Sounds/complete.caf
  Resources/Colors.xcassets

Packages/DesignKit/Tests/DesignKitTests/
  SnapshotTests.swift         light, dark, largest Dynamic Type
```

### App

```
App/
  BaggedApp.swift             @main, environment wiring, database bootstrap
  RootView.swift
  Route.swift                 the navigation enum
  Sheet.swift                 the sheet enum
  EnvironmentValues+.swift    @Entry keys for the stores

App/Features/List/
  ListScreen.swift
  ListStore.swift             ★ the core store
  AddField.swift              the ≤2-tap add path
  AutocompleteResults.swift   personal → household → catalog
  ItemDetailSheet.swift       quantity, note, price
  CheckOffAnimation.swift     strike, desaturate, sink

App/Features/Stores/
  StorePickerScreen.swift
  AisleOrderEditor.swift      drag to reorder, per store

App/Features/Household/
  ShareListSheet.swift        invite link generation
  JoinListScreen.swift        no-account join
  MembersScreen.swift

App/Features/Prices/
  PriceEditorSheet.swift
  PriceHistoryScreen.swift

App/Features/Capture/
  VoiceAddButton.swift
  BarcodeScanScreen.swift
  PhotoImportScreen.swift     Vision first, Claude fallback
  ReceiptScanScreen.swift

App/Features/Paywall/
  PaywallScreen.swift         price, period and trial visible — not behind a link
  SubscriptionStore.swift

App/Features/Settings/
  SettingsScreen.swift
  SoundHapticsSettings.swift
  WhyItWorksThisWay.swift     the ADHD page — design rationale, no health claims

App/Services/
  SpeechService.swift         SFSpeechRecognizer, requiresOnDeviceRecognition
  VisionService.swift         text + barcode recognition
  FoundationModelsService.swift   availability-gated
  AIClient.swift              protocol + ClaudeClient — URLSession, no SDK
```

### Widget and Intents

```
Widget/
  BaggedWidget.swift          @main widget bundle
  ListWidgetView.swift        lock screen + home screen
  WidgetProvider.swift        timeline, reads Repository directly
  ToggleItemIntent.swift      AppIntent — the tappable checkbox

Intents/
  Entities/ListEntity.swift       @AppEntity(schema: .reminders.list)
  Entities/ItemEntity.swift       @AppEntity(schema: .reminders.reminder)
  Entities/SectionEntity.swift    @AppEntity(schema: .reminders.section)
  CreateListIntent.swift
  CreateReminderIntent.swift      "add milk"
  UpdateReminderIntent.swift      check off, edit
  DeleteRemindersIntent.swift
  SectionIntents.swift            create + update — the aisle groups
  BaggedShortcuts.swift           AppShortcutsProvider
```

### Why this shape

- **Packages are layer-first** because app, widget and intents all link them. Feature-first
  packages would mean the widget links a feature module to read a row
- **`App/Features/` is feature-first** because that's where change is local to a screen
- **`Core` and `Catalog` import nothing** — not even Foundation types beyond the basics. They're
  the expensive-to-get-wrong logic, and they run on the command line in milliseconds
- **`Repository` is the only thing that writes SQL.** One file to audit when sync misbehaves
- **`DesignKit` has zero feature code** — so `INTERACTION.md` has exactly one place to land, and
  the widget gets the same tokens as the app for free

---

## 6. Integrations

| Integration | How it plugs in | Notes |
|---|---|---|
| **Supabase** | `SupabaseTransport: SyncTransport` in `Data/Sync/` | Nothing above this layer knows Supabase exists. **RLS is the security model — policies written and tested with two accounts before any UI** |
| **RevenueCat** | `SubscriptionStore` only | Entitlement cached locally so the paywall state survives offline. Never lock a user out of their own list |
| **Claude API** | `ClaudeClient: AIClient` in `App/Services/` | `URLSession` + `Codable`, no SDK. Batch API for receipts, prompt caching on the fixed schema prefix. **Paid tier only, off the critical path** |
| **App Intents** | `Intents/` target, `reminders` schema domain | ⚠️ **Xcode enforces cluster completeness at build time** — budget for the whole domain, not one intent |
| **WidgetKit** | `Widget/` target, App Group | Reads `Repository`; writes go through `ToggleItemIntent` and must produce valid op-log entries or a lock-screen check-off won't sync |
| **Speech / Vision / FoundationModels** | `App/Services/`, thin wrappers | Each returns a plain Swift value. Nothing above them knows which framework produced it |
| **StoreKit 2** | Under RevenueCat | Not called directly |

### The App Group is the load-bearing detail

All three targets open **the same SQLite file** in a shared App Group container. Consequences,
each of which is a real bug if ignored:

1. **WAL mode, and every process opens through `AppDatabase`.** Never a second connection path
2. **A migration must not run from the widget.** Only the app migrates; the widget checks the
   schema version and renders last-known state if it doesn't match
3. **Intent writes go through `Repository`**, which writes the op, so sync stays correct
4. **The catalog is read-only and bundled separately** from the writable database — different
   file, different lifetime

---

## 7. Build order

Structural risk first, while it's still cheap:

1. **`Core` + `Catalog`.** Port the resolver's 23 cases, write the merge rules and the conflict
   harness. No Xcode signing, no simulator, no Apple approvals — **this can start today**
2. **`Data` + the App Group.** Forces the shared-database decision immediately, which is where
   the widget's requirements actually bite
3. **RLS policies and `SyncEngine`**, tested against two accounts, before any screen exists
4. **`DesignKit`**, then the list screen — add, check off, aisle grouping, prices
5. **Widget** — proves the App Group layout in practice
6. **Speech and Vision** — small, self-contained, off the critical path
7. **App Intents cluster** — the largest native piece
8. **Paywall** — after the Paid Applications Agreement clears
9. **Foundation Models** — availability-gated, genuinely optional

**Steps 1–3 have no dependency on the name, the trademark, the domain or Apple's agreements** —
they can run in parallel with all the paperwork in `OPS.md` §4.

---

## 8. What we are deliberately not doing

- **No TCA.** Powerful, opinionated, and a large dependency plus a learning curve for six screens
- **No coordinator pattern.** An enum and a `NavigationStack` is enough
- **No ViewModel per screen.** `@Observable` already does that job
- **No DI container.** `@Environment` and initialisers
- **No protocol per type.** Two protocols total, both because a fake is genuinely needed
- **No generic `NetworkManager` / `APIService`.** Two callers, both specific
- **No CloudKit sync.** It brings its own conflict semantics and ours are the product
- **No repository per entity.** One `Repository`
