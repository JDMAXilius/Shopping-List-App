# TERMINAL_TICKET_WAVE789_GATE — the gate for Prices, Surfaces and Kitchen

> STATUS: in-progress — terminal 2026-08-16 (92044a4)
> STATUS: open — written by cloud 2026-08-16.
> Founder is away. Do not ask questions. Do not stop. Same operating mode and the same honesty
> laws as `TERMINAL_TICKET_GATE_AUTOPILOT.md` — read that ticket's "Operating mode" and "honesty
> laws" sections first; they govern this one too and are not repeated here.

Waves 7, 8 and 9 are on `main` and, like every wave before them, **have never been compiled**.
This is their queue. Work it alongside the other ticket's T9 regression loop — when this queue is
dry, go back there and keep going.

**The rule that governs everything here: fixing their compile errors is in scope, building their
features is not.**

---

## What landed, in one paragraph each

**Wave 7 — Prices.** The price book, one item over time, and month spend. Two contract gaps were
closed first: a **`name` op** (an item's name is a fact about the item, not about a list row —
`item_name` table, schema v4) and **`Kitchen.currencyCode`** (a kitchen shops in one currency,
taken from the device locale). `Receipt.totalMinor` became **optional** and gained `recordedMinor`
(schema v5): the till's total is what the till printed, or nothing. `Money` learned the 0- and
3-decimal currency classes.

**Wave 8 — Surfaces.** A widget (own process, App Group database, never migrates) and a Siri
cluster. Apple's `.reminders` assistant schema was **cut from v1** — it is iOS 27 beta against our
iOS 18 target, has no read intent, and no concept of a shop. It is parked complete and out of
every target in `Intents/Schema27/`; **do not build it and do not delete it.** What ships is a
custom `AppIntent` cluster working from iOS 16.

**Wave 9 (in progress) — a barcode can suggest a name** via Open Food Facts. Name only, never an
image, and nothing third-party is ever persisted as data.

---

## The queue

### V1 — Compile and run everything, and record real counts

```bash
git fetch && git pull --rebase
~/tools/xcodegen/bin/xcodegen generate     # ALWAYS first: two targets and many files are new
xcodebuild -scheme Bagged -destination 'platform=iOS Simulator,name=iPhone 17' test
cd Packages/Core && swift test && cd ../Catalog && swift test \
  && cd ../Data && swift test && cd ../DesignKit && swift test
```

Wave 8 added **`BaggedWidget`** (app-extension, bundle id `app.bagged.widget`, App Group
entitlement, embedded by the app) and **`WidgetTests`** (compiles the widget's sources rather than
linking the appex — an `.appex` cannot host unit tests and `@main` cannot live in a test bundle).
Both also compile `App/Features/List/ListCatalog.swift` and `ListDerivation.swift` as sources, so
the widget uses the app's one price rule instead of a second copy of it.

- [x] All four packages green — counts
- [x] `BaggedTests` green — counts
- [x] `WidgetTests` green — counts
- [x] UI suites green — counts

### V2 — The migrations, upgraded in place

v4 (`item_name`, `kitchen.currency_code`) and v5 (`receipt.total_minor` nullable +
`recorded_minor`) are both new. `MigrationTests` steps every version, but **a v3 database upgrading
in place on a device is the case worth doing deliberately** — install an older build, add data,
then install this one.

One known sharp edge, argued but never executed (a critic found it, severity P3): migration `v5`
writes `PRAGMA user_version = \(AppDatabase.schemaVersion)` using the **constant**, where v1–v4 use
literals. It is correct today. The day a `v6` is registered and `schemaVersion` becomes 6, a fresh
install that runs v5 and then dies before v6 commits will claim to be v6 while holding v5's shape —
and the widget and the intents both trust that number to decide whether they may write. **Change it
to a literal `5` when you are in that file**, and log it.

- [x] v3 → **v6** upgrade in place, with real data, verified
- [x] `user_version` pragma in v5 changed to a literal — **done by cloud**, and
      `MigrationTests` now asserts a database stopped at v5 reads 5

