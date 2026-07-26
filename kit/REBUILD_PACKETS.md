# Otto Rebuild — Work Packets & Structured Messages

The **bridge layer**: how work reaches agents and how results come back.
Agents communicate only through the artifacts and schemas below — no
free-form chat between agents or sessions. Malformed output never reaches
the tree: it is caught, self-corrected, or rejected before merge
("validate before compile").

Companion to `REBUILD_WORKFLOW.md` (the plan). This file is write-once law;
if it needs changing mid-rebuild, that change is itself a gate decision.

---

## 1. The work packet (input to every builder)

A packet is not launched until the manager validates it complete — an agent
with an ambiguous packet produces plausible garbage fast. Template:

```markdown
# PACKET <id> — <one-line title>
owner_path:   src/features/planner/          # the ONLY writable directory
branch:       rebuild/feat-planner           # = the agent's worktree

## Kick-off (all must validate before spawn)
- file exists on rebuild/v2: src/types/database.ts
- file exists on rebuild/v2: docs/contracts/feature-module.md
- check green: engine suite (M1)

## Inputs (read-only)
- contracts: <paths>
- old source being ported: mobile/lib/week.js, mobile/app/(tabs)/plan.jsx
- fixtures: e2e/fixtures/planner.json

## Acceptance (definition of done — ALL must pass)
- tsc + eslint clean
- unit tests for <named behaviors> pass
- L3 journey `e2e/journeys/planner.ts` green, zero console errors
- diff touches owner_path only

## Don't touch
- src/shared/**  (file contract_gap instead)
- any *.json under features/nutrition/engine/data/

## Report-back
(agent fills per §2)
```

## 2. Report-back (output of every agent — schema-validated)

```json
{
  "packet_id": "T4.5",
  "status": "done | blocked | contract_gap",
  "files_touched": ["src/features/planner/PlanScreen.tsx", "..."],
  "tests_run": [{ "suite": "planner.unit", "pass": 14, "fail": 0 }],
  "journey": { "script": "e2e/journeys/planner.ts", "console_errors": [], "screenshots": ["..."] },
  "gaps": ["anything the agent knows it did not cover — silence is lying"],
  "contract_gap": null
}
```

Rules: every field required; `gaps` may be empty but must be present;
schema failure triggers one automatic self-correction retry, then the packet
returns to the manager as failed (counts toward the two-failure limit).

M0 amendments (critic panel): `journey` is `null` for packets with no
screen (engine, migrations, tooling) — null is schema-valid there, absent
is not. `gaps` entries may be strings OR structured objects (critic
findings `{claim, failure_scenario, severity, evidence}`, scout reports) —
validators accept both. `owner_path` must match the WORKFLOW §4.4 ownership
table (incl. M0 addendum) or a feature-module.md boundary; the manager's
pre-spawn validation rejects broader paths.

## 3. `contract_gap` (the cycle-breaker)

When a builder discovers its contract is missing something (e.g. planner
needs a Button variant `shared/ui` doesn't export):

```json
{
  "contract": "docs/contracts/ui-components.md",
  "need": "Button variant='ghost-destructive'",
  "why": "plan-entry delete affordance per SCREEN_MAP",
  "proposed": "add variant prop value; no API break"
}
```

Flow: builder **stops that thread of work** (finishes what's unblocked) →
manager amends the contract file → owner agent of the shared folder
implements → dependent packets re-issued. Builders NEVER edit outside
`owner_path` to unblock themselves — that discipline is what keeps the
one-copy-of-everything property that killed the card-vs-detail bug class.

## 4. The validation ladder (every packet climbs all rungs)

| Rung | Check | On failure |
|---|---|---|
| V0 Schema | report-back parses against §2 | 1 auto-retry (self-correction), then fail |
| V1 Mechanical | separate verifier agent runs tsc, lint, unit suites, L3 journey **in the packet's worktree** | fail → back to builder (attempt 2 of 2) |
| V2 Adversarial | only for security/design-shaped packets: 3 refuters prompted to BREAK it (e.g. "write a query that leaks another user's rows") | survives <2 of 3 → back to builder |
| V3 Merge | manager checks diff ⊆ owner_path, fast-forwards into rebuild/v2, updates REBUILD_STATE.md | conflict → rebase in worktree, re-verify V1 |

Builders never verify their own work. Verifiers never fix — they report.

## 5. Failure & recovery rules

- **Two failures on the same packet → re-decompose.** Never a third retry
  (twice-failed = bad packet, not bad agent).
- Every agent result is nullable; workflows filter nulls and re-queue rather
  than crash the run.
- Runs are journaled and resumable — a killed run re-executes only changes.
- **No silent caps:** any bounded coverage (top-N findings, skipped journey,
  sampled files) is logged in `gaps` or the run log. Silent truncation reads
  as "covered everything" when it didn't.
- Escalation to human: only via the manager, only when a decision is
  genuinely the founder's (scope change, contract dispute the judges split
  on, anything touching money/accounts).

## 6. Ticket variant (cloud ↔ terminal)

Terminal tickets are packets with a human executor. Same shape, two changes:
`owner_path` becomes the real-world action list (commands to run, things to
click), and Report-back is written by hand into the ticket file and
committed. The manager treats a ticket without a report-back commit as
not-run — regardless of what anyone remembers.
