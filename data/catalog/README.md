# Seed item catalog

The bundled catalog that makes autocomplete instant on day one, before a user
has any history. Ships read-only inside the app; user data always outranks it.

```
catalog.json   the source of truth — hand-curated, edit this
schema.sql     SQLite schema
build.mjs      validates catalog.json → compiles catalog.db
resolve.mjs    query-time resolution (the logic the app runs per keystroke)
catalog.db     build artifact, not committed
```

```sh
node data/catalog/build.mjs            # validate + build
node data/catalog/build.mjs --check    # validate only (CI)
node data/catalog/resolve.mjs --test   # resolution test cases
node data/catalog/resolve.mjs "organic whole milk"
```

Requires Node 22+ (`node:sqlite`). No dependencies.

## What belongs here

Generic grocery **items**: "oat milk", "chicken thighs", "sourdough loaf".

**Not** brands or SKUs. "Oatly Barista Edition 1L" is out of scope — that road
leads to a retail catalog, a data pipeline, staleness, and a retailer API
dependency. See `RESEARCH.md` §5.

Variants **are** in scope and are the point: "whole milk", "oat milk" and
"almond milk" are separate rows, not one "milk". They have different prices,
different dietary tags, and often different aisles — oat milk is frequently
shelf-stable and nowhere near the dairy case.

## Item shape

```json
{ "n": "oat milk", "p": "milk", "c": "plant-milk", "e": "🥛",
  "u": "carton", "est": 5.0, "t": ["dairy-free", "vegan"],
  "s": ["oatmilk", "oat drink"] }
```

| key | meaning |
|---|---|
| `n` | canonical name, required |
| `p` | parent concept — groups variants, does not nest them |
| `c` | category id, required |
| `e` | emoji; falls back to the category's |
| `u` | default unit |
| `est` | price estimate in USD |
| `t` | tags — `dairy-free`, `gluten-free`, `nut`, `vegan`, `vegetarian` |
| `s` | synonyms |

`p` deliberately isn't a foreign key to a parent row. Variants stay flat and
independently searchable because **people type the variant, not the parent** —
someone types "oat" and must land on oat milk without traversing anything.

## Depth is uneven on purpose

Deep where price and aisle actually vary — milk, cheese, bread, meat cuts,
rice, pasta, apples, potatoes, onions, tomatoes, greens. One row where nobody
is specific — bananas, salt, sugar, flour. Expanding everything uniformly
triples the curation cost and buys nothing.

## Price estimates

`est` is a **seed prior**, never a fact. Any real observation from the user
overrides it permanently for that household.

`build.mjs` enforces the rounding rule and fails the build on violations:
nearest **$0.50** under $10, nearest **$1** at or above. This is not cosmetic —
rounding is what makes the number read as a guess instead of a lookup. `$3.47`
implies the app checked; `~$3.50` implies it's estimating. The UI pairs this
with grey text and a `~` prefix so an estimate can never be mistaken for a
price someone actually paid.

Regional variation is one multiplier per region, not per-item regional rows.

Stamp: prices are USD, compiled 2026. A seed this old is embarrassing by 2029 —
bump `seed_version` and `compiled_year` when refreshing.

## Resolution

`resolve.mjs` is why most "unlisted" items aren't. Before declaring a miss:

1. **Normalize** — lowercase, strip punctuation and accents.
2. **Singularize** — including irregulars (mangoes → mango).
3. **Strip qualifiers** — organic, free-range, boneless, large, ripe…
4. **Match** exact terms, then any-word-boundary prefix, then bounded edit
   distance for typos.

`build.mjs` precomputes all four forms into `lookup_term` with a weight
(0 canonical, 1 synonym, 2 derived) so lookups stay index-only.

Worth knowing:

- **Ambiguity is not failure.** "milk" and "mince" resolve to several items on
  purpose — the autocomplete list is where the user disambiguates. Forcing a
  "which one?" prompt would be friction at the worst possible moment.
- **Prefix matches any word boundary**, so "mince" reaches "beef mince" and
  "pork mince". Anchoring at position 0 would make resolution depend on the
  word order a synonym happened to be written in.
- **A genuine miss must still work.** Unmatched text becomes a valid item with
  no `item_id`, no emoji, no price, landing in "Other". One tap to categorize,
  remembered forever in that household's own catalog.

## Adding a market

Add synonyms, not rows. `aubergine`, `courgette`, `coriander`, `rocket`,
`nappies`, `cling film` and `loo roll` all already resolve. Launching the UK or
AU is a data task, not a code change — that's the whole reason synonyms exist
from day one rather than being retrofitted.
