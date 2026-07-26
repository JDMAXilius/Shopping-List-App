#!/usr/bin/env node
// Validates catalog.json and compiles it to a SQLite database the app ships.
//
//   node data/catalog/build.mjs            validate + build catalog.db
//   node data/catalog/build.mjs --check    validate only (CI)
//
// Requires Node 22+ for node:sqlite.

import { readFileSync, unlinkSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const here = dirname(fileURLToPath(import.meta.url));
const checkOnly = process.argv.includes('--check');

const catalog = JSON.parse(readFileSync(join(here, 'catalog.json'), 'utf8'));
const errors = [];
const warnings = [];

/* ── normalization ──────────────────────────────────────────────────────────
 * The same pipeline the app runs on user input before declaring a miss.
 * Most "unlisted" items are a known item wearing a qualifier or a typo:
 * "organic whole milk" → "whole milk", "bananna" → handled by fuzzy match
 * at query time against the terms we generate here.
 */

// Stripped from the head of a query. Order matters: longest first.
const QUALIFIERS = [
  'organic', 'free range', 'free-range', 'fresh', 'frozen', 'raw', 'whole grain',
  'wholegrain', 'low fat', 'low-fat', 'reduced fat', 'fat free', 'fat-free',
  'nonfat', 'non fat', 'unsalted', 'salted', 'large', 'small', 'medium', 'jumbo',
  'baby', 'mini', 'extra', 'premium', 'store brand', 'generic', 'natural',
  'unsweetened', 'sweetened', 'plain', 'sliced', 'shredded', 'grated', 'chopped',
  'ground', 'boneless', 'skinless', 'ripe', 'seedless', 'unbleached',
];

// Irregulars first; the -es/-s rules handle the rest.
const IRREGULAR = new Map([
  ['leaves', 'leaf'], ['loaves', 'loaf'], ['knives', 'knife'],
  ['potatoes', 'potato'], ['tomatoes', 'tomato'], ['mangoes', 'mango'],
  ['berries', 'berry'], ['cherries', 'cherry'], ['peaches', 'peach'],
]);

function singularize(word) {
  if (IRREGULAR.has(word)) return IRREGULAR.get(word);
  if (word.length <= 3) return word;
  if (word.endsWith('ss') || word.endsWith('us')) return word;   // glass, hummus
  if (word.endsWith('ies')) return word.slice(0, -3) + 'y';
  if (word.endsWith('oes')) return word.slice(0, -2);
  if (word.endsWith('es') && /(sh|ch|x|z)es$/.test(word)) return word.slice(0, -2);
  if (word.endsWith('s')) return word.slice(0, -1);
  return word;
}

function normalize(text) {
  return text
    .toLowerCase()
    .normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9%\s-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function stripQualifiers(text) {
  let out = ` ${text} `;
  for (const q of QUALIFIERS.sort((a, b) => b.length - a.length)) {
    out = out.replaceAll(` ${q} `, ' ');
  }
  return out.replace(/\s+/g, ' ').trim();
}

// Every string that should resolve to this item, with a weight.
// 0 canonical, 1 synonym, 2 derived. Lower wins on ties.
function lookupTerms(item) {
  const terms = new Map();
  const add = (t, w) => {
    const k = normalize(t);
    if (!k) return;
    if (!terms.has(k) || terms.get(k) > w) terms.set(k, w);
  };

  add(item.n, 0);
  for (const s of item.s ?? []) add(s, 1);

  // Derived: singularized, qualifier-stripped, and both together.
  for (const [base, weight] of [[item.n, 2], ...(item.s ?? []).map((s) => [s, 2])]) {
    const n = normalize(base);
    const singular = n.split(' ').map(singularize).join(' ');
    const stripped = stripQualifiers(n);
    const both = stripQualifiers(singular);
    for (const v of [singular, stripped, both]) if (v && v !== n) add(v, weight);
  }
  return terms;
}

/* ── validation ─────────────────────────────────────────────────────────── */

const categoryIds = new Set(catalog.categories.map((c) => c.id));
const seenNames = new Set();
const termOwners = new Map();   // normalized term → [item names]

for (const [i, item] of catalog.items.entries()) {
  const where = `items[${i}] "${item.n ?? '?'}"`;

  if (!item.n) errors.push(`${where}: missing name`);
  if (!item.c) errors.push(`${where}: missing category`);
  else if (!categoryIds.has(item.c)) errors.push(`${where}: unknown category "${item.c}"`);

  const key = normalize(item.n ?? '');
  if (seenNames.has(key)) errors.push(`${where}: duplicate canonical name`);
  seenNames.add(key);

  if (!item.e) warnings.push(`${where}: no emoji, will fall back to category`);
  if (!item.u) warnings.push(`${where}: no default unit`);

  // The rounding rule is load-bearing: it is what makes an estimate read as a
  // guess rather than a looked-up fact. Enforce it here, not in review.
  if (item.est !== undefined) {
    const v = item.est;
    if (typeof v !== 'number' || v <= 0) {
      errors.push(`${where}: price estimate must be a positive number`);
    } else if (v < 10 && Math.round(v * 2) !== v * 2) {
      errors.push(`${where}: estimate ${v} under $10 must round to $0.50`);
    } else if (v >= 10 && !Number.isInteger(v)) {
      errors.push(`${where}: estimate ${v} at/over $10 must round to $1`);
    }
  }

  for (const [term] of lookupTerms(item)) {
    if (!termOwners.has(term)) termOwners.set(term, []);
    termOwners.get(term).push(item.n);
  }
}

// Ambiguous terms are not errors — "milk" legitimately resolves to several
// variants and the autocomplete list is where the user disambiguates. But a
// canonical name colliding with another item's canonical name is a bug.
let ambiguous = 0;
for (const [term, owners] of termOwners) {
  if (owners.length > 1) {
    ambiguous++;
    const canonicals = owners.filter((o) => normalize(o) === term);
    if (canonicals.length > 1) {
      errors.push(`term "${term}" is the canonical name of ${canonicals.length} items`);
    }
  }
}

for (const c of catalog.categories) {
  if (typeof c.order !== 'number') errors.push(`category "${c.id}": missing order`);
}

const usedCategories = new Set(catalog.items.map((i) => i.c));
for (const id of categoryIds) {
  if (!usedCategories.has(id) && id !== 'other') warnings.push(`category "${id}" has no items`);
}

/* ── report ─────────────────────────────────────────────────────────────── */

const byCategory = {};
for (const item of catalog.items) byCategory[item.c] = (byCategory[item.c] ?? 0) + 1;
const parents = new Set(catalog.items.map((i) => i.p).filter(Boolean));
const priced = catalog.items.filter((i) => i.est !== undefined).length;

console.log(`catalog v${catalog.seed_version} (compiled ${catalog.compiled_year})`);
console.log(`  ${catalog.items.length} items, ${parents.size} parent concepts, ${categoryIds.size} categories`);
console.log(`  ${priced} priced (${Math.round((priced / catalog.items.length) * 100)}%), ${termOwners.size} lookup terms, ${ambiguous} ambiguous`);
console.log(`  depth: ${Object.entries(byCategory).sort((a, b) => b[1] - a[1]).map(([c, n]) => `${c} ${n}`).join(', ')}`);

if (warnings.length) console.log(`  ${warnings.length} warnings (use --verbose to list)`);
if (process.argv.includes('--verbose')) for (const w of warnings) console.log(`    warn: ${w}`);

if (errors.length) {
  console.error(`\n${errors.length} error(s):`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}

if (checkOnly) {
  console.log('\nvalid');
  process.exit(0);
}

/* ── build ──────────────────────────────────────────────────────────────── */

const dbPath = join(here, 'catalog.db');
if (existsSync(dbPath)) unlinkSync(dbPath);

const db = new DatabaseSync(dbPath);
db.exec(readFileSync(join(here, 'schema.sql'), 'utf8'));

const insMeta = db.prepare('INSERT INTO catalog_meta (key, value) VALUES (?, ?)');
const insCat = db.prepare('INSERT INTO category (id, name, emoji, default_order) VALUES (?, ?, ?, ?)');
const insItem = db.prepare(
  'INSERT INTO item (id, canonical_name, parent_concept, category_id, emoji, default_unit) VALUES (?, ?, ?, ?, ?, ?)');
const insSyn = db.prepare('INSERT INTO item_synonym (item_id, term) VALUES (?, ?)');
const insTag = db.prepare('INSERT INTO item_tag (item_id, tag) VALUES (?, ?)');
const insSeed = db.prepare(
  'INSERT INTO price_seed (item_id, base_amount, currency, base_unit, compiled_year) VALUES (?, ?, ?, ?, ?)');
const insRegion = db.prepare('INSERT INTO price_region (region_key, label, multiplier) VALUES (?, ?, ?)');
const insTerm = db.prepare('INSERT OR IGNORE INTO lookup_term (term, item_id, weight) VALUES (?, ?, ?)');

db.exec('BEGIN');

for (const [k, v] of Object.entries({
  seed_version: catalog.seed_version,
  compiled_year: catalog.compiled_year,
  currency: catalog.currency,
  locale: catalog.locale,
  item_count: catalog.items.length,
})) insMeta.run(k, String(v));

for (const c of catalog.categories) insCat.run(c.id, c.name, c.emoji ?? null, c.order);
for (const r of catalog.regions) insRegion.run(r.key, r.label, r.multiplier);

const emojiFor = new Map(catalog.categories.map((c) => [c.id, c.emoji]));

catalog.items.forEach((item, idx) => {
  const id = idx + 1;
  insItem.run(id, item.n, item.p ?? null, item.c, item.e ?? emojiFor.get(item.c) ?? null, item.u ?? null);
  for (const s of item.s ?? []) insSyn.run(id, s);
  for (const t of item.t ?? []) insTag.run(id, t);
  if (item.est !== undefined) insSeed.run(id, item.est, catalog.currency, item.u ?? null, catalog.compiled_year);
  for (const [term, weight] of lookupTerms(item)) insTerm.run(term, id, weight);
});

db.exec('COMMIT');
db.exec('VACUUM');
db.close();

const { size } = await import('node:fs').then((fs) => fs.statSync(dbPath));
console.log(`\nbuilt ${dbPath} (${(size / 1024).toFixed(0)} KB)`);
