# 🔌 shared/CONTRACT (template) — the seam between frontend & backend

> **The single interface both tracks build to.** The FE designs screens against these endpoints +
> shapes; the BE implements this data model + these endpoints. Neither track reads the other's
> internals — only this file. Change it deliberately, here, and both sides follow. Copy to
> `CONTRACT.md` and fill. See `../EXAMPLE-otto.md`.

---

## 1. Feature list (the whole product, one line each)
For each: name · one-line job · free/paid · built|planned.
{{FEATURES}}

## 2. Data entities (the model the backend owns, the frontend renders)
For each entity: fields (name · type · notes), ownership (user-scoped?), and any **derived** fields
(computed, not authored — must carry a source + confidence per the honesty law).
{{ENTITIES}}
*(Template per entity:)*
```
Entity: {{name}}
  - {{field}} : {{type}}   // {{note}}
  - ...
  ownership: {{user-scoped? public? }}
  derived: {{field → how computed → cached? → confidence framing}}
```

## 3. API endpoints (the calls the frontend makes)
For each: method · path · auth (public/user) · owner-scoped? · request → response shape · errors.
{{ENDPOINTS}}
*(Template per endpoint:)*
```
{{METHOD}} {{/path}}   auth:{{user|public}}  owner-scoped:{{yes|no}}
  req:  { {{...}} }
  res:  { {{...}} }
  errs: {{400/401/404/422/429 conditions}}
```

## 4. Derived-data pipelines (where "correctness" is produced)
The app's compute-heavy truths (e.g. a nutrition/score/ranking pipeline). For each:
input → parse/normalize → enrich (which provider) → compute → cache → **honest framing** (estimate +
confidence). This is usually the backend's "hero" work.
{{PIPELINES}}

## 5. External providers (swappable via adapters)
For each capability: what we need · provider(s) · cost · which the backend adapter wraps.
{{PROVIDERS}}

## 6. Integrations / ingest channels
Import/share/platform integrations (URL/photo/video/share-extension, health, payments…), each with
its FE trigger and BE handler.
{{INTEGRATIONS}}

## 7. Gating & entitlements
What's free vs paid, and **where it's enforced** (client meter = UX; **server = source of truth**).
{{GATING_RULES}}

## 8. Cross-cutting guarantees (both sides rely on)
- **Auth/ownership:** {{AUTH_MODEL}} — every user resource scoped to the caller.
- **Security:** RLS on, input validation on all writes, SSRF guards on any URL fetch.
- **Honesty:** derived values labeled + confidence; no fabricated data (mirrors APP-CONFIG §5).
- **Errors:** shared error shape + one brand voice for user-facing messages.
