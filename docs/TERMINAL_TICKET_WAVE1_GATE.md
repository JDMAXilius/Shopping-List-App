# TERMINAL_TICKET_WAVE1_GATE — now covers Waves 1, 2 AND 3

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
