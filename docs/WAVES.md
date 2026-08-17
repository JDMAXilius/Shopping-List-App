# WAVES — the crew activation plan

The build order (`ARCHITECTURE.md` §11) executed as agent waves. A wave = a set of packets that
can run in parallel; a wave doesn't start until the previous wave's gate is green. The crew lives
in `.claude/agents/`; the lead skill is `.claude/skills/bagged-lead/`.

## Packet format (what a builder receives)

```
packet_id:      W3-P2
owner_path:     supabase/            # write scope — a diff outside it is rejected
contracts:      PRODUCT.md §N, ARCHITECTURE.md §N   # law
inputs:         files/docs the packet builds from
acceptance:     the exact checks the verifier will run
```

## Report-back (what every agent returns — one JSON, no prose)

```json
{ "packet_id": "", "status": "done|blocked", "files_touched": [],
  "tests_run": {"suite": "pass/fail counts"}, "gaps": [
  {"claim": "", "failure_scenario": "", "severity": "P1|P2|P3", "evidence": ""}] }
```

## The waves

| Wave | Packets | Agents | Gate to next wave |
|---|---|---|---|
| **1 · Engine** | Core models + `Merge` + op-log (`Packages/Core`) · resolver port JS→Swift (`Packages/Catalog`) | builder · **engine-porter** · critic (REFUTER on Merge) · verifier | Conflict harness green · all 23 golden resolver cases green |
| **2 · Data** | GRDB, `Repository`, `Observed`, migrations, `SyncEngine` vs fake transport (`Packages/Data`) | builder · critic · verifier | Sync tests green against fake transport · migration tests green |
| **3 · Backend** | schema + RLS + 3 edge functions (`supabase/`) | **security-builder** · critic (REFUTER: write the query that leaks kitchen B) · verifier | `rls.test.sql` proves isolation with two accounts · scan-receipt returns schema-valid JSON |
| **4 · DesignKit** | tokens, glyphs, sounds, the 7 components (`Packages/DesignKit`) | **ui-systems** · critic · verifier | Snapshots match Figma `138:978` · one style only · contrast 4.5:1 verified on grey estimates |
| **5 · List** | ListScreen + store + add/detail/aisle/switcher (`App/Features/List`) | builder ×2 · critic · verifier | Add ≤2 taps ≤2s · three price tiers never confusable · 01/01b parity with Figma |
| **6 · Capture** | camera→review→resolver→result + enter-by-hand + barcode (`App/Features/Capture`) | builder ×2 · critic · verifier | Nothing commits unreviewed · >3× estimate flagged · offline path works |
| **7 · Prices** | price book, history, month (`App/Features/Prices`) | builder · critic · verifier | 90-day decay renders · measured/estimated split shown |
| **8 · Surfaces** | Widget + full `reminders` intents cluster | builder · critic · verifier | Lock-screen tick produces a valid op · cluster builds (all-or-nothing) |
| **9 · Kitchen · Places · Paywall** | invite/join/realtime · geofence · paywall | builder ×2 · security-builder (join flow) · critic · verifier | Guest joins with no account ≤3s · location never leaves device · paywall matches PRODUCT §6 |
| **10 · The debts** | 403 quarantine so a refused op cannot wedge the queue (`Packages/Data`) · entitlement that reaches a device without a scan (`App`) | builder ×2 · critic (REFUTER on both) · verifier | A refused op never blocks a later one AND is never silently lost · someone who has paid is never shown a sales card after one launch |

**Wave 10 is not new features.** Every packet in it is a bug this project found by arguing with
itself and then wrote down instead of fixing — see `TERMINAL_TICKET_FOUNDER_BLOCKERS` §9 and the
"two known holes" in `TERMINAL_TICKET_WAVE789_GATE`. Two more are queued behind it and are NOT in
this wave because they collide with W10-P1's owner_path or need server work: the kitchen-blind
local projection (a guest's own pre-join items mix into the shared list) and in-app account
deletion (App Review 5.1.1(v), which needs a `Repository` wipe **and** a server-side delete).

Rules: one packet, one owner_path, no overlap inside a wave · every P1 finding blocks the gate ·
verifier runs `swift build && swift test` per package (Xcode UI targets from wave 5, plus
`supabase test` for wave 3) · waves 1–3 need no signing, no name, no Apple paperwork.

Human gates in parallel (not agent work): the ten conversations before wave 5 spends UI effort ·
Paid Apps Agreement before wave 9's paywall · domain/trademark anytime.
