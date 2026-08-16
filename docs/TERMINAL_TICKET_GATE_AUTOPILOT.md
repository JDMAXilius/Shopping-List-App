# TERMINAL_TICKET_GATE_AUTOPILOT — you own the gate for Waves 1–6. Run it unattended.

> STATUS: in-progress — terminal 2026-08-16 (8bc435f)
> STATUS: open — written by cloud 2026-08-16.
> Founder is away from the machine and is NOT watching. Do not ask questions. Do not stop.

**You are the verification side of this project.** Everything in Waves 1–6 was written by the
crew in a cloud container with **no Swift toolchain** — critic-reviewed, argued line by line,
and **never once compiled**. Your Mac is the first machine that can actually run any of it.

Your job is to make Waves 1–6 real: build it, test it, run it, and fix what is mechanically
broken. Nothing here is finished until it has executed on your machine.

---

## The scope fence — read this before anything else

**You own Waves 1 through 6 ONLY.** The cloud session is continuing to build Waves 7, 8 and 9
in parallel with you, on its own branch.

- ❌ **Do NOT start Wave 7, 8 or 9.** No Prices screens, no Widget, no Intents, no Kitchen,
  no Places, no Paywall. If you find yourself creating a file that `FILES.md` lists under those
  waves, stop and go back to the queue below.
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

- [ ] Core green — paste counts
- [ ] Catalog green, 23/23 goldens — paste counts
- [ ] Data green, incl. incremental==rebuild + crash-before-mark re-push — paste counts
- [ ] DesignKit green (Contrast · Glyph · SoundAsset · PriceSemantics · ComponentSemantics)
- [ ] catalog.db shasum matches

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

- [ ] Project builds: `xcodebuild -scheme Bagged -destination 'platform=iOS Simulator,name=iPhone 16' build`
- [ ] App test target runs the three suites — paste counts

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

- [ ] `App/` compiles with strict concurrency, zero warnings suppressed
- [ ] All three App suites green — paste counts

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

- [ ] RLS suite green on the real stack — paste counts
- [ ] `deno test` green — paste counts
- [ ] all three functions type-check

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

- [ ] Snapshot harness chosen and committed
- [ ] 12 components × 2 type sizes, all recorded and passing

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

- [ ] App launches in the simulator
- [ ] Screenshots committed to `design/built/` next to their `design/app/` counterparts
- [ ] Parity notes in the Log — what matches, what does not, per screen

### T7 — The config check that does not exist yet

`ScanReceiptEndpoint` and `SupabaseAnonKey` are read from Info.plist and are **never committed**.
Today every build takes the signed-out path, so **no live scan has ever run end to end.**

There is a trap here that is currently harmless and becomes a lie the moment wave 9 lands sign-in:
**a missing config key and a missing account produce the same message** ("You're signed out"). A
misconfigured build will blame the user's account. Add a **build-time** config check when you set
up the target — not a runtime one.

Use an `.xcconfig` that is gitignored, or Xcode build settings. **Never commit a key.**

- [ ] Config plumbed from a gitignored source; a build with keys present reaches the function
- [ ] One real receipt scanned end to end, with the result pasted in the Log
- [ ] Build-time check fails the build when config is absent

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

- [ ] Coupon path verified on-device
- [ ] No orphan in either direction, verified on the real container

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
