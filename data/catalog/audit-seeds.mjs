#!/usr/bin/env node
// Gate #2 (PRODUCT.md §7): are the seeded estimates good enough to show on trip one?
// Feed it real receipt lines; it resolves each to a catalog item and reports the
// error distribution. Median error > ~15% means ship observed prices only.
//
//   node data/catalog/audit-seeds.mjs receipts/trader-joes-2026-08.tsv [region]
//
// Input: TSV, one line per receipt row —  <item text> <TAB> <price paid>
// Lines starting with # are ignored. Region defaults to us-national.

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { resolve as resolveItem } from './resolve.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const [file, regionKey = 'us-national'] = process.argv.slice(2);
if (!file) { console.error('usage: audit-seeds.mjs <receipt.tsv> [region]'); process.exit(2); }

const catalog = JSON.parse(readFileSync(join(here, 'catalog.json'), 'utf8'));
const region = catalog.regions.find((r) => r.key === regionKey);
if (!region) { console.error(`unknown region ${regionKey}`); process.exit(2); }

const db = new DatabaseSync(join(here, 'catalog.db'), { readOnly: true });
const rows = readFileSync(file, 'utf8').split('\n')
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#'))
  .map((l) => l.split('\t'))
  .map(([text, paid]) => ({ text: (text ?? '').trim(), paid: Number(paid) }))
  .filter((r) => r.text && Number.isFinite(r.paid));

const scored = [];
const unmatched = [];

for (const r of rows) {
  const [top] = resolveItem(db, r.text);
  if (!top || top.score >= 5 || top.base_amount == null) { unmatched.push(r); continue; }
  const seeded = top.base_amount * region.multiplier;
  scored.push({ ...r, item: top.canonical_name, seeded, err: (seeded - r.paid) / r.paid });
}

if (!scored.length) { console.log('nothing resolved with a seed price — check the input'); process.exit(1); }

const abs = scored.map((s) => Math.abs(s.err)).sort((a, b) => a - b);
const median = abs[Math.floor(abs.length / 2)];
const mean = abs.reduce((a, b) => a + b, 0) / abs.length;
const within = (t) => abs.filter((e) => e <= t).length / abs.length;
const bias = scored.reduce((a, s) => a + s.err, 0) / scored.length;

console.log(`\n${file}  ·  region ${region.key} (×${region.multiplier})`);
console.log(`${rows.length} lines · ${scored.length} priced · ${unmatched.length} unmatched\n`);
console.log(`  median error   ${(median * 100).toFixed(1)}%      ${median <= 0.15 ? 'PASS — seeds are shippable' : 'FAIL — ship observed prices only'}`);
console.log(`  mean error     ${(mean * 100).toFixed(1)}%`);
console.log(`  bias           ${bias >= 0 ? '+' : ''}${(bias * 100).toFixed(1)}%  ${Math.abs(bias) > 0.1 ? (bias > 0 ? '(seeds run high — consider lowering the region multiplier)' : '(seeds run low)') : ''}`);
console.log(`  within 10%     ${(within(0.10) * 100).toFixed(0)}%`);
console.log(`  within 25%     ${(within(0.25) * 100).toFixed(0)}%\n`);

const worst = [...scored].sort((a, b) => Math.abs(b.err) - Math.abs(a.err)).slice(0, 12);
console.log('WORST OFFENDERS (fix these seeds first):');
for (const s of worst) {
  const sign = s.err >= 0 ? '+' : '';
  console.log(`  ${s.text.slice(0, 24).padEnd(24)} → ${s.item.padEnd(22)} paid $${s.paid.toFixed(2).padStart(6)}  seed $${s.seeded.toFixed(2).padStart(6)}  ${sign}${(s.err * 100).toFixed(0)}%`);
}
if (unmatched.length) {
  console.log('\nUNMATCHED (catalog growth candidates):');
  for (const u of unmatched) console.log(`  ${u.text}`);
}
