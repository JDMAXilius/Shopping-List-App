// Both boundaries of scan-receipt, in one file with no Deno or npm dependency so it can
// be unit-tested directly (validation_test.ts) — nothing here talks to the network.
//
// IN:  what a client is allowed to send us.
// OUT: what the model is allowed to send the client. Structured outputs are a request,
//      not a guarantee, so RECEIPT_SCHEMA lives next to the code that re-checks it —
//      edit one and the other is on screen.

export const MEDIA_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

// $1,000,000 in minor units. `Number.isInteger(1e300)` is true, and the client decodes
// amount_minor into a Swift Int — an out-of-range number returns 200, fails the WHOLE decode
// on the device, and burns a free scan that nothing can refund. The bound the client needs
// has to be stated here, because here is the only place that can enforce it.
const AMOUNT_LIMIT = 100_000_000;
const QUANTITY_LIMIT = 10_000;

const inRange = (v: number, limit: number) => Number.isInteger(v) && Math.abs(v) <= limit;

export const RECEIPT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["lines", "currency"],
  properties: {
    lines: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["raw_text", "amount_minor", "quantity", "confidence"],
        properties: {
          raw_text: { type: "string" },
          amount_minor: { type: "integer", minimum: -100000000, maximum: 100000000 },
          quantity: { type: "number", exclusiveMinimum: 0, maximum: 10000 },
          confidence: { enum: ["sure", "not_sure", "no_match"] },
          match_hint: { type: "string" },
        },
      },
    },
    shop_name: { type: "string" },
    total_minor: { type: "integer", minimum: -100000000, maximum: 100000000 },
    currency: { type: "string", pattern: "^[A-Z]{3}$" },
    purchased_at: { type: "string" },
  },
} as const;

// Read off the schema rather than restated: the enum cannot drift from the thing we asked for.
const CONFIDENCE_VALUES = new Set<string>(
  RECEIPT_SCHEMA.properties.lines.items.properties.confidence.enum,
);

export interface ScanRequest {
  image_base64: string;
  media_type: string;
  shop_hint?: string;
}

// Boundary validation by hand — the shape is too small to justify a dependency.
export function validateBody(body: unknown): ScanRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  if (typeof b.image_base64 !== "string" || b.image_base64.length === 0) return null;
  if (typeof b.media_type !== "string" || !MEDIA_TYPES.has(b.media_type)) return null;
  if (b.shop_hint !== undefined && (typeof b.shop_hint !== "string" || b.shop_hint.length > 100)) {
    return null;
  }
  return {
    image_base64: b.image_base64,
    media_type: b.media_type,
    shop_hint: b.shop_hint as string | undefined,
  };
}

export interface ReceiptLine {
  raw_text: string;
  amount_minor: number;
  quantity: number;
  confidence: string;
  match_hint?: string;
}

// The client decodes strictly and deliberately — a silently dropped line is a silently
// lost price — so an unchecked line does not degrade the receipt, it destroys it: one
// malformed field used to fail the whole decode on the device AND burn the user's scan.
// Returns the line REBUILT from the fields we validated, so the response carries exactly
// the keys we checked and never a passthrough of whatever else the model emitted.
export function validateLine(value: unknown): ReceiptLine | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  const l = value as Record<string, unknown>;
  if (typeof l.raw_text !== "string" || l.raw_text.trim().length === 0) return null;
  if (typeof l.amount_minor !== "number" || !inRange(l.amount_minor, AMOUNT_LIMIT)) return null;
  if (
    typeof l.quantity !== "number" || !Number.isFinite(l.quantity) ||
    l.quantity <= 0 || l.quantity > QUANTITY_LIMIT
  ) {
    return null;
  }
  if (typeof l.confidence !== "string" || !CONFIDENCE_VALUES.has(l.confidence)) return null;
  // null is accepted as absent — both mean "no hint", and that is how the client decodes
  // it. Any other type is a malformed line.
  if (l.match_hint !== undefined && l.match_hint !== null && typeof l.match_hint !== "string") {
    return null;
  }
  const line: ReceiptLine = {
    raw_text: l.raw_text,
    amount_minor: l.amount_minor,
    quantity: l.quantity,
    confidence: l.confidence,
  };
  if (typeof l.match_hint === "string") line.match_hint = l.match_hint;
  return line;
}

