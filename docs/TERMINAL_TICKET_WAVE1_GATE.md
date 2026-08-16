# TERMINAL_TICKET_WAVE1_GATE

> STATUS: open — written by cloud 2026-08-16. Blocked in cloud: the container's proxy denies
> download.swift.org, so no Swift toolchain there. This machine has one.

**Run the Wave 1 gate (`docs/WAVES.md`): build + test `Packages/Core` and `Packages/Catalog`,
fix what's mechanical, report what isn't.**

The packages were written by the crew in the cloud session, critic-reviewed, but **never
compiled** — expect a handful of mechanical compile errors (that's normal for unexecuted code),
not design problems. The design contracts are law; don't redesign while fixing.

## Do

```bash
git fetch && git pull --rebase
cd Packages/Core    && swift build && swift test
cd ../Catalog       && swift build && swift test
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
- [ ] Log entry appended; pushed to main

## Log — append only

- **2026-08-16 · cloud** — Wave 1 built by builder (W1-P1 Core) + engine-porter (W1-P2 Catalog);
  critic REFUTER pass done in cloud (see WAVES log/commits). Gate handed here.
