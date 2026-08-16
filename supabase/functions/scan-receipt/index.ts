// scan-receipt: JWT → quota → Claude (structured output) → parsed lines.
// Stateless by contract: the image is never stored, never logged; scan_audit
// records user_id + timestamp ONLY. The Anthropic key exists only in function env.

import { createClient } from "npm:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";
import {
  RECEIPT_SCHEMA,
  validateBody,
  validateEnvelope,
  validateLines,
  validateOptionals,
} from "./validation.ts";

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const RATE_LIMIT_PER_HOUR = 10;

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

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
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

  // PRODUCT: paywall the owner, never the joiner — scanning is owner-side. An
  // anonymous session is recyclable; free quota must attach to a real account.
  //
  // The two 403s below are NOT interchangeable, and the client's routing is pinned to
  // these exact strings (PRODUCT §5: onboarding is contextual, so a refusal must name the
  // step that is missing). Do not merge or rename them:
  //   "sign_in_required" -> Sign in (screen 19)          — anonymous session, no account
  //   "kitchen_required" -> Name your kitchen (sheet 17) — real account, owns no kitchen
  // Sending a signed-in owner to a sign-in screen is a dead end; that is what one shared
  // string caused. Same status (403) because both are the same refusal: not entitled yet.
  if (userData.user.is_anonymous) return json(403, { error: "sign_in_required" });

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

  // Only owners scan: a fresh non-owner account has no quota to farm.
  const { data: ownerRow, error: ownerError } = await svc
    .from("member")
    .select("kitchen_id")
    .eq("user_id", userId)
    .eq("role", "owner")
    .limit(1)
    .maybeSingle();
  if (ownerError) return json(502, { error: "upstream" });
  if (!ownerRow) return json(403, { error: "kitchen_required" });  // pinned above

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

  // EVERY failure below this line goes through failAfterQuota: the quota is already spent,
  // so a bare `return json(...)` here would burn one of three free scans for nothing.
  // The returned body says whether it really was spent — `free_scan_charged` is false when
  // the scan was restored (or when a Plus scan spent nothing), true when the refund itself
  // failed. It is never a guess in the user's favour: if we cannot restore it we say so.
  // The field is present ONLY on failures after this point; its absence on a 400/401/403/
  // 413/429/402 means the quota was never touched at all.
  const failAfterQuota = async (status: number, error: string): Promise<Response> => {
    if (!freeScanConsumed) return json(status, { error, free_scan_charged: false });
    try {
      const { error: refundError } = await svc.rpc("refund_scan", { p_user: userId });
      return json(status, { error, free_scan_charged: refundError !== null });
    } catch {
      return json(status, { error, free_scan_charged: true });  // could not restore it: say so
    }
  };

  // Nothing between here and the response may throw its way past the refund: before this
  // guard an unexpected exception became a 500 with the free scan silently spent.
  try {
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
    let stopReason: unknown;
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
      stopReason = message.stop_reason;
      for (const block of message.content) {
        if (block.type === "text") {
          responseText = block.text;
          break;
        }
      }
    } catch {
      // never log the error body: it can echo input
      return await failAfterQuota(502, "upstream");
    }
    if (!responseText) return await failAfterQuota(502, "upstream");

    // Truncation is not a statement about the photo: max_tokens means WE cut the model off
    // mid-receipt, so whatever lines arrived are missing their tail with no way to tell.
    // Fail it as upstream (502), never as an unreadable image — a long receipt is not a bad one.
    if (stopReason === "max_tokens") return await failAfterQuota(502, "upstream");

    let parsed: unknown;
    try {
      parsed = JSON.parse(responseText);
    } catch {
      // Not JSON at all is the model declining rather than parsing — that IS an answer
      // about the image, and 422 sends the user to retake it, which is the right move.
      return await failAfterQuota(422, "unparseable_image");
    }
    // One gate for every shape that is not a readable receipt — not an object, no lines
    // array, NO LINES AT ALL, no currency. All 422: the model answered, and the answer was
    // that there was nothing on this image to read. All refunded by the same path.
    const envelope = validateEnvelope(parsed);
    if (envelope === null) return await failAfterQuota(422, "unparseable_image");

    // Past this point the model claimed a parse, so a schema violation is OUR upstream
    // malfunctioning — not a bad photo. 502, never 422: telling someone their perfectly good
    // receipt is unreadable would send them to retake it for a fault that is not theirs.
    const lines = validateLines(envelope.lines);
    const optionals = validateOptionals(envelope.receipt);
    if (lines === null || optionals === null) return await failAfterQuota(502, "upstream");

    return json(200, {
      lines,
      shop_name: optionals.shop_name,
      total_minor: optionals.total_minor,
      currency: envelope.currency,
      purchased_at: optionals.purchased_at,
      is_plus,
      scans_used,
    });
  } catch {
    return await failAfterQuota(502, "upstream");
  }
});
