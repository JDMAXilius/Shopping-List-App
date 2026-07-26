# Technology stack — React Native, and how to keep it native

Decided: **React Native**. This document is how to build that well rather than a rerun of the
platform argument. `PLAN.md` §3.0 carries the record of the earlier recommendation and why it
changed.

**The governing principle, applied to engineering:** *less is more* means **fewer dependencies**,
not less rigour. Every library is a thing that can break on the next OS release, and a one-person
team pays that bill alone. The default answer to "should we add a library" is **no**.

---

## 1. The base

| Choice | Version | Why |
|---|---|---|
| **Expo (managed, with Continuous Native Generation)** | **SDK 57** | SDK 57 ships **React Native 0.86**. Not "Expo Go" — CNG plus config plugins, which is how native Swift gets in without ejecting |
| **React Native New Architecture** | always on | Mandatory from SDK 55 up. Fabric renderer, TurboModules, JSI. Synchronous JS↔native calls with no bridge serialisation |
| **Hermes** | default | Faster start-up, lower memory, smaller bundle |
| **TypeScript** | `strict: true` | Non-negotiable. `any` is a bug |
| **EAS Build** | — | One person cannot maintain a build machine |

**Why Expo and not bare RN.** The instinct with heavy native work is to go bare. It's wrong here:
**config plugins are the supported way to add native targets** — the widget extension, App
Intents, entitlements, App Groups — and they keep the native project reproducible instead of a
hand-edited `.xcodeproj` nobody dares regenerate. Bare RN buys freedom we don't need and costs
maintenance we can't afford.

---

## 2. The dependency list, and the argument for each

Short on purpose. Anything not here is a *no* until it earns its place.

### Data

| Library | Role | Why this and not the alternative |
|---|---|---|
| **`expo-sqlite`** | Local database — the source of truth | `op-sqlite` / `nitro-sqlite` are faster via JSI, but our whole dataset is a 200 KB catalog and a few hundred list rows. **Raw SQLite throughput is not our bottleneck and never will be.** `expo-sqlite` is first-party, ships with the SDK, and survives upgrades |
| **Drizzle ORM** | Typed queries + migrations + **live queries** | Type safety from schema to component, and reactive queries so the UI updates without a state library babysitting it |
| **`react-native-mmkv`** | Preferences, entitlement cache, **widget bridge** | Synchronous, and supports an **App Group** container — which is how the Swift widget reads state without booting JS |

### UI and motion

| Library | Role | Why |
|---|---|---|
| **`react-native-reanimated`** (v4) | All animation | Runs on the UI thread. Anything else drops frames the moment JS is busy |
| **`react-native-gesture-handler`** | Swipe, drag-to-reorder, long-press | Native gesture recognition; required by Reanimated's ecosystem anyway |
| **`@shopify/flash-list`** | The list — **only if profiling demands it** | **Start with `FlatList`.** A grocery list is 20–60 rows. FlashList and LegendList solve a problem we do not have. Documented switch threshold: >200 rows or a measured dropped-frame problem |
| **`expo-haptics`** | Tactile feedback | Covers every pattern in `INTERACTION.md`. Core Haptics only if we later need custom waveforms |
| **`expo-audio`** | Optional sounds | Replaces the deprecated `expo-av` |

### Everything else

| Library | Role | Why |
|---|---|---|
| **`zustand`** | Ephemeral UI state only | ~1 KB. Drizzle live queries own the *data*; Zustand owns "is the sheet open". **Do not** put list data in it |
| **`expo-camera`** | Barcode scanning | Barcode support is built in. `react-native-vision-camera` is more powerful and we don't need the power |
| **`react-native-purchases`** (RevenueCat) | Subscriptions | StoreKit 2 from RN means writing and maintaining receipt validation, and getting it wrong locks paying users out. Free below $2.5k/mo revenue, which covers us to roughly year 3 |
| **`expo-router`** | Navigation | File-based, first-party. The app has ~6 screens |
| **Supabase** | Sync backend | Postgres + auth + realtime, one person can run it. The op-log is ours; Supabase is just where it lands |

### Deliberately **not** included

- **No analytics SDK at launch.** Adds size, adds a privacy label, answers questions we don't
  have yet. Add one — one — after there are users to learn from.
- **No crash reporter at launch, then Sentry.** Add it at the first TestFlight, not before.
- **No UI kit.** No NativeBase, no Tamagui, no RN Paper. Our design language is specific and
  small; a kit would fight it and add megabytes.
- **No i18n framework in v1.** English-only launch. `en-GB` synonyms already live in the catalog.
- **No state-sync library** (WatermelonDB, PowerSync, Replicache). They bring their own sync
  models; **we already designed ours** (`RESEARCH.md` §5) and it's ~300 lines. Adopting one means
  adopting its conflict semantics, and ours are the product.

