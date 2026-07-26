# ✅ backend/CHECKLIST — spine acceptance

## Roadmap
- ☐ `BACKEND_ROADMAP.md` exists: honest inventory vs. contract · hero pipeline designed · per-layer plan ·
  cross-cutting · phased B0→Bn with founder inputs · provider capability matrix.

## Foundations (B0)
- ☐ Live DB confirmed; migrations applied; **RLS ON** for every user table; advisors clean.
- ☐ Write bodies **validated**; **structured logging** + error tracking wired; **rate limits** on
  external-calling endpoints.
- ☐ Adapter **interfaces** exist (providers from the contract), with one real adapter.
- ☐ No breaking change to the client API path.

## Hero pipeline (B1)
- ☐ Full chain built: parse → provider adapter → compute → **schema + cache** → lifecycle wiring.
- ☐ **Cache-once** — no paid API call on read.
- ☐ Derived values framed as **estimates + confidence**; never fabricated.
- ☐ A **test batch** diffs computed output vs. a trusted source, within tolerance (the acceptance test).

## Contract fidelity
- ☐ Every implemented endpoint matches `../shared/CONTRACT.md` (method · path · auth · shape · errors).
- ☐ Every user resource is **owner-scoped** in the query (not just middleware).
- ☐ Any contract gap was **raised as a contract change**, not invented silently.

## Cross-cutting
- ☐ SSRF guards on URL fetches; user media validated + EXIF-stripped; signed URLs.
- ☐ Gating (if any) enforced **server-side**; client meters are UX only.
- ☐ Account deletion complete (data + auth user); privacy/retention handled.
- ☐ Cost caps + caching on LLM/paid-API usage.

## Voice
- ☐ User-facing error/copy shares the app's brand voice (`../shared/APP-CONFIG.md`).
