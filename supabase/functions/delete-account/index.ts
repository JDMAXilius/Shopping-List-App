// delete-account: authenticated caller (anonymous-auth guest sessions included) →
// their account is gone. App Review 5.1.1(v) requires this to exist in-app;
// DECISIONS.md → "Deleting an account" defines what "gone" means, and the SQL side
// (delete_account(), migration 0003) is what actually defines it.
//
// WHY THIS FUNCTION EXISTS AT ALL, given the RPC does the work:
// the RPC cannot GUARANTEE the auth user is deleted. auth.users belongs to
// supabase_auth_admin, and whether the `postgres`-owned definer function may delete
// from it is a property of the hosted project rather than of this repo — and a
// refusal there can be silent (a policy matching zero rows deletes nothing and
// raises nothing). So the RPC reports whether it removed the row, and this function
// closes the gap with the Admin API, which is Supabase's supported path and needs the
// service-role key — a key that must never be in the app binary. Migration 0003 alone
// does not finish the job on a project where that privilege is absent.

import { createClient } from "npm:@supabase/supabase-js@2";

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

  // THE INPUT SHAPE IS "NOTHING", ON PURPOSE. The request body is never read: there is
  // no user id to accept, because a body-supplied id here would be an
  // account-deletion-of-anyone endpoint. Identity is the verified JWT and nothing else,
  // on this side and inside delete_account(), which takes no parameter either.
  // No rate limit for the same reason it needs none: the only account this can reach is
  // the caller's, and a repeat call is an all-zero no-op (proven, RLS suite section 20).

  // Runs as the CALLER (the join-kitchen idiom): delete_account derives identity from
  // auth.uid(), so the service key is not involved in deciding whose data goes.
  const { data, error } = await userClient.rpc("delete_account");
  if (error || !data) {
    // The RPC is one transaction: a failure here deleted nothing. Say so plainly —
    // an app that told the user "your account is deleted" over this would be lying.
    return json(502, { error: "upstream", data_deleted: false });
  }
  const summary = data as Record<string, unknown>;

  // The auth user, guaranteed. Only when the RPC did not remove the row itself — false
  // also covers "it was already gone" (a retry), and deleteUser on an absent user
  // answers 404, which IS success for our purpose.
  if (summary.auth_user_deleted !== true) {
    const svc = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    // shouldSoftDelete stays false explicitly: a soft delete keeps the row and the
    // email address, which is not what 5.1.1(v) asks for and not what we promised.
    const { error: adminError } = await svc.auth.admin.deleteUser(userId, false);
    const alreadyGone = adminError !== null &&
      (adminError.status === 404 || /not.?found/i.test(adminError.message ?? ""));
    if (adminError && !alreadyGone) {
      // The data is gone but the login is not: the honest report, because the app must
      // retry rather than show a success screen. Retrying is safe — the RPC half is
      // idempotent. Never log adminError: it carries the identity of someone who just
      // asked to be forgotten.
      return json(502, { error: "auth_user_not_deleted", data_deleted: true });
    }
  }

  // Counts only, never ids: the app can say what happened ("1 kitchen deleted, 1 handed
  // over") without this function ever holding a kitchen id or another member's user id.
  // The local half is NOT this function's: the app still has to wipe its database,
  // receipt photos, pins and defaults, and sign out (DataPrivacyScreen's promise).
  return json(200, {
    deleted: true,
    kitchens_deleted: summary.kitchens_deleted,
    kitchens_kept: summary.kitchens_kept,
    owners_promoted: summary.owners_promoted,
  });
});
