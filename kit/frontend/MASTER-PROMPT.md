# 🧩 frontend/MASTER-PROMPT — build the Master Board (reusable)

> Hand to an agent with **Figma MCP write access**, together with `../shared/APP-CONFIG.md`,
> `../shared/CONTRACT.md`, and `SCREEN-MAP.md`. Builds the 6-page board for `{{APP_NAME}}` by mirroring
> the app's real tokens + screens. Reads `CONTEXT.md` (method) and `CHECKLIST.md` (done).

---

## ROLE
You are the design engineer building **`{{APP_NAME}}` — Master Board**: one Figma file that holds the
entire app at a glance. Mirror the app's code (tokens + screens) and design **against the contract** —
never invent data or screens; unbuilt screens are labeled placeholders.

## BEFORE YOU START
1. **Read** `CONTEXT.md`, `../shared/APP-CONFIG.md`, `../shared/CONTRACT.md`, `SCREEN-MAP.md`, and the
   source of truth (`{{PATH_COLORS}}`, `{{PATH_TOKENS}}`, `{{PATH_COMPONENTS}}`, `{{PATH_ASSETS}}`).
2. **Load the Figma skills** (MANDATORY): `/figma-use` before `use_figma`; `/figma-generate-library`
   (Design System); `/figma-generate-design` (screens); `generate_diagram` / `/figma-use-figjam`
   (app map + flows).
3. **Upload real assets** (`upload_assets`) from `{{PATH_ASSETS}}` — never redraw logos/mascot/icons.
4. **Target:** create `{{APP_NAME}} — Master Board` (or file key `{{FILE_KEY}}`). Build only the pages in `{{FE_PAGES}}`.

## GLOBAL CRAFT RULES (CONTEXT §3–4)
Figma Sections · auto-layout everywhere · 8-pt grid · Variables (tokens) · text styles (type) ·
components with variants (states) · screens at `{{DEVICE_WIDTH}}` wide **full length** · namespace every
layer · a cover/legend per page · obey the honesty law `{{HONESTY_LAWS}}` · render `{{THEME_MODE}}` only.

## BUILD ORDER
- **P1 Design System:** Variables + swatch cards for `{{COLOR_TOKENS}}` (mark fixed/functional); text-style
  specimens for `{{TYPE_SCALE}}` (real copy); spacing/radius/overlay; a **motion spec card** for `{{MOTION}}`.
  Assets Section: every asset uploaded + labeled (mascot states captioned with their app-state). Components
  Section: **every** component in `{{PATH_COMPONENTS}}` as a component **with variants**.
- **P2 App Map · Wireframes · Screens:** app map grouped by `{{NAV_MODEL}}`/`{{TABS}}` (+ entry/auth);
  low-fi grey wireframe per screen in `SCREEN-MAP.md`; hi-fi full-length screens built from each screen's
  content blocks — and label each screen with the **contract data it consumes** (from `SCREEN-MAP`'s
  data-needs column). Unbuilt → `— PLACEHOLDER`. Superseded → one `Alternates` section.
- **P3 User Flows:** each journey in `{{FLOWS}}` as a thumbnail strip (thumbs + arrows + decision chips).
- **P4 App Store / Launch Kit:** store shots (device + headline) per hero moment (from `CONTRACT.FEATURES`).
- **P5 Brand & Voice:** `{{WORDMARK}}` lockups (light+dark), `{{VOICE}}` with **real copy per state**,
  broken-conventions, icon spec.
- **P6 Strategy Review (optional):** vision · goals · research · design concepts · Q&A.

## FINISH
- Add a **page index** to P1's cover. Self-check against `CHECKLIST.md`; fix failures. **Share the file
  link back.** If Figma writes need approval, complete them in an authorized session.
- If any screen needs data no `CONTRACT.md` endpoint provides, **flag the contract gap** (don't invent it).

## KEEP IT ALIVE
The board is a **mirror** — when tokens/screens/contract change, **re-run this prompt to reconcile 1:1**.
Correct the board to match code; if the board reveals a code/contract problem, raise it.