**v6 landed after this ticket was written**: `PriceObservation` gained a quantity, so a receipt
line finally records how many were bought. The one that risks real data: **every `.price` op
already written must still decode, and must go on meaning exactly one unit.** A silent default
that turns old data into a different claim is the worst outcome available here. The decode was
proven by a Python port of the payload rather than argued — re-prove it on a real database with
pre-v6 ops in it.

### V3 — The quantity fix, which touched every total in the app

Until this wave, **nothing multiplied a unit price by its quantity**: a list with ×4 milk at $3.50
showed a trip total of **$3.50**. It now sums line totals. A row still shows the **unit** price
(what you compare between shops); a total sums **line** totals (what is in the trolley).

Verify on screen, not only in tests, because this is the number the product exists to give:

- [x] ×4 at $3.50 → `$14.00` on the list bar, the aisle subtotal, the widget tile, and Siri's
      "what's left" (list bar + aisle on screen; widget/Siri by executed tests — see Log)
- [x] `½ × ~$4.50` reads `$2.25` and does **not** grow a `~` of its own (on screen, pinned by ListTotalsUITests)
- [x] Scaling never changes the tier — four measured items are measured, not estimated (on screen: ×4 milk aisle shows plain $14.00)
- [x] The snapshot suite still matches (`TotalBar`/`AisleHeader` were deliberately ported at
      quantity 1 so the recorded references stay valid — if they drift, that is a finding)
- [x] **New:** record a snapshot of a five-digit total (`≈ $148.24`). Only a ×4 list produces one,
      and a wrapping or truncating total at `accessibility5` would not be caught today (it WAS truncating — found and fixed, see Log)

### V4 — Wave 8's device-only questions

These cannot be reached from a test bed and are the reason this section exists.

- [ ] **Three processes, one SQLite file.** App, widget and intents all write under
      `busyMode = .timeout(5)`. Tick the lock-screen checkbox while the app is foregrounded and
      writing; add via Siri while a capture review is open. Nothing may be lost and nothing may
      wedge.
- [ ] **A widget holding a v5 pool while the app migrates to v6.** The rule is *only the app
      migrates*; the widget compares `installedSchemaVersion()` and renders last-known state.
      Prove the refusal actually refuses.
- [ ] **A lock-screen tick produces a valid op** — the wave-8 gate. Tick from the lock screen,
      then confirm the op reached the log and the app agrees.
- [x] **Widget snapshot coverage.** No widget family has any. Record `accessoryRectangular` and
      `systemSmall`, default and `accessibility5`.
- [ ] **Widget tap targets are 20–26pt** against INTERACTION's 44pt floor — forced by fitting
      three rows into a ~72pt tile. **This is a judgement call I want your eyes on, not a bug to
      fix blind.** If mis-taps are easy on a real lock screen, the honest fix is fewer rows.
- [ ] **`AppGroup`.** The three shared strings moved into `Packages/Data` this wave. Confirm on
      device that app, widget and intents all open the *same* file — a mismatch is silent.

### V5 — Two Dynamic Type rulings, already made, yours to implement

Both were your findings; the rulings are settled, the implementation and the re-recording are
yours.

- [x] **A tab label never wraps and never hyphenates.** `lineLimit(1)`, let the pill grow first,
      then scale to a floor of `0.8` and no lower. If 0.8 is not enough at AX5, the pill's padding
      gives, not the word. **Re-record the AX5 component snapshot** — the current reference has
      "Pric es" baked into it, so the suite is defending the bug.
- [x] **The shop chip adopts DesignKit's `Chip`.** Truncating to "Tr…" hides which shop's prices
      you are being quoted, which is the fact that makes every other number on the screen mean
      something. If `Chip` cannot express what `ListScreen.swift:62` needs, that is a `Chip` gap
      worth a Log entry — not a reason to keep the hand-composed copy.

General principle for the next one of these: **when a hand-composed copy and a DesignKit component
disagree, the component wins and the copy goes** — unless the component genuinely cannot express
the need, and then the component grows, on the record.

### V6 — The barcode lookup: one `curl` settles five unknowns

