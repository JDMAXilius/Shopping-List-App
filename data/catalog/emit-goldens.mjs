#!/usr/bin/env node
// The Swift port pins FULL result arrays for the 23 golden queries, so any
// catalog change shifts them. This regenerates the expectations from the JS
// engine — the port's source of truth — as JSON for CatalogTests to consume.
//
//   node data/catalog/emit-goldens.mjs > Packages/Catalog/Tests/CatalogTests/goldens.json

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { resolve } from './resolve.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const db = new DatabaseSync(join(here, 'catalog.db'), { readOnly: true });

// The 23 cases, verbatim from resolve.mjs --test. Keep in sync by hand: a new
// case belongs in both, and the JS test remains the semantic contract.
const QUERIES = [
  'organic whole milk', 'free-range eggs', 'boneless skinless chicken breast',
  'bananna', 'tomatos', 'mangoes', 'aubergine', 'courgette', 'coriander',
  'rocket', 'spring onions', 'mince', 'beef mince', 'oat', 'crisps',
  'loo roll', 'cling film', 'a large ripe avocado', 'skimmed milk',
  'plain flour', 'fizzy water', 'nappies', 'unicorn steaks',
];

const out = QUERIES.map((query) => ({
  query,
  results: resolve(db, query).map((r) => ({
    canonical_name: r.canonical_name,
    category_id: r.category_id,
    score: r.score,
    via: r.via,
  })),
}));

console.log(JSON.stringify({ generated_from: 'catalog.db', cases: out }, null, 2));
