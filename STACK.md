# Technology stack — iOS native

**Decided: Swift 6 + SwiftUI, iOS only. Minimum iOS 18. Android deferred indefinitely.**

`PLAN.md` §3.0 carries the decision history — this was recommended, changed to React Native, and
changed back. `OPS.md` §1 has the full argument.

**The governing principle, applied to engineering:** *less is more* means **fewer dependencies**,
not less rigour. Every library is a thing that can break on the next OS release, and a one-person
team pays that bill alone. The default answer to "should we add a library" is **no**.

---

## 1. The base

| Choice | Version | Why |
|---|---|---|
| **Swift** | 6, strict concurrency on | Data races become compile errors. Worth the early friction on a codebase with a widget, an app and background sync all touching one database |
| **SwiftUI** | iOS 18 baseline | The whole UI. UIKit only where SwiftUI genuinely can't reach |
| **Xcode** | current | One project, local Swift Packages for module boundaries |
| **Deployment target** | **iOS 18** | Covers interactive widgets, App Intents, on-device speech and Vision. Foundation Models (iOS 26) is availability-gated, never a dependency |

**No Android Studio, no Kotlin, no second app.** If Android ever happens it is a post-PMF
decision, written native at that point, sharing the sync protocol and the compiled catalog — the
only two things that were ever shareable.

---

## 2. Dependencies — all three of them

This is the payoff of going native. The React Native plan needed roughly twelve packages; this
needs three.

| Package | Role | Why this, and why not the alternative |
|---|---|---|
| **GRDB.swift** | SQLite access, migrations, reactive queries | **Not SwiftData.** SwiftData is CloudKit-shaped and hides the store; we need raw SQL, a file we control, and a widget extension reading the *same* file. GRDB's `ValueObservation` gives SwiftUI live updates without a state library |
| **RevenueCat** (`purchases-ios`) | Subscriptions | StoreKit 2 alone is genuinely good now that we're iOS-only, and would save ~1%. Keeping RevenueCat anyway for **paywall A/B testing and cohort retention data** — subscription conversion is the whole business, and measuring it is worth 1% |
| **supabase-swift** | Sync transport | Optional. The op-log is ours; this is only PostgREST + Realtime plumbing. Drop it for plain `URLSession` if the SDK proves heavier than the API |

### Everything else is a system framework

No dependency, no size, no upgrade risk:

- **SwiftUI** — animation, layout, dark mode, Dynamic Type
- **`UIFeedbackGenerator` / Core Haptics** — the haptic map in `INTERACTION.md`
- **AVFoundation** — the two optional sounds
- **AVFoundation + Vision** — barcode scanning
- **Vision** — printed-list text recognition
- **Speech** (`SFSpeechRecognizer`) — on-device transcription
- **App Intents** — Siri, the `reminders` schema domain, widget interactivity
- **WidgetKit** — lock-screen and home-screen widgets
- **FoundationModels** — on-device LLM, availability-gated
- **`URLSession`** — including the Claude API calls. No SDK on device
- **StoreKit 2** — underneath RevenueCat

### Deliberately not included

- **No analytics SDK at launch.** Adds a privacy label and answers questions we don't have yet
- **No crash reporter until the first TestFlight**, then Sentry, and only Sentry
- **No UI or component library.** Our design language is small and specific
- **No networking, JSON, or DI library.** `URLSession` + `Codable` + initialisers
- **No sync framework** — WatermelonDB, PowerSync, Replicache, CloudKit sync. They bring their own
  conflict semantics and **ours are the product** (`RESEARCH.md` §5)
- **No localisation framework in v1.** English-only launch; `en-GB` synonyms already ship in the
  catalog

---

## 3. Project structure

Local Swift Packages, not folders. The boundary matters because **the widget extension must link
the data layer without linking the app.**

```
Bagged.xcodeproj
├─ Packages/
│  ├─ Core/        models, op-log, logical clock, conflict resolution — no UI, no I/O
│  ├─ Catalog/     the resolver + catalog.db access — pure, heavily tested
│  ├─ Data/        GRDB stack, migrations, queries, App Group container
│  └─ DesignKit/   colour, type, motion, haptic and sound tokens — no feature code
├─ App/            SwiftUI features, screens, paywall
├─ Widget/         WidgetKit extension + AppIntents
└─ Intents/        the reminders App Schema cluster
```

