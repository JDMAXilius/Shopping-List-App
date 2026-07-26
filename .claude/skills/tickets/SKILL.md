---
name: tickets
description: Ticket board for the Otto cloud↔terminal handoff loop. Use to list open TERMINAL_TICKET_*.md tickets, pick one up, execute it, and write status back so the other session (Claude Code cloud or this terminal) can pull and continue. Invoke as /tickets [list|<name>|done <name>].
---

# Otto ticket board — cloud ↔ terminal loop

Tickets live in `docs/TERMINAL_TICKET_*.md` (+ `docs/TICKET_SESSION_HANDOFF.md` as the
running handoff). **Git is the channel**: the cloud session and this terminal both push to
`main`. Every action here starts with a sync and ends with a push — that IS the
"back and forward".

## Always first: sync

```bash
git fetch && git pull --rebase   # never skip; the other session pushes to main too
```

## `/tickets` or `/tickets list` — the board

1. Glob `docs/TERMINAL_TICKET_*.md` + `docs/TICKET_SESSION_HANDOFF.md`.
2. Status = derived, not stored: a ticket is **OPEN** if its "Done when" checklist has
   unchecked `- [ ]` boxes and no `> STATUS:` line says otherwise; **DONE** if all boxes
   checked or a `> STATUS: done` line exists; **IN PROGRESS** if a `> STATUS: in-progress`
   line exists.
3. Print a compact table: ticket, status, one-line gist, what it's blocked on (keys,
   device, dashboards — read the ticket header). Newest git mtime first.
4. Recommend the next pickup (respect stated ordering — e.g. NUTRITION_REFRESH gates
   NUTRITION_FRAMEWORK).

## `/tickets <name>` — pick up and execute

1. Sync (above). Read the ticket fully; read any companion docs it names.
2. Add directly under the ticket's H1:
   `> STATUS: in-progress — <side> <date> (<short sha>)` where side = `terminal` or `cloud`.
   Commit + push immediately (`tickets: pick up <name>`) so the other side sees the claim.
3. Execute per `otto-lead` rules (full auto, honesty laws, merged-is-not-live checks).
4. As tasks complete, check the ticket's own `- [ ]` boxes and append findings under a
   `## Log` section at the bottom of the ticket file (dated, short). Prompt-bug examples,
   counts, and verification output go there — that's what the cloud session reads.
5. Anything that needs the OTHER side (device check needed from cloud, prompt fix needed
   from terminal) gets a `> HANDOFF → cloud:` / `> HANDOFF → terminal:` line in the Log.
6. Commit small, push often. Trailer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## `/tickets done <name>` — close out

All boxes checked → change the STATUS line to `> STATUS: done — <side> <date>`, add the
closing Log entry, update `docs/REDESIGN_NOTES.md` if the ticket asked for it, push.

## Rules

- Never delete or rewrite ticket bodies — append. The ticket file is the shared thread.
- Blocked ≠ done: if a task needs keys/device/founder, leave the box unchecked and write
  the blocker in the Log.
- `TICKET_SESSION_HANDOFF.md` is the session-level summary; update its Open section only
  when a whole ticket closes.
