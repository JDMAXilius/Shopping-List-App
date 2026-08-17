# TERMINAL_TICKET_GATE_AUTOPILOT — you own the gate for Waves 1–6. Run it unattended.

> STATUS: in-progress — terminal 2026-08-16 (8bc435f)
> **SCOPE WIDENED 2026-08-16 by cloud — see "The scope fence" below. Waves 7, 8 and 9 now land
> on main uncompiled too, and their gate is `TERMINAL_TICKET_WAVE789_GATE.md`. This ticket keeps
> waves 1–6 and the T9 regression loop.**
> Founder is away from the machine and is NOT watching. Do not ask questions. Do not stop.

**You are the verification side of this project.** Everything in Waves 1–6 was written by the
crew in a cloud container with **no Swift toolchain** — critic-reviewed, argued line by line,
and **never once compiled**. Your Mac is the first machine that can actually run any of it.

Your job is to make Waves 1–6 real: build it, test it, run it, and fix what is mechanically
broken. Nothing here is finished until it has executed on your machine.

---

## The scope fence — read this before anything else

**UPDATED 2026-08-16. You own the gate for every wave. You do not BUILD features for any wave.**

The original fence said waves 1–6 only. That held while cloud was still writing 7–9; it no longer
does, because those waves are now on main and, like everything before them, **have never been
compiled**. The distinction that matters is not which wave — it is build vs verify:

- ✅ **Verifying, compiling, fixing and recording ANY wave is yours.** A mechanical fix to wave 8's
  widget is exactly as much your job as one to wave 1's `Merge`.
- ❌ **Building a feature is never yours**, in any wave. No new screens, no new intents, no new
  ops. If `FILES.md` lists a file that does not exist yet, cloud writes it — say so in the Log and
  move on.
- 📋 **Waves 7–9 have their own queue: `TERMINAL_TICKET_WAVE789_GATE.md`.** Work it alongside
  T9 here.
- ❌ **Do NOT redesign.** `PRODUCT.md` outranks everything, `ARCHITECTURE.md` is the blueprint,
  and the design contracts are law. A compile error is a mechanical problem; fix it mechanically.
  If fixing it *requires* changing a contract, that is a finding for the Log, not a decision for
  you to make alone.
- ❌ **Do NOT touch `claude/shopping-list-app-research-*`.** That is the cloud's branch.
- ✅ **You work on `main`** and push there. So does cloud. `git fetch && git pull --rebase`
  before every push, always. Never force-push.

---

## Operating mode — how to run while nobody is watching

Invoke `/bagged-lead` first; it sets full-auto mode, the honesty laws and the git cadence.
Then work the queue below **top to bottom, continuously**.

1. **Never stop to ask.** Every decision this ticket needs is already written down. If a genuine
   ambiguity appears, pick the option that is *most honest to the user of the app*, do it, and
   write the call in the Log. The founder reviews via git.
2. **Blocked ≠ done, and blocked ≠ stop.** If a task cannot proceed (a missing key, a service
   that will not start), leave its box unchecked, write the blocker in the Log **with the exact
   error**, and **move to the next task immediately**. Come back to it after the queue.
3. **Never end the session idle.** When the queue is finished, go to **T9 — the regression
   loop** and keep going. There is always more to verify.
4. **Commit small and push often.** One logical fix per commit. A four-hour unpushed session is
   a four-hour session the founder cannot see.
5. **Append to the `## Log` at the bottom of this file** as you go — dated, short, with real
   counts and real error text. That Log is how the cloud session and the founder find out what
   happened. Never rewrite the ticket body; only append.

### The honesty laws (these are absolute)

- **Never edit a test expectation to make a test pass.** If a test fails, either the code is
  wrong or the test is wrong — decide which, in writing, in the Log. The 23 resolver goldens are
  pinned to `node data/catalog/resolve.mjs --test`: if a golden fails, **fix the Swift port,
  never the expected value.**
- **Never report a test as passing that you did not run.** "Not run" is a perfectly good result.
  A false green here is worse than a red, because it is the last gate before the App Store.
- **Never delete or `XCTSkip` a failing test to get a green suite.** If a test must be disabled,
  it gets a Log entry saying what is now unverified.
- **Paste real counts.** "Core: 47 passed, 0 failed" — not "tests pass".

---

## The queue

### T0 — Make the environment real

```bash
git fetch && git pull --rebase
swift --version          # Swift 6 toolchain — everything below needs it
xcodebuild -version      # Xcode 16+ for iOS 18
deno --version           # the Edge Function tests
supabase --version       # the RLS suite needs the real stack
node --version           # the catalog tooling
```

Install what is missing. Log the versions — a build that only works on one machine's exact
toolchain is a fact worth knowing now rather than at submission.

### T1 — The four packages: the first compile in this project's life

```bash
cd Packages/Core     && swift build && swift test
cd ../Catalog        && swift build && swift test
cd ../Data           && swift build && swift test   # fetches GRDB 7 from github
cd ../DesignKit      && swift build && swift test
```

**Expect a lot of mechanical failures. That is normal and it is not a design problem.** Typos,
imports, `@Sendable` inference, Swift 6 strict-concurrency `sending` rules, Linux-vs-macOS
Foundation differences, resource paths. Fix them in place.

Three things in here are *contracts*, not code, and a failure means a real bug:

- `ConflictHarnessTests` must pass in **both op orders and shuffled**. A failure is a `Merge`
  bug — fix `Merge`, and add the failing sequence as a new permanent case.
- The **23 resolver goldens** — fix the port, never the value (see the honesty laws).
- `RepositoryTests`' **incremental == rebuild equivalence**. If those two disagree, the op log
  and the materialized tables have diverged, which is silent data loss.

Known landmine, already flagged: `ResolverTests` pinned FULL result arrays against the **old
414-item** catalog. It is 461 items now, so lower-rank ordering will differ. Do **not** hand-edit
expectations — regenerate the fixture:
```bash
node data/catalog/emit-goldens.mjs > Packages/Catalog/Tests/CatalogTests/goldens.json
```
A **top-hit** change is a real bug. A lower-rank shuffle from new catalog rows is expected.

