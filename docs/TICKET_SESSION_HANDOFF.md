# Ticket session handoff

Running summary of the cloud ↔ terminal ticket loop. One entry per ticket close; the ticket
files themselves hold the detail.

## Open

### TERMINAL_TICKET_WAVE789_GATE — opened 2026-08-16 by cloud · **terminal**

The gate for Prices, Surfaces and the barcode lookup. Waves 7, 8 and 9 are on main and have never
been compiled. Adds two Xcode targets (`BaggedWidget`, `WidgetTests`), two migrations (v4, v5), and
the quantity fix that changed every total in the app. Also carries the device-only questions the
test bed cannot reach — three processes on one SQLite file, a widget holding a stale pool through a
migration, a lock-screen tick producing a valid op — and the one `curl` that settles five
unverified facts about the Open Food Facts request shape.

### TERMINAL_TICKET_FOUNDER_BLOCKERS — opened 2026-08-16 by cloud · **founder, not an agent**

What no agent can do, and the real critical path. Headline: **Bagged has no Supabase project**, so
no live receipt scan has ever run end to end in this project's history — the differentiator is the
least-proven thing in the app. Plus the unowned domain (which the Open Food Facts User-Agent already
points at), Apple paperwork, a physical device, and the two research gates that predate the code —
the ten validation conversations and the 20-receipt seed audit that every `~` in the app rests on.

### TERMINAL_TICKET_GATE_AUTOPILOT — opened 2026-08-16 by cloud · **terminal, unattended**

**The terminal owns the entire gate for Waves 1–6. The cloud session continues Waves 7–9 on its
own branch and does NOT touch the gate.**

Everything in Waves 1–6 — four Swift packages, ~30 App files, twelve DesignKit components, the
whole capture flow, three Edge Functions — was written in a container with **no Swift toolchain**
and has **never been compiled**. The Mac is the first machine that can run any of it. There is
also no Xcode project yet, which is why nothing under `App/` has ever seen a compiler.

Run it as a continuous loop, not a task list: work the queue, never stop to ask, move past
blockers and come back, and when the queue is done, live in the regression loop (T9) re-running
everything against whatever cloud has pushed to main since.

Supersedes `TERMINAL_TICKET_WAVE1_GATE` **as the thing to execute** — that ticket stays as the
accumulated wave-by-wave reasoning, and its Log is required reading.

## Done

### TERMINAL_TICKET_V1_SCREENS — closed 2026-08-12 by terminal

All three parts, same day it was written:

- **Research:** `design/references/` is complete — 28/28 screens × top-3 Mobbin refs (84 images),
  README rewritten, pending table retired. Commit `8a6b7e3`.
- **Build:** all 28 surfaces + `01b List · full` (40 items) + 2 dark duplicates on page
  `138:978 · Bagged · Screens app current`, file `Lpx5Pdgvy3Gx8l5ZSDS0JH`. Nine sections:
  `F · Components` + Onboarding / List / Capture / Prices / Kitchen / Places / You / Widget.
  Commit `849a84e`, QA pass `994dc87`.
- **Both standing embarrassments are fixed on the new page:** 187 component instances in use
  (old pages had 0), and a new `F · Tokens` collection (17 colours × light/dark) with dark
  proven by **mode switching** on `01 List — dark` (`162:834`) and `10 Month / spend — dark`
  (`155:2149`) — not repainted hex.
- **QA:** every frame screenshotted individually; 4 rendering defects found and fixed (see the
  ticket's QA log entry). Banned-word scan over all text nodes: zero hits for
  shelf / pantry-inventory / recipe / `guessed`.
- **New datum for the standing density question:** `01b` at full res shows ~8 of 40 rows per
  screenful at F's default row height. The F-density-mode-vs-K decision can now be made from a
  real frame.

**What cloud should know before touching the file:**

1. Build on `138:978` only; `74:16` (old 59-screen spec) is still the quarry, untouched.
2. Colours on the new page bind to `F · Tokens` (`VariableCollectionId:144:2`, modes
   `144:0` light / `144:1` dark) — not to the older `Bagged color` collection (light-only,
   still used by `74:16`).
3. Components live in the `F · Components` section on `138:978`: `F/List row` (4 state
   variants, set `146:1331`), `F/Aisle header` `147:10`, `F/Total bar` `147:19`,
   `F/Input bar` `147:1313`, `F/Tab bar` `147:1325`, and 12 `F/Icon/*` monoline glyphs
   (strokes bound to `ink/primary` so they flip in dark mode).
4. Known gotchas recorded in the ticket log: `createAutoLayout` default-white fills,
   `setBoundVariableForPaint` stripping paint opacity, fonts are Inter + JetBrains Mono.
5. Icon backlog: no apple or barcode glyph yet (leaf/cart reused as stand-ins).

### TERMINAL_TICKET_FIGMA_CONCEPTS — closed 2026-07-26 by terminal

16 directions A→P (74 frames) in `joF6lVqRiHaWqc9v5q4kLg`; F · Hybrid chosen, K's density and
L/P organs earmarked. Superseded as a working surface by `138:978` above.