// All-or-nothing, by ruling: one bad line fails the whole parse rather than being dropped
// with a count. A receipt quietly missing a line is exactly the failure the review screen
// exists to prevent (PRODUCT §5 CAPTURE — "nothing commits unreviewed", and the capture
// result claims "every line became a price"). The caller refunds the scan; the user retries.
// Emptiness is not this function's question — validateEnvelope has already refused a receipt
// with no lines at all, one status earlier (422, not 502).
export function validateLines(values: readonly unknown[]): ReceiptLine[] | null {
  const lines: ReceiptLine[] = [];
  for (const value of values) {
    const line = validateLine(value);
    if (line === null) return null;
    lines.push(line);
  }
  return lines;
}

export interface ReceiptEnvelope {
  receipt: Record<string, unknown>;
  lines: readonly unknown[];
  currency: string;
}

// The whole "this parse is not usable as a receipt" gate, in one place: the caller answers
// every failure here identically (422 unparseable_image + refund), because to the user they
// are one thing — "we couldn't read this, try again".
//
// ZERO LINES IS A FAILED READ. A receipt with no line items is not a receipt: a photo of a
// cat, a blank wall or a menu comes back from structured outputs as a well-formed
// `{lines: [], ...}`, and shipping that as a 200 would put an empty review screen (PRODUCT §5
// CAPTURE) in front of someone and charge them one of their three free scans (§3 Money) for
// nothing. Nothing malfunctioned, there was just nothing there — which is 422, not 502.
//
// Deliberately NOT extended past emptiness: lines present with `total_minor` null (a receipt
// whose grand total is not printed, or not parsed, is still a receipt — the review screen
// shows what was read), and lines whose amounts sum to zero (a coupon-heavy trip is real,
// and per-line negatives are valid by validateLine — a coupon is ON the receipt, and hiding it
// here would stop the review screen from reconciling to the printed total. Whether a negative
// line is a PRICE is the client's ruling, not ours; it is not).
export function validateEnvelope(parsed: unknown): ReceiptEnvelope | null {
  // JSON.parse returns null, a number or an array just as happily as an object, and reaching
  // for .lines on null throws — which would have been an unrefunded 500.
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) return null;
  const receipt = parsed as Record<string, unknown>;
  if (!Array.isArray(receipt.lines) || receipt.lines.length === 0) return null;
  // A three-letter ISO code, upper-cased here. Any non-empty string used to pass, and the
  // client puts this straight into Money: "eur" renders as "eur 40.00" because the symbol
  // table is keyed uppercase, and "Dollars" renders as "Dollars 40.00".
  if (typeof receipt.currency !== "string") return null;
  const currency = receipt.currency.trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(currency)) return null;
  return { receipt, lines: receipt.lines, currency };
}

export interface ReceiptOptionals {
  shop_name: string | null;
  total_minor: number | null;
  purchased_at: string | null;
}

// The optional top-level fields are the same trap one level up: the client decodes
// total_minor as Int? and shop_name/purchased_at as String?, so a wrong-typed value here
// fails the entire receipt on the device just as a bad line does. Absent and null are the
// same answer ("not printed"); present-but-wrong-typed is a malfunction, not an answer.
export function validateOptionals(receipt: Record<string, unknown>): ReceiptOptionals | null {
  const nullableString = (v: unknown) => v === undefined || v === null || typeof v === "string";
  if (!nullableString(receipt.shop_name)) return null;
  if (!nullableString(receipt.purchased_at)) return null;
  if (
    receipt.total_minor !== undefined && receipt.total_minor !== null &&
    !(typeof receipt.total_minor === "number" && inRange(receipt.total_minor, AMOUNT_LIMIT))
  ) {
    return null;
  }
  return {
    shop_name: typeof receipt.shop_name === "string" ? receipt.shop_name : null,
    total_minor: typeof receipt.total_minor === "number" ? receipt.total_minor : null,
    purchased_at: typeof receipt.purchased_at === "string" ? receipt.purchased_at : null,
  };
}
