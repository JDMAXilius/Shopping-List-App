# Otto Rebuild — Orchestration Plan

Status: **approved blueprint, execution not started** (founder sessions 2026-07-21).
The target architecture is `docs/FRAMEWORK.md`. This doc is the **plan**: goals,
phases, agents, branches, and the cloud↔terminal split.

Companion docs — read the one you need, not all four:

| Doc | Role |
|---|---|
| `REBUILD_WORKFLOW.md` (this) | The plan — amended only at gates |
| `REBUILD_PACKETS.md` | The law agents run under — packet + message schemas |
| `REBUILD_STATE.md` | Living dashboard — the shared memory both sessions sync on |
| `TESTING.md` | The testing pyramid, journey scripts, credentials policy |

---

## 1. Main goal and guardrails

**Rebuild Otto on the target framework (~110 files) with all existing behavior
pinned green, while the old app keeps working untouched until cutover.**

Non-negotiable guardrails:

- The old app on `main` stays buildable/shippable the entire time.
- Behavior is pinned by the existing test suites (backend 101, mobile 53 —
  golden nutrition + macro-split included). A port that changes behavior fails,
  full stop.
- The honesty law carries over verbatim: null beats a guess, estimates are
  labelled, no fabricated numbers.
- Correctness work is never what gets cut under budget pressure (see §7).

## 2. Goal tree

```
MAIN GOAL
├── SG1  Contracts signed off              ← everything blocks on this
│    T0.5 crew packet (7 agent definitions + critic panel review)
│    T1.1 schema+types · T1.2 engine API · T1.3 feature/ui contracts · T1.4 critic review
├── SG2  Engine ported, behavior-identical
│    T2.1 parse · T2.2 lookup · T2.3 compute+guards · T2.4 one data copy · T2.5 suites green
├── SG3  Platform track (parallel with SG2)
│    T3.1 RLS + attack tests · T3.2 five edge functions · T3.3 shared/ui + theme
├── SG4  Features (blocks on SG1–SG3)
│    T4.1–T4.9 one packet per features/* folder
├── SG5  Integration
│    T5.1 thin routes + providers + boot · T5.2 L3 journey smoke
└── SG6  Quality convergence
     T6.x review swarm → 3-vote verify → fix → repeat until 2 dry rounds
```

Atomicity rule (when something is a task, not a sub-goal): **(a)** one owner
directory, **(b)** testable acceptance criterion, **(c)** all inputs already
exist as contracts. Fails (c) → it's a dependency, not a task.

## 3. Phase DAG and gates

```mermaid
flowchart LR
    M0[M0 Contracts<br/>FOUNDER signs off] --> E[SG2 Engine port]
    M0 --> P[SG3 Platform:<br/>RLS · functions · ui]
    E -->|golden + macro green| J{join}
    P -->|critics pass| J
    J --> F[SG4 Feature fan-out ×9<br/>worktrees, 6–8 concurrent]
    F --> I[SG5 Integration + L3 smoke]
    I --> R[SG6 Review loop<br/>until 2 dry rounds]
    R --> M4[M4 Device QA → PR → main<br/>FOUNDER signs off]
```

**Kick-off pattern: every gate is an artifact validation, never a schedule.**
An agent spawns only when its packet's `kickoff:` list checks green (files
exist on `rebuild/v2`, named checks pass). No artifact, no agent.

| Gate | Exit condition | Checked by |
|---|---|---|
| M0 Contracts | founder approves ~6 contract files | human |
| M1 Engine | golden + macro suites green on the TS port | automatic |
| M2 Platform | RLS survives 3 critics; functions deploy; ui renders | automatic + critics |
| M3 Features | every packet accepted (schema → verify → merge) | automatic |
| M4 Converged | review loop dry ×2 → terminal device QA → founder review | human |

## 4. Agent model

### 4.1 The three layers

An agent is a **file**, so the crew is code — versioned on `rebuild/v2`,
reviewed and diffed like anything else.

```
DEFINITIONS  .claude/agents/*.md — durable "classes": identity, doctrine,
             tool permissions, model/effort. 7 of them (§4.2).
     │  spawned by
WORKFLOW SCRIPTS  the phase orchestrations — pick a definition, inject a packet
     │  producing
INSTANCES  ephemeral — one per packet, in its own worktree; returns one
           structured report-back, then disappears.
```

Instances are disposable; **definitions accumulate wisdom**. A failure pattern
becomes a one-line doctrine commit that every future instance inherits.

### 4.2 The crew — 7 definitions (4 archetypes + 3 specialists)

```mermaid
flowchart TD
    O[MANAGER — cloud session<br/>owns goal tree · only merger · scouts inline · never writes feature code]
    O --> W1[Phase workflows<br/>deterministic scripts]
    W1 --> B[builder + 3 specialist builders<br/>write in worktrees]
    W1 --> V[verifier<br/>tsc · tests · L3 journeys · NO write]
    W1 --> C[critic<br/>judge + refuter · NO write]
    W1 --> S[scout<br/>read-only research]
```