**→ The complete file plan, the architectural pattern, the concurrency model and the integration
points are in `ARCHITECTURE.md`.** Rules that keep this honest:

- **`Core` and `Catalog` import nothing.** They're pure Swift, testable on the command line, and
  they hold the logic that's expensive to get wrong
- **`Widget` links `Core` + `Data` + `DesignKit`, never `App`.** If the widget needs something
  from `App`, it belongs in a package
- **The App Group container holds the SQLite file.** App, widget and intents all open the same
  database — this is the thing that was a cross-language contract under React Native and is now
  just a shared package
- **`DesignKit` has no feature code.** It's tokens and primitives, so `INTERACTION.md` has one
  place to land

---

## 4. Data and sync

- **Local SQLite is the source of truth.** GRDB, WAL mode, in the App Group container
- **`catalog.db` ships read-only in the bundle** — 200 KB, built by `data/catalog/build.mjs`,
  unchanged from the existing pipeline
- **Migrations via `DatabaseMigrator`**, versioned, forward-only, and tested against a fixture
  database from the previous release
- **Reactive UI via `ValueObservation`** — SwiftUI updates when rows change, with no observable
  object plumbing
- **The op-log is a table**, drained by a background task, retried with backoff. Supabase is the
  peer, never the read path
- **Row Level Security is the entire security model** for household sharing. Policies written and
  tested with a second account *before* any UI exists

---

## 5. Testing

- **Swift Testing** for `Core` and `Catalog` — pure functions, fast, no simulator. The resolver's
  23 existing cases port over directly
- **The op-log conflict harness is the highest-value test in the project.** Two simulated devices,
  offline edits, reconnect, assert no duplicates and no losses. Sync bugs are what lose households
- **Snapshot tests on `DesignKit`** — light, dark, largest Dynamic Type
- **XCUITest** for the three flows that must never break: add, check off, and offline→sync
- **RLS tests against a real Supabase branch**, asserting that household A cannot read household B
- `swift build` + tests in CI on every push

---

## 6. App size

Back to the native numbers — React Native's ~10 MB runtime cost is gone.

| Component | Size |
|---|---|
| Swift + SwiftUI binary | 12–18 MB **[estimate]** |
| GRDB | ~1.5 MB **[estimate]** |
| RevenueCat | ~1 MB **[estimate]** |
| **`catalog.db`** | **200 KB measured** (66 KB compressed) |
| Widget extension | 1–2 MB **[estimate]** |
| Icon, brand assets | 1–2 MB **[estimate]** |
| All system frameworks, emoji, Claude integration | **0** |
| **Total, before photos** | **≈ 17–25 MB [estimate]** |

- **Ceiling: 30 MB.** Past that, something got in that shouldn't have
- **Top 100 item photos add ~3.5 MB** → ~21–29 MB, still under the ceiling (`SOURCING.md` §2)
- For scale: **OurGroceries ships 13.5 MB, AnyList 50.9 MB**. We land near OurGroceries with more
  features
- **Measure the App Store Connect thinned download size at the first TestFlight build.** The
  `.xcarchive` on disk will look far worse and mean nothing

---

## 7. Build order for the native surface

Sequenced so the risky, structural decisions happen while they're still cheap to change:

1. **`Core` + `Catalog`** — port the resolver, write the op-log and its conflict harness. No UI,
   no device, no Xcode signing. This is the logic that's expensive to get wrong
2. **`Data` + the App Group container** — forces the shared-database decision immediately, which
   is where the widget's requirements actually bite
3. **RLS policies and sync**, tested against two accounts before any screen exists
4. **The list screen** — add, check off, aisle grouping, prices
5. **Widget** — proves the App Group layout in practice
6. **Speech + Vision** — small, self-contained, off the critical path
7. **App Intents + the `reminders` schema cluster** — the largest native piece. Xcode enforces
   cluster completeness at build time, so budget for the whole domain
8. **RevenueCat + paywall** — last, and only after the Paid Applications Agreement has cleared
   (`OPS.md` §3)
9. **Foundation Models** — availability-gated, genuinely optional
