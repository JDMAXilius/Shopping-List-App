# 🗺️ frontend/SCREEN-MAP (template) — every screen, its content, its data

> Copy to `SCREEN-MAP.md` and fill. Drives Page 2 (wireframes + full-length screens). The **data
> needs** column ties each screen to `../shared/CONTRACT.md` — so the board can't design a screen the
> backend won't serve. Group by area; mark unbuilt screens as PLACEHOLDER. See `../EXAMPLE-otto.md`.

## Legend
`built` = shipping · `PLACEHOLDER` = should exist, not built (renders as a labeled empty frame).

## Screen inventory
For each screen fill a row:

| Area | Screen | State | Content blocks (top → bottom) | Components used | Data needs (CONTRACT) |
|---|---|---|---|---|---|
| Launch/Auth | {{name}} | built/PLACEHOLDER | {{block · block · block}} | {{Comp/… }} | {{endpoint or entity, or "none"}} |
| … | … | … | … | … | … |

**Areas to cover (adapt to the app):**
- **Launch / Auth** — splash, onboarding, sign-up/in.
- **<Core area(s)>** — the app's primary destinations (one section per tab).
- **Detail / task surfaces** — item detail, the focused-task mode.
- **Create / input** — any add/create/import/edit flows.
- **Account** — profile, membership/paywall, settings, confirm dialogs.
- **Supporting states** — celebration, error/offline, empty, search-empty, loading.
- **Future** — planned-but-later screens (all PLACEHOLDER).

## Rules
- Every screen is **built** or **PLACEHOLDER** — no fake mockups.
- **Content blocks** are the real top-to-bottom sections (drives the full-length frame height).
- **Data needs** must reference a real `CONTRACT.md` endpoint/entity, or say "none" (static/marketing).
  A screen that needs data no endpoint provides = a **contract gap** to raise, not invent.
- Note the **honesty flags** on any block that shows derived/estimated data (must be labeled).

## Tallest-screen watch
List the long scrollers (detail, paywall, account, planner) so the board author sizes their frames for
full content — these are the ones viewport-crops hide.
