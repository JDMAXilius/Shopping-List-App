# TERMINAL_TICKET_V1_SCREENS

> STATUS: **open** — written by cloud 2026-08-12. Nobody has picked this up yet.

**Build the settled v1 — all 28 surfaces — as the new vision, on the empty page
`138:978 · Bagged · Screens app current`, in the shared file `Lpx5Pdgvy3Gx8l5ZSDS0JH`.**

The scope changed after the old Screens page was drawn: **recipes are cut, the whole Shelf/pantry
is cut, and the app is now list-first, shaped like Amazon Fresh's shopping list.** The old page
`74:16 · Bagged · Screens` (59 screens) is now the *quarry*, not the spec — take its best organs,
leave its dead ones.

## Read first, in this order (~20 min)

1. **`docs/V1_SCOPE.md`** — the build spec. 62 features, 19 screens + 8 sheets + 7 states +
   1 widget target, the cut table, the two overriding rules. **Everything you draw must match it.**
2. **`design/app/README.md` + the 28 PNGs next to it** — the old page's take on each of these
   surfaces, numbered `01`–`28`. This numbering is the project's screen index now; keep it.
3. **`design/references/README.md`** — per-screen top-3 shipped-app references, with a "why"
   for each. Filled folders sit next to it; use them while designing the matching screen.
4. `docs/DESIGN_HANDOFF.md` — tokens, fixed sample data, hard constraints. Direction **F ·
   Hybrid** is the chosen visual system (`docs/DIRECTION_RECOMMENDATION.md` says why, and which
   organ to take from A, K, L and P).
5. `docs/FIGMA_FILE_MAP.md` — what's where in the file, and the two standing embarrassments:
   **components with `instances: 0`** and **variables bound to nothing**.

## Tooling

Figma MCP. Load `/figma-use` before `use_figma` — mandatory. Everything goes on the one page
`138:978`. Do not touch `74:16` or `0:1` except to read.

---

## Part 1 — Understand what changed (nothing to produce)

The deltas between the old Screens page and `V1_SCOPE.md`, all of which are decisions, not
suggestions:

- **Navigation is three tabs + one action:** `List` · `Prices` · `You`, plus `+` for capture.
  The old page's 4-tab bar with Shelf leftmost is dead. Every frame with a tab bar changes.
- **No Shelf, no pantry, nowhere.** No shelf screens, no "put N things on the shelf" CTAs, no
  shelf copy in onboarding or sign-in. The old `A6 · Sign in` says *"so the shelf survives a lost
  phone"* — rewrite (e.g. *"so your kitchen survives a lost phone"*).
- **Capture result closes into the price book, not the shelf.** The old `C7` headline
  *"12 things went on the shelf"* becomes about prices: every line became a price observation.
- **Three price tiers only:** `$4.49` measured · `~$5.00` estimated · `—` no price yet.
  **The `guessed` tier is dropped.** The old list frame's footnote *"3 estimated · 1 guessed"*
  becomes *"3 estimated · 1 no price yet"*.
- **From Amazon Fresh, by name:** `COMPLETED (n)` collapsed at the bottom, `SUGGESTED FOR YOU`
  tappable grid, "Your usual" card. The old `D1` already has NO-PRICE-YET promoted to top and
  collapsing finished aisles — keep both, they're better than anything else on the page.
- **Paywall is $2.99/month AND $29.99/year**, 7-day trial, **3 free receipt scans before the
  paywall**. The old annual-only paywall frame is wrong. Siri and the widget are free-tier —
  don't show them behind Plus.
- **Item imagery: line-icon glyphs** (standing recommendation, two sessions arrived at it
  independently) — not emoji, not photos, never a blank.
- The two rules that override everything: **estimated and measured prices must never be
  confusable** (`~` + lighter weight + muted colour; `≈` on any total containing an estimate;
  estimates round hard), and **no streaks, badges or guilt mechanics.**

## Part 2 — Build the 28 surfaces on `138:978`

- Frames at **393 × 852**, named by the project index: `01 List` … `28 Widget` (the list in
  `design/app/README.md`). Group into sections by area: `Onboarding` (17, 18, 19) · `List`
  (01, 02, 03, 23, 24) · `Capture` (20, 21, 22, 04, 05, 06, 07, 27) · `Prices` (08, 09, 10) ·
  `Kitchen` (11, 25) · `Places` (12, 13) · `You` (14, 15, 16, 26) · `Widget` (28).
- **Direction F · Hybrid is the system**: warm paper ground, persimmon action, green semantic
  only, dotted-leader prices, bottom pill nav — per `DESIGN_HANDOFF.md` §6 — **adapted to the
  three-tab + `+` navigation.**
- **Fix the two embarrassments while you're there, on this page:**
  - Build the F components (list row with its four state variants, aisle header, total bar,
    input bar, nav pill) and **use instances everywhere** — a component library with
    `instances: 0` is a false claim about the file.
  - Bind colours to the **light/dark variable collection** and prove it: deliver `01 List` and
    `10 Month / spend` as dark-mode duplicates driven by mode switching, not repainted hex.
- **Sample data:** `DESIGN_HANDOFF.md` §5, unchanged, so frames compare honestly against every
  earlier round.
- **`01 List` must also be drawn at ~40 items** (a second frame, `01b List · full`). Every
  density judgement so far is inference from a 7-item mockup — this is a standing known issue.
- Use the per-screen references in `design/references/` as you go. They're ranked; the "why"
  column in its README says which organ to take.

## Part 3 — Finish what cloud couldn't

`design/references/` is 10 of 28 screens filled (7 complete, 3 partial). The pending table in
`design/references/README.md` has the exact `search_screens` query per remaining screen
(platform `ios`, limit 5, pick top 3, save as `design/references/NN-slug/RANK-app-pattern.webp`).
If this terminal has the Mobbin MCP, fill them and update that README's tables; if not, say so
in the Log and cloud will finish.

Top-ups needed: `05` (+1), `17` (+1), `18` (+2), `22` (+2).

## Done when

- [ ] All 28 frames exist on `138:978`, named by index, sectioned, at 393 × 852
- [ ] Zero shelf/pantry/recipe words or affordances anywhere on the page
- [ ] Tab bar is `List · Prices · You` + `+` on every full screen that shows chrome
- [ ] No `guessed` anywhere; three price tiers, never confusable; `≈` on estimated totals
- [ ] Paywall shows both prices, trial, and the 3-free-scans rule
- [ ] F components used as instances on every frame; light/dark via variables, proven on 01 + 10
- [ ] `01b List · full` exists at ~40 items
- [ ] `design/references/` filled or the gap declared in the Log
- [ ] Log entry appended below; push docs/reference changes to `main`

## Log — append only, never rewrite an earlier entry

- **2026-08-12 · cloud** — Ticket written. Page `138:978 · Bagged · Screens app current`
  confirmed to exist and be empty. `design/app/` (28 renders of the old page) and
  `design/references/` (10 of 28 filled) are pushed to `main`. The old page's renders still
  show shelf copy and 4 tabs — that's exactly what Part 2 replaces.
