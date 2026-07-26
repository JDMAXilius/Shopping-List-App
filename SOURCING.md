# Data and imagery sourcing — what we can legally use, and what we should build

Two questions: **is there an open dataset we should build the catalog on**, and **where do item
photos come from**. Both have a licensing answer and a quality answer, and on both the licensing
answer and the quality answer point the same way.

---

## 1. Catalog data — the honest finding

**There is no open dataset that fits, and the one that looks closest carries a licence that would
infect our catalog.**

| Source | Licence | Verdict |
|---|---|---|
| **USDA FoodData Central** | **Public domain / CC0** — no permission needed, attribution requested not required | **Safe, but wrong shape.** 400k+ entries of *nutrition* data. No categories, no aisles, no prices, no shopping synonyms. Useful as a name and spelling reference, nothing more |
| **Open Food Facts — data** | **ODbL** | ⚠️ **Avoid for the catalog.** See below |
| **Open Food Facts — images** | **CC-BY-SA** | Attribution *and* share-alike, and they're branded packshots |
| **FoodOn ontology** | CC-BY | Academic food classification. Genuinely open, but built for research taxonomy, not for someone typing "oat" at a supermarket |
| **GS1 / GDSN** | Proprietary, paid, per-seat | The real product database. Priced for retailers, not for us |
| **Open Grocery Database** | Public domain | Small and long unmaintained |

### The ODbL trap, stated precisely

Open Food Facts data is **Open Database License**. ODbL is *share-alike for databases*: if you
build a derived database from it and make that database publicly available, **you must license
your derived database under ODbL too.** Our catalog — the categories, the aisle mapping, the
lookup terms, the price seeds — is one of the few genuinely proprietary assets this project has.
Deriving it from ODbL data risks handing it to every competitor.

**The distinction that keeps us safe:** *querying* Open Food Facts at runtime for a barcode is
**use**, not derivation. Caching a scanned product's name for that one user is fine.
**Bulk-importing OFF into our catalog is derivation, and we don't do it.**

> **Rule:** Open Food Facts is a **runtime lookup service** for barcodes, with attribution. It is
> never an input to `catalog.json`.

### Which means we keep doing what we're doing

`data/catalog/` is **414 hand-built items, 859 lookup terms, 22 categories, 8 price regions,
authored by us**. That is:

- **Clean IP.** No licence, no attribution obligation, no share-alike, wholly owned.
- **The right shape.** It maps how shoppers *talk* ("oat", "mince") to what they *buy*, which no
  nutrition or ontology dataset does.
- **Small.** 200 KB, ~1% of the app.
- **The thing nobody can copy quickly.** The price seeds and the aisle mapping compound with use.

It also isn't finished. **Growing it is a data-entry job, not a licensing problem** — target
~1,200 items, prioritised by the unmatched search terms real users type (the opt-in reporting
decision in `CAPABILITIES.md`). That is the correct way to grow a catalog: from demand, not from
a bulk import.

---

## 2. Item imagery

Photos are agreed as the direction. The question is where they come from, and the licensing answer
turns out to be the *smaller* problem.

### The legal options

| Source | Licence | Usable? |
|---|---|---|
| **Rawpixel (public-domain section)**, **PublicDomainPictures**, **LibreShot**, **Good Free Photos** | CC0 / public domain — no attribution, commercial fine | **Yes** |
| **Wikimedia Commons** | **Mixed, per file** — CC0, CC-BY, CC-BY-SA all present | **Only per-file.** Never bulk-scrape; each file's licence must be checked and recorded |
| **Openverse** | Aggregator, filterable to CC0 | Yes, with the same per-file discipline |
| **Unsplash / Pexels** | Permissive, commercial allowed, **not public domain** | Careful. Both licences restrict compiling images into a competing service. Our use is decoration, not redistribution — but it's a licence to read, not assume |
| **Open Food Facts images** | CC-BY-SA | **No.** Share-alike, plus they're *branded packshots*, and our catalog is deliberately generic — a photo of one brand of oat milk misrepresents the item |

### The real problem isn't legal, it's coherence

414 items sourced from a dozen free-photo sites gives you **414 different backgrounds, angles,
crops, colour temperatures and shadow directions.** A grid of that looks worse than emoji —
emoji at least has one visual system. AnyList's photography works *because* it's a consistent set,
not because photos beat emoji in the abstract.

Sourcing found photos also means, per image: find it, verify the licence, record the provenance,
crop it, colour-match it, background-remove it. **414 times.** That's most of the work of
generating them, with a worse result and a permanent paperwork liability.

### Recommendation: generate a consistent set

**Generate the item images ourselves, to one specification.** Same background (our paper
`#F6F4F1`), same three-quarter angle, same soft light, same shadow, same crop, same scale
relationship between items.

Why this wins on every axis that matters:

- **Legally clean** — no attribution, no share-alike, no provenance ledger, no per-file audit
- **Visually coherent** — the set becomes brand equity, not decoration. This is the single biggest
  visual differentiator available to us
- **Complete** — no item is stuck on emoji because nobody photographed a rutabaga well
- **Correctable** — a bad one gets regenerated in minutes

Two things to get right: keep it **generic, never brand-alike** (no packaging that resembles a real
product — that's a trademark problem we don't need), and **check the generator's commercial-use
terms** and keep that written down.

### The progressive-replacement architecture

Emoji as placeholder, photos swapped in per item, exactly as proposed. Make it a data property:

```
item.image_status ∈ { 'emoji', 'generated', 'licensed' }
item.image_ref     -- asset name, NULL when emoji
item.image_source  -- provenance + licence, required when 'licensed'
```

Rules:

1. **Emoji is the permanent fallback, never a blank or a spinner.** Every item ships with one.
2. **Photos ship in the app bundle, not fetched on demand.** On-Demand Resources would keep the
   download small, but a photo that needs a network breaks offline-first *in a supermarket*.
   Offline is a core feature; imagery isn't.
3. **A release ships whatever photos exist at that point.** No coordination, no big-bang
   changeover.
4. **`image_source` is mandatory for anything licensed.** A provenance record we can't produce
   later is a licence we can't defend.

### Size, which decides how many we ship

Against the native baseline of ~17–25 MB (`STACK.md` §6):

| Approach | Added | Total app **[estimate]** |
|---|---|---|
| Emoji only | 0 MB | 17–25 MB |
| **Top 100 items bundled** | **~3.5 MB** | **21–29 MB** — under the 30 MB ceiling |
| Top 250 | ~9 MB | 26–34 MB |
| All 414 | ~15 MB | 32–40 MB — over the ceiling, near AnyList |

> 414 × ~35 KB HEIC at 480 px. HEIC over WebP because iOS decodes it natively.

**Ship the top 100 by real usage frequency.** They cover the overwhelming majority of what
actually goes on lists — milk, eggs, bread, bananas, chicken — and the tail degrades to emoji,
which is exactly what the fallback is for. Being a larger download than a 14-year-old incumbent
with more features is a bad trade for pictures of rutabaga.

---

## 3. What to do, in order

1. **Stop considering Open Food Facts as a catalog input.** Keep it as a runtime barcode lookup,
   with attribution. *(Decision — no work required, just don't do the tempting thing.)*
2. **Write the image specification** — background, angle, light, crop, scale — before generating
   anything. Consistency is the entire value; it cannot be retrofitted.
3. **Rank the catalog by expected frequency** and generate the top 100 first.
4. **Add `image_status` / `image_ref` / `image_source` to the schema** now, while it's free.
5. **Keep growing the catalog from unmatched search terms**, not from bulk imports.
