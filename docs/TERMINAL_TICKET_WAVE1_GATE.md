# TERMINAL_TICKET_WAVE1_GATE — now covers Waves 1, 2 AND 3

> STATUS: done — terminal 2026-08-16, superseded by TERMINAL_TICKET_GATE_AUTOPILOT.
> STATUS: open — written by cloud 2026-08-16. Blocked in cloud: the container's proxy denies
> download.swift.org, so no Swift toolchain there. This machine has one.

**Run the Wave 1 + Wave 2 gates (`docs/WAVES.md`): build + test `Packages/Core`,
`Packages/Catalog` and `Packages/Data`, fix what's mechanical, report what isn't.**
*(Founder call 2026-08-16: waves continued in cloud without the gate — not at the PC; both
gates run together here.)*

The packages were written by the crew in the cloud session, critic-reviewed, but **never
compiled** — expect a handful of mechanical compile errors (that's normal for unexecuted code),
not design problems. The design contracts are law; don't redesign while fixing.

## Do

```bash
git fetch && git pull --rebase
cd Packages/Core    && swift build && swift test
cd ../Catalog       && swift build && swift test
cd ../Data          && swift build && swift test   # fetches GRDB 7 from github
```

1. Fix mechanical compile/test failures in place (typos, imports, Linux/macOS Foundation
   differences, resource paths). Behavioral divergence in Catalog is different: the 23 golden
   cases are pinned to `node data/catalog/resolve.mjs --test` — if a golden fails, fix the
   PORT, never the expected value.
2. The conflict harness (CoreTests) must pass in both op orders + shuffled. If a harness
   scenario fails, that's a real Merge bug: fix Merge, add the failing sequence as a new case.
3. Commit fixes to main (small commits), append results to the Log below.

## Done when

- [ ] `swift test` green on Core (incl. ConflictHarnessTests) — paste counts in Log
- [ ] `swift test` green on Catalog — 23/23 goldens — paste counts in Log
- [ ] catalog.db shasum in Packages matches data/catalog/catalog.db
      (currently `58aab7e9…`, 220 KB, 461 items)
- [ ] ⚠️ **ResolverTests pinned FULL result arrays against the OLD 414-item db.** The catalog
      grew to 461, so some pinned arrays will now differ. Do NOT hand-edit expectations:
      regenerate with `node data/catalog/emit-goldens.mjs > Packages/Catalog/Tests/CatalogTests/goldens.json`
      (already regenerated in this commit) and point the test at that fixture. The TOP-hit
      semantics in `resolve.mjs --test` (23/23) remain the contract — a top-hit change is a
      real bug; a lower-rank shuffle from new catalog rows is expected
- [ ] `swift test` green on Data — incl. incremental==rebuild equivalence, the
      crash-before-mark re-push test, and the deterministic fake-clock backoff tests
- [ ] Wave 3: `supabase start && supabase db reset` then run `supabase/tests/rls.test.sql`
      per its header on the REAL stack (the cloud run used a PG16 shim — 51/51 green, twice,
      with a negative control proving the suite detects the seq-gap; the real stack is the
      authoritative re-run). Deno-check the three functions
- [ ] Wave 4: `swift test` on Packages/DesignKit (Contrast · Glyph · SoundAsset ·
      PriceSemantics suites — all expectations machine-derived, never hand-tuned).
      Then pick the snapshot harness (pointfree swift-snapshot-testing vs plain images —
      Mac decision) and add the one-style x default + largest Dynamic Type suite
- [ ] Wave 5: create the **Xcode project** — App target `Bagged` + Widget + Intents, the four
      local packages as dependencies, App Group `group.app.bagged` entitlement on every target,
      and a unit-test target that runs `App/Features/List/ListStoreTests.swift`
      (`@testable import Bagged`). This is the one wave-5 task that CANNOT be done in cloud.
      Then `swift test` the packages and run the app in the simulator against `design/app/01-list.png`
- [ ] Wave 6: `swift test` on Core/Data (alias op, pending_scan, schema v3) and DesignKit
      (Chip · Notice · Field · SectionLabel · UndoBar). Then `deno test supabase/functions/scan-receipt/`
      and re-run `rls.test.sql` — the cloud run was PG16+shim, 60/60, mutation-tested
- [ ] ⚠️ **THE SNAPSHOT SUITE STILL DOES NOT EXIST** and is now the largest hole in the visual
      contract. FILES.md advertises `Tests/DesignKitTests/SnapshotTests`; twelve components have
      shipped without it. Every layout claim — quantity under the name at AX5, chip words
      wrapping instead of truncating, Field's label above the box, a long undo phrase not
      shoving the price off-screen — is reasoned, never rendered. Contrast and semantics ARE
      tested (pure functions, real WCAG math); geometry is not. Rank this just behind the
      Xcode project
- [ ] Log entry appended; pushed to main

## Log — append only

- **2026-08-16 · cloud** — Wave 1 built by builder (W1-P1 Core) + engine-porter (W1-P2 Catalog);
  critic REFUTER pass done in cloud (see WAVES log/commits). Gate handed here.
- **2026-08-16 · cloud (critic + fixes)** — Critic W1-C1 found 1 P1 + 3 P2 in Merge, all fixed
  in W1-P3: re-add-after-delete now resurrects (MAX delete stamp per id, later add wins);
  grouping keys on RESOLVED name not seed name; adds contribute only name + checked=false as
  stamped writes (no default-clobber; other seed fields are unstamped fallbacks from the
  latest add); price observations keyed by OpID (duplicate receipt lines both survive, replay
  idempotent); output sort fully totalized. Accepted tradeoff documented at the OpStamp
  comparator. Harness now 13 scenarios incl. the three breaking sequences, asserted in both
  orders + shuffled. **Nothing has been compiled — expect mechanical fix-ups here, and treat
  any golden or harness failure as a real bug, not a flaky test.**

- **2026-08-16 · cloud (wave 2)** — Packages/Data built (W2-P1), critic W2-C1 found 1 P1 + 4 P2
  (push-idempotency contract hole masked by a too-kind fake; SQLITE_BUSY cross-process; Observed
  cross-process blindness; timestamp-cursor under-delivery; wall-clock test flake), all fixed in
  W2-P2 with matching tests; op schema gained seq bigserial + ON CONFLICT DO NOTHING as contract.
  Known P3s accepted and documented in code. GRDB 7 API spellings are from knowledge, never
  compiled — expect mechanical fix-ups here; the builder's report lists likely alternates.

- **2026-08-16 · cloud (wave 3)** — Backend built (W3-P1) and attack-tested on an in-container
  PG16 + Supabase shim. Critic W3-C1 ran live attacks: 3 HIGH proven (seq pulled past a
  mid-commit batch = permanent op loss; idempotent push existed only as a comment — retried
  batch 409s; free scans farmable via fresh anonymous sessions), 3 MED (evicted guest rejoins
  with live token; token entropy client-controlled; webhook replay flips entitlement), 3 LOW.
  All fixed in W3-P2: per-kitchen advisory-lock trigger (commit-ordered seq), push_ops RPC,
  owner-only non-anonymous scanning, eviction revokes invites, server-minted 32-byte tokens,
  plus_event_at replay fence, seq SELECT revoked, kitchen cap, last-owner guard. Suite now 51
  checks, green twice, with a NEGATIVE CONTROL (trigger dropped → suite fails on exactly the
  critic's repro). What only the real stack can prove: GoTrue is_anonymous rejection + owner
  check in scan-receipt, and the Anthropic structured-output param spelling.

- **2026-08-16 · cloud (catalog growth)** — Demand simulation added (`probe.mjs` + 338 realistic
  queries): coverage was **79.6%**, now **96.4%** after 47 new items + 14 synonym fixes, all
  driven by measured misses rather than bulk import. Killed 7 dangerous fuzzy matches — the worst
  were `salted butter → UNSALTED butter`, `matches → matcha`, `water → watermelon`. Added the
  five missing generic parents (bread/pasta/potatoes/cheese/chicken) that the catalog already had
  for `milk`; before this, `pasta` returned *pasta sauce* and `chicken` ranked *stock* above
  *breast*. 461 items · 1004 lookup terms · 220 KB. `resolve.mjs --test` still 23/23.
  ~~Open finding: QuantityParser vocabulary gap~~ — **fixed, see the entry below.**
  Also new: `audit-seeds.mjs` — gate #2 tooling. Feed it `<item>\t<price>` TSV from real
  receipts; it reports median/mean error, bias, and the worst-offending seeds.

- **2026-08-16 · cloud (QuantityParser fix)** — Closed the vocabulary gap. New JS reference
  `data/catalog/quantity.mjs` (23 cases, green) is now the pinned contract; the Swift parser was
  rewritten against it and `QuantityParserTests` regenerated from its output — **every expectation
  in that file was produced by running the reference, not written by hand**. Adds: containers with
  no number (`carton of milk` -> 1 carton, milk), the `of` connector, word-numbers and halves
  (`a`, `three`, `couple of`, `half dozen`), ~30 packaging nouns (punnet/loaf/tub/carton/jar/tin/
  head/clove/slice/roll/sachet...), and a size skip before a container (`large tub of yoghurt`).
  Two guards keep it honest: it never consumes the whole input (bare `loaf`/`dozen`/`bag` stay
  items), and container words inside names are untouched (`bin bags`, `tea bags`, `canned
  tomatoes`). **Pipeline coverage on the 338-query probe: 96.4% resolver-only -> 99.7% with the
  parser in front** (`node data/catalog/probe.mjs`, `--raw` for resolver-only). The single
  remaining miss is `weetabix`, a brand we exclude by rule.
  WARNING: two pre-existing Swift expectations legitimately CHANGED (verified against the
  reference, not relaxed): `p("2")` is now `(nil, nil, "2")` — the never-consume-everything
  guard — and `p("a dozen eggs")` is now `(1, "dozen", "eggs")`, which is the fix itself.
  **Wiring still owed (wave 5, App/Features/List):** the add-item path must call
  `QuantityParser.parse` and feed `.rest` to the resolver, storing quantity/unit on the item.

- **2026-08-16 · cloud (wave 4)** — DesignKit built (W4-P1) and refuted (W4-C1). The pre-build
  contrast check caught **muted #8C857A failing its own gate at 3.33:1** — on the colour that
  renders every estimated price — now #716A5F (4.87/5.34). The critic then found the two
  canonical renders DISAGREE on the item tile (01-list: white + tint ring + item glyphs;
  08-prices: solid tint + category glyph). **Lead ruling: solid tint is canonical**; 01-list's
  ring treatment is superseded. Persimmon darkened #C9502C -> #C64E2B (4.499 failed strict 4.5;
  now 4.640, rounding hack deleted from the test). Honesty made structural where the critic
  proved it wasn't: PriceDisplay.measured is unreachable without a PriceObservation.Confidence;
  TotalBar/AisleHeader derive sum, approx-marker and breakdown from ONE [PriceDisplay] array so
  they cannot disagree; unpriced items make aisle subtotals approximate; the promoted-row
  "tap to set what you paid" prompt exists as component anatomy. Progressive strikethrough
  (attribute strike = the Reduce Motion path), checked-price opacity removed (composite was
  3.02:1 — worse than the grey we corrected), one VoiceOver phrase defined once, Sound
  structurally silent in .appex processes, whole-row toggle wired. Sounds are generated + parsed:
  check 100.0ms / complete 380.0ms, both -13.0dBFS, soft attack, no DC, no clicks.
  **Figma F·Tokens now owes TWO values: muted #716A5F, persimmon #C64E2B.**
  **Render defects for the wave-7 packet: 10-month-spend shows a GREEN delta (PRODUCT bans
  valuative green — must be ink) and a stop-square instead of + in the tab circle. PRODUCT
  outranks renders.** Wave-5 note: TotalBar/AisleHeader/PriceDisplay have the new surface —
  build against it, and Money needs the per-currency minor-unit exponent before any non-USD.

- **2026-08-16 · cloud (wave 6, part 1)** — Capture's foundations. Two things the flow needed that
  didn't exist: the **`alias` op** ('TJ ORG BABY SPNC' -> Baby spinach, matched once and remembered
  kitchen-wide, with a nil case meaning 'ignore forever'), and **`pending_scan`**, which keeps the
  offline promise printed on the camera screen — capture succeeds, photo stays on device, parse is
  deferred, survives an app kill. Alias keys fold punctuation because till printers emit it.
  `shop_id` is nullable: forcing a shop choice before the shutter is friction at the worst moment,
  so the trip gets its shop at review.
  **DesignKit gained five components** (SectionLabel, UndoBar, Chip, Notice, Field) collapsing
  duplications the nine capture screens would have copied, plus ONE home for the persimmon rule
  that all of them forward to. Two rulings worth knowing: a `sure` confidence chip is **not green**
  (green means fact; a parse awaiting review is a guess), and the Figma-sanctioned amber
  **#D9A03F is refused** at 2.32:1 — it could only ever have been a decorative dot. `Motion.undoDwell`
  is 8s, derived from glance-up + read + reach, not picked.
  **The backend stopped burning scans on its own failures**: model output is validated line by
  line (one bad line 502s the parse AND refunds), 403 split into sign_in_required vs
  kitchen_required so a signed-in owner isn't sent to a sign-in screen, and two bugs found in
  self-review — an uncaught 500 that spent a scan with no refund path, and truncation reported as
  'unreadable image' when the receipt was merely long. RLS suite 51 -> 60 checks, **mutation-tested**
  (code broken to prove the tests fail, then restored).