---

## 3. The native boundary — the part that matters

Five capabilities have **no JavaScript API and never will**. They are Swift, written by us, in
config-plugin-generated targets:

| # | Native module | What it is | Difficulty |
|---|---|---|---|
| 1 | **Widget extension** | SwiftUI + WidgetKit, lock screen and home screen, tappable checkboxes via `AppIntent` | Medium — well-trodden; `react-native-widget-extension` shows the config-plugin pattern |
| 2 | **App Intents + `reminders` App Schema domain** | `createReminder`, `updateReminder`, `deleteReminders`, `createSection`/`updateSection`, `locationTrigger` | **Hardest.** Xcode enforces cluster completeness at build time |
| 3 | **On-device speech** | `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` | Small — verify a community module honours the on-device flag before writing our own |
| 4 | **Vision text recognition** | Printed list → lines of text | Small — a single function bridged out |
| 5 | **Foundation Models** | On-device LLM, iOS 26+, availability-gated | Small surface, new API — budget for churn |

### The architectural consequence, and it is the important one

**The widget and Siri must work without the JS runtime.** A widget cannot boot React Native, and
neither can an App Intent invoked from a locked screen. So:

> **The SQLite file lives in a shared App Group container, and Swift reads and writes it
> directly. The database schema is a contract between JavaScript and Swift — not a JS
> implementation detail.**

Three rules follow, and breaking any of them breaks the widget silently:

1. **Schema migrations are a cross-language event.** A Drizzle migration that Swift doesn't know
   about means a widget that renders stale or empty. Version the schema explicitly and have Swift
   fail loudly on an unexpected version.
2. **Business logic that both sides need gets written twice** — or pushed into SQL. Prefer SQL:
   a view or a trigger is one implementation both languages read.
3. **Writes from Swift must produce valid op-log entries**, or a lock-screen check-off won't sync.
   The op-log format is the second cross-language contract.

This is the real cost of React Native here, stated plainly: **not "one codebase", but one codebase
plus a carefully-managed seam.** Managed deliberately it's fine. Discovered late it's the thing
that eats a month.

### Order to build the native side

Do #3 and #4 first — they're small, they prove the config-plugin pipeline, and they're not on the
launch critical path. Then #1 (widget), which forces the App Group and the shared-database
decision early, where it's cheap. Then #2 (App Intents), the largest. #5 last, since it's gated
and optional.

---

## 4. Testing and quality

- **Vitest** for the resolver and price logic — pure functions, no device needed. The resolver
  already has 23 cases; that suite moves over as-is
- **React Native Testing Library** for component behaviour
- **Maestro** for end-to-end flows — add, check off, go offline, sync
- **A conflict test harness for the op-log.** Two simulated devices, offline edits, reconnect,
  assert no duplicates and no lost items. **This is the highest-value test in the project** —
  sync bugs are the ones that lose households
- **ESLint + Prettier + `tsc --noEmit`** in CI on every push
- Native modules get Swift unit tests where practical, and a real-device smoke test where not

---

## 5. App size, recalculated for React Native

React Native is not free in bundle terms. Revising `ENGINEERING.md` §4:

| Component | Native (earlier estimate) | React Native |
|---|---|---|
| App binary / runtime | 12–18 MB | **20–28 MB** — RN runtime, Hermes, Fabric, JSI **[estimate]** |
| JS bundle | — | **1–3 MB** minified **[estimate]** |
| Database layer | ~1.5 MB (GRDB) | ~1 MB (`expo-sqlite` + Drizzle) |
| **`catalog.db`** | **200 KB measured** | **200 KB measured** — unchanged |
| Widget extension | 1–2 MB | 1–2 MB — Swift either way |
| RevenueCat SDK | 0 | ~1 MB **[estimate]** |
| Icon, brand assets | 1–2 MB | 1–2 MB |
| Vision · Speech · App Intents · Foundation Models | 0 | 0 — system frameworks |
| **Total, before photos** | ≈ 16–24 MB | **≈ 25–37 MB [estimate]** |

**React Native costs roughly 10 MB.** For scale: OurGroceries ships 13.5 MB and AnyList 50.9 MB
(Android APKs, the closest public figures). We land between them, nearer AnyList than is ideal.

**The ceiling moves from 30 MB to 45 MB**, and item imagery has to fit under it — which makes the
"top 100 photos bundled, emoji tail" recommendation in `SOURCING.md` stronger, not weaker. Bundling
all 414 photos would put us past AnyList, and we'd be a bigger download than the 14-year-old
incumbent with more features.

**Measure at the first TestFlight build.** App Store Connect's thinned download size is the only
number that counts; the `.xcarchive` on disk will look much worse and mean nothing.
