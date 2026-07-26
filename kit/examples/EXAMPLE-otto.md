# 📎 EXAMPLE — the App Kit filled for "Otto"

> A condensed, filled instance of the whole kit (shared · frontend · backend) for the Otto recipe app,
> so you see how the templates connect. Full detail lives in the repo docs referenced below.

---

## shared/APP-CONFIG (excerpt)
- **App:** Otto — a warm recipe app (import/create, honest nutrition, plan the week). iOS · RN/Expo ·
  Express · Postgres/Supabase. Device width 393.
- **Source of truth:** colors `mobile/constants/colors.js` · tokens `mobile/constants/tokens.js` ·
  screens `mobile/app/` · components `mobile/components/` · assets `mobile/assets/` · backend
  `backend/src/` · screen-map `docs/SCREEN_MAP.md`.
- **Foundations:** accent `#C4562E`; warm neutrals; **fixed nutrition** protein `#3B82F6`/carbs
  `#F0A020`/fat `#8B5CF6`. Lora display + system body. Light-only.
- **Voice:** warm · capable · gently playful · trustworthy.
- **Honesty laws:** nutrition is always an **estimate + confidence** (never a daily-goal); **no fake
  ratings** (cook-then-rate on real UGC only); no personalization we can't compute.
- **Mascot:** Otto (river-otter chef, watercolor) — `docs/MASCOT.md`; state map Happy/Excited/Thinking/
  Sleepy/Sad/Proud.
- **IA:** 5-tab — Discover · Cookbook · ＋Add · Plan · Account. Gating: all shipped **ungated**.

## shared/CONTRACT (excerpt)
- **Features:** browse/search · save · import (URL/photo/video) · create/edit · cook mode · **nutrition
  (hero pipeline)** · plan · shopping list · membership (Otto Club) · ratings/comments (Phase 2, UGC).
- **Entities:** `recipes {id, userId, source, sourceUrl, sourceName, title, image, category, area,
  servings, ingredients[], steps[], nutrition(derived: parse→USDA→per-serving→cached+confidence),
  visibility}` · `favorites` · `plan_entries {day, recipeId, cooked}` · `seed_nutrition` (cache).
- **Endpoints:** `POST /api/import` · `POST|GET|PUT|DELETE /api/recipes[/:id]` ·
  `POST /api/recipes/:id/nutrition/recompute` · `GET /api/nutrition/seed/:mealId` · `*/api/favorites` ·
  `*/api/plan` · `DELETE /api/account`. Auth = Supabase JWT; every resource owner-scoped.
- **Pipelines:** **nutrition** = ingredient text → `parseIngredient` → USDA adapter → ÷ servings →
  cache on row / `seed_nutrition` → "estimate + confidence" framing.
- **Providers:** nutrition → **USDA FDC** (CC0; Edamam rejected — its licence forbids the cache this design needs); content → TheMealDB (swappable to Spoonacular).
- **Ingest:** URL (JSON-LD, SSRF-guarded, built) · photo OCR (planned) · video/IG share-extension (planned).
- **Gating:** enforced server-side; Otto Club via RevenueCat webhooks (planned).

## frontend/SCREEN-MAP (excerpt)
| Area | Screen | State | Data needs |
|---|---|---|---|
| Launch/Auth | Splash · Onboarding B1–B3 · Sign up/in | built | none / Supabase auth |
| Discover | Home · Search · Filter · By-ingredient | built / PLACEHOLDER | `RecipeSource` search |
| Recipe | Detail · Mise-en-place · Cook mode | built | `GET /recipes/:id` (+ nutrition) |
| Add | Add sheet · Import-URL · Scan/Video review · Manual · Edit | built / PLACEHOLDER | `POST /import`, `/recipes` |
| Cookbook | Home · Empty | built | `GET /recipes`, `/favorites` |
| Plan | Planner · Shopping list · Journal | built | `*/plan` |
| Account | You · Otto Club · Connected accts · Confirm | built / PLACEHOLDER | `DELETE /account`, entitlements |
| Supporting | Celebration · Error · Empty · Search-empty · Loading | built | none |
| Future | Ask Otto · Collections · Subscribed · Notifications | PLACEHOLDER | — |

→ Board built: `Otto — Master Board`, file key `mM0uWkHod9rL1Ff1VJ64Au` (6 pages).

## backend (excerpt)
- **Roadmap:** `docs/BACKEND_ROADMAP.md` (B0 foundations → B1 nutrition hero → B2+ create/ingest/social/IAP).
- **B0/B1 status:** foundations (logger/validate/rateLimits) + `RecipeSource`/`NutritionProvider`+USDA
  adapter + `parseIngredient` + `recipes.nutrition`/`seed_nutrition` + lifecycle + test-batch — built;
  live on USDA FDC (CC0, offline table — no keys, no runtime calls).

---

*This example maps 1:1 to the templates: APP-CONFIG → CONTRACT → (frontend SCREEN-MAP + board) ∥
(backend roadmap + spine). The two tracks meet only at CONTRACT.*
