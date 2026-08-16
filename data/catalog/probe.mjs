#!/usr/bin/env node
// Demand simulation: run realistic shopping phrasings through the resolver and
// report what misses. Growth comes from misses, never from bulk import.
//
//   node data/catalog/probe.mjs            # summary + miss list
//   node data/catalog/probe.mjs --verbose  # every query with its top hit

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { resolve } from './resolve.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const db = new DatabaseSync(join(here, 'catalog.db'), { readOnly: true });
const queries = readFileSync(join(here, 'probe-queries.txt'), 'utf8')
  .split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));

const verbose = process.argv.includes('--verbose');
const misses = [];
const weak = [];

for (const q of queries) {
  const [top] = resolve(db, q);
  if (!top) { misses.push([q, null]); continue; }
  // score >= 5 is the fuzzy tier — a guess, not a match.
  if (top.score >= 5) { weak.push([q, top.canonical_name]); continue; }
  if (verbose) console.log(`  ok    ${q.padEnd(30)} → ${top.canonical_name}`);
}

const hit = queries.length - misses.length - weak.length;
console.log(`\n${queries.length} queries · ${hit} resolved · ${weak.length} weak · ${misses.length} missed`);
console.log(`coverage ${((hit / queries.length) * 100).toFixed(1)}%\n`);
if (weak.length) {
  console.log('WEAK (fuzzy-tier only — a guess, not a match):');
  for (const [q, got] of weak) console.log(`  ${q.padEnd(30)} → ${got}`);
}
if (misses.length) {
  console.log('\nMISSED (nothing at all):');
  for (const [q] of misses) console.log(`  ${q}`);
}
process.exit(0);
