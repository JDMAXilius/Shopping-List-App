# Architecture — final

**Aligned with `PRODUCT.md` (Aug 2026).** Language, libraries, file layout, backend, frontend,
code standards. This is the build blueprint; the previous version of this file is superseded —
one material correction from it is flagged in §7.

**The constraint that shapes everything:** three surfaces — **app, widget, App Intents** — read
and write the same data, and two of them cannot run app code. A widget renders in its own
process; an intent fires from a locked screen with the app never launched. Any architecture that
assumes "the app is running" is wrong before it starts.

---

## 1. Language, toolchain, dependencies

| | Decision |
|---|---|
| Language | **Swift 6**, strict concurrency from day one |
| UI | **SwiftUI**, iOS 18 minimum |
| Dependencies | **Three:** GRDB.swift · RevenueCat (`purchases-ios`) · supabase-swift |
| Backend | **Supabase** — Postgres + Auth + Realtime + Edge Functions (Deno/TypeScript) |
| AI | **Claude API** — called only from an Edge Function, never from the app |
| Formatting | Xcode's built-in swift-format, default config. No linter dependency |
| Everything else | System frameworks: Speech, Vision, App Intents, WidgetKit, CoreLocation, StoreKit 2 (under RevenueCat), FoundationModels (availability-gated) |

**Owned IP, kept clean:** the catalog (414 items, hand-built, no ODbL input), the resolver, the
glyph set, the price seeds. Open Food Facts is a runtime barcode lookup only, with attribution.

## 2. Code standards — less is more, enforced

- **Comments: one or two lines, only where the code can't say it** — a constraint, an invariant,
  a why. No file headers, no doc-comment ceremony, no narrating the next line. A file with zero
  comments is the normal case
- **No speculative generality.** Two protocols exist in the whole app (`SyncTransport`,
  `ScanBackend`) because both need a fake in tests. Nothing else gets a protocol, a generic, or
  a configuration point until a second concrete use exists
- **A store over ~200 lines means logic is in the wrong layer** — move it to a package
- **No dead code, no `// TODO` older than a week, no commented-out blocks.** Delete; git remembers
- Value types and `let` by default; force-unwraps never; `guard` early-exit shape
- Files named for the one thing they contain; if the name needs "And", split it

## 3. The pattern — Model–View with domain stores

MVVM-per-screen, coordinators and DI containers are rejected — that advice is for rotating teams
on large apps. `@Observable` already gives precise invalidation; our screens are thin; the logic
lives in packages where it's testable without a simulator.

**Three app-lifetime `@Observable` stores, scoped to domains, injected via `@Environment`:**

| Store | Owns |
|---|---|
| `ListStore` | The list, add/check/edit intents, shops + aisle order, kitchen membership, sync status |
| `PriceStore` | The price book, month/spend aggregates, receipt index |
| `SubscriptionStore` | Entitlement, scan quota, paywall presentation |

Plus one **per-flow** `@Observable`: `CaptureSession`, created with `@State` when a capture
starts, dead when it ends. Views use `@State` for genuinely local UI only.

Rules: a View never touches `AppDatabase`/`SyncEngine` directly · stores coordinate, packages
decide · no store created in a view body.

## 4. Concurrency — Swift 6 strict

| Layer | Isolation |
|---|---|
| `Core`, `Catalog` | `nonisolated`, all `Sendable` value types — pure logic, CLI-testable |
| `Repository` | `nonisolated` over GRDB's thread-safe `DatabasePool` |
| `SyncEngine` | `actor` — drain loop, retries, backoff |
| Stores, views | `@MainActor` |
| `SpeechService`, `VisionService`, `LocationService` | per framework requirement |

The sharp edge that shapes the design: under Swift 6, observing `@Observable` outside SwiftUI is
deliberately awkward (`withObservationTracking` is `@Sendable`, fires once). **So the widget and
intents never observe stores — they read the database through `Repository`.** One mechanism.

## 5. Data flow — one direction