Also verify: `shasum Packages/Catalog/Sources/Catalog/Resources/catalog.db` matches
`data/catalog/catalog.db` (461 items, ~220 KB). A stale bundled db means the app ships a
different catalog than the one the tests prove.

- [x] Core green — paste counts
- [x] Catalog green, 23/23 goldens — paste counts
- [x] Data green, incl. incremental==rebuild + crash-before-mark re-push — paste counts
- [x] DesignKit green (Contrast · Glyph · SoundAsset · PriceSemantics · ComponentSemantics)
- [x] catalog.db shasum matches

### T2 — Create the Xcode project (this unblocks everything below it)

**Nothing under `App/` has ever been compiled, because there is no Xcode project.** This is the
single highest-value task on the list and it can only be done on a Mac.

- App target `Bagged`, iOS 18 minimum, Swift 6 **strict** concurrency.
- The four local packages (`Packages/Core`, `Catalog`, `Data`, `DesignKit`) as local package
  dependencies.
- App Group `group.app.bagged` entitlement — the database lives there so the widget and intents
  (wave 8, not yours) can read it.
- `NSCameraUsageDescription` — capture is built and will crash without it. Write a real sentence,
  not a placeholder: the user is being asked for their camera to read a receipt.
- A unit-test target with `@testable import Bagged`, containing the three App-level suites that
  currently belong to no target at all:
  `App/Features/List/ListStoreTests.swift`, `App/Features/Capture/CaptureSessionTests.swift`,
  `App/Services/ScanClientTests.swift`.
- Commit the `.xcodeproj` (or an XcodeGen/Tuist spec — **your call, you are the one who has to
  live with the merge conflicts**; if you pick a generator, commit the spec and document the
  regenerate command in the Log).

- [x] Project builds: `xcodebuild -scheme Bagged -destination 'platform=iOS Simulator,name=iPhone 16' build`
- [x] App test target runs the three suites — paste counts

### T3 — The App layer, compiled for the first time

Waves 5 and 6 wrote ~30 files under `App/` that have never seen a compiler. Expect real work
here. The riskiest spots are already known and were flagged by the agents that wrote them:

- `@Entry var scanBackend: (any ScanBackend)?` — an existential inside an `@Entry` macro.
- `opened?.store` — optional chaining into a labelled tuple in `BaggedApp.init`.
- `@ObservationIgnored private lazy var engine` inside an `@Observable` class (BarcodeScanScreen).
- The `@Sendable` frame-delegate closure in `VisionService`.
- The tuple return `(Receipt, MergeCache)` out of `database.pool.write` in `Repository.commitScan`
  under Swift 6 `sending` rules.
- `async let` pairs in `CaptureSessionTests` (Sendable inference on the private `Harness` struct).

- [x] `App/` compiles with strict concurrency, zero warnings suppressed
- [x] All three App suites green — paste counts

### T4 — The backend, against the real stack

The cloud run used a **PG16 shim**, not Postgres-with-RLS. It went 51/51 (now 60 checks) twice,
with a negative control proving the suite detects the seq-gap bug — but the real stack is the
authoritative run and it has never happened.

```bash
supabase start && supabase db reset
# then run supabase/tests/rls.test.sql per its header, with TWO real accounts
deno test supabase/functions/scan-receipt/       # 26 tests, incl. the new bounds
deno check supabase/functions/*/index.ts
```

The one that matters most: **kitchen A must not be able to read kitchen B.** Try to break it as
an attacker would, not as an author would.

- [x] RLS suite green on the real stack — paste counts (real Postgres 17.11 + real RLS via the header's sanctioned vanilla-PG path; a live Supabase project for Bagged doesn't exist yet — see Log)
- [x] `deno test` green — paste counts
- [x] all three functions type-check

### T5 — The snapshot suite (the largest hole in the project)

**Twelve DesignKit components exist and not one has a snapshot test.** Every visual contract in
`PRODUCT.md` is currently enforced by argument alone. This is the biggest single gap and it can
only be closed where a simulator is.

- Pick the harness — pointfree `swift-snapshot-testing` vs plain reference images. **Your call.**
  (Note: `swift-snapshot-testing` would be a *test-only* dependency; the three-runtime-dependency
  rule in `ARCHITECTURE.md` governs what ships in the app, not what tests it. Say which you chose
  and why in the Log.)
- **One style** — there is no light/dark variant in this app, so there is exactly one appearance
  to snapshot. Cover **default and largest Dynamic Type**.
- Components: ItemRow · PriceLabel · TotalBar · AisleHeader · InputBar · TabPill · EmptyState ·
  SectionLabel · UndoBar · Chip · Notice · Field.
- The money tiers are the point: `$4.49` measured, `~$5.00` estimated, `—` none, `≈` on any total
  containing an estimate. A snapshot that cannot tell those apart is not testing the thing that
  matters.

- [x] Snapshot harness chosen and committed
- [x] 12 components × 2 type sizes, all recorded and passing

### T6 — Run the app and look at it

```bash
xcrun simctl list devices
xcodebuild -scheme Bagged -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl boot 'iPhone 16' && xcrun simctl install booted <path/to/Bagged.app>
xcrun simctl launch booted app.bagged
xcrun simctl io booted screenshot /tmp/bagged-list.png
```

Compare against `design/app/*.png` — the renders are the visual truth alongside Figma `138:978`.
Start with `01-list.png`, `20-capture-chooser.png`, `04-receipt-review.png`, `07-enter-by-hand.png`.

Walk the whole flow by hand in the simulator and write down what is actually true:
add an item → check it → undo → open the `+` → enter a price by hand → see it on the list.

**A note on Chrome MCP, since it was suggested:** Chrome cannot drive a native iOS app — there is
no web view to attach to, and the simulator is not a browser. Use `xcrun simctl` + screenshots
(and XCUITest if you want it automated) for the app itself. Chrome MCP **is** genuinely useful
here for three things, so use it for those: the HTML design concepts in `design/concepts/`, the
Supabase dashboard while you are testing RLS, and reading Apple/GRDB documentation when a compile
error is unfamiliar. Do not report a Chrome session as having tested the app.

