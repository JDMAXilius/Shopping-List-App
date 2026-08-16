-- Seed item catalog. Ships read-only inside the app binary.
--
-- This holds generic grocery ITEMS, never products: "oat milk", not
-- "Oatly Barista Edition 1L". Variants are first-class rows (whole milk,
-- oat milk) grouped by parent_concept; brands and SKUs are out of scope.
--
-- User-generated data (their own items, their aisle order, their prices)
-- lives in separate tables and always outranks this catalog.

-- DELETE journal: the db ships read-only inside the app bundle; WAL needs a
-- writable -shm next to the file and fails to open there.
PRAGMA journal_mode = DELETE;

CREATE TABLE catalog_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE category (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  emoji         TEXT,
  -- Default order for a generic store layout. Per-store, per-household
  -- aisle order lives in user data and overrides this.
  default_order INTEGER NOT NULL
);

CREATE TABLE item (
  id             INTEGER PRIMARY KEY,
  canonical_name TEXT NOT NULL,
  -- Groups variants for defaults and "you usually buy…" resolution.
  -- Deliberately NOT a foreign key to a parent row: variants are flat and
  -- independently searchable, because people type "oat", not "milk".
  parent_concept TEXT,
  category_id    TEXT NOT NULL REFERENCES category(id),
  emoji          TEXT,
  default_unit   TEXT,
  locale         TEXT NOT NULL DEFAULT 'en'
);

CREATE TABLE item_synonym (
  item_id INTEGER NOT NULL REFERENCES item(id) ON DELETE CASCADE,
  term    TEXT NOT NULL,
  PRIMARY KEY (item_id, term)
);

CREATE TABLE item_tag (
  item_id INTEGER NOT NULL REFERENCES item(id) ON DELETE CASCADE,
  tag     TEXT NOT NULL,   -- dairy-free, gluten-free, nut, vegetarian…
  PRIMARY KEY (item_id, tag)
);

-- Estimated prices, kept apart from `item` so "estimated" and "observed"
-- can never blur together. Observations live in user data and always win.
CREATE TABLE price_seed (
  item_id       INTEGER PRIMARY KEY REFERENCES item(id) ON DELETE CASCADE,
  base_amount   REAL NOT NULL,      -- USD, rounded: .50 under $10, $1 above
  currency      TEXT NOT NULL DEFAULT 'USD',
  base_unit     TEXT,
  compiled_year INTEGER NOT NULL
);

-- One multiplier per region beats thousands of regional price rows.
CREATE TABLE price_region (
  region_key TEXT PRIMARY KEY,
  label      TEXT NOT NULL,
  multiplier REAL NOT NULL
);

-- Normalized lookup: lowercased, singularized, qualifiers stripped.
-- "organic whole milk" and "bananna" resolve here before we call it a miss.
CREATE TABLE lookup_term (
  term    TEXT NOT NULL,
  item_id INTEGER NOT NULL REFERENCES item(id) ON DELETE CASCADE,
  -- 0 canonical name, 1 synonym, 2 derived (singular/qualifier-stripped)
  weight  INTEGER NOT NULL,
  PRIMARY KEY (term, item_id)
);

CREATE INDEX idx_item_category  ON item(category_id);
CREATE INDEX idx_item_parent    ON item(parent_concept);
CREATE INDEX idx_lookup_term    ON lookup_term(term, weight);
CREATE INDEX idx_synonym_term   ON item_synonym(term);