| Definition | Role | Tools | Model / effort |
|---|---|---|---|
| **builder** | writes one packet in its worktree | Read · Edit · Write · Bash · Grep · Glob | default / low–med |
| **verifier** | runs tsc, tests, L3 journeys; reports only | Read · Bash — **no Write** | cheap / low |
| **critic** | adversarial — scores competing designs AND refutes findings (mode set by packet) | Read · Bash — **no Write** | default / high |
| **scout** | reads old code, feeds packets | Read · Grep · Glob | cheap / low |
| **engine-porter** | specialist builder: nutrition-engine doctrine | builder tools | default / med |
| **security-builder** | specialist builder: RLS / SSRF / auth | builder tools | default / high |
| **ui-systems** | specialist builder: `shared/ui` + tokens | builder tools | default / med |

**Tools ARE the org chart.** The rules in REBUILD_PACKETS.md — builders never
verify, verifiers never fix, critics never touch code — are enforced by
*capability*, not by asking: a verifier physically has no Write tool, so
"quietly patched the test to pass" is impossible, not discouraged. Same move
as RLS replacing auth middleware — push the rule from prompt-space into
permission-space.

### 4.3 Decisions on the record (do not re-litigate)

- **critic = judge + refuter merged.** Same shape (read-only, adversarial,
  high-effort); they differ only in mode. A port-driven rebuild has little to
  "judge" and much to "refute" — one definition covers both, one fewer file.
- **Specialists are definitions, not packet-doctrine.** Their doctrine (engine
  honesty law + no runtime LLM; RLS attack patterns; semantic-ink tokens) is
  where a mistake is *silent and confident* — so it lives behind a reviewed
  fence (a definition inherited forever), never a sticky note (doctrine retyped
  per packet, which decays).
- **REJECTED: splitting agents by discipline** (backend / frontend / UI-UX /
  API). That axis cuts every feature across contexts that cannot talk, forcing
  4 agents to agree on one feature's contract mid-flight — which recreates the
  card-vs-detail drift bug this rebuild exists to kill. The correct axis is
  ownership by **folder** (§4.4): API = owned edge-function folders,
  UI/UX = the owned `shared/ui` folder, DB = the owned migrations folder —
  concerns as owned folders with doctrine, never as disciplines.
- **scout runs inline in the manager** for now (~30 packets). Promoted to its
  own running definition only if old-code reading gets heavy — cheap to add,
  wasteful to build early.
- **NOT in the crew:** the manager (that's this cloud session, not a file); any
  standing "fixer" (fixing is a builder with a bug-shaped packet); any
  free-roaming "improver" (nothing runs without a packet).

### 4.4 Folder ownership = write scope

One folder, one owner. The specialist/archetype that owns each:

| Folder | Owned by | Kick-off inputs |
|---|---|---|
| `supabase/migrations/` | security-builder | FRAMEWORK.md (M0 start) |
| `src/types/` | generated — no agent | schema merged |
| `features/nutrition/engine/` | engine-porter | engine API contract |
| `src/shared/ui/` + `theme/` | ui-systems | token contract |
| `supabase/functions/*` | security-builder (+ builder) | schema + zod contracts |
| `features/*` (9) | builder (one per folder) | types + engine + ui green |
| `app/` + layout | builder (integration) | all features merged |
| cross-cutting (read-only) | critic swarm | M3 passed |

M0 addendum (critic panel finding — every folder a contract references
needs an owner; amended at the M0 gate):

| Folder | Owned by |
|---|---|
| root config (`package.json`, tsconfig, eslint, CI) | builder (integration) — via packet only |
| `src/shared/supabase/` + `src/shared/lib/` | ui-systems (shared primitives fence) |
| `src/types/ids.ts` (branded IDs; database.ts stays generated) | engine-porter (first consumer, M1 packet) |
| `tools/` (USDA pipeline — sole writer of engine data JSONs) | engine-porter |
| `assets/` | ui-systems |
| `e2e/journeys/<feature>.ts` + `e2e/fixtures/<feature>.json` | that feature's packet (feature-module.md) |
| `e2e/` shared (smoke.ts, harness) | builder (integration) |

A packet's `owner_path` must equal a row of this table (or a boundary in
feature-module.md §Owner-path boundaries). Broader paths (`src/`) are
invalid — rejected before spawn. Nested-folder rule: a parent-folder packet
NEVER implicitly owns a child with its own row (e.g. `features/nutrition/`
excludes `engine/`).

Ownership rules — enforced mechanically at merge, not by honor:

1. Write scope = your folder. Read scope = contracts + `src/types/` + old code.
   A diff outside the packet's owner path is rejected.
2. Shared folders have one owner. Needing a change there = file a
   `contract_gap` (see REBUILD_PACKETS.md), never edit it yourself.
3. The manager is the only merger. Agents never merge.

### 4.5 Crew bootstrap

