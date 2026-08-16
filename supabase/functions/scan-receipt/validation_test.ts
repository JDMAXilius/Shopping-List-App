// Attacks on the scan-receipt boundaries. Run: deno test supabase/functions/scan-receipt/
//
// The cases here are the ones the client proved reach it today: a single malformed line
// used to fail the whole strict decode on the device AND burn one of three free scans.
// Each one must be stopped HERE, on the server, before it is ever billed to a user.
// Not imported by index.ts, so it is never bundled into the deployed function.

import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import {
  type ReceiptLine,
  validateBody,
  validateLine,
  validateLines,
  validateOptionals,
} from "./validation.ts";

const GOOD: ReceiptLine = {
  raw_text: "TJ ORG BABY SPNC",
  amount_minor: 349,
  quantity: 1,
  confidence: "sure",
};

Deno.test("validateLine: a well-formed line survives unchanged", () => {
  assertEquals(validateLine({ ...GOOD }), GOOD);
});

Deno.test("validateLine: match_hint is kept when present, absent when null", () => {
  assertEquals(validateLine({ ...GOOD, match_hint: "baby spinach" }), {
    ...GOOD,
    match_hint: "baby spinach",
  });
  // null and absent are the same answer — no hint — and the client decodes them the same.
  assertEquals(validateLine({ ...GOOD, match_hint: null }), GOOD);
  assertEquals(validateLine({ ...GOOD, match_hint: 7 }), null);
});

Deno.test("validateLine: a missing amount_minor is rejected", () => {
  const line: Record<string, unknown> = { ...GOOD };
  delete line.amount_minor;
  assertEquals(validateLine(line), null);
});

Deno.test("validateLine: a string where a number belongs is rejected", () => {
  assertEquals(validateLine({ ...GOOD, amount_minor: "349" }), null);
  assertEquals(validateLine({ ...GOOD, quantity: "2" }), null);
});

Deno.test("validateLine: amount_minor must be an integer — minor units, never a float", () => {
  assertEquals(validateLine({ ...GOOD, amount_minor: 3.49 }), null);
  // A negative amount is allowed: a per-line coupon is a real printed line.
  assertNotEquals(validateLine({ ...GOOD, amount_minor: -100 }), null);
});

Deno.test("validateLine: fractional quantity is allowed — 0.75 kg is a real line", () => {
  assertNotEquals(validateLine({ ...GOOD, quantity: 0.75 }), null);
});

Deno.test("validateLine: confidence outside the enum is rejected", () => {
  assertEquals(validateLine({ ...GOOD, confidence: "maybe" }), null);
  assertEquals(validateLine({ ...GOOD, confidence: "SURE" }), null);
  for (const c of ["sure", "not_sure", "no_match"]) {
    assertNotEquals(validateLine({ ...GOOD, confidence: c }), null);
  }
});

Deno.test("validateLine: raw_text must carry actual text", () => {
  assertEquals(validateLine({ ...GOOD, raw_text: "" }), null);
  assertEquals(validateLine({ ...GOOD, raw_text: "   " }), null);
});

Deno.test("validateLine: a line that is not an object is rejected", () => {
  for (const v of [null, undefined, [], "line", 3, true]) {
    assertEquals(validateLine(v), null);
  }
});

Deno.test("validateLine: unknown keys are dropped, never passed through", () => {
  assertEquals(validateLine({ ...GOOD, injected: "<script>", amount_major: 3 }), GOOD);
});

Deno.test("validateLines: ONE bad line among nine good ones fails the whole receipt", () => {
  const lines: unknown[] = Array.from({ length: 9 }, (_, i) => ({ ...GOOD, raw_text: `L${i}` }));
  lines.splice(4, 0, { ...GOOD, amount_minor: "1.99" });
  // The ruling: a receipt silently missing a line is worse than a receipt the user retries.
  assertEquals(validateLines(lines), null);
});

Deno.test("validateLines: good lines pass through in printed order", () => {
  const out = validateLines([GOOD, { ...GOOD, raw_text: "MILK 2%", amount_minor: 199 }]);
  assertEquals(out?.length, 2);
  assertEquals(out?.[1].raw_text, "MILK 2%");
});

Deno.test("validateLines: an empty receipt is valid, not an error", () => {
  assertEquals(validateLines([]), []);
});

Deno.test("validateOptionals: absent and null both become explicit null", () => {
  const empty = { shop_name: null, total_minor: null, purchased_at: null };
  assertEquals(validateOptionals({}), empty);
  assertEquals(validateOptionals({ ...empty }), empty);
});

Deno.test("validateOptionals: good values survive", () => {
  assertEquals(
    validateOptionals({ shop_name: "Trader Joe's", total_minor: 8450, purchased_at: "2026-08-16" }),
    { shop_name: "Trader Joe's", total_minor: 8450, purchased_at: "2026-08-16" },
  );
});

Deno.test("validateOptionals: a wrong-typed optional fails the receipt too", () => {
  // The client decodes total_minor as Int? — "84.50" or 84.5 breaks the whole decode there,
  // which is the same lost-scan bug as a bad line, one level up.
  assertEquals(validateOptionals({ total_minor: "84.50" }), null);
  assertEquals(validateOptionals({ total_minor: 84.5 }), null);
  assertEquals(validateOptionals({ shop_name: 5 }), null);
  assertEquals(validateOptionals({ purchased_at: 1723800000 }), null);
});

Deno.test("validateBody: the request boundary still refuses what it always did", () => {
  assertNotEquals(validateBody({ image_base64: "abc", media_type: "image/jpeg" }), null);
  assertEquals(validateBody({ image_base64: "abc", media_type: "image/heic" }), null);
  assertEquals(validateBody({ image_base64: "", media_type: "image/png" }), null);
  assertEquals(validateBody({ media_type: "image/png" }), null);
  assertEquals(
    validateBody({ image_base64: "abc", media_type: "image/png", shop_hint: "x".repeat(101) }),
    null,
  );
  assertEquals(validateBody("nope"), null);
  assertEquals(validateBody(null), null);
});
