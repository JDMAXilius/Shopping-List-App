#!/usr/bin/env node
// Query-time resolution against the built catalog. This is the logic the app
// runs on every keystroke, and the reason most "unlisted" items aren't.
//
//   node data/catalog/resolve.mjs "organic whole milk"
//   node data/catalog/resolve.mjs --test
//
// Ranking in the real app is: personal history → household → this catalog.
// Only the last tier is implemented here.

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const here = dirname(fileURLToPath(import.meta.url));

const QUALIFIERS = [
  'organic', 'free range', 'free-range', 'fresh', 'raw', 'whole grain', 'wholegrain',
  'low fat', 'low-fat', 'reduced fat', 'fat free', 'fat-free', 'nonfat', 'non fat',
  'large', 'small', 'medium', 'jumbo', 'mini', 'extra', 'premium', 'store brand',
  'generic', 'natural', 'unsweetened', 'sweetened', 'boneless', 'skinless',
  'ripe', 'seedless', 'unbleached', 'a', 'some', 'the',
];

const IRREGULAR = new Map([
  ['leaves', 'leaf'], ['loaves', 'loaf'], ['potatoes', 'potato'],
  ['tomatoes', 'tomato'], ['mangoes', 'mango'], ['berries', 'berry'],
  ['cherries', 'cherry'], ['peaches', 'peach'],
]);

const singularize = (w) => {
  if (IRREGULAR.has(w)) return IRREGULAR.get(w);
  if (w.length <= 3 || w.endsWith('ss') || w.endsWith('us')) return w;
  if (w.endsWith('ies')) return w.slice(0, -3) + 'y';
  if (w.endsWith('oes')) return w.slice(0, -2);
  if (w.endsWith('es') && /(sh|ch|x|z)es$/.test(w)) return w.slice(0, -2);
  return w.endsWith('s') ? w.slice(0, -1) : w;
};

const normalize = (t) => t.toLowerCase()
  .normalize('NFKD').replace(/[̀-ͯ]/g, '')
  .replace(/[^a-z0-9%\s-]/g, ' ').replace(/\s+/g, ' ').trim();

const strip = (t) => {
  let out = ` ${t} `;
  for (const q of [...QUALIFIERS].sort((a, b) => b.length - a.length)) out = out.replaceAll(` ${q} `, ' ');
  return out.replace(/\s+/g, ' ').trim();
};