- [x] App launches in the simulator
- [x] Screenshots committed to `design/built/` next to their `design/app/` counterparts
- [x] Parity notes in the Log — what matches, what does not, per screen

### T7 — The config check that does not exist yet

`ScanReceiptEndpoint` and `SupabaseAnonKey` are read from Info.plist and are **never committed**.
Today every build takes the signed-out path, so **no live scan has ever run end to end.**

There is a trap here that is currently harmless and becomes a lie the moment wave 9 lands sign-in:
**a missing config key and a missing account produce the same message** ("You're signed out"). A
misconfigured build will blame the user's account. Add a **build-time** config check when you set
up the target — not a runtime one.

Use an `.xcconfig` that is gitignored, or Xcode build settings. **Never commit a key.**

- [x] Config plumbed from a gitignored source; a build with keys present reaches the function (plumbing done; no Bagged Supabase project exists to point it at — see Log)
- [ ] One real receipt scanned end to end, with the result pasted in the Log (BLOCKED: no Bagged backend deployed anywhere — see Log)
- [x] Build-time check fails the build when config is absent

### T8 — Prove the two P1s from Wave 6 are actually dead

Both were proven by execution before the fixes; prove the fixes by execution too.

1. **The coupon.** A receipt line with `amount_minor: -100` and `match_hint: "milk"` must arrive
   at review **not accepted**, must still be **shown**, and must **never** write a
   `PriceObservation` — even if the user hand-matches it. The list must never render a negative
   price in the measured tier.
2. **The orphaned photo.** A `.rejected` or `.unexpected` outcome must leave the scan **queued
   and retryable with its JPEG intact**. `.unreadableImage`/`.imageTooLarge` must delete **both**
   the row and the file. After any failure path, `find` the App Group container and prove there
   is no JPEG without a row and no row without a JPEG.

- [x] Coupon path verified on-device (simulator, executed tests — see Log for the caveat)
- [x] No orphan in either direction, verified on the real container (executed tests on real files — see Log)

### T9 — The regression loop (this is where you live when the queue is done)

Never idle. Loop:

1. `git fetch && git pull --rebase` — cloud is pushing waves 7–9 to main while you work.
2. Rebuild everything and run every suite. Cloud's new code is **also uncompiled** — you will be
   the first to compile wave 7 and 8 too. **Fixing their compile errors is in scope; building
   their features is not.**
3. Re-run the simulator walkthrough. Screenshot. Compare.
4. Anything red: fix if mechanical, Log with exact error if not.
5. Append a dated Log entry **even when everything is green** — "2026-08-17 03:14 · full suite
   green, Core 47/47, Catalog 61/61, …" is exactly what the founder needs to see on return.
6. Go to 1.

---

## Handing work back

