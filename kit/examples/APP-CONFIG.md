# ⚙️ shared/APP-CONFIG — Otto (filled · reference implementation)

> Otto's filled instance of `APP-CONFIG.template.md`. Both tracks read this + `CONTRACT.md`.

## 1. Identity
- **App name:** Otto
- **One-liner:** A warm recipe app — import/create recipes, cook with honest nutrition, plan the week.
- **Platform / stack:** iOS · React Native/Expo (SDK ~53) · Express 5 · Drizzle · Postgres/Supabase.
- **Category:** Recipes / cooking. **Device width:** 393.

## 2. Source of truth (repo paths)
- Colors `mobile/constants/colors.js` · tokens `mobile/constants/tokens.js`
- Screens `mobile/app/` · components `mobile/components/` · assets `mobile/assets/`
- Backend `backend/src/` · screen-map `docs/SCREEN_MAP.md` · contract `shared/CONTRACT.md`

## 3. Foundations
- **Colors (base light — the only theme):** accent `#C4562E` · accentSoft `#F3D9CD` · secondary
  `#8A5A3B` · gold `#E8B04B` · bg `#FAF4EA` · surface `#FFFFFF` · surfaceWarm `#F3E9DA` · ink `#2A211B`
  · inkSoft `#6E6055` · border `#E8DECF` · gray `#B9A895` · destructive `#D64545`. **Fixed nutrition
  (never re-skin):** protein `#3B82F6` · carbs `#F0A020` · fat `#8B5CF6`.
- **Type:** display Lora700 30/34 · title Lora600 22/26 · body System 15/22 · label System600 13 ·
  caption System500 12 +0.5 UPPER · step System 24/32.
- **Spacing** 4·8·12·16·24·32 · **Radius** card20/sheet24/button14/pill999/mascot24 · **Overlay** warm-ink
  scrims (.35/.65/.45) · **Motion** springs gentle/snappy/pop(paw-pop)/sheet, sweep500/fade200.
- **Theming:** **light-only** (`ThemeContext` locked); board renders base/light.

## 4. Brand & voice
- **Wordmark:** "Otto" (Lora); lockups on cream + on black; badge = circle-crop bust.
- **Voice:** warm · capable · gently playful · trustworthy. Never hyperactive/babyish/sarcastic.
- **Mascot:** Otto — river-otter chef, watercolor/gouache storybook (`docs/MASCOT.md`, hero ref
  `5f74831c-…`). States: Happy=home · Excited=first-save · Thinking=search-empty · Sleepy=loading ·
  Sad=empty/offline · Proud=cook-finish/onboarding. One Otto per screen; never over food photos.

## 5. Honesty laws (shared — board + API obey)
- Nutrition is always an **estimate + confidence**, `null` when unknown; never a daily-goal contract.
- **No fake ratings/counts/personalization**; ratings only on real UGC (cook-then-rate), never on seed.
- State only true facts; derived values carry source + confidence.

## 6. Information architecture
- **Nav:** 5-tab — Discover · Cookbook · ＋Add (center) · Plan · Account.
- **Gating:** all premium features shipped **ungated** at launch (Otto Club IAP is a fast-follow).

## 7. Which tracks / pages to build
- **Frontend pages:** all 6 (Design System · App Map+Wireframes+Screens · User Flows · App Store Kit ·
  Brand & Voice · Strategy Review) — **built** (`Otto — Master Board`, file `mM0uWkHod9rL1Ff1VJ64Au`).
- **Backend phases:** B0 foundations + B1 nutrition (built; **live on USDA FDC**, no keys needed) → B2+
  per `docs/BACKEND_ROADMAP.md`.