- **2026-08-16 · cloud (wave 6, part 2)** — Capture is now **reachable**. The flow existed but the
  `+` presented a placeholder; `RootView` now builds a `CaptureSession` before the sheet is asked
  for (never inside a body pass — a session minted in `sheetContent` loses a half-checked review
  mid-scroll) and releases it in `onDismiss`. The environment carries `repository`, `kitchenID`,
  `catalog` and `scanBackend` as `@Entry` keys rather than widening `ListStore` into the DI
  container §6 refuses. Stranded `parsing` scans — a scan the app was killed during, which nothing
  else would ever pick up — are swept back to `queued` at launch.
  **A remembered alias now gets its name from the catalog**, not from the list: before this, an
  alias pointing at an item you had already bought and checked off rendered as the till printed it,
  'TJ ORG BABY SPNC'. **Display casing was ruled once, at the `ListCatalog` boundary** — the catalog
  stores names lowercase because that is how it matches, so the name written to the list is now the
  name the user was shown, and the widget, the CSV and twelve components need no display rule of
  their own. Only the first character moves, so a user's own 'TJ' or '2% milk' survives; every
  dedupe key already goes through `Merge.normalized`, which lowercases.

  **Two things for your Mac, both new:**
  1. **Scan config comes from Info.plist** — `ScanReceiptEndpoint` and `SupabaseAnonKey`, read via
     `Bundle.main.object(forInfoDictionaryKey:)`, **never committed**. Until the Xcode project
     exists, every build takes the signed-out path and **no live scan has ever run end to end**.
  2. **A missing key and a missing account currently give the same message** ("You're signed out").
     That is true today, when neither exists. Once wave 9 lands sign-in it becomes a lie — a
     misconfigured build will blame the user's account. **Add a build-time config check when you
     create the Xcode target**, not a runtime one.

  Still open from earlier waves and unchanged: **the snapshot suite does not exist** after twelve
  DesignKit components — it remains the largest hole in the visual contract, and it can only be
  written where a simulator is.

