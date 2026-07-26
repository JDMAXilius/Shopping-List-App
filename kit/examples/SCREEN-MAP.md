# 🗺️ frontend/SCREEN-MAP — Otto (filled · reference implementation)

> Otto's filled instance of `SCREEN-MAP.template.md`, matching `mobile/app/` + `docs/SCREEN_MAP.md` +
> the built `Otto — Master Board` (file `mM0uWkHod9rL1Ff1VJ64Au`). Data-needs reference
> `../shared/CONTRACT.md`.

`built` = shipping · `PLACEHOLDER` = labeled empty frame on the board (should exist, not built).

| Area | Screen | State | Route | Data needs (CONTRACT) |
|---|---|---|---|---|
| Launch/Auth | Splash | built | native splash | none (static) |
| Launch/Auth | Onboarding B1/B2/B3 | built | `(auth)` flow | none (marketing) |
| Launch/Auth | Sign up (Apple/Google/Facebook) | built | `(auth)/sign-up` | Supabase Auth (OAuth) |
| Launch/Auth | Sign in | built | `(auth)/sign-in` | Supabase Auth |
| Discover | Home | built | `(tabs)/index` | `RecipeSource` (TheMealDB) search/feed |
| Discover | Search-active | built | `(tabs)/index` | `RecipeSource` search |
| Discover | Filter sheet | built | component | none (client filter) |
| Discover | By-ingredient | **PLACEHOLDER** | — | `RecipeSource.filterByIngredient` |
| Recipe | Detail | built | `recipe/[id]` | seed `RecipeSource.getById` / `GET /recipes/:id`; nutrition inline or `GET /nutrition/seed/:mealId` |
| Recipe | Mise-en-place | built | `recipe/[id]` | recipe ingredients (structured) |
| Recipe | Cook mode | built | `recipe/cook/[id]` | recipe steps; `cooked` event (plan) |
| Add/Create | Add sheet | built | `add` | none (menu) |
| Add/Create | Import-URL review | built | `add` → `POST /import` | `POST /import` → draft |
| Add/Create | Scan-photo review | **PLACEHOLDER** | — | OCR extract (planned) |
| Add/Create | Video/IG review | **PLACEHOLDER** | — | share-extension extract (planned) |
| Add/Create | Manual editor | built | `(tabs)/create` | `POST /recipes` |
| Add/Create | Edit recipe | built | `recipe/edit` | `PUT /recipes/:id` |
| Cookbook | Home (Saved · My recipes) | built | `(tabs)/cookbook` | `GET /favorites`, `GET /recipes` |
| Cookbook | Empty | built | `(tabs)/cookbook` | none |
| Plan | Planner | built | `(tabs)/plan` | `GET/POST/PATCH/DELETE /plan` |
| Plan | Shopping list | built (client) | `shopping` | *(no endpoint yet — contract gap: shopping list is planned)* |
| Plan | Journal | built | `journal` | `GET /plan` (cooked) |
| Account | You | built | `(tabs)/profile` | Supabase user; `DELETE /account`; entitlements (planned) |
| Account | Otto Club paywall | built (pre-IAP) | `otto-club` | entitlements/IAP (planned) |
| Account | Connected accounts | **PLACEHOLDER** | — | Instagram OAuth (planned) |
| Account | Confirm dialogs | built | components | none |
| Supporting | Celebration · Error/offline · Generic empty · Search-empty · Loading | built | states | none |
| Future | Ask Otto · Collections · Membership-subscribed · Notifications-ask | **PLACEHOLDER** | — | — |

## Contract gaps flagged (screens needing data no endpoint serves yet)
- **Shopping list** (`shopping`) — renders client-side; **no shopping endpoint/entity in the contract**.
  Raise: add `shopping_lists`/`shopping_items` + generation endpoint (see `BACKEND_ROADMAP.md §H`).
- **Otto Club / entitlements** — paywall + Account membership need a **subscriptions** entity +
  entitlement endpoint (RevenueCat webhook) — `BACKEND_ROADMAP.md §J`.
- **By-ingredient / photo / video import** — endpoints planned, screens are placeholders until then.

## Tallest scrollers (size full-length frames for these)
Otto Club (~1537px) · Recipe Detail (~1373) · Discover Home (~1203) · Account (~1085) · Mise-en-place (~979).