The container that wrote `App/Services/ProductLookup.swift` has `openfoodfacts.org` blocked by its
egress proxy, so the request shape comes from published docs and **has never met a real response**.

```bash
curl -sS -H 'User-Agent: Bagged/1.0 (https://bagged.app)' \
  'https://world.openfoodfacts.org/api/v2/product/3017620422003.json?fields=product_name' | head -c 400
```

1. The path — does v2 accept the `.json` suffix, or want the bare path?
2. Is `?fields=product_name` v2's field-selection syntax?
3. Is `product_name` the key **inside** `product`?
4. Is `status` the integer 1/0, or a string? (A string is treated as "absent" and fails safe — but
   `"status":"0"` would read as **found**, which is the one direction that lies.)
5. Is not-found a 404, or a 200 with `status: 0`, or something else?

**A wrong shape fails silently.** The tests use a fake transport and never touch the network, so a
wrong URL passes every test and the screen simply behaves as it did before — indistinguishable
from the feature working and finding nothing.

Two judgement calls to make with a real response in front of you:

- [x] **Name length.** We refuse names over 60 characters rather than truncate — a cut name is a
      name nobody wrote and the user would be confirming it. Real names are often longer
      ("Organic whole grain rolled oats with flax and chia, family pack" is 63). Raise
      `ProductLookup.maxNameCharacters` if the data says so. **Never truncate.**
- [x] **Language.** `product_name` comes back in whatever language the contributor used, so a
      Portuguese packet in a US kitchen suggests "Leite meio gordo". Their API may expose
      `product_name_en`. I refused to guess a second field name on top of five unverified ones —
      log what the response actually offers and the ruling can follow.

### V7 — Loop

When this queue is dry, return to `TERMINAL_TICKET_GATE_AUTOPILOT.md` T9 and keep sweeping. Cloud
is still pushing to main; every new wave arrives uncompiled and comes back through here.

---

## Known and NOT to be re-reported

These are recorded, understood, and either deliberate or owned elsewhere. Finding something
*worse* about one of them is still worth a Log entry; restating them is not.

- **Nothing in waves 7–9 has been compiled by anyone.** That is the whole point of this ticket.
- **`Intents/Schema27/**` is parked deliberately** and is in no target. Its README says why.
- **The month screen still counts one of each.** `PriceObservation` carries no quantity, so
  capture stores $3.50 for a ×4 row and throws the count away. Cloud owns the fix (Core + Data +
  a migration); the coverage sentence has already been changed to stop naming causes it cannot
  separate.
- **Mixed-currency totals are wrong and scaling made them 4× more wrong.** Only reachable through
  a currency change or legacy data. Left alone deliberately: adding a precondition to a summary
  that renders on a lock screen is a crash surface, and picking the policy is a ruling.
- **`bagged.app` is not owned and `CFBundleShortVersionString` is unset** — see
  `TERMINAL_TICKET_FOUNDER_BLOCKERS.md`.

## Log

<!-- Append dated entries. Never rewrite above this line. -->

**2026-08-16 · terminal — picked up. V1, V5 and V6 were already closed under GATE_AUTOPILOT's
loop before this ticket landed; full detail lives in that Log.** Counts at pickup: Core 52/52 ·
Catalog 57/57 · Data 38/38 · DesignKit 89/89 · BaggedTests 163/163 (after the three W8-P5/W9
drift rulings, logged there) · WidgetTests 20/20 · UI 8/8. TabPill and shop-chip rulings
implemented, TabPill refs re-recorded. The curl ran: all five OFF facts verified, ProductLookup
correct as written, 404-vs-200 not-found split both handled; name length stands at 60 (observed
names short); product_name_en exists and is selectable. Working V2 next.

**2026-08-16 · terminal · V2 done, V3 done, V4 partial — and the five-digit snapshot caught a real bug.**
- **V2, the deliberate in-place upgrade**: built a seed tool against the pre-wave-7 tree
  (worktree at 9f27f8c, schemaVersion 3), wrote a REAL v3 database through the old Repository —
  kitchen, Tesco, Milk ×4 with a $3.50 manual observation, Sourdough, 4 ops, `user_version 3` —
  planted it in the current app's App Group container and launched. `user_version` came back
  **5**; on screen: Tesco chip, Milk ×4 at $3.50 under DAIRY & EGGS ($14.00 subtotal), Sourdough
  promoted under NO PRICE YET, total **≈ $14.00 · 1 no price yet**. Nothing lost. One
  non-finding recorded: a `.add` op seeded `checked:true` materializes unchecked — deliberate
  (Merge.swift:23 "an add contributes only name + unchecked"); a real check-off is its own op.