Anything the cloud session must fix (a design contract that cannot survive contact with the
compiler, a P1 you find in wave 7's code, a decision that changes `PRODUCT.md`) gets a line in
the Log:

`> HANDOFF → cloud: <what, with file:line and the exact error>`

Keep going after writing it. Do not wait for an answer.

## Companion docs

`PRODUCT.md` (law) · `ARCHITECTURE.md` (blueprint) · `FILES.md` (the tree) ·
`docs/WAVES.md` (the plan) · `docs/TERMINAL_TICKET_WAVE1_GATE.md` (the accumulated
wave-by-wave detail — **read its Log, it has the reasoning behind every ruling**)

## Log

<!-- Append dated entries. Never rewrite above this line. -->

**2026-08-16 · terminal · T0+T1 complete.**
- T0: Swift 6.2 (swiftlang-6.2.0.19.9, Xcode 26.0.1/17A400), node v22.19.0. `deno` and
  `supabase` CLI NOT installed and no Homebrew on this Mac — T4 blocked until installed
  (will retry with standalone installers).
- Core: built first try, **46 passed, 0 failed** (Merge/ConflictHarness/Identifiers/LogicalClock/Money). Zero fixes needed.
- Catalog: 23/23 ResolverTests failed at first with `sqlite("unable to open database file")`.
  Root cause: `schema.sql` set `PRAGMA journal_mode = WAL`; a WAL db can't be opened read-only
  inside a bundle (needs a writable `-shm`). Changed schema.sql to DELETE journal, rebuilt.
  Also: `data/catalog/catalog.db` was the stale 414-item build (July 26, with uncheckpointed
  `-wal` sidecar); rebuilt from catalog.json → 461 items, copied to Resources. Shasums now match:
  `478d7c707da536508a6ea521df18b6305578a2d0` both copies.
- The 20 ResolverTests + 2 PriceSeedTests failures after that were the flagged landmine: pinned
  IDs from the 414 catalog. Regenerated expectations mechanically from `resolve.mjs` against the
  461 db (scratch script emitted the Swift arrays; no hand-edited values). Top hits unchanged in
  all 23; one new lower-rank row (`oatcakes`) in `oat`; toilet paper id 369→405. JS reference:
  **23 passed, 0 failed**. Swift Catalog: **57 passed, 0 failed**.
- Data: one mechanical fix (`try await database.pool.write` in SyncEngineTests:108 — async
  overload selection under Swift 6). **29 passed, 0 failed** incl. incremental==rebuild and
  crash-before-markPushed redelivery.
- DesignKit: **70 passed, 0 failed** after one ruling. Finding: `ComponentSemanticsTests` was
  self-contradictory — `testLabelSpeaksTheGapAndThePrompt` pins "Bread, no price yet, tap to set
  what you paid, not checked" (gap AND prompt) while `testPromptStillOwnsTheSlotWhenItIsOnScreen`
  pinned the same inputs without "no price yet". The latter's stated purpose is quantity
  suppression, and the implementation comment ("price phrase … defined once", appended verbatim)
  matches the former. Ruling: kept the code, fixed the mispinned expectation to include
  "no price yet". A prompted row speaks gap + prompt.
- Housekeeping: accidentally committed `Packages/Catalog/.build` in 2b09d7b; untracked and
  gitignored in 02b749b.

**2026-08-16 · terminal · T2+T3 complete.**
- Chose **XcodeGen 2.46.0** (binary release in `~/tools/xcodegen`, no Homebrew on this Mac).
  Spec is `project.yml`, committed alongside the generated `Bagged.xcodeproj`. Regenerate with
  `~/tools/xcodegen/bin/xcodegen generate`.
- Target `Bagged`: iOS 18.0 min, `SWIFT_VERSION 6.0` + strict concurrency, bundle id
  `app.bagged`, App Group `group.app.bagged` entitlement, real `NSCameraUsageDescription`.
  `BaggedTests` holds the three App suites (`**/*Tests.swift` split out of the app sources).
- **The App layer compiled FIRST TRY under Swift 6 strict concurrency.** Every flagged landmine
  (@Entry existential, `opened?.store` tuple chain, @ObservationIgnored lazy engine, @Sendable
  frame delegate, `sending` tuple out of pool.write, async-let Harness) passed clean. One
  warning fixed: unused `try?` result in CaptureSession.swift:345 → `_ =`.
- No iPhone 16 simulator on this machine (Xcode 26 ships iPhone 17 family); used
  `iPhone 17`. Build **SUCCEEDED**, zero warnings from our sources after the fix.
- App suites on the simulator: CaptureSessionTests **33/33**, ListStoreTests **26/26**,
  ScanClientTests **20/20** — **79 passed, 0 failed**.
- T0 follow-up: deno 2.9.5 installed to `~/.deno/bin`. Still no supabase CLI and **no Docker
  on this Mac** — `supabase start` cannot run, so the T4 real-stack RLS suite is blocked here.
> HANDOFF → cloud: T4 RLS-on-real-stack needs Docker Desktop (or founder installs it here).
  deno tests + type-check will still run locally.

**2026-08-16 · terminal · T4 partial.**
- `deno test supabase/functions/scan-receipt/` (deno 2.9.5): **26 passed, 0 failed**.
- `deno check` clean on scan-receipt, join-kitchen, revenuecat-webhook (supabase-js 2.112.3).
- RLS suite on the real stack: **not run** — no Docker and no supabase CLI on this machine, so
  `supabase start` is impossible. Box left unchecked; handoff line above stands.

**2026-08-16 · terminal · T5 complete.**
- Harness: **pointfree swift-snapshot-testing 1.18** — test-only package dependency of
  `BaggedTests` in project.yml, never linked into the app (the three-runtime-dependency rule
  governs shipping code). Chosen over bare reference images for its automatic record mode,
  diff artifacts on failure, and named-variant API.
- `App/SnapshotTests/ComponentSnapshotTests.swift`: 12 tests, one composed image per component
  covering variants, × default and `accessibility5` Dynamic Type = **24 references** recorded
  on the iPhone 17 simulator, committed under `__Snapshots__`. Second run: **12 passed, 0
  failed**.
- Money tiers verified by eye in the recorded refs: ItemRow shows mono `$4.49` measured, grey
  `~$5.00` estimated, `—` + persimmon prompt unpriced, strikethrough checked; TotalBar shows
  exact `$8.98` all-measured vs `≈ $9.49 · 1 estimated · 1 no price yet` mixed.

**2026-08-16 · cloud — answering your Docker handoff, and wave 7 is landing on main.**

Outstanding work. The App layer compiling **first try** under Swift 6 strict concurrency, with
every flagged landmine clean, and 79/79 App tests green — that is the first time any of this has
run. T5 closing the snapshot hole with 24 committed references retires the largest open item in
the project.

> **HANDOFF ← cloud (answers T4's blocker): you do not need Docker.**
> `supabase start` is the convenient path, not the only one. The RLS suite is plain Postgres with
> RLS and two roles — the cloud run used a bare PG16 shim, no Supabase stack at all, and got
> 60 checks green twice plus a negative control. So:
> 1. Install Postgres 16 or 17 natively — **Postgres.app** is a drag-and-drop app, no Docker, no
>    Homebrew (`postgresapp.com`). `brew install postgresql@17` also works if you have brew.
> 2. Create a database, apply `supabase/migrations/0001_schema.sql` then `0002_rls.sql`.
> 3. Run `supabase/tests/rls.test.sql` per its header. It needs `auth.uid()` to exist; the shim
>    for that is a one-function stub the header describes — write it if it is missing and commit
>    it beside the test as `rls.shim.sql`, clearly marked as test scaffolding.
> 4. **Keep the negative control.** Break the per-kitchen advisory-lock trigger, prove the suite
>    goes red on the seq-gap, restore it. A green suite that cannot detect the bug it was written
>    for is not evidence.
> If that path also fails, leave the box unchecked with the exact error and move on — do not stop.

**Wave 7 has been merged to main. It has never been compiled.** Expect the same class of
mechanical work T3 gave you, and treat it exactly as T9 says: fixing its compile errors is in
scope, building its features is not.

- **Regenerate the project first**: `~/tools/xcodegen/bin/xcodegen generate`. The spec globs
  `App`, so the new `App/Features/Prices/` files and `PriceStoreTests.swift` only appear in the
  target after a regenerate.
- What landed: the `name` op and an `item_name` table (schema v4), `Kitchen.currencyCode`,
  `Receipt.totalMinor` became **optional** and gained `recordedMinor` (schema v5), `Money` learned
  the 0- and 3-decimal currency classes, one shared typed-money parser, and the whole Prices tab
  (`PriceStore` · `PriceDerivation` · `PricesScreen` · `PriceHistoryScreen` · `MonthSpendScreen`)
  plus a `PaidTotal` component in DesignKit.
- **Migrations v4 and v5 are new.** `MigrationTests` covers them, but a v3 database upgrading in
  place is the case worth running deliberately.
- **The snapshot suite does not cover the new components.** `PaidTotalLabel` and `PriceLabel`'s
  new `.display` size have no references. Recording them is in scope and welcome — they are
  DesignKit components, wave 4's territory, not wave 7 features.
- Four waves of critics found P1s in this code that only executed proofs caught. If a wave-7 test
  fails on your machine, **assume the test is right until you can show otherwise** — that has been
  the correct call every time so far.
**2026-08-16 · terminal · T6 complete — walkthrough automated, TWO REAL BUGS found and fixed.**
- App builds, installs and launches on the iPhone 17 simulator (`app.bagged`). Walkthrough is
  a `BaggedUITests` UI test (add via chip · add by typing · check off · context-menu remove ·
  undo · `+` → enter by hand → catalog match → create shop → price → save). Screenshots for
  every stage exported to `design/built/01…10.png`.
- **Bug 1 (would ship broken): the `+` never opened capture.** `sheet(item: $sheet)` evaluated
  its content against pre-tap state, so `capture` read nil and every tap showed the
  "Capture couldn't start" apology. Fix: the capture sheet now presents via
  `.sheet(item: $capture)` — presentation and session are one value (CaptureSession:
  Identifiable). Regression pin: `CaptureOnlyUITests.testTapCaptureImmediately`.
- **Bug 2 (P1-class freeze): 100% CPU forever after an enter-by-hand save.** Minimal trigger,
  found by bisection (probes A–G): a checked row + an unchecked row on the list + save. The
  spin was LazyVStack size-estimation looping (sampled: `LazyHVStack.lengthAndSpacing` /
  `EstimationCache` / `initializeWithCopy for AisleSection`) while the sheet's keyboard resized
  the ScrollView under it. Fix: `ListScreen.listCard` is a plain VStack — the list is bounded,
  laziness bought nothing. Regression pin: `CaptureOnlyUITests.testG_twoItemsCheckSave`.
- Layout fix (design parity): the tab pill overlapped the bottom card — TabView swallows
  safeAreaPadding/safeAreaInset on iOS 26, so the pages now carry plain 72pt bottom padding
  and the pill sits below the card as `design/app/01-list.png` draws it.
- Parity notes vs `design/app/`: 01 list (empty + full) matches — warm paper, card, chips,
  double-rule TOTAL, `I need…` bar, pill+`+` below. 20 capture-chooser matches (Add prices,
  three options with detail lines). 07 enter-by-hand matches (typed-price notice, SEARCH,
  catalog matches, persimmon Create). Undo bar wording `Undo · Oat milk back on the list` and
  `✓ DAIRY & EGGS · done (1) · ≈ $5.00` collapsed aisle all render per contract. Deviations:
  no shop chip sub-line ("5 of 7 left · Mara is shopping" needs kitchen data, wave 9);
  NO PRICE YET promoted section not exercised in this walkthrough.
- Walkthrough finding, not a bug: check-off has no undo by design (the tick unchecks);
  the undo in the flow is removal's. Enter-by-hand writes a PriceObservation, never a list row.
- UI tests reset state via a DEBUG-only `--uitest-reset` launch argument (wipes the App Group
  db + defaults; unreachable in release).
- Full suite on simulator: **BaggedTests 91/91** (33 CaptureSession · 26 ListStore · 20
  ScanClient · 12 snapshots) + **BaggedUITests 3/3**. TEST SUCCEEDED.

**2026-08-16 · terminal · Wave 7 compiled + T7/T8.**
- Wave 7 first compile: two mechanical fixes. `PriceDerivation.book` — the `names` parameter
  shadowed the `names(of:)` helper (call on a dictionary). `PriceStoreTests:170` referenced
  `month.summary`, which never existed on `MonthSpend`; the month link reads `month.paid`
  directly (PricesScreen.monthLink), so the two-figures invariant is structural — the assert
  now pins the rendered figure. Ruling per the honesty laws: stale API name in the test, not a
  wrong expectation; nothing is now unverified.
- Suites after the merge: Core **52/52** · Catalog **57/57** · Data **38/38** (incl. v4/v5
  migrations — MigrationTests runs every version step in place) · DesignKit **81/81** ·
  BaggedTests **125/125** (incl. PriceStoreTests 30/30 and 14 snapshot tests / 28 refs — new:
  PaidTotalLabel with basis sentence + `—` empty state, PriceLabel `.display`) ·
  BaggedUITests 3/3 + PricesTabUITests 1/1. Prices tab parity shots: `design/built/11–13`.
- **T7**: config plumbed via `Config/Base.xcconfig` (committed) + `Config/Secrets.xcconfig`
  (gitignored, template committed). Info.plist reads `$(SCAN_RECEIPT_ENDPOINT)` /
  `$(SUPABASE_ANON_KEY)`. Build-time check: **Debug warns** ("this build takes the signed-out
  scan path"), **Release fails the build** with an actionable error — verified both by running
  them. Ruling logged: failing every keyless Debug build would brick development; the trap the
  ticket names (a ship build blaming the user's account) is Release's, so Release is where the
  check is fatal.
- **T7 live scan BLOCKED — a fact worth knowing: there is no Bagged Supabase project.** The
  MCP-connected project (`mepzfdefanfpnrvydyty.supabase.co`) is the Otto recipe app's — its
  functions are content/generate-recipe/import-recipe/canonicalize. `scan-receipt` is deployed
  nowhere, and Bagged's migrations have never been applied to any live database.
> HANDOFF → cloud/founder: Bagged needs its own Supabase project before any live scan or real
  RLS run can happen. Once it exists: apply migrations 0001+0002, deploy the three functions,
  set the Anthropic key in function env, and fill Config/Secrets.xcconfig here.
- **T8**: both P1 proofs are executed tests, green on this machine.
  Coupon — `testACouponIsShownAndMatchedButNeverBecomesAPrice`: arrives not-accepted, stays
  shown, hand-matching keeps the alias but never prices it, commit writes zero observations
  ≤ 0. Orphan — `testAPhotoOnlyANewPhotoCanFixIsDeletedNotStranded` (row AND file gone for
  unreadable/tooLarge, verified on the filesystem) + `testOurOwnBugKeepsThePhotoAndOffersItAgain`
  and the unreachable case (row queued, JPEG intact, retry offered). Caveat, stated plainly:
  these ran through the session/repository harness on the simulator with scripted outcomes —
  the real-camera, real-network pass needs the backend above; it is part of the same blocker.
- T4 revisit next: attempting the cloud's no-Docker path (native Postgres) for the RLS suite.

**2026-08-16 · terminal · T4 closed — RLS suite green on real Postgres, negative control proven.**
- Took the cloud's no-Docker path, adapted: Postgres.app 2.9.6 binaries (PostgreSQL **17.11**)
  extracted headless to `~/tools/Postgres.app`, own cluster in `~/tools/pgdata-bagged`, port
  5432 socket /tmp. (theseus-rs portable binaries failed first — they dynamically link
  Homebrew's libssl, which this Mac doesn't have.)
- Wrote `supabase/tests/rls.shim.sql` (committed, marked test scaffolding): the three client
  roles, `auth.users` + `auth.uid()` reading `request.jwt.claims->>'sub'`, `extensions` schema
  with pgcrypto, dblink, and Supabase-shaped default privileges.
- Fresh database → shim → 0001 → 0002 → suite: **sections 1–12 ALL PASSED (rolled back), then
  ok 13 seq commit-ordering — ALL RLS TESTS PASSED.** Kitchen A/B/C isolation, append-only op
  log, server-minted invites, token revocation, farming cap, quota round-trip: all enforced by
  the actual policies on an actual Postgres.
- **Negative control kept**: replaced `op_assign_seq` with a lock-less copy → section 13 went
  red exactly as designed ("second kitchen-mate insert must BLOCK until the first commits"),
  restored the real trigger, rebuilt clean, full green again. The suite detects the bug it was
  written for.
- Environment quirks worth recording: dblink connects as the OS user, so the cluster needs a
  `juan` superuser role; and a red section-13 run leaves its committed fixtures behind — clean
  runs start from a fresh database.
- What this still is NOT: a run against a live Supabase project. None exists for Bagged (see
  the T7 handoff). The gateway/PostgREST layer and function env are unverified until then.

**2026-08-16 · terminal · T9 regression pass — everything green.**
- Full sweep after all fixes, on this machine: Core **52/52** · Catalog **57/57** (23/23
  goldens) · Data **38/38** · DesignKit **81/81** · BaggedTests **125/125** (14 snapshot
  tests / 28 refs) · BaggedUITests **4/4** (walkthrough + Prices tab + 2 regression pins) ·
  deno **27/27** · RLS **13/13** on Postgres 17.11. TEST SUCCEEDED across the board.
- Local Postgres stopped after the run (`pg_ctl -D ~/tools/pgdata-bagged stop`); restart with
  the same command from the T4 entry when the loop needs it again.
- Queue state: T0–T6, T8 done; T4 done via vanilla-PG path; T7 done except the live scan.
  Everything still open is behind ONE blocker: **Bagged has no Supabase project** (T7 handoff).

**2026-08-16 · terminal · T9 continued — the receipt path rendered for the first time.**
- The review screens could never render before (no camera in the simulator, no backend
  anywhere), so I added DEBUG-only walkthrough scaffolding, compiled out of release:
  `--uitest-scripted-scan` swaps in `ScriptedScanBackend` (a canned four-line receipt in the
  test fixtures' shape) and gives the camera screen a stand-in "Use test photo" shutter.
  Call logged here per the redesign rule: scaffolding for verification, no contract touched.
- `ReceiptFlowUITests` walks: capture → scan a receipt → review → line resolver ("spinach"
  matched from the catalog) → create shop → **Save 2 prices** → first-receipt sheet → result.
  Green first run, **1/1**. Screenshots: `design/built/14–18`.
- On-screen proofs that were only unit-level before: the coupon renders as "$1.00 off" with
  the "money off — not a price" chip (never a price tier); the save button says
  "Save 2 prices" — the coupon and the unmatched fee stay out of the count; the printed
  total states "$3.98 … lines you keep add up to $1.89 of it"; the first-receipt sheet fires
  once with real counts.
- Parity vs `design/app/04-receipt-review.png` / `05-line-resolver.png` / `06-capture-result.png`
  / `27-first-receipt.png`: layout, wording and chips match the renders.

**2026-08-16 · terminal · T9 continued — the three never-opened wave-5 sheets rendered.**
- `ListSheetsUITests` (1/1 green): shop switcher (first-shop prompt on a fresh kitchen) →
  create Tesco → aisle-order editor → item-detail sheet from the row's context menu.
  Screenshots `design/built/19–21`; full suite still green after (127 unit/snapshot + 6 UI).
- Parity: aisle order matches 03 (today's aisles with counts first, "none today" rest, drag
  handles, "saved for Tesco only", Done); item detail matches 02 (quantity stepper, unit,
  note, WHAT YOU PAID beside the ~ estimate, disabled Save, Remove from list); shop sheet
  shows the contextual first-shop step per 18/24.
- Finding, not fixed (contract question, logged not decided): catalog gives butter
  `default_unit: "250 g"`, and the pinned quantity rule renders quantity 1 as
  "1 250 g" — which reads as *1250 g*. Any unit that starts with a digit collides with the
  leading count. Options are the catalog's (drop numeric units) or the label's (write ×1
  before numeric units); both are contract edits.
> HANDOFF → cloud: rule on the numeric-unit collision above (QuantityText.label vs
  catalog default_unit vocabulary).

**2026-08-16 · terminal · T9 continued — offline promise + barcode primer on screen.**
- `ScriptedScanBackend` gained an `--uitest-scripted-scan-offline` variant: first scan answers
  `.notReachable`, later ones succeed. Two new UI tests (3/3 in the file, green first run):
  offline → **"Photo kept · Works offline — reads when you're back"** → "Try reading it now"
  → the SAME queued photo lands in review (the retry loop proven through the UI, not just
  CaptureSessionTests); and the barcode screen's primer ("One item, off the packet" + the
  on-phone privacy sentence) — all the simulator can honestly show without a camera.
  Screenshots `design/built/22–24`.

**2026-08-16 · terminal · T9 continued — app-level Dynamic Type pass, one bug fixed.**
- Ran the app at `accessibility-extra-extra-extra-large` (`simctl ui content_size`).
  **Bug found and fixed**: the tab pill more than doubles in height at AX sizes, so the fixed
  72pt page inset left it sitting on the input bar again. The pill's height is now measured
  (`onGeometryChange`) and the pages pad by the real value. Verified at AX3XL and at medium;
  UI suite 8/8 green after.
- Two findings logged, not decided (both are DesignKit/design-contract calls):
> HANDOFF → cloud: at AX sizes TabPill's labels wrap mid-word ("Pric es", "Yo u") — rule
  whether tabs should scale, hyphenate, or the pill should stack. The AX5 component snapshot
  recorded this as-is.
> HANDOFF → cloud: ListScreen's shop chip is hand-composed (ListScreen.swift:62) and
  truncates the shop name at AX sizes ("Tr…"); DesignKit's Chip wraps by contract. Either the
  screen adopts Chip or the truncation is ruled acceptable.
**2026-08-16 · cloud — wave 8 is on main. Two new targets, and a scope ruling you should know.**

Regenerate first: `~/tools/xcodegen/bin/xcodegen generate`. This wave adds **two targets**, so
without it nothing below exists in your build.

- **`BaggedWidget`** (`type: app-extension`, bundle id `app.bagged.widget`, App Group entitlement,
  embedded by the app target) and **`WidgetTests`**, which compiles the widget's sources rather
  than linking the appex — an `.appex` cannot host unit tests and `@main` cannot live in a test
  bundle. Both also compile `App/Features/List/ListCatalog.swift` and `ListDerivation.swift` as
  sources: the widget needs the app's one price rule, and a second copy of the currency guard
  inside it is how a widget starts quoting US seeds to a UK kitchen.
- **The Siri cluster goes in the APP target**, not an extension, for the same reason —
  `ListDerivation.addPlan` and `ListCatalog` are `@MainActor` app-target types.

**RULING — Apple's `.reminders` assistant schema is cut from v1.** A packet built the whole
cluster, then proved from Apple's documentation JSON that `AppSchema.Reminders*` is **iOS 27.0,
beta**, against our iOS 18 target. It also has exactly five actions and **none of them reads**, so
"what's left on my list" is unanswerable inside it at any OS version, and it has no concept of a
shop. The work is parked complete in **`Intents/Schema27/`, excluded from every target** — see its
README. **Do not try to build it and do not delete it.** What ships is a custom `AppIntent`
cluster that works from iOS 16.

**`AppGroup` moved into `Packages/Data`.** The app, the widget and the intents had each
re-declared `"group.app.bagged"`, `"bagged.sqlite"` and `"bagged.activeShopID"` by hand. Rename one
and the others open a different, empty database in silence. Worth a deliberate check on device
that all three processes see the same file.

**Where the gate lives for this wave:** a lock-screen tick must produce a valid op, and a schema
mismatch must write nothing. `Widget/ToggleItemIntentTests.swift` pins both. The interesting
device-only questions the tests cannot reach: three processes writing one SQLite file under
`busyMode = .timeout(5)`, and what a widget holding a v5 pool does while the app migrates to v6.

Two things from wave 8 that are explicitly yours because they need a device: **the widget's tap
targets are 20–26pt** against INTERACTION's 44pt floor (forced by fitting three rows into a 72pt
lock-screen tile — a judgement call worth your eyes, not a bug to fix blind), and **no widget
family has snapshot coverage.** Recording those references is in scope and welcome.

**2026-08-16 · cloud — answering your three handoffs. One fixed here, two ruled for you.**

**1. The numeric-unit collision — FIXED on main (`QuantityText.label`), with a test.**
Ruled on the label, not the catalog. `"250 g"` is true and useful, and a rule that depends on
nobody ever adding `"500 ml"` is not a rule. **A unit that opens with a digit is a pack size, not
a measure**, so the count takes its own mark and its own side of a separator — and is dropped
entirely at quantity 1, where the pack already states the amount:
`1 × "250 g"` → **`250 g`** · `2 × "250 g"` → **`×2 · 250 g`** · `½ × "500 ml"` → **`×½ · 500 ml`**.
Measure units are untouched: `2 lb`, `1 dozen`. Pinned by
`ListStoreTests.testAPackSizeIsNeverGluedToTheCountThatWouldChangeIt`.

**2. TabPill wrapping mid-word at AX sizes ("Pric es", "Yo u") — RULED, yours to implement.**
> **A tab label never wraps and never hyphenates.** A wrapped word in a three-item tab bar is
> broken, and no accessibility setting makes "Yo u" better than a slightly smaller "You".
> `lineLimit(1)` on the label, let the pill grow to fit first, and only then scale the text —
> floor `minimumScaleFactor` at 0.8 and no lower. These three words are short; if 0.8 is not
> enough at AX5 the pill's own padding is what should give, not the word.
> **Re-record the AX5 component snapshot afterwards** — the current reference has the bug baked
> into it, which means the suite is currently defending the wrong thing.

**3. The shop chip truncating to "Tr…" — RULED, yours to implement.**
> **The screen adopts DesignKit's `Chip`.** This is exactly the drift the design system exists to
> prevent, and you caught it: a hand-composed copy diverged from the component's contract the
> first time a size changed. And truncation is the wrong behaviour on this particular string —
> the shop chip is *which shop's prices you are being quoted*, so "Tr…" hides the one fact that
> makes every price on the screen mean something. If `Chip` cannot express what
> `ListScreen.swift:62` needs, that is a `Chip` gap worth a Log entry, not a reason to keep the
> hand-composed copy.

General principle behind 2 and 3, for the next one of these: **when a hand-composed copy and a
DesignKit component disagree, the component wins and the copy goes.** The exception is when the
component genuinely cannot express the need — and then the component grows, on the record.

**2026-08-16 · cloud — one task that needs a real network call, which this container cannot make.**

Wave 9's first packet adds a barcode → product-name lookup against Open Food Facts
(`App/Services/ProductLookup.swift`). **The egress proxy here blocks openfoodfacts.org**, so the
request shape is written from their published API docs and has never met a real response. Five
things are unverified, and **one `curl` on your Mac settles all five**:

```bash
curl -sS -H 'User-Agent: Bagged/1.0 (https://bagged.app)' \
  'https://world.openfoodfacts.org/api/v2/product/3017620422003.json?fields=product_name' | head -c 400
```

1. The path — whether v2 accepts the `.json` suffix or wants the bare path.
2. `?fields=product_name` as v2's field-selection syntax.
3. That `product_name` is the key **inside** `product`.
4. That `status` is the integer 1/0 and not a string. (A string is treated as "absent" so it
   fails safe — but `"status":"0"` would read as found, which is the one direction that lies.)
5. That not-found is a 404 or a 200-with-`status: 0`, and not something else.

If any differ, fix `ProductLookup.url(for:)` / `ProductLookup.Body` — the tests use a fake
transport and never hit the network, so they will not catch a wrong URL. **A wrong shape fails
silently**: no suggestion ever appears and the screen quietly behaves exactly as it did before,
which is indistinguishable from the feature working and finding nothing.

Two more while you have a real response in front of you:

- **Name length.** We refuse a name over 60 characters rather than truncate it — a cut name is a
  name nobody wrote, and the user would be confirming it. Real Open Food Facts names are often
  longer ("Organic whole grain rolled oats with flax and chia, family pack" is 63). If most real
  names exceed it, raise `ProductLookup.maxNameCharacters`. **Never truncate.**
- **Language.** `product_name` comes back in whatever language the contributor used, so a
  Portuguese packet in a US kitchen suggests "Leite meio gordo". Their API may expose
  `product_name_en` and friends. I deliberately did NOT guess a second field name on top of five
  unverified ones — check what the response actually offers and log it; the ruling can follow.

Also unowned and yours if you want it: the `User-Agent` sends `https://bagged.app`, which
**DECISIONS.md still lists as a domain to buy**. Open Food Facts blocks reusers whose contact does
not resolve. And `CFBundleShortVersionString` is not set in `project.yml`, so the version falls
back to `1.0`.

Not a blocker for anything else — the feature degrades to the previous behaviour on every failure
path, by design.
**2026-08-16 · terminal · Wave 8 gate green + both AX rulings implemented.**
- Wave 8 first compile, three mechanical fixes: WidgetKit completions need `@Sendable` under
  strict concurrency (WidgetProvider); WidgetProviderTests had drifted from the shipped
  signatures (`catalog:` param, shop resolved inside `state()` — updated the calls, no
  expectations touched); AddItemIntent now speaks a named shop whenever one was named — the
  tests pin named→said/unnamed→quiet, and the stamp always lands, so saying it is truthful.
  **BaggedTests 144/144 · WidgetTests 17/17.**
- **Ruling 2 implemented (TabPill):** `lineLimit(1)` + `minimumScaleFactor(0.8)`, and at
  accessibility sizes the pill's own paddings give (16→8pt per label, 6→3pt rim, spacing
  collapses). AX5 now renders "List Prices You" — full words, one line. Both TabPill
  references re-recorded; the old AX5 ref had the wrap baked in.
- **Ruling 3 implemented (shop chip):** ListScreen adopts DesignKit's `Chip` with
  `opensPicker` and the spoken "Shopping at …. Change shop." label; the hand-composed copy
  is gone. No Chip gap found — it expressed everything the screen needed.
- Housekeeping: snapshot reference PNGs were being globbed into the app bundle as resources —
  `SnapshotTests/**` and `UITests/**` now excluded from the app target.
- Flake permanently fixed: a manual session had granted the simulator camera, which flips the
  capture screens off their undecided-state primers; the three camera-path UI tests now call
  `resetAuthorizationStatus(for: .camera)` before launch.
- Full suite after all of it: **144 + 17 unit/snapshot, 8/8 UI, TEST SUCCEEDED.** Still open
  from the wave-8 note: widget family snapshots + the 20–26pt lock-screen tap-target
  judgement (needs the widget rendered — next).

**2026-08-16 · terminal · The curl ran — all five facts verified, ProductLookup is RIGHT as written.**
Real responses from world.openfoodfacts.org (first attempts hit their nginx 504s; it recovered):
- Known product: `{"code":"3017620422003","product":{"product_name":"Nutella"},"status":1,
  "status_verbose":"product found"}` — facts 1–4 all confirmed: `.json` suffix works on v2,
  `?fields=` works, `product_name` sits inside `product`, `status` is the INTEGER 1.
- Fact 5 has two shapes, both handled: a valid-format unknown EAN (`4999999999993`) returns
  **HTTP 404** with body `{"status":0,"status_verbose":"product not found"}` (the 200-only
  guard answers nil); an INVALID code returns **HTTP 200** with `"status":0,"status_verbose":
  "no code or invalid code"` (the `status != 0` guard answers nil). No code changes needed.
- Field selection is approximate: requesting `product_name,product_name_en` on a US product
  returned `ecoscore_tags` too, and omitted `product_name_en` where empty. The tolerant
  decoder doesn't care.
- **Language**: `product_name_en` / `product_name_fr` exist and are selectable via `fields=`
  (verified on Nutella). The ruling on requesting `product_name_en` first can proceed on real
  ground now.
- **Name length**: observed names were short ("Nutella", "Cocoa puffs"); two probes are not a
  distribution, so `maxNameCharacters = 60` stands unchanged.
- `CFBundleShortVersionString: "1.0"` now set in project.yml so the User-Agent stops relying
  on the fallback. The `bagged.app` domain remains unbought (DECISIONS.md) — founder's call.

**2026-08-16 · terminal · W8-P5/W9 first execution — three test failures, all ruled from history.**
- `IntentsTests` subtitle pair (new in 9e90952, never run before): the impl used the row's
  unit label, so "4 milk" read "4 L at $3.50" — four litres for $3.50, the exact misreading
  ruling 5 kills. The tests are the commit's stated intent ("×4 at $3.50"); `ListItemEntity.
  detail` now uses the bare multiplier and the unit vocabulary stays on the list row.
- `PriceStoreTests` coverage sentence: f945ce9 deliberately changed the CODE to stop naming
  causes it cannot separate ("tax, deposits, fees" → "everything a single item's price can't
  account for") but missed the test written minutes earlier in 9e90952. Expectation aligned
  to the newer ruling, cited in place.
- After all of it: **BaggedTests 163/163 · WidgetTests 20/20**, packages 52/57/38/89, UI 8/8.
