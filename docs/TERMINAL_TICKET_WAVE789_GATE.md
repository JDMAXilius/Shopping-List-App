# TERMINAL_TICKET_WAVE789_GATE — the gate for Prices, Surfaces and Kitchen

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

- [ ] All four packages green — counts
- [ ] `BaggedTests` green — counts
- [ ] `WidgetTests` green — counts
- [ ] UI suites green — counts

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

- [ ] v3 → **v6** upgrade in place, with real data, verified
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

- [ ] ×4 at $3.50 → `$14.00` on the list bar, the aisle subtotal, the widget tile, and Siri's
      "what's left"
- [ ] `½ × ~$4.50` reads `$2.25` and does **not** grow a `~` of its own
- [ ] Scaling never changes the tier — four measured items are measured, not estimated
- [ ] The snapshot suite still matches (`TotalBar`/`AisleHeader` were deliberately ported at
      quantity 1 so the recorded references stay valid — if they drift, that is a finding)
- [ ] **New:** record a snapshot of a five-digit total (`≈ $148.24`). Only a ×4 list produces one,
      and a wrapping or truncating total at `accessibility5` would not be caught today

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
- [ ] **Widget snapshot coverage.** No widget family has any. Record `accessoryRectangular` and
      `systemSmall`, default and `accessibility5`.
- [ ] **Widget tap targets are 20–26pt** against INTERACTION's 44pt floor — forced by fitting
      three rows into a ~72pt tile. **This is a judgement call I want your eyes on, not a bug to
      fix blind.** If mis-taps are easy on a real lock screen, the honest fix is fewer rows.
- [ ] **`AppGroup`.** The three shared strings moved into `Packages/Data` this wave. Confirm on
      device that app, widget and intents all open the *same* file — a mismatch is silent.

### V5 — Two Dynamic Type rulings, already made, yours to implement

Both were your findings; the rulings are settled, the implementation and the re-recording are
yours.

- [ ] **A tab label never wraps and never hyphenates.** `lineLimit(1)`, let the pill grow first,
      then scale to a floor of `0.8` and no lower. If 0.8 is not enough at AX5, the pill's padding
      gives, not the word. **Re-record the AX5 component snapshot** — the current reference has
      "Pric es" baked into it, so the suite is defending the bug.
- [ ] **The shop chip adopts DesignKit's `Chip`.** Truncating to "Tr…" hides which shop's prices
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

- [ ] **Name length.** We refuse names over 60 characters rather than truncate — a cut name is a
      name nobody wrote and the user would be confirming it. Real names are often longer
      ("Organic whole grain rolled oats with flax and chia, family pack" is 63). Raise
      `ProductLookup.maxNameCharacters` if the data says so. **Never truncate.**
- [ ] **Language.** `product_name` comes back in whatever language the contributor used, so a
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
