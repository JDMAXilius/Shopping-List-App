// join-kitchen: authenticated caller (anonymous-auth guest sessions included)
// + exact invite token → membership. Invalid and revoked tokens are one
// indistinguishable 404 — no oracle for enumerating capability URLs.

import { createClient } from "npm:@supabase/supabase-js@2";

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authHeader = req.headers.get("authorization");
  if (!authHeader) return json(401, { error: "unauthenticated" });

  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData?.user) return json(401, { error: "unauthenticated" });

  let token: unknown;
  try {
    ({ token } = await req.json());
  } catch {
    return json(400, { error: "invalid_body" });
  }
  if (typeof token !== "string" || token.length === 0 || token.length > 200) {
    return json(400, { error: "invalid_body" });
  }

  // Runs as the caller: join_kitchen derives identity from auth.uid().
  const { data, error } = await client.rpc("join_kitchen", { invite_token: token });
  if (error || !data) return json(404, { error: "not_found" });  // one shape for every failure

  return json(200, { kitchen_id: data });
});