- **2026-08-16 · cloud (wave 6, closed)** — The last two capture screens, then a refutation that
  found **two P1s**, then the fixes. Wave 6 is done.

  **The barcode ruling.** The catalog has no UPC column and we are not inventing one, so a barcode
  is **a key the kitchen teaches once** — scan it, say what it is, and the `.alias` op tells the
  whole kitchen forever. Same machinery receipt lines use. QR was dropped from the symbology list:
  a QR payload is a URL, never a product key.

  **P1 — a coupon wrote a negative MEASURED price.** Proven by execution. A per-item discount line
  is in-contract for the parser, resolves `match_hint: milk`, and auto-accepted; the sanity gate
  only ever tested for prices too HIGH, so -$1.00, $0.00 and $0.05 all passed. It committed as a
  `.receipt` observation sharing the real line's date, so the tie-break was a random UUID —
  **about half the time your list showed milk at -$1.00 in solid ink.** Ruled: zero or less is not
  a price, enforced structurally rather than by a screen remembering. The coupon is still shown,
  because the receipt has to reconcile to its printed total.

  **P1 — a failed scan orphaned the photo forever, and one input made it permanent.** Nothing in
  the app ever queried `state = 'failed'`: the photo could not be read, shown or deleted, and sat
  in the App Group container for good. The trigger was deterministic — shop names have no length
  cap, the hint went out untruncated, and >100 chars is a 400. **A user whose shop is called
  "Whole Foods Market — 1234 Something Blvd, Suite 200, San Francisco CA 94110" had every photo
  they would ever take fail identically, forever.** Ruled three ways: the client truncates to the
  limit it already knows; our fault (or a gateway's) keeps the photo and stays retryable; only a
  photo that a new photo is the only fix for is deleted — and its JPEG goes with the row.

  Also fixed: cancelling the shop picker silently reverted the shop (14 Trader Joe's prices filed
  under Whole Foods), the receipt under review was still offered as "waiting to be read" — a tap
  spent a second scan and wiped every hand-match — "Keep it" on a permanently-ignored line wrote
  nothing, and `commit()` half-wrote under `try?` while the result screen still claimed "every
  line became a price". A commit is now **one transaction**, retryable, with nothing written on
  failure.

  **Server side, mutation-tested:** `amount_minor`/`total_minor` bounded to ±$1,000,000
  (`Number.isInteger(1e300)` is true — that number shipped as a 200, failed the client's decode and
  **burned a free scan with no refund path**), `quantity` must be a real count, and `currency` must
  be a 3-letter ISO code. Any non-empty string used to pass, so "eur" rendered as `eur 40.00` — and
  worse, the 3× sanity gate requires matching currency codes, so it was **silently off for every
  non-USD receipt**, exactly the ones most likely to be mis-read.

  **TWO CONTRACT GAPS FOR WAVE 7 — read these before the price book is built:**
  1. **There is no op that names an item.** `edit` is keyed on `ListItemID`, a LIST ROW. An item
     created at the resolver or the barcode screen lives only in the alias table: its prices are
     real and its name is stored nowhere. The price book would have rows it cannot name. Needs a
     `name` op in Core, Data and the sync contract.
  2. **There is no source for the user's currency.** `currencyCode` defaults to "USD" and is only
     ever set by a scanned receipt, so a eurozone user typing a price stores USD — the third place
     with no locale source. Ruling: **a kitchen shops in one currency**, taken from the device
     locale at kitchen creation and stored on `Kitchen`; a receipt in another currency is an
     exception to flag, not to mix. Needs a migration.

  Unchanged and still the largest hole: **the snapshot suite does not exist.** Nothing in this wave
  was compiled or run — there is no Swift toolchain here.

---

> **2026-08-16 — SUPERSEDED AS THE THING TO EXECUTE by `TERMINAL_TICKET_GATE_AUTOPILOT.md`.**
> That ticket is the runnable queue for Waves 1–6 and the unattended operating mode. **This file
> stays open and stays required reading** — it holds the reasoning behind every ruling, every P1
> the critics found, and the wave-by-wave detail the autopilot ticket only summarises. Read this
> Log before fixing anything; it will usually tell you *why* the code is the way it is.


## Log

**2026-08-16 · terminal — closed as superseded.** Every task here ran under
TERMINAL_TICKET_GATE_AUTOPILOT (T0/T1): Core 52/52, Catalog 57/57 with 23/23 goldens against
the 461-item catalog, Data 38/38, conflict harness green in both orders and shuffled. Full
detail and every ruling lives in the AUTOPILOT Log.
