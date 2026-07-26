# 🛠️ backend/CONTEXT — the data-services-spine methodology (reusable)

> The backend track's *why/what*; `MASTER-PROMPT.md` is *how*. The backend implements
> `../shared/CONTRACT.md` (data model + endpoints) and shares `../shared/APP-CONFIG.md`'s honesty law
> and voice. It never designs UI — it serves the contract.

---

## 1. What the spine is
The backend is a **layered service** that owns: **auth + the data model + business logic + derived-data
pipelines + third-party integrations + jobs + security**. Everything the frontend renders comes from
here, through the contract. Treat it as a spine you build **bottom-up**: foundations before features.

## 2. The layered anatomy (build low → high)
1. **Foundations** — DB + auth + **RLS/ownership** + input validation + structured logging + rate
   limiting + error tracking + a health check. No feature ships on an unsafe base.
2. **Core domain** — the contract's **entities + CRUD**, every user resource **scoped to the caller**.
3. **Derived-data pipeline(s)** — the app's "correctness" work (the hero). Generalized shape:
   `input → parse/normalize → enrich (provider) → compute → cache-once → honest framing (estimate +
   confidence)`. Never call a paid API on read; compute once, cache on the row.
4. **Integrations** — third-party APIs behind **swappable adapters** (a `Provider` interface + one
   adapter now, others later). Never let a vendor leak into routes.
5. **Ingest / content** — import channels (URL/photo/video/share), each an extractor feeding one
   review→save path; SSRF-guard any URL fetch.
6. **Social / UGC (if any)** — ratings/comments/profiles **come with the moderation floor**
   (report/block/filter) — a legal requirement for shipping UGC, not optional.
7. **Monetization** — IAP/subscription via webhooks → an entitlement store; **gating enforced
   server-side** (client meters are UX only).
8. **Platform integrations** — health/share/notifications — usually client-side, but depend on the
   backend serving correct data + the right events.

## 3. Cross-cutting concerns (apply across all layers)
- **Security:** RLS on every user table; validate all write bodies; SSRF guards; authz = ownership in
  every query, not just middleware.
- **Cost governance:** cache-once-per-item everywhere; budget caps + alerts on LLM/paid-API spend.
- **Storage:** object storage for user media; validate type/size; strip EXIF GPS; signed URLs.
- **Jobs:** backfills, aggregations, reminders, moderation queue.
- **Observability:** structured logs (not console), error tracking, per-endpoint metrics.
- **Privacy:** complete account deletion (App Store 5.1.1(v)); data export; retention on soft-deletes.
- **Versioning:** an `/api/v1` prefix before any public/shared URL exists.

## 4. Principles that make it reusable
- **Adapters over vendors** — a `RecipeSource`/`NutritionProvider`/`PaymentProvider`-style interface so
  the data/nutrition/payment source is swappable without touching routes.
- **Compute-once, cache** — derived truths are expensive; compute on write, cache, serve on read.
- **Server is the source of truth for gating** — never trust the client for entitlements/limits.
- **Honesty law (shared):** derived/estimated values carry a **source + confidence** and are framed as
  estimates; the API never returns fabricated data. Same law the UI obeys.

## 5. The phasing method
- **B0 — Foundations & truth first** (non-breaking): confirm the live DB, run migrations, **verify
  RLS**, validation/logging/rate-limits, and the empty **adapter interfaces**. Unblocks everything.
- **B1 — The hero pipeline** (the app's #1 correctness feature — §2.3): parser → provider adapter →
  schema + cache → lifecycle wiring → a **test batch that validates output against trusted data**.
- **B2+ — Expand** by contract priority: create/media, ingest channels, social+moderation,
  monetization, platform integrations. Each its own ticket; dependency-ordered.

## 6. Definition of done → `CHECKLIST.md`.
