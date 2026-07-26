# 🔌 shared/CONTRACT — Otto (filled · reference implementation)

> This is **Otto's real contract**, derived from the running code (`backend/src/server.js`,
> `backend/src/db/schema.js`, `mobile/services/*`, `mobile/lib/api.js`). It's the filled instance of
> `CONTRACT.template.md` and the single seam between the frontend and backend tracks. Keep it 1:1 with
> the code; when the code changes, update here.

**Auth:** every `/api/*` route except `/api/health` requires a **Supabase JWT** (`requireAuth` →
`req.userId`). All user resources are scoped to the caller in the query.
**ID convention:** seed (TheMealDB) recipe ids are numeric strings (`"52772"`); user-recipe ids are
`"u-<dbId>"` (`mobile/services/userRecipes.js`). `favorites.recipeId` is the integer seed id.

---

## 1. Features
| Feature | Job | Tier | State |
|---|---|---|---|
| Browse / search (seed) | find TheMealDB recipes | free | built (client `RecipeSource`) |
| Save (paw) | keep a recipe | free | built (`favorites`) |
| Import (URL) | pull a recipe from a link | free | built |
| Import (photo / video-IG) | OCR / share-extension extract | free | **planned** |
| Create / edit | write/own a recipe | free | built |
| Cook mode | hands-free steps | free | built (client) |
| **Nutrition (hero pipeline)** | correct per-serving kcal/macros | free | built + **live on USDA FDC** (ships offline, zero runtime calls) |
| Plan (Otto's week) | assign dishes to days | free (ungated) | built |
| Shopping list | list from plan/recipe | free (ungated) | **planned** (client/board only) |
| Membership (Otto Club) | trial → subscription | paid | **planned** (pre-IAP waitlist) |
| Ratings / comments | UGC trust signal | free | **Phase 2** (needs moderation kit) |

## 2. Data entities (schema.js — the model the backend owns)
```
favorites            user-scoped
  id serial pk · userId text · recipeId int (seed id) · title · image? · cookTime? ·
  servings? (text) · category? · createdAt

recipes              user-scoped   (imported | manual; seed never lands here)
  id serial pk · userId text · source "imported"|"manual" · sourceUrl? · sourceName? ·
  title · image? · category? · area? · servings int? ·
  ingredients jsonb [{measure,name}] · steps jsonb [string] · youtubeUrl? ·
  visibility "private"(default)|"public"   // P10 §4 seed; public feed is Phase 2
  nutrition jsonb?  DERIVED (null until computed — never a guess) ·
  createdAt · updatedAt

seed_nutrition       compute-once cache for seed + test-batch recipes
  recipeId text pk · nutrition jsonb · computedAt

plan_entries         user-scoped   (loose day buckets; recipe fields are a snapshot)
  id serial pk · userId text · day date · recipeId? text ("52772"|"u-12"|null) ·
  title · image? · category? · note? · cooked bool=false · createdAt
```
**Derived `nutrition` shape** (per serving, rounded): `{ kcal, protein_g, carbs_g, fat_g, fiber_g?,
sugar_g?, sodium_mg?, basis_grams, confidence "high"|"medium"|"low", per:"serving", source,
computed_at }` — **or `null`** ("honestly unknown"; the card falls back to the category estimate).

## 3. API endpoints
```
GET    /api/health                         public                → {success:true}

POST   /api/favorites                       user                  req {recipeId int, title, image?, cookTime?, servings?, category?} → 201 row · 400 missing recipeId|title
GET    /api/favorites                       user                  → [favorites]
DELETE /api/favorites/:recipeId             user  owner-scoped     → {message} · 400 bad id

POST   /api/import                          user                  req {url} → 200 draft {title,image,servings,category,area,ingredients:[{measure,name}],steps:[],sourceUrl,sourceName} · 400 missing url · 422 no recipe/unreadable
POST   /api/recipes                         user                  req {source"imported"|"manual", sourceUrl?, sourceName?, title, image?, category?, area?, servings?, ingredients:[{measure,name}], steps:[string], youtubeUrl?} → 201 recipe · 400 missing title|bad source
GET    /api/recipes                         user  owner-scoped     → [recipes] (own, newest first)
GET    /api/recipes/:id                     user  owner-scoped     → recipe · 400 bad id · 404
PUT    /api/recipes/:id                     user  owner-scoped     partial {title,image,category,area,servings,ingredients,steps,youtubeUrl} (source* immutable) → recipe; triggers async nutrition backfill · 404
DELETE /api/recipes/:id                     user  owner-scoped     → {message}
POST   /api/recipes/:id/nutrition/recompute user  owner-scoped     → recipe (nutrition recomputed)

GET    /api/nutrition/seed/:mealId          user                  → {recipeId, nutrition|null}  (server computes once + caches)

GET    /api/plan?start&end                  user  owner-scoped     → [entries] (day range, ordered)
POST   /api/plan                            user                  req {day"YYYY-MM-DD", recipeId?, title, image?, category?, note?} → 201 · 400 missing day|title, bad day
PATCH  /api/plan/:id                        user  owner-scoped     {day?, note?, cooked?} → entry · 404
DELETE /api/plan/:id                        user  owner-scoped     → {message}

DELETE /api/account                         user                  deletes all user rows (+ auth user if SUPABASE_SERVICE_ROLE_KEY) → {dataDeleted, authUserDeleted}
```
Client wrappers: `mobile/services/userRecipes.js` (`UserRecipeAPI`, `NutritionAPI`, `PlanAPI`),
favorites in `mobile/services/mealAPI.js`; all via `authFetch` (Bearer token) → base
`process.env.EXPO_PUBLIC_API_URL`.

## 4. Derived-data pipelines
**Nutrition (the hero):** `recipes.ingredients [{measure,name}]` → `parseIngredient.js` (normalize
qty/unit/item) → `NutritionProvider.computeNutrition(ingredients, servings)` → **USDA adapter** →
÷ servings → per-serving + `confidence` → cached on `recipes.nutrition` (user) / `seed_nutrition`
(seed). USDA FoodData Central is **public domain (CC0)**, and `usdaTable.json` ships inside the app —
so this runs with **zero runtime API calls** and no key. Unresolved ingredients return `null` → the UI
keeps the honest category estimate. Never a fabricated number.

> **Provider rule for any app built from this template: check the vendor's CACHE and RETENTION terms
> before writing the adapter.** Otto's pipeline is compute-once-then-store. It was first built on
> Edamam, whose licence forbids exactly that (caching limited to "FoodId, Food Label"; storage needs
> explicit permission) — discovered *after* the architecture assumed a cache. Rebuilt on USDA, which
> permits storing and redistributing freely. Pick the provider whose licence fits the architecture.

## 5. External providers (adapters — swappable)
| Capability | Adapter | Provider now | Swap later |
|---|---|---|---|
| Recipe content | `backend/src/lib/content/RecipeSource.js` + client `mealAPI` | **TheMealDB** | Spoonacular |
| Nutrition | `backend/src/lib/nutrition/NutritionProvider.js` → `usdaProvider.js` | **USDA FDC** (CC0, offline table) | any CC0/permissive source — **verify cache terms** |
| Payments | — | — | **RevenueCat** (planned) |

## 6. Integrations / ingest
- **URL import** — built (`importRecipe.js`, JSON-LD, **SSRF-guarded**, byte-capped).
- **Photo OCR / video-IG share-extension** — planned (needs dev-build; feed the same review→save path).
- **Apple Health (write nutrition on cook)** — planned; depends on §4 being correct.

## 7. Gating & entitlements
- **Today: none enforced** — all features ship ungated (matches the "Plan at launch" ruling).
- **Planned: Otto Club** via RevenueCat webhook → entitlement store → **server-side** gate enforcement
  (client meters would be UX only). This is a known **gap** — see `docs/BACKEND_ROADMAP.md` §J.

## 8. Cross-cutting guarantees
- **Auth/ownership:** Supabase JWT; every user resource `WHERE user_id = req.userId`.
- **Security:** input validation (`lib/validate.js`), rate limits (`lib/rateLimits.js`), SSRF guards on
  URL fetch. **RLS: to be confirmed/enabled in B0** (`docs/BACKEND_ROADMAP.md` §B0.1) — the middleware
  is the boundary today, RLS is defense-in-depth.
- **Honesty:** `nutrition` is `null` until computed, framed as an estimate + confidence when present;
  no fabricated data; no ratings on seed recipes.
- **Errors:** JSON `{error}` with brand-voice user messages; structured logging (`lib/logger.js`).
