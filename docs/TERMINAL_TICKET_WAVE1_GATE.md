# TERMINAL_TICKET_WAVE1_GATE — now covers Waves 1 AND 2

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
- [ ] `swift test` green on Data — incl. incremental==rebuild equivalence, the
      crash-before-mark re-push test, and the deterministic fake-clock backoff tests
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
