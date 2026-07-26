# 📐 frontend/CONTEXT — the Master-Board methodology (reusable)

> The design track's *why/what*; `MASTER-PROMPT.md` is *how*. App specifics live in
> `../shared/APP-CONFIG.md`; data the screens need lives in `../shared/CONTRACT.md`. The frontend
> designs **against the contract** — it never assumes data the backend won't serve.

---

## 1. What the Master Board is
A **single Figma file that holds the entire product at a glance** — tokens, assets, components, app
map, wireframes, full-length screens, flows, and store/brand collateral. It is a **mirror of the app**
(token constants + screen-map + contract), kept 1:1 — not a sketchpad.

## 2. The 6-page anatomy (build in order — later pages reuse earlier ones)
1. **Design System** — Foundations (color, type, spacing, radius, overlay, motion spec) + Assets
   (logo/mascot, icons, illustration) + Components (every component as a real component *with variants*).
2. **App Map · Wireframes · Screens** — a route diagram grouped by the nav model; one **low-fi grey**
   wireframe per screen; the real hi-fi screens at device width, **full natural height (uncropped)**,
   grouped by flow; unbuilt-but-planned screens as **labeled placeholders**.
3. **User Flows** — the 3–6 critical journeys as thumbnail strips with connectors + decision points.
4. **App Store / Launch Kit** — store marketing screenshots (device mockup + headline) per hero moment.
5. **Brand & Voice** — wordmark lockups, the voice with real copy per state, "conventions we break," icon spec.
6. **Strategy Review (optional)** — vision · goals · research · design concepts · Q&A.
> Minimum viable = Pages 1–2. `APP-CONFIG.FE_PAGES` chooses which to build.

## 3. Craft laws (Figma mechanics — every page)
- **Figma Sections** carve each page into labeled zones. **Auto-layout** on everything.
- **Variables** for tokens · **text styles** for type · **components + variants** for states.
- **8-pt grid**; consistent gutters (≈64/160–240/120px). One device width; screens **never clipped**.
- Wireframes are **grey low-fi**; screens use the **real library** — kept visually distinct.
- Unbuilt screen → explicit `… — PLACEHOLDER`. Each page opens with a **cover/legend** frame.

## 4. Naming system
`DS/Color/*` · `DS/Type/*` · `DS/Spacing/*` · `DS/Radius/*` · `DS/Motion/*` · `Asset/<Group>/*` ·
`Comp/<Name>` (+ variant props) · `Screen/<Area>/<Name>` · `WF/<Name>` · `Map/Zone/*` + `Map/Node/*` ·
`Alternative version — <Name>` for anything superseded.

## 5. Design against the contract (the FE/BE seam)
- Each screen's content blocks should map to **real `CONTRACT.md` data** (an endpoint response / entity).
  If a screen needs data no endpoint provides, that's a **contract gap** — raise it, don't invent the data.
- Obey the **shared honesty law** (`APP-CONFIG §5`): state only true facts; **label estimates** with
  confidence; no fake ratings/counts/personalization. Deterministic + explainable > fake-smart.

## 6. Lessons baked in
- **Archive alternates on ONE page**, clearly labeled — provenance without doubling the primary pages.
- **Full-length beats viewport crops** — reviewers must see the whole scroll.
- **Placeholders keep the set honest and complete** — a labeled gap is information; a fake mockup is a lie.
- **Re-sync, don't rebuild** — reconcile the board to the app after changes.
- **Enumerate pages by node IDs** — some Figma surfaces under-list pages; keep a page index in the cover.

## 7. Definition of done → `CHECKLIST.md`.
