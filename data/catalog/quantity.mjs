#!/usr/bin/env node
// Reference implementation for Packages/Catalog/QuantityParser.swift.
// Pulls a leading quantity/container off free text so the resolver sees the item:
//   "2 lb chicken breast" → 2 lb   · "chicken breast"
//   "punnet of strawberries" → 1 punnet · "strawberries"
//
// The Swift port is pinned to this file's behaviour (node quantity.mjs --test).

const UNITS = {
  lb: 'lb', lbs: 'lb', pound: 'lb', pounds: 'lb',
  kg: 'kg', kgs: 'kg', kilo: 'kg', kilos: 'kg',
  g: 'g', gram: 'g', grams: 'g', oz: 'oz', ounce: 'oz', ounces: 'oz',
  l: 'l', litre: 'l', litres: 'l', liter: 'l', liters: 'l',
  ml: 'ml', pint: 'pint', pints: 'pint', quart: 'quart', quarts: 'quart',
  dozen: 'dozen', dozens: 'dozen',
  pack: 'pack', packs: 'pack', packet: 'pack', packets: 'pack',
  bunch: 'bunch', bunches: 'bunch',
  can: 'can', cans: 'can', tin: 'tin', tins: 'tin',
  bottle: 'bottle', bottles: 'bottle',
  box: 'box', boxes: 'box',
  bag: 'bag', bags: 'bag',
  jar: 'jar', jars: 'jar',
  tub: 'tub', tubs: 'tub', pot: 'pot', pots: 'pot',
  carton: 'carton', cartons: 'carton',
  punnet: 'punnet', punnets: 'punnet',
  loaf: 'loaf', loaves: 'loaf',
  head: 'head', heads: 'head',
  clove: 'clove', cloves: 'clove',
  slice: 'slice', slices: 'slice',
  roll: 'roll', rolls: 'roll',
  sachet: 'sachet', sachets: 'sachet',
  tube: 'tube', tubes: 'tube',
  block: 'block', blocks: 'block',
  piece: 'piece', pieces: 'piece',
  bar: 'bar', bars: 'bar',
};

const WORD_NUMBERS = {
  a: 1, an: 1, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6,
  seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12, couple: 2,
};

// Only sizes, and only ahead of a container: "large tub of yoghurt".
const SIZES = new Set(['large', 'small', 'medium', 'big', 'little', 'jumbo', 'mini']);

const isNumber = (t) => /^\d+(\.\d+)?$/.test(t);

// "2lb" / "500g" — number and unit fused into one token.
function attached(token) {
  const m = /^(\d+(?:\.\d+)?)([a-z]+)$/.exec(token);
  if (!m || !UNITS[m[2]]) return null;
  return [Number(m[1]), UNITS[m[2]]];
}

export function parseQuantity(input) {
  const raw = (input ?? '').trim().split(/\s+/).filter(Boolean);
  if (!raw.length) return { quantity: null, unit: null, rest: '' };

  const lower = raw.map((t) => t.toLowerCase());
  let i = 0;
  let quantity = null;
  let unit = null;

  // half / half a / half dozen
  if (lower[i] === 'half') {
    quantity = 0.5;
    i += 1;
    if (lower[i] === 'a' || lower[i] === 'an') i += 1;
  }

  if (quantity === null && isNumber(lower[i])) {
    quantity = Number(lower[i]);
    i += 1;
  } else if (quantity === null && attached(lower[i])) {
    [quantity, unit] = attached(lower[i]);
    i += 1;
  } else if (quantity === null && WORD_NUMBERS[lower[i]] !== undefined && lower.length > 1) {
    quantity = WORD_NUMBERS[lower[i]];
    i += 1;
    if (lower[i] === 'of') i += 1;               // "couple of apples"
  }

  if (!unit && SIZES.has(lower[i]) && UNITS[lower[i + 1]]) i += 1;   // "large tub of…"

  if (!unit && UNITS[lower[i]]) {
    unit = UNITS[lower[i]];
    i += 1;
    if (quantity === null) quantity = 1;         // "carton of milk" is one carton
  }

  if (unit && lower[i] === 'of') i += 1;

  const rest = raw.slice(i).join(' ');
  // Never consume the whole input: a bare "loaf" or "dozen" IS the item.
  if (!rest) return { quantity: null, unit: null, rest: raw.join(' ') };
  return { quantity, unit, rest };
}

/* ── CLI ────────────────────────────────────────────────────────────────── */

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split('/').pop());
if (isMain) {
  const cases = [
    ['2 lb chicken breast', 2, 'lb', 'chicken breast'],
    ['1kg mince', 1, 'kg', 'mince'],
    ['500g pasta', 500, 'g', 'pasta'],
    ['6 eggs', 6, null, 'eggs'],
    ['dozen eggs', 1, 'dozen', 'eggs'],
    ['half dozen eggs', 0.5, 'dozen', 'eggs'],
    ['a loaf of bread', 1, 'loaf', 'bread'],
    ['loaf of bread', 1, 'loaf', 'bread'],
    ['carton of milk', 1, 'carton', 'milk'],
    ['2 pints of milk', 2, 'pint', 'milk'],
    ['bag of potatoes', 1, 'bag', 'potatoes'],
    ['punnet of strawberries', 1, 'punnet', 'strawberries'],
    ['large tub of yoghurt', 1, 'tub', 'yoghurt'],
    ['three apples', 3, null, 'apples'],
    ['couple of bananas', 2, null, 'bananas'],
    ['2 x 1l milk', 2, null, 'x 1l milk'],
    // must NOT strip — the container word is the item, or isn't a container
    ['loaf', null, null, 'loaf'],
    ['dozen', null, null, 'dozen'],
    ['bin bags', null, null, 'bin bags'],
    ['tea bags', null, null, 'tea bags'],
    ['canned tomatoes', null, null, 'canned tomatoes'],
    ['chicken breast', null, null, 'chicken breast'],
    ['bag', null, null, 'bag'],
  ];
  let pass = 0, fail = 0;
  for (const [input, q, u, rest] of cases) {
    const got = parseQuantity(input);
    const ok = got.quantity === q && got.unit === u && got.rest === rest;
    if (ok) { pass++; console.log(`  ok    ${input.padEnd(24)} → ${got.quantity ?? '–'} ${got.unit ?? '–'} · ${got.rest}`); }
    else { fail++; console.log(`  FAIL  ${input.padEnd(24)} → ${got.quantity} ${got.unit} · "${got.rest}"   want ${q} ${u} · "${rest}"`); }
  }
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
}
