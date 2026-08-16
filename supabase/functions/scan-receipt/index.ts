// scan-receipt: JWT → quota → Claude (structured output) → parsed lines.
// Stateless by contract: the image is never stored, never logged; scan_audit
// records user_id + timestamp ONLY. The Anthropic key exists only in function env.

import { createClient } from "npm:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const RATE_LIMIT_PER_HOUR = 10;
const MEDIA_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

// ARCHITECTURE §7: Opus 5 is the beta accuracy baseline; the cost step-down
// to a smaller model later is exactly this one line.
const MODEL = "claude-opus-5";

// Fixed and FIRST in the message on every call, so prompt caching can apply.
const INSTRUCTION_PREFIX =
  "You are a grocery receipt parser. Extract the purchased line items from the receipt image. " +
  "Respond with JSON only, matching the required schema. All amounts are integer minor units " +
  "(e.g. cents). For each line: raw_text is the line exactly as printed; quantity defaults to 1; " +
  "confidence is 'sure' when text and price are clearly legible, 'not_sure' when partially " +
  "legible, 'no_match' when the line is probably not a purchasable item; match_hint is a " +
  "lowercase normalized guess of the item name when you have one. Exclude subtotal, tax, " +
  "discount-summary and payment lines from lines; put the printed grand total in total_minor. " +
  "currency is the ISO 4217 code. purchased_at is the printed date as ISO 8601, if present.";

const RECEIPT_SCHEMA = {
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
          amount_minor: { type: "integer" },
          quantity: { type: "number" },
          confidence: { enum: ["sure", "not_sure", "no_match"] },
          match_hint: { type: "string" },
        },
      },
    },
    shop_name: { type: "string" },
    total_minor: { type: "integer" },
    currency: { type: "string" },
    purchased_at: { type: "string" },
  },
} as const;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

interface ScanRequest {
  image_base64: string;
  media_type: string;
  shop_hint?: string;
}

// Boundary validation by hand — the shape is too small to justify a dependency.
function validateBody(body: unknown): ScanRequest | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  if (typeof b.image_base64 !== "string" || b.image_base64.length === 0) return null;
  if (typeof b.media_type !== "string" || !MEDIA_TYPES.has(b.media_type)) return null;
  if (b.shop_hint !== undefined && (typeof b.shop_hint !== "string" || b.shop_hint.length > 100)) {
    return null;
  }
  return { image_base64: b.image_base64, media_type: b.media_type, shop_hint: b.shop_hint as string | undefined };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("authorization");
  if (!authHeader) return json(401, { error: "unauthenticated" });

  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) return json(401, { error: "unauthenticated" });
  const userId = userData.user.id;

  let parsedBody: unknown;
  try {
    parsedBody = await req.json();
  } catch {
    return json(400, { error: "invalid_body" });
  }
  const input = validateBody(parsedBody);
  if (input === null) return json(400, { error: "invalid_body" });
  if ((input.image_base64.length * 3) / 4 > MAX_IMAGE_BYTES) {
    return json(413, { error: "image_too_large", max_bytes: MAX_IMAGE_BYTES });
  }

  // Service-role client: quota + audit live behind RLS that clients cannot reach.
  const svc = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const { count, error: countError } = await svc
    .from("scan_audit")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", hourAgo);
  if (countError) return json(502, { error: "upstream" });
  if ((count ?? 0) >= RATE_LIMIT_PER_HOUR) return json(429, { error: "rate_limited" });

  const { error: auditError } = await svc.from("scan_audit").insert({ user_id: userId });
  if (auditError) return json(502, { error: "upstream" });

  const { data: quota, error: quotaError } = await svc
    .rpc("consume_scan", { p_user: userId })
    .single();
  if (quotaError || !quota) return json(502, { error: "upstream" });
  const { allowed, is_plus, scans_used } = quota as {
    allowed: boolean;
    is_plus: boolean;
    scans_used: number;
  };
  if (!allowed) return json(402, { error: "quota_exhausted", scans_used });
  const freeScanConsumed = !is_plus;

  const refund = async () => {
    if (freeScanConsumed) await svc.rpc("refund_scan", { p_user: userId });
  };

  const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

  const content: unknown[] = [
    { type: "text", text: INSTRUCTION_PREFIX },
    {
      type: "image",
      source: { type: "base64", media_type: input.media_type, data: input.image_base64 },
    },
  ];
  if (input.shop_hint) {
    content.push({ type: "text", text: `The shop is probably: ${input.shop_hint}` });
  }

  let responseText: string | undefined;
  try {
    // `output_config` spelling per spec; if the SDK ships structured outputs as
    // `output_format: { type: "json_schema", schema }`, that rename is the only change (flagged P3).
    const request = {
      model: MODEL,
      max_tokens: 2048,
      output_config: { format: { type: "json_schema", schema: RECEIPT_SCHEMA } },
      messages: [{ role: "user", content }],
    };
    // deno-lint-ignore no-explicit-any
    const message = await anthropic.messages.create(request as any);
    for (const block of message.content) {
      if (block.type === "text") {
        responseText = block.text;
        break;
      }
    }
  } catch {
    await refund();
    return json(502, { error: "upstream" });  // never log the error body: it can echo input
  }
  if (!responseText) {
    await refund();
    return json(502, { error: "upstream" });
  }

  let receipt: Record<string, unknown>;
  try {
    receipt = JSON.parse(responseText);
  } catch {
    await refund();
    return json(422, { error: "unparseable_image" });
  }
  if (!Array.isArray(receipt.lines) || typeof receipt.currency !== "string") {
    await refund();
    return json(422, { error: "unparseable_image" });
  }

  return json(200, {
    lines: receipt.lines,
    shop_name: receipt.shop_name ?? null,
    total_minor: receipt.total_minor ?? null,
    currency: receipt.currency,
    purchased_at: receipt.purchased_at ?? null,
    is_plus,
    scans_used,
  });
});