```
        ┌──────────── SQLite (App Group container) ────────────┐
        │                                                       │
   Repository ──ValueObservation──► Observed<T> ──► Store ──► View
        ▲                                                       │
        └───────────── write op ◄── Store ◄── user action ◄─────┘
                            │
                     op_log table ──► SyncEngine (actor) ──► Supabase (peer,
                                                             never the read path)
```

- **SQLite is the single source of truth.** Every user action writes an op; the op-log write is
  what updates the UI via `ValueObservation`. The UI shows what's in the database, always
- `Observed<T>` is ~40 lines we own, bridging `ValueObservation` → `@Observable`
- Op-log: `add / check / uncheck / edit / delete / price / shop`, client UUIDs, logical clock,
  last-write-wins per field, `add` idempotent on normalized name. **Not a CRDT** — a list is a
  set, not a sequence
- **A `delete` removes the normalized-name GROUP its row held, not one row id.** Two devices can
  each add "bread"; Merge collapses them for display, so a delete naming only the canonical id
  would let the twin resurrect and one user intent would need N deletes. A later-stamped add
  brings the name back (resurrection is by name, never by id — so an undo must mint a fresh
  `ListItemID`, not reuse the deleted one)
- Sync is invisible: no spinners, no alerts, one quiet `SyncStatus`

## 6. Navigation — deliberately boring

- `TabView` with three roots — **List · Prices · You** — plus the capture `+` overlaid
- One `Route` enum + one `NavigationStack` per tab; one `Sheet` enum per screen that presents
- **Onboarding is contextual sheets, not a wizard** (`PRODUCT.md` §5): first shop → first
  switcher use · kitchen name → first invite · sign-in → owners only · primers → at the moment
  of permission
- DI is `@Environment` + `@Entry`. No container, no router object

## 7. Backend — Supabase, and the one correction

> ⚠️ **Correction to the previous plan:** it placed `ClaudeClient` in the app. That ships the
> Anthropic API key inside a public binary. **The Claude API is called only from a Supabase Edge
> Function.** The app holds no AI credentials, ever.

### Schema (Postgres)

```sql
kitchen   (id uuid pk, name text, created_at timestamptz)
member    (kitchen_id fk, user_id uuid, role text check (role in ('owner','guest')),
           joined_at, pk (kitchen_id, user_id))
invite    (kitchen_id fk, token text unique, created_at, revoked_at timestamptz)
op        (id uuid pk, seq bigserial, kitchen_id fk, device_id uuid, clock bigint,
           type text, payload jsonb, created_at)           -- THE sync table
           -- seq is the pull cursor, made commit-ordered per kitchen by a BEFORE INSERT
           -- advisory-lock trigger (bare bigserial can be pulled past mid-commit — proven
           -- op loss, W3-C1). Push goes through the push_ops RPC (ON CONFLICT DO NOTHING);
           -- bare .insert() 409s a re-delivered batch. Re-delivery is the normal case
entitlement (user_id pk, is_plus bool, scans_used int default 0, updated_at)
```

- **The op-log is the whole sync protocol.** Clients push ops, subscribe to Realtime inserts on
  `op` for their kitchen, and replay. The server materializes nothing; conflict resolution is
  client-side (`Core/Merge.swift`), so server logic stays near zero
- Price observations sync as `price` ops — the price book is kitchen-shared
- **Never on the server:** receipt photos (kept on device — it's printed on the Data & privacy
  screen), locations (geofences evaluated on-device), voice audio (never leaves the phone)

### RLS — the entire security model

Every table: `kitchen_id in (select kitchen_id from member where user_id = auth.uid())`.
Owners authenticate (Sign in with Apple / email); **guests get anonymous Supabase auth sessions**
bound by the invite flow — no account, full membership. A new invite token revokes the old one's
future joins. **Policies are written and proven with two real accounts before any UI exists** —
get this wrong and lists leak between families.

### Edge Functions (three, small)