The crew is built by the same machinery it will run. Added to SG1 as **T0.5
"crew packet"**: write the 7 definitions → a critic panel tries to find the
prompt-hole in each ("what packet makes this builder write outside its
owner_path?") → survivors merge to `rebuild/v2`. Thereafter crew changes are
ordinary reviewed commits, so cloud and terminal always spawn the identical
crew at the same commit.

## 5. Concurrency

- Engine hard cap: `min(16, cores−2)` per workflow; excess queues.
- **Writers: max 6–8 concurrent** — binding constraint is merge-conflict
  surface, not compute. One writer per directory, each in its own worktree.
- Readers/verifiers/critics: up to 10–16.
- **Minimum pairing: never a builder without its verifier.** An unverified
  green checkmark is how confidently-wrong code lands.
- Granularity floor: the feature folder. Never agent-per-file.
- No free-form agent chat — artifacts and structured messages only
  (REBUILD_PACKETS.md). Git is the message bus.

## 6. Branch strategy

```mermaid
gitGraph
    commit id: "v1 today"
    branch v1-legacy
    commit id: "frozen + tag v1.0-legacy"
    checkout main
    branch rebuild/v2
    commit id: "M0 contracts"
    branch rebuild/engine
    commit id: "port"
    checkout rebuild/v2
    merge rebuild/engine id: "M1 green"
    commit id: "M2 M3 M4 ..."
    commit id: "cutover: delete mobile/ backend/"
    checkout main
    merge rebuild/v2 id: "M4 PR — founder approved"
```

- **`v1-legacy`** — frozen snapshot of today's app + tag `v1.0-legacy`. Never
  advances. The old project is one checkout away, forever.
- **`rebuild/v2`** — long-lived integration branch. All gates live here; it may
  be red mid-flight without touching main. **Old code stays present on this
  branch during the port** — agents need the old source and its tests in the
  same tree to pin behavior. The final pre-PR commit deletes `mobile/` +
  `backend/` so main's history shows one clean cutover.
- **`rebuild/<task>`** — one short-lived branch per packet (this IS the agent's
  worktree). Merged by the manager on verifier sign-off, then deleted.
- **`main`** — the working v1 app throughout (TestFlight keeps building from
  it). Receives exactly one PR, at M4, after founder approval.

## 7. Cloud ↔ terminal session split

**Cloud = rebuild manager + agent fleet. Terminal = hardware, secrets, final eyes.**
(~80% cloud / 20% terminal by volume; the terminal's 20% cannot be faked.)

| Capability | Cloud | Terminal |
|---|---|---|
| Multi-agent Workflow engine, hours-long runs | ✅ only | — |
| iOS simulator, device, visual verification | — | ✅ only |
| Secrets: USDA key, Supabase login, .env, EAS/TestFlight | — | ✅ only |
| Figma writes | — | ✅ |
| Browser (L3) testing | ✅ headless Playwright | ✅ Chrome MCP interactive |
| Code, git, node tests, tsc | ✅ | ✅ |

Per milestone: cloud runs M0–M3 end to end; terminal executes M2's real-project
steps (supabase link/migrations, `fix-table-identities.mjs` with the USDA key),
smoke-runs checkpoints on simulator during M3, and owns the M4 device QA +
EAS build. **Nothing merges to main on cloud's say-so alone.**

Protocol (the existing ticket pattern, tightened):

- Structured tickets only: kick-off condition, exact commands, expected output,
  and a **Report-back** section the terminal fills in. No cross-session chat.
- Terminal always `git pull --rebase` before acting; cloud never assumes a
  ticket ran until the report-back commit exists.
- Done tickets move to `docs/archive/`.
- `REBUILD_STATE.md` is read first, updated last, by both sessions — the
  manager is its only writer; terminal report-backs get folded in.
- **One manager.** The cloud session owns the goal tree for the rebuild; the
  terminal executes tickets and reports back. Disagreement goes in the
  report-back, and the manager re-decomposes. (Day-to-day v1 work keeps the
  existing terminal-lead convention; revisit after cutover.)

## 8. Re-decomposition triggers

The plan re-plans at defined points, not continuously:

1. **A task fails verification twice** → never a third retry; the manager
   splits the task or fixes its packet. Twice-failed = bad decomposition, not
   a bad agent.
2. **`contract_gap` filed** → builder stops improvising; manager amends the
   contract file, re-issues affected packets.
3. **Budget pressure** → SG6 shrinks first (fewer lenses per round). SG4
   correctness work is never cut.

## 9. Human touchpoints

Exactly three, plus escalations: **M0** (read ~6 contract files), **M4**
(device QA + final PR), and any `AskUserQuestion` an agent escalates through
the manager. Everything between runs autonomously behind automatic gates.

## 10. Open decisions — ALL RESOLVED by founder 2026-07-21 (REBUILD_STATE.md)

1. Anon key committed in `.env.development` — **YES**. 2. Authed E2E
terminal-only — **YES**. 3. SG4 — **two waves of 4–5**. 4. `v1-legacy`
README — **YES** (done).
