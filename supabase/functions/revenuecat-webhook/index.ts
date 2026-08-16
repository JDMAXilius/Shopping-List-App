// revenuecat-webhook: RevenueCat server events → entitlement upsert.
// Verified by shared secret in the Authorization header (constant-time compare).
// Service-role only path; logs event TYPE only — never payloads or ids.

import { createClient } from "npm:@supabase/supabase-js@2";

const PLUS_ON = new Set(["INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION"]);
// CANCELLATION alone is auto-renew off — access lasts until EXPIRATION fires,
// so only EXPIRATION flips the flag (never lock a paying user out early).
const PLUS_OFF = new Set(["EXPIRATION"]);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  const header = req.headers.get("authorization") ?? "";
  if (
    !secret ||
    (!timingSafeEqual(header, secret) && !timingSafeEqual(header, `Bearer ${secret}`))
  ) {
    return json(401, { error: "unauthorized" });
  }

  let event: { type?: unknown; app_user_id?: unknown; event_timestamp_ms?: unknown };
  try {
    ({ event = {} } = await req.json());
  } catch {
    return json(400, { error: "invalid_body" });
  }
  const type = typeof event.type === "string" ? event.type : "UNKNOWN";
  const appUserId = typeof event.app_user_id === "string" ? event.app_user_id : "";
  // Ordering fence input: RevenueCat delivery is unordered and retried. Fallback
  // to now() keeps liveness if the field is ever absent (it is documented-always).
  const eventMs =
    typeof event.event_timestamp_ms === "number" && Number.isFinite(event.event_timestamp_ms)
      ? event.event_timestamp_ms
      : Date.now();

  if (!PLUS_ON.has(type) && !PLUS_OFF.has(type)) {
    console.log(`revenuecat-webhook: unhandled event type ${type}`);
    return json(200, { ok: true });
  }
  if (!UUID_RE.test(appUserId)) {
    // e.g. an anonymous RevenueCat alias that is not a Supabase user id
    console.log(`revenuecat-webhook: ${type} without uuid app_user_id, skipped`);
    return json(200, { ok: true });
  }

  const svc = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  // apply_entitlement_event (0002) upserts WHERE plus_event_at < excluded's:
  // a stale or replayed event is a no-op; scans_used is never touched.
  const { error } = await svc.rpc("apply_entitlement_event", {
    p_user: appUserId,
    p_is_plus: PLUS_ON.has(type),
    p_event_at: new Date(eventMs).toISOString(),
  });
  if (error) return json(500, { error: "storage" });

  return json(200, { ok: true });
});