| Function | Does |
|---|---|
| `scan-receipt` | Verify JWT → check `entitlement` (Plus, or `scans_used < 3`, increment) → call Claude with the receipt image + fixed JSON schema (structured outputs; prompt-cached prefix) → return line items. Stateless; image never stored |
| `join-kitchen` | Validate invite token not revoked → create anonymous session → insert `member` |
| `revenuecat-webhook` | RevenueCat server event → upsert `entitlement` |

Receipt model: start on **Opus 5** in beta for the accuracy baseline, measure per-line accuracy,
step down to **Haiku 4.5** (~$0.22/subscriber/yr) if it holds; Batch API is not applicable — the
user is waiting on the parse. Entitlement is also cached client-side so the paywall state
survives offline; never lock a user out of their own list.

## 8. The file plan

Layer-first packages (all three surfaces link them), feature-first app folder (change stays
local to a screen). Anything not listed is a **no** until argued for.

```
Packages/Core/Sources/Core/           # imports nothing, runs on CLI
  Item.swift  Kitchen.swift  Shop.swift  Money.swift  PriceObservation.swift
  Operation.swift  LogicalClock.swift  Merge.swift  Identifiers.swift
Packages/Core/Tests/CoreTests/
  MergeTests.swift  ConflictHarnessTests.swift  ★  LogicalClockTests.swift  MoneyTests.swift
  IdentifiersTests.swift   # the catalog<->ItemID join key: get it wrong and the price book splits

Packages/Catalog/Sources/Catalog/
  CatalogDatabase.swift  Resolver.swift  Normalizer.swift  QuantityParser.swift
  EditDistance.swift  PriceSeed.swift  Resources/catalog.db
Packages/Catalog/Tests/CatalogTests/
  ResolverTests.swift (the 23 cases)  QuantityParserTests.swift  NormalizerTests.swift
  PriceSeedTests.swift  EditDistanceTests.swift  CatalogDatabaseTests.swift

Packages/Data/Sources/Data/
  AppDatabase.swift  Migrations.swift  Observed.swift  Repository.swift   # the ONLY SQL surface
  Records/ (ListItem, Kitchen, Shop, Price, Receipt, Op)                  # 6 files
  Sync/SyncEngine.swift  Sync/SyncTransport.swift  Sync/DeviceIdentity.swift
Packages/Data/Tests/DataTests/
  MigrationTests.swift  RepositoryTests.swift  SyncEngineTests.swift (fake transport)

Packages/DesignKit/Sources/DesignKit/  # zero feature code; widget shares it
  Palette.swift  Typography.swift  Motion.swift  Haptics.swift  Sound.swift  Glyphs.swift
  Components/ (ItemRow, PriceLabel, AisleHeader, TotalBar, InputBar, TabPill, EmptyState)
  Resources/ (check.wav, complete.wav — generated to spec, length/peak-tested; no asset
              catalogs: glyphs and colors are code, which is what makes them testable)
Packages/DesignKit/Tests/DesignKitTests/
  SnapshotTests.swift                  # one style × default + largest Dynamic Type

App/
  BaggedApp.swift  RootView.swift  Route.swift  Sheet.swift  Environment+.swift
App/Features/List/
  ListScreen.swift  ListStore.swift  ListDerivation.swift  ListCatalog.swift  ItemDetailSheet.swift
  AisleOrderEditor.swift  ShopSwitcherSheet.swift
App/Features/Capture/
  CaptureSession.swift  CaptureChooserSheet.swift  ReceiptCameraScreen.swift
  ReceiptReviewScreen.swift  LineResolverScreen.swift  CaptureResultScreen.swift
  EnterByHandScreen.swift  BarcodeScanScreen.swift  FirstReceiptSheet.swift
App/Features/Prices/
  PricesScreen.swift  PriceStore.swift  PriceHistoryScreen.swift  MonthSpendScreen.swift
App/Features/Kitchen/
  KitchenScreen.swift  InviteSheet.swift  JoinScreen.swift  NameKitchenSheet.swift  SignInScreen.swift
App/Features/Places/
  PlacesScreen.swift  ShopEditorScreen.swift  FirstShopSheet.swift
App/Features/You/
  SetupScreen.swift  DataPrivacyScreen.swift  AboutScreen.swift  WhyItWorksThisWay.swift
  PaywallScreen.swift  SubscriptionStore.swift
App/Services/
  SpeechService.swift        # SFSpeechRecognizer, requiresOnDeviceRecognition = true
  VisionService.swift        # barcode + printed text
  LocationService.swift      # geofence registration, arrival events; on-device only
  ScanClient.swift           # calls the scan-receipt Edge Function; no AI key in app
  FoundationModelsService.swift  # availability-gated
  CSVExporter.swift

Widget/
  BaggedWidget.swift  ListWidgetView.swift  WidgetProvider.swift  ToggleItemIntent.swift
Intents/
  Entities/ (ListEntity, ItemEntity, SectionEntity — @AppEntity, .reminders schema)
  CreateReminderIntent.swift  UpdateReminderIntent.swift  DeleteRemindersIntent.swift
  SectionIntents.swift  BaggedShortcuts.swift
  # ⚠️ Xcode enforces schema-cluster completeness — budget the whole reminders domain

supabase/
  migrations/0001_schema.sql  0002_rls.sql
  functions/scan-receipt/index.ts  functions/join-kitchen/index.ts  functions/revenuecat-webhook/index.ts
  tests/rls.test.sql                # kitchen A cannot read kitchen B — proven, not assumed
```

