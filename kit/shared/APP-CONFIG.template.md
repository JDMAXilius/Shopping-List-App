# ⚙️ shared/APP-CONFIG (template) — the app's identity (both tracks read this)

> Copy to `APP-CONFIG.md`, replace every `{{…}}` from the app's real code + brand. Frontend and
> backend both consume this. Pair it with `CONTRACT.md` (the data/API seam). See `../EXAMPLE-otto.md`.

## 1. Identity
- **App name:** {{APP_NAME}}
- **One-liner:** {{TAGLINE}}
- **Platform / stack:** {{PLATFORM}}  *(e.g. iOS · React Native/Expo · Express · Postgres/Supabase)*
- **Category / niche:** {{CATEGORY}}
- **Device frame width (screens):** {{DEVICE_WIDTH}}  *(default 393)*

## 2. Source of truth (repo paths — both tracks mirror these; never invent)
- **Color tokens:** {{PATH_COLORS}}
- **Non-color tokens:** {{PATH_TOKENS}}
- **Frontend screens dir:** {{PATH_SCREENS}}
- **Components dir:** {{PATH_COMPONENTS}}
- **Assets dir:** {{PATH_ASSETS}}
- **Backend source dir:** {{PATH_BACKEND}}
- **Screen map doc:** {{PATH_SCREENMAP}} · **Contract doc:** `shared/CONTRACT.md`

## 3. Foundations (from the token files — used by the design board)
- **Color tokens** (name · hex · usage; mark fixed/functional ones): {{COLOR_TOKENS}}
- **Type scale:** {{TYPE_SCALE}}
- **Spacing:** {{SPACING}} · **Radius:** {{RADIUS}} · **Overlay:** {{OVERLAY}} · **Motion:** {{MOTION}}
- **Theming:** {{THEME_MODE}}

## 4. Brand & voice (used by both — UI copy + API error copy should share one voice)
- **Wordmark / logo:** {{WORDMARK}}
- **Voice** (adjectives + do/don't): {{VOICE}}
- **Mascot / illustration** (or "none"): {{MASCOT}}  *(name, bible path, state→placement map)*

## 5. Honesty laws (THE shared law — both the board and the API must obey)
What the product may NOT imply (translate to this app's domain):
{{HONESTY_LAWS}}
*(e.g. "no invented ratings/counts/personalization; derived/estimated values are labeled as
estimates with a confidence; state only true facts.")*

## 6. Information architecture (shared)
- **Navigation model:** {{NAV_MODEL}}
- **Primary destinations / tabs:** {{TABS}}
- **Gating (free vs paid, or ungated):** {{GATING}}

## 7. Which tracks / pages to build
- **Frontend pages:** {{FE_PAGES}}  *(default all 6 board pages — see frontend/CONTEXT.md)*
- **Backend phases:** {{BE_PHASES}}  *(default B0 foundations + the hero pipeline — see backend/CONTEXT.md)*