- v5's `user_version` pragma is now the literal `5`, with the reasoning in place. Data 38/38.
- **V3 on screen**: the same migrated database doubles as the ×4 proof — list bar and aisle
  subtotal both say $14.00 from a $3.50 unit price, tier untouched (no `~`, no `≈` beyond the
  unpriced row's). ½ × estimate pinned by a new UI test (`ListTotalsUITests`): "0.5 Oat milk"
  totals `≈ $2.50`, single mark. Widget tile and Siri sums are executed-test-pinned
  (`testTheTileMultipliesByTheQuantityTheListSays`, `testWhatsLeftSpeaksTheUncheckedRows…`,
  `testATotalIsNeverSpokenBareWhenSomethingAboutItIsAGuess`) — a home-screen widget cannot be
  driven by simctl, so the on-glass check stays with the device pass below.
- **The five-digit AX5 snapshot found the bug it was designed for**: `≈ $153.17` rendered as
  "≈ $153…" — a truncated money figure, i.e. a wrong number. Fixed in TotalBar under the
  standing ruling (money never wraps or truncates; scale floor 0.8; at accessibility sizes the
  LAYOUT gives — the figure takes its own full-width line under the label). TotalBar refs
  re-recorded; 15 snapshot tests green.
- **V4**: widget snapshots recorded — `accessoryRectangular`, `systemSmall`, and the `needsApp`
  refusal, default + AX5 (a `familyOverride` seam on ListWidgetView; `\.widgetFamily` is not
  writable from a test host). Remaining V4 items need a physical device and stay open:
  three-process concurrency, v5-pool-during-v6-migration, the real lock-screen tick, and the
  AppGroup same-file check on device.
- **Tap-target judgement, from the recorded refs**: three rows in the 76pt tile put each row at
  ~24pt — full-width, so the x-axis is forgiving, but three targets stacked 24pt apart on a
  lock screen will mis-tap. My eyes say the honest fix is the ticket's own suggestion: two rows
  on `accessoryRectangular`, ~36pt each. That is a design change, not a mechanical fix —
> HANDOFF → cloud: rule on 3 rows @ ~24pt vs 2 rows @ ~36pt for the lock-screen tile.

**2026-08-16 · terminal · v6 gated: the old ops still mean what they meant, proven on a real database.**
- The same real v3 seed database (old-tree Repository, a genuine pre-quantity `.price` op)
  planted and migrated in place by this build: `user_version` **6**, and the pre-v6 observation
  reads `amount_minor=350, quantity_milli=NULL` — no silent default, still exactly one unit.
  On screen: identical to the v5 run — Milk ×4 at $3.50, $14.00 subtotal, ≈ $14.00 total.
- Two mechanical fixes on W9-P2's never-compiled tests: `PriceLine(_:quantity:)` is internal by
  design (a line is made solely by `PriceDisplay.line(quantity:)`) — calls rewritten to the
  sanctioned API, values untouched. And the coverage-sentence expectation moved forward again:
  W9-P2 restored "tax, deposits, fees" WITH the backing (`uncounted == 0` guard), so the
  sentence I had aligned to f945ce9's cause-free wording is superseded; expectation now pins
  the guarded causes sentence, citation in place.
- Full sweep after the merge: Core 59/59 · Data 41/41 · BaggedTests 171/171 · WidgetTests 23/23
  · UI 9/9. TEST SUCCEEDED.

### V8 — Wave 9 is complete and wired. It is the largest uncompiled drop yet.

Kitchen, Places, the You tab and the navigation that joins them all landed together. **Regenerate
first** — three new feature folders and the app now builds `App/Features/Kitchen`,
`App/Features/Places`, `App/Features/You` and `App/Services/{LocationService,CSVExporter}`.

Two structural changes worth knowing before you read the first error:

- **`BaggedApp` grew an `AppSession`.** Joining a kitchen changes which kitchen every store
  reads, and a `let` on an App struct cannot answer that, so the stores are held in an
  `@Observable` object and rebuilt whole on a kitchen change. Launch now resolves the kitchen you
  last used (`ActiveKitchen.resolve`) rather than the alphabetically first.
- **`Sheet` gained `case join(String)`** for invite links, and `Route.setup` is now unused —
  Setup is tab 3's root, not a push destination.

- [x] Everything compiles and every suite is green — counts
- [x] `SupabaseURL` reaches the app: with it absent the transport is nil, the phone is `.local`,
      and **nothing syncs, silently.** `Config/Base.xcconfig` and the template both declare it now
      and the Release preflight fails without it. Confirm the Debug warning actually fires.
- [ ] **A guest never sees the paywall.** The role is bound to `kitchenStore.isGuest`, which
      `load()` resolves asynchronously. Exercise it: join as a guest, exhaust three scans, confirm
      the paywall does not appear. This is a `.onChange` binding, so a wrong one fails silently.
- [ ] **An invite link opens the join sheet and nothing else.** Also needs an Associated Domains
      entitlement / `bagged.app` AASA for the tap-through; without it the paste path still works,
      which is the fallback by design.

**Ten Supabase request shapes are unverified** and this is the same trap as the barcode lookup:
`supabase.co` is proxy-blocked here, so every shape came from `0001`/`0002` SQL and the function
source. A wrong one fails silently — no sync, no error, looks like a phone with no server. They
are listed in W9-P3's report; the highest-value five are `rpc/push_ops`' named-argument body, the
PostgREST `op` select with `seq=gt`, the anonymous-signup body, the OTP verify shapes, and
`join-kitchen`'s response. **One live project settles all of them at once** — which is blocked on
`TERMINAL_TICKET_FOUNDER_BLOCKERS` item 1.

**Two known holes, deliberately left, do not "fix" them blind:**

- **A 403 is a poison pill.** An evicted member's queue never drains and every later op piles up
  behind it. `SupabaseTransportError` distinguishes "will never be accepted" from "try again"
  precisely so a future packet can quarantine; nothing quarantines yet.
- **The local projection is kitchen-blind.** A guest's own pre-join items stay in their list and
  mix with the shared one, on their phone only. Fixing it needs a kitchen filter in
  `Repository`/`Merge`.

**2026-08-17 · terminal · V8 — wave 9 compiled, five mechanical fixes, tab 3 seen for the first time.**
- Five fixes, all mechanical, none touching a contract:
  1. `LocationService.fenceLimit` is `static let` on a `@MainActor` class and was used as a
     DEFAULT ARGUMENT of nonisolated `Place.monitored` — now `nonisolated` (a constant Int is
     safe anywhere). This was the only non-test compile error in the whole wave.
  2. `MigrationTests.testTheGeofenceColumnsAreGoneInV7` called `temporaryURL()`, which this file
     does not have; switched to its own `makeDatabase()`.
  3. `KitchenStoreTests.testSharingKeepsTheKitchenTheOpsAreAlreadyAddressedTo` was written
     against a harness shape this file does not have (`Harness()` + `signIn()` + `store.name`).
     Rewritten to `makeHarness(identity:)` + `nameKitchen`, assertions unchanged, and the
     `askedToKeep` read now awaits — `FakeKitchenBackend` is an actor.
  4. `PlaceStoreTests` asserted `shop.wakeRadius == 150` / `wakeEnabled == false`, but v7
     DELETED those fields on purpose. The claim is now structural, so the test asserts what
     survives: the shop round-trips unchanged through a pin, a radius and a wake switch.
  5. One `XCTAssertEqual(await …)` autoclosure in `SubscriptionStoreTests`.
- Counts: Core 59/59 · Catalog 57/57 · Data **59/59** (SupabaseTransport's fake-server suite
  included) · DesignKit 89/89 · **BaggedTests 252/252** · WidgetTests 23/23 · UI 9→10/10.
- **SupabaseURL box closed by execution**: Debug prints `warning: backend config absent — this
  build … never syncs`; Release **fails** with the actionable error naming all three keys.
- **Tab 3 rendered for the first time** (`YouTabUITests`, 1/1): You root, paywall, Kitchen,
  Places, Data & privacy, Why it works this way, About → `design/built/25–31`. Each screen is
  opened from its own launch: Kitchen and Places hide the navigation bar (their back control is
  a custom circular chevron), so chaining back-navigation between them is fragile in XCUI.
- What the screens say with no backend configured, and it is all honest: Kitchen — "This
  kitchen is on this phone only. Invite someone and the list is on both." · Paywall — the
  features, the free-forever list, and "Bagged Plus isn't on sale in this build. Nothing is
  charged" instead of a fabricated price · You — "3 free scans left" chip, Places "none yet".
- **Still blocked, unchanged**: the guest-never-paywalled check needs a real join (the binding
  is `.onChange(of: kitchenStore?.isGuest)` and only a live roster answers it), and the ten
  Supabase request shapes need a live project. Both are FOUNDER_BLOCKERS item 1.

**2026-08-17 · terminal · Dynamic Type sweep over wave 9 — two more real bugs, both fixed.**
Ran the whole You tab at `accessibility-extra-extra-extra-large` (`simctl ui content_size`),
the method that has now found four bugs nothing else caught:
- **"Places" broke mid-word into "Place / s"** on the You root. The row shared one line between
  title and detail ("none yet"), and at AX there was no width left. Fixed the same way TotalBar
  was: at accessibility sizes the LAYOUT gives — the detail moves under the title, which then
  has the full width. Same principle as the tab-label ruling: a word is never broken in half.
- **The tab pill's `+` was clipped clean off the right edge.** The pill grows at AX until the
  row exceeds the display; the persimmon circle was half gone on every screen. `TabPill` now
  constrains its row (`maxWidth: .infinity` + 12pt horizontal padding) so it can never run off.
  Both TabPill references re-recorded — the old ones were taken before this and did not show it
  because the snapshot frame is exactly 390pt while the device row had no bound.
- Re-captured at AX to confirm: "Places" whole with "none yet" beneath it, `+` fully on screen.
- The other five wave-9 screens wrap correctly at word boundaries at AX3XL; paywall, Data &
  privacy, Why it works this way and About are all legible and scrollable.
- Full sweep after: DesignKit 89/89 · BaggedTests 252/252 · WidgetTests 23/23 · UI 10/10.
  (Note for the next person: leaving the simulator at an AX content size makes the capture UI
  tests fail — they assert on layout-sensitive controls. `simctl ui booted content_size medium`
  resets it.)

**2026-08-17 · terminal · Two more paths executed for the first time: the export, and the month chart.**
- **CSV export had never been run.** `ExportUITests` now drives it on real content: two items on
  the list → You → Data & privacy → "Export everything (CSV)". The screen answers **"3 files
  ready — share or save"**, and the files are really on disk in the app container. Contents
  checked by hand against what the copy promises:
  `bagged-list.csv` carries both rows with their catalog units (`Butter,1,250 g,…`),
  `bagged-prices.csv` and `bagged-receipts.csv` carry their headers with no rows (nothing was
  priced), every amount column is `amount_minor` + `minor_unit_exponent` so nothing is rounded
  on the way out, and the `quantity` column is BLANK rather than 1 — exactly the v6 promise
  ("a count nobody recorded is left blank"). Screenshot `design/built/32-export-ready.png`.
- **Month spend re-checked after W8-P5 and W9-P2 changed the money rules**, and the screen is
  honest end to end: no receipts → `—` with "No receipts captured in August, so there is no
  total to state", the coverage line says the prices were recorded by hand, and "How real is
  this? 0 of 1 matched price came from a receipt".
  One defect found and fixed: the aisle breakdown pinned its label to a fixed 92pt with
  `lineLimit(1)`, so **"Dairy & Eggs" rendered as "Dairy & Eg…"** — an aisle the reader has to
  guess at, while the bar beside it had slack. The column stays fixed (that alignment is what
  makes the bars readable as a chart) and the label now takes two lines, wrapped at the word.
- DesignKit component snapshot coverage confirmed complete: every component in
  `Components/` has a reference except `OptionalFocus`, which is a helper, not a view.
---

### V9 — The screens panel, and one trap in how it arrives (cloud, 2026-08-17)

A testing-only panel landed on the You tab: **About → "Open a screen directly"** opens one list
that constructs ~25 screens directly, so a screen that normally costs a real receipt or a real
invite to reach is one tap away. `App/Features/You/ScreensPanel.swift` + `ScreensPanelTests.swift`.
The founder asked for it explicitly as scaffolding — *"keep in mind that we wanted to actually make
it properly later"* — so treat it as temporary, and do not build on it.

**Read this before you run anything, because the failure is silent:**

- [ ] **Regenerate first.** `Bagged.xcodeproj/project.pbxproj` lists sources individually and it
      does NOT contain `ScreensPanel`. Without `xcodegen generate` the panel is not in the app
      target **and its 9 tests are not in `BaggedTests`** — you would run a green suite that never
      compiled either file and report it as a pass. `git grep -c ScreensPanel
      Bagged.xcodeproj/project.pbxproj` must be non-zero before you believe a green run.
- [ ] **Confirm the test count went UP by 9** against your last recorded `BaggedTests` number
      (252 at V8). A count that did not move means the file is still not in the bundle. This is the
      whole reason the check exists — state both numbers in the Log.
- [ ] **It has never been compiled.** I checked every initialiser it calls against the real
      declarations (all 20 match, `ListItem.itemID` and every `@Entry` are optional as it assumes),
      but I cannot build iOS here. Expect mechanical errors and fix them; report anything that is
      not mechanical instead of fixing it.
- [ ] **Open it on the simulator and walk the list.** Every row must either open a screen or say in
      one sentence why it cannot. Four rows refuse on purpose — Receipt review, Line resolver,
      Receipt saved, First receipt — because each needs a receipt a real scan parsed, and a
      fabricated one would write invented prices into the price book as `source: .receipt`. **Do
      not "fix" those four by making one up.** If you want them reachable, that needs
      `CaptureSession` to expose a test seam, which is a packet and a cloud ruling, not a patch.
- [ ] Three screens are handed `sheet: .constant(nil)` (You, Kitchen, Price history), so rows
      *inside* them that open a sheet do nothing from the panel. Each says so. Verify the wording
      is there rather than assuming it.

**A new build flag, `BAGGED_SCREENS_PANEL`.** `project.yml` now sets
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` explicitly for both configs — `DEBUG BAGGED_SCREENS_PANEL`
in Debug, `BAGGED_SCREENS_PANEL` in Release — and the panel, its row in About and its tests are all
inside `#if BAGGED_SCREENS_PANEL`. Two things follow, and both are yours to verify:

- [ ] **`DEBUG` still reaches the compiler.** Naming that key replaces the value XcodeGen would
      have injected, and I spelled `DEBUG` back in by hand. If I got it wrong, `#if DEBUG` blocks
      go quiet **without breaking the build** — `--uitest-reset` stops working and
      `ScriptedScanBackend.isRequested` is never consulted, so the capture UI tests would fail or
      start hitting the real backend path. Check a Debug build actually honours `--uitest-reset`.
- [ ] **The panel is visible in Debug.** If the flag does not reach the compiler the failure mode is
      soft: everything stays green and the panel is simply absent. Seeing the row in About on the
      simulator is the only proof.

Why a flag rather than `#if DEBUG`: **a TestFlight build is a Release build**, so DEBUG-only would
hide the panel from the one place a tester needs it. There is also a runtime lock (`sandboxReceipt`
only, App Store never), but a runtime boolean in a shipping binary is one edit away from being
wrong, and the flag means the code is not there at all. **Deleting the token from the Release line
is the entire removal** — no file to remember. That deletion is now a submission blocker in
`TERMINAL_TICKET_FOUNDER_BLOCKERS` §10.