~90 files for 28 surfaces + widget + intents + backend. States (empty, offline, scan-failed,
primers) are view states inside their screens, not separate files.

## 9. Integrations

| Integration | Plugs in at | Rule |
|---|---|---|
| Supabase | `SupabaseTransport: SyncTransport` | Nothing above this layer knows Supabase exists |
| RevenueCat | `SubscriptionStore` only | Entitlement cached; offline users keep their list |
| Claude | `supabase/functions/scan-receipt` only | Key server-side; app calls `ScanClient` |
| WidgetKit | Reads `Repository`; writes via `ToggleItemIntent` → op-log | A lock-screen tick must sync like any other op |
| App Group | All targets open the same SQLite via `AppDatabase` | WAL; only the app migrates — the widget renders last-known state on version mismatch |
| Speech/Vision/CoreLocation | `App/Services/`, thin wrappers returning plain values | Nothing above them knows which framework answered |

## 10. Testing — the four that matter

1. **The op-log conflict harness** — two simulated devices, offline edits, reconnect, assert no
   duplicates and no losses. The highest-value test in the project
2. **Resolver golden tests** — the 23 ported cases, plus every new synonym added from real use
3. **RLS tests** against a real Supabase branch — membership isolation proven with two accounts
4. **Snapshot tests** on DesignKit components — one style, default + largest Dynamic Type

No UI-test suite at v1; the falsification metrics (`PRODUCT.md` §6) are measured in TestFlight.

## 11. Build order — structural risk first

1. **`Core` + `Catalog`** — port the resolver, write Merge + the conflict harness. No signing,
   no simulator. **Can start today**
2. **`Data` + App Group** — forces the shared-database decision where the widget bites
3. **`supabase/` schema + RLS**, proven with two accounts, before any screen
4. **`DesignKit`**, then **List** (add, check, aisles, prices) — the app exists here
5. **Capture** (camera → review → resolver → result) + `scan-receipt` function
6. **Prices** screens — reads over data that already exists
7. **Widget**, then the **App Intents cluster**
8. **Kitchen/sharing** (invite, join, realtime), **Places** (geofence)
9. **Paywall** — after the Paid Applications Agreement clears

## 12. Deliberately not doing

No TCA · no coordinators · no ViewModel-per-screen · no DI container · no repository-per-entity ·
no generic `NetworkManager` · no CloudKit (its conflict semantics aren't ours) · no analytics or
crash SDK · no custom fonts · no third-party UI kit · **no appearance variants — one style** ·
no AI SDK in the app · no server-side rendering of anything the phone can compute.