// Bounded edit distance — we only ever care about 1–2 character typos.
function editDistance(a, b, max = 2) {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    let best = i;
    for (let j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] === b[j - 1]
        ? prev[j - 1]
        : 1 + Math.min(prev[j - 1], prev[j], cur[j - 1]);
      best = Math.min(best, cur[j]);
    }
    if (best > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

export function resolve(db, query, limit = 6) {
  const q = normalize(query);
  if (!q) return [];

  const variants = new Map();               // term → penalty
  const consider = (t, p) => {
    if (t && (!variants.has(t) || variants.get(t) > p)) variants.set(t, p);
  };
  consider(q, 0);
  consider(q.split(' ').map(singularize).join(' '), 1);
  consider(strip(q), 2);
  consider(strip(q.split(' ').map(singularize).join(' ')), 2);

  const hits = new Map();                   // item id → best score
  const stmt = db.prepare(`
    SELECT i.id, i.canonical_name, i.parent_concept, i.category_id, i.emoji,
           i.default_unit, lt.weight, ps.base_amount
      FROM lookup_term lt
      JOIN item i ON i.id = lt.item_id
      LEFT JOIN price_seed ps ON ps.item_id = i.id
     WHERE lt.term = ?`);

  for (const [term, penalty] of variants) {
    for (const row of stmt.all(term)) {
      const score = row.weight + penalty;
      const prev = hits.get(row.id);
      if (!prev || prev.score > score) hits.set(row.id, { ...row, score, via: 'exact' });
    }
  }

  // Prefix match on any word boundary, not just the start of the term:
  // "oat" must reach "oat milk", and "mince" must reach "beef mince",
  // "pork mince" and the rest. Anchoring at position 0 only would make
  // resolution depend on the word order a synonym happens to be written in.
  if (hits.size < limit) {
    const pre = db.prepare(`
      SELECT i.id, i.canonical_name, i.parent_concept, i.category_id, i.emoji,
             i.default_unit, lt.term, ps.base_amount
        FROM lookup_term lt
        JOIN item i ON i.id = lt.item_id
        LEFT JOIN price_seed ps ON ps.item_id = i.id
       WHERE lt.term LIKE ? OR lt.term LIKE ? LIMIT 60`).all(`${q}%`, `% ${q}%`);
    for (const row of pre) {
      // Starts-with beats matches-a-later-word.
      const score = row.term.startsWith(q) ? 4 : 4.5;
      const prev = hits.get(row.id);
      if (!prev || prev.score > score) hits.set(row.id, { ...row, score, via: 'prefix' });
    }
  }

  // Typo fallback: only when nothing else matched, and only on short queries.
  if (hits.size === 0 && q.length >= 4 && q.split(' ').length <= 3) {
    const all = db.prepare('SELECT term, item_id FROM lookup_term WHERE weight <= 1').all();
    const near = [];
    for (const { term, item_id } of all) {
      const d = editDistance(q, term);
      if (d <= (q.length <= 6 ? 1 : 2)) near.push({ item_id, d });
    }
    near.sort((a, b) => a.d - b.d);
    const detail = db.prepare(`
      SELECT i.id, i.canonical_name, i.parent_concept, i.category_id, i.emoji,
             i.default_unit, ps.base_amount
        FROM item i LEFT JOIN price_seed ps ON ps.item_id = i.id WHERE i.id = ?`);
    for (const { item_id, d } of near.slice(0, limit)) {
      if (hits.has(item_id)) continue;
      const row = detail.get(item_id);
      if (row) hits.set(item_id, { ...row, score: 5 + d, via: 'fuzzy' });
    }
  }

  return [...hits.values()]
    .sort((a, b) => a.score - b.score || a.canonical_name.length - b.canonical_name.length)
    .slice(0, limit);
}

/* ── CLI ────────────────────────────────────────────────────────────────── */

// Importable: only run the CLI when invoked directly, never on import.
const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (!isMain) { /* imported as a library */ }
else {

const db = new DatabaseSync(join(here, 'catalog.db'), { readOnly: true });

if (process.argv.includes('--test')) {
  // Each case is a real way someone types a thing that "isn't in the catalog".
  const cases = [
    ['organic whole milk', 'whole milk', 'qualifier stripped'],
    ['free-range eggs', 'free-range eggs', 'exact, qualifier kept when canonical'],
    ['boneless skinless chicken breast', 'chicken breast', 'multi-qualifier'],
    ['bananna', 'bananas', 'typo'],
    ['tomatos', 'vine tomatoes', 'typo + plural'],
    ['mangoes', 'mangoes', 'irregular plural, exact'],
    ['aubergine', 'eggplant', 'UK synonym'],
    ['courgette', 'zucchini', 'UK synonym'],
    ['coriander', 'cilantro', 'UK synonym'],
    ['rocket', 'arugula', 'UK synonym'],
    ['spring onions', 'green onions', 'UK synonym + plural'],
    ['mince', ['ground beef', 'ground pork', 'ground lamb'], 'ambiguous: show every mince, let the list disambiguate'],
    ['beef mince', 'ground beef', 'UK term'],
    ['oat', 'rolled oats', 'exact beats prefix; oat milk follows'],
    ['crisps', 'potato chips', 'UK synonym'],
    ['loo roll', 'toilet paper', 'UK slang'],
    ['cling film', 'plastic wrap', 'UK term'],
    ['a large ripe avocado', 'avocados', 'article + qualifiers + singular'],
    ['skimmed milk', 'skim milk', 'UK variant'],
    ['plain flour', 'all-purpose flour', 'UK term'],
    ['fizzy water', 'sparkling water', 'colloquial'],
    ['nappies', 'diapers', 'UK term'],
    ['unicorn steaks', null, 'genuine miss, should return nothing confident'],
  ];

  let pass = 0, fail = 0;
  for (const [query, expected, why] of cases) {
    const results = resolve(db, query);
    const top = results[0];
    const got = top?.canonical_name ?? null;
    const names = results.map((r) => r.canonical_name);

    let ok, detail;
    if (expected === null) {
      ok = got === null || top.score >= 5;
      detail = got ?? '(none)';
    } else if (Array.isArray(expected)) {
      // Ambiguous query: every listed variant must appear somewhere in the
      // results. Which one ranks first is the user's call, not ours.
      const missing = expected.filter((e) => !names.includes(e));
      ok = missing.length === 0;
      detail = `${names.length} hits: ${names.slice(0, 4).join(', ')}`;
      if (!ok) detail += `  missing ${missing.join(', ')}`;
    } else {
      ok = got === expected;
      detail = got ?? '(none)';
    }

    if (ok) { pass++; console.log(`  ok    ${query.padEnd(34)} → ${detail}   ${why}`); }
    else { fail++; console.log(`  FAIL  ${query.padEnd(34)} → ${detail}   expected ${expected}`); }
  }
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
}

const query = process.argv.slice(2).filter((a) => !a.startsWith('--')).join(' ');
if (!query) { console.error('usage: resolve.mjs "<query>" | --test'); process.exit(2); }

const results = resolve(db, query);
if (!results.length) { console.log(`no match for "${query}" → lands in Other, one tap to categorize`); process.exit(0); }
console.log(`"${query}"`);
for (const r of results) {
  const price = r.base_amount ? `~$${r.base_amount < 10 ? r.base_amount.toFixed(2) : r.base_amount.toFixed(0)}` : '—';
  console.log(`  ${r.emoji ?? ' '} ${r.canonical_name.padEnd(26)} ${r.category_id.padEnd(14)} ${price.padStart(7)}   [${r.via}]`);
}

}
